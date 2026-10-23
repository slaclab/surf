-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP integrator wrapper for surf.RoceResizeAndSwap
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

entity RoceResizeAndSwapIpIntegrator is
   generic (
      TPD_G               : time     := 1 ns;
      RST_POLARITY_G      : sl       := '1';
      RST_ASYNC_G         : boolean  := false;
      READY_EN_G          : boolean  := true;
      PIPE_STAGES_G       : natural  := 0;
      SIDE_BAND_WIDTH_G   : positive := 1;
      SWAP_ENDIAN_G       : boolean  := false;
      LITTLE_ENDIAN_G     : boolean  := true;
      SLAVE_DATA_BYTES_G  : positive := 16;
      MASTER_DATA_BYTES_G : positive := 32);
   port (
      axisClk       : in  sl;
      axisRst       : in  sl;
      S_AXIS_TVALID : in  sl;
      S_AXIS_TDATA  : in  slv(SLAVE_DATA_BYTES_G*8-1 downto 0);
      S_AXIS_TKEEP  : in  slv(SLAVE_DATA_BYTES_G-1 downto 0);
      S_AXIS_TLAST  : in  sl;
      S_AXIS_TDEST  : in  slv(7 downto 0);
      S_AXIS_TID    : in  slv(7 downto 0);
      S_AXIS_TREADY : out sl;
      S_SIDE_BAND   : in  slv(SIDE_BAND_WIDTH_G-1 downto 0);
      M_AXIS_TVALID : out sl;
      M_AXIS_TDATA  : out slv(MASTER_DATA_BYTES_G*8-1 downto 0);
      M_AXIS_TKEEP  : out slv(MASTER_DATA_BYTES_G-1 downto 0);
      M_AXIS_TLAST  : out sl;
      M_AXIS_TDEST  : out slv(7 downto 0);
      M_AXIS_TID    : out slv(7 downto 0);
      M_AXIS_TREADY : in  sl;
      M_SIDE_BAND   : out slv(SIDE_BAND_WIDTH_G-1 downto 0));
end entity RoceResizeAndSwapIpIntegrator;

architecture rtl of RoceResizeAndSwapIpIntegrator is

   constant SLAVE_AXI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => SLAVE_DATA_BYTES_G,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 1,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   constant MASTER_AXI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => MASTER_DATA_BYTES_G,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 1,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   signal axisAResetN : sl                  := '1';
   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   axisAResetN <= not axisRst when (RST_POLARITY_G = '1') else axisRst;

   ----------------------------------------------------------------------------
   -- AXI Stream shims
   ----------------------------------------------------------------------------
   U_ShimLayerSlave : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 1,
         TID_WIDTH       => 8,
         TDEST_WIDTH     => 8,
         TDATA_NUM_BYTES => SLAVE_DATA_BYTES_G)
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
         S_AXIS_TUSER   => "0",
         S_AXIS_TREADY  => S_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => sAxisMaster,
         axisSlave      => sAxisSlave);

   U_ShimLayerMaster : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 1,
         TID_WIDTH       => 8,
         TDEST_WIDTH     => 8,
         TDATA_NUM_BYTES => MASTER_DATA_BYTES_G)
      port map (
         M_AXIS_ACLK    => axisClk,
         M_AXIS_ARESETN => axisAResetN,
         M_AXIS_TVALID  => M_AXIS_TVALID,
         M_AXIS_TDATA   => M_AXIS_TDATA,
         M_AXIS_TSTRB   => open,
         M_AXIS_TKEEP   => M_AXIS_TKEEP,
         M_AXIS_TLAST   => M_AXIS_TLAST,
         M_AXIS_TDEST   => M_AXIS_TDEST,
         M_AXIS_TID     => M_AXIS_TID,
         M_AXIS_TUSER   => open,
         M_AXIS_TREADY  => M_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => mAxisMaster,
         axisSlave      => mAxisSlave);

   ----------------------------------------------------------------------------
   -- DUT hookup
   ----------------------------------------------------------------------------
   U_DUT : entity surf.RoceResizeAndSwap
      generic map (
         TPD_G               => TPD_G,
         RST_POLARITY_G      => RST_POLARITY_G,
         RST_ASYNC_G         => RST_ASYNC_G,
         READY_EN_G          => READY_EN_G,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         SIDE_BAND_WIDTH_G   => SIDE_BAND_WIDTH_G,
         SWAP_ENDIAN_G       => SWAP_ENDIAN_G,
         LITTLE_ENDIAN_G     => LITTLE_ENDIAN_G,
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_C,
         MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_C)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => sAxisMaster,
         sSideBand   => S_SIDE_BAND,
         sAxisSlave  => sAxisSlave,
         mAxisMaster => mAxisMaster,
         mSideBand   => M_SIDE_BAND,
         mAxisSlave  => mAxisSlave);

end architecture rtl;
