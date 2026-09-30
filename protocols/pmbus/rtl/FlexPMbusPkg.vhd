-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AxiLitePMbusMasterCore access-ROM constants for the Flex Power
-- Modules BMR467 and BMR474 digital point-of-load regulators.
--
-- AxiLitePMbusMasterCore selects the SMBus transfer type for each PMBus command
-- code from a 256-entry PMbusAccessArray ROM (see PMbusPkg): bit 2 set means a
-- Send Byte with no data, and bits 1:0 give the data size ("00" = 1 byte,
-- "01" = 2 bytes, "11" = 4 bytes). The generic default PMBUS_ACCESS_ROM_INIT_C
-- treats every manufacturer-specific command in 0xAA-0xFF as a byte and every
-- command in 0x21-0x39 as a word. Both Flex parts disagree with that table, so
-- the core would issue Read Byte where the module expects Read Word (upper
-- byte lost) or Write Word where it expects Write Byte.
--
-- Each constant below starts from PMBUS_ACCESS_ROM_INIT_C and overrides only
-- the command codes where the Flex "PMBus Command Summary" table differs.
-- Block and string transfers are not supported by the core and keep their
-- default entries; the matching PyRogue drivers (surf.devices.flex) leave
-- those commands commented out.
--
-- Pass the constant to the ACCESS_ROM_INIT_G generic of AxiLitePMbusMasterCore
-- (or AxiLitePMbusMaster). A board that can carry either module may select
-- the ROM from a generic with the PMbusPkg ite() overload:
--
--    ACCESS_ROM_INIT_G => ite(USE_BMR474_G, BMR474_ACCESS_ROM_C, BMR467_ACCESS_ROM_C)
--
-- The constants are deferred to the package body so that the helper functions
-- are elaborated before they are called.
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
use surf.PMbusPkg.all;

package FlexPMbusPkg is

   -- Flex BMR467 (1/28701-BMR467 Rev E): 120 A single-rail module.
   -- PMBus address 0x26 with RSA = 0 Ohm (SA shorted to PREF); VOUT_MODE = 0x13.
   constant BMR467_ACCESS_ROM_C : PMbusAccessArray;

   -- Flex BMR474 (1/28701-BMR474 Rev A): 80 A two-phase module (PAGE 1 unused).
   -- PMBus address 0x72 with RSA = 5.11 kOhm (SA to VREF); VOUT_MODE = 0x16.
   constant BMR474_ACCESS_ROM_C : PMbusAccessArray;

end package FlexPMbusPkg;

package body FlexPMbusPkg is

   function bmr467AccessRom return PMbusAccessArray is
      variable rom : PMbusAccessArray := PMBUS_ACCESS_ROM_INIT_C;
   begin
      -- Manufacturer-specific R/W Word and Read Word commands (default ROM says byte)
      rom(16#BF#) := "001";             -- DEADTIME_MAX
      rom(16#CA#) := "001";             -- IOUT0_CAL_GAIN
      rom(16#CB#) := "001";             -- IOUT1_CAL_GAIN
      rom(16#CC#) := "001";             -- IOUT0_CAL_OFFSET
      rom(16#CD#) := "001";             -- IOUT1_CAL_OFFSET
      rom(16#CE#) := "001";             -- MIN_VOUT_REG
      rom(16#D0#) := "001";             -- ISENSE_CONFIG
      rom(16#D1#) := "001";             -- USER_CONFIG
      rom(16#D3#) := "001";             -- GCB_CONFIG
      rom(16#D4#) := "001";             -- POWER_GOOD_DELAY
      rom(16#D6#) := "001";             -- INDUCTOR
      rom(16#D7#) := "001";             -- SNAPSHOT_FAULT_MASK
      rom(16#D9#) := "001";             -- XTEMP_SCALE
      rom(16#DA#) := "001";             -- XTEMP_OFFSET
      rom(16#DD#) := "001";             -- DEADTIME
      rom(16#DE#) := "001";             -- DEADTIME_CONFIG
      rom(16#E0#) := "001";             -- SEQUENCE
      rom(16#E3#) := "001";             -- READ_IOUT1
      rom(16#E7#) := "001";             -- IOUT_AVG_OC_FAULT_LIMIT
      rom(16#E8#) := "001";             -- IOUT_AVG_UC_FAULT_LIMIT
      rom(16#E9#) := "001";             -- MFR_USER_CONFIG
      rom(16#F2#) := "001";             -- READ_IOUT0
      rom(16#F5#) := "001";             -- MFR_VMON_OV_FAULT_LIMIT
      rom(16#F6#) := "001";             -- MFR_VMON_UV_FAULT_LIMIT
      return rom;
   end function bmr467AccessRom;

   function bmr474AccessRom return PMbusAccessArray is
      variable rom : PMbusAccessArray := PMBUS_ACCESS_ROM_INIT_C;
   begin
      -- POWER_MODE is R/W Byte inside the 0x21-0x39 word range (default ROM says word)
      rom(16#34#) := "000";             -- POWER_MODE
      -- Manufacturer-specific word commands (default ROM says byte)
      rom(16#D4#) := "001";             -- READ_MFR_VOUT (Read Word)
      rom(16#DC#) := "001";             -- STATUS_PHASES (Read Word)
      rom(16#FB#) := "001";             -- MFR_SPECIFIC_WRITE_PROTECT (R/W Word)
      -- 0xEE PIN_DETECT_OVERRIDE and 0xEF SLAVE_ADDRESS are bytes: default is correct
      return rom;
   end function bmr474AccessRom;

   constant BMR467_ACCESS_ROM_C : PMbusAccessArray := bmr467AccessRom;
   constant BMR474_ACCESS_ROM_C : PMbusAccessArray := bmr474AccessRom;

end package body FlexPMbusPkg;
