-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flat cocotb harness for surf.RogueSideBandWrap
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

entity RogueSideBandFlatHarness is
   generic (
      TPD_G      : time                        := 1 ns;
      PORT_NUM_G : natural range 1024 to 49151 := 9000);
   port (
      sysClk     : in  sl;
      sysRst     : in  sl;
      txOpCode   : in  slv(7 downto 0);
      txOpCodeEn : in  sl;
      txRemData  : in  slv(7 downto 0);
      rxOpCode   : out slv(7 downto 0);
      rxOpCodeEn : out sl;
      rxRemData  : out slv(7 downto 0));
end entity RogueSideBandFlatHarness;

architecture harness of RogueSideBandFlatHarness is

begin

   -- RogueSideBandWrap's ports are already scalar sl/slv, so the flat harness
   -- is a direct pass-through -- no AXI-Stream record shims are needed (unlike
   -- RogueTcpStreamFlatHarness).
   U_DUT : entity surf.RogueSideBandWrap
      generic map (
         TPD_G      => TPD_G,
         PORT_NUM_G => PORT_NUM_G)
      port map (
         sysClk     => sysClk,     -- [in]
         sysRst     => sysRst,     -- [in]
         txOpCode   => txOpCode,   -- [in]
         txOpCodeEn => txOpCodeEn, -- [in]
         txRemData  => txRemData,  -- [in]
         rxOpCode   => rxOpCode,   -- [out]
         rxOpCodeEn => rxOpCodeEn, -- [out]
         rxRemData  => rxRemData); -- [out]

end architecture harness;
