-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for the fixed multi-channel FIR
--              regression configuration.
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

entity FirFilterMultiChannelTestWrapper is
   port (
      S_AXIS_ACLK    : in  std_logic;
      S_AXIS_ARESETN : in  std_logic;
      S_AXIS_TVALID  : in  std_logic;
      S_AXIS_TDATA   : in  std_logic_vector(15 downto 0);
      S_AXIS_TSTRB   : in  std_logic_vector(1 downto 0);
      S_AXIS_TKEEP   : in  std_logic_vector(1 downto 0);
      S_AXIS_TLAST   : in  std_logic;
      S_AXIS_TDEST   : in  std_logic_vector(0 downto 0);
      S_AXIS_TID     : in  std_logic_vector(0 downto 0);
      S_AXIS_TUSER   : in  std_logic_vector(0 downto 0);
      S_AXIS_TREADY  : out std_logic;
      M_AXIS_ACLK    : in  std_logic;
      M_AXIS_ARESETN : in  std_logic;
      M_AXIS_TVALID  : out std_logic;
      M_AXIS_TDATA   : out std_logic_vector(15 downto 0);
      M_AXIS_TSTRB   : out std_logic_vector(1 downto 0);
      M_AXIS_TKEEP   : out std_logic_vector(1 downto 0);
      M_AXIS_TLAST   : out std_logic;
      M_AXIS_TDEST   : out std_logic_vector(0 downto 0);
      M_AXIS_TID     : out std_logic_vector(0 downto 0);
      M_AXIS_TUSER   : out std_logic_vector(0 downto 0);
      M_AXIS_TREADY  : in  std_logic;
      S_AXI_ACLK     : in  std_logic;
      S_AXI_ARESETN  : in  std_logic;
      S_AXI_AWADDR   : in  std_logic_vector(3 downto 0);
      S_AXI_AWPROT   : in  std_logic_vector(2 downto 0);
      S_AXI_AWVALID  : in  std_logic;
      S_AXI_AWREADY  : out std_logic;
      S_AXI_WDATA    : in  std_logic_vector(31 downto 0);
      S_AXI_WSTRB    : in  std_logic_vector(3 downto 0);
      S_AXI_WVALID   : in  std_logic;
      S_AXI_WREADY   : out std_logic;
      S_AXI_BRESP    : out std_logic_vector(1 downto 0);
      S_AXI_BVALID   : out std_logic;
      S_AXI_BREADY   : in  std_logic;
      S_AXI_ARADDR   : in  std_logic_vector(3 downto 0);
      S_AXI_ARPROT   : in  std_logic_vector(2 downto 0);
      S_AXI_ARVALID  : in  std_logic;
      S_AXI_ARREADY  : out std_logic;
      S_AXI_RDATA    : out std_logic_vector(31 downto 0);
      S_AXI_RRESP    : out std_logic_vector(1 downto 0);
      S_AXI_RVALID   : out std_logic;
      S_AXI_RREADY   : in  std_logic);
end entity FirFilterMultiChannelTestWrapper;

architecture rtl of FirFilterMultiChannelTestWrapper is

   signal axisClkSig      : sl;
   signal axisRstSig      : sl;
   signal sAxisMasterSig  : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlaveSig   : AxiStreamSlaveType     := AXI_STREAM_SLAVE_FORCE_C;
   signal mAxisMasterSig  : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlaveSig   : AxiStreamSlaveType     := AXI_STREAM_SLAVE_FORCE_C;
   signal axilClkSig      : sl;
   signal axilRstSig      : sl;
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

begin

   U_S_AXIS : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         TDATA_NUM_BYTES => 2,
         TUSER_WIDTH     => 1,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         HAS_TSTRB       => 1,
         HAS_TKEEP       => 1,
         HAS_TLAST       => 1,
         HAS_TREADY      => 1)
      port map (
         S_AXIS_ACLK    => S_AXIS_ACLK,
         S_AXIS_ARESETN => S_AXIS_ARESETN,
         S_AXIS_TVALID  => S_AXIS_TVALID,
         S_AXIS_TDATA   => S_AXIS_TDATA,
         S_AXIS_TSTRB   => S_AXIS_TSTRB,
         S_AXIS_TKEEP   => S_AXIS_TKEEP,
         S_AXIS_TLAST   => S_AXIS_TLAST,
         S_AXIS_TDEST   => S_AXIS_TDEST,
         S_AXIS_TID     => S_AXIS_TID,
         S_AXIS_TUSER   => S_AXIS_TUSER,
         S_AXIS_TREADY  => S_AXIS_TREADY,
         axisClk        => axisClkSig,
         axisRst        => axisRstSig,
         axisMaster     => sAxisMasterSig,
         axisSlave      => sAxisSlaveSig);

   U_M_AXIS : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         TDATA_NUM_BYTES => 2,
         TUSER_WIDTH     => 1,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         HAS_TSTRB       => 1,
         HAS_TKEEP       => 1,
         HAS_TLAST       => 1,
         HAS_TREADY      => 1)
      port map (
         M_AXIS_ACLK    => M_AXIS_ACLK,
         M_AXIS_ARESETN => M_AXIS_ARESETN,
         M_AXIS_TVALID  => M_AXIS_TVALID,
         M_AXIS_TDATA   => M_AXIS_TDATA,
         M_AXIS_TSTRB   => M_AXIS_TSTRB,
         M_AXIS_TKEEP   => M_AXIS_TKEEP,
         M_AXIS_TLAST   => M_AXIS_TLAST,
         M_AXIS_TDEST   => M_AXIS_TDEST,
         M_AXIS_TID     => M_AXIS_TID,
         M_AXIS_TUSER   => M_AXIS_TUSER,
         M_AXIS_TREADY  => M_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => mAxisMasterSig,
         axisSlave      => mAxisSlaveSig);

   U_AXIL : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         ADDR_WIDTH => 4,
         HAS_PROT   => 1,
         HAS_WSTRB  => 1)
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
         axilClk         => axilClkSig,
         axilRst         => axilRstSig,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   U_DUT : entity surf.FirFilterMultiChannel
      generic map (
         COMMON_CLK_G   => true,
         NUM_TAPS_G     => 3,
         NUM_CHANNELS_G => 2,
         PARALLEL_G     => 2,
         DATA_WIDTH_G   => 8,
         COEFF_WIDTH_G  => 4,
         COEFFICIENTS_G => (0 => 0, 1 => 0, 2 => 0),
         MEMORY_TYPE_G  => "distributed",
         SYNTH_MODE_G   => "inferred")
      port map (
         axisClk         => axisClkSig,
         axisRst         => axisRstSig,
         sAxisMaster     => sAxisMasterSig,
         sAxisSlave      => sAxisSlaveSig,
         mAxisMaster     => mAxisMasterSig,
         mAxisSlave      => mAxisSlaveSig,
         axilClk         => axilClkSig,
         axilRst         => axilRstSig,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end architecture rtl;
