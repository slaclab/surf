-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Timing-port RTL-backend adapters against the passive taps.
--
-- Instantiates PtpMacPortEthMac with PtpMacPortRxAdapter and
-- PtpMacPortTxAdapter, and places PtpRxTimestampTap and PtpTxTimestampTap on
-- the same RX and TX pins as oracles. Both paths share the bench-driven PHC
-- tuple, the RX flush and the record ready. Delay_Req frames enter the TX
-- adapter; RX pins come from the MAC's TX pins (rxInject = '0') or the bench.
-- Records are exposed losslessly packed (ptpPackRxMessage, which includes the
-- capture increment and error) so cocotb can compare the adapter
-- outputs with the tap outputs. Admission opens after reset. The wrapper adds
-- no reference model.
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
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.EthMacPkg.all;
use surf.PtpPkg.all;

entity PtpMacPortAdapterWrapper is
   generic (
      TPD_G             : time             := 1 ns;
      PHY_TYPE_G        : string           := "GMII";
      INGRESS_LATENCY_G : slv(63 downto 0) := x"FFFFFFFFFFFD0000";
      EGRESS_LATENCY_G  : slv(63 downto 0) := x"0000000000050000";
      TX_TABLE_DEPTH_G  : positive         := 4;
      -- 0 selects the PHY's depth, as PtpMacPortEndpoint does.
      RX_TABLE_DEPTH_G  : natural          := 0);
   port (
      -- Ethernet/PHC clock and system reset (active high)
      clk      : in  sl;
      rst      : in  sl;
      phyReady : in  sl;
      rxFlush  : in  sl;

      -- PHC tuple for the current cycle
      phcSeconds     : in  slv(47 downto 0);
      phcNanoseconds : in  slv(31 downto 0);
      phcFraction    : in  slv(31 downto 0);
      phcGeneration  : in  slv(31 downto 0);
      phcTicks       : in  slv(63 downto 0);
      phcIncrement   : in  slv(63 downto 0);
      phcTimeValid   : in  sl;
      captureAbort   : in  sl;

      -- Engine-side Delay_Req stream (EMAC_AXIS_CONFIG_C)
      sAxisTValid : in  sl;
      sAxisTData  : in  slv(127 downto 0);
      sAxisTKeep  : in  slv(15 downto 0);
      sAxisTLast  : in  sl;
      sAxisSof    : in  sl;
      sAxisTReady : out sl;

      -- Record ready shared by both RX paths and both TX paths
      rxReady : in sl;
      txReady : in sl;

      -- Adapter and tap RX records
      portRxValid    : out sl;
      portRxData     : out slv(PTP_RX_STORAGE_BITS_C-1 downto 0);
      portRxAbort    : out sl;
      portRxOverflow : out sl;
      portRxCounters : out slv(95 downto 0);
      tapRxValid     : out sl;
      tapRxData      : out slv(PTP_RX_STORAGE_BITS_C-1 downto 0);
      tapRxAbort     : out sl;
      tapRxOverflow  : out sl;
      tapRxCounters  : out slv(95 downto 0);

      -- Adapter and tap TX records
      portTxValid : out sl;
      portTxData  : out slv(PTP_RX_STORAGE_BITS_C-1 downto 0);
      tapTxValid  : out sl;
      tapTxData   : out slv(PTP_RX_STORAGE_BITS_C-1 downto 0);
      tapTxAbort  : out sl;

      -- Port lifecycle and counters
      admissionOpen : out sl;
      counters      : out slv(8*32-1 downto 0);

      -- Wire
      rxInject    : in  sl;
      injXgmiiRxd : in  slv(63 downto 0);
      injXgmiiRxc : in  slv(7 downto 0);
      injGmiiRxd  : in  slv(7 downto 0);
      injGmiiRxDv : in  sl;
      injGmiiRxEr : in  sl;
      xgmiiTxd    : out slv(63 downto 0);
      xgmiiTxc    : out slv(7 downto 0);
      gmiiTxd     : out slv(7 downto 0);
      gmiiTxEn    : out sl;
      gmiiTxEr    : out sl);
end entity PtpMacPortAdapterWrapper;

