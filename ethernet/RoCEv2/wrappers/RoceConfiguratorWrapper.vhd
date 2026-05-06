-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for RoceConfigurator
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

entity RoceConfiguratorWrapper is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false);
   port (
      clk                : in  sl;
      rst                : in  sl;
      M_META_REQ_TVALID  : out sl;
      M_META_REQ_TDATA   : out slv(302 downto 0);
      M_META_REQ_TREADY  : in  sl;
      S_META_RESP_TVALID : in  sl;
      S_META_RESP_TDATA  : in  slv(275 downto 0);
      S_META_RESP_TREADY : out sl;
      S_AXIL_AWADDR      : in  slv(31 downto 0);
      S_AXIL_AWPROT      : in  slv(2 downto 0);
      S_AXIL_AWVALID     : in  sl;
      S_AXIL_AWREADY     : out sl;
      S_AXIL_WDATA       : in  slv(31 downto 0);
      S_AXIL_WSTRB       : in  slv(3 downto 0);
      S_AXIL_WVALID      : in  sl;
      S_AXIL_WREADY      : out sl;
      S_AXIL_BRESP       : out slv(1 downto 0);
      S_AXIL_BVALID      : out sl;
      S_AXIL_BREADY      : in  sl;
      S_AXIL_ARADDR      : in  slv(31 downto 0);
      S_AXIL_ARPROT      : in  slv(2 downto 0);
      S_AXIL_ARVALID     : in  sl;
      S_AXIL_ARREADY     : out sl;
      S_AXIL_RDATA       : out slv(31 downto 0);
      S_AXIL_RRESP       : out slv(1 downto 0);
      S_AXIL_RVALID      : out sl;
      S_AXIL_RREADY      : in  sl);
end entity RoceConfiguratorWrapper;

architecture rtl of RoceConfiguratorWrapper is

   signal axilClk         : sl;
   signal axilRst         : sl;
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal mMetaReqMaster  : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal mMetaReqSlave   : AxiStreamSlaveType     := AXI_STREAM_SLAVE_INIT_C;
   signal sMetaRespMaster : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal sMetaRespSlave  : AxiStreamSlaveType     := AXI_STREAM_SLAVE_INIT_C;

begin

   ----------------------------------------------------------------------------
   -- AXI-Lite shim
   ----------------------------------------------------------------------------
   U_ShimLayer : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         FREQ_HZ       => 125000000,
         ADDR_WIDTH    => 32)
      port map (
         S_AXI_ACLK      => clk,
         S_AXI_ARESETN   => not rst,
         S_AXI_AWADDR    => S_AXIL_AWADDR,
         S_AXI_AWPROT    => S_AXIL_AWPROT,
         S_AXI_AWVALID   => S_AXIL_AWVALID,
         S_AXI_AWREADY   => S_AXIL_AWREADY,
         S_AXI_WDATA     => S_AXIL_WDATA,
         S_AXI_WSTRB     => S_AXIL_WSTRB,
         S_AXI_WVALID    => S_AXIL_WVALID,
         S_AXI_WREADY    => S_AXIL_WREADY,
         S_AXI_BRESP     => S_AXIL_BRESP,
         S_AXI_BVALID    => S_AXIL_BVALID,
         S_AXI_BREADY    => S_AXIL_BREADY,
         S_AXI_ARADDR    => S_AXIL_ARADDR,
         S_AXI_ARPROT    => S_AXIL_ARPROT,
         S_AXI_ARVALID   => S_AXIL_ARVALID,
         S_AXI_ARREADY   => S_AXIL_ARREADY,
         S_AXI_RDATA     => S_AXIL_RDATA,
         S_AXI_RRESP     => S_AXIL_RRESP,
         S_AXI_RVALID    => S_AXIL_RVALID,
         S_AXI_RREADY    => S_AXIL_RREADY,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   ----------------------------------------------------------------------------
   -- Metadata stream views
   ----------------------------------------------------------------------------
   mMetaReqView : process (mMetaReqMaster) is
   begin
      M_META_REQ_TVALID <= mMetaReqMaster.tValid;
      M_META_REQ_TDATA  <= mMetaReqMaster.tData(302 downto 0);
   end process mMetaReqView;

   mMetaReqSlave.tReady <= M_META_REQ_TREADY;

   sMetaRespComb : process (S_META_RESP_TDATA, S_META_RESP_TVALID) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := S_META_RESP_TVALID;
      v.tData(275 downto 0) := S_META_RESP_TDATA;
      sMetaRespMaster       <= v;
   end process sMetaRespComb;

   S_META_RESP_TREADY <= sMetaRespSlave.tReady;

   ----------------------------------------------------------------------------
   -- DUT hookup
   ----------------------------------------------------------------------------
   U_DUT : entity surf.RoceConfigurator
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk                     => clk,
         rst                     => rst,
         mAxisMetaDataReqMaster  => mMetaReqMaster,
         mAxisMetaDataReqSlave   => mMetaReqSlave,
         sAxisMetaDataRespMaster => sMetaRespMaster,
         sAxisMetaDataRespSlave  => sMetaRespSlave,
         axilReadMaster          => axilReadMaster,
         axilReadSlave           => axilReadSlave,
         axilWriteMaster         => axilWriteMaster,
         axilWriteSlave          => axilWriteSlave);

end architecture rtl;
