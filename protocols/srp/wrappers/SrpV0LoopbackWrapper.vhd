-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing loopback wrapper for the two SRPv0 AXI-Lite bridges
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

entity SrpV0LoopbackWrapper is
   port (
      S_AXI_ACLK    : in  std_logic;
      S_AXI_ARESETN : in  std_logic;
      S_AXI_AWADDR  : in  std_logic_vector(11 downto 0);
      S_AXI_AWPROT  : in  std_logic_vector(2 downto 0);
      S_AXI_AWVALID : in  std_logic;
      S_AXI_AWREADY : out std_logic;
      S_AXI_WDATA   : in  std_logic_vector(31 downto 0);
      S_AXI_WSTRB   : in  std_logic_vector(3 downto 0);
      S_AXI_WVALID  : in  std_logic;
      S_AXI_WREADY  : out std_logic;
      S_AXI_BRESP   : out std_logic_vector(1 downto 0);
      S_AXI_BVALID  : out std_logic;
      S_AXI_BREADY  : in  std_logic;
      S_AXI_ARADDR  : in  std_logic_vector(11 downto 0);
      S_AXI_ARPROT  : in  std_logic_vector(2 downto 0);
      S_AXI_ARVALID : in  std_logic;
      S_AXI_ARREADY : out std_logic;
      S_AXI_RDATA   : out std_logic_vector(31 downto 0);
      S_AXI_RRESP   : out std_logic_vector(1 downto 0);
      S_AXI_RVALID  : out std_logic;
      S_AXI_RREADY  : in  std_logic);
end entity SrpV0LoopbackWrapper;

architecture rtl of SrpV0LoopbackWrapper is

   constant TPD_C         : time                := 10 ns / 4;
   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);

   signal axilClk : sl := '0';
   signal axilRst : sl := '1';

   signal uutAxilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal uutAxilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal uutAxilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal uutAxilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal srpAxilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal srpAxilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal srpAxilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal srpAxilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;

   signal txAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal rxAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rxAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   -- AXI-Lite shim layer for cocotb.
   U_ShimLayerSlave : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         INTERFACENAME => "S_AXI",
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 12)
      port map (
         S_AXI_ACLK      => S_AXI_ACLK,
         S_AXI_ARESETN   => S_AXI_ARESETN,
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
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => uutAxilReadMaster,
         axilReadSlave   => uutAxilReadSlave,
         axilWriteMaster => uutAxilWriteMaster,
         axilWriteSlave  => uutAxilWriteSlave);

   -- SRPv0 bridge pair under test.
   U_AxiLiteSrpV0 : entity surf.AxiLiteSrpV0
      generic map (
         TPD_G               => TPD_C,
         RESP_THOLD_G        => 1,
         SLAVE_READY_EN_G    => true,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_PAUSE_THRESH_G => 256,
         AXI_STREAM_CONFIG_G => AXIS_CONFIG_C)
      port map (
         mAxisClk         => axilClk,
         mAxisRst         => axilRst,
         mAxisMaster      => txAxisMaster,
         mAxisSlave       => txAxisSlave,
         sAxisClk         => axilClk,
         sAxisRst         => axilRst,
         sAxisMaster      => rxAxisMaster,
         sAxisSlave       => rxAxisSlave,
         sAxisCtrl        => open,
         axilClk          => axilClk,
         axilRst          => axilRst,
         sAxilWriteMaster => uutAxilWriteMaster,
         sAxilWriteSlave  => uutAxilWriteSlave,
         sAxilReadMaster  => uutAxilReadMaster,
         sAxilReadSlave   => uutAxilReadSlave);

   U_SrpV0AxiLite : entity surf.SrpV0AxiLite
      generic map (
         TPD_G               => TPD_C,
         RESP_THOLD_G        => 1,
         SLAVE_READY_EN_G    => true,
         EN_32BIT_ADDR_G     => true,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_PAUSE_THRESH_G => 256,
         AXI_STREAM_CONFIG_G => AXIS_CONFIG_C)
      port map (
         sAxisClk            => axilClk,
         sAxisRst            => axilRst,
         sAxisMaster         => txAxisMaster,
         sAxisSlave          => txAxisSlave,
         sAxisCtrl           => open,
         mAxisClk            => axilClk,
         mAxisRst            => axilRst,
         mAxisMaster         => rxAxisMaster,
         mAxisSlave          => rxAxisSlave,
         axiLiteClk          => axilClk,
         axiLiteRst          => axilRst,
         mAxiLiteWriteMaster => srpAxilWriteMaster,
         mAxiLiteWriteSlave  => srpAxilWriteSlave,
         mAxiLiteReadMaster  => srpAxilReadMaster,
         mAxiLiteReadSlave   => srpAxilReadSlave);

   U_MEM : entity surf.AxiDualPortRam
      generic map (
         TPD_G        => TPD_C,
         COMMON_CLK_G => true,
         ADDR_WIDTH_G => 12,
         DATA_WIDTH_G => 32)
      port map (
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => srpAxilReadMaster,
         axiReadSlave   => srpAxilReadSlave,
         axiWriteMaster => srpAxilWriteMaster,
         axiWriteSlave  => srpAxilWriteSlave);

end architecture rtl;
