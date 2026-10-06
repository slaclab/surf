-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flat transaction and measurement fixture for the real PtpPort.
--
-- Exposes validated RX records, capture provenance, cancellation and measurement
-- backpressure without a servo consuming results. Python owns all stimulus and
-- expected arithmetic. The AXI adapter accesses the production local register
-- bank; prepare/apply inputs model the endpoint coordinator's transaction.
-- Physical validation is covered separately by the endpoint and RX fixtures.
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
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.PtpPkg.all;

entity PtpPortWrapper is
   port (
      clk                   : in  sl;
      rst                   : in  sl;
      regRst                : in  sl;
      restart               : in  sl;
      prepare               : in  sl;
      applyConfig           : in  sl;
      configValid           : out sl;
      ticks                 : in  slv(63 downto 0);
      generation            : in  slv(31 downto 0);
      rxAbort               : in  sl;
      rxOverflow            : in  sl;
      rxValid               : in  sl;
      rxReady               : out sl;
      rxKind                : in  slv(3 downto 0);
      rxFlags               : in  slv(15 downto 0);
      rxControl             : in  slv(7 downto 0);
      rxSequence            : in  slv(15 downto 0);
      rxDomain              : in  slv(7 downto 0);
      rxSource              : in  slv(79 downto 0);
      rxTimestamp           : in  slv(79 downto 0);
      rxCorrection          : in  slv(63 downto 0);
      captureTime           : in  slv(95 downto 0);
      captureTicks          : in  slv(63 downto 0);
      captureGeneration     : in  slv(31 downto 0);
      measurementReady      : in  sl;
      measurementValid      : out sl;
      measurementAbort      : out sl;
      measurementForward    : out slv(127 downto 0);
      measurementTicks      : out slv(63 downto 0);
      measurementSequence   : out slv(15 downto 0);
      measurementGeneration : out slv(31 downto 0);
      measurementRatio      : out slv(63 downto 0);
      ratioValid            : out sl;
      syncCount             : out slv(31 downto 0);
      rejectedCount         : out slv(31 downto 0);
      axil_awaddr           : in  slv(31 downto 0);
      axil_awvalid          : in  sl;
      axil_awready          : out sl;
      axil_wdata            : in  slv(31 downto 0);
      axil_wstrb            : in  slv(3 downto 0);
      axil_wvalid           : in  sl;
      axil_wready           : out sl;
      axil_bresp            : out slv(1 downto 0);
      axil_bvalid           : out sl;
      axil_bready           : in  sl;
      axil_araddr           : in  slv(31 downto 0);
      axil_arvalid          : in  sl;
      axil_arready          : out sl;
      axil_rdata            : out slv(31 downto 0);
      axil_rresp            : out slv(1 downto 0);
      axil_rvalid           : out sl;
      axil_rready           : in  sl);
end entity PtpPortWrapper;

architecture rtl of PtpPortWrapper is

   signal readMaster  : AxiLiteReadMasterType;
   signal readSlave   : AxiLiteReadSlaveType;
   signal writeMaster : AxiLiteWriteMasterType;
   signal writeSlave  : AxiLiteWriteSlaveType;
   signal config      : PtpConfigControlType := PTP_CONFIG_CONTROL_INIT_C;
   signal phcStatus   : PtpPhcStatusType     := PTP_PHC_STATUS_INIT_C;
   signal rxMessage   : PtpRxMessageType     := PTP_RX_MESSAGE_INIT_C;
   signal measurement : PtpMeasurementMasterType;
   signal take        : PtpMeasurementSlaveType;
   signal status      : PtpPortStatusType;
   signal resetN      : sl;

