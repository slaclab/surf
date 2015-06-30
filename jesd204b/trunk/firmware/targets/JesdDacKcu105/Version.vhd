-------------------------------------------------------------------------------
-- Title      : Version Constant File
-------------------------------------------------------------------------------
-- File       : Version.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-06-04
-- Last update: 2015-06-04
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.ALL;

package Version is

constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"00000005"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "JesdDacKcu105: Vivado v2015.1 (x86_64) Built Tue Jun 30 14:30:17 PDT 2015 by ulegat";

end Version;
 
-------------------------------------------------------------------------------
-- Revision History:
-------------------------------------------------------------------------------
-- 06/05/2015 - 00000000      - Without pgp
-- 06/12/2015 - 00000001      - First complete system
-- 06/12/2015 - 00000002      - Added 10 Mhz clock out
-- 06/12/2015 - 00000003      - Changed leds, added pulse
-- 06/12/2015 - 00000004      - Changed leds, added pulse, 185 reference
-- 06/19/2015 - 00000005      - Tx buff disabled,185 reference