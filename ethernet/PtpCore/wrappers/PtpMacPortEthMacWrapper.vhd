-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for the PtpMacPortEthMac composition
-------------------------------------------------------------------------------
-- Flattens the timing-port records for the bench. The PHC tuple is driven by
-- the bench every cycle and feeds the port and two PtpRxTimestampAdapter
-- oracles: one on the RX pins and one in TX-observe mode (with the egress
-- latency, as PtpTxTimestampTap applies it) on the TX pins. Captures,
-- completions and RX metadata are exposed packed with the PtpPkg toSlv
-- helpers. RX pins come from the MAC's own TX pins (rxInject = '0') or from
-- the bench (rxInject = '1').
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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.EthMacPkg.all;
use surf.PtpPkg.all;

entity PtpMacPortEthMacWrapper is
   generic (
      TPD_G             : time             := 1 ns;
      PHY_TYPE_G        : string           := "GMII";
      CSUM_EN_G         : boolean          := false;
      INGRESS_LATENCY_G : slv(63 downto 0) := x"0000000000000000";
      EGRESS_LATENCY_G  : slv(63 downto 0) := x"0000000000000000");
   port (
      clk             : in  sl;
      rst             : in  sl;
      phyReady        : in  sl;
      -- PHC tuple for the current cycle
      phcSeconds      : in  slv(47 downto 0);
      phcNanoseconds  : in  slv(31 downto 0);
      phcFraction     : in  slv(31 downto 0);
      phcGeneration   : in  slv(31 downto 0);
      phcTicks        : in  slv(63 downto 0);
      phcIncrement    : in  slv(63 downto 0);
      phcTimeValid    : in  sl;
      captureAbort    : in  sl;
      -- Lifecycle
      openAdmission   : in  sl;
      drainRequest    : in  sl;
      abortRequest    : in  sl;
      cancelAck       : in  sl;
      admissionOpen   : out sl;
      drainIdle       : out sl;
      cancelRequest   : out sl;
      abortDone       : out sl;
      generation      : out slv(15 downto 0);
      faults          : out slv(2 downto 0);
      counters        : out slv(8*32-1 downto 0);
      -- Controller TX
      sAxisTValid     : in  sl;
      sAxisTData      : in  slv(127 downto 0);
      sAxisTKeep      : in  slv(15 downto 0);
      sAxisTLast      : in  sl;
      sAxisTReady     : out sl;
      sAxisSof        : in  sl;
      sAxisEofe       : in  sl;
      txCookie        : in  slv(31 downto 0);
      txTimestamp     : in  sl;
      txFrameLength   : in  slv(15 downto 0);
      txGeneration    : in  slv(15 downto 0);
      cmplValid       : out sl;
      cmplData        : out slv(PTP_MAC_PORT_TX_COMPLETION_BITS_C-1 downto 0);
      cmplReady       : in  sl;
      -- Controller RX
      mAxisTValid     : out sl;
      mAxisTData      : out slv(127 downto 0);
      mAxisTKeep      : out slv(15 downto 0);
      mAxisTLast      : out sl;
      mAxisTId        : out slv(7 downto 0);
      mAxisTReady     : in  sl;
      mAxisSof        : out sl;
      mAxisEofe       : out sl;
      rxMeta          : out slv(PTP_MAC_PORT_RX_META_BITS_C-1 downto 0);
      -- Wire
      rxInject        : in  sl;
      injXgmiiRxd     : in  slv(63 downto 0);
      injXgmiiRxc     : in  slv(7 downto 0);
      injGmiiRxd      : in  slv(7 downto 0);
      injGmiiRxDv     : in  sl;
      injGmiiRxEr     : in  sl;
      xgmiiTxd        : out slv(63 downto 0);
      xgmiiTxc        : out slv(7 downto 0);
      gmiiTxd         : out slv(7 downto 0);
      gmiiTxEn        : out sl;
      gmiiTxEr        : out sl;
      -- Oracles
      rxOracleSof     : out sl;
      rxOracleCapture : out slv(PTP_RX_CAPTURE_BITS_C-1 downto 0);
      txOracleSof     : out sl;
      txOracleCapture : out slv(PTP_RX_CAPTURE_BITS_C-1 downto 0));
end entity PtpMacPortEthMacWrapper;