architecture mapping of PtpMacPortAdapterWrapper is

   constant RX_DEPTH_C : positive :=
      ite(RX_TABLE_DEPTH_G /= 0, RX_TABLE_DEPTH_G,
          ite(PHY_TYPE_G = "GMII", PTP_MAC_PORT_RX_DEPTH_GMII_C, PTP_MAC_PORT_RX_DEPTH_XGMII_C));

   constant RX_FIFO_ADDR_WIDTH_C : positive :=
      maximum(9, bitSize(RX_DEPTH_C*((EMAC_TIMING_MAX_FRAME_C+15)/16+1)-1));

   signal phcTime        : PtpTimeType      := PTP_TIME_INIT_C;
   signal phcStatus      : PtpPhcStatusType := PTP_PHC_STATUS_INIT_C;
   signal control        : PtpMacPortControlType := PTP_MAC_PORT_CONTROL_INIT_C;
   signal status         : PtpMacPortStatusType;
   signal portCounter    : PtpMacPortCountersType;
   signal ethConfig      : EthMacConfigType := ETH_MAC_CONFIG_INIT_C;
   signal delayReqMaster : AxiStreamMasterType;
   signal delayReqSlave  : AxiStreamSlaveType;
   signal portTxMaster   : PtpMacPortTxMasterType;
   signal portTxSlave    : AxiStreamSlaveType;
   signal completion     : PtpMacPortTxCompletionMasterType;
   signal completionRdy  : sl;
   signal portRxMaster   : PtpMacPortRxMasterType;
   signal portRxReady    : sl;
   signal portRxRecord   : PtpRxMessageMasterType;
   signal tapRxRecord    : PtpRxMessageMasterType;
   signal portTxRecord   : PtpRxMessageMasterType;
   signal tapTxRecord    : PtpRxMessageMasterType;
   signal portRxCount    : PtpRxCountersType;
   signal tapRxCount     : PtpRxCountersType;

   signal txd   : slv(63 downto 0);
   signal txc   : slv(7 downto 0);
   signal gTxd  : slv(7 downto 0);
   signal gTxEn : sl;
   signal gTxEr : sl;
   signal rxd   : slv(63 downto 0);
   signal rxc   : slv(7 downto 0);
   signal gRxd  : slv(7 downto 0);
   signal gRxDv : sl;
   signal gRxEr : sl;

