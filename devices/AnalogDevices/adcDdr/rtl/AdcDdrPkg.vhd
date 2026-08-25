-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Common constants and types for serialized DDR ADC receivers
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

package AdcDdrPkg is

   -- Register-map version and fixed alignment policy. Alignment thresholds are
   -- shared because all supported devices expose a deterministic repeating FCO word.
   constant ADC_DDR_VERSION_C          : slv(31 downto 0) := x"00010000";
   constant ADC_DDR_LOCK_MATCHES_C     : positive         := 4;
   constant ADC_DDR_UNLOCK_ERRORS_C    : positive         := 2;
   -- ISERDESE2 DDR operation requires three quiet CLKDIV cycles after a
   -- one-cycle BITSLIP request before the shifted word is evaluated.
   constant ADC_DDR_BITSLIP_INTERVAL_C : positive         := 8;
   -- captureClk (CLKDIV) cycles the deserializer reset is held on every relock
   -- so that a group's FCO and data deserializers all leave reset on the same
   -- edge. Comfortably exceeds the minimum ISERDES/IDELAY reset pulse width.
   constant ADC_DDR_RESET_HOLD_C       : positive         := 8;

   -- Return the native programmable input-delay width for an FPGA family.
   function adcDdrDelayBits (deviceFamily : string) return positive;

   -- Base offsets for the normalized register windows. Per-lane and per-channel
   -- entries use four-byte strides from these bases.
   constant ADC_DDR_VERSION_ADDR_C           : slv(11 downto 0) := X"000";
   constant ADC_DDR_CAPABILITIES0_ADDR_C     : slv(11 downto 0) := X"004";
   constant ADC_DDR_CAPABILITIES1_ADDR_C     : slv(11 downto 0) := X"008";
   constant ADC_DDR_CAPTURE_RESET_ADDR_C      : slv(11 downto 0) := X"00C";
   constant ADC_DDR_RELOCK_ADDR_C             : slv(11 downto 0) := X"010";
   constant ADC_DDR_SNAPSHOT_ADDR_C           : slv(11 downto 0) := X"014";
   constant ADC_DDR_CLEAR_COUNTERS_ADDR_C     : slv(11 downto 0) := X"018";
   constant ADC_DDR_STATUS_ADDR_C             : slv(11 downto 0) := X"01C";
   constant ADC_DDR_LOCKED_MASK_ADDR_C        : slv(11 downto 0) := X"020";
   constant ADC_DDR_SNAPSHOT_SEQUENCE_ADDR_C  : slv(11 downto 0) := X"024";
   constant ADC_DDR_DATA_DELAY_ADDR_C        : slv(11 downto 0) := X"100";
   constant ADC_DDR_FCO_DELAY_ADDR_C         : slv(11 downto 0) := X"200";
   constant ADC_DDR_FCO_WORD_ADDR_C          : slv(11 downto 0) := X"300";
   constant ADC_DDR_LOST_LOCK_COUNT_ADDR_C   : slv(11 downto 0) := X"340";
   constant ADC_DDR_PATTERN_BASE_ADDR_C        : slv(11 downto 0) := X"800";
   constant ADC_DDR_PATTERN_START_ADDR_C       : slv(7 downto 0)  := X"00";
   constant ADC_DDR_PATTERN_ABORT_ADDR_C       : slv(7 downto 0)  := X"04";
   constant ADC_DDR_PATTERN_CONFIG_ADDR_C      : slv(7 downto 0)  := X"08";
   constant ADC_DDR_PATTERN_CHANNEL_MASK_ADDR_C : slv(7 downto 0) := X"0C";
   constant ADC_DDR_PATTERN_FCO_MASK_ADDR_C    : slv(7 downto 0)  := X"10";
   constant ADC_DDR_PATTERN_DATA_MASK_ADDR_C   : slv(7 downto 0)  := X"14";
   constant ADC_DDR_PATTERN_A_ADDR_C           : slv(7 downto 0)  := X"18";
   constant ADC_DDR_PATTERN_B_ADDR_C           : slv(7 downto 0)  := X"1C";
   constant ADC_DDR_PATTERN_SAMPLES_ADDR_C     : slv(7 downto 0)  := X"20";
   constant ADC_DDR_PATTERN_TIMEOUT_ADDR_C     : slv(7 downto 0)  := X"24";
   constant ADC_DDR_PATTERN_STATUS_ADDR_C      : slv(7 downto 0)  := X"28";
   constant ADC_DDR_PATTERN_SEQUENCE_ADDR_C    : slv(7 downto 0)  := X"2C";
   constant ADC_DDR_PATTERN_CHECKED_ADDR_C     : slv(7 downto 0)  := X"30";
   constant ADC_DDR_PATTERN_CHANNEL_PASS_ADDR_C : slv(7 downto 0) := X"34";
   constant ADC_DDR_PATTERN_FCO_PASS_ADDR_C    : slv(7 downto 0)  := X"38";
   constant ADC_DDR_PATTERN_WORD_ERROR_ADDR_C  : slv(7 downto 0)  := X"40";
   constant ADC_DDR_PATTERN_BIT_ERROR_ADDR_C   : slv(7 downto 0)  := X"80";
   constant ADC_DDR_PATTERN_FCO_ERROR_ADDR_C   : slv(7 downto 0)  := X"C0";
   constant ADC_DDR_OVERFLOW_COUNT_ADDR_C    : slv(11 downto 0) := X"500";
   constant ADC_DDR_DEBUG_ADDR_C             : slv(11 downto 0) := X"600";

   -- Capture capability feature-bit assignments.
   constant ADC_DDR_CAP_PATTERN_CHECK_BIT_C : natural := 16;

   -- Status register bit assignments.
   constant ADC_DDR_STATUS_DELAY_READY_BIT_C    : natural := 1;
   constant ADC_DDR_STATUS_ALL_LOCKED_BIT_C     : natural := 2;
   constant ADC_DDR_STATUS_ANY_OVERFLOW_BIT_C   : natural := 3;

   -- Pattern measurement command and status bit assignments.
   constant ADC_DDR_PATTERN_ALTERNATING_BIT_C    : natural := 0;
   constant ADC_DDR_PATTERN_REFERENCE_OFFSET_C   : natural := 8;
   constant ADC_DDR_PATTERN_BUSY_BIT_C           : natural := 0;
   constant ADC_DDR_PATTERN_TIMEOUT_BIT_C        : natural := 1;
   constant ADC_DDR_PATTERN_CONFIG_ERROR_BIT_C   : natural := 2;
   constant ADC_DDR_PATTERN_ABORTED_BIT_C        : natural := 3;
   constant ADC_DDR_PATTERN_PHASE_ACQUIRED_BIT_C : natural := 4;
   constant ADC_DDR_PATTERN_CHANNEL_PASS_BIT_C   : natural := 5;
   constant ADC_DDR_PATTERN_FCO_PASS_BIT_C       : natural := 6;

   -- Runtime PHY delay command. The value width matches the widest supported
   -- Xilinx input delay; load is a one-cycle capture-domain write strobe.
   type AdcDdrDelayType is record
      value : slv(8 downto 0);
      load  : sl;
   end record AdcDdrDelayType;

   constant ADC_DDR_DELAY_INIT_C : AdcDdrDelayType := (
      value => (others => '0'),
      load  => '0');

   type AdcDdrDelayArray is array (natural range <>) of AdcDdrDelayType;

end package AdcDdrPkg;

package body AdcDdrPkg is

   function adcDdrDelayBits (deviceFamily : string) return positive is
   begin
      if deviceFamily = "7SERIES" then
         return 5;
      elsif deviceFamily = "ULTRASCALE" or deviceFamily = "ULTRASCALE_PLUS" then
         return 9;
      else
         assert false
            report "Unsupported AdcDdr FPGA device family " & deviceFamily
            severity failure;
         return 5;
      end if;
   end function adcDdrDelayBits;

end package body AdcDdrPkg;
