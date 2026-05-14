-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for RawEthFramer
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
use surf.SsiPkg.all;
use surf.RawEthFramerPkg.all;

entity RawEthFramerFlatWrapper is
   generic (
      TPD_G      : time             := 1 ns;
      ETH_TYPE_G : slv(15 downto 0) := x"0010");
   port (
      clk           : in  sl;
      rst           : in  sl;
      localMac      : in  slv(47 downto 0);
      sMacTValid    : in  sl;
      sMacTData     : in  slv(63 downto 0);
      sMacTKeep     : in  slv(7 downto 0);
      sMacTLast     : in  sl;
      sMacTReady    : out sl;
      sMacSof       : in  sl;
      sMacEofe      : in  sl;
      mMacTValid    : out sl;
      mMacTData     : out slv(63 downto 0);
      mMacTKeep     : out slv(7 downto 0);
      mMacTLast     : out sl;
      mMacTReady    : in  sl := '1';
      mMacSof       : out sl;
      mMacEofe      : out sl;
      sAppTValid    : in  sl;
      sAppTData     : in  slv(63 downto 0);
      sAppTKeep     : in  slv(7 downto 0);
      sAppTLast     : in  sl;
      sAppTReady    : out sl;
      sAppTDest     : in  slv(7 downto 0);
      sAppSof       : in  sl;
      sAppBcf       : in  sl;
      sAppEofe      : in  sl;
      mAppTValid    : out sl;
      mAppTData     : out slv(63 downto 0);
      mAppTKeep     : out slv(7 downto 0);
      mAppTLast     : out sl;
      mAppTReady    : in  sl := '1';
      mAppTDest     : out slv(7 downto 0);
      mAppSof       : out sl;
      mAppBcf       : out sl;
      mAppEofe      : out sl;
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
end entity RawEthFramerFlatWrapper;

architecture rtl of RawEthFramerFlatWrapper is

   signal sMacMaster      : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal sMacSlave       : AxiStreamSlaveType     := AXI_STREAM_SLAVE_INIT_C;
   signal mMacMaster      : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal mMacSlave       : AxiStreamSlaveType     := AXI_STREAM_SLAVE_INIT_C;
   signal sAppMaster      : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal sAppSlave       : AxiStreamSlaveType     := AXI_STREAM_SLAVE_INIT_C;
   signal mAppMaster      : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal mAppSlave       : AxiStreamSlaveType     := AXI_STREAM_SLAVE_INIT_C;
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

begin

   -- Flatten the inbound MAC-side stream that feeds the RX path.
   sMacComb : process (sMacEofe, sMacSof, sMacTData, sMacTKeep, sMacTLast,
                       sMacTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                    := AXI_STREAM_MASTER_INIT_C;
      v.tValid             := sMacTValid;
      v.tData(63 downto 0) := sMacTData;
      v.tKeep(7 downto 0)  := sMacTKeep;
      v.tLast              := sMacTLast;
      ssiSetUserSof(RAW_ETH_CONFIG_INIT_C, v, sMacSof);
      ssiSetUserEofe(RAW_ETH_CONFIG_INIT_C, v, sMacEofe);
      sMacMaster           <= v;
   end process sMacComb;

   -- Flatten the application-side stream that feeds the TX path.
   sAppComb : process (sAppBcf, sAppEofe, sAppSof, sAppTData, sAppTDest,
                       sAppTKeep, sAppTLast, sAppTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                    := AXI_STREAM_MASTER_INIT_C;
      v.tValid             := sAppTValid;
      v.tData(63 downto 0) := sAppTData;
      v.tKeep(7 downto 0)  := sAppTKeep;
      v.tLast              := sAppTLast;
      v.tDest(7 downto 0)  := sAppTDest;
      ssiSetUserSof(RAW_ETH_CONFIG_INIT_C, v, sAppSof);
      ssiSetUserBcf(RAW_ETH_CONFIG_INIT_C, v, sAppBcf);
      ssiSetUserEofe(RAW_ETH_CONFIG_INIT_C, v, sAppEofe);
      sAppMaster           <= v;
   end process sAppComb;

   sMacTReady       <= sMacSlave.tReady;
   sAppTReady       <= sAppSlave.tReady;
   mMacSlave.tReady <= mMacTReady;
   mAppSlave.tReady <= mAppTReady;

   -- Re-expand the outbound MAC-side stream for cocotb inspection.
   mMacView : process (mMacMaster) is
   begin
      mMacTValid <= mMacMaster.tValid;
      mMacTData  <= mMacMaster.tData(63 downto 0);
      mMacTKeep  <= mMacMaster.tKeep(7 downto 0);
      mMacTLast  <= mMacMaster.tLast;
      mMacSof    <= ssiGetUserSof(RAW_ETH_CONFIG_INIT_C, mMacMaster);
      mMacEofe   <= ssiGetUserEofe(RAW_ETH_CONFIG_INIT_C, mMacMaster);
   end process mMacView;

   -- Re-expand the application-side output stream and metadata.
   mAppView : process (mAppMaster) is
   begin
      mAppTValid <= mAppMaster.tValid;
      mAppTData  <= mAppMaster.tData(63 downto 0);
      mAppTKeep  <= mAppMaster.tKeep(7 downto 0);
      mAppTLast  <= mAppMaster.tLast;
      mAppTDest  <= mAppMaster.tDest(7 downto 0);
      mAppSof    <= ssiGetUserSof(RAW_ETH_CONFIG_INIT_C, mAppMaster);
      mAppBcf    <= ssiGetUserBcf(RAW_ETH_CONFIG_INIT_C, mAppMaster);
      mAppEofe   <= ssiGetUserEofe(RAW_ETH_CONFIG_INIT_C, mAppMaster);
   end process mAppView;

   U_AxilShim : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         INTERFACENAME => "S_AXI",
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 32)
      port map (
         S_AXI_ACLK      => clk,
         S_AXI_ARESETN   => not rst,
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

   U_DUT : entity surf.RawEthFramerWrapper
      generic map (
         TPD_G      => TPD_G,
         ETH_TYPE_G => ETH_TYPE_G)
      port map (
         localMac        => localMac,
         obMacMaster     => sMacMaster,
         obMacSlave      => sMacSlave,
         ibMacMaster     => mMacMaster,
         ibMacSlave      => mMacSlave,
         ibAppMaster     => mAppMaster,
         ibAppSlave      => mAppSlave,
         obAppMaster     => sAppMaster,
         obAppSlave      => sAppSlave,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         clk             => clk,
         rst             => rst);

end architecture rtl;
