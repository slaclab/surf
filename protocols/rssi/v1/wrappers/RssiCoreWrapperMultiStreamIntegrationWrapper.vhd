-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing multi-stream RSSI core-wrapper integration wrapper
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

entity RssiCoreWrapperMultiStreamIntegrationWrapper is
   generic (
      TPD_G               : time     := 1 ns;
      CLK_FREQUENCY_G     : real     := 1.0E6;
      TIMEOUT_UNIT_G      : real     := 1.0E-6;
      WINDOW_ADDR_SIZE_G  : positive := 3;
      MAX_SEG_SIZE_G      : positive := 128;
      BYPASS_CHUNKER_G    : boolean  := false;
      APP_ILEAVE_EN_G     : boolean  := true;
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

      cltSApp0TValid : in  sl;
      cltSApp0TReady : out sl;
      cltSApp0TData  : in  slv(63 downto 0);
      cltSApp0TKeep  : in  slv(7 downto 0);
      cltSApp0TLast  : in  sl;
      cltSApp0Sof    : in  sl;
      cltSApp0Eofe   : in  sl;

      cltSApp1TValid : in  sl;
      cltSApp1TReady : out sl;
      cltSApp1TData  : in  slv(63 downto 0);
      cltSApp1TKeep  : in  slv(7 downto 0);
      cltSApp1TLast  : in  sl;
      cltSApp1Sof    : in  sl;
      cltSApp1Eofe   : in  sl;

      cltMApp0TValid : out sl;
      cltMApp0TReady : in  sl;
      cltMApp0TData  : out slv(63 downto 0);
      cltMApp0TKeep  : out slv(7 downto 0);
      cltMApp0TLast  : out sl;
      cltMApp0Sof    : out sl;
      cltMApp0Eofe   : out sl;

      cltMApp1TValid : out sl;
      cltMApp1TReady : in  sl;
      cltMApp1TData  : out slv(63 downto 0);
      cltMApp1TKeep  : out slv(7 downto 0);
      cltMApp1TLast  : out sl;
      cltMApp1Sof    : out sl;
      cltMApp1Eofe   : out sl;

      srvSApp0TValid : in  sl;
      srvSApp0TReady : out sl;
      srvSApp0TData  : in  slv(63 downto 0);
      srvSApp0TKeep  : in  slv(7 downto 0);
      srvSApp0TLast  : in  sl;
      srvSApp0Sof    : in  sl;
      srvSApp0Eofe   : in  sl;

      srvSApp1TValid : in  sl;
      srvSApp1TReady : out sl;
      srvSApp1TData  : in  slv(63 downto 0);
      srvSApp1TKeep  : in  slv(7 downto 0);
      srvSApp1TLast  : in  sl;
      srvSApp1Sof    : in  sl;
      srvSApp1Eofe   : in  sl;

      srvMApp0TValid : out sl;
      srvMApp0TReady : in  sl;
      srvMApp0TData  : out slv(63 downto 0);
      srvMApp0TKeep  : out slv(7 downto 0);
      srvMApp0TLast  : out sl;
      srvMApp0Sof    : out sl;
      srvMApp0Eofe   : out sl;

      srvMApp1TValid : out sl;
      srvMApp1TReady : in  sl;
      srvMApp1TData  : out slv(63 downto 0);
      srvMApp1TKeep  : out slv(7 downto 0);
      srvMApp1TLast  : out sl;
      srvMApp1Sof    : out sl;
      srvMApp1Eofe   : out sl;

      cltConnected_o : out sl;
      srvConnected_o : out sl;
      cltStatusReg_o : out slv(8 downto 0);
      srvStatusReg_o : out slv(8 downto 0));
end entity RssiCoreWrapperMultiStreamIntegrationWrapper;

