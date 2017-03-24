-------------------------------------------------------------------------------
-- File       : AxiMicronN25QReg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2016-09-20
-------------------------------------------------------------------------------
-- Description: MicronN25Q AXI-Lite Register Access
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity AxiMicronN25QReg is
   generic (
      TPD_G            : time                := 1 ns;
      MEM_ADDR_MASK_G  : slv(31 downto 0)    := x"00000000";
      AXI_CLK_FREQ_G   : real                := 200.0E+6;  -- units of Hz
      SPI_CLK_FREQ_G   : real                := 25.0E+6;   -- units of Hz
      PIPE_STAGES_G    : natural             := 0;
      AXI_CONFIG_G     : AxiStreamConfigType := ssiAxiStreamConfig(4);
      AXI_ERROR_RESP_G : slv(1 downto 0)     := AXI_RESP_SLVERR_C);       
   port (
      -- FLASH Memory Ports
      csL            : out sl;
      sck            : out sl;
      mosi           : out sl;
      miso           : in  sl;
      -- AXI-Lite Register Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- AXI Streaming Interface (Optional)
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType;
      sAxisMaster    : in  AxiStreamMasterType;
      sAxisSlave     : out AxiStreamSlaveType;
      -- Global Signals
      axiClk         : in  sl;
      axiRst         : in  sl);
end AxiMicronN25QReg;

architecture rtl of AxiMicronN25QReg is

   constant DOUBLE_SCK_FREQ_C : real    := SPI_CLK_FREQ_G * 2.0;
   constant SCK_HALF_PERIOD_C : natural := (getTimeRatio(AXI_CLK_FREQ_G, DOUBLE_SCK_FREQ_C))-1;
   constant MIN_CS_WIDTH_C    : natural := (getTimeRatio(AXI_CLK_FREQ_G, 2.0E+7));
   constant MAX_SCK_CNT_C     : natural := ite((SCK_HALF_PERIOD_C > MIN_CS_WIDTH_C), SCK_HALF_PERIOD_C, MIN_CS_WIDTH_C);

   constant AXI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);  -- 32-bit interface   

   constant PRESET_32BIT_ADDR_C : slv(8 downto 0) := "111111011";
   constant PRESET_24BIT_ADDR_C : slv(8 downto 0) := "111111100";
   
   type StateType is (
      IDLE_S,
      WORD_WRITE_S,
      WORD_READ_S,
      WORD_READ_HOLD_S,
      RX_ADDR_S,
      RX_LOAD_S,
      BUF_WRITE_MODE_S,
      SCK_LOW_S,
      SCK_HIGH_S,
      MIN_CS_WIDTH_S,
      BUF_READ_MODE_S); 

   type RegType is record
      test          : slv(31 downto 0);
      wrData        : slv(31 downto 0);
      addr          : slv(31 downto 0);
      addr32BitMode : sl;
      cmd           : slv(7 downto 0);
      status        : slv(7 downto 0);
      txStream      : sl;
      bufProgEn     : sl;
      fastCnt       : slv(3 downto 0);
      -- RAM Signals
      RnW           : sl;
      we            : sl;
      rd            : slv(1 downto 0);
      cnt           : slv(8 downto 0);
      waddr         : slv(8 downto 0);
      raddr         : slv(8 downto 0);
      xferSize      : slv(8 downto 0);
      ramDin        : slv(7 downto 0);
      -- SPI Signals
      csL           : sl;
      sck           : sl;
      mosi          : sl;
      sckCnt        : natural range 0 to MAX_SCK_CNT_C;
      bitPntr       : natural range 0 to 7;
      -- AXI Stream Signals
      rxSlave       : AxiStreamSlaveType;
      txMaster      : AxiStreamMasterType;
      -- AXI-Lite Signals
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
      -- Status Machine
      state         : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      test          => (others => '0'),
      wrData        => (others => '0'),
      addr          => (others => '0'),
      addr32BitMode => '0',
      cmd           => (others => '0'),
      status        => (others => '0'),
      txStream      => '0',
      bufProgEn     => '0',
      fastCnt       => (others => '0'),
      -- RAM Signals      
      RnW           => '1',
      we            => '0',
      rd            => "00",
      cnt           => (others => '0'),
      waddr         => (others => '0'),
      raddr         => (others => '0'),
      xferSize      => (others => '0'),
      ramDin        => (others => '0'),
      -- SPI Signals
      csL           => '1',
      sck           => '0',
      mosi          => '0',
      sckCnt        => 0,
      bitPntr       => 0,
      -- AXI Stream Signals
      rxSlave       => AXI_STREAM_SLAVE_INIT_C,
      txMaster      => AXI_STREAM_MASTER_INIT_C,
      -- AXI-Lite Signals
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      -- Status Machine
      state         => IDLE_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ramDout : slv(7 downto 0);

   signal rxMaster : AxiStreamMasterType;
   signal txCtrl   : AxiStreamCtrlType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";

