-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for clink framer
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity ClinkUartTb is end ClinkUartTb;

-- Define architecture
architecture test of ClinkUartTb is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 4,               -- 32 bits
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant CLK_PERIOD_C : time := 5.000 ns;
   constant TPD_G        : time := 1 ns;

   type StateType is (
      TX_S,
      RX_S,
      FAIL_S,
      PASS_S);

   type RegType is record
      passed   : sl;
      failed   : sl;
      rxSlave  : AxiStreamSlaveType;
      txMaster : AxiStreamMasterType;
      state    : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      passed   => '0',
      failed   => '0',
      rxSlave  => AXI_STREAM_SLAVE_INIT_C,
      txMaster => AXI_STREAM_MASTER_INIT_C,
      state    => TX_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clk      : sl;
   signal rst      : sl;
   signal loopback : sl;

   signal txMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal rxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal passed : sl := '0';
   signal failed : sl := '0';

begin

   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1000 ns)
      port map (
         clkP => clk,
         rst  => rst);

   U_Uart : entity surf.ClinkUart
      generic map (
         TPD_G              => TPD_G,
         UART_AXIS_CONFIG_G => AXIS_CONFIG_C)
      port map (
         -- Clock and reset, 200Mhz
         intClk      => clk,
         intRst      => rst,
         -- Configurations
         baud        => toSlv(9600, 24),  -- 9600 baud
         throttle    => toSlv(10, 16),    -- 10 us
         -- Data In/Out
         uartClk     => clk,
         uartRst     => rst,
         sUartMaster => txMaster,
         sUartSlave  => txSlave,
         mUartMaster => rxMaster,
         mUartSlave  => rxSlave,
         -- Serial data
         rxIn        => loopback,
         txOut       => loopback);

   comb : process (r, rst, rxMaster, txSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Flow control
      v.rxSlave := AXI_STREAM_SLAVE_INIT_C;
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when TX_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               v.txMaster.tValid            := '1';
               v.txMaster.tLast             := '1';
               ssiSetUserSof(AXIS_CONFIG_C, v.txMaster, '1');
               v.txMaster.tData(7 downto 0) := r.txMaster.tData(7 downto 0) + 1;
               v.state                      := RX_S;
            end if;
         ----------------------------------------------------------------------
         when RX_S =>
            -- Check if ready to move data
            if (rxMaster.tValid = '1') then
               v.rxSlave.tReady := '1';
               if (r.txMaster.tData(7 downto 0) /= rxMaster.tData(7 downto 0)) then
                  v.state := FAIL_S;
               elsif (r.txMaster.tData(7 downto 0) = x"FF") then
                  v.state := PASS_S;
               else
                  v.state := TX_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when FAIL_S =>
            v.failed := '1';
         ----------------------------------------------------------------------
         when PASS_S =>
            v.passed := '1';
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      rxSlave  <= v.rxSlave;
      txMaster <= r.txMaster;
      failed   <= r.failed;
      passed   <= r.passed;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   process(failed, passed)
   begin
      if failed = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
      if passed = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      end if;
   end process;

end test;
