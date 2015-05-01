-------------------------------------------------------------------------------
-- Title         : Version Constant File
-- Project       : COB Zynq DTM
-------------------------------------------------------------------------------
-- File          : Version.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/18/2014
-------------------------------------------------------------------------------
-- Description:
-- Version Constant Module
-------------------------------------------------------------------------------
-- Copyright (c) 2012 by SLAC. All rights reserved.
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Version is

constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"00000006"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "DevBoard: Vivado v2014.4 (x86_64) Built Thu Apr 30 15:01:37 PDT 2015 by ulegat";

end Version;
 
-------------------------------------------------------------------------------
-- Revision History:
-------------------------------------------------------------------------------
-- 04/30/2015 - 00000006      - Same as 4 tested for 2-byte word(added_self test generic).
-- 04/30/2015 - 00000005      - Added TX simulator with variable alignment and delay settable from register.
-- 04/29/2015 - 00000002,3,4  - Testing different AXI stream options (getting data out).
-- 04/27/2015 - 00000001      - Fix Pgp2bAxi registers.
-- 04/27/2015 - 00000000      - First build. PGP working, some registers not working.
