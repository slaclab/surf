-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for the BoxcarIntegrator module
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

entity BoxcarIntegratorTb is end BoxcarIntegratorTb;

architecture testbed of BoxcarIntegratorTb is

   constant TPD_G : time := 2.5 ns;

   constant DOB_REG_C : boolean := true;

   signal clk : sl := '0';
   signal rst : sl := '0';

   signal intCount : slv(9 downto 0);
   signal obPeriod : sl;
   signal obValid  : sl;
   signal obFull   : sl;
   signal obData   : slv(25 downto 0);
   signal validCnt : slv(15 downto 0);
   signal validEn  : sl;
   signal dataIn   : slv(15 downto 0);
   signal expData0 : slv(25 downto 0);
   signal expData1 : slv(25 downto 0);
   signal expData2 : slv(25 downto 0);
   signal expError : sl;
   signal spacing  : slv(15 downto 0);

   signal passed : sl := '0';
   signal failed : sl := '0';

begin

   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 10 ns,
         RST_START_DELAY_G => 1 ns,
         RST_HOLD_TIME_G   => 1 us)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => open);

   process (clk)
   begin
      if rising_edge(clk) then
         if rst = '1' then
            validCnt <= (others => '0') after TPD_G;
            dataIn   <= (others => '0') after TPD_G;
            validEn  <= '0';
         else
            if validCnt >= spacing then
               validCnt <= (others => '0') after TPD_G;
               dataIn   <= dataIn + 1      after TPD_G;
               validEn  <= '1'             after TPD_G;
            else
               validCnt <= validCnt + 1 after TPD_G;
               validEn  <= '0'          after TPD_G;
            end if;
         end if;
      end if;
   end process;

   process
   begin
      passed   <= '0';
      intCount <= toSlv(0, 10);
      spacing  <= toSlv(99, 16);
      wait for 100 us;
      intCount <= toSlv(1, 10);
      wait for 100 us;
      intCount <= toSlv(2, 10);
      wait for 100 us;
      intCount <= toSlv(8, 10);
      wait for 100 us;
      intCount <= toSlv(4, 10);
      wait for 100 us;
      intCount <= toSlv(1023, 10);
      wait for 4000 us;

      intCount <= toSlv(0, 10);
      spacing  <= toSlv(0, 16);
      wait for 100 us;
      intCount <= toSlv(1, 10);
      wait for 100 us;
      intCount <= toSlv(2, 10);
      wait for 100 us;
      intCount <= toSlv(8, 10);
      wait for 100 us;
      intCount <= toSlv(4, 10);
      wait for 100 us;
      intCount <= toSlv(1023, 10);
      wait for 4000 us;

      intCount <= toSlv(0, 10);
      spacing  <= toSlv(1, 16);
      wait for 100 us;
      intCount <= toSlv(1, 10);
      wait for 100 us;
      intCount <= toSlv(2, 10);
      wait for 100 us;
      intCount <= toSlv(8, 10);
      wait for 100 us;
      intCount <= toSlv(4, 10);
      wait for 100 us;
      intCount <= toSlv(1023, 10);
      wait for 4000 us;

      intCount <= toSlv(0, 10);
      spacing  <= toSlv(2, 16);
      wait for 100 us;
      intCount <= toSlv(1, 10);
      wait for 100 us;
      intCount <= toSlv(2, 10);
      wait for 100 us;
      intCount <= toSlv(8, 10);
      wait for 100 us;
      intCount <= toSlv(4, 10);
      wait for 100 us;
      intCount <= toSlv(1023, 10);
      wait for 4000 us;
      passed   <= '1';

   end process;

   U_BoxcarIntegrator : entity surf.BoxcarIntegrator
      generic map (
         TPD_G        => TPD_G,
         SIGNED_G     => false,
         DOB_REG_G    => DOB_REG_C,
         DATA_WIDTH_G => 16,
         ADDR_WIDTH_G => 10)
      port map (
         clk      => clk,
         rst      => rst,
         intCount => intCount,
         ibValid  => validEn,
         ibData   => dataIn,
         obValid  => obValid,
         obData   => obData,
         obFull   => obFull,
         obPeriod => obPeriod);

   process (clk)
      variable exp : slv(25 downto 0);
      variable tmp : slv(15 downto 0);
   begin
      if rising_edge(clk) then
         if rst = '1' then
            expData0 <= (others => '0') after TPD_G;
            expData1 <= (others => '0') after TPD_G;
            expData2 <= (others => '0') after TPD_G;
            expError <= '0'             after TPD_G;
         else
            if validEn = '1' then
               exp := (others => '0');
               for i in 0 to conv_integer(intCount) loop
                  tmp := dataIn - i;
                  exp := exp + tmp;
               end loop;
               expData0 <= exp after TPD_G;
            end if;

            expData1 <= expData0 after TPD_G;

            if DOB_REG_C then
               expData2 <= expData1 after TPD_G;
            else
               expData2 <= expData0 after TPD_G;
            end if;

            if obValid = '1' then
               if obFull = '0' or expData2 = obData then
                  expError <= '0' after TPD_G;
               else
                  expError <= '1' after TPD_G;
               end if;
            end if;

            failed <= expError after TPD_G;

         end if;
      end if;
   end process;

   process(failed, passed)
   begin
      if passed = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      elsif failed = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
   end process;

end testbed;
