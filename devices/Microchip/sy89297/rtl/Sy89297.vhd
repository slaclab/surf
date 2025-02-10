-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: This controller is designed around the Microchip SY89297UMH
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;

entity Sy89297 is
   generic (
      TPD_G        : time    := 1 ns;
      SIMULATION_G : boolean := false);
   port (
      -- Delay control signals
      enableL         : out sl;
      enaL            : out sl;
      enbL            : out sl;
      sdata           : out sl;
      sclk            : out sl;
      sload           : out sl;
      -- AXI-Lite Interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end Sy89297;

architecture rtl of Sy89297 is

   type StateType is (
      IDLE_S,
      SEND_DATA_S,
      SLOAD_S);

   type RegType is record
      delayA         : slv(9 downto 0);
      delayB         : slv(9 downto 0);
      busy           : sl;
      cnt            : natural range 0 to 20;
      shiftReg       : slv(19 downto 0);
      -- Serial Clock Generation
      sclkEn         : sl;
      sclkCnt        : slv(7 downto 0);
      sckHalfCycle   : slv(7 downto 0);
      -- I/O Signals
      sclk           : sl;
      sload          : sl;
      -- AXIL and state machine
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      state          : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      delayA         => (others => '0'),
      delayB         => (others => '0'),
      busy           => '0',
      cnt            => 0,
      shiftReg       => (others => '0'),
      -- Serial Clock Generation
      sclkEn         => '0',
      sclkCnt        => (others => '0'),
      sckHalfCycle   => ite(SIMULATION_G, x"00", x"0F"),
      -- I/O Signals
      sclk           => '0',
      sload          => '1',
      -- AXIL and state machine
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      state          => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axilReadMaster, axilRst, axilWriteMaster, r) is
      variable v             : RegType;
      variable axilStatus    : AxiLiteStatusType;
      variable axilWriteResp : slv(1 downto 0);
      variable axilReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      axilWriteResp := AXI_RESP_OK_C;
      axilReadResp  := AXI_RESP_OK_C;

      -- Check for timeout
      if r.sclkCnt = 0 then

         -- Check if enabled
         if (r.sclkEn = '1') then
            -- Set the flag
            v.sclk := not(r.sclk);
         end if;

         -- Preset counter
         v.sclkCnt := r.sckHalfCycle;

      else
         -- Decreament counter
         v.sclkCnt := r.sclkCnt - 1;
      end if;

      -- Determine the transaction type
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the signals in IDLE state
            v.busy    := '0';
            v.sload   := '1';
            v.sclk    := '0';
            v.sclkEn  := '0';
            v.sclkCnt := r.sckHalfCycle;
            v.cnt     := 0;

            -- Check for a write request
            if (axilStatus.writeEnable = '1') then

               -- Decode address and perform write
               case (axilWriteMaster.awaddr(3 downto 0)) is
                  --------------------------------------------------------
                  when x"0" =>
                     -- Set the value
                     v.delayA := axilWriteMaster.wdata(9 downto 0);
                     -- Set the flags
                     v.busy   := '1';
                     v.sload  := '0';
                     v.sclkEn := '1';
                     -- Next state
                     v.state  := SEND_DATA_S;
                  --------------------------------------------------------
                  when x"4" =>
                     -- Set the value
                     v.delayB := axilWriteMaster.wdata(9 downto 0);
                     -- Set the flags
                     v.busy   := '1';
                     v.sload  := '0';
                     v.sclkEn := '1';
                     -- Next state
                     v.state  := SEND_DATA_S;
                  --------------------------------------------------------
                  when x"C" =>
                     -- Set the value
                     v.sckHalfCycle := axilWriteMaster.wdata(7 downto 0);
                     -- Send AXI-Lite response
                     axiSlaveWriteResponse(v.axilWriteSlave, axilWriteResp);
                  --------------------------------------------------------
                  when others =>
                     axilWriteResp := AXI_RESP_DECERR_C;
                     -- Send AXI-Lite response
                     axiSlaveWriteResponse(v.axilWriteSlave, AXI_RESP_DECERR_C);
               --------------------------------------------------------
               end case;

            -- Check for a read request
            elsif (axilStatus.readEnable = '1') then
               case (axilReadMaster.araddr(3 downto 0)) is
                  --------------------------------------------------------
                  when x"0" =>
                     v.axilReadSlave.rdata(9 downto 0) := r.delayA;
                  --------------------------------------------------------
                  when x"4" =>
                     v.axilReadSlave.rdata(9 downto 0) := r.delayB;
                  --------------------------------------------------------
                  when x"C" =>
                     v.axilReadSlave.rdata(7 downto 0) := r.sckHalfCycle;
                  --------------------------------------------------------
                  when others =>
                     axilReadResp := AXI_RESP_DECERR_C;
               --------------------------------------------------------
               end case;
               -- Send AXI-Lite Response
               axiSlaveReadResponse(v.axilReadSlave, axilReadResp);
            end if;

            -- Update the shift Register value
            v.shiftReg := v.delayB & v.delayA;
         -------------------------------------------------
         when SEND_DATA_S =>
            -- Check for SCLK fallling edge
            if (r.sclk = '1') and (v.sclk = '0') then

               -- Update the shift register
               v.shiftReg := '0' & r.shiftReg(19 downto 1);

               -- Increment the counter
               v.cnt := r.cnt + 1;

            end if;

            -- Check for SCLK rising edge
            if (r.sclk = '0') and (v.sclk = '1') then

               -- Check for last serial bit
               if r.cnt = 19 then

                  -- Reset counter
                  v.cnt := 0;

                  -- Next state
                  v.state := SLOAD_S;

               end if;

            end if;
         -------------------------------------------------
         when SLOAD_S =>
            -- Check for timeout
            if r.sclkCnt = 0 then

               -- Increment the counter
               v.cnt := r.cnt + 1;

               if (r.cnt = 0) then
                  -- Reset flag
                  v.sclkEn := '0';

               elsif (r.cnt = 1) then
                  -- Set flag
                  v.sload := '1';

               else

                  -- Send AXI-Lite response
                  axiSlaveWriteResponse(v.axilWriteSlave, axilWriteResp);

                  -- Next state
                  v.state := IDLE_S;

               end if;

            end if;
      -------------------------------------------------
      end case;

      -- Outputs
      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;
      enableL        <= r.busy;         -- Active LOW
      enaL           <= r.busy;         -- Active LOW
      enbL           <= r.busy;         -- Active LOW
      sdata          <= r.shiftReg(0);
      sclk           <= r.sclk;
      sload          <= r.sload;

      -- Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;
   end process;

   seq : process (axilClk) is
   begin
      if rising_edge(axilClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
