-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: LTM4664 Package File
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

package Ltm4664Pkg is

   -- The following constant controls the access to the registers in the LTM4664 using the AxiLitePMbusMasterCore
   -- Refer to Table 7 in https://www.analog.com/media/en/technical-documentation/data-sheets/ltm4664.pdf
   -- There are three bits per register address: BIT[2] = regAddrSkip, BIT[1:0] = regDataSize
   -- NOTE: ***block*** and ***string*** transfers are not supported by the AxiLitePMbusMasterCore module
   constant LTM4664_ACCESS_ROM_INIT_C : PMbusAccessArray := (
      16#00# to 16#02# => "000", -- byte: PAGE[0x00], OPERATION[0x01], ON_OFF_CONFIG[0x02]
      16#03# to 16#03# => "100", -- send byte: CLEAR_FAULTS[0x03]
      16#04# to 16#04# => "000", -- N/A
      16#05# to 16#06# => "000", -- ***block***: PAGE_PLUS_WRITE[0x05], PAGE_PLUS_READ[0x06]
      16#07# to 16#0F# => "000", -- N/A
      16#10# to 16#10# => "000", -- byte: WRITE_PROTECT[0x10]
      16#11# to 16#12# => "100", -- N/A
      16#13# to 16#14# => "000", -- N/A
      16#15# to 16#16# => "100", -- send byte: STORE_USER_ALL[0x15], RESTORE_USER_ALL[0x16]
      16#17# to 16#18# => "000", -- N/A
      16#19# to 16#19# => "000", -- byte: CAPABILITY[0x19]
      16#1A# to 16#1A# => "000", -- N/A
      16#1B# to 16#1B# => "000", -- ***block***: SMBALERT_MASK[0x1B]
      16#1C# to 16#1F# => "000", -- N/A
      16#20# to 16#20# => "000", -- byte: VOUT_MODE[0x20]
      16#21# to 16#21# => "001", -- word: VOUT_COMMAND[0x21]
      16#22# to 16#23# => "001", -- N/A
      16#24# to 16#27# => "001", -- word: VOUT_MAX[0x24], VOUT_MARGIN_HIGH[0x25], VOUT_MARGIN_LOW[0x26], VOUT_TRANSITION_RATE[0x27]
      16#28# to 16#32# => "001", -- N/A
      16#33# to 16#33# => "001", -- word: FREQUENCY_SWITCH[0x33]
      16#34# to 16#34# => "001", -- N/A
      16#35# to 16#36# => "001", -- word: VIN_ON[0x35], VIN_OFF[0x36]
      16#37# to 16#39# => "001", -- N/A
      16#3A# to 16#3A# => "000", -- N/A
      16#3B# to 16#3C# => "001", -- N/A
      16#3D# to 16#3D# => "000", -- N/A
      16#3E# to 16#3F# => "001", -- N/A
      16#40# to 16#40# => "001", -- word: VOUT_OV_FAULT_LIMIT[0x40]
      16#41# to 16#41# => "000", -- byte: VOUT_OV_FAULT_RESPONSE[0x41]
      16#42# to 16#44# => "001", -- word: VOUT_OV_WARN_LIMIT[0x42], VOUT_UV_WARN_LIMIT[0x43], VOUT_UV_FAULT_LIMIT[0x44]
      16#45# to 16#45# => "000", -- byte: VOUT_UV_FAULT_RESPONSE[0x45]
      16#46# to 16#46# => "001", -- word: IOUT_OC_FAULT_LIMIT[0x46]
      16#47# to 16#47# => "000", -- byte: IOUT_OC_FAULT_RESPONSE[0x47]
      16#48# to 16#48# => "001", -- N/A
      16#49# to 16#49# => "000", -- N/A
      16#4A# to 16#4A# => "001", -- word: IOUT_OC_WARN_LIMIT[0x4A]
      16#4B# to 16#4B# => "001", -- N/A
      16#4C# to 16#4E# => "000", -- N/A
      16#4F# to 16#4F# => "001", -- word: OT_FAULT_LIMIT[0x4F]
      16#50# to 16#50# => "000", -- byte: OT_FAULT_RESPONSE[0x50]
      16#51# to 16#51# => "001", -- word: OT_WARN_LIMIT[0x51]
      16#52# to 16#52# => "001", -- N/A
      16#53# to 16#53# => "001", -- word: UT_FAULT_LIMIT[0x53]
      16#54# to 16#54# => "000", -- byte: UT_FAULT_RESPONSE[0x54]
      16#55# to 16#55# => "001", -- word: VIN_OV_FAULT_LIMIT[0x55]
      16#56# to 16#56# => "000", -- byte: VIN_OV_FAULT_RESPONSE[0x56]
      16#57# to 16#57# => "001", -- N/A
      16#58# to 16#58# => "001", -- word: VIN_UV_WARN_LIMIT[0x58]
      16#59# to 16#59# => "001", -- N/A
      16#5A# to 16#5A# => "000", -- N/A
      16#5B# to 16#5B# => "001", -- N/A
      16#5C# to 16#5C# => "000", -- N/A
      16#5D# to 16#5D# => "001", -- word: IIN_OC_WARN_LIMIT[0x5D]
      16#5E# to 16#5F# => "001", -- N/A
      16#60# to 16#62# => "001", -- word: TON_DELAY[0x60], TON_RISE[0x61], TON_MAX_FAULT_LIMIT[0x62]
      16#63# to 16#63# => "000", -- byte: TON_MAX_FAULT_RESPONSE[0x63]
      16#64# to 16#68# => "001", -- word: TOFF_DELAY[0x64], TOFF_FALL[0x65], TOFF_MAX_WARN_LIMIT[0x66]
      16#69# to 16#69# => "000", -- N/A
      16#6A# to 16#6B# => "001", -- N/A
      16#6C# to 16#77# => "000", -- N/A
      16#78# to 16#78# => "000", -- byte: STATUS_BYTE[0x78]
      16#79# to 16#79# => "001", -- word: STATUS_WORD[0x79]
      16#7A# to 16#7E# => "000", -- byte: STATUS_VOUT[0x7A] to STATUS_CML[0x7E]
      16#7F# to 16#7F# => "000", -- N/A
      16#80# to 16#80# => "000", -- byte: STATUS_MFR_SPECIFIC[0x80]
      16#81# to 16#87# => "000", -- N/A
      16#88# to 16#97# => "001", -- word: READ_VIN[0x88] to READ_PIN[0x97]
      16#98# to 16#98# => "000", -- byte: PMBus_REVISION[0x98]
      16#99# to 16#9A# => "011", -- ***string***: MFR_ID[0x99], MFR_MODEL[0x9A]
      16#9B# to 16#9F# => "011", -- N/A
      16#A0# to 16#A4# => "001", -- N/A
      16#A5# to 16#A5# => "001", -- word: MFR_VOUT_MAX[0xA5]
      16#A6# to 16#A9# => "001", -- N/A
      16#AA# to 16#AB# => "000", -- N/A
      16#AC# to 16#AC# => "000", -- byte: MFR_PIN_ACCURACY[0xAC]
      16#AD# to 16#AF# => "000", -- N/A
      16#B0# to 16#B4# => "001", -- word: USER_DATA_00[0xB0], USER_DATA_01[0xB1], USER_DATA_02[0xB2], USER_DATA_03[0xB3], USER_DATA_04[0xB4]
      16#B5# to 16#CF# => "000", -- N/A
      16#D0# to 16#D1# => "000", -- byte: MFR_CHAN_CONFIG[0xD0], MFR_CONFIG_ALL[0xD1]
      16#D2# to 16#D2# => "001", -- word: MFR_FAULT_PROPAGATE[0xD2]
      16#D3# to 16#D6# => "000", -- byte: MFR_PWM_COMP[0xD3], MFR_PWM_MODE[0xD4], MFR_FAULT_RESPONSE[0xD5], MFR_OT_FAULT_RESPONSE[0xD6]
      16#D7# to 16#D7# => "001", -- word: MFR_IOUT_PEAK[0xD7]
      16#D8# to 16#D8# => "000", -- byte: MFR_ADC_CONTROL[0xD8]
      16#D9# to 16#D9# => "000", -- N/A
      16#DA# to 16#DF# => "001", -- word: MFR_IOUT_CAL_GAIN[0xDA], MFR_RETRY_DELAY[0xDB], MFR_RESTART_DELAY[0xDC], MFR_VOUT_PEAK[0xDD], MFR_VIN_PEAK[0xDE], MFR_TEMPERATURE_1_PEAK[0xDF]
      16#E0# to 16#E0# => "000", -- N/A
      16#E1# to 16#E1# => "001", -- word: MFR_READ_IIN_PEAK[0xE1]
      16#E2# to 16#E2# => "000", -- N/A
      16#E3# to 16#E3# => "100", -- send byte: MFR_CLEAR_PEAKS[0xE3]
      16#E4# to 16#E4# => "001", -- word: MFR_READ_ICHIP[0xE4]
      16#E5# to 16#E5# => "001", -- word: MFR_PADS[0xE5]
      16#E6# to 16#E6# => "000", -- byte: MFR_ADDRESS[0xE6]
      16#E7# to 16#E8# => "001", -- word: MFR_SPECIAL_ID[0xE7], MFR_IIN_CAL_GAIN[0xE8]
      16#E9# to 16#E9# => "000", -- N/A
      16#EA# to 16#EA# => "100", -- send byte: MFR_FAULT_LOG_STORE[0xEA]
      16#EB# to 16#EB# => "000", -- N/A
      16#EC# to 16#EC# => "100", -- send byte: MFR_FAULT_LOG_CLEAR[0xEC]
      16#ED# to 16#ED# => "000", -- N/A
      16#EE# to 16#EE# => "011", -- ***block***: MFR_FAULT_LOG[0xEE]
      16#EF# to 16#EF# => "000", -- byte: MFR_COMMON[0xEF]
      16#F0# to 16#F0# => "100", -- send byte: MFR_COMPARE_USER_ALL[0xF0]
      16#F1# to 16#F3# => "000", -- N/A
      16#F4# to 16#F4# => "001", -- word: MFR_TEMPERATURE_2_PEAK[0xF4]
      16#F5# to 16#F5# => "000", -- byte: MFR_PWM_CONFIG[0xF5]
      16#F6# to 16#F9# => "000", -- word: MFR_IOUT_CAL_GAIN_TC[0xF6], MFR_RVIN[0xF7], MFR_TEMP_1_GAIN[0xF8], MFR_TEMP_1_OFFSET[0xF9]
      16#FA# to 16#FA# => "000", -- byte: MFR_RAIL_ADDRESS[0xFA]
      16#FB# to 16#FB# => "011", -- ***block***: MFR_REAL_TIME[0xFB]
      16#FC# to 16#FC# => "000", -- N/A
      16#FD# to 16#FD# => "100", -- send byte: MFR_RESET[0xFD]
      16#FE# to 16#FF# => "000"  -- N/A
   );

end package Ltm4664Pkg;
