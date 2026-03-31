-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP integrator wrapper for surf.AxiStreamDeMux
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

entity AxiStreamDeMuxIpIntegrator is
   generic (
      TPD_G           : time                   := 1 ns;
      RST_POLARITY_G  : sl                     := '1';
      RST_ASYNC_G     : boolean                := false;
      DATA_BYTES_G    : positive               := 4;
      TUSER_WIDTH_G   : positive range 1 to 8  := 1;
      PIPE_STAGES_G   : natural                := 0;
      MODE_G          : string                 := "INDEXED";
      TDEST_ROUTE_0_G : natural range 0 to 255 := 0;
      TDEST_ROUTE_1_G : natural range 0 to 255 := 1;
      TDEST_HIGH_G    : integer range 0 to 7   := 7;
      TDEST_LOW_G     : integer range 0 to 7   := 0);
   port (
      axisClk           : in  sl;
      axisRst           : in  sl;
      dynamicRouteMask0 : in  slv(7 downto 0)                := (others => '0');
      dynamicRouteDest0 : in  slv(7 downto 0)                := (others => '0');
      dynamicRouteMask1 : in  slv(7 downto 0)                := (others => '0');
      dynamicRouteDest1 : in  slv(7 downto 0)                := (others => '0');
      S_AXIS_TVALID     : in  sl                             := '0';
      S_AXIS_TDATA      : in  slv(DATA_BYTES_G*8-1 downto 0) := (others => '0');
      S_AXIS_TKEEP      : in  slv(DATA_BYTES_G-1 downto 0)   := (others => '0');
      S_AXIS_TLAST      : in  sl                             := '0';
      S_AXIS_TDEST      : in  slv(7 downto 0)                := (others => '0');
      S_AXIS_TID        : in  slv(7 downto 0)                := (others => '0');
      S_AXIS_TUSER      : in  slv(TUSER_WIDTH_G-1 downto 0)  := (others => '0');
      S_AXIS_TREADY     : out sl;
      M0_AXIS_TVALID    : out sl;
      M0_AXIS_TDATA     : out slv(DATA_BYTES_G*8-1 downto 0);
      M0_AXIS_TKEEP     : out slv(DATA_BYTES_G-1 downto 0);
      M0_AXIS_TLAST     : out sl;
      M0_AXIS_TDEST     : out slv(7 downto 0);
      M0_AXIS_TID       : out slv(7 downto 0);
      M0_AXIS_TUSER     : out slv(TUSER_WIDTH_G-1 downto 0);
      M0_AXIS_TREADY    : in  sl                             := '0';
      M1_AXIS_TVALID    : out sl;
      M1_AXIS_TDATA     : out slv(DATA_BYTES_G*8-1 downto 0);
      M1_AXIS_TKEEP     : out slv(DATA_BYTES_G-1 downto 0);
      M1_AXIS_TLAST     : out sl;
      M1_AXIS_TDEST     : out slv(7 downto 0);
      M1_AXIS_TID       : out slv(7 downto 0);
      M1_AXIS_TUSER     : out slv(TUSER_WIDTH_G-1 downto 0);
      M1_AXIS_TREADY    : in  sl                             := '0');
end entity AxiStreamDeMuxIpIntegrator;

architecture rtl of AxiStreamDeMuxIpIntegrator is

   constant TDEST_ROUTES_C : Slv8Array(1 downto 0) := (
      0 => toSlv(TDEST_ROUTE_0_G, 8),
      1 => toSlv(TDEST_ROUTE_1_G, 8));

   signal axisAResetN      : sl := '1';
   signal dynamicRouteMasks : Slv8Array(1 downto 0) := (others => (others => '0'));
   signal dynamicRouteDests : Slv8Array(1 downto 0) := (others => (others => '0'));
   signal sAxisMaster      : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave       : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMasters     : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal mAxisSlaves      : AxiStreamSlaveArray(1 downto 0) := (others => AXI_STREAM_SLAVE_INIT_C);