architecture mapping of RssiCoreWrapperMultiStreamIntegrationWrapper is

   constant APP_STREAM_ROUTES_C : Slv8Array(1 downto 0) := (
      0 => x"00",
      1 => x"01");
   constant APP_AXIS_BASE_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => RSSI_WORD_WIDTH_C,
      tKeepMode => TKEEP_COMP_C,
      tUserMode => TUSER_FIRST_LAST_C,
      tDestBits => 8);
   constant APP_AXIS_CONFIG_C : AxiStreamConfigArray(1 downto 0) := (
      others => APP_AXIS_BASE_CONFIG_C);

   signal cltSAppMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal cltSAppSlaves  : AxiStreamSlaveArray(1 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal cltMAppMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal cltMAppSlaves  : AxiStreamSlaveArray(1 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);

   signal srvSAppMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal srvSAppSlaves  : AxiStreamSlaveArray(1 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal srvMAppMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal srvMAppSlaves  : AxiStreamSlaveArray(1 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);

   signal cltTspMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal cltTspSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal srvTspMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal srvTspSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal cltAxilReadSlave  : AxiLiteReadSlaveType;
   signal cltAxilWriteSlave : AxiLiteWriteSlaveType;
   signal srvAxilReadSlave  : AxiLiteReadSlaveType;
   signal srvAxilWriteSlave : AxiLiteWriteSlaveType;

begin

   -- Flattened client application inputs.
   cltSApp0Comb : process (cltSApp0Eofe, cltSApp0Sof, cltSApp0TData,
                           cltSApp0TKeep, cltSApp0TLast,
                           cltSApp0TValid) is
      variable v : AxiStreamMasterType;
   begin
      v                    := AXI_STREAM_MASTER_INIT_C;
      v.tValid             := cltSApp0TValid;
      v.tData(63 downto 0) := cltSApp0TData;
      v.tStrb(7 downto 0)  := cltSApp0TKeep;
      v.tKeep(7 downto 0)  := cltSApp0TKeep;
      v.tLast              := cltSApp0TLast;
      ssiSetUserSof(RSSI_AXIS_CONFIG_C, v, cltSApp0Sof);
      ssiSetUserEofe(RSSI_AXIS_CONFIG_C, v, cltSApp0Eofe);
      cltSAppMasters(0) <= v;
   end process cltSApp0Comb;

   cltSApp1Comb : process (cltSApp1Eofe, cltSApp1Sof, cltSApp1TData,
                           cltSApp1TKeep, cltSApp1TLast,
                           cltSApp1TValid) is
      variable v : AxiStreamMasterType;
   begin
      v                    := AXI_STREAM_MASTER_INIT_C;
      v.tValid             := cltSApp1TValid;
      v.tData(63 downto 0) := cltSApp1TData;
      v.tStrb(7 downto 0)  := cltSApp1TKeep;
      v.tKeep(7 downto 0)  := cltSApp1TKeep;
      v.tLast              := cltSApp1TLast;
      ssiSetUserSof(RSSI_AXIS_CONFIG_C, v, cltSApp1Sof);
      ssiSetUserEofe(RSSI_AXIS_CONFIG_C, v, cltSApp1Eofe);
      cltSAppMasters(1) <= v;
   end process cltSApp1Comb;

   -- Flattened server application inputs.
   srvSApp0Comb : process (srvSApp0Eofe, srvSApp0Sof, srvSApp0TData,
                           srvSApp0TKeep, srvSApp0TLast,
                           srvSApp0TValid) is
      variable v : AxiStreamMasterType;
   begin
      v                    := AXI_STREAM_MASTER_INIT_C;
      v.tValid             := srvSApp0TValid;
      v.tData(63 downto 0) := srvSApp0TData;
      v.tStrb(7 downto 0)  := srvSApp0TKeep;
      v.tKeep(7 downto 0)  := srvSApp0TKeep;
      v.tLast              := srvSApp0TLast;
      ssiSetUserSof(RSSI_AXIS_CONFIG_C, v, srvSApp0Sof);
      ssiSetUserEofe(RSSI_AXIS_CONFIG_C, v, srvSApp0Eofe);
      srvSAppMasters(0) <= v;
   end process srvSApp0Comb;

   srvSApp1Comb : process (srvSApp1Eofe, srvSApp1Sof, srvSApp1TData,
                           srvSApp1TKeep, srvSApp1TLast,
                           srvSApp1TValid) is
      variable v : AxiStreamMasterType;
   begin
      v                    := AXI_STREAM_MASTER_INIT_C;
      v.tValid             := srvSApp1TValid;
      v.tData(63 downto 0) := srvSApp1TData;
      v.tStrb(7 downto 0)  := srvSApp1TKeep;
      v.tKeep(7 downto 0)  := srvSApp1TKeep;
      v.tLast              := srvSApp1TLast;
      ssiSetUserSof(RSSI_AXIS_CONFIG_C, v, srvSApp1Sof);
      ssiSetUserEofe(RSSI_AXIS_CONFIG_C, v, srvSApp1Eofe);
      srvSAppMasters(1) <= v;
   end process srvSApp1Comb;

   cltSApp0TReady <= cltSAppSlaves(0).tReady;
   cltSApp1TReady <= cltSAppSlaves(1).tReady;
   srvSApp0TReady <= srvSAppSlaves(0).tReady;
   srvSApp1TReady <= srvSAppSlaves(1).tReady;

   -- Flattened client application outputs.
   cltMAppSlaves(0).tReady <= cltMApp0TReady;
   cltMApp0TValid          <= cltMAppMasters(0).tValid;
   cltMApp0TData           <= cltMAppMasters(0).tData(63 downto 0);
   cltMApp0TKeep           <= cltMAppMasters(0).tKeep(7 downto 0);
   cltMApp0TLast           <= cltMAppMasters(0).tLast;
   cltMApp0Sof             <= ssiGetUserSof(RSSI_AXIS_CONFIG_C, cltMAppMasters(0));
   cltMApp0Eofe            <= ssiGetUserEofe(RSSI_AXIS_CONFIG_C, cltMAppMasters(0));

   cltMAppSlaves(1).tReady <= cltMApp1TReady;
   cltMApp1TValid          <= cltMAppMasters(1).tValid;
   cltMApp1TData           <= cltMAppMasters(1).tData(63 downto 0);
   cltMApp1TKeep           <= cltMAppMasters(1).tKeep(7 downto 0);
   cltMApp1TLast           <= cltMAppMasters(1).tLast;
   cltMApp1Sof             <= ssiGetUserSof(RSSI_AXIS_CONFIG_C, cltMAppMasters(1));
   cltMApp1Eofe            <= ssiGetUserEofe(RSSI_AXIS_CONFIG_C, cltMAppMasters(1));

   -- Flattened server application outputs.
   srvMAppSlaves(0).tReady <= srvMApp0TReady;
   srvMApp0TValid          <= srvMAppMasters(0).tValid;
   srvMApp0TData           <= srvMAppMasters(0).tData(63 downto 0);
   srvMApp0TKeep           <= srvMAppMasters(0).tKeep(7 downto 0);
   srvMApp0TLast           <= srvMAppMasters(0).tLast;
   srvMApp0Sof             <= ssiGetUserSof(RSSI_AXIS_CONFIG_C, srvMAppMasters(0));
   srvMApp0Eofe            <= ssiGetUserEofe(RSSI_AXIS_CONFIG_C, srvMAppMasters(0));

   srvMAppSlaves(1).tReady <= srvMApp1TReady;
   srvMApp1TValid          <= srvMAppMasters(1).tValid;
   srvMApp1TData           <= srvMAppMasters(1).tData(63 downto 0);
   srvMApp1TKeep           <= srvMAppMasters(1).tKeep(7 downto 0);
   srvMApp1TLast           <= srvMAppMasters(1).tLast;
   srvMApp1Sof             <= ssiGetUserSof(RSSI_AXIS_CONFIG_C, srvMAppMasters(1));
   srvMApp1Eofe            <= ssiGetUserEofe(RSSI_AXIS_CONFIG_C, srvMAppMasters(1));

   -- Client wrapper with transport connected directly to the server wrapper.
   U_Client : entity surf.RssiCoreWrapper
      generic map (
         TPD_G               => TPD_G,
         CLK_FREQUENCY_G     => CLK_FREQUENCY_G,
         TIMEOUT_UNIT_G      => TIMEOUT_UNIT_G,
         SERVER_G            => false,
         WINDOW_ADDR_SIZE_G  => WINDOW_ADDR_SIZE_G,
         BYPASS_CHUNKER_G    => BYPASS_CHUNKER_G,
         APP_STREAMS_G       => 2,
         APP_STREAM_ROUTES_G => APP_STREAM_ROUTES_C,
         APP_ILEAVE_EN_G     => APP_ILEAVE_EN_G,
         APP_AXIS_CONFIG_G   => APP_AXIS_CONFIG_C,
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
         APP_STREAMS_G       => 2,
         APP_STREAM_ROUTES_G => APP_STREAM_ROUTES_C,
         APP_ILEAVE_EN_G     => APP_ILEAVE_EN_G,
         APP_AXIS_CONFIG_G   => APP_AXIS_CONFIG_C,
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
