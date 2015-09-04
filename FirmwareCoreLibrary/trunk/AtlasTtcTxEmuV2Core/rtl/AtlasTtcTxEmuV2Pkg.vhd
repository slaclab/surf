-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcTxEmuV2Pkg.vhd
-- Author     : Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-09-16
-- Last update: 2014-07-15
-- Platform   : Vivado 2014.1
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   This package contains all the constants, types, and records
--                for AsmPackEmu.vhd
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package AtlasTtcTxEmuV2Pkg is

   type AtlasTtcTxEmuV2EngineStatusType is record
      empty    : sl;
      full     : sl;
      overflow : sl;
      running  : sl;
   end record;
   constant ATLAS_TTC_TX_EMU_V2_ENGINE_STATUS_INIT_C : AtlasTtcTxEmuV2EngineStatusType := (
      empty    => '1',
      full     => '0',
      overflow => '0',
      running  => '0');

   type AtlasTtcTxEmuV2EngineConfigType is record
      wrEn     : sl;
      data     : slv(31 downto 0);
      preset   : slv(31 downto 0);
      startCmd : sl;
      stopCmd  : sl;
   end record;
   constant ATLAS_TTC_TX_EMU_V2_ENGINE_CONFIG_INIT_C : AtlasTtcTxEmuV2EngineConfigType := (
      wrEn     => '0',
      data     => (others=>'0'),
      preset   => (others=>'0'),
      startCmd => '0',
      stopCmd  => '0');
      
   type AtlasTtcTxEmuV2StatusType is record
      busy     : sl;
      engineA  : AtlasTtcTxEmuV2EngineStatusType;
      engineB  : AtlasTtcTxEmuV2EngineStatusType;
   end record;
   constant ATLAS_TTC_TX_EMU_V2_STATUS_INIT_C : AtlasTtcTxEmuV2StatusType := (
      busy    => '0',
      engineA => ATLAS_TTC_TX_EMU_V2_ENGINE_STATUS_INIT_C,
      engineB => ATLAS_TTC_TX_EMU_V2_ENGINE_STATUS_INIT_C);
      
   type AtlasTtcTxEmuV2ConfigType is record
      reset    : sl;
      engineA  : AtlasTtcTxEmuV2EngineConfigType;
      engineB  : AtlasTtcTxEmuV2EngineConfigType;
   end record;
   constant ATLAS_TTC_TX_EMU_V2_CONFIG_INIT_C : AtlasTtcTxEmuV2ConfigType := (
      reset   => '1',
      engineA => ATLAS_TTC_TX_EMU_V2_ENGINE_CONFIG_INIT_C,
      engineB => ATLAS_TTC_TX_EMU_V2_ENGINE_CONFIG_INIT_C);      
      
end package AtlasTtcTxEmuV2Pkg;
