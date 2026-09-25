-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: RSSI packetizer/SRP reconnect integration test wrapper
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
use surf.SsiPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.RssiPkg.all;

entity RssiSrpRecoveryWrapper is
   port (
      ethClk    : in sl;
      ethRst    : in sl;
      axilClk   : in sl;
      axilRst   : in sl;
      connected : out sl;
      status    : out slv(8 downto 0);
      rxTValid  : in sl;
      rxTReady  : out sl;
      rxTData   : in slv(63 downto 0);
      rxTKeep   : in slv(7 downto 0);
      rxTLast   : in sl;
      rxSof     : in sl;
      rxEofe    : in sl;
      txTValid  : out sl;
      txTReady  : in sl;
      txTData   : out slv(63 downto 0);
      txTKeep   : out slv(7 downto 0);
      txTLast   : out sl;
      txSof     : out sl;
      txEofe    : out sl;
      reqTValid : out sl;
      reqTReady : out sl;
      reqTData  : out slv(63 downto 0);
      reqTKeep  : out slv(7 downto 0);
      reqTLast  : out sl;
      reqSof    : out sl;
      reqEofe   : out sl;
      repTValid : out sl;
      repTReady : out sl;
      repTData  : out slv(63 downto 0);
      repTKeep  : out slv(7 downto 0);
      repTLast  : out sl;
      repSof    : out sl;
      repEofe   : out sl;
      arValid   : out sl;
      arReady   : in sl;
      arAddr    : out slv(31 downto 0);
      rValid    : in sl;
      rReady    : out sl;
      rData     : in slv(31 downto 0);
      rResp     : in slv(1 downto 0));
end entity RssiSrpRecoveryWrapper;

architecture rtl of RssiSrpRecoveryWrapper is

   constant APP_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(dataBytes => 8, tDestBits => 8, tUserBits => 8);
   signal rxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rxSlave : AxiStreamSlaveType;
   signal txMaster : AxiStreamMasterType;
   signal txSlave : AxiStreamSlaveType := AXI_STREAM_SLAVE_INIT_C;
   signal reqMasters : AxiStreamMasterArray(0 downto 0);
   signal reqSlaves : AxiStreamSlaveArray(0 downto 0);
   signal repMasters : AxiStreamMasterArray(0 downto 0);
   signal repSlaves : AxiStreamSlaveArray(0 downto 0);
   signal readMaster : AxiLiteReadMasterType;
   signal readSlave : AxiLiteReadSlaveType := AXI_LITE_READ_SLAVE_INIT_C;

begin

   -- Flattening only; all framing, buffering, CDC and recovery are production RTL.
   rxMaster.tValid <= rxTValid;
   rxMaster.tData(63 downto 0) <= rxTData;
   rxMaster.tKeep(7 downto 0) <= rxTKeep;
   rxMaster.tLast <= rxTLast;
   rxMaster.tUser(1) <= rxSof;
   rxMaster.tUser(0) <= rxEofe;
   rxTReady <= rxSlave.tReady;
   txSlave.tReady <= txTReady;
   txTValid <= txMaster.tValid;
   txTData <= txMaster.tData(63 downto 0);
   txTKeep <= txMaster.tKeep(7 downto 0);
   txTLast <= txMaster.tLast;
   txSof <= ssiGetUserSof(RSSI_AXIS_CONFIG_C, txMaster);
   txEofe <= ssiGetUserEofe(RSSI_AXIS_CONFIG_C, txMaster);
   reqTValid <= reqMasters(0).tValid;
   reqTData <= reqMasters(0).tData(63 downto 0);
   reqTKeep <= reqMasters(0).tKeep(7 downto 0);
   reqTLast <= reqMasters(0).tLast;
   reqSof <= ssiGetUserSof(APP_CONFIG_C, reqMasters(0));
   reqEofe <= ssiGetUserEofe(APP_CONFIG_C, reqMasters(0));
   reqTReady <= reqSlaves(0).tReady;
   repTValid <= repMasters(0).tValid;
   repTData <= repMasters(0).tData(63 downto 0);
   repTKeep <= repMasters(0).tKeep(7 downto 0);
   repTLast <= repMasters(0).tLast;
   repSof <= ssiGetUserSof(APP_CONFIG_C, repMasters(0));
   repEofe <= ssiGetUserEofe(APP_CONFIG_C, repMasters(0));
   repTReady <= repSlaves(0).tReady;

   arValid <= readMaster.arvalid;
   arAddr <= readMaster.araddr;
   rReady <= readMaster.rready;
   readSlave.arready <= arReady;
   readSlave.rvalid <= rValid;
   readSlave.rdata <= rData;
   readSlave.rresp <= rResp;

   U_Rssi : entity surf.RssiCoreWrapper
      generic map (
         CLK_FREQUENCY_G => 156.25E6,
         TIMEOUT_UNIT_G => 1.0E-6,
         APP_ILEAVE_EN_G => true,
         WINDOW_ADDR_SIZE_G => 3,
         MAX_SEG_SIZE_G => 1024,
         APP_STREAMS_G => 1,
         APP_STREAM_ROUTES_G => (0 => x"00"),
         APP_AXIS_CONFIG_G => (0 => APP_CONFIG_C),
         TSP_AXIS_CONFIG_G => RSSI_AXIS_CONFIG_C,
         ACK_TOUT_G => 2,
         RETRANS_TOUT_G => 1000,
         NULL_TOUT_G => 10000)
      port map (
         clk_i => ethClk,
         rst_i => ethRst,
         sAppAxisMasters_i => repMasters,
         sAppAxisSlaves_o => repSlaves,
         mAppAxisMasters_o => reqMasters,
         mAppAxisSlaves_i => reqSlaves,
         sTspAxisMaster_i => rxMaster,
         sTspAxisSlave_o => rxSlave,
         mTspAxisMaster_o => txMaster,
         mTspAxisSlave_i => txSlave,
         openRq_i => '1',
         rssiConnected_o => connected,
         statusReg_o => status,
         axilReadSlave => open,
         axilWriteSlave => open);

   U_Srp : entity surf.SrpV3AxiLite
      generic map (
         INT_PIPE_STAGES_G => 1,
         PIPE_STAGES_G => 0,
         SLAVE_READY_EN_G => true,
         GEN_SYNC_FIFO_G => false,
         AXIL_CLK_FREQ_G => 125.0E6,
         AXI_STREAM_CONFIG_G => APP_CONFIG_C)
      port map (
         sAxisClk => ethClk,
         sAxisRst => ethRst,
         sAxisMaster => reqMasters(0),
         sAxisSlave => reqSlaves(0),
         sAxisCtrl => open,
         mAxisClk => ethClk,
         mAxisRst => ethRst,
         mAxisMaster => repMasters(0),
         mAxisSlave => repSlaves(0),
         axilClk => axilClk,
         axilRst => axilRst,
         mAxilReadMaster => readMaster,
         mAxilReadSlave => readSlave,
         mAxilWriteMaster => open,
         mAxilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

end architecture rtl;
