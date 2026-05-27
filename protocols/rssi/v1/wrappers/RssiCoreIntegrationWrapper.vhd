-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing client/server RSSI core integration wrapper
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

entity RssiCoreIntegrationWrapper is
   generic (
      TPD_G                 : time     := 1 ns;
      CLK_FREQUENCY_G       : real     := 1.0E6;
      TIMEOUT_UNIT_G        : real     := 1.0E-6;
      WINDOW_ADDR_SIZE_G    : positive := 2;
      SEGMENT_ADDR_SIZE_G   : positive := 5;
      MAX_NUM_OUTS_SEG_G    : positive := 4;
      MAX_SEG_SIZE_G        : positive := 32;
      ACK_TOUT_G            : positive := 4;
      RETRANS_TOUT_G        : positive := 16;
      NULL_TOUT_G           : positive := 48;
      MAX_RETRANS_CNT_G     : positive := 2;
      MAX_CUM_ACK_CNT_G     : positive := 2;
      CLIENT_INIT_SEQ_N_G   : natural  := 16#20#;
      SERVER_INIT_SEQ_N_G   : natural  := 16#80#;
      CONN_ID_G             : positive := 16#12345678#;
      VERSION_G             : positive := 1;
      HEADER_CHKSUM_EN_G    : boolean  := true;
      RETRANSMIT_ENABLE_G   : boolean  := true);
   port (
      axisClk : in sl;
      axisRst : in sl;

      cltOpen_i    : in sl;
      cltClose_i   : in sl;
      cltInject_i  : in sl;
      srvOpen_i    : in sl;
      srvClose_i   : in sl;
      srvInject_i  : in sl;

      cltSAppTValid : in  sl;
      cltSAppTReady : out sl;
      cltSAppTData  : in  slv(63 downto 0);
      cltSAppTKeep  : in  slv(7 downto 0);
      cltSAppTLast  : in  sl;
      cltSAppSof    : in  sl;
      cltSAppEofe   : in  sl;

      cltMAppTValid : out sl;
      cltMAppTReady : in  sl;
      cltMAppTData  : out slv(63 downto 0);
      cltMAppTKeep  : out slv(7 downto 0);
      cltMAppTLast  : out sl;
      cltMAppSof    : out sl;
      cltMAppEofe   : out sl;

      srvSAppTValid : in  sl;
      srvSAppTReady : out sl;
      srvSAppTData  : in  slv(63 downto 0);
      srvSAppTKeep  : in  slv(7 downto 0);
      srvSAppTLast  : in  sl;
      srvSAppSof    : in  sl;
      srvSAppEofe   : in  sl;

      srvMAppTValid : out sl;
      srvMAppTReady : in  sl;
      srvMAppTData  : out slv(63 downto 0);
      srvMAppTKeep  : out slv(7 downto 0);
      srvMAppTLast  : out sl;
      srvMAppSof    : out sl;
      srvMAppEofe   : out sl;

      cltSTspTValid : in  sl;
      cltSTspTReady : out sl;
      cltSTspTData  : in  slv(63 downto 0);
      cltSTspTKeep  : in  slv(7 downto 0);
      cltSTspTLast  : in  sl;
      cltSTspSof    : in  sl;
      cltSTspEofe   : in  sl;

      cltMTspTValid : out sl;
      cltMTspTReady : in  sl;
      cltMTspTData  : out slv(63 downto 0);
      cltMTspTKeep  : out slv(7 downto 0);
      cltMTspTLast  : out sl;
      cltMTspSof    : out sl;
      cltMTspEofe   : out sl;

      srvSTspTValid : in  sl;
      srvSTspTReady : out sl;
      srvSTspTData  : in  slv(63 downto 0);
      srvSTspTKeep  : in  slv(7 downto 0);
      srvSTspTLast  : in  sl;
      srvSTspSof    : in  sl;
      srvSTspEofe   : in  sl;

      srvMTspTValid : out sl;
      srvMTspTReady : in  sl;
      srvMTspTData  : out slv(63 downto 0);
      srvMTspTKeep  : out slv(7 downto 0);
      srvMTspTLast  : out sl;
      srvMTspSof    : out sl;
      srvMTspEofe   : out sl;

      cltStatusReg_o  : out slv(8 downto 0);
      srvStatusReg_o  : out slv(8 downto 0);
      cltConnected_o  : out sl;
      srvConnected_o  : out sl;
      cltMaxSegSize_o : out slv(15 downto 0);
      srvMaxSegSize_o : out slv(15 downto 0));
end entity RssiCoreIntegrationWrapper;

architecture mapping of RssiCoreIntegrationWrapper is

   signal cltSAppMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal cltSAppSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal cltMAppMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal cltMAppSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal srvSAppMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal srvSAppSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal srvMAppMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal srvMAppSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal cltTspMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal cltTspSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal srvTspMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal srvTspSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal cltRxTspMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal cltRxTspSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal srvRxTspMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal srvRxTspSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal cltAxilReadSlave   : AxiLiteReadSlaveType;
   signal cltAxilWriteSlave  : AxiLiteWriteSlaveType;
   signal srvAxilReadSlave   : AxiLiteReadSlaveType;
   signal srvAxilWriteSlave  : AxiLiteWriteSlaveType;

   signal cltStatusReg : slv(8 downto 0);
   signal srvStatusReg : slv(8 downto 0);

begin

   -- Flattened client application input.
   cltSAppComb : process (cltSAppEofe, cltSAppSof, cltSAppTData, cltSAppTKeep,
                          cltSAppTLast, cltSAppTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                    := AXI_STREAM_MASTER_INIT_C;
      v.tValid             := cltSAppTValid;
      v.tData(63 downto 0) := cltSAppTData;
      v.tStrb(7 downto 0)  := cltSAppTKeep;
      v.tKeep(7 downto 0)  := cltSAppTKeep;
      v.tLast              := cltSAppTLast;
      ssiSetUserSof(RSSI_AXIS_CONFIG_C, v, cltSAppSof);
      ssiSetUserEofe(RSSI_AXIS_CONFIG_C, v, cltSAppEofe);
      cltSAppMaster <= v;
   end process cltSAppComb;

   -- Flattened server application input.
   srvSAppComb : process (srvSAppEofe, srvSAppSof, srvSAppTData, srvSAppTKeep,
                          srvSAppTLast, srvSAppTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                    := AXI_STREAM_MASTER_INIT_C;
      v.tValid             := srvSAppTValid;
      v.tData(63 downto 0) := srvSAppTData;
      v.tStrb(7 downto 0)  := srvSAppTKeep;
      v.tKeep(7 downto 0)  := srvSAppTKeep;
      v.tLast              := srvSAppTLast;
      ssiSetUserSof(RSSI_AXIS_CONFIG_C, v, srvSAppSof);
      ssiSetUserEofe(RSSI_AXIS_CONFIG_C, v, srvSAppEofe);
      srvSAppMaster <= v;
   end process srvSAppComb;

   cltSAppTReady <= cltSAppSlave.tReady;
   srvSAppTReady <= srvSAppSlave.tReady;

   -- Flattened client application output.
   cltMAppSlave.tReady <= cltMAppTReady;
   cltMAppTValid       <= cltMAppMaster.tValid;
   cltMAppTData        <= cltMAppMaster.tData(63 downto 0);
   cltMAppTKeep        <= cltMAppMaster.tKeep(7 downto 0);
   cltMAppTLast        <= cltMAppMaster.tLast;
   cltMAppSof          <= ssiGetUserSof(RSSI_AXIS_CONFIG_C, cltMAppMaster);
   cltMAppEofe         <= ssiGetUserEofe(RSSI_AXIS_CONFIG_C, cltMAppMaster);

   -- Flattened server application output.
   srvMAppSlave.tReady <= srvMAppTReady;
   srvMAppTValid       <= srvMAppMaster.tValid;
   srvMAppTData        <= srvMAppMaster.tData(63 downto 0);
   srvMAppTKeep        <= srvMAppMaster.tKeep(7 downto 0);
   srvMAppTLast        <= srvMAppMaster.tLast;
   srvMAppSof          <= ssiGetUserSof(RSSI_AXIS_CONFIG_C, srvMAppMaster);
   srvMAppEofe         <= ssiGetUserEofe(RSSI_AXIS_CONFIG_C, srvMAppMaster);

   -- Flattened client transport input.
   cltSTspComb : process (cltSTspEofe, cltSTspSof, cltSTspTData,
                          cltSTspTKeep, cltSTspTLast, cltSTspTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                    := AXI_STREAM_MASTER_INIT_C;
      v.tValid             := cltSTspTValid;
      v.tData(63 downto 0) := cltSTspTData;
      v.tStrb(7 downto 0)  := cltSTspTKeep;
      v.tKeep(7 downto 0)  := cltSTspTKeep;
      v.tLast              := cltSTspTLast;
      ssiSetUserSof(RSSI_AXIS_CONFIG_C, v, cltSTspSof);
      ssiSetUserEofe(RSSI_AXIS_CONFIG_C, v, cltSTspEofe);
      cltRxTspMaster <= v;
   end process cltSTspComb;

   -- Flattened server transport input.
   srvSTspComb : process (srvSTspEofe, srvSTspSof, srvSTspTData,
                          srvSTspTKeep, srvSTspTLast, srvSTspTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                    := AXI_STREAM_MASTER_INIT_C;
      v.tValid             := srvSTspTValid;
      v.tData(63 downto 0) := srvSTspTData;
      v.tStrb(7 downto 0)  := srvSTspTKeep;
      v.tKeep(7 downto 0)  := srvSTspTKeep;
      v.tLast              := srvSTspTLast;
      ssiSetUserSof(RSSI_AXIS_CONFIG_C, v, srvSTspSof);
      ssiSetUserEofe(RSSI_AXIS_CONFIG_C, v, srvSTspEofe);
      srvRxTspMaster <= v;
   end process srvSTspComb;

   cltSTspTReady <= cltRxTspSlave.tReady;
   srvSTspTReady <= srvRxTspSlave.tReady;

   -- Flattened transport outputs for cocotb loopback/perturbation.
   cltTspSlave.tReady <= cltMTspTReady;
   cltMTspTValid <= cltTspMaster.tValid;
   cltMTspTData  <= cltTspMaster.tData(63 downto 0);
   cltMTspTKeep  <= cltTspMaster.tKeep(7 downto 0);
   cltMTspTLast  <= cltTspMaster.tLast;
   cltMTspSof    <= ssiGetUserSof(RSSI_AXIS_CONFIG_C, cltTspMaster);
   cltMTspEofe   <= ssiGetUserEofe(RSSI_AXIS_CONFIG_C, cltTspMaster);

   srvTspSlave.tReady <= srvMTspTReady;
   srvMTspTValid <= srvTspMaster.tValid;
   srvMTspTData  <= srvTspMaster.tData(63 downto 0);
   srvMTspTKeep  <= srvTspMaster.tKeep(7 downto 0);
   srvMTspTLast  <= srvTspMaster.tLast;
   srvMTspSof    <= ssiGetUserSof(RSSI_AXIS_CONFIG_C, srvTspMaster);
   srvMTspEofe   <= ssiGetUserEofe(RSSI_AXIS_CONFIG_C, srvTspMaster);

   cltStatusReg_o <= cltStatusReg;
   srvStatusReg_o <= srvStatusReg;
   cltConnected_o <= cltStatusReg(0);
   srvConnected_o <= srvStatusReg(0);

   -- Client core with transport exposed to cocotb for loopback.
   U_Client : entity surf.RssiCore
      generic map (
         TPD_G               => TPD_G,
         CLK_FREQUENCY_G     => CLK_FREQUENCY_G,
         TIMEOUT_UNIT_G      => TIMEOUT_UNIT_G,
         SERVER_G            => false,
         RETRANSMIT_ENABLE_G => RETRANSMIT_ENABLE_G,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_G,
         SEGMENT_ADDR_SIZE_G => SEGMENT_ADDR_SIZE_G,
         APP_AXIS_CONFIG_G   => RSSI_AXIS_CONFIG_C,
         TSP_AXIS_CONFIG_G   => RSSI_AXIS_CONFIG_C,
         INIT_SEQ_N_G        => CLIENT_INIT_SEQ_N_G,
         CONN_ID_G           => CONN_ID_G,
         VERSION_G           => VERSION_G,
         HEADER_CHKSUM_EN_G  => HEADER_CHKSUM_EN_G,
         MAX_NUM_OUTS_SEG_G  => MAX_NUM_OUTS_SEG_G,
         MAX_SEG_SIZE_G      => MAX_SEG_SIZE_G,
         ACK_TOUT_G          => ACK_TOUT_G,
         RETRANS_TOUT_G      => RETRANS_TOUT_G,
         NULL_TOUT_G         => NULL_TOUT_G,
         MAX_RETRANS_CNT_G   => MAX_RETRANS_CNT_G,
         MAX_CUM_ACK_CNT_G   => MAX_CUM_ACK_CNT_G)
      port map (
         clk_i            => axisClk, -- [in]
         rst_i            => axisRst, -- [in]
         openRq_i         => cltOpen_i, -- [in]
         closeRq_i        => cltClose_i, -- [in]
         inject_i         => cltInject_i, -- [in]
         sAppAxisMaster_i => cltSAppMaster, -- [in]
         sAppAxisSlave_o  => cltSAppSlave, -- [out]
         mAppAxisMaster_o => cltMAppMaster, -- [out]
         mAppAxisSlave_i  => cltMAppSlave, -- [in]
         sTspAxisMaster_i => cltRxTspMaster, -- [in]
         sTspAxisSlave_o  => cltRxTspSlave, -- [out]
         mTspAxisMaster_o => cltTspMaster, -- [out]
         mTspAxisSlave_i  => cltTspSlave, -- [in]
         axilReadSlave    => cltAxilReadSlave, -- [out]
         axilWriteSlave   => cltAxilWriteSlave, -- [out]
         statusReg_o      => cltStatusReg, -- [out]
         maxSegSize_o     => cltMaxSegSize_o); -- [out]

   -- Server core with transport exposed to cocotb for loopback.
   U_Server : entity surf.RssiCore
      generic map (
         TPD_G               => TPD_G,
         CLK_FREQUENCY_G     => CLK_FREQUENCY_G,
         TIMEOUT_UNIT_G      => TIMEOUT_UNIT_G,
         SERVER_G            => true,
         RETRANSMIT_ENABLE_G => RETRANSMIT_ENABLE_G,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_G,
         SEGMENT_ADDR_SIZE_G => SEGMENT_ADDR_SIZE_G,
         APP_AXIS_CONFIG_G   => RSSI_AXIS_CONFIG_C,
         TSP_AXIS_CONFIG_G   => RSSI_AXIS_CONFIG_C,
         INIT_SEQ_N_G        => SERVER_INIT_SEQ_N_G,
         CONN_ID_G           => CONN_ID_G,
         VERSION_G           => VERSION_G,
         HEADER_CHKSUM_EN_G  => HEADER_CHKSUM_EN_G,
         MAX_NUM_OUTS_SEG_G  => MAX_NUM_OUTS_SEG_G,
         MAX_SEG_SIZE_G      => MAX_SEG_SIZE_G,
         ACK_TOUT_G          => ACK_TOUT_G,
         RETRANS_TOUT_G      => RETRANS_TOUT_G,
         NULL_TOUT_G         => NULL_TOUT_G,
         MAX_RETRANS_CNT_G   => MAX_RETRANS_CNT_G,
         MAX_CUM_ACK_CNT_G   => MAX_CUM_ACK_CNT_G)
      port map (
         clk_i            => axisClk, -- [in]
         rst_i            => axisRst, -- [in]
         openRq_i         => srvOpen_i, -- [in]
         closeRq_i        => srvClose_i, -- [in]
         inject_i         => srvInject_i, -- [in]
         sAppAxisMaster_i => srvSAppMaster, -- [in]
         sAppAxisSlave_o  => srvSAppSlave, -- [out]
         mAppAxisMaster_o => srvMAppMaster, -- [out]
         mAppAxisSlave_i  => srvMAppSlave, -- [in]
         sTspAxisMaster_i => srvRxTspMaster, -- [in]
         sTspAxisSlave_o  => srvRxTspSlave, -- [out]
         mTspAxisMaster_o => srvTspMaster, -- [out]
         mTspAxisSlave_i  => srvTspSlave, -- [in]
         axilReadSlave    => srvAxilReadSlave, -- [out]
         axilWriteSlave   => srvAxilWriteSlave, -- [out]
         statusReg_o      => srvStatusReg, -- [out]
         maxSegSize_o     => srvMaxSegSize_o); -- [out]

end architecture mapping;
