-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Debug cocotb-facing wrapper for CoaXPressCore issue triage
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
use surf.AxiLitePkg.all;
use surf.SsiPkg.all;

entity CoaXPressCoreDebugWrapper is
   generic (
      FORCE_RX_CTRL_G : boolean := false);
   port (
      dataClk            : in  sl;
      dataRst            : in  sl;
      cfgClk             : in  sl;
      cfgRst             : in  sl;
      txClk              : in  sl;
      txRst              : in  sl;
      rxClk              : in  sl;
      rxRst              : in  sl;
      axilClk            : in  sl;
      axilRst            : in  sl;
      txTrig             : in  sl;
      txLinkUp           : in  sl;
      rxData             : in  slv(31 downto 0);
      rxDataK            : in  slv(3 downto 0);
      rxDispErr          : in  sl;
      rxDecErr           : in  sl;
      rxLinkUp           : in  sl;
      gtRstAll           : out sl;
      txLsValid          : out sl;
      txLsData           : out slv(7 downto 0);
      txLsDataK          : out sl;
      txLsRate           : out sl;
      txLsLaneEn         : out slv(3 downto 0);
      DBG_RX_FSM_RST     : out sl;
      DBG_RX_NUM_OF_LANE : out slv(2 downto 0);
      DBG_RX_OVERFLOW    : out sl;
      DBG_RX_FSM_ERROR   : out sl;
      DBG_AXIL_OVERFLOW  : out sl;
      DBG_AXIL_FSM_ERROR : out sl;
      S_AXI_AWADDR       : in  slv(11 downto 0);
      S_AXI_AWPROT       : in  slv(2 downto 0);
      S_AXI_AWVALID      : in  sl;
      S_AXI_AWREADY      : out sl;
      S_AXI_WDATA        : in  slv(31 downto 0);
      S_AXI_WSTRB        : in  slv(3 downto 0);
      S_AXI_WVALID       : in  sl;
      S_AXI_WREADY       : out sl;
      S_AXI_BRESP        : out slv(1 downto 0);
      S_AXI_BVALID       : out sl;
      S_AXI_BREADY       : in  sl;
      S_AXI_ARADDR       : in  slv(11 downto 0);
      S_AXI_ARPROT       : in  slv(2 downto 0);
      S_AXI_ARVALID      : in  sl;
      S_AXI_ARREADY      : out sl;
      S_AXI_RDATA        : out slv(31 downto 0);
      S_AXI_RRESP        : out slv(1 downto 0);
      S_AXI_RVALID       : out sl;
      S_AXI_RREADY       : in  sl;
      S_CFG_IB_TVALID    : in  sl;
      S_CFG_IB_TDATA     : in  slv(255 downto 0);
      S_CFG_IB_TKEEP     : in  slv(31 downto 0);
      S_CFG_IB_TLAST     : in  sl;
      S_CFG_IB_TUSER     : in  slv(1 downto 0);
      S_CFG_IB_TREADY    : out sl;
      M_CFG_OB_TVALID    : out sl;
      M_CFG_OB_TDATA     : out slv(255 downto 0);
      M_CFG_OB_TKEEP     : out slv(31 downto 0);
      M_CFG_OB_TLAST     : out sl;
      M_CFG_OB_TUSER     : out slv(1 downto 0);
      M_CFG_OB_TREADY    : in  sl;
      M_DATA_TVALID      : out sl;
      M_DATA_TDATA       : out slv(31 downto 0);
      M_DATA_TKEEP       : out slv(3 downto 0);
      M_DATA_TLAST       : out sl;
      M_DATA_TUSER       : out slv(0 downto 0);
      M_DATA_TREADY      : in  sl;
      M_HDR_TVALID       : out sl;
      M_HDR_TDATA        : out slv(31 downto 0);
      M_HDR_TKEEP        : out slv(3 downto 0);
      M_HDR_TLAST        : out sl;
      M_HDR_TUSER        : out slv(0 downto 0);
      M_HDR_TREADY       : in  sl);
end entity CoaXPressCoreDebugWrapper;

