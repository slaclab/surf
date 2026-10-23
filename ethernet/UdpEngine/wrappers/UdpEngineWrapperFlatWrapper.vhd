-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for UdpEngineWrapper
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
use surf.EthMacPkg.all;

entity UdpEngineWrapperFlatWrapper is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      CLK_FREQ_G     : real     := 4.0;
      COMM_TIMEOUT_G : positive := 6);
   port (
      clk           : in  sl;
      rst           : in  sl;
      localMac      : in  slv(47 downto 0);
      localIp       : in  slv(31 downto 0);
      softMac       : out slv(47 downto 0);
      softIp        : out slv(31 downto 0);
      sMacTValid    : in  sl;
      sMacTData     : in  slv(127 downto 0);
      sMacTKeep     : in  slv(15 downto 0);
      sMacTLast     : in  sl;
      sMacTReady    : out sl;
      sMacSof       : in  sl;
      sMacEofe      : in  sl;
      mMacTValid    : out sl;
      mMacTData     : out slv(127 downto 0);
      mMacTKeep     : out slv(15 downto 0);
      mMacTLast     : out sl;
      mMacTReady    : in  sl := '1';
      mMacSof       : out sl;
      mMacEofe      : out sl;
      sServerTValid : in  sl;
      sServerTData  : in  slv(127 downto 0);
      sServerTKeep  : in  slv(15 downto 0);
      sServerTLast  : in  sl;
      sServerTReady : out sl;
      sServerTDest  : in  slv(7 downto 0);
      sServerSof    : in  sl;
      sServerEofe   : in  sl;
      mServerTValid : out sl;
      mServerTData  : out slv(127 downto 0);
      mServerTKeep  : out slv(15 downto 0);
      mServerTLast  : out sl;
      mServerTReady : in  sl := '1';
      mServerTDest  : out slv(7 downto 0);
      mServerSof    : out sl;
      mServerEofe   : out sl;
      sClientTValid : in  sl;
      sClientTData  : in  slv(127 downto 0);
      sClientTKeep  : in  slv(15 downto 0);
      sClientTLast  : in  sl;
      sClientTReady : out sl;
      sClientTDest  : in  slv(7 downto 0);
      sClientSof    : in  sl;
      sClientEofe   : in  sl;
      mClientTValid : out sl;
      mClientTData  : out slv(127 downto 0);
      mClientTKeep  : out slv(15 downto 0);
      mClientTLast  : out sl;
      mClientTReady : in  sl := '1';
      mClientTDest  : out slv(7 downto 0);
      mClientSof    : out sl;
      mClientEofe   : out sl;
      S_AXI_AWADDR  : in  slv(31 downto 0);
      S_AXI_AWPROT  : in  slv(2 downto 0);
      S_AXI_AWVALID : in  sl;
      S_AXI_AWREADY : out sl;
      S_AXI_WDATA   : in  slv(31 downto 0);
      S_AXI_WSTRB   : in  slv(3 downto 0);
      S_AXI_WVALID  : in  sl;
      S_AXI_WREADY  : out sl;
      S_AXI_BRESP   : out slv(1 downto 0);
      S_AXI_BVALID  : out sl;
      S_AXI_BREADY  : in  sl;
      S_AXI_ARADDR  : in  slv(31 downto 0);
      S_AXI_ARPROT  : in  slv(2 downto 0);
      S_AXI_ARVALID : in  sl;
      S_AXI_ARREADY : out sl;
      S_AXI_RDATA   : out slv(31 downto 0);
      S_AXI_RRESP   : out slv(1 downto 0);
      S_AXI_RVALID  : out sl;
      S_AXI_RREADY  : in  sl);
end entity UdpEngineWrapperFlatWrapper;

architecture rtl of UdpEngineWrapperFlatWrapper is

   signal sMacMaster      : AxiStreamMasterType              := AXI_STREAM_MASTER_INIT_C;
   signal sMacSlave       : AxiStreamSlaveType               := AXI_STREAM_SLAVE_INIT_C;
   signal mMacMaster      : AxiStreamMasterType              := AXI_STREAM_MASTER_INIT_C;
   signal mMacSlave       : AxiStreamSlaveType               := AXI_STREAM_SLAVE_INIT_C;
   signal sServerMasters  : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal sServerSlaves   : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal mServerMasters  : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal mServerSlaves   : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal sClientMasters  : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal sClientSlaves   : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal mClientMasters  : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal mClientSlaves   : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal axilReadMaster  : AxiLiteReadMasterType            := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType             := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType           := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType            := AXI_LITE_WRITE_SLAVE_INIT_C;

