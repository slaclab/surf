-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Monitors the time between sysref rising edge detections
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

entity JesdSysrefMon is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- SYSREF Edge detection (devClk domain)
      devClk          : in  sl;
      sysrefEdgeDet_i : in  sl;
      -- Max/Min measurements  (axilClk domain)
      axilClk         : in  sl;
      statClr         : in  sl;
      sysRefPeriodmin : out slv(15 downto 0);
      sysRefPeriodmax : out slv(15 downto 0));
end entity JesdSysrefMon;

architecture rtl of JesdSysrefMon is

   type RegType is record
      armed           : slv(1 downto 0);
      cnt             : slv(15 downto 0);
      sysRefPeriodmin : slv(15 downto 0);
      sysRefPeriodmax : slv(15 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      armed           => "00",
      cnt             => x"0000",
      sysRefPeriodmin => x"0000",
      sysRefPeriodmax => x"0000");

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clr : sl;

begin

   U_RstOneShot : entity surf.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => devClk,
         dataIn  => statClr,
         dataOut => clr);

   comb : process (clr, r, sysrefEdgeDet_i) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Increment the counter
      if (r.cnt /= x"FFFF") then
         v.cnt := r.cnt + 1;
      end if;

      -- Wait for SYSREF edge detection strobe
      if (sysrefEdgeDet_i = '1') then

         -- Reset the counter
         v.cnt := (others => '0');

         -- Check for first SYSREF edge after reset
         if (r.armed = "00") then

            -- Update the flag
            v.armed := "01";

         -- Check for Second SYSREF edge after reset
         elsif (r.armed = "01") then

            -- Update the flag
            v.armed := "11";

            -- Pass the current values to the statistics measurements
            v.sysRefPeriodmax := r.cnt;
            v.sysRefPeriodmin := r.cnt;

         -- Normal mode
         else

            -- Check for max.
            if (r.cnt > r.sysRefPeriodmax) then
               v.sysRefPeriodmax := r.cnt;
            end if;

            -- Check for min.
            if (r.cnt < r.sysRefPeriodmin) then
               v.sysRefPeriodmin := r.cnt;
            end if;

         end if;

      end if;

      -- Check for reseting statistics
      if (clr = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (devClk) is
   begin
      if (rising_edge(devClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_sync : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk             => devClk,
         din(15 downto 0)   => r.sysRefPeriodmin,
         din(31 downto 16)  => r.sysRefPeriodmax,
         rd_clk             => axilClk,
         dout(15 downto 0)  => sysRefPeriodmin,
         dout(31 downto 16) => sysRefPeriodmax);

end rtl;
