-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flattened simulation wrapper for surf.Ad9249SimCore
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

library surf;
use surf.StdRtlPkg.all;

entity Ad9249SimCoreWrapper is
   port (
      sampleClk    : in  sl;
      sampleRst    : in  sl;
      sampleEnable : in  sl;
      normalData   : in  slv(127 downto 0);
      cfgWrEn      : in  sl;
      cfgAddr      : in  slv(8 downto 0);
      cfgWrData    : in  slv(7 downto 0);
      cfgRdData    : out slv(7 downto 0);
      sampleData   : out slv(127 downto 0);
      sampleValid  : out sl);
end entity Ad9249SimCoreWrapper;

architecture rtl of Ad9249SimCoreWrapper is

   signal normalArray : Slv16Array(7 downto 0);
   signal sampleArray : Slv16Array(7 downto 0);

begin

   GEN_FLATTEN : for i in 7 downto 0 generate
      normalArray(i) <= normalData((i*16)+15 downto i*16);
      sampleData((i*16)+15 downto i*16) <= sampleArray(i);
   end generate GEN_FLATTEN;

   U_DUT : entity surf.Ad9249SimCore
      port map (
         sampleClk    => sampleClk, -- [in]
         sampleRst    => sampleRst, -- [in]
         sampleEnable => sampleEnable, -- [in]
         normalData   => normalArray, -- [in]
         cfgWrEn      => cfgWrEn, -- [in]
         cfgAddr      => cfgAddr, -- [in]
         cfgWrData    => cfgWrData, -- [in]
         cfgRdData    => cfgRdData, -- [out]
         sampleData   => sampleArray, -- [out]
         sampleValid  => sampleValid); -- [out]

end architecture rtl;
