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
   constant CXP_ALL_DATA_K_C : slv(3 downto 0) := x"0";
   constant CXP_ALL_CTRL_K_C : slv(3 downto 0) := x"F";

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

   constant CXPOF_XGMII_ALL_DATA_C     : slv(3 downto 0) := x"0";
   constant CXPOF_XGMII_ALL_CTRL_C     : slv(3 downto 0) := x"F";
   constant CXPOF_XGMII_LANE0_CTRL_C   : slv(3 downto 0) := "0001";
   constant CXPOF_XGMII_LANE2_3_CTRL_C : slv(3 downto 0) := "1100";

   constant CXPOF_RESERVED_BYTE_C : slv(7 downto 0) := x"00";

   constant CXPOF_SOP_CTRL_PACKET_TYPE_BIT_C : natural := 7;
   constant CXPOF_SOP_CTRL_UPDATE_BIT_C      : natural := 3;
   constant CXPOF_SOP_CTRL_LS_RATE_BIT_C     : natural := 1;
   constant CXPOF_SOP_CTRL_HKP_BIT_C         : natural := 0;

   constant CXPOF_SOP_CTRL_LOW_SPEED_C  : sl := '0';
   constant CXPOF_SOP_CTRL_HIGH_SPEED_C : sl := '1';

   constant CXPOF_SOP_CTRL_HS_PREFIX_C : slv(6 downto 0) := CXPOF_SOP_CTRL_HIGH_SPEED_C & "000000";

   constant CXPOF_LS_CTRL_DATA_C   : slv(7 downto 0) := x"01";
   constant CXPOF_LS_CTRL_K_CODE_C : slv(7 downto 0) := x"02";

   constant CXPOF_TERM_SUFFIX_C : slv(23 downto 0) := CXPOF_IDLE_C & CXPOF_TERM_C & CXPOF_RESERVED_BYTE_C;

   constant CXPOF_RX_ERR_NONE_C          : slv(3 downto 0) := x"0";
   constant CXPOF_RX_ERR_SEQ_MISMATCH_C  : slv(3 downto 0) := x"1";
   constant CXPOF_RX_ERR_IDLE_ERROR_C    : slv(3 downto 0) := x"2";
   constant CXPOF_RX_ERR_PAYLOAD_ABORT_C : slv(3 downto 0) := x"3";
   constant CXPOF_RX_ERR_BAD_CONTROL_C   : slv(3 downto 0) := x"4";
   constant CXPOF_RX_ERR_OVERWRITE_C     : slv(3 downto 0) := x"5";
   constant CXPOF_RX_ERR_HKP_MALFORMED_C : slv(3 downto 0) := x"6";
   constant CXPOF_RX_ERR_HKP_BAD_K_CODE_C : slv(3 downto 0) := x"7";

   constant CXPOF_HKP_TYPE_NONE_C     : slv(3 downto 0) := x"0";
   constant CXPOF_HKP_TYPE_K_CODE_C   : slv(3 downto 0) := x"1";
   constant CXPOF_HKP_TYPE_SOP_C      : slv(3 downto 0) := x"2";
   constant CXPOF_HKP_TYPE_EOP_C      : slv(3 downto 0) := x"3";
   constant CXPOF_HKP_TYPE_TRIG_C     : slv(3 downto 0) := x"4";
   constant CXPOF_HKP_TYPE_IO_ACK_C   : slv(3 downto 0) := x"5";
   constant CXPOF_HKP_TYPE_MARKER_C   : slv(3 downto 0) := x"6";
   constant CXPOF_HKP_TYPE_INVALID_C  : slv(3 downto 0) := x"F";

   function cxpIsKCode (data : slv(7 downto 0)) return sl;
   function cxpKCodeMask (data : slv(31 downto 0)) return slv;
   function cxpHkpType (data : slv(31 downto 0)) return slv;

end package CoaXPressPkg;

package body CoaXPressPkg is

   function cxpIsKCode (data : slv(7 downto 0)) return sl is
   begin
      case data is
         when K_28_0_C | K_28_1_C | K_28_2_C | K_28_3_C |
              K_28_4_C | K_28_5_C | K_28_6_C | K_28_7_C |
              K_23_7_C | K_27_7_C | K_29_7_C | K_30_7_C =>
            return '1';
         when others =>
            return '0';
      end case;
   end function cxpIsKCode;

   function cxpKCodeMask (data : slv(31 downto 0)) return slv is
      variable ret : slv(3 downto 0);
   begin
      for i in 0 to 3 loop
         ret(i) := cxpIsKCode(data((8*i)+7 downto (8*i)));
      end loop;
      return ret;
   end function cxpKCodeMask;

   function cxpHkpType (data : slv(31 downto 0)) return slv is
   begin
      if (cxpKCodeMask(data) /= CXP_ALL_CTRL_K_C) then
         return CXPOF_HKP_TYPE_INVALID_C;
      elsif (data = CXP_SOP_C) then
         return CXPOF_HKP_TYPE_SOP_C;
      elsif (data = CXP_EOP_C) then
         return CXPOF_HKP_TYPE_EOP_C;
      elsif (data = CXP_TRIG_C) then
         return CXPOF_HKP_TYPE_TRIG_C;
      elsif (data = CXP_IO_ACK_C) then
         return CXPOF_HKP_TYPE_IO_ACK_C;
      elsif (data = CXP_MARKER_C) then
         return CXPOF_HKP_TYPE_MARKER_C;
      else
         return CXPOF_HKP_TYPE_K_CODE_C;
      end if;
   end function cxpHkpType;

end package body CoaXPressPkg;