begin

   sMacComb : process (sMacEofe, sMacSof, sMacTData, sMacTKeep, sMacTLast,
                       sMacTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sMacTValid;
      v.tData(127 downto 0) := sMacTData;
      v.tKeep(15 downto 0)  := sMacTKeep;
      v.tLast               := sMacTLast;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sMacSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sMacEofe);
      sMacMaster            <= v;
   end process sMacComb;

   sServerComb : process (sServerEofe, sServerSof, sServerTData, sServerTDest,
                          sServerTKeep, sServerTLast, sServerTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sServerTValid;
      v.tData(127 downto 0) := sServerTData;
      v.tKeep(15 downto 0)  := sServerTKeep;
      v.tLast               := sServerTLast;
      v.tDest(7 downto 0)   := sServerTDest;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sServerSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sServerEofe);
      sServerMasters(0)     <= v;
   end process sServerComb;

   sClientComb : process (sClientEofe, sClientSof, sClientTData, sClientTDest,
                          sClientTKeep, sClientTLast, sClientTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sClientTValid;
      v.tData(127 downto 0) := sClientTData;
      v.tKeep(15 downto 0)  := sClientTKeep;
      v.tLast               := sClientTLast;
      v.tDest(7 downto 0)   := sClientTDest;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sClientSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sClientEofe);
      sClientMasters(0)     <= v;
   end process sClientComb;

   mMacView : process (mMacMaster) is
   begin
      mMacTValid <= mMacMaster.tValid;
      mMacTData  <= mMacMaster.tData(127 downto 0);
      mMacTKeep  <= mMacMaster.tKeep(15 downto 0);
      mMacTLast  <= mMacMaster.tLast;
      mMacSof    <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mMacMaster, EMAC_SOF_BIT_C, 0);
      mMacEofe   <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mMacMaster, EMAC_EOFE_BIT_C);
   end process mMacView;

   mServerView : process (mServerMasters) is
   begin
      mServerTValid <= mServerMasters(0).tValid;
      mServerTData  <= mServerMasters(0).tData(127 downto 0);
      mServerTKeep  <= mServerMasters(0).tKeep(15 downto 0);
      mServerTLast  <= mServerMasters(0).tLast;
      mServerTDest  <= mServerMasters(0).tDest(7 downto 0);
      mServerSof    <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mServerMasters(0), EMAC_SOF_BIT_C, 0);
      mServerEofe   <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mServerMasters(0), EMAC_EOFE_BIT_C);
   end process mServerView;

   mClientView : process (mClientMasters) is
   begin
      mClientTValid <= mClientMasters(0).tValid;
      mClientTData  <= mClientMasters(0).tData(127 downto 0);
      mClientTKeep  <= mClientMasters(0).tKeep(15 downto 0);
      mClientTLast  <= mClientMasters(0).tLast;
      mClientTDest  <= mClientMasters(0).tDest(7 downto 0);
      mClientSof    <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mClientMasters(0), EMAC_SOF_BIT_C, 0);
      mClientEofe   <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mClientMasters(0), EMAC_EOFE_BIT_C);
   end process mClientView;

   axilWriteMaster.awaddr  <= S_AXI_AWADDR;
   axilWriteMaster.awprot  <= S_AXI_AWPROT;
   axilWriteMaster.awvalid <= S_AXI_AWVALID;
   axilWriteMaster.wdata   <= S_AXI_WDATA;
   axilWriteMaster.wstrb   <= S_AXI_WSTRB;
   axilWriteMaster.wvalid  <= S_AXI_WVALID;
   axilWriteMaster.bready  <= S_AXI_BREADY;
   axilReadMaster.araddr   <= S_AXI_ARADDR;
   axilReadMaster.arprot   <= S_AXI_ARPROT;
   axilReadMaster.arvalid  <= S_AXI_ARVALID;
   axilReadMaster.rready   <= S_AXI_RREADY;

   S_AXI_AWREADY <= axilWriteSlave.awready;
   S_AXI_WREADY  <= axilWriteSlave.wready;
   S_AXI_BRESP   <= axilWriteSlave.bresp;
   S_AXI_BVALID  <= axilWriteSlave.bvalid;
   S_AXI_ARREADY <= axilReadSlave.arready;
   S_AXI_RDATA   <= axilReadSlave.rdata;
   S_AXI_RRESP   <= axilReadSlave.rresp;
   S_AXI_RVALID  <= axilReadSlave.rvalid;

   sMacTReady              <= sMacSlave.tReady;
   mMacSlave.tReady        <= mMacTReady;
   sServerTReady           <= sServerSlaves(0).tReady;
   mServerSlaves(0).tReady <= mServerTReady;
   sClientTReady           <= sClientSlaves(0).tReady;
   mClientSlaves(0).tReady <= mClientTReady;

   U_DUT : entity surf.UdpEngineWrapper
      generic map (
         TPD_G               => TPD_G,
         RST_POLARITY_G      => RST_POLARITY_G,
         RST_ASYNC_G         => RST_ASYNC_G,
         SERVER_EN_G         => true,
         SERVER_SIZE_G       => 1,
         SERVER_PORTS_G      => (0 => 8192),
         CLIENT_EN_G         => true,
         CLIENT_SIZE_G       => 1,
         CLIENT_PORTS_G      => (0 => 8193),
         CLIENT_EXT_CONFIG_G => false,
         TX_FLOW_CTRL_G      => true,
         DHCP_G              => false,
         IGMP_G              => false,
         IGMP_GRP_SIZE       => 1,
         CLK_FREQ_G          => CLK_FREQ_G,
         COMM_TIMEOUT_G      => COMM_TIMEOUT_G)
      port map (
         localMac        => localMac,
         localIp         => localIp,
         softMac         => softMac,
         softIp          => softIp,
         obMacMaster     => sMacMaster,
         obMacSlave      => sMacSlave,
         ibMacMaster     => mMacMaster,
         ibMacSlave      => mMacSlave,
         obServerMasters => mServerMasters,
         obServerSlaves  => mServerSlaves,
         ibServerMasters => sServerMasters,
         ibServerSlaves  => sServerSlaves,
         obClientMasters => mClientMasters,
         obClientSlaves  => mClientSlaves,
         ibClientMasters => sClientMasters,
         ibClientSlaves  => sClientSlaves,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         clk             => clk,
         rst             => rst);

end architecture rtl;
