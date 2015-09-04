-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcRxPkg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-03-14
-- Last update: 2015-02-27
-- Platform   : Vivado 2014.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;

package AtlasTtcRxPkg is

   -- Clock Monitoring Constants
   constant ATLAS_TTC_RX_REF_CLK_FREQ_C      : real    := 200.0E+6;   -- units of Hz
   constant ATLAS_TTC_RX_REFRESH_RATE_C      : real    := 1.0E+3;     -- units of Hz
   constant ATLAS_TTC_RX_CDR_CLK_FREQ_C      : real    := 160.32E+6;  -- units of Hz   
   constant ATLAS_TTC_RX_BAND_WIDTH_C        : real    := 1.0E+6;     -- units of Hz   
   constant ATLAS_TTC_RX_CLK_LOWER_LIMIT_C   : real    := (ATLAS_TTC_RX_CDR_CLK_FREQ_C-ATLAS_TTC_RX_BAND_WIDTH_C);  -- units of Hz   
   constant ATLAS_TTC_RX_CLK_UPPER_LIMIT_C   : real    := (ATLAS_TTC_RX_CDR_CLK_FREQ_C+ATLAS_TTC_RX_BAND_WIDTH_C);  -- units of Hz
   constant ATLAS_TTC_RX_LOCK_RST_DURATION_C : natural := getTimeRatio(ATLAS_TTC_RX_CDR_CLK_FREQ_C, 1.0E+0);  -- 1 second lockout reset  

   type AtlasTTCRxBcType is record
      valid   : sl;
      cmdData : slv(7 downto 0);
   end record;
   constant ATLAS_TTC_RX_BC_INIT_C : AtlasTTCRxBcType := (
      valid   => '0',
      cmdData => (others => '0'));     

   type AtlasTTCRxIacType is record
      valid    : sl;
      addr     : slv(13 downto 0);
      bitE     : sl;
      reserved : sl;                    -- Should always be '1'
      subAddr  : slv(7 downto 0);
      data     : slv(7 downto 0);
   end record;
   constant ATLAS_TTC_RX_IAC_INIT_C : AtlasTTCRxIacType := (
      valid    => '0',
      addr     => (others => '0'),
      bitE     => '0',
      reserved => '1',
      subAddr  => (others => '0'),
      data     => (others => '0')); 

   type AtlasTTCRxOutType is record
      trigL1      : sl;
      ecrDet      : sl;
      bunchCnt    : slv(11 downto 0);
      bunchRstCnt : slv(7 downto 0);
      eventCnt    : slv(23 downto 0);
      eventRstCnt : slv(7 downto 0);
      bc          : AtlasTTCRxBcType;
      iac         : AtlasTTCRxIacType;
   end record;
   constant ATLAS_TTC_RX_OUT_INIT_C : AtlasTTCRxOutType := (
      trigL1      => '0',
      ecrDet      => '0',
      bunchCnt    => (others => '0'),
      bunchRstCnt => (others => '0'),
      eventCnt    => (others => '0'),
      eventRstCnt => (others => '0'),
      bc          => ATLAS_TTC_RX_BC_INIT_C,
      iac         => ATLAS_TTC_RX_IAC_INIT_C);         

   type AtlasTTCRxDelayInType is record
      load : sl;
      rst  : sl;
      data : slv(4 downto 0);
   end record;
   constant ATLAS_TTC_RX_DELAY_IN_INIT_C : AtlasTTCRxDelayInType := (
      load => '0',
      rst  => '0',
      data => (others => '0'));   

   type AtlasTTCRxDelayOutType is record
      rdy  : sl;
      data : slv(4 downto 0);
   end record;
   constant ATLAS_TTC_RX_DELAY_OUT_INIT_C : AtlasTTCRxDelayOutType := (
      rdy  => '0',
      data => (others => '0'));   

   type AtlasTTCRxStatusType is record
      -- Clock Status (atlasClk160MHz domain)
      refClkLocked   : sl;
      freqLocked     : sl;
      clkLocked      : sl;
      freqMeasured   : slv(31 downto 0);  -- Units of Hz
      -- Timing Data FIFO (atlasClk160MHz domain)
      fifoAlmostFull : sl;
      fifoOverFlow   : sl;
      -- Deserialization Status (atlasClk160MHz domain)
      bpmLocked      : sl;
      bpmErr         : sl;
      deSerErr       : sl;
      -- Hamming Decode Status (atlasClk160MHz domain)
      sBitErrBc      : sl;
      dBitErrBc      : sl;
      sBitErrIac     : sl;
      dBitErrIac     : sl;
      -- TTC-RX Output Bus (atlasClk160MHz domain)
      ttcRx          : AtlasTTCRxOutType;
      busyRateCnt    : slv(31 downto 0);
      busyRate       : slv(31 downto 0);
      busyIn         : sl;
      -- EC and ECR debug
      debugEC        : slv(23 downto 0);
      debugECR       : slv(7 downto 0);
      -- IO-Delay Signals (refClk200MHz domain)
      delayOut       : AtlasTTCRxDelayOutType;
   end record;
   constant ATLAS_TTC_RX_STATUS_INIT_C : AtlasTTCRxStatusType := (
      -- Clock Status
      refClkLocked   => '0',
      freqLocked     => '0',
      clkLocked      => '0',
      freqMeasured   => (others => '0'),
      -- Timing Data FIFO
      fifoAlmostFull => '0',
      fifoOverFlow   => '0',
      -- Deserialization Status
      bpmLocked      => '0',
      bpmErr         => '0',
      deSerErr       => '0',
      -- Hamming Decode Status
      sBitErrBc      => '0',
      dBitErrBc      => '0',
      sBitErrIac     => '0',
      dBitErrIac     => '0',
      -- TTC-RX Output Bus
      ttcRx          => ATLAS_TTC_RX_OUT_INIT_C,
      busyRateCnt    => (others => '0'),
      busyRate       => (others => '0'),
      busyIn         => '0',
      -- EC and ECR debug
      debugEC        => (others => '0'),
      debugECR       => (others => '0'),
      -- IO-Delay Signals
      delayOut       => ATLAS_TTC_RX_DELAY_OUT_INIT_C);  

   type AtlasTTCRxConfigType is record
      rstL1Id         : sl;
      presetECR       : slv(7 downto 0);
      pauseECR        : sl;
      forceBusy       : sl;
      busyRateRst     : sl;
      serDataEdgeSel  : sl;
      ignoreExtBusyIn : sl;
      ignoreFifoFull  : sl;
      delayIn         : AtlasTTCRxDelayInType;
   end record;
   constant ATLAS_TTC_RX_CONFIG_INIT_C : AtlasTTCRxConfigType := (
      rstL1Id         => '1',
      presetECR       => (others => '0'),
      pauseECR        => '0',
      forceBusy       => '0',
      busyRateRst     => '1',
      serDataEdgeSel  => '0',
      ignoreExtBusyIn => '1',
      ignoreFifoFull  => '1',
      delayIn         => ATLAS_TTC_RX_DELAY_IN_INIT_C);      

end package AtlasTtcRxPkg;
