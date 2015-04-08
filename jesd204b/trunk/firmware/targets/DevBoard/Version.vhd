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

constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"00000000"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "DataDpm: Vivado v2014.4 (x86_64) Built Wed Apr  8 11:23:07 PDT 2015 by bareese";

end Version;
 
-------------------------------------------------------------------------------
-- Revision History:
-------------------------------------------------------------------------------

