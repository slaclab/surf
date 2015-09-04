-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcTxEmuPkg.vhd
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

package AtlasTtcTxEmuPkg is

   constant ATLAS_TTC_TX_EMU_TRIG_1S_C     : real    := 40.0E+6;
   constant ATLAS_TTC_TX_EMU_TRIG_1HZ_C    : natural := (getTimeRatio(ATLAS_TTC_TX_EMU_TRIG_1S_C, 1.0E+0) - 1);
   constant ATLAS_TTC_TX_EMU_TRIG_10HZ_C   : natural := (getTimeRatio(ATLAS_TTC_TX_EMU_TRIG_1S_C, 1.0E+1) - 1);
   constant ATLAS_TTC_TX_EMU_TRIG_100HZ_C  : natural := (getTimeRatio(ATLAS_TTC_TX_EMU_TRIG_1S_C, 1.0E+2) - 1);
   constant ATLAS_TTC_TX_EMU_TRIG_1KHZ_C   : natural := (getTimeRatio(ATLAS_TTC_TX_EMU_TRIG_1S_C, 1.0E+3) - 1);
   constant ATLAS_TTC_TX_EMU_TRIG_10KHZ_C  : natural := (getTimeRatio(ATLAS_TTC_TX_EMU_TRIG_1S_C, 1.0E+4) - 1);
   constant ATLAS_TTC_TX_EMU_TRIG_100KHZ_C : natural := (getTimeRatio(ATLAS_TTC_TX_EMU_TRIG_1S_C, 1.0E+5) - 1);

   type AtlasTtcTxEmuStatusType is record
      busy         : sl;
      trigBurstCnt : slv(31 downto 0);
      bcrBurstCnt  : slv(31 downto 0);
      ecrBurstCnt  : slv(31 downto 0);
   end record;
   constant ATLAS_TTC_TX_EMU_STATUS_INIT_C : AtlasTtcTxEmuStatusType := (
      '0',
      (others => '0'),
      (others => '0'),
      (others => '0'));

   type AtlasTtcTxEmuConfigType is record
      enbleContinousMode : sl;
      enbleBurstMode     : sl;
      burstRst           : sl;
      trigBurstCnt       : slv(31 downto 0);
      bcrBurstCnt        : slv(31 downto 0);
      ecrBurstCnt        : slv(31 downto 0);
      iacValid           : sl;
      iacData            : slv(31 downto 0);
      rstCnt             : slv(2 downto 0);
      trigPeriod         : slv(31 downto 0);
      ecrPeriod          : slv(31 downto 0);
      bcrPeriod          : slv(31 downto 0);
   end record;
   constant ATLAS_TTC_TX_EMU_CONFIG_INIT_C : AtlasTtcTxEmuConfigType := (
      '0',
      '0',
      '1',
      toSlv(1, 32),
      toSlv(1, 32),
      toSlv(1, 32),
      '0',
      (others => '0'),
      "111",
      toSlv(ATLAS_TTC_TX_EMU_TRIG_100KHZ_C, 32),
      toSlv(6060605, 32),               -- 0.1 Hz  
      toSlv(53, 32));                   -- 11 kHz

end package AtlasTtcTxEmuPkg;
