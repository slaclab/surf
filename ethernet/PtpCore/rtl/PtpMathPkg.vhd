-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PTP arithmetic request/result records and width-safe initializers.
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

package PtpMathPkg is

   -- All interfaces use the instance clk. Reset/cancel wins over request or
   -- result transfer and discards pending work. Opposite-direction ready and
   -- independent cancellation remain separate ports. Generic leaf records use
   -- VHDL-2008 element constraints to preserve every existing operand width.

   -- Signed constant-divisor request. Hold valid, rounding and dividend through
   -- inputReady. roundNearest=0 truncates toward zero; 1 rounds half away from zero.
   type PtpConstDivideRequestType is record
      valid        : sl;
      roundNearest : sl;
      operand      : slv;
   end record;

   type PtpConstDivideRequestArray is array (natural range <>) of PtpConstDivideRequestType;

   function ptpConstDivideRequestInit(width : positive) return PtpConstDivideRequestType;

   -- Held signed quotient and exact remainder; resultReady consumes valid.
   -- Widths match the dividend. Constant divisor and units belong to the instance.
   type PtpConstDivideResultType is record
      valid     : sl;
      value     : slv;
      remainder : slv;
   end record;

   type PtpConstDivideResultArray is array (natural range <>) of PtpConstDivideResultType;

   function ptpConstDivideResultInit(width : positive) return PtpConstDivideResultType;

   -- Signed A times unsigned B request; hold through inputReady. Widths remain
   -- instance constraints, so records do not widen the multiplier inputs.
   type PtpProductRequestType is record
      valid    : sl;
      operandA : slv;
      operandB : slv;
   end record;

   type PtpProductRequestArray is array (natural range <>) of PtpProductRequestType;

   function ptpProductRequestInit(aWidth : positive; bWidth : positive) return PtpProductRequestType;

   -- Full signed A+B-bit product held through resultReady. overflow preserves
   -- the signed128 fit contract, independently of downstream rounding.
   type PtpProductResultType is record
      valid    : sl;
      value    : slv;
      overflow : sl;
   end record;

   type PtpProductResultArray is array (natural range <>) of PtpProductResultType;

   function ptpProductResultInit(width : positive) return PtpProductResultType;

   -- Unsigned seconds and Q16 subsecond ns, captured together on inputReady.
   type PtpEpochRequestType is record
      valid        : sl;
      seconds      : slv(47 downto 0);
      subsecondQ16 : slv(47 downto 0);
   end record;

   type PtpEpochRequestArray is array (natural range <>) of PtpEpochRequestType;

   constant PTP_EPOCH_REQUEST_INIT_C : PtpEpochRequestType := (
      valid        => '0',
      seconds      => (others => '0'),
      subsecondQ16 => (others => '0'));

   -- Unsigned95 absolute Q16 ns held through resultReady.
   type PtpEpochResultType is record
      valid : sl;
      value : slv(94 downto 0);
   end record;

   type PtpEpochResultArray is array (natural range <>) of PtpEpochResultType;

   constant PTP_EPOCH_RESULT_INIT_C : PtpEpochResultType := (
      valid => '0',
      value => (others => '0'));

   -- Signed128 arithmetic request held through inputReady; divide selects the
   -- operation, roundNearest selects half-away rounding. Units belong to the client.
   type PtpMathRequestType is record
      valid        : sl;
      divide       : sl;
      roundNearest : sl;
      operandA     : slv(127 downto 0);
      operandB     : slv(127 downto 0);
   end record;

   type PtpMathRequestArray is array (natural range <>) of PtpMathRequestType;

   constant PTP_MATH_REQUEST_INIT_C : PtpMathRequestType := (
      valid        => '0',
      divide       => '0',
      roundNearest => '0',
      operandA     => (others => '0'),
      operandB     => (others => '0'));

   -- Held arithmetic value/remainder/error; resultReady consumes valid.
   type PtpMathResultType is record
      valid     : sl;
      value     : slv(127 downto 0);
      remainder : slv(127 downto 0);
      error     : sl;
   end record;

   type PtpMathResultArray is array (natural range <>) of PtpMathResultType;

   constant PTP_MATH_RESULT_INIT_C : PtpMathResultType := (
      valid     => '0',
      value     => (others => '0'),
      remainder => (others => '0'),
      error     => '0');

   -- Shared variable-divider request: signed128 numerator, unsigned divisor.
   -- Each client holds its request until its inputReady; units belong to the client.
   type PtpDivideRequestType is record
      valid        : sl;
      roundNearest : sl;
      operandA     : slv(127 downto 0);
      operandB     : slv;
   end record;

   type PtpDivideRequestArray is array (natural range <>) of PtpDivideRequestType;

   function ptpDivideRequestInit(divisorWidth : positive) return PtpDivideRequestType;

   -- Owner-specific signed128 quotient/error held through resultReady; a stalled
   -- response does not block other clients. Cancellation is separately owner-local.
   type PtpDivideResultType is record
      valid : sl;
      value : slv(127 downto 0);
      error : sl;
   end record;

   type PtpDivideResultArray is array (natural range <>) of PtpDivideResultType;

   constant PTP_DIVIDE_RESULT_INIT_C : PtpDivideResultType := (
      valid => '0',
      value => (others => '0'),
      error => '0');

   -- Fixed endpoint clients use the generic records with explicit widths.
   subtype PtpSecondRequestType is PtpConstDivideRequestType(operand(127 downto 0));
   subtype PtpSecondResultType is PtpConstDivideResultType(value(127 downto 0), remainder(127 downto 0));
   subtype PtpDivideRequest80Type is PtpDivideRequestType(operandB(79 downto 0));
   constant PTP_SECOND_REQUEST_INIT_C   : PtpSecondRequestType := ptpConstDivideRequestInit(128);
   constant PTP_SECOND_RESULT_INIT_C    : PtpSecondResultType := ptpConstDivideResultInit(128);
   constant PTP_DIVIDE_REQUEST80_INIT_C : PtpDivideRequest80Type := ptpDivideRequestInit(80);

