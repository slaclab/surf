-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: surf.AxiStreamDemux/surf.AxiStreamMux cocoTB testbed
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamDemuxMuxTb is
   generic (
      -- AXI Stream Configuration
      TUSER_WIDTH_G        : positive range 1 to 8   := 1;
      TID_WIDTH_G          : positive range 1 to 8   := 1;
      TDEST_WIDTH_G        : positive range 1 to 8   := 1;
      TDATA_NUM_BYTES_G    : positive range 1 to 128 := 1;
      MUX_STREAMS_G        : positive                := 2;
      PIPE_STAGES_G        : natural                 := 0;
      ILEAVE_EN_G          : boolean                 := false;
      ILEAVE_ON_NOTVALID_G : boolean                 := false;
      ILEAVE_REARB_G       : natural                 := 0;
      REARB_DELAY_G        : boolean                 := true;
      FORCED_REARB_HOLD_G  : boolean                 := false);
   port (
      -- Clock and Reset
      AXIS_ACLK     : in  std_logic                                          := '0';
      AXIS_ARESETN  : in  std_logic                                          := '0';
      -- IP Integrator Slave AXI Stream Interface
      S_AXIS_TVALID : in  std_logic                                          := '0';
      S_AXIS_TDATA  : in  std_logic_vector((8*TDATA_NUM_BYTES_G)-1 downto 0) := (others => '0');
      S_AXIS_TSTRB  : in  std_logic_vector(TDATA_NUM_BYTES_G-1 downto 0)     := (others => '0');
      S_AXIS_TKEEP  : in  std_logic_vector(TDATA_NUM_BYTES_G-1 downto 0)     := (others => '0');
      S_AXIS_TLAST  : in  std_logic                                          := '0';
      S_AXIS_TDEST  : in  std_logic_vector(TDEST_WIDTH_G-1 downto 0)         := (others => '0');
      S_AXIS_TID    : in  std_logic_vector(TID_WIDTH_G-1 downto 0)           := (others => '0');
      S_AXIS_TUSER  : in  std_logic_vector(TUSER_WIDTH_G-1 downto 0)         := (others => '0');
      S_AXIS_TREADY : out std_logic;
      -- IP Integrator Master AXI Stream Interface
      M_AXIS_TVALID : out std_logic;
      M_AXIS_TDATA  : out std_logic_vector((8*TDATA_NUM_BYTES_G)-1 downto 0);
      M_AXIS_TSTRB  : out std_logic_vector(TDATA_NUM_BYTES_G-1 downto 0);
      M_AXIS_TKEEP  : out std_logic_vector(TDATA_NUM_BYTES_G-1 downto 0);
      M_AXIS_TLAST  : out std_logic;
      M_AXIS_TDEST  : out std_logic_vector(TDEST_WIDTH_G-1 downto 0);
      M_AXIS_TID    : out std_logic_vector(TID_WIDTH_G-1 downto 0);
      M_AXIS_TUSER  : out std_logic_vector(TUSER_WIDTH_G-1 downto 0);
      M_AXIS_TREADY : in  std_logic);
end AxiStreamDemuxMuxTb;

architecture mapping of AxiStreamDemuxMuxTb is

   signal axisClk : sl := '0';
   signal axisRst : sl := '0';

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal axisMasters : AxiStreamMasterArray(MUX_STREAMS_G-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal axisSlaves  : AxiStreamSlaveArray(MUX_STREAMS_G-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   U_ShimLayerSlave : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 1,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => TUSER_WIDTH_G,
         TID_WIDTH       => TID_WIDTH_G,
         TDEST_WIDTH     => TDEST_WIDTH_G,
         TDATA_NUM_BYTES => TDATA_NUM_BYTES_G)
      port map (
         -- IP Integrator AXI Stream Interface
         S_AXIS_ACLK    => AXIS_ACLK,
         S_AXIS_ARESETN => AXIS_ARESETN,
         S_AXIS_TVALID  => S_AXIS_TVALID,
         S_AXIS_TDATA   => S_AXIS_TDATA,
         S_AXIS_TSTRB   => S_AXIS_TSTRB,
         S_AXIS_TKEEP   => S_AXIS_TKEEP,
         S_AXIS_TLAST   => S_AXIS_TLAST,
         S_AXIS_TDEST   => S_AXIS_TDEST,
         S_AXIS_TID     => S_AXIS_TID,
         S_AXIS_TUSER   => S_AXIS_TUSER,
         S_AXIS_TREADY  => S_AXIS_TREADY,
         -- SURF AXI Stream Interface
         axisClk        => axisClk,
         axisRst        => axisRst,
         axisMaster     => sAxisMaster,
         axisSlave      => sAxisSlave);

   U_DeMux : entity surf.AxiStreamDeMux
      generic map (
         NUM_MASTERS_G => MUX_STREAMS_G,
         PIPE_STAGES_G => PIPE_STAGES_G)
      port map (
         -- Clock and reset
         axisClk      => axisClk,
         axisRst      => axisRst,
         -- Slave
         sAxisMaster  => sAxisMaster,
         sAxisSlave   => sAxisSlave,
         -- Masters
         mAxisMasters => axisMasters,
         mAxisSlaves  => axisSlaves);

   U_Mux : entity surf.AxiStreamMux
      generic map (
         NUM_SLAVES_G         => MUX_STREAMS_G,
         PIPE_STAGES_G        => PIPE_STAGES_G,
         ILEAVE_EN_G          => ILEAVE_EN_G,
         ILEAVE_ON_NOTVALID_G => ILEAVE_ON_NOTVALID_G,
         ILEAVE_REARB_G       => ILEAVE_REARB_G,
         REARB_DELAY_G        => REARB_DELAY_G,
         FORCED_REARB_HOLD_G  => FORCED_REARB_HOLD_G)
      port map (
         -- Clock and reset
         axisClk      => axisClk,
         axisRst      => axisRst,
         -- Slaves
         sAxisMasters => axisMasters,
         sAxisSlaves  => axisSlaves,
         -- Master
         mAxisMaster  => mAxisMaster,
         mAxisSlave   => mAxisSlave);

   U_ShimLayerMaster : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 1,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => TUSER_WIDTH_G,
         TID_WIDTH       => TID_WIDTH_G,
         TDEST_WIDTH     => TDEST_WIDTH_G,
         TDATA_NUM_BYTES => TDATA_NUM_BYTES_G)
      port map (
         -- IP Integrator AXI Stream Interface
         M_AXIS_ACLK    => AXIS_ACLK,
         M_AXIS_ARESETN => AXIS_ARESETN,
         M_AXIS_TVALID  => M_AXIS_TVALID,
         M_AXIS_TDATA   => M_AXIS_TDATA,
         M_AXIS_TSTRB   => M_AXIS_TSTRB,
         M_AXIS_TKEEP   => M_AXIS_TKEEP,
         M_AXIS_TLAST   => M_AXIS_TLAST,
         M_AXIS_TDEST   => M_AXIS_TDEST,
         M_AXIS_TID     => M_AXIS_TID,
         M_AXIS_TUSER   => M_AXIS_TUSER,
         M_AXIS_TREADY  => M_AXIS_TREADY,
         -- SURF AXI Stream Interface
         axisClk        => open,
         axisRst        => open,
         axisMaster     => mAxisMaster,
         axisSlave      => mAxisSlave);

end mapping;
