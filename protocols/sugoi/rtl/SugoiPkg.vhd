-------------------------------------------------------------------------------
-- Title      : SUGOI Protocol: https://confluence.slac.stanford.edu/x/3of_E
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: SUGOI Package File
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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.Code8b10bPkg.all;

package SugoiPkg is

   constant SUGOI_VERSION_C : slv(2 downto 0) := "001";  -- 0x1

   -------------------------
   -- Header bit mapping
   -------------------------
   subtype SUGOI_HDR_VERSION_FIELD_C is natural range 2 downto 0;
   constant SUGOI_HDR_OP_TYPE_C : positive := 3;
   subtype SUGOI_HDR_DDEV_ID_FIELD_C is natural range 7 downto 4;

   -------------------------
   -- Header bit mapping
   -------------------------
   subtype SUGOI_FOOTER_BUS_RESP_FIELD_C is natural range 1 downto 0;
   constant SUGOI_FOOTER_VER_MISMATCH_C   : positive := 2;
   constant SUGOI_FOOTER_NOT_ADDR_ALIGN_C : positive := 3;
   constant SUGOI_FOOTER_XSUM_ERROR_C     : positive := 4;

   -------------------------
   -- Control Code Constants
   -------------------------
   constant CODE_IDLE_C : slv(7 downto 0) := K_28_5_C;  --  Comma Character
   constant CODE_SOF_C  : slv(7 downto 0) := K_28_0_C;
   constant CODE_EOF_C  : slv(7 downto 0) := K_30_7_C;
   constant CODE_TRIG_C : Slv8Array(7 downto 0) := (
      0 => K_28_2_C,
      1 => K_28_3_C,
      2 => K_28_4_C,
      3 => K_28_6_C,
      4 => K_28_7_C,                                    --  Comma Character
      5 => K_23_7_C,
      6 => K_27_7_C,
      7 => K_29_7_C);
   constant CODE_RST_C : slv(7 downto 0) := K_28_1_C;   --  Comma Character

end package SugoiPkg;

package body SugoiPkg is

end package body SugoiPkg;
