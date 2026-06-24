-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for the FULL RoCEv2AxiStreamRdma
--   (RoCEv2Engine[blue-rdma Verilog] + RoCEv2Dcqcn + RoCEv2AxiStreamRdmaCore).
--
--   Flattens the record ports into plain std_logic/std_logic_vector so a
--   mixed-language (VCS) cocotb bench can drive: the inbound PRBS payload stream,
--   the RoCEv2 UDP port-4791 pair (obUdp = responses IN, ibUdp = requests OUT),
--   and the merged AXI-Lite slave (Engine 0x0_000 incl. RoceConfigurator metadata
--   regs 0xF00+, Dcqcn 0x1_000, Core 0x2_000). This is the same DUT that runs on
--   the KCU105, so a go-back-N responder on the UDP port reproduces the engine's
--   real DMA-read-reissue behavior (HW DmaReadCount measurement).
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
use surf.SsiPkg.all;
use surf.AxiLitePkg.all;
use surf.RoCEv2Pkg.all;

entity RoCEv2AxiStreamRdmaWrapper is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk                  : in  sl;
      rst                  : in  sl;
      -- Inbound PRBS payload stream (TB AxiStreamSource drives; 32-byte beats)
      S_AXIS_TVALID        : in  sl;
      S_AXIS_TDATA         : in  slv(255 downto 0);
      S_AXIS_TKEEP         : in  slv(31 downto 0);
      S_AXIS_TLAST         : in  sl;
      S_AXIS_TREADY        : out sl;
      -- obUdp: RoCEv2 UDP responses INTO the engine (TB drives = go-back-N ACK/NAK)
      S_OBUDP_TVALID       : in  sl;
      S_OBUDP_TDATA        : in  slv(255 downto 0);
      S_OBUDP_TKEEP        : in  slv(31 downto 0);
      S_OBUDP_TLAST        : in  sl;
      S_OBUDP_TUSER        : in  slv(1 downto 0);
      S_OBUDP_TREADY       : out sl;
      -- ibUdp: RoCEv2 UDP requests OUT of the engine (TB observes = transmissions)
      M_IBUDP_TVALID       : out sl;
      M_IBUDP_TDATA        : out slv(255 downto 0);
      M_IBUDP_TKEEP        : out slv(31 downto 0);
      M_IBUDP_TLAST        : out sl;
      M_IBUDP_TUSER        : out slv(1 downto 0);
      M_IBUDP_TREADY       : in  sl;
      -- AXI-Lite (cocotbext-axi AxiLiteMaster drives the flat AXI4-Lite bus)
      S_AXIL_AWADDR        : in  slv(31 downto 0);
      S_AXIL_AWPROT        : in  slv(2 downto 0);
      S_AXIL_AWVALID       : in  sl;
      S_AXIL_AWREADY       : out sl;
      S_AXIL_WDATA         : in  slv(31 downto 0);
      S_AXIL_WSTRB         : in  slv(3 downto 0);
      S_AXIL_WVALID        : in  sl;
      S_AXIL_WREADY        : out sl;
      S_AXIL_BRESP         : out slv(1 downto 0);
      S_AXIL_BVALID        : out sl;
      S_AXIL_BREADY        : in  sl;
      S_AXIL_ARADDR        : in  slv(31 downto 0);
      S_AXIL_ARPROT        : in  slv(2 downto 0);
      S_AXIL_ARVALID       : in  sl;
      S_AXIL_ARREADY       : out sl;
      S_AXIL_RDATA         : out slv(31 downto 0);
      S_AXIL_RRESP         : out slv(1 downto 0);
      S_AXIL_RVALID        : out sl;
      S_AXIL_RREADY        : in  sl);
end entity RoCEv2AxiStreamRdmaWrapper;

architecture rtl of RoCEv2AxiStreamRdmaWrapper is

   signal axilClk         : sl;
   signal axilRst         : sl;
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal obUdpMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal obUdpSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal ibUdpMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal ibUdpSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   ----------------------------------------------------------------------------
   -- AXI-Lite shim (flat AXI4-Lite <-> AxiLite record)
   ----------------------------------------------------------------------------
   U_ShimLayer : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         FREQ_HZ       => 156250000,
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
   -- Record <-> flat packing
   ----------------------------------------------------------------------------
   -- Inbound PRBS payload (TB drives)
   sAxisComb : process (S_AXIS_TVALID, S_AXIS_TDATA, S_AXIS_TKEEP, S_AXIS_TLAST) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := S_AXIS_TVALID;
      v.tData(255 downto 0) := S_AXIS_TDATA;
      v.tKeep(31 downto 0)  := S_AXIS_TKEEP;
      v.tLast               := S_AXIS_TLAST;
      sAxisMaster           <= v;
   end process sAxisComb;
   S_AXIS_TREADY <= sAxisSlave.tReady;

   -- obUdp responses INTO the engine (TB drives go-back-N ACK/NAK packets)
   obUdpComb : process (S_OBUDP_TVALID, S_OBUDP_TDATA, S_OBUDP_TKEEP, S_OBUDP_TLAST, S_OBUDP_TUSER) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := S_OBUDP_TVALID;
      v.tData(255 downto 0) := S_OBUDP_TDATA;
      v.tKeep(31 downto 0)  := S_OBUDP_TKEEP;
      v.tLast               := S_OBUDP_TLAST;
      v.tUser(1 downto 0)   := S_OBUDP_TUSER;
      obUdpMaster           <= v;
   end process obUdpComb;
   S_OBUDP_TREADY <= obUdpSlave.tReady;

   -- ibUdp requests OUT of the engine (TB observes = transmissions)
   M_IBUDP_TVALID        <= ibUdpMaster.tValid;
   M_IBUDP_TDATA         <= ibUdpMaster.tData(255 downto 0);
   M_IBUDP_TKEEP         <= ibUdpMaster.tKeep(31 downto 0);
   M_IBUDP_TLAST         <= ibUdpMaster.tLast;
   M_IBUDP_TUSER         <= ibUdpMaster.tUser(1 downto 0);
   ibUdpSlave.tReady     <= M_IBUDP_TREADY;

   ----------------------------------------------------------------------------
   -- DUT: the full RoCEv2AxiStreamRdma (engine + DCQCN + host-logic core).
   ----------------------------------------------------------------------------
   U_DUT : entity surf.RoCEv2AxiStreamRdma
      generic map (
         TPD_G            => TPD_G,
         DCQCN_EN_G       => true,
         AXIL_BASE_ADDR_G => x"0000_0000",
         AXIS_CONFIG_G    => ssiAxiStreamConfig(dataBytes => TDATA_ROCE_NUM_BYTES_C, tKeepMode => TKEEP_NORMAL_C, tDestBits => 0))
      port map (
         roceClk         => clk,
         roceRst         => rst,
         sAxisMaster     => sAxisMaster,
         sAxisSlave      => sAxisSlave,
         obUdpMaster     => obUdpMaster,
         obUdpSlave      => obUdpSlave,
         ibUdpMaster     => ibUdpMaster,
         ibUdpSlave      => ibUdpSlave,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end architecture rtl;
