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

constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"00000011"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "DevBoard: Vivado v2015.1 (x86_64) Built Mon Jul 20 17:47:09 PDT 2015 by ulegat";

end Version;
 
-------------------------------------------------------------------------------
-- Revision History:
-------------------------------------------------------------------------------
-- 05/12/2015 - 00000011      - LLRF board TX RX Siggen DAQ loopback test + SPI + RAM
-- 05/12/2015 - 00000010      - RX - ADC board test F2 - 370 MHz out - subclass0
-- 05/12/2015 - 0000000F      - RX - ADC board test F2 - 370 MHz out
-- 05/11/2015 - 0000000E      - RX - ADC board test F2 - 61.44 MHz out
-- 05/11/2015 - 0000000D      - RX - ADC board test F2 
-- 05/08/2015 - 0000000C      - RX - ADC board test F22
-- 05/07/2015 - 0000000B      - RXTX -Added char replacement enable/disable.
-- 05/07/2015 - 0000000A      - RXTX -Added ILAS and made axiLiteReg generic.
-- 05/06/2015 - 00000009      - RXTX -Tx core loopback (devBoard has tx and rx).
-- 04/30/2015 - 00000008      - Fixed enable mechanism for independent lane operation. 
-- 04/30/2015 - 00000007      - Added subclass 0 support, packet size settable from register and AXIS trigger placeholder.
-- 04/30/2015 - 00000006      - Same as 5 tested for 2-byte word(added_self test generic).
-- 04/30/2015 - 00000005      - Added TX simulator with variable alignment and delay settable from register.
-- 04/29/2015 - 00000002,3,4  - Testing different AXI stream options (getting data out).
-- 04/27/2015 - 00000001      - Fix Pgp2bAxi registers.
-- 04/27/2015 - 00000000      - First build. PGP working, some registers not working.