begin

   phcTime.seconds      <= phcSeconds;
   phcTime.nanoseconds  <= phcNanoseconds;
   phcTime.fraction     <= phcFraction;
   phcStatus.generation <= phcGeneration;
   phcStatus.ticks      <= phcTicks;
   phcStatus.increment  <= phcIncrement;
   phcStatus.timeValid  <= phcTimeValid;

   control.openAdmission <= not rst;

   ethConfig.macAddress  <= x"554433221100";
   ethConfig.filtEnable  <= '0';
   ethConfig.pauseEnable <= '0';
   ethConfig.ipCsumEn    <= '0';
   ethConfig.tcpCsumEn   <= '0';
   ethConfig.udpCsumEn   <= '0';
   ethConfig.dropOnPause <= '0';

   txComb : process (sAxisSof, sAxisTData, sAxisTKeep, sAxisTLast, sAxisTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sAxisTValid;
      v.tData(127 downto 0) := sAxisTData;
      v.tKeep(15 downto 0)  := sAxisTKeep;
      v.tLast               := sAxisTLast;
      ssiSetUserSof(EMAC_AXIS_CONFIG_C, v, sAxisSof);
      delayReqMaster        <= v;
   end process txComb;

   sAxisTReady <= delayReqSlave.tReady;

   portRxValid    <= portRxRecord.valid;
   portRxData     <= ptpPackRxMessage(portRxRecord.data);
   portRxCounters <= portRxCount.overflow & portRxCount.dropped & portRxCount.accepted;
   tapRxValid     <= tapRxRecord.valid;
   tapRxData      <= ptpPackRxMessage(tapRxRecord.data);
   tapRxCounters  <= tapRxCount.overflow & tapRxCount.dropped & tapRxCount.accepted;
   portTxValid    <= portTxRecord.valid;
   portTxData     <= ptpPackRxMessage(portTxRecord.data);
   tapTxValid     <= tapTxRecord.valid;
   tapTxData      <= ptpPackRxMessage(tapTxRecord.data);
   admissionOpen  <= status.admissionOpen;

   counters <= portCounter.txRejected & portCounter.txFlushed & portCounter.txDiscarded &
               portCounter.txWireError & portCounter.txSent & portCounter.rxLost &
               portCounter.rxDropped & portCounter.rxDelivered;

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

   U_Port : entity surf.PtpMacPortEthMac
      generic map (
         TPD_G                => TPD_G,
         PHY_TYPE_G           => PHY_TYPE_G,
         TX_TABLE_DEPTH_G     => TX_TABLE_DEPTH_G,
         RX_TABLE_DEPTH_G     => RX_DEPTH_C,
         RX_FIFO_ADDR_WIDTH_G => RX_FIFO_ADDR_WIDTH_C,
         INGRESS_LATENCY_G    => INGRESS_LATENCY_G,
         EGRESS_LATENCY_G     => EGRESS_LATENCY_G)
      port map (
         clk              => clk,            -- [in]
         rst              => rst,            -- [in]
         phyReady         => phyReady,       -- [in]
         ethConfig        => ethConfig,      -- [in]
         ethStatus        => open,           -- [out]
         phcTime          => phcTime,        -- [in]
         phcStatus        => phcStatus,      -- [in]
         captureAbort     => captureAbort,   -- [in]
         control          => control,        -- [in]
         status           => status,         -- [out]
         counters         => portCounter,    -- [out]
         txMaster         => portTxMaster,   -- [in]
         txSlave          => portTxSlave,    -- [out]
         completionMaster => completion,     -- [out]
         completionReady  => completionRdy,  -- [in]
         rxMaster         => portRxMaster,   -- [out]
         rxReady          => portRxReady,    -- [in]
         xgmiiRxd         => rxd,            -- [in]
         xgmiiRxc         => rxc,            -- [in]
         xgmiiTxd         => txd,            -- [out]
         xgmiiTxc         => txc,            -- [out]
         gmiiRxd          => gRxd,           -- [in]
         gmiiRxDv         => gRxDv,          -- [in]
         gmiiRxEr         => gRxEr,          -- [in]
         gmiiTxd          => gTxd,           -- [out]
         gmiiTxEn         => gTxEn,          -- [out]
         gmiiTxEr         => gTxEr);         -- [out]

   U_RxAdapter : entity surf.PtpMacPortRxAdapter
      generic map (
         TPD_G => TPD_G)
      port map (
         clk           => clk,                   -- [in]
         rst           => rst,                   -- [in]
         rxFlush       => rxFlush,               -- [in]
         generation    => phcStatus.generation,  -- [in]
         portRxMaster  => portRxMaster,          -- [in]
         portRxReady   => portRxReady,           -- [out]
         messageMaster => portRxRecord,          -- [out]
         messageReady  => rxReady,               -- [in]
         rxAbort       => portRxAbort,           -- [out]
         queueOverflow => portRxOverflow,        -- [out]
         rxEpoch       => open,                  -- [out]
         counters      => portRxCount);          -- [out]

   U_TxAdapter : entity surf.PtpMacPortTxAdapter
      generic map (
         TPD_G         => TPD_G,
         TABLE_DEPTH_G => TX_TABLE_DEPTH_G)
      port map (
         clk                 => clk,                         -- [in]
         rst                 => rst,                         -- [in]
         sAxisMaster         => delayReqMaster,              -- [in]
         sAxisSlave          => delayReqSlave,               -- [out]
         portTxMaster        => portTxMaster,                -- [out]
         portTxSlave         => portTxSlave,                 -- [in]
         portGeneration      => status.transportGeneration,  -- [in]
         portCompletion      => completion,                  -- [in]
         portCompletionReady => completionRdy,               -- [out]
         messageMaster       => portTxRecord,                -- [out]
         messageReady        => txReady);                    -- [in]

   U_RxTap : entity surf.PtpRxTimestampTap
      generic map (
         TPD_G             => TPD_G,
         PHY_TYPE_G        => PHY_TYPE_G,
         INGRESS_LATENCY_G => INGRESS_LATENCY_G)
      port map (
         clk           => clk,             -- [in]
         rst           => rst,             -- [in]
         rxFlush       => rxFlush,         -- [in]
         phyReady      => phyReady,        -- [in]
         phcTime       => phcTime,         -- [in]
         phcStatus     => phcStatus,       -- [in]
         captureAbort  => captureAbort,    -- [in]
         xgmiiRxd      => rxd,             -- [in]
         xgmiiRxc      => rxc,             -- [in]
         gmiiRxd       => gRxd,            -- [in]
         gmiiRxDv      => gRxDv,           -- [in]
         gmiiRxEr      => gRxEr,           -- [in]
         messageMaster => tapRxRecord,     -- [out]
         messageReady  => rxReady,         -- [in]
         rxAbort       => tapRxAbort,      -- [out]
         queueOverflow => tapRxOverflow,   -- [out]
         rxEpoch       => open,            -- [out]
         counters      => tapRxCount);     -- [out]

   U_TxTap : entity surf.PtpTxTimestampTap
      generic map (
         TPD_G            => TPD_G,
         PHY_TYPE_G       => PHY_TYPE_G,
         EGRESS_LATENCY_G => EGRESS_LATENCY_G)
      port map (
         clk              => clk,           -- [in]
         rst              => rst,           -- [in]
         phyReady         => phyReady,      -- [in]
         phcTime          => phcTime,       -- [in]
         phcStatus        => phcStatus,     -- [in]
         captureAbort     => captureAbort,  -- [in]
         xgmiiTxd         => txd,           -- [in]
         xgmiiTxc         => txc,           -- [in]
         gmiiTxd          => gTxd,          -- [in]
         gmiiTxEn         => gTxEn,         -- [in]
         gmiiTxEr         => gTxEr,         -- [in]
         completionMaster => tapTxRecord,   -- [out]
         completionReady  => txReady,       -- [in]
         completionAbort  => tapTxAbort);   -- [out]

end architecture mapping;