begin

   axisAResetN <= not axisRst when (RST_POLARITY_G = '1') else axisRst;

   dynamicRouteMasks(0) <= dynamicRouteMask0;
   dynamicRouteDests(0) <= dynamicRouteDest0;
   dynamicRouteMasks(1) <= dynamicRouteMask1;
   dynamicRouteDests(1) <= dynamicRouteDest1;

   U_ShimLayerSlave : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => TUSER_WIDTH_G,
         TID_WIDTH       => 8,
         TDEST_WIDTH     => 8,
         TDATA_NUM_BYTES => DATA_BYTES_G)
      port map (
         S_AXIS_ACLK    => axisClk,
         S_AXIS_ARESETN => axisAResetN,
         S_AXIS_TVALID  => S_AXIS_TVALID,
         S_AXIS_TDATA   => S_AXIS_TDATA,
         S_AXIS_TSTRB   => (others => '0'),
         S_AXIS_TKEEP   => S_AXIS_TKEEP,
         S_AXIS_TLAST   => S_AXIS_TLAST,
         S_AXIS_TDEST   => S_AXIS_TDEST,
         S_AXIS_TID     => S_AXIS_TID,
         S_AXIS_TUSER   => S_AXIS_TUSER,
         S_AXIS_TREADY  => S_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => sAxisMaster,
         axisSlave      => sAxisSlave);

   U_ShimLayerMaster0 : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M0_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => TUSER_WIDTH_G,
         TID_WIDTH       => 8,
         TDEST_WIDTH     => 8,
         TDATA_NUM_BYTES => DATA_BYTES_G)
      port map (
         M_AXIS_ACLK    => axisClk,
         M_AXIS_ARESETN => axisAResetN,
         M_AXIS_TVALID  => M0_AXIS_TVALID,
         M_AXIS_TDATA   => M0_AXIS_TDATA,
         M_AXIS_TSTRB   => open,
         M_AXIS_TKEEP   => M0_AXIS_TKEEP,
         M_AXIS_TLAST   => M0_AXIS_TLAST,
         M_AXIS_TDEST   => M0_AXIS_TDEST,
         M_AXIS_TID     => M0_AXIS_TID,
         M_AXIS_TUSER   => M0_AXIS_TUSER,
         M_AXIS_TREADY  => M0_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => mAxisMasters(0),
         axisSlave      => mAxisSlaves(0));

   U_ShimLayerMaster1 : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M1_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => TUSER_WIDTH_G,
         TID_WIDTH       => 8,
         TDEST_WIDTH     => 8,
         TDATA_NUM_BYTES => DATA_BYTES_G)
      port map (
         M_AXIS_ACLK    => axisClk,
         M_AXIS_ARESETN => axisAResetN,
         M_AXIS_TVALID  => M1_AXIS_TVALID,
         M_AXIS_TDATA   => M1_AXIS_TDATA,
         M_AXIS_TSTRB   => open,
         M_AXIS_TKEEP   => M1_AXIS_TKEEP,
         M_AXIS_TLAST   => M1_AXIS_TLAST,
         M_AXIS_TDEST   => M1_AXIS_TDEST,
         M_AXIS_TID     => M1_AXIS_TID,
         M_AXIS_TUSER   => M1_AXIS_TUSER,
         M_AXIS_TREADY  => M1_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => mAxisMasters(1),
         axisSlave      => mAxisSlaves(1));

   U_DUT : entity surf.AxiStreamDeMux
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         NUM_MASTERS_G  => 2,
         MODE_G         => MODE_G,
         TDEST_ROUTES_G => TDEST_ROUTES_C,
         PIPE_STAGES_G  => PIPE_STAGES_G,
         TDEST_HIGH_G   => TDEST_HIGH_G,
         TDEST_LOW_G    => TDEST_LOW_G)
      port map (
         axisClk           => axisClk,
         axisRst           => axisRst,
         dynamicRouteMasks => dynamicRouteMasks,
         dynamicRouteDests => dynamicRouteDests,
         sAxisMaster       => sAxisMaster,
         sAxisSlave        => sAxisSlave,
         mAxisMasters      => mAxisMasters,
         mAxisSlaves       => mAxisSlaves);

end architecture rtl;