architecture rtl of CoaXPressCoreDebugWrapper is

   constant DATA_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(dataBytes => 4);
   constant CFG_AXIS_CONFIG_C  : AxiStreamConfigType := ssiAxiStreamConfig(dataBytes => 32);

   signal cfgIbMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal cfgIbSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal cfgObMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal cfgObSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal dataMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal dataSlave   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal hdrMaster   : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal hdrSlave    : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

   signal rxClkVec      : slv(0 downto 0);
   signal rxRstVec      : slv(0 downto 0);
   signal rxDataVec     : slv32Array(0 downto 0);
   signal rxDataKVec    : Slv4Array(0 downto 0);
   signal rxDispErrVec  : slv(0 downto 0);
   signal rxDecErrVec   : slv(0 downto 0);
   signal rxLinkUpVec   : slv(0 downto 0);

   signal unusedClk : sl;
   signal unusedRst : sl;

   signal cfgTxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal cfgTxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal cfgRxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;

   signal configTimerSize : slv(31 downto 0);
   signal configErrResp   : sl;
   signal configPktTag    : sl;

   signal txTrigInv    : sl;
   signal txPulseWidth : slv(31 downto 0);
   signal swTrig       : sl;
   signal txTrigDrop   : sl;

   signal eventAck : sl;
   signal eventTag : slv(7 downto 0);

   signal trigAck     : sl;
   signal txLsRateInt : sl;

   signal rxOverflow         : sl;
   signal rxFsmError         : sl;
   signal rxFsmRst           : sl;
   signal rxFsmRstAxil       : sl;
   signal rxNumberOfLane     : slv(2 downto 0);
   signal rxNumberOfLaneAxil : slv(2 downto 0);

