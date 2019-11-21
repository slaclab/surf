-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Synchronizes a reset signal and holds it for a parametrized
-- number of cycles.
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

entity PwrUpRst is
   generic (
      TPD_G          : time                           := 1 ns;
      SIM_SPEEDUP_G  : boolean                        := false;
      IN_POLARITY_G  : sl                             := '1';
      OUT_POLARITY_G : sl                             := '1';
      USE_DSP_G      : string                         := "no";
      DURATION_G     : natural range 0 to ((2**30)-1) := 156250000);
   port (
      arst   : in  sl := not IN_POLARITY_G;
      clk    : in  sl;
      rstOut : out sl);
end PwrUpRst;

architecture rtl of PwrUpRst is

   constant CNT_SIZE_C : natural := ite(SIM_SPEEDUP_G, 127, DURATION_G);
   signal   rstSync,
      rst : sl := OUT_POLARITY_G;
   signal cnt : natural range 0 to DURATION_G := 0;

   -- Attribute for XST
   attribute use_dsp        : string;
   attribute use_dsp of cnt : signal is USE_DSP_G;
   
begin

   RstSync_Inst : entity surf.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => IN_POLARITY_G,
         OUT_POLARITY_G => OUT_POLARITY_G)
      port map (
         clk      => clk,
         asyncRst => arst,
         syncRst  => rstSync);

   process (clk)
   begin
      if rising_edge(clk) then
         if rstSync = OUT_POLARITY_G then
            rst <= OUT_POLARITY_G after TPD_G;
            cnt <= 0              after TPD_G;
         else
            if cnt /= CNT_SIZE_C then
               rst <= OUT_POLARITY_G after TPD_G;
               cnt <= cnt + 1        after TPD_G;
            else
               rst <= not(OUT_POLARITY_G) after TPD_G;
            end if;
         end if;
      end if;
   end process;

   rstOut <= rst;
   
end rtl;