architecture rtl of PtpMacPortEthMacWrapper is

   constant CONFIG_C : AxiStreamConfigType := EMAC_AXIS_CONFIG_C;

   signal phcTime     : PtpTimeType      := PTP_TIME_INIT_C;
   signal phcStatus   : PtpPhcStatusType := PTP_PHC_STATUS_INIT_C;
   signal control     : PtpMacPortControlType;
   signal status      : PtpMacPortStatusType;
   signal portCounter : PtpMacPortCountersType;
   signal ethConfig   : EthMacConfigType := ETH_MAC_CONFIG_INIT_C;
   signal txMaster    : PtpMacPortTxMasterType;
   signal txSlave     : AxiStreamSlaveType;
   signal completion  : PtpMacPortTxCompletionMasterType;
   signal rxMaster    : PtpMacPortRxMasterType;

   signal txd     : slv(63 downto 0);
   signal txc     : slv(7 downto 0);
   signal gTxd    : slv(7 downto 0);
   signal gTxEn   : sl;
   signal gTxEr   : sl;
   signal rxd     : slv(63 downto 0);
   signal rxc     : slv(7 downto 0);
   signal gRxd    : slv(7 downto 0);
   signal gRxDv   : sl;
   signal gRxEr   : sl;
   signal rxOracle : AxiStreamMasterType;
   signal txOracle : AxiStreamMasterType;
   signal rxOrCap  : PtpRxCaptureType;
   signal txOrCap  : PtpRxCaptureType;

