-------------------------------------------------------------------------------
-- File       : AxiMicronN25QReg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2017-11-09
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

entity AxiMicronN25QReg is
   generic (
      TPD_G            : time             := 1 ns;
      MEM_ADDR_MASK_G  : slv(31 downto 0) := x"00000000";
      AXI_CLK_FREQ_G   : real             := 200.0E+6;  -- units of Hz
      SPI_CLK_FREQ_G   : real             := 25.0E+6;   -- units of Hz
      AXI_ERROR_RESP_G : slv(1 downto 0)  := AXI_RESP_SLVERR_C);
   port (
      -- FLASH Memory Ports
      csL            : out sl;
      sck            : out sl;
      mosi           : out sl;
      miso           : in  sl;
      -- Shared SPI Interface 
      busyIn         : in  sl := '0';
      busyOut        : out sl;
      -- AXI-Lite Register Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Global Signals
      axiClk         : in  sl;
      axiRst         : in  sl);
end AxiMicronN25QReg;

architecture rtl of AxiMicronN25QReg is

   constant DOUBLE_SCK_FREQ_C : real    := SPI_CLK_FREQ_G * 2.0;
   constant SCK_HALF_PERIOD_C : natural := (getTimeRatio(AXI_CLK_FREQ_G, DOUBLE_SCK_FREQ_C))-1;
   constant MIN_CS_WIDTH_C    : natural := (getTimeRatio(AXI_CLK_FREQ_G, 2.0E+7));
   constant MAX_SCK_CNT_C     : natural := ite((SCK_HALF_PERIOD_C > MIN_CS_WIDTH_C), SCK_HALF_PERIOD_C, MIN_CS_WIDTH_C);

   constant PRESET_32BIT_ADDR_C : slv(8 downto 0) := "111111011";
   constant PRESET_24BIT_ADDR_C : slv(8 downto 0) := "111111100";

   type StateType is (
      IDLE_S,
      WORD_WRITE_S,
      WORD_READ_S,
      SCK_LOW_S,
      SCK_HIGH_S,
      MIN_CS_WIDTH_S);

   type RegType is record
      test          : slv(31 downto 0);
      wrData        : slv(31 downto 0);
      rdData        : slv(31 downto 0);
      addr          : slv(31 downto 0);
      addr32BitMode : sl;
      cmd           : slv(7 downto 0);
      status        : slv(7 downto 0);
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
      busy          : sl;
      csL           : sl;
      sck           : sl;
      mosi          : sl;
      sckCnt        : natural range 0 to MAX_SCK_CNT_C;
      bitPntr       : natural range 0 to 7;
      -- AXI-Lite Signals
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
      -- Status Machine
      state         : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      test          => (others => '0'),
      wrData        => (others => '0'),
      rdData        => (others => '0'),
      addr          => (others => '0'),
      addr32BitMode => '0',
      cmd           => (others => '0'),
      status        => (others => '0'),
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
      busy          => '0',
      csL           => '1',
      sck           => '0',
      mosi          => '0',
      sckCnt        => 0,
      bitPntr       => 0,
      -- AXI-Lite Signals
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      -- Status Machine
      state         => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ramDout : slv(7 downto 0);

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";

begin

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiRst, axiWriteMaster, busyIn, miso, r,
                   ramDout) is
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset the strobing signals
      axiWriteResp := AXI_RESP_OK_C;
      axiReadResp  := AXI_RESP_OK_C;
      v.we         := '0';

      -- Shift register
      v.rd(1) := r.rd(0);
      v.rd(0) := '0';

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the signals in IDLE state
            v.csL   := '1';
            v.sck   := '0';
            v.cnt   := (others => '0');
            v.waddr := (others => '0');
            v.raddr := (others => '0');
            -- Check for a write request
            if (axiStatus.writeEnable = '1') then
               if axiWriteMaster.awaddr(9) = '1' then
                  -- Latch the write data and write address
                  v.waddr  := axiWriteMaster.awaddr(8 downto 0);
                  v.raddr  := axiWriteMaster.awaddr(8 downto 0);
                  v.wrData := axiWriteMaster.wdata;
                  -- Next state
                  v.state  := WORD_WRITE_S;
               elsif (busyIn = '0') then
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
               elsif (busyIn = '0') then
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
               v.rd(0)               := '1';
               -- Shift the data
               v.rdData(31 downto 8) := r.rdData(23 downto 0);
               v.rdData(7 downto 0)  := ramDout;
               -- Increment the counters
               v.raddr               := r.raddr + 1;
               v.cnt                 := r.cnt + 1;
               -- Check the counter size
               if r.cnt = 3 then
                  -- Reset the counter
                  v.cnt                := (others => '0');
                  -- Forward the read data
                  v.axiReadSlave.rdata := v.rdData;
                  -- Send AXI-Lite Response
                  axiSlaveReadResponse(v.axiReadSlave);
                  -- Next state
                  v.state              := IDLE_S;
               end if;
            end if;
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
               -- Next State
               v.state  := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      if (r.state = IDLE_S) then
         -- Reset the flag
         v.busy := '0';
      else
         -- Set the flag
         v.busy := '1';
      end if;

      -- Synchronous Reset
      if axiRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;

      csL     <= r.csL;
      sck     <= r.sck;
      mosi    <= r.mosi;
      busyOut <= r.busy;

   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_Ram : entity work.SimpleDualPortRam
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