begin

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiRst, axiWriteMaster, miso, r, ramDout, rxMaster, txCtrl) is
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset the strobing signals
      axiWriteResp     := AXI_RESP_OK_C;
      axiReadResp      := AXI_RESP_OK_C;
      v.rxSlave.tReady := '0';
      v.we             := '0';
      ssiResetFlags(v.txMaster);

      -- Shift register
      v.rd(1) := r.rd(0);
      v.rd(0) := '0';

      -- Set the tKeep = 32-bit transfers
      v.txMaster.tKeep := x"00FF";

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the signals in IDLE state
            v.csL      := '1';
            v.sck      := '0';
            v.txStream := '0';
            v.cnt      := (others => '0');
            v.waddr    := (others => '0');
            v.raddr    := (others => '0');
            -- Check for a write request
            if (axiStatus.writeEnable = '1') then
               if axiWriteMaster.awaddr(9) = '1' then
                  -- Latch the write data and write address
                  v.waddr  := axiWriteMaster.awaddr(8 downto 0);
                  v.raddr  := axiWriteMaster.awaddr(8 downto 0);
                  v.wrData := axiWriteMaster.wdata;
                  -- Next state
                  v.state  := WORD_WRITE_S;
               else
                  -- Decode address and perform write
                  case (axiWriteMaster.awaddr(7 downto 0)) is
                     when x"00" =>
                        v.test := axiWriteMaster.wdata;
                     when x"04" =>
                        v.addr32BitMode := axiWriteMaster.wdata(0);
                     when x"08" =>
                        v.addr := axiWriteMaster.wdata;
                     when x"0C" =>
                        v.RnW      := axiWriteMaster.wdata(31);
                        v.txStream := axiWriteMaster.wdata(30);
                        v.cmd      := axiWriteMaster.wdata(23 downto 16);
                        v.xferSize := axiWriteMaster.wdata(8 downto 0);
                        -- Check address mode
                        if r.addr32BitMode = '1' then
                           -- 32-bit Address Mode
                           v.raddr := PRESET_32BIT_ADDR_C;
                        else
                           -- 24-bit Address Mode
                           v.raddr := PRESET_24BIT_ADDR_C;
                        end if;
                        -- Next state
                        v.state := SCK_LOW_S;
                     when others =>
                        axiWriteResp := AXI_ERROR_RESP_G;
                  end case;
               end if;
               -- Send AXI-Lite response
               axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
            -- Check for a read request            
            elsif (axiStatus.readEnable = '1') then
               if axiReadMaster.araddr(9) = '1' then
                  -- Set the read address
                  v.raddr := axiReadMaster.araddr(8 downto 0);
                  -- Set the flag
                  v.rd(0) := '1';
                  -- Next state
                  v.state := WORD_READ_S;
               else
                  -- Reset the register
                  v.axiReadSlave.rdata := (others => '0');
                  -- Decode address and assign read data
                  case (axiReadMaster.araddr(7 downto 0)) is
                     when x"00" =>
                        v.axiReadSlave.rdata := r.test;
                     when x"04" =>
                        v.axiReadSlave.rdata(0) := r.addr32BitMode;
                     when x"08" =>
                        v.axiReadSlave.rdata := r.addr;
                     when x"0C" =>
                        v.axiReadSlave.rdata(7 downto 0) := r.status;
                     when others =>
                        axiReadResp := AXI_ERROR_RESP_G;
                  end case;
                  -- Send AXI-Lite Response
                  axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
               end if;
            else
               -- Check for valid data 
               if (r.rxSlave.tReady = '0') and (rxMaster.tValid = '1') then
                  -- Check for start of frame bit
                  if (ssiGetUserSof(AXI_CONFIG_C, rxMaster) = '1') and (rxMaster.tLast = '0') then
                     -- Ready to readout the FIFO
                     v.rxSlave.tReady := '1';
                     -- Next state
                     v.state          := RX_ADDR_S;
                  else
                     -- Blow off the data
                     v.rxSlave.tReady := '1';
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when WORD_WRITE_S =>
            -- Write a byte to the RAM
            v.we                  := '1';
            v.waddr               := r.raddr;
            v.ramDin              := r.wrData(31 downto 24);
            -- Shift the data
            v.wrData(31 downto 8) := r.wrData(23 downto 0);
            v.wrData(7 downto 0)  := x"00";
            -- Increment the counters
            v.raddr               := r.raddr + 1;
            v.cnt                 := r.cnt + 1;
            -- Check the counter size
            if r.cnt = 3 then
               -- Reset the counter
               v.cnt   := (others => '0');
               -- Next state
               v.state := IDLE_S;
            end if;
         ----------------------------------------------------------------------
         when WORD_READ_S =>
            -- Check if the RAM data is updated
            if r.rd = "00" then
               -- Set the flag
               v.rd(0)                           := '1';
               -- Shift the data
               v.axiReadSlave.rdata(31 downto 8) := v.axiReadSlave.rdata(23 downto 0);
               v.axiReadSlave.rdata(7 downto 0)  := ramDout;
               -- Increment the counters
               v.raddr                           := r.raddr + 1;
               v.cnt                             := r.cnt + 1;
               -- Check the counter size
               if r.cnt = 3 then
                  -- Reset the counter
                  v.cnt   := (others => '0');
                  -- Next state
                  v.state := WORD_READ_HOLD_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when WORD_READ_HOLD_S =>
            -- Send AXI-Lite Response
            axiSlaveReadResponse(v.axiReadSlave);
            -- Wait for read request to complete
            if (axiStatus.readEnable = '0') then
               -- Reset the counters
               v.waddr := (others => '0');
               v.raddr := (others => '0');
               -- Next state
               v.state := IDLE_S;
            end if;
         ----------------------------------------------------------------------
         when RX_ADDR_S =>
            -- Ready to readout the FIFO
            v.rxSlave.tReady := '1';
            -- Check for FIFO data
            if rxMaster.tValid = '1' then
               -- Set the address
               v.addr  := rxMaster.tData(31 downto 0);
               -- Reset the counter
               v.raddr := (others => '0');
               -- Next state
               v.state := RX_LOAD_S;
            end if;
         ----------------------------------------------------------------------
         when RX_LOAD_S =>
            -- Ready to readout the FIFO
            v.rxSlave.tReady := '1';
            -- Check for FIFO data
            if rxMaster.tValid = '1' then
               -- Write the stream data to RAM
               v.we     := '1';
               v.waddr  := r.raddr;
               v.ramDin := rxMaster.tData(7 downto 0);
               -- Increment the counter
               v.raddr  := r.raddr + 1;
               -- Check for valid completion
               if (rxMaster.tLast = '1') then
                  -- Reset the counter
                  v.raddr          := (others => '0');
                  -- Done reading out the FIFO
                  v.rxSlave.tReady := '0';
                  -- Check for EOFE
                  if ssiGetUserEofe(AXI_CONFIG_C, rxMaster) = '1' then
                     -- Next state
                     v.state := IDLE_S;
                  elsif r.raddr /= 255 then
                     -- Next state
                     v.state := IDLE_S;
                  else
                     -- Set the flag
                     v.bufProgEn := '1';
                     -- Next state
                     v.state     := BUF_WRITE_MODE_S;
                  end if;
               -- No EOF but reached counter size
               elsif r.raddr = 255 then
                  -- Reset the counter
                  v.raddr          := (others => '0');
                  -- Done reading out the FIFO
                  v.rxSlave.tReady := '0';
                  -- Next state
                  v.state          := IDLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when BUF_WRITE_MODE_S =>
            -- Set the flag
            v.RnW     := '1';
            -- Increment the counter
            v.fastCnt := r.fastCnt + 1;
            -- Check the counter
            case r.fastCnt is
               when x"0" =>
                  -- Poll the status register
                  v.cmd      := x"05";
                  v.xferSize := toSlv(1, 9);
               when x"1" =>
                  -- Check if busy
                  if r.status(0) = '1' then
                     -- Poll the status register
                     v.cmd      := x"05";
                     v.xferSize := toSlv(1, 9);
                     -- Set the counter
                     v.fastCnt  := r.fastCnt;
                  else
                     -- Set the write enable register
                     v.cmd      := x"06";
                     v.xferSize := toSlv(0, 9);
                  end if;
               when x"2" =>
                  -- Poll the status register
                  v.cmd      := x"05";
                  v.xferSize := toSlv(1, 9);
               when x"3" =>
                  -- Check if busy
                  if r.status(0) = '1' then
                     -- Poll the status register
                     v.cmd      := x"05";
                     v.xferSize := toSlv(1, 9);
                     -- Set the counter
                     v.fastCnt  := r.fastCnt;
                  else
                     -- Set the write command
                     v.cmd := x"02";
                     -- Check address mode
                     if r.addr32BitMode = '1' then
                        -- 32-bit Address Mode
                        v.xferSize := toSlv(260, 9);
                     else
                        -- 24-bit Address Mode
                        v.xferSize := toSlv(259, 9);
                     end if;
                  end if;
               when x"4" =>
                  -- Poll the status register
                  v.cmd      := x"05";
                  v.xferSize := toSlv(1, 9);
               when others =>
                  -- Set the counter
                  v.fastCnt := r.fastCnt;
                  -- Check if busy
                  if r.status(0) = '1' then
                     -- Poll the status register
                     v.cmd      := x"05";
                     v.xferSize := toSlv(1, 9);
                  else
                     -- Set the write enable register
                     v.cmd       := x"04";
                     v.xferSize  := toSlv(0, 9);
                     -- Reset the flag
                     v.bufProgEn := '0';
                     -- Reset the counter
                     v.fastCnt   := x"0";
                  end if;
            end case;
            -- Check address mode
            if r.addr32BitMode = '1' then
               -- 32-bit Address Mode
               v.raddr := PRESET_32BIT_ADDR_C;
            else
               -- 24-bit Address Mode
               v.raddr := PRESET_24BIT_ADDR_C;
            end if;
            -- Next state
            v.state := SCK_LOW_S;
         ----------------------------------------------------------------------
         when SCK_LOW_S =>
            -- Assert the chip select
            v.csL := '0';
            -- Serial Clock low phase
            v.sck := '0';
            -- Check if the RAM data is updated
            if r.rd = "00" then
               -- 32-bit Address Mode
               if r.addr32BitMode = '1' then
                  if r.cnt = 0 then
                     v.mosi := r.cmd(7-r.bitPntr);
                  elsif r.cnt = 1 then
                     v.mosi := MEM_ADDR_MASK_G(31-r.bitPntr) or r.addr(31-r.bitPntr);
                  elsif r.cnt = 2 then
                     v.mosi := MEM_ADDR_MASK_G(23-r.bitPntr) or r.addr(23-r.bitPntr);
                  elsif r.cnt = 3 then
                     v.mosi := MEM_ADDR_MASK_G(15-r.bitPntr) or r.addr(15-r.bitPntr);
                  elsif r.cnt = 4 then
                     v.mosi := MEM_ADDR_MASK_G(7-r.bitPntr) or r.addr(7-r.bitPntr);
                  else
                     v.mosi := ramDout(7-r.bitPntr);
                  end if;
               -- 24-bit Address Mode
               else
                  if r.cnt = 0 then
                     v.mosi := r.cmd(7-r.bitPntr);
                  elsif r.cnt = 1 then
                     v.mosi := MEM_ADDR_MASK_G(23-r.bitPntr) or r.addr(23-r.bitPntr);
                  elsif r.cnt = 2 then
                     v.mosi := MEM_ADDR_MASK_G(15-r.bitPntr) or r.addr(15-r.bitPntr);
                  elsif r.cnt = 3 then
                     v.mosi := MEM_ADDR_MASK_G(7-r.bitPntr) or r.addr(7-r.bitPntr);
                  else
                     v.mosi := ramDout(7-r.bitPntr);
                  end if;
               end if;
               -- Increment the counter
               v.sckCnt := r.sckCnt + 1;
               -- Check the counter value
               if r.sckCnt = SCK_HALF_PERIOD_C then
                  -- Reset the counter
                  v.sckCnt := 0;
                  -- Next state
                  v.state  := SCK_HIGH_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when SCK_HIGH_S =>
            -- Serial Clock high phase
            v.sck    := '1';
            -- Increment the counter
            v.sckCnt := r.sckCnt + 1;
            -- Check the counter value
            if r.sckCnt = SCK_HALF_PERIOD_C then
               -- Set the default state
               v.state              := SCK_LOW_S;
               -- Reset the counter
               v.sckCnt             := 0;
               -- Update the ram data bus
               v.ramDin(7 downto 1) := r.ramDin(6 downto 0);
               v.ramDin(0)          := miso;
               -- Increment the counter
               v.bitPntr            := r.bitPntr + 1;
               -- Check the counter value
               if r.bitPntr = 7 then
                  -- Reset the counter
                  v.bitPntr := 0;
                  -- Write to RAM
                  v.we      := not(r.RnW);
                  v.waddr   := r.raddr;
                  -- Increment the counters
                  v.raddr   := r.raddr + 1;
                  v.cnt     := r.cnt + 1;
                  -- Set the flag
                  v.rd(0)   := '1';
                  -- Check the xfer size
                  if r.cnt = r.xferSize then
                     -- Reset the counter
                     v.cnt   := (others => '0');
                     -- Next state
                     v.state := MIN_CS_WIDTH_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when MIN_CS_WIDTH_S =>
            -- De-assert the chip select
            v.csL    := '1';
            -- Serial Clock low phase
            v.sck    := '0';
            -- Increment the counter
            v.sckCnt := r.sckCnt + 1;
            -- Check counter
            if r.sckCnt = MIN_CS_WIDTH_C then
               -- Latch the last write value
               v.status := r.ramDin;
               -- Reset the counter
               v.sckCnt := 0;
               -- Check for TX streaming
               if r.txStream = '1' then
                  -- Reset the counter
                  v.raddr := (others => '1');
                  -- Set the flag
                  v.rd(0) := '1';
                  -- Next State
                  v.state := BUF_READ_MODE_S;
               elsif r.bufProgEn = '1' then
                  -- Next State
                  v.state := BUF_WRITE_MODE_S;
               else
                  -- Next State
                  v.state := IDLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when BUF_READ_MODE_S =>
            -- Check the TX FIFO status 
            if (txCtrl.pause = '0') and (r.rd = "00") then
               -- Set the flag
               v.rd(0)           := '1';
               -- Increment the counter
               v.raddr           := r.raddr + 1;
               -- Write to the TX FIFO
               v.txMaster.tValid := '1';
               -- Check for SOF
               if r.raddr = "111111111" then
                  ssiSetUserSof(AXI_CONFIG_C, v.txMaster, '1');
                  v.txMaster.tData(31 downto 0) := r.addr;
               else
                  v.txMaster.tData(31 downto 8) := (others => '0');
                  v.txMaster.tData(7 downto 0)  := ramDout;
               end if;
               -- Check for EOF
               if r.raddr = 255 then
                  -- Reset the counter
                  v.raddr          := (others => '0');
                  -- Set the EOF flag
                  v.txMaster.tLast := '1';
                  -- Next State
                  v.state          := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if axiRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;

      csL  <= r.csL;
      sck  <= r.sck;
      mosi <= r.mosi;
      
   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   RX_FIFO : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         CASCADE_SIZE_G      => 1,
         BRAM_EN_G           => false,
         XIL_DEVICE_G        => "7SERIES",
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 4,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 8,
         SLAVE_AXI_CONFIG_G  => AXI_CONFIG_G,
         MASTER_AXI_CONFIG_G => AXI_CONFIG_C)     
      port map (
         -- Slave Port
         sAxisClk    => axiClk,
         sAxisRst    => axiRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         -- Master Port
         mAxisClk    => axiClk,
         mAxisRst    => axiRst,
         mAxisMaster => rxMaster,
         mAxisSlave  => r.rxSlave);      

   TX_FIFO : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         SLAVE_READY_EN_G    => false,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         CASCADE_SIZE_G      => 1,
         BRAM_EN_G           => false,
         XIL_DEVICE_G        => "7SERIES",
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 4,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 8,
         SLAVE_AXI_CONFIG_G  => AXI_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXI_CONFIG_G)     
      port map (
         -- Slave Port
         sAxisClk    => axiClk,
         sAxisRst    => axiRst,
         sAxisMaster => r.txMaster,
         sAxisCtrl   => txCtrl,
         -- Master Port
         mAxisClk    => axiClk,
         mAxisRst    => axiRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);     

   SimpleDualPortRam_Inst : entity work.SimpleDualPortRam
      generic map(
         BRAM_EN_G    => true,
         DATA_WIDTH_G => 8,
         ADDR_WIDTH_G => 9)
      port map (
         -- Port A
         clka  => axiClk,
         wea   => r.we,
         addra => r.waddr,
         dina  => r.ramDin,
         -- Port B
         clkb  => axiClk,
         addrb => r.raddr,
         doutb => ramDout);          

end rtl;
