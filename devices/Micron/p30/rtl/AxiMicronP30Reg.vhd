-------------------------------------------------------------------------------
-- File       : AxiMicronP30Reg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-10-21
-- Last update: 2017-03-24
-------------------------------------------------------------------------------
-- Description: This controller is designed around the Micron PC28F FLASH IC.
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

library unisim;
use unisim.vcomponents.all;

entity AxiMicronP30Reg is
   generic (
      TPD_G            : time                := 1 ns;
      MEM_ADDR_MASK_G  : slv(31 downto 0)    := x"00000000";
      AXI_CLK_FREQ_G   : real                := 200.0E+6;  -- units of Hz
      PIPE_STAGES_G    : natural             := 0;
      AXI_CONFIG_G     : AxiStreamConfigType := ssiAxiStreamConfig(4);
      AXI_ERROR_RESP_G : slv(1 downto 0)     := AXI_RESP_SLVERR_C);
   port (
      -- FLASH Interface 
      flashAddr      : out slv(30 downto 0);
      flashAdv       : out sl;
      flashClk       : out sl;
      flashRstL      : out sl;
      flashCeL       : out sl;
      flashOeL       : out sl;
      flashWeL       : out sl;
      flashTri       : out sl;
      flashDin       : out slv(15 downto 0);
      flashDout      : in  slv(15 downto 0);
      -- AXI-Lite Register Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- AXI Streaming Interface (Optional)
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
      sAxisMaster    : in  AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      sAxisSlave     : out AxiStreamSlaveType;
      -- Clocks and Resets
      axiClk         : in  sl;
      axiRst         : in  sl);
end AxiMicronP30Reg;

architecture rtl of AxiMicronP30Reg is

   constant HALF_CYCLE_PERIOD_C : real := 128.0E-9;  -- units of seconds

   constant HALF_CYCLE_FREQ_C : real := (1.0 / HALF_CYCLE_PERIOD_C);  -- units of Hz

   constant MAX_CNT_C : natural := getTimeRatio(AXI_CLK_FREQ_G, HALF_CYCLE_FREQ_C);

   constant AXI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);  -- 32-bit interface

   type stateType is (
      IDLE_S,
      RX_ADDR_S,
      RX_SIZE_S,
      RX_DATA_S,
      BUF_WRITE_MODE_S,
      BUF_READ_MODE_S,
      FAST_MODE_S,
      CMD_LOW_S,
      CMD_HIGH_S,
      WAIT_S,
      DATA_LOW_S,
      DATA_HIGH_S);

   type RegType is record
      -- PROM Control Signals
      tristate      : sl;
      ceL           : sl;
      oeL           : sl;
      RnW           : sl;
      weL           : sl;
      cnt           : natural range 0 to (MAX_CNT_C+1);
      din           : slv(15 downto 0);
      dataReg       : slv(15 downto 0);
      addr          : slv(30 downto 0);
      wrCmd         : slv(15 downto 0);
      wrData        : slv(15 downto 0);
      test          : slv(31 downto 0);
      -- Fast Register Program Signals
      fastProgEn    : sl;
      fastData      : slv(15 downto 0);
      fastCnt       : slv(3 downto 0);
      -- RAM Buffer Signals
      ramWe         : sl;
      ramAddr       : slv(7 downto 0);
      ramDin        : slv(15 downto 0);
      -- Buffered Program Signals
      bufProgEn     : sl;
      baseAddr      : slv(30 downto 0);
      size          : slv(7 downto 0);
      axisCnt       : slv(7 downto 0);
      -- Buffered Read Signals
      bufReadEn     : sl;
      bufReadCnt    : slv(7 downto 0);
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
      -- PROM Control Signals
      tristate      => '1',
      ceL           => '1',
      oeL           => '1',
      RnW           => '1',
      weL           => '1',
      cnt           => 0,
      din           => x"0000",
      dataReg       => x"0000",
      addr          => (others => '0'),
      wrCmd         => (others => '0'),
      wrData        => (others => '0'),
      test          => (others => '0'),
      -- Fast Register Program Signals
      fastProgEn    => '0',
      fastData      => (others => '0'),
      fastCnt       => (others => '0'),
      -- RAM Buffer Signals
      ramWe         => '0',
      ramAddr       => (others => '0'),
      ramDin        => (others => '0'),
      -- Buffered Program Signals
      bufProgEn     => '0',
      baseAddr      => (others => '0'),
      size          => (others => '0'),
      axisCnt       => (others => '0'),
      -- Buffered Read Signals      
      bufReadEn     => '0',
      bufReadCnt    => (others => '0'),
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

   signal ramDout : slv(15 downto 0);

   signal rxMaster : AxiStreamMasterType;
   signal txCtrl   : AxiStreamCtrlType;

   -- attribute dont_touch             : string;
   -- attribute dont_touch of r        : signal is "true";
   -- attribute dont_touch of rxMaster : signal is "true";
   -- attribute dont_touch of ramDout  : signal is "true";