begin

   resetN <= not rst;
   U_Axi : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         ADDR_WIDTH    => 32,
         EN_ERROR_RESP => true,
         HAS_WSTRB     => 1,
         FREQ_HZ       => 125000000)
      port map (
         S_AXI_ACLK      => clk,           -- [in]
         S_AXI_ARESETN   => resetN,        -- [in]
         S_AXI_AWADDR    => axil_awaddr,   -- [in]
         S_AXI_AWPROT    => "000",         -- [in]
         S_AXI_AWVALID   => axil_awvalid,  -- [in]
         S_AXI_AWREADY   => axil_awready,  -- [out]
         S_AXI_WDATA     => axil_wdata,    -- [in]
         S_AXI_WSTRB     => axil_wstrb,    -- [in]
         S_AXI_WVALID    => axil_wvalid,   -- [in]
         S_AXI_WREADY    => axil_wready,   -- [out]
         S_AXI_BRESP     => axil_bresp,    -- [out]
         S_AXI_BVALID    => axil_bvalid,   -- [out]
         S_AXI_BREADY    => axil_bready,   -- [in]
         S_AXI_ARADDR    => axil_araddr,   -- [in]
         S_AXI_ARPROT    => "000",         -- [in]
         S_AXI_ARVALID   => axil_arvalid,  -- [in]
         S_AXI_ARREADY   => axil_arready,  -- [out]
         S_AXI_RDATA     => axil_rdata,    -- [out]
         S_AXI_RRESP     => axil_rresp,    -- [out]
         S_AXI_RVALID    => axil_rvalid,   -- [out]
         S_AXI_RREADY    => axil_rready,   -- [in]
         axilClk         => open,          -- [out]
         axilRst         => open,          -- [out]
         axilReadMaster  => readMaster,    -- [out]
         axilReadSlave   => readSlave,     -- [in]
         axilWriteMaster => writeMaster,   -- [out]
         axilWriteSlave  => writeSlave);   -- [in]

   -- Fixed record slices only: no protocol behavior in this fixture.
   config.prepare                        <= prepare;
   config.apply                          <= applyConfig;
   phcStatus.ticks                       <= ticks;
   phcStatus.generation                  <= generation;
   phcStatus.increment                   <= ptpNominalIncrement(125000000);
   rxMessage.destination                 <= PTP_PRIMARY_MULTICAST_MAC_C;
   rxMessage.sourcePortIdentity          <= rxSource;
   rxMessage.domainNumber                <= rxDomain;
   rxMessage.messageType                 <= rxKind;
   rxMessage.flags                       <= rxFlags;
   rxMessage.control                     <= rxControl;
   rxMessage.sequenceId                  <= rxSequence;
   rxMessage.logInterval                 <= PTP_LOG_INTERVAL_UNSPECIFIED_C;
   rxMessage.messageBody(239 downto 160) <= rxTimestamp;
   rxMessage.correction                  <= rxCorrection;
   rxMessage.capture.timestamp           <= captureTime;
   rxMessage.capture.ticks               <= captureTicks;
   rxMessage.capture.generation          <= captureGeneration;
   rxMessage.capture.increment           <= ptpNominalIncrement(125000000);
   take.ready                            <= measurementReady;
   measurementValid                      <= measurement.valid;
   measurementAbort                      <= measurement.abort;
   measurementForward                    <= measurement.data.forward;
   measurementTicks                      <= measurement.data.ticks;
   measurementSequence                   <= measurement.data.syncSequence;
   measurementGeneration                 <= measurement.data.generation;
   measurementRatio                      <= measurement.data.ratio;
   ratioValid                            <= measurement.data.ratioValid;
   syncCount                             <= status.syncCount;
   rejectedCount                         <= status.rejectedCount;

   U_DUT : entity surf.PtpPort
      generic map (
         CLK_FREQ_G        => 125000000,
         PACKET_LIFETIME_G => 5000)
      port map (
         clk               => clk,                       -- [in]
         rst               => rst,                       -- [in]
         regRst            => regRst,                    -- [in]
         axiReadMaster     => readMaster,                -- [in]
         axiReadSlave      => readSlave,                 -- [out]
         axiWriteMaster    => writeMaster,               -- [in]
         axiWriteSlave     => writeSlave,                -- [out]
         configControl     => config,                    -- [in]
         configValid       => configValid,               -- [out]
         enable            => '1',                       -- [in]
         sharedConfig      => open,                      -- [out]
         restart           => restart,                   -- [in]
         linkReady         => '1',                       -- [in]
         macResetDone      => '1',                       -- [in]
         localMac          => x"010000000002",           -- [in]
         phcStatus         => phcStatus,                 -- [in]
         captureAbort      => '0',                       -- [in]
         rxMessage         => rxMessage,                 -- [in]
         rxValid           => rxValid,                   -- [in]
         rxReady           => rxReady,                   -- [out]
         rxQueueOverflow   => rxOverflow,                -- [in]
         rxAbort           => rxAbort,                   -- [in]
         txMessage         => PTP_RX_MESSAGE_INIT_C,     -- [in]
         txValid           => '0',                       -- [in]
         txAbort           => '0',                       -- [in]
         txMaster          => open,                      -- [out]
         txSlave           => AXI_STREAM_SLAVE_FORCE_C,  -- [in]
         measurementMaster => measurement,               -- [out]
         measurementSlave  => take,                      -- [in]
         lifecycle         => open,                      -- [out]
         status            => status);                   -- [out]

end architecture rtl;
