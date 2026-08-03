-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing client/server RSSI core-wrapper integration wrapper
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

entity RssiCoreWrapperIntegrationWrapper is
   generic (
      TPD_G               : time     := 1 ns;
      CLK_FREQUENCY_G     : real     := 1.0E6;
      TIMEOUT_UNIT_G      : real     := 1.0E-6;
      WINDOW_ADDR_SIZE_G  : positive := 2;
      MAX_SEG_SIZE_G      : positive := 256;
      BYPASS_CHUNKER_G    : boolean  := true;
      ACK_TOUT_G          : positive := 4;
      RETRANS_TOUT_G      : positive := 16;
      NULL_TOUT_G         : positive := 48;
      MAX_RETRANS_CNT_G   : positive := 2;
      MAX_CUM_ACK_CNT_G   : positive := 2;
      CLIENT_INIT_SEQ_N_G : natural  := 16#20#;
      SERVER_INIT_SEQ_N_G : natural  := 16#80#;
      CONN_ID_G           : positive := 16#12345678#;
      VERSION_G           : positive := 1;
      HEADER_CHKSUM_EN_G  : boolean  := true);
   port (
      axisClk : in sl;
      axisRst : in sl;

      cltOpen_i  : in sl;
      cltClose_i : in sl;
      srvOpen_i  : in sl;
      srvClose_i : in sl;

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

      cltConnected_o : out sl;
      srvConnected_o : out sl;
      cltStatusReg_o : out slv(8 downto 0);
      srvStatusReg_o : out slv(8 downto 0));
end entity RssiCoreWrapperIntegrationWrapper;

architecture mapping of RssiCoreWrapperIntegrationWrapper is

   signal cltSAppMasters : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal cltSAppSlaves  : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal cltMAppMasters : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal cltMAppSlaves  : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);

   signal srvSAppMasters : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal srvSAppSlaves  : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal srvMAppMasters : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal srvMAppSlaves  : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);

   signal cltTspMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal cltTspSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal srvTspMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal srvTspSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal cltAxilReadSlave   : AxiLiteReadSlaveType;
   signal cltAxilWriteSlave  : AxiLiteWriteSlaveType;
   signal srvAxilReadSlave   : AxiLiteReadSlaveType;
   signal srvAxilWriteSlave  : AxiLiteWriteSlaveType;

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
      cltSAppMasters(0) <= v;
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
      srvSAppMasters(0) <= v;
   end process srvSAppComb;

   cltSAppTReady <= cltSAppSlaves(0).tReady;
   srvSAppTReady <= srvSAppSlaves(0).tReady;

   -- Flattened client application output.
   cltMAppSlaves(0).tReady <= cltMAppTReady;
   cltMAppTValid           <= cltMAppMasters(0).tValid;
   cltMAppTData            <= cltMAppMasters(0).tData(63 downto 0);
   cltMAppTKeep            <= cltMAppMasters(0).tKeep(7 downto 0);
   cltMAppTLast            <= cltMAppMasters(0).tLast;
   cltMAppSof              <= ssiGetUserSof(RSSI_AXIS_CONFIG_C, cltMAppMasters(0));
   cltMAppEofe             <= ssiGetUserEofe(RSSI_AXIS_CONFIG_C, cltMAppMasters(0));

   -- Flattened server application output.
   srvMAppSlaves(0).tReady <= srvMAppTReady;
   srvMAppTValid           <= srvMAppMasters(0).tValid;
   srvMAppTData            <= srvMAppMasters(0).tData(63 downto 0);
   srvMAppTKeep            <= srvMAppMasters(0).tKeep(7 downto 0);
   srvMAppTLast            <= srvMAppMasters(0).tLast;
   srvMAppSof              <= ssiGetUserSof(RSSI_AXIS_CONFIG_C, srvMAppMasters(0));
   srvMAppEofe             <= ssiGetUserEofe(RSSI_AXIS_CONFIG_C, srvMAppMasters(0));

   -- Client wrapper with transport connected directly to the server wrapper.
   U_Client : entity surf.RssiCoreWrapper
      generic map (
         TPD_G               => TPD_G,
         CLK_FREQUENCY_G     => CLK_FREQUENCY_G,
         TIMEOUT_UNIT_G      => TIMEOUT_UNIT_G,
         SERVER_G            => false,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_G,
         BYPASS_CHUNKER_G    => BYPASS_CHUNKER_G,
         APP_AXIS_CONFIG_G   => (0 => RSSI_AXIS_CONFIG_C),
         TSP_AXIS_CONFIG_G   => RSSI_AXIS_CONFIG_C,
         INIT_SEQ_N_G        => CLIENT_INIT_SEQ_N_G,
         CONN_ID_G           => CONN_ID_G,
         VERSION_G           => VERSION_G,
         HEADER_CHKSUM_EN_G  => HEADER_CHKSUM_EN_G,
         MAX_SEG_SIZE_G      => MAX_SEG_SIZE_G,
         ACK_TOUT_G          => ACK_TOUT_G,
         RETRANS_TOUT_G      => RETRANS_TOUT_G,
         NULL_TOUT_G         => NULL_TOUT_G,
         MAX_RETRANS_CNT_G   => MAX_RETRANS_CNT_G,
         MAX_CUM_ACK_CNT_G   => MAX_CUM_ACK_CNT_G)
      port map (
         clk_i             => axisClk, -- [in]
         rst_i             => axisRst, -- [in]
         sAppAxisMasters_i => cltSAppMasters, -- [in]
         sAppAxisSlaves_o  => cltSAppSlaves, -- [out]
         mAppAxisMasters_o => cltMAppMasters, -- [out]
         mAppAxisSlaves_i  => cltMAppSlaves, -- [in]
         sTspAxisMaster_i  => srvTspMaster, -- [in]
         sTspAxisSlave_o   => srvTspSlave, -- [out]
         mTspAxisMaster_o  => cltTspMaster, -- [out]
         mTspAxisSlave_i   => cltTspSlave, -- [in]
         openRq_i          => cltOpen_i, -- [in]
         closeRq_i         => cltClose_i, -- [in]
         rssiConnected_o   => cltConnected_o, -- [out]
         axilReadSlave     => cltAxilReadSlave, -- [out]
         axilWriteSlave    => cltAxilWriteSlave, -- [out]
         statusReg_o       => cltStatusReg_o); -- [out]

   -- Server wrapper with transport connected directly to the client wrapper.
   U_Server : entity surf.RssiCoreWrapper
      generic map (
         TPD_G               => TPD_G,
         CLK_FREQUENCY_G     => CLK_FREQUENCY_G,
         TIMEOUT_UNIT_G      => TIMEOUT_UNIT_G,
         SERVER_G            => true,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_G,
         BYPASS_CHUNKER_G    => BYPASS_CHUNKER_G,
         APP_AXIS_CONFIG_G   => (0 => RSSI_AXIS_CONFIG_C),
         TSP_AXIS_CONFIG_G   => RSSI_AXIS_CONFIG_C,
         INIT_SEQ_N_G        => SERVER_INIT_SEQ_N_G,
         CONN_ID_G           => CONN_ID_G,
         VERSION_G           => VERSION_G,
         HEADER_CHKSUM_EN_G  => HEADER_CHKSUM_EN_G,
         MAX_SEG_SIZE_G      => MAX_SEG_SIZE_G,
         ACK_TOUT_G          => ACK_TOUT_G,
         RETRANS_TOUT_G      => RETRANS_TOUT_G,
         NULL_TOUT_G         => NULL_TOUT_G,
         MAX_RETRANS_CNT_G   => MAX_RETRANS_CNT_G,
         MAX_CUM_ACK_CNT_G   => MAX_CUM_ACK_CNT_G)
      port map (
         clk_i             => axisClk, -- [in]
         rst_i             => axisRst, -- [in]
         sAppAxisMasters_i => srvSAppMasters, -- [in]
         sAppAxisSlaves_o  => srvSAppSlaves, -- [out]
         mAppAxisMasters_o => srvMAppMasters, -- [out]
         mAppAxisSlaves_i  => srvMAppSlaves, -- [in]
         sTspAxisMaster_i  => cltTspMaster, -- [in]
         sTspAxisSlave_o   => cltTspSlave, -- [out]
         mTspAxisMaster_o  => srvTspMaster, -- [out]
         mTspAxisSlave_i   => srvTspSlave, -- [in]
         openRq_i          => srvOpen_i, -- [in]
         closeRq_i         => srvClose_i, -- [in]
         rssiConnected_o   => srvConnected_o, -- [out]
         axilReadSlave     => srvAxilReadSlave, -- [out]
         axilWriteSlave    => srvAxilWriteSlave, -- [out]
         statusReg_o       => srvStatusReg_o); -- [out]

end architecture mapping;
