-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Narrow register-path wrapper for surf.AxiStreamDmaV2
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
use surf.AxiPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamDmaV2IpIntegrator is
   generic (
      TPD_G : time := 1 ns);
   port (
      axiClk         : in  sl;
      axiRst         : in  sl;
      interrupt      : out sl;
      online         : out sl;
      acknowledge    : out sl;
      buffGrpPause   : out slv(7 downto 0);
      S_AXI_AWADDR   : in  slv(11 downto 0);
      S_AXI_AWPROT   : in  slv(2 downto 0);
      S_AXI_AWVALID  : in  sl;
      S_AXI_AWREADY  : out sl;
      S_AXI_WDATA    : in  slv(31 downto 0);
      S_AXI_WSTRB    : in  slv(3 downto 0);
      S_AXI_WVALID   : in  sl;
      S_AXI_WREADY   : out sl;
      S_AXI_BRESP    : out slv(1 downto 0);
      S_AXI_BVALID   : out sl;
      S_AXI_BREADY   : in  sl;
      S_AXI_ARADDR   : in  slv(11 downto 0);
      S_AXI_ARPROT   : in  slv(2 downto 0);
      S_AXI_ARVALID  : in  sl;
      S_AXI_ARREADY  : out sl;
      S_AXI_RDATA    : out slv(31 downto 0);
      S_AXI_RRESP    : out slv(1 downto 0);
      S_AXI_RVALID   : out sl;
      S_AXI_RREADY   : in  sl);
end entity AxiStreamDmaV2IpIntegrator;

architecture rtl of AxiStreamDmaV2IpIntegrator is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 16,
      DATA_BYTES_C => 8,
      ID_BITS_C    => 8,
      LEN_BITS_C   => 8);

   signal axiResetN       : sl := '1';
   signal axilReadMaster  : AxiLiteReadMasterType     := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType      := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType    := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType     := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal sAxisMasters    : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal sAxisSlaves     : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal mAxisMasters    : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal mAxisSlaves     : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal mAxisCtrl       : AxiStreamCtrlArray(0 downto 0)   := (others => AXI_STREAM_CTRL_UNUSED_C);
   signal axiReadMasters  : AxiReadMasterArray(1 downto 0)   := (others => AXI_READ_MASTER_INIT_C);
   signal axiReadSlaves   : AxiReadSlaveArray(1 downto 0)    := (others => AXI_READ_SLAVE_INIT_C);
   signal axiWriteMasters : AxiWriteMasterArray(1 downto 0)  := (others => AXI_WRITE_MASTER_INIT_C);
   signal axiWriteSlaves  : AxiWriteSlaveArray(1 downto 0)   := (others => AXI_WRITE_SLAVE_INIT_C);
   signal axiWriteCtrl    : AxiCtrlArray(1 downto 0)         := (others => AXI_CTRL_INIT_C);
   signal onlineVec       : slv(0 downto 0);
   signal acknowledgeVec  : slv(0 downto 0);

begin

   ---------------------------------------------------------------------------
   -- AXI-Lite shim
   ---------------------------------------------------------------------------
   axiResetN <= not axiRst;
   online <= onlineVec(0);
   acknowledge <= acknowledgeVec(0);

   U_AXIL : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 12)
      port map (
         S_AXI_ACLK      => axiClk,
         S_AXI_ARESETN   => axiResetN,
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

   ---------------------------------------------------------------------------
   -- DUT
   ---------------------------------------------------------------------------
   U_DUT : entity surf.AxiStreamDmaV2
      generic map (
         TPD_G           => TPD_G,
         DESC_AWIDTH_G   => 8,
         AXIS_CONFIG_G   => AXIS_CONFIG_C,
         AXI_DMA_CONFIG_G => AXI_CONFIG_C,
         CHAN_COUNT_G    => 1,
         BURST_BYTES_G   => 16,
         RD_PEND_THRESH_G => 4)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         interrupt       => interrupt,
         online          => onlineVec,
         acknowledge     => acknowledgeVec,
         buffGrpPause    => buffGrpPause,
         sAxisMasters    => sAxisMasters,
         sAxisSlaves     => sAxisSlaves,
         mAxisMasters    => mAxisMasters,
         mAxisSlaves     => mAxisSlaves,
         mAxisCtrl       => mAxisCtrl,
         axiReadMasters  => axiReadMasters,
         axiReadSlaves   => axiReadSlaves,
         axiWriteMasters => axiWriteMasters,
         axiWriteSlaves  => axiWriteSlaves,
         axiWriteCtrl    => axiWriteCtrl);

end architecture rtl;
