-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: DSP VHDL Package File
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

use ieee.fixed_float_types.all;
use ieee.float_pkg.all;

package DspPkg is

   -- IEEE 754 half precision: https://en.wikipedia.org/wiki/Half-precision_floating-point_format
   subtype UNRESOLVED_float16 is UNRESOLVED_float (5 downto -10);
   alias U_float16 is UNRESOLVED_float16;
   subtype float16 is float (5 downto -10);

   -- Useful constants
   constant FP16_ZERO_C    : float16 := x"0000";
   constant FP16_NEG_ONE_C : float16 := x"bC00";
   constant FP16_POS_ONE_C : float16 := x"3C00";

   constant FP32_ZERO_C    : float32 := x"00000000";
   constant FP32_NEG_ONE_C : float32 := x"bf800000";
   constant FP32_POS_ONE_C : float32 := x"3f800000";

   constant FP64_ZERO_C    : float64 := x"0000000000000000";
   constant FP64_NEG_ONE_C : float64 := x"bff0000000000000";
   constant FP64_POS_ONE_C : float64 := x"3ff0000000000000";

   constant FP128_ZERO_C    : float128 := x"00000000000000000000000000000000";
   constant FP128_NEG_ONE_C : float128 := x"bfff0000000000000000000000000000";
   constant FP128_POS_ONE_C : float128 := x"3fff0000000000000000000000000000";

end package DspPkg;

package body DspPkg is

end package body DspPkg;
