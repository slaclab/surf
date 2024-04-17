-------------------------------------------------------------------------------
-- Title      : PGPv2fc: https://confluence.slac.stanford.edu/x/q86fD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Checks if the raw MGT 8b10b stream is aligned and correct.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library surf;
use surf.StdRtlPkg.all;
use surf.Pgp2fcPkg.all;

entity Pgp2fcAlignmentChecker is
   generic (
      LATCH_ERROR : boolean := false); -- If true, rst will clear the flag
   port (
      clk    : in  sl;
      rst    : in  sl := '0';
      rxLane : in  Pgp2fcRxPhyLaneInType;
      error  : out sl
   );
end Pgp2fcAlignmentChecker;

architecture Behavioral of Pgp2fcAlignmentChecker is
   signal syncRst : sl;

   signal dispErrors : sl;
   signal decErrors : sl;
   signal wrongAlign : sl;
begin
   U_Rst : entity surf.RstSync
   generic map (
      RELEASE_DELAY_G => 3)
   port map (
      clk => clk,
      asyncRst => rst,
      syncRst => syncRst);

   -- Check for proper raw datastream alignment and validity
   dispErrors <= '1' when rxLane.dispErr /= "00" else '0';
   decErrors <= '1' when rxLane.decErr /= "00" else '0';
   wrongAlign <= '1' when rxLane.dataK(1) = '1' else '0';

   process (clk) begin
      if (rising_edge(clk)) then
         if (syncRst = '1' and LATCH_ERROR = true) then
            error <= '0';
         else
            if (LATCH_ERROR = true) then
               if (dispErrors = '1' or decErrors = '1' or wrongAlign = '1') then
                  error <= '1';
               end if;
            else
               if (dispErrors = '1' or decErrors = '1' or wrongAlign = '1') then
                  error <= '1';
               else
                  error <= '0';
               end if;
            end if;
         end if;
      end if;
   end process;

end Behavioral;