begin

   comb : process (axiReadMaster, axiRst, axiWriteMaster, flashDout, r,
                   ramDout, rxMaster, txCtrl) is
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
      variable i            : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the strobing signals
      v.ceL            := '1';
      v.oeL            := '1';
      v.weL            := '1';
      v.tristate       := '1';
      axiWriteResp     := AXI_RESP_OK_C;
      axiReadResp      := AXI_RESP_OK_C;
      v.rxSlave.tReady := '0';
      v.ramWe          := '0';
      ssiResetFlags(v.txMaster);

      -- Set the tKeep = 32-bit transfers
      v.txMaster.tKeep := x"00FF";

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for a read request            
            if (axiStatus.readEnable = '1') then
               -- Reset the register
               v.axiReadSlave.rdata := (others => '0');
               -- Decode address and assign read data
               case (axiReadMaster.araddr(7 downto 0)) is
                  when x"00" =>
                     -- Get the opCode bus
                     v.axiReadSlave.rdata(31 downto 16) := r.wrCmd;
                     -- Get the input data bus
                     v.axiReadSlave.rdata(15 downto 0)  := r.wrData;
                  when x"04" =>
                     -- Get the RnW
                     v.axiReadSlave.rdata(31)          := r.RnW;
                     -- Get the address bus
                     v.axiReadSlave.rdata(30 downto 0) := r.addr;
                  when x"08" =>
                     -- Get the output data bus
                     v.axiReadSlave.rdata(15 downto 0) := r.dataReg;
                  when x"0C" =>
                     v.axiReadSlave.rdata := r.test;
                  when x"10" =>
                     -- Get the address bus
                     v.axiReadSlave.rdata(30 downto 0) := r.addr;
                  when others =>
                     axiReadResp := AXI_ERROR_RESP_G;
               end case;
               -- Send AXI-Lite Response
               axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
            -- Check for a write request
            elsif (axiStatus.writeEnable = '1') then
               -- Decode address and perform write
               case (axiWriteMaster.awaddr(7 downto 0)) is
                  when x"00" =>
                     -- Set the opCode bus
                     v.wrCmd  := axiWriteMaster.wdata(31 downto 16);
                     -- Set the input data bus
                     v.wrData := axiWriteMaster.wdata(15 downto 0);
                  when x"04" =>
                     -- Set the RnW
                     v.RnW   := axiWriteMaster.wdata(31);
                     -- Set the address bus
                     v.addr  := axiWriteMaster.wdata(30 downto 0);
                     -- Next state
                     v.state := CMD_LOW_S;
                  when x"0C" =>
                     v.test := axiWriteMaster.wdata;
                  when x"10" =>
                     -- Set the address bus
                     v.addr := axiWriteMaster.wdata(30 downto 0);
                  when x"14" =>
                     -- Set the flag
                     v.fastProgEn := '1';
                     -- Set the data bus
                     v.fastData   := axiWriteMaster.wdata(15 downto 0);
                     -- Next state
                     v.state      := FAST_MODE_S;
                  when x"18" =>
                     -- Set the flag
                     v.bufReadEn := '1';
                     -- Set the read mode
                     v.RnW       := '1';
                     -- Set the address buses
                     v.addr      := axiWriteMaster.wdata(30 downto 0);
                     -- Next state
                     v.state     := CMD_LOW_S;
                  when others =>
                     axiWriteResp := AXI_ERROR_RESP_G;
               end case;
               -- Send AXI-Lite response
               axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
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
         when RX_ADDR_S =>
            -- Ready to readout the FIFO
            v.rxSlave.tReady := '1';
            -- Check for FIFO data
            if rxMaster.tValid = '1' then
               -- Set the base address
               v.baseAddr := rxMaster.tData(30 downto 0);
               -- Next state
               v.state    := RX_SIZE_S;
            end if;
         ----------------------------------------------------------------------
         when RX_SIZE_S =>
            -- Ready to readout the FIFO
            v.rxSlave.tReady := '1';
            -- Check for FIFO data
            if rxMaster.tValid = '1' then
               -- Set the burst size
               v.size := rxMaster.tData(7 downto 0);
               -- Check for packet length error detected
               if rxMaster.tLast = '1' then
                  -- Done reading out the FIFO
                  v.rxSlave.tReady := '0';
                  -- Next state
                  v.state          := IDLE_S;
               else
                  -- Next state
                  v.state := RX_DATA_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when RX_DATA_S =>
            -- Ready to readout the FIFO
            v.rxSlave.tReady := '1';
            -- Check for FIFO data
            if rxMaster.tValid = '1' then
               -- Write the stream data to RAM
               v.ramWe   := '1';
               v.ramAddr := r.axisCnt;
               v.ramDin  := rxMaster.tData(15 downto 0);
               -- Increment the counter
               v.axisCnt := r.axisCnt + 1;
               -- Check for valid completion
               if (rxMaster.tLast = '1') then
                  -- Reset the counter
                  v.axisCnt        := (others => '0');
                  -- Done reading out the FIFO
                  v.rxSlave.tReady := '0';
                  -- Check for EOFE
                  if ssiGetUserEofe(AXI_CONFIG_C, rxMaster) = '1' then
                     -- Next state
                     v.state := IDLE_S;
                  elsif r.axisCnt /= r.size then
                     -- Next state
                     v.state := IDLE_S;
                  else
                     -- Set the flag
                     v.bufProgEn := '1';
                     -- Next state
                     v.state     := BUF_WRITE_MODE_S;
                  end if;
               -- No EOF but reached counter size
               elsif r.axisCnt = r.size then
                  -- Reset the counter
                  v.axisCnt        := (others => '0');
                  -- Done reading out the FIFO
                  v.rxSlave.tReady := '0';
                  -- Next state
                  v.state          := IDLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when BUF_WRITE_MODE_S =>
            -- Check the counter
            case r.fastCnt is
               when x"0" =>
                  -- Increment the counter
                  v.fastCnt := x"1";
                  -- Reset the RAM address 
                  v.ramAddr := (others => '0');
                  -- Set the address bus
                  v.addr    := r.baseAddr;
                  -- Send the "unlock the block" command
                  v.RnW     := '0';
                  v.wrCmd   := x"0060";
                  v.wrData  := x"00D0";
               when x"1" =>
                  -- Increment the counter
                  v.fastCnt := x"2";
                  -- Send the "reset the status register" command
                  v.RnW     := '0';
                  v.wrCmd   := x"0050";
                  v.wrData  := x"0050";
               when x"2" =>
                  -- Increment the counter
                  v.fastCnt             := x"3";
                  -- Send the "buffer program command and size" command
                  v.RnW                 := '0';
                  v.wrCmd               := x"00E8";
                  v.wrData(15 downto 8) := (others => '0');
                  v.wrData(7 downto 0)  := r.size;
               when x"3" =>
                  -- Load the buffer 
                  v.RnW     := '1';
                  v.wrCmd   := ramDout;  -- Load information via the command word                   
                  -- Increment the counter
                  v.ramAddr := r.ramAddr + 1;
                  -- Check if first sample
                  if r.ramAddr = 0 then
                     -- Set the address bus
                     v.addr := r.baseAddr;
                  else
                     -- Increment the address
                     v.addr := r.addr + 1;
                  end if;
                  -- Check the counter size
                  if r.ramAddr = r.size then
                     -- Reset the RAM address 
                     v.ramAddr := (others => '0');
                     -- Increment the counter
                     v.fastCnt := x"4";
                  end if;
               -- Get the status register
               when x"4" =>
                  -- Increment the counter
                  v.fastCnt := x"5";
                  -- Set the address bus
                  v.addr    := r.baseAddr;
                  -- Send the "Confirm buffer programming" command
                  v.RnW     := '1';
                  v.wrCmd   := x"00D0";  -- Load information via the command word   
               -- Get the status register
               when x"5" =>
                  -- Increment the counter
                  v.fastCnt := x"6";
                  -- Set the address bus
                  v.addr    := r.baseAddr;
                  -- Get the status register
                  v.RnW     := '1';
                  v.wrCmd   := x"0070";
               when others =>
                  -- Set the address bus
                  v.addr := r.baseAddr;
                  -- Check if FLASH is still busy
                  if r.dataReg(7) = '0' then
                     -- Set the counter
                     v.fastCnt := x"6";
                     -- Get the status register
                     v.RnW     := '1';
                     v.wrCmd   := x"0070";
                  -- Check for programming failure
                  elsif r.dataReg(4) = '1' then
                     -- Set the counter
                     v.fastCnt := x"1";
                     -- Send the "unlock the block" command
                     v.RnW     := '0';
                     v.wrCmd   := x"0060";
                     v.wrData  := x"00D0";
                  else
                     -- Send the "lock the block" command
                     v.RnW       := '0';
                     v.wrCmd     := x"0060";
                     v.wrData    := x"0001";
                     -- Reset the flag
                     v.bufProgEn := '0';
                     -- Reset the counter
                     v.fastCnt   := x"0";
                  end if;
            end case;
            -- Next state
            v.state := CMD_LOW_S;
         ----------------------------------------------------------------------
         when FAST_MODE_S =>
            -- Increment the counter
            v.fastCnt := r.fastCnt + 1;
            -- Check the counter
            case r.fastCnt is
               when x"0" =>
                  -- Send the "unlock the block" command
                  v.RnW    := '0';
                  v.wrCmd  := x"0060";
                  v.wrData := x"00D0";
               when x"1" =>
                  -- Send the "reset the status register" command
                  v.RnW    := '0';
                  v.wrCmd  := x"0050";
                  v.wrData := x"0050";
               when x"2" =>
                  -- Send the "program" command
                  v.RnW    := '0';
                  v.wrCmd  := x"0040";
                  v.wrData := r.fastData;
               -- Get the status register
               when x"3" =>
                  v.RnW   := '1';
                  v.wrCmd := x"0070";
               when others =>
                  -- Check if FLASH is still busy
                  if r.dataReg(7) = '0' then
                     -- Set the counter
                     v.fastCnt := x"4";
                     -- Get the status register
                     v.RnW     := '1';
                     v.wrCmd   := x"0070";
                  -- Check for programming failure
                  elsif r.dataReg(4) = '1' then
                     -- Set the counter
                     v.fastCnt := x"1";
                     -- Send the "unlock the block" command
                     v.RnW     := '0';
                     v.wrCmd   := x"0060";
                     v.wrData  := x"00D0";
                  else
                     -- Send the "lock the block" command
                     v.RnW        := '0';
                     v.wrCmd      := x"0060";
                     v.wrData     := x"0001";
                     -- Reset the flag
                     v.fastProgEn := '0';
                     -- Reset the counter
                     v.fastCnt    := x"0";
                  end if;
            end case;
            -- Next state
            v.state := CMD_LOW_S;
         ----------------------------------------------------------------------
         when BUF_READ_MODE_S =>
            -- Check the TX FIFO status 
            if txCtrl.pause = '0' then
               -- Write to the FIFO
               v.txMaster.tValid              := '1';
               v.txMaster.tData(31 downto 16) := x"0000";
               v.txMaster.tData(15 downto 0)  := r.dataReg;
               -- Increment the counter
               v.bufReadCnt                   := r.bufReadCnt + 1;
               -- Check the counter
               if r.bufReadCnt = x"FF" then
                  -- Reset the counter
                  v.bufReadCnt     := (others => '0');
                  -- Set the EOF flag
                  v.txMaster.tLast := '1';
                  -- Reset the flag
                  v.bufReadEn      := '0';
                  -- Next state
                  v.state          := IDLE_S;
               else
                  -- Increment the address
                  v.addr  := r.addr + 1;
                  -- Next state
                  v.state := CMD_LOW_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when CMD_LOW_S =>
            v.ceL      := '0';
            v.oeL      := '1';
            v.weL      := '0';
            v.tristate := '0';
            v.din      := r.wrCmd;
            -- Increment the counter
            v.cnt      := r.cnt + 1;
            -- Check the counter 
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt   := 0;
               -- Next state
               v.state := CMD_HIGH_S;
            end if;
         ----------------------------------------------------------------------
         when CMD_HIGH_S =>
            v.ceL      := '1';
            v.oeL      := '1';
            v.weL      := '1';
            v.tristate := '0';
            v.din      := r.wrCmd;
            -- Increment the counter
            v.cnt      := r.cnt + 1;
            -- Check the counter 
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt   := 0;
               -- Next state
               v.state := WAIT_S;
            end if;
         ----------------------------------------------------------------------
         when WAIT_S =>
            v.ceL      := '1';
            v.oeL      := '1';
            v.weL      := '1';
            v.tristate := '1';
            v.din      := r.wrData;
            -- Increment the counter
            v.cnt      := r.cnt + 1;
            -- Check the counter 
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt   := 0;
               -- Next state
               v.state := DATA_LOW_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_LOW_S =>
            v.ceL      := '0';
            v.oeL      := not(r.RnW);
            v.weL      := r.RnW;
            v.tristate := r.RnW;
            v.din      := r.wrData;
            -- Increment the counter
            v.cnt      := r.cnt + 1;
            -- Check the counter 
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt     := 0;
               --latch the data bus value
               v.dataReg := flashDout;
               -- Next state
               v.state   := DATA_HIGH_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_HIGH_S =>
            v.ceL      := '1';
            v.oeL      := '1';
            v.weL      := '1';
            v.tristate := r.RnW;
            v.din      := r.wrData;
            if txCtrl.pause = '0' then
               -- Increment the counter
               v.cnt := r.cnt + 1;
               -- Check the counter 
               if r.cnt = MAX_CNT_C then
                  -- Reset the counter
                  v.cnt := 0;
                  -- Check for buffered program command mode
                  if r.bufProgEn = '1' then
                     -- Next state
                     v.state := BUF_WRITE_MODE_S;
                  -- Check for fast program command mode
                  elsif r.fastProgEn = '1' then
                     -- Next state
                     v.state := FAST_MODE_S;
                  -- Check for buffered read command mode
                  elsif r.bufReadEn = '1' then
                     -- Check for SOF
                     if r.bufReadCnt = 0 then
                        -- Write to the FIFO
                        v.txMaster.tValid             := '1';
                        ssiSetUserSof(AXI_CONFIG_C, v.txMaster, '1');
                        v.txMaster.tData(31)          := '0';
                        v.txMaster.tData(30 downto 0) := r.addr;
                     end if;
                     -- Next state
                     v.state := BUF_READ_MODE_S;
                  else
                     -- Next state
                     v.state := IDLE_S;
                  end if;
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
      for i in 0 to 30 loop
         flashAddr(i) <= r.addr(i) or MEM_ADDR_MASK_G(i);
      end loop;
      flashAdv      <= '0';
      flashClk      <= '1';
      flashRstL     <= not(axiRst);
      flashCeL      <= r.ceL;
      flashOeL      <= r.oeL;
      flashWeL      <= r.weL;
      flashDin      <= r.din;
      flashTri      <= r.tristate;
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;

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
         DATA_WIDTH_G => 16,
         ADDR_WIDTH_G => 8)
      port map (
         -- Port A
         clka  => axiClk,
         wea   => r.ramWe,
         addra => r.ramAddr,
         dina  => r.ramDin,
         -- Port B
         clkb  => axiClk,
         addrb => r.ramAddr,
         doutb => ramDout);

end rtl;
