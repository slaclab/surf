-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flattened fixed-point and command-lifecycle fixture for
-- PtpServo.
--
-- Builds measurement and PHC-status records from test-controlled forward/delay
-- values, raw ticks and rate ratio, then exposes the production servo's
-- filter, offset, frequency, quality and command outputs. The fixture selects
-- the nominal clock frequency, enables the servo and supplies valid time and
-- ratio flags. The standard AXI adapter exposes the local bank so Python can
-- program sample and age limits, then drive prepare/apply strobes. The shared
-- configuration record supplies the port-owned timeout limits for this fixture.
--
-- The wrapper contains no PHC. Cocotb independently drives command readiness,
-- acknowledgement and error to test command holding, cancellation and when a
-- frequency update becomes committed. Default record fields provide the
-- remaining provenance/configuration. Independent Python models own expected
-- filter and PI results; full acquisition and physical-clock behavior are
-- covered by the endpoint fixture.
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
use surf.PtpMathPkg.all;
use surf.AxiLitePkg.all;
use surf.PtpPkg.all;

entity PtpServoWrapper is
   generic (
      CLK_FREQ_G : positive := 125000000);
   port (
      clk                : in  sl;
      rst                : in  sl;
      regRst             : in  sl                := '0';
      restart            : in  sl                := '0';
      generation         : in  slv(31 downto 0)  := (others => '0');
      associationTimeout : in  slv(63 downto 0)  := x"3FFFFFFFFFFFFFFF";
      snapshotPublish    : in  sl                := '0';
      snapshotPrepared   : out sl;
      snapshotCapture    : in  sl                := '0';
      snapshotSequence   : in  slv(31 downto 0)  := (others => '0');
      axil_awaddr        : in  slv(31 downto 0);
      axil_awvalid       : in  sl;
      axil_awready       : out sl;
      axil_wdata         : in  slv(31 downto 0);
      axil_wstrb         : in  slv(3 downto 0);
      axil_wvalid        : in  sl;
      axil_wready        : out sl;
      axil_bresp         : out slv(1 downto 0);
      axil_bvalid        : out sl;
      axil_bready        : in  sl;
      axil_araddr        : in  slv(31 downto 0);
      axil_arvalid       : in  sl;
      axil_arready       : out sl;
      axil_rdata         : out slv(31 downto 0);
      axil_rresp         : out slv(1 downto 0);
      axil_rvalid        : out sl;
      axil_rready        : in  sl;
      prepareConfig      : in  sl;
      applyConfig        : in  sl;
      configValid        : out sl;
      configPrepared     : out sl;
      cancel             : in  sl;
      ticks              : in  slv(63 downto 0);
      sampleTicks        : in  slv(63 downto 0);
      isDelay            : in  sl;
      forwardValue       : in  slv(127 downto 0);
      delayValue         : in  slv(127 downto 0);
      maxPathDelay       : in  slv(63 downto 0)  := x"0000000F42400000";
      ratio              : in  slv(63 downto 0);
      inputValid         : in  sl;
      inputReady         : out sl;
      commandValid       : out sl;
      commandReady       : in  sl;
      commandAck         : in  sl;
      commandError       : in  sl;
      commandKind        : out slv(2 downto 0);
      commandRate        : out slv(63 downto 0);
      cancelCommand      : out sl;
      expireTime         : out sl;
      servoState         : out slv(2 downto 0);
      filteredDelay      : out slv(127 downto 0);
      offsetValue        : out slv(127 downto 0);
      ratePpb            : out slv(63 downto 0);
      filterCount        : out slv(2 downto 0);
      rejectedCount      : out slv(31 downto 0));
end entity PtpServoWrapper;

architecture rtl of PtpServoWrapper is

   signal resetN : sl;
   signal axiReadMaster  : AxiLiteReadMasterType;
   signal axiReadSlave   : AxiLiteReadSlaveType;
   signal axiWriteMaster : AxiLiteWriteMasterType;
   signal axiWriteSlave  : AxiLiteWriteSlaveType;
   signal sharedConfig : PtpSharedConfigType := PTP_SHARED_CONFIG_INIT_C;
   signal status       : PtpPhcStatusType    := PTP_PHC_STATUS_INIT_C;
   signal measurement  : PtpMeasurementType  := PTP_MEASUREMENT_INIT_C;
   signal command      : PtpPhcCommandType;
   -- Record-typed interfaces are assembled below rather than associated
   -- element by element, which older GHDL releases reject in a port map.
   signal configControl     : PtpConfigControlType     := PTP_CONFIG_CONTROL_INIT_C;
   signal snapshotControl   : PtpSnapshotControlType   := PTP_SNAPSHOT_CONTROL_INIT_C;
   signal measurementMaster : PtpMeasurementMasterType := PTP_MEASUREMENT_MASTER_INIT_C;
   signal measurementSlave  : PtpMeasurementSlaveType;
   signal commandMaster     : PtpPhcCommandMasterType;
   signal commandSlave      : PtpPhcCommandSlaveType   := PTP_PHC_COMMAND_SLAVE_INIT_C;
   signal servoStatus       : PtpServoStatusType;
   -- Private shared-service instances keep each fixture's arithmetic
   -- contract identical to the endpoint's without its cross-client arbiter.
   signal secondReady       : slv(0 downto 0);
   signal secondCancel      : slv(0 downto 0);
   signal secondResultReady : slv(0 downto 0);

   signal secondRequests : PtpConstDivideRequestArray(1-1 downto 0)(operand(128-1 downto 0));
   signal secondResults  : PtpConstDivideResultArray(1-1 downto 0)(value(128-1 downto 0), remainder(128-1 downto 0));

