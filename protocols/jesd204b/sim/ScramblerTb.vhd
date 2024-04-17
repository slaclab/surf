-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing JESD Scramblers
------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Common Carrier Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'LCLS2 Common Carrier Core', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;
use surf.Jesd204bPkg.all;

entity ScramblerTb is
end entity;

architecture testbed of ScramblerTb is

   constant TPD_C           : time := 1 ns;
   constant CLK_PERIOD_C    : time := 10 ns;
   constant EN_SCRAMBLING_C : sl   := '1';

   signal clk        : sl               := '0';
   signal rst        : sl               := '0';
   signal rxValid    : sl               := '0';
   signal rxValidDly : sl               := '0';
   signal rxData     : slv(31 downto 0) := (others => '0');
   signal rxDataDly  : slv(31 downto 0) := (others => '0');
   signal txData     : slv(31 downto 0) := (others => '0');
   signal sync       : sl               := '0';
   signal sysref     : sl               := '0';
   signal lmfc       : sl               := '0';
   signal rxGt       : jesdGtRxLaneType := JESD_GT_RX_LANE_INIT_C;
   signal txGt       : jesdGtTxLaneType := JESD_GT_TX_LANE_INIT_C;
   signal cnt        : slv(31 downto 0) := toSlv(1, 32);
   signal failed     : sl               := '0';
   signal failedDly  : sl               := '0';

begin

   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 1 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk,
         rst  => rst);

   process (clk) is
   begin
      if (rising_edge(clk)) then
         failedDly  <= failed  after TPD_C;
         rxValidDly <= rxValid after TPD_C;
         rxDataDly  <= rxData after TPD_C;
         if (rst = '1') then
            txData <= (others => '0');
         elsif (rxValidDly = '1') then
            txData <= txData + 1 after TPD_C;
            if (rxData /= 0) or (cnt /= 1) then
               -- Check for COMMA
               if (rxData=rxDataDly) then
                  cnt <= rxData + 2 after TPD_C;
               else
                  -- Check for skip
                  if (rxData /= cnt)   then
                     failed <= '1' after TPD_C;
                  end if;
                  cnt <= rxData + 1 after TPD_C;
               end if;
            end if;
         end if;
      end if;
   end process;

   U_Sync : entity surf.jesdLmfcGen
      generic map (
         TPD_G => TPD_C,
         K_G   => 256,
         F_G   => 2)
      port map (
         clk      => clk,
         rst      => rst,
         nSync_i  => '0',
         sysref_i => '0',
         lmfc_o   => sync);

   U_LmfcGen : entity surf.jesdLmfcGen
      generic map (
         TPD_G => TPD_C,
         F_G   => 2,
         K_G   => 32)
      port map (
         clk        => clk,
         rst        => rst,
         nSync_i    => '1',
         sysref_i   => sync,
         sysrefRe_o => sysref,
         lmfc_o     => lmfc);

   U_TX : entity surf.JesdTxLane
      generic map (
         TPD_G => TPD_C,
         F_G   => 2,
         K_G   => 32)
      port map (
         devClk_i     => clk,
         devRst_i     => rst,
         subClass_i   => '1',
         enable_i     => '1',
         replEnable_i => '1',
         scrEnable_i  => EN_SCRAMBLING_C,  -- Testing scrambling
         inv_i        => '0',
         lmfc_i       => lmfc,
         nSync_i      => '1',
         gtTxReady_i  => '1',
         sysRef_i     => sysref,
         status_o     => open,
         sampleData_i => endianSwapSlv(txData, GT_WORD_SIZE_C),
         r_jesdGtTx   => txGt);

   rxGt.data      <= txGt.data;
   rxGt.dataK     <= txGt.dataK;
   rxGt.rstDone   <= '1';
   rxGt.cdrStable <= '1';

   U_RX : entity surf.JesdRxLane
      generic map (
         TPD_G => TPD_C,
         F_G   => 2,
         K_G   => 32)
      port map (
         devClk_i     => clk,
         devRst_i     => rst,
         subClass_i   => '1',
         sysRef_i     => sysref,
         clearErr_i   => '0',
         enable_i     => '1',
         replEnable_i => '1',
         scrEnable_i  => EN_SCRAMBLING_C,  -- Testing scrambling
         status_o     => open,
         r_jesdGtRx   => rxGt,
         lmfc_i       => lmfc,
         nSyncAny_i   => '1',
         nSyncAnyD1_i => '0',
         nSync_o      => open,
         dataValid_o  => rxValid,
         sampleData_o => rxData);

   process(failedDly)
   begin
      if failedDly = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
   end process;

end testbed;
