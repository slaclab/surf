-------------------------------------------------------------------------------
-- Title      : SLAC Asynchronous Logic Transceiver (SALT)
-------------------------------------------------------------------------------
-- File       : SaltRx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-01
-- Last update: 2016-07-13
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Asynchronous Logic Transceiver'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Asynchronous Logic Transceiver', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

package SaltPkg is

   constant SSI_GMII_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(1, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 0);
   constant SSI_SALT_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 8);
   constant SALT_MAX_WORDS_C  : natural             := (1500/4);
   constant INTER_GAP_SIZE_C  : natural             := 12;

   constant SOF_C  : slv(31 downto 0) := x"BBBBBBBB";  -- SOF  = start of frame
   constant SOC_C  : slv(31 downto 0) := x"CCCCCCCC";  -- SOC  = start of continuation
   constant EOC_C  : slv(31 downto 0) := x"DDDDDDDD";  -- EOC  = end of continuation
   constant EOF_C  : slv(31 downto 0) := x"EEEEEEEE";  -- EOF  = end of frame w/out errors
   constant EOFE_C : slv(31 downto 0) := x"FFFFFFFF";  -- EOFE = end of frame w/ errors

   constant PREAMBLE_C : slv(31 downto 0) := x"55555555";
   constant SFD_C      : slv(31 downto 0) := x"D5555555";
   
end package;