begin

   txLsRate         <= txLsRateInt;
   DBG_RX_FSM_RST   <= rxFsmRst;
   DBG_RX_NUM_OF_LANE <= rxNumberOfLane;
   DBG_RX_OVERFLOW  <= rxOverflow;
   DBG_RX_FSM_ERROR <= rxFsmError;

   rxFsmRst       <= '0' when FORCE_RX_CTRL_G else rxFsmRstAxil;
   rxNumberOfLane <= (others => '0') when FORCE_RX_CTRL_G else rxNumberOfLaneAxil;

   rxClkVec(0)     <= rxClk;
   rxRstVec(0)     <= rxRst;
   rxDataVec(0)    <= rxData;
   rxDataKVec(0)   <= rxDataK;
   rxDispErrVec(0) <= rxDispErr;
   rxDecErrVec(0)  <= rxDecErr;
   rxLinkUpVec(0)  <= rxLinkUp;

   U_Axil : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         INTERFACENAME => "S_AXI",
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         FREQ_HZ       => 100000000,
         ADDR_WIDTH    => 12)
      port map (
         S_AXI_ACLK      => axilClk,
         S_AXI_ARESETN   => not axilRst,
         S_AXI_AWADDR    => S_AXI_AWADDR,
         S_AXI_AWPROT    => S_AXI_AWPROT,
         S_AXI_AWVALID   => S_AXI_AWVALID,
         S_AXI_AWREADY   => S_AXI_AWREADY,
         S_AXI_WDATA     => S_AXI_WDATA,
         S_AXI_WSTRB     => S_AXI_WSTRB,
         S_AXI_WVALID    => S_AXI_WVALID,
         S_AXI_WREADY    => S_AXI_WREADY,
         S_AXI_BRESP     => S_AXI_BRESP,
         S_AXI_BVALID    => S_AXI_BVALID,
         S_AXI_BREADY    => S_AXI_BREADY,
         S_AXI_ARADDR    => S_AXI_ARADDR,
         S_AXI_ARPROT    => S_AXI_ARPROT,
         S_AXI_ARVALID   => S_AXI_ARVALID,
         S_AXI_ARREADY   => S_AXI_ARREADY,
         S_AXI_RDATA     => S_AXI_RDATA,
         S_AXI_RRESP     => S_AXI_RRESP,
         S_AXI_RVALID    => S_AXI_RVALID,
         S_AXI_RREADY    => S_AXI_RREADY,
         axilClk         => open,
         axilRst         => open,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   U_CfgIb : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_CFG_IB",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         TDATA_NUM_BYTES => 32)
      port map (
         S_AXIS_ACLK    => cfgClk,
         S_AXIS_ARESETN => not cfgRst,
         S_AXIS_TVALID  => S_CFG_IB_TVALID,
         S_AXIS_TDATA   => S_CFG_IB_TDATA,
         S_AXIS_TSTRB   => (others => '1'),
         S_AXIS_TKEEP   => S_CFG_IB_TKEEP,
         S_AXIS_TLAST   => S_CFG_IB_TLAST,
         S_AXIS_TDEST   => "0",
         S_AXIS_TID     => "0",
         S_AXIS_TUSER   => S_CFG_IB_TUSER,
         S_AXIS_TREADY  => S_CFG_IB_TREADY,
         axisClk        => unusedClk,
         axisRst        => unusedRst,
         axisMaster     => cfgIbMaster,
         axisSlave      => cfgIbSlave);

   U_CfgOb : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_CFG_OB",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         TDATA_NUM_BYTES => 32)
      port map (
         M_AXIS_ACLK    => cfgClk,
         M_AXIS_ARESETN => not cfgRst,
         M_AXIS_TVALID  => M_CFG_OB_TVALID,
         M_AXIS_TDATA   => M_CFG_OB_TDATA,
         M_AXIS_TSTRB   => open,
         M_AXIS_TKEEP   => M_CFG_OB_TKEEP,
         M_AXIS_TLAST   => M_CFG_OB_TLAST,
         M_AXIS_TDEST   => open,
         M_AXIS_TID     => open,
         M_AXIS_TUSER   => M_CFG_OB_TUSER,
         M_AXIS_TREADY  => M_CFG_OB_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => cfgObMaster,
         axisSlave      => cfgObSlave);

   U_Data : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_DATA",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 1,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         TDATA_NUM_BYTES => 4)
      port map (
         M_AXIS_ACLK    => dataClk,
         M_AXIS_ARESETN => not dataRst,
         M_AXIS_TVALID  => M_DATA_TVALID,
         M_AXIS_TDATA   => M_DATA_TDATA,
         M_AXIS_TSTRB   => open,
         M_AXIS_TKEEP   => M_DATA_TKEEP,
         M_AXIS_TLAST   => M_DATA_TLAST,
         M_AXIS_TDEST   => open,
         M_AXIS_TID     => open,
         M_AXIS_TUSER   => M_DATA_TUSER,
         M_AXIS_TREADY  => M_DATA_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => dataMaster,
         axisSlave      => dataSlave);

   U_Hdr : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_HDR",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 1,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         TDATA_NUM_BYTES => 4)
      port map (
         M_AXIS_ACLK    => dataClk,
         M_AXIS_ARESETN => not dataRst,
         M_AXIS_TVALID  => M_HDR_TVALID,
         M_AXIS_TDATA   => M_HDR_TDATA,
         M_AXIS_TSTRB   => open,
         M_AXIS_TKEEP   => M_HDR_TKEEP,
         M_AXIS_TLAST   => M_HDR_TLAST,
         M_AXIS_TDEST   => open,
         M_AXIS_TID     => open,
         M_AXIS_TUSER   => M_HDR_TUSER,
         M_AXIS_TREADY  => M_HDR_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => hdrMaster,
         axisSlave      => hdrSlave);

   U_Config : entity surf.CoaXPressConfig
      generic map (
         TPD_G         => 1 ns,
         AXIS_CONFIG_G => CFG_AXIS_CONFIG_C)
      port map (
         cfgClk          => cfgClk,
         cfgRst          => cfgRst,
         configTimerSize => configTimerSize,
         configErrResp   => configErrResp,
         configPktTag    => configPktTag,
         cfgIbMaster     => cfgIbMaster,
         cfgIbSlave      => cfgIbSlave,
         cfgObMaster     => cfgObMaster,
         cfgObSlave      => cfgObSlave,
         cfgTxMaster     => cfgTxMaster,
         cfgTxSlave      => cfgTxSlave,
         cfgRxMaster     => cfgRxMaster);

   U_Tx : entity surf.CoaXPressTx
      generic map (
         TPD_G => 1 ns)
      port map (
         cfgClk       => cfgClk,
         cfgRst       => cfgRst,
         cfgTxMaster  => cfgTxMaster,
         cfgTxSlave   => cfgTxSlave,
         eventAck     => eventAck,
         eventTag     => eventTag,
         txClk        => txClk,
         txRst        => txRst,
         txLsRate     => txLsRateInt,
         txLsValid    => txLsValid,
         txLsData     => txLsData,
         txLsDataK    => txLsDataK,
         txTrigInv    => txTrigInv,
         txPulseWidth => txPulseWidth,
         swTrig       => swTrig,
         txTrig       => txTrig,
         txTrigDrop   => txTrigDrop);

   U_Rx : entity surf.CoaXPressRx
      generic map (
         TPD_G              => 1 ns,
         NUM_LANES_G        => 1,
         RX_FSM_CNT_WIDTH_G => 8,
         AXIS_CONFIG_G      => DATA_AXIS_CONFIG_C)
      port map (
         dataClk        => dataClk,
         dataRst        => dataRst,
         dataMaster     => dataMaster,
         dataSlave      => dataSlave,
         imageHdrMaster => hdrMaster,
         imageHdrSlave  => hdrSlave,
         cfgClk         => cfgClk,
         cfgRst         => cfgRst,
         cfgRxMaster    => cfgRxMaster,
         eventAck       => eventAck,
         eventTag       => eventTag,
         txClk          => txClk,
         txRst          => txRst,
         trigAck        => trigAck,
         rxClk          => rxClkVec,
         rxRst          => rxRstVec,
         rxData         => rxDataVec,
         rxDataK        => rxDataKVec,
         rxLinkUp       => rxLinkUpVec,
         rxOverflow     => rxOverflow,
         rxFsmError     => rxFsmError,
         rxFsmRst       => rxFsmRst,
         rxNumberOfLane => rxNumberOfLane);

   U_AxilCore : entity surf.CoaXPressAxiL
      generic map (
         TPD_G              => 1 ns,
         NUM_LANES_G        => 1,
         STATUS_CNT_WIDTH_G => 8,
         RX_FSM_CNT_WIDTH_G => 8,
         AXIL_CLK_FREQ_G    => 100.0E+6,
         AXIS_CLK_FREQ_G    => 100.0E+6,
         AXIS_CONFIG_G      => DATA_AXIS_CONFIG_C)
      port map (
         gtRstAll        => gtRstAll,
         txClk           => txClk,
         txRst           => txRst,
         txTrigInv       => txTrigInv,
         txPulseWidth    => txPulseWidth,
         txTrig          => txTrig,
         swTrig          => swTrig,
         txTrigDrop      => txTrigDrop,
         trigAck         => trigAck,
         txLinkUp        => txLinkUp,
         txLsRate        => txLsRateInt,
         txLsLaneEn      => txLsLaneEn,
         rxClk           => rxClkVec,
         rxRst           => rxRstVec,
         rxDispErr       => rxDispErrVec,
         rxDecErr        => rxDecErrVec,
         rxLinkUp        => rxLinkUpVec,
         rxFsmRst        => rxFsmRstAxil,
         rxNumberOfLane  => rxNumberOfLaneAxil,
         rxOverflow      => rxOverflow,
         rxFsmError      => rxFsmError,
         cfgClk          => cfgClk,
         cfgRst          => cfgRst,
         configTimerSize => configTimerSize,
         configErrResp   => configErrResp,
         configPktTag    => configPktTag,
         dataClk         => dataClk,
         dataRst         => dataRst,
         dataMaster      => dataMaster,
         dataSlave       => dataSlave,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   U_DbgRxOverflow : entity surf.SynchronizerOneShot
      generic map (
         TPD_G => 1 ns)
      port map (
         clk     => axilClk,
         rst     => axilRst,
         dataIn  => rxOverflow,
         dataOut => DBG_AXIL_OVERFLOW);

   U_DbgRxFsmError : entity surf.SynchronizerOneShot
      generic map (
         TPD_G => 1 ns)
      port map (
         clk     => axilClk,
         rst     => axilRst,
         dataIn  => rxFsmError,
         dataOut => DBG_AXIL_FSM_ERROR);

end architecture rtl;
