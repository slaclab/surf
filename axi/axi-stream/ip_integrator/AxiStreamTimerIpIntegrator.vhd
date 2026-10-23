-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP integrator wrapper for surf.AxiStreamTimer
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

entity AxiStreamTimerIpIntegrator is
   generic (
      TPD_G         : time                  := 1 ns;
      NUM_STREAMS_G : integer range 1 to 8  := 2;
      NUM_EVENT_G   : integer range 1 to 16 := 2;
      DATA_BYTES_G  : positive              := 4);
   port (
      axisClk        : in  sl;
      axisRst        : in  sl;
      axilClk        : in  sl;
      axilRst        : in  sl;
      S0_AXIS_TVALID : in  sl                             := '0';
      S0_AXIS_TDATA  : in  slv(DATA_BYTES_G*8-1 downto 0) := (others => '0');
      S0_AXIS_TKEEP  : in  slv(DATA_BYTES_G-1 downto 0)   := (others => '0');
      S0_AXIS_TLAST  : in  sl                             := '0';
      S0_AXIS_TREADY : in  sl                             := '0';
      S1_AXIS_TVALID : in  sl                             := '0';
      S1_AXIS_TDATA  : in  slv(DATA_BYTES_G*8-1 downto 0) := (others => '0');
      S1_AXIS_TKEEP  : in  slv(DATA_BYTES_G-1 downto 0)   := (others => '0');
      S1_AXIS_TLAST  : in  sl                             := '0';
      S1_AXIS_TREADY : in  sl                             := '0';
      S_AXI_AWADDR   : in  slv(31 downto 0);
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
      S_AXI_ARADDR   : in  slv(31 downto 0);
      S_AXI_ARPROT   : in  slv(2 downto 0);
      S_AXI_ARVALID  : in  sl;
      S_AXI_ARREADY  : out sl;
      S_AXI_RDATA    : out slv(31 downto 0);
      S_AXI_RRESP    : out slv(1 downto 0);
      S_AXI_RVALID   : out sl;
      S_AXI_RREADY   : in  sl);
end entity AxiStreamTimerIpIntegrator;

architecture rtl of AxiStreamTimerIpIntegrator is

   signal axilResetN      : sl                                             := '1';
   signal streamMasters   : AxiStreamMasterArray(NUM_STREAMS_G-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal streamSlaves    : AxiStreamSlaveArray(NUM_STREAMS_G-1 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal axilReadMaster  : AxiLiteReadMasterType                          := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType                           := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType                         := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType                          := AXI_LITE_WRITE_SLAVE_INIT_C;

begin

   axilResetN <= not axilRst;

   streamMasters(0).tValid                           <= S0_AXIS_TVALID;
   streamMasters(0).tData(DATA_BYTES_G*8-1 downto 0) <= S0_AXIS_TDATA;
   streamMasters(0).tKeep(DATA_BYTES_G-1 downto 0)   <= S0_AXIS_TKEEP;
   streamMasters(0).tLast                            <= S0_AXIS_TLAST;
   streamSlaves(0).tReady                            <= S0_AXIS_TREADY;

   streamMasters(1).tValid                           <= S1_AXIS_TVALID;
   streamMasters(1).tData(DATA_BYTES_G*8-1 downto 0) <= S1_AXIS_TDATA;
   streamMasters(1).tKeep(DATA_BYTES_G-1 downto 0)   <= S1_AXIS_TKEEP;
   streamMasters(1).tLast                            <= S1_AXIS_TLAST;
   streamSlaves(1).tReady                            <= S1_AXIS_TREADY;

   U_ShimLayerSlave : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 32)
      port map (
         S_AXI_ACLK      => axilClk,
         S_AXI_ARESETN   => axilResetN,
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

   U_DUT : entity surf.AxiStreamTimer
      generic map (
         TPD_G         => TPD_G,
         NUM_STREAMS_G => NUM_STREAMS_G,
         NUM_EVENT_G   => NUM_EVENT_G)
      port map (
         axisClk         => axisClk,
         axisRst         => axisRst,
         streamMasters   => streamMasters,
         streamSlaves    => streamSlaves,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end architecture rtl;