end package PtpMathPkg;

package body PtpMathPkg is

   function ptpConstDivideRequestInit(width : positive) return PtpConstDivideRequestType is
      variable ret : PtpConstDivideRequestType(operand(width-1 downto 0));
   begin
      ret.valid        := '0';
      ret.roundNearest := '0';
      ret.operand      := (others => '0');
      return ret;
   end function;

   function ptpConstDivideResultInit(width : positive) return PtpConstDivideResultType is
      variable ret : PtpConstDivideResultType(value(width-1 downto 0), remainder(width-1 downto 0));
   begin
      ret.valid     := '0';
      ret.value     := (others => '0');
      ret.remainder := (others => '0');
      return ret;
   end function;

   function ptpProductRequestInit(aWidth : positive; bWidth : positive) return PtpProductRequestType is
      variable ret : PtpProductRequestType(operandA(aWidth-1 downto 0), operandB(bWidth-1 downto 0));
   begin
      ret.valid    := '0';
      ret.operandA := (others => '0');
      ret.operandB := (others => '0');
      return ret;
   end function;

   function ptpProductResultInit(width : positive) return PtpProductResultType is
      variable ret : PtpProductResultType(value(width-1 downto 0));
   begin
      ret.valid    := '0';
      ret.value    := (others => '0');
      ret.overflow := '0';
      return ret;
   end function;

   function ptpDivideRequestInit(divisorWidth : positive) return PtpDivideRequestType is
      variable ret : PtpDivideRequestType(operandB(divisorWidth-1 downto 0));
   begin
      ret.valid        := '0';
      ret.roundNearest := '0';
      ret.operandA     := (others => '0');
      ret.operandB     := (others => '0');
      return ret;
   end function;

end package body PtpMathPkg;
