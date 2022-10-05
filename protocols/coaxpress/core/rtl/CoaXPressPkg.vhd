-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
--            : CXP Over Fiber Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXPR-008-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress Package File
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

package CoaXPressPkg is

   constant CXP_CRC_POLY_C : slv(31 downto 0) := x"04C11DB7";

   constant CXP_IDLE_K_C : slv(3 downto 0)  := "0111";
   constant CXP_IDLE_C   : slv(31 downto 0) := D_21_5_C & K_28_1_C & K_28_1_C & K_28_5_C;  -- 0xB53C3CBC
   constant CXP_SOP_C    : slv(31 downto 0) := K_27_7_C & K_27_7_C & K_27_7_C & K_27_7_C;  -- 0xFBFBFBFB
   constant CXP_EOP_C    : slv(31 downto 0) := K_29_7_C & K_29_7_C & K_29_7_C & K_29_7_C;  -- 0xFDFDFDFD
   constant CXP_TRIG_C   : slv(31 downto 0) := K_28_2_C & K_28_2_C & K_28_2_C & K_28_2_C;  -- 0x5C5C5C5C
   constant CXP_IO_ACK_C : slv(31 downto 0) := K_28_6_C & K_28_6_C & K_28_6_C & K_28_6_C;  -- 0xDCDCDCDC
   constant CXP_MARKER_C : slv(31 downto 0) := K_28_3_C & K_28_3_C & K_28_3_C & K_28_3_C;  -- 0x7C7C7C7C

   constant CXP_TX_IDLE_C : Slv8Array(3 downto 0) := (
      0 => CXP_IDLE_C(7 downto 0),
      1 => CXP_IDLE_C(15 downto 8),
      2 => CXP_IDLE_C(23 downto 16),
      3 => CXP_IDLE_C(31 downto 24));

   type CxpSpeedType is (
      CXP_1_C,                          -- 1.250
      CXP_2_C,                          -- 2.500
      CXP_3_C,                          -- 3.125
      CXP_6_C,                          -- 6.250
      CXP_10_C,                         -- 10.000
      CXP_12_C);                        -- 12.500

   constant CXPOF_IDLE_C  : slv(7 downto 0) := x"07";  -- /I/ = Idle (nGMII IDLE)
   constant CXPOF_SEQ_C   : slv(7 downto 0) := x"9C";  -- /Q/ = Sequence (only valid in lane 0)
   constant CXPOF_START_C : slv(7 downto 0) := x"FB";  -- /S/ = Start (only valid in lane 0)
   constant CXPOF_TERM_C  : slv(7 downto 0) := x"FD";  -- /T/ = Terminate
   constant CXPOF_ERROR_C : slv(7 downto 0) := x"FE";  -- /E/ = Error

   constant CXPOF_IDLE_WORD_C : slv(31 downto 0) := CXPOF_IDLE_C & CXPOF_IDLE_C & CXPOF_IDLE_C & CXPOF_IDLE_C;

end package CoaXPressPkg;

package body CoaXPressPkg is

end package body CoaXPressPkg;
