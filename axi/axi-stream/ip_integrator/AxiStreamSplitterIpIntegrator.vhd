-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP integrator wrapper for surf.AxiStreamSplitter
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

entity AxiStreamSplitterIpIntegrator is
   generic (
      TPD_G          : time                  := 1 ns;
      RST_POLARITY_G : sl                    := '1';
      RST_ASYNC_G    : boolean               := false;
      DATA_BYTES_G   : positive              := 2;
      TUSER_WIDTH_G  : positive range 1 to 8 := 2);
   port (
      axisClk        : in  sl;
      axisRst        : in  sl;
      S_AXIS_TVALID  : in  sl                                 := '0';
      S_AXIS_TDATA   : in  slv((DATA_BYTES_G*2*8)-1 downto 0) := (others => '0');
      S_AXIS_TKEEP   : in  slv((DATA_BYTES_G*2)-1 downto 0)   := (others => '0');
      S_AXIS_TLAST   : in  sl                                 := '0';
      S_AXIS_TDEST   : in  slv(7 downto 0)                    := (others => '0');
      S_AXIS_TID     : in  slv(7 downto 0)                    := (others => '0');
      S_AXIS_TUSER   : in  slv(TUSER_WIDTH_G-1 downto 0)      := (others => '0');
      S_AXIS_TREADY  : out sl;
      M0_AXIS_TVALID : out sl;
      M0_AXIS_TDATA  : out slv(DATA_BYTES_G*8-1 downto 0);
      M0_AXIS_TKEEP  : out slv(DATA_BYTES_G-1 downto 0);
      M0_AXIS_TLAST  : out sl;
      M0_AXIS_TDEST  : out slv(7 downto 0);
      M0_AXIS_TID    : out slv(7 downto 0);
      M0_AXIS_TUSER  : out slv(TUSER_WIDTH_G-1 downto 0);
      M0_AXIS_TREADY : in  sl                                 := '0';
      M1_AXIS_TVALID : out sl;
      M1_AXIS_TDATA  : out slv(DATA_BYTES_G*8-1 downto 0);
      M1_AXIS_TKEEP  : out slv(DATA_BYTES_G-1 downto 0);
      M1_AXIS_TLAST  : out sl;
      M1_AXIS_TDEST  : out slv(7 downto 0);
      M1_AXIS_TID    : out slv(7 downto 0);
      M1_AXIS_TUSER  : out slv(TUSER_WIDTH_G-1 downto 0);
      M1_AXIS_TREADY : in  sl                                 := '0');
end entity AxiStreamSplitterIpIntegrator;

architecture rtl of AxiStreamSplitterIpIntegrator is

   constant SLAVE_AXI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => DATA_BYTES_G*2,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => TUSER_WIDTH_G,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   constant MASTER_AXI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => DATA_BYTES_G,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => TUSER_WIDTH_G,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   signal axisAResetN : sl := '1';
   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal mAxisSlaves  : AxiStreamSlaveArray(1 downto 0) := (others => AXI_STREAM_SLAVE_INIT_C);

begin

   axisAResetN <= not axisRst when (RST_POLARITY_G = '1') else axisRst;

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
         TDATA_NUM_BYTES => DATA_BYTES_G*2)
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

   U_DUT : entity surf.AxiStreamSplitter
      generic map (
         TPD_G               => TPD_G,
         RST_POLARITY_G      => RST_POLARITY_G,
         RST_ASYNC_G         => RST_ASYNC_G,
         LANES_G             => 2,
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_C,
         MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_C)
      port map (
         axisClk      => axisClk,
         axisRst      => axisRst,
         sAxisMaster  => sAxisMaster,
         sAxisSlave   => sAxisSlave,
         mAxisMasters => mAxisMasters,
         mAxisSlaves  => mAxisSlaves);

end architecture rtl;
