-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Version.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-09-29
-- Last update: 2015-04-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

package Version is

  constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := X"00000000";  -- MAKE_VERSION
  constant BUILD_STAMP_C : string := "Feb: Vivado v2014.4 (x86_64) Built Tue Mar 24 15:44:36 PDT 2015 by bareese";

end Version;

-------------------------------------------------------------------------------
-- Revision History:
