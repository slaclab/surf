-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing status wrapper for CoaXPressOverFiberBridge
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

library surf;
use surf.StdRtlPkg.all;
use surf.CoaXPressPkg.all;

entity CoaXPressOverFiberBridgeStatusWrapper is
   generic (
      LANE0_G : boolean := true);
   port (
      -- XGMII TX interface (txClk156 domain)
      txClk156         : in  sl;
      xgmiiTxd         : out slv(63 downto 0);
      xgmiiTxc         : out slv(7 downto 0);
      -- XGMII RX interface (rxClk156 domain)
      rxClk156         : in  sl;
      xgmiiRxd         : in  slv(63 downto 0);
      xgmiiRxc         : in  slv(7 downto 0);
      -- CXP TX interface (txClk312 domain)
      txClk312         : in  sl;
      txRst312         : in  sl;
      txLsValid        : in  sl;
      txLsData         : in  slv(7 downto 0);
      txLsDataK        : in  sl;
      txLsLaneEn       : in  slv(3 downto 0);
      txLsRate         : in  sl;
      -- CXP RX interface (rxClk312 domain)
      rxClk312         : in  sl;
      rxRst312         : in  sl;
      rxData           : out slv(31 downto 0);
      rxDataK          : out slv(3 downto 0);
      -- Flattened Status Interface
      rxError          : out sl;
      rxAbort          : out sl;
      rxErrorCode      : out slv(3 downto 0);
      seqValid         : out sl;
      seqData          : out slv(23 downto 0);
      seqError         : out sl;
      seqExpected      : out slv(23 downto 0);
      seqErrorExpected : out slv(23 downto 0);
      hkpValid         : out sl;
      hkpData          : out slv(31 downto 0);
      hkpEop           : out sl;
      hkpSof           : out sl;
      hkpError         : out sl;
      hkpWordCount     : out slv(7 downto 0);
      hkpKCodeMask     : out slv(3 downto 0);
      hkpKCodeValid    : out sl;
      hkpType          : out slv(3 downto 0));
end entity CoaXPressOverFiberBridgeStatusWrapper;

architecture mapping of CoaXPressOverFiberBridgeStatusWrapper is

   signal rxStatus : CxpofRxStatusType := CXPOF_RX_STATUS_INIT_C;

begin

   rxError          <= rxStatus.rxError;
   rxAbort          <= rxStatus.rxAbort;
   rxErrorCode      <= rxStatus.rxErrorCode;
   seqValid         <= rxStatus.seqValid;
   seqData          <= rxStatus.seqData;
   seqError         <= rxStatus.seqError;
   seqExpected      <= rxStatus.seqExpected;
   seqErrorExpected <= rxStatus.seqErrorExpected;
   hkpValid         <= rxStatus.hkpValid;
   hkpData          <= rxStatus.hkpData;
   hkpEop           <= rxStatus.hkpEop;
   hkpSof           <= rxStatus.hkpSof;
   hkpError         <= rxStatus.hkpError;
   hkpWordCount     <= rxStatus.hkpWordCount;
   hkpKCodeMask     <= rxStatus.hkpKCodeMask;
   hkpKCodeValid    <= rxStatus.hkpKCodeValid;
   hkpType          <= rxStatus.hkpType;

   U_DUT : entity surf.CoaXPressOverFiberBridge
      generic map (
         TPD_G   => 1 ns,
         LANE0_G => LANE0_G)
      port map (
         -- XGMII TX interface (txClk156 domain)
         txClk156   => txClk156,
         xgmiiTxd   => xgmiiTxd,
         xgmiiTxc   => xgmiiTxc,
         -- XGMII RX interface (rxClk156 domain)
         rxClk156   => rxClk156,
         xgmiiRxd   => xgmiiRxd,
         xgmiiRxc   => xgmiiRxc,
         -- CXP TX interface (txClk312 domain)
         txClk312   => txClk312,
         txRst312   => txRst312,
         txLsValid  => txLsValid,
         txLsData   => txLsData,
         txLsDataK  => txLsDataK,
         txLsLaneEn => txLsLaneEn,
         txLsRate   => txLsRate,
         -- CXP RX interface (rxClk312 domain)
         rxClk312   => rxClk312,
         rxRst312   => rxRst312,
         rxData     => rxData,
         rxDataK    => rxDataK,
         rxStatus   => rxStatus);

end architecture mapping;
