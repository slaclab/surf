-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
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



------------------------------------------------------------------------
-- Supported low speed connection bit rates
------------------------------------------------------------------------
-- Supported Bit Rates  | Unit Interval (UI) | Used at Connection Speeds
------------------------------------------------------------------------
--    20.83 Mbps        |     48.000 ns      |     CXP-1 to CXP-6
--    41.6  Mbps        |     24.000 ns      |     CXP10, CXP-12
------------------------------------------------------------------------

--------------------------------------------
-- K-code usage
--------------------------------------------
-- K-Code |    Function
-- K27.7  | Start of data packet indication
-- K28.6  | I/O acknowledgment
-- K28.1  | Used for alignment
-- K28.2  | Trigger indication
-- K28.3  | Stream marker – see section 10.2
-- K28.4  | Trigger indication
-- K28.5  | Used for alignment
-- K29.7  | End of data packet indication
--------------------------------------------


-------------------------------------------------------------------------------
-- Note:
-------------------------------------------------------------------------------
-- The recommended heartbeat message interval (see section 9.7) is 10 milliseconds.
-- The low speed connection bit rate shall be certain fractions of 125 Mbps
-- The common use case is for trigger from Host to Device.
-- In CXP v1.x, LinkTrigger0 was called “rising edge” and LinkTrigger1 “falling edge”.
-- The Device or Host transmitting a trigger packet shall use the following rules:
--    After completion of a trigger packet transmission it shall not send a new trigger packet until it has
--    received an acknowledgment from the Host or Device receiving the packet.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.Code8b10bPkg.all;

package CoaXPressPkg is

   constant CXP_HS_LINK_TRIG_SIZE_C : positive := 3; -- 3 words
   constant CXP_HS_LINK_TRIG_C      : slv(31 downto 0) := K_28_2_C & K_28_2_C & K_28_2_C & K_28_2_C;

   constant CXP_IO_ACK_SIZE_C : positive := 2; -- 2 words
   constant CXP_IO_ACK_C      : slv(31 downto 0) := K_28_6_C & K_28_6_C & K_28_6_C & K_28_6_C;

   constant CXP_IDLE_K_C : slv(3 downto 0) := "0111";
   constant CXP_IDLE_C   : slv(31 downto 0) := D_21_5_C & K_28_1_C & K_28_1_C & K_28_5_C;
   constant CXP_SOF_C    : slv(31 downto 0) := K_27_7_C & K_27_7_C & K_27_7_C & K_27_7_C;
   constant CXP_EOF_C    : slv(31 downto 0) := K_29_7_C & K_29_7_C & K_29_7_C & K_29_7_C;

   type CxpSpeedType is (
      CXP_1_C, -- 1.250
      CXP_2_C, -- 2.500
      CXP_3_C, -- 3.125
      CXP_6_C, -- 6.250
      CXP_10_C, -- 10.000
      CXP_12_C); -- 12.500

end package CoaXPressPkg;

package body CoaXPressPkg is

end package body CoaXPressPkg;
