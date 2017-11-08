-------------------------------------------------------------------------------
-- File       : SaltPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-01
-- Last update: 2017-11-08
-------------------------------------------------------------------------------
-- Description: SLAC Asynchronous Logic Transceiver (SALT) Package File
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
use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

package SaltPkg is

   constant SSI_GMII_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 1,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant SSI_SALT_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 4,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant SALT_MAX_WORDS_C : natural := (1500/4);
   constant INTER_GAP_SIZE_C : natural := 12;

   constant SOF_C  : slv(31 downto 0) := x"BBBBBBBB";  -- SOF  = start of frame
   constant SOC_C  : slv(31 downto 0) := x"CCCCCCCC";  -- SOC  = start of continuation
   constant EOC_C  : slv(31 downto 0) := x"DDDDDDDD";  -- EOC  = end of continuation
   constant EOF_C  : slv(31 downto 0) := x"EEEEEEEE";  -- EOF  = end of frame w/out errors
   constant EOFE_C : slv(31 downto 0) := x"FFFFFFFF";  -- EOFE = end of frame w/ errors

   constant PREAMBLE_C : slv(31 downto 0) := x"55555555";
   constant SFD_C      : slv(31 downto 0) := x"D5555555";

end package;