begin

   phcTime.seconds      <= phcSeconds;
   phcTime.nanoseconds  <= phcNanoseconds;
   phcTime.fraction     <= phcFraction;
   phcStatus.generation <= phcGeneration;
   phcStatus.ticks      <= phcTicks;
   phcStatus.increment  <= phcIncrement;
   phcStatus.timeValid  <= phcTimeValid;

   control.openAdmission <= openAdmission;
   control.drainRequest  <= drainRequest;
   control.abortRequest  <= abortRequest;
   control.cancelAck     <= cancelAck;

   admissionOpen <= status.admissionOpen;
   drainIdle     <= status.drainIdle;
   cancelRequest <= status.cancelRequest;
   abortDone     <= status.abortDone;
   generation    <= status.transportGeneration;
   faults        <= status.faultTokenProtocol & status.faultClockEnable & status.faultGeneration;

   counters <= portCounter.txRejected & portCounter.txFlushed & portCounter.txDiscarded &
               portCounter.txWireError & portCounter.txSent & portCounter.rxLost &
               portCounter.rxDropped & portCounter.rxDelivered;

   ethConfig.macAddress  <= x"554433221100";
   ethConfig.filtEnable  <= '0';
   ethConfig.pauseEnable <= '0';
   ethConfig.ipCsumEn    <= toSl(CSUM_EN_G);
   ethConfig.tcpCsumEn   <= toSl(CSUM_EN_G);
   ethConfig.udpCsumEn   <= toSl(CSUM_EN_G);
   ethConfig.dropOnPause <= '0';

   txComb : process (sAxisEofe, sAxisSof, sAxisTData, sAxisTKeep, sAxisTLast, sAxisTValid,
                     txCookie, txFrameLength, txGeneration, txTimestamp) is
      variable v : PtpMacPortTxMasterType;
   begin
      v                           := PTP_MAC_PORT_TX_MASTER_INIT_C;
      v.frame.tValid              := sAxisTValid;
      v.frame.tData(127 downto 0) := sAxisTData;
      v.frame.tKeep(15 downto 0)  := sAxisTKeep;
      v.frame.tLast               := sAxisTLast;
      ssiSetUserSof(CONFIG_C, v.frame, sAxisSof);
      ssiSetUserEofe(CONFIG_C, v.frame, sAxisEofe);
      v.request.cookie              := txCookie;
      v.request.timestamp           := txTimestamp;
      v.request.frameLength         := txFrameLength;
      v.request.transportGeneration := txGeneration;
      txMaster                      <= v;
   end process txComb;

   sAxisTReady <= txSlave.tReady;
   cmplValid   <= completion.valid;
   cmplData    <= toSlv(completion.data);

   rxView : process (rxMaster) is
   begin
      mAxisTValid <= rxMaster.frame.tValid;
      mAxisTData  <= rxMaster.frame.tData(127 downto 0);
      mAxisTKeep  <= rxMaster.frame.tKeep(15 downto 0);
      mAxisTLast  <= rxMaster.frame.tLast;
      mAxisTId    <= rxMaster.frame.tId;
      mAxisSof    <= ssiGetUserSof(CONFIG_C, rxMaster.frame);
      mAxisEofe   <= ssiGetUserEofe(CONFIG_C, rxMaster.frame);
      rxMeta      <= toSlv(rxMaster.meta);
   end process rxView;

   rxd   <= injXgmiiRxd when rxInject = '1' else txd;
   rxc   <= injXgmiiRxc when rxInject = '1' else txc;
   gRxd  <= injGmiiRxd  when rxInject = '1' else gTxd;
   gRxDv <= injGmiiRxDv when rxInject = '1' else gTxEn;
   gRxEr <= injGmiiRxEr when rxInject = '1' else gTxEr;

   xgmiiTxd <= txd;
   xgmiiTxc <= txc;
   gmiiTxd  <= gTxd;
   gmiiTxEn <= gTxEn;
   gmiiTxEr <= gTxEr;

   rxOracleSof     <= rxOracle.tValid and ssiGetUserSof(PTP_RX_AXIS_CONFIG_C, rxOracle);
   txOracleSof     <= txOracle.tValid and ssiGetUserSof(PTP_RX_AXIS_CONFIG_C, txOracle);
   rxOracleCapture <= toSlv(rxOrCap);
   txOracleCapture <= toSlv(txOrCap);

   U_DUT : entity surf.PtpMacPortEthMac
      generic map (
         TPD_G             => TPD_G,
         PHY_TYPE_G        => PHY_TYPE_G,
         INGRESS_LATENCY_G => INGRESS_LATENCY_G,
         EGRESS_LATENCY_G  => EGRESS_LATENCY_G)
      port map (
         clk              => clk,
         rst              => rst,
         phyReady         => phyReady,
         ethConfig        => ethConfig,
         ethStatus        => open,
         phcTime          => phcTime,
         phcStatus        => phcStatus,
         captureAbort     => captureAbort,
         control          => control,
         status           => status,
         counters         => portCounter,
         txMaster         => txMaster,
         txSlave          => txSlave,
         completionMaster => completion,
         completionReady  => cmplReady,
         rxMaster         => rxMaster,
         rxReady          => mAxisTReady,
         xgmiiRxd         => rxd,
         xgmiiRxc         => rxc,
         xgmiiTxd         => txd,
         xgmiiTxc         => txc,
         gmiiRxd          => gRxd,
         gmiiRxDv         => gRxDv,
         gmiiRxEr         => gRxEr,
         gmiiTxd          => gTxd,
         gmiiTxEn         => gTxEn,
         gmiiTxEr         => gTxEr);

   U_RxOracle : entity surf.PtpRxTimestampAdapter
      generic map (
         TPD_G             => TPD_G,
         TX_OBSERVE_G      => false,
         PHY_TYPE_G        => PHY_TYPE_G,
         INGRESS_LATENCY_G => INGRESS_LATENCY_G)
      port map (
         clk          => clk,
         rst          => rst,
         rxFlush      => '0',
         phyReady     => phyReady,
         phcTime      => phcTime,
         phcStatus    => phcStatus,
         captureAbort => captureAbort,
         xgmiiRxd     => rxd,
         xgmiiRxc     => rxc,
         gmiiRxd      => gRxd,
         gmiiRxDv     => gRxDv,
         gmiiRxEr     => gRxEr,
         rxMaster     => rxOracle,
         rxCapture    => rxOrCap);

   U_TxOracle : entity surf.PtpRxTimestampAdapter
      generic map (
         TPD_G             => TPD_G,
         TX_OBSERVE_G      => true,
         PHY_TYPE_G        => PHY_TYPE_G,
         INGRESS_LATENCY_G => slv(-signed(EGRESS_LATENCY_G)))
      port map (
         clk          => clk,
         rst          => rst,
         rxFlush      => '0',
         phyReady     => phyReady,
         phcTime      => phcTime,
         phcStatus    => phcStatus,
         captureAbort => captureAbort,
         xgmiiRxd     => txd,
         xgmiiRxc     => txc,
         gmiiRxd      => gTxd,
         gmiiRxDv     => gTxEn,
         gmiiRxEr     => gTxEr,
         rxMaster     => txOracle,
         rxCapture    => txOrCap);

end architecture rtl;