begin

   U_Second : entity surf.PtpSecondService
      generic map (
         NUM_CLIENTS_G => 1,
         WIDTH_G       => 128)
      port map (
         clk         => clk,                 -- [in]
         rst         => rst,                 -- [in]
         cancel      => secondCancel,        -- [in]
         requests    => secondRequests,      -- [in]
         inputReady  => secondReady,         -- [out]
         results     => secondResults,       -- [out]
         resultReady => secondResultReady);  -- [in]

   resetN                          <= not rst;
   sharedConfig.syncTimeout        <= x"3FFFFFFFFFFFFFFF";
   sharedConfig.associationTimeout <= associationTimeout;
   sharedConfig.maxPathDelay       <= maxPathDelay;
   status.ticks                    <= ticks;
   status.timeValid                <= '1';
   status.generation               <= generation;
   measurement.generation          <= generation;
   measurement.ticks               <= sampleTicks;
   measurement.isDelay             <= isDelay;
   measurement.forward             <= forwardValue;
   measurement.delayValue          <= delayValue;
   measurement.ratio               <= ratio;
   measurement.ratioValid          <= '1';
   commandKind                     <= command.kind;
   commandRate                     <= command.rate;

   configControl.prepare      <= prepareConfig;
   configControl.apply        <= applyConfig;
   configControl.busy         <= '0';
   snapshotControl.publish    <= snapshotPublish;
   snapshotControl.capture    <= snapshotCapture;
   snapshotControl.sequenceId <= snapshotSequence;
   measurementMaster.data     <= measurement;
   measurementMaster.valid    <= inputValid;
   measurementMaster.abort    <= cancel;
   commandSlave.ready         <= commandReady;
   commandSlave.ack           <= commandAck;
   commandSlave.error         <= commandError;

   inputReady    <= measurementSlave.ready;
   command       <= commandMaster.data;
   commandValid  <= commandMaster.valid;
   cancelCommand <= commandMaster.cancel;
   servoState    <= servoStatus.state;
   filteredDelay <= servoStatus.filteredDelay;
   offsetValue   <= servoStatus.offsetValue;
   ratePpb       <= servoStatus.ratePpb;
   filterCount   <= servoStatus.filterCount;
   rejectedCount <= servoStatus.rejectedCount;

   U_Axi : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         ADDR_WIDTH    => 32,
         EN_ERROR_RESP => true,
         HAS_WSTRB     => 1,
         FREQ_HZ       => CLK_FREQ_G)
      port map (
         S_AXI_ACLK      => clk,             -- [in]
         S_AXI_ARESETN   => resetN,          -- [in]
         S_AXI_AWADDR    => axil_awaddr,     -- [in]
         S_AXI_AWPROT    => "000",           -- [in]
         S_AXI_AWVALID   => axil_awvalid,    -- [in]
         S_AXI_AWREADY   => axil_awready,    -- [out]
         S_AXI_WDATA     => axil_wdata,      -- [in]
         S_AXI_WSTRB     => axil_wstrb,      -- [in]
         S_AXI_WVALID    => axil_wvalid,     -- [in]
         S_AXI_WREADY    => axil_wready,     -- [out]
         S_AXI_BRESP     => axil_bresp,      -- [out]
         S_AXI_BVALID    => axil_bvalid,     -- [out]
         S_AXI_BREADY    => axil_bready,     -- [in]
         S_AXI_ARADDR    => axil_araddr,     -- [in]
         S_AXI_ARPROT    => "000",           -- [in]
         S_AXI_ARVALID   => axil_arvalid,    -- [in]
         S_AXI_ARREADY   => axil_arready,    -- [out]
         S_AXI_RDATA     => axil_rdata,      -- [out]
         S_AXI_RRESP     => axil_rresp,      -- [out]
         S_AXI_RVALID    => axil_rvalid,     -- [out]
         S_AXI_RREADY    => axil_rready,     -- [in]
         axilClk         => open,            -- [out]
         axilRst         => open,            -- [out]
         axilReadMaster  => axiReadMaster,   -- [out]
         axilReadSlave   => axiReadSlave,    -- [in]
         axilWriteMaster => axiWriteMaster,  -- [out]
         axilWriteSlave  => axiWriteSlave);  -- [in]

   U_DUT : entity surf.PtpServo
      generic map (
         CLK_FREQ_G => CLK_FREQ_G)
      port map (
         clk               => clk,                    -- [in]
         rst               => rst,                    -- [in]
         regRst            => regRst,                 -- [in]
         axiReadMaster     => axiReadMaster,          -- [in]
         axiReadSlave      => axiReadSlave,           -- [out]
         axiWriteMaster    => axiWriteMaster,         -- [in]
         axiWriteSlave     => axiWriteSlave,          -- [out]
         configControl     => configControl,          -- [in]
         snapshotControl   => snapshotControl,        -- [in]
         snapshotPrepared  => snapshotPrepared,       -- [out]
         configValid       => configValid,            -- [out]
         configPrepared    => configPrepared,         -- [out]
         servoEnable       => '1',                    -- [in]
         sharedConfig      => sharedConfig,           -- [in]
         measurementMaster => measurementMaster,      -- [in]
         measurementSlave  => measurementSlave,       -- [out]
         restart           => restart,                -- [in]
         phcStatus         => status,                 -- [in]
         expireTime        => expireTime,             -- [out]
         commandMaster     => commandMaster,          -- [out]
         commandSlave      => commandSlave,           -- [in]
         status            => servoStatus,            -- [out]
         secondRequest     => secondRequests(0),      -- [out]
         secondReady       => secondReady(0),         -- [in]
         secondCancel      => secondCancel(0),        -- [out]
         secondResult      => secondResults(0),       -- [in]
         secondResultReady => secondResultReady(0));  -- [out]

end architecture rtl;
