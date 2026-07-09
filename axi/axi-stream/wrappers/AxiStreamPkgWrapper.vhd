-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for AxiStreamPkg helper functions
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamPkgWrapper is
   port (
      bytes       : in  integer range 0 to 64;
      tKeepResult : out slv(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto 0));
end entity AxiStreamPkgWrapper;

architecture rtl of AxiStreamPkgWrapper is

begin

   tKeepResult <= genTKeep(bytes);

end architecture rtl;
