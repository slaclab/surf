-------------------------------------------------------------------------------
-- File       : RawEthFramerPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-25
-- Last update: 2016-05-26
-------------------------------------------------------------------------------
-- Description: Raw L2 Ethernet Framer Package File
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

package RawEthFramerPkg is

   -- Ethernet Broadcast Frame
   constant ETH_BCF_C : integer := 2;

   -- dataBytes = 8
   -- tKeepMode = TKEEP_COMP_C;
   -- tUserMode = TUSER_FIRST_LAST_C;
   -- tDestBits = 8
   -- tUserBits = 3
   constant RAW_ETH_CONFIG_INIT_C : AxiStreamConfigType := ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 8, 3);
   
   function ssiGetUserBcf (
      axisConfig : AxiStreamConfigType;
      axisMaster : AxiStreamMasterType)
      return sl;

   procedure ssiSetUserBcf (
      axisConfig : in    AxiStreamConfigType;
      axisMaster : inout AxiStreamMasterType;
      bcf        : in    sl);   

end package RawEthFramerPkg;

package body RawEthFramerPkg is

   function ssiGetUserBcf (
      axisConfig : AxiStreamConfigType;
      axisMaster : AxiStreamMasterType)
      return sl is
      variable ret : sl;
   begin
      ret := axiStreamGetUserBit(axisConfig, axisMaster, ETH_BCF_C, 0);
      return ret;
   end function;

   procedure ssiSetUserBcf (
      axisConfig : in    AxiStreamConfigType;
      axisMaster : inout AxiStreamMasterType;
      bcf        : in    sl) is
   begin
      axiStreamSetUserBit(axisConfig, axisMaster, ETH_BCF_C, bcf, 0);
   end procedure;

end package body RawEthFramerPkg;
