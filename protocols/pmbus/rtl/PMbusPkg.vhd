-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PMBus Support Package
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;

package PMbusPkg is

   -- BIT[2] = regAddrSkip, BIT[1:0] = regDataSize
   type PMbusAccessArray is array (0 to 255) of slv(2 downto 0);

   -- The following constant controls the access to the registers in the PMBUS device using the AxiLitePMbusMasterCore.
   -- The values listed here are simplified defaults based on table 26 in http://pmbus.org/Assets/PDFS/Public/PMBus_Specification_Part_II_Rev_1-1_20070205.pdf
   -- A custom version may be needed to reflect the access to manufacturer defined registers as per the device datasheet.
   constant PMBUS_ACCESS_ROM_INIT_C : PMbusAccessArray := (
      16#00# to 16#02# => "000",
      16#03# to 16#03# => "100",
      16#04# to 16#10# => "000",
      16#11# to 16#12# => "100",
      16#13# to 16#14# => "000",
      16#15# to 16#16# => "100",
      16#17# to 16#20# => "000",
      16#21# to 16#39# => "001",
      16#3A# to 16#3A# => "000",
      16#3B# to 16#3C# => "001",
      16#3D# to 16#3D# => "000",
      16#3E# to 16#40# => "001",
      16#41# to 16#41# => "000",
      16#42# to 16#44# => "001",
      16#45# to 16#45# => "000",
      16#46# to 16#46# => "001",
      16#47# to 16#47# => "000",
      16#48# to 16#48# => "001",
      16#49# to 16#49# => "000",
      16#4A# to 16#4B# => "001",
      16#4C# to 16#4E# => "000",
      16#4F# to 16#4F# => "001",
      16#50# to 16#50# => "000",
      16#51# to 16#53# => "001",
      16#54# to 16#54# => "000",
      16#55# to 16#55# => "001",
      16#56# to 16#56# => "000",
      16#57# to 16#59# => "001",
      16#5A# to 16#5A# => "000",
      16#5B# to 16#5B# => "001",
      16#5C# to 16#5C# => "000",
      16#5D# to 16#62# => "001",
      16#63# to 16#63# => "000",
      16#64# to 16#68# => "001",
      16#69# to 16#69# => "000",
      16#6A# to 16#6B# => "001",
      16#6C# to 16#78# => "000",
      16#79# to 16#79# => "001",
      16#7A# to 16#87# => "000",
      16#88# to 16#97# => "001",
      16#98# to 16#98# => "000",
      16#99# to 16#9F# => "011",
      16#A0# to 16#A9# => "001",
      16#AA# to 16#FF# => "000");

end package PMbusPkg;
