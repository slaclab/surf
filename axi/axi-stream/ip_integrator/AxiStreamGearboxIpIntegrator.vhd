-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP integrator wrapper for surf.AxiStreamGearbox
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

entity AxiStreamGearboxIpIntegrator is
   generic (
      BYTE_PACKER_MODE  : natural range 0 to 1   := 0;
      S_INTERFACENAME   : string                 := "S_AXIS";
      S_HAS_TLAST       : natural range 0 to 1   := 1;
      S_HAS_TKEEP       : natural range 0 to 1   := 1;
      S_HAS_TSTRB       : natural range 0 to 1   := 0;
      S_HAS_TREADY      : natural range 0 to 1   := 1;
      S_TUSER_WIDTH     : natural range 1 to 8   := 2;
      S_TID_WIDTH       : natural range 1 to 8   := 1;
      S_TDEST_WIDTH     : natural range 1 to 8   := 1;
      S_TDATA_NUM_BYTES : natural range 1 to 128 := 1;
      M_INTERFACENAME   : string                 := "M_AXIS";
      M_HAS_TLAST       : natural range 0 to 1   := 1;
      M_HAS_TKEEP       : natural range 0 to 1   := 1;
      M_HAS_TSTRB       : natural range 0 to 1   := 0;
      M_HAS_TREADY      : natural range 0 to 1   := 1;
      M_TUSER_WIDTH     : natural range 1 to 8   := 2;
      M_TID_WIDTH       : natural range 1 to 8   := 1;
      M_TDEST_WIDTH     : natural range 1 to 8   := 1;
      M_TDATA_NUM_BYTES : natural range 1 to 128 := 1);
   port (
      AXIS_ACLK     : in  std_logic                                          := '0';
      AXIS_ARESETN  : in  std_logic                                          := '0';
      S_AXIS_TVALID : in  std_logic                                          := '0';
      S_AXIS_TDATA  : in  std_logic_vector((8*S_TDATA_NUM_BYTES)-1 downto 0) := (others => '0');
      S_AXIS_TSTRB  : in  std_logic_vector(S_TDATA_NUM_BYTES-1 downto 0)     := (others => '0');
      S_AXIS_TKEEP  : in  std_logic_vector(S_TDATA_NUM_BYTES-1 downto 0)     := (others => '0');
      S_AXIS_TLAST  : in  std_logic                                          := '0';
      S_AXIS_TDEST  : in  std_logic_vector(S_TDEST_WIDTH-1 downto 0)         := (others => '0');
      S_AXIS_TID    : in  std_logic_vector(S_TID_WIDTH-1 downto 0)           := (others => '0');
      S_AXIS_TUSER  : in  std_logic_vector(S_TUSER_WIDTH-1 downto 0)         := (others => '0');
      S_AXIS_TREADY : out std_logic;
      M_AXIS_TVALID : out std_logic;
      M_AXIS_TDATA  : out std_logic_vector((8*M_TDATA_NUM_BYTES)-1 downto 0);
      M_AXIS_TSTRB  : out std_logic_vector(M_TDATA_NUM_BYTES-1 downto 0);
      M_AXIS_TKEEP  : out std_logic_vector(M_TDATA_NUM_BYTES-1 downto 0);
      M_AXIS_TLAST  : out std_logic;
      M_AXIS_TDEST  : out std_logic_vector(M_TDEST_WIDTH-1 downto 0);
      M_AXIS_TID    : out std_logic_vector(M_TID_WIDTH-1 downto 0);
      M_AXIS_TUSER  : out std_logic_vector(M_TUSER_WIDTH-1 downto 0);
      M_AXIS_TREADY : in  std_logic                                          := '1');
end entity AxiStreamGearboxIpIntegrator;

architecture mapping of AxiStreamGearboxIpIntegrator is

   constant MAX_NUM_BYTES_C : positive := ite(M_TDATA_NUM_BYTES > S_TDATA_NUM_BYTES, M_TDATA_NUM_BYTES, S_TDATA_NUM_BYTES);

   constant S_AXI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => ite(S_HAS_TSTRB = 1, true, false),
      TDATA_BYTES_C => ite(BYTE_PACKER_MODE = 1, MAX_NUM_BYTES_C, S_TDATA_NUM_BYTES),
      TDEST_BITS_C  => S_TDEST_WIDTH,
      TID_BITS_C    => S_TID_WIDTH,
      TKEEP_MODE_C  => ite(S_HAS_TKEEP = 1, TKEEP_NORMAL_C, TKEEP_FIXED_C),
      TUSER_BITS_C  => S_TUSER_WIDTH,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   constant M_AXI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => ite(M_HAS_TSTRB = 1, true, false),
      TDATA_BYTES_C => M_TDATA_NUM_BYTES,
      TDEST_BITS_C  => M_TDEST_WIDTH,
      TID_BITS_C    => M_TID_WIDTH,
      TKEEP_MODE_C  => ite(M_HAS_TKEEP = 1, TKEEP_NORMAL_C, TKEEP_FIXED_C),
      TUSER_BITS_C  => M_TUSER_WIDTH,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   signal sAxisMaster : AxiStreamMasterType := axiStreamMasterInit(S_AXI_CONFIG_C);
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal mAxisMaster : AxiStreamMasterType := axiStreamMasterInit(M_AXI_CONFIG_C);
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal axisClk     : sl                  := '0';
   signal axisRst     : sl                  := '0';

begin

   U_ShimLayerSlave : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => S_INTERFACENAME,
         HAS_TLAST       => S_HAS_TLAST,
         HAS_TKEEP       => S_HAS_TKEEP,
         HAS_TSTRB       => S_HAS_TSTRB,
         HAS_TREADY      => S_HAS_TREADY,
         TUSER_WIDTH     => S_TUSER_WIDTH,
         TID_WIDTH       => S_TID_WIDTH,
         TDEST_WIDTH     => S_TDEST_WIDTH,
         TDATA_NUM_BYTES => S_TDATA_NUM_BYTES)
      port map (
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
         axisClk        => axisClk,
         axisRst        => axisRst,
         axisMaster     => sAxisMaster,
         axisSlave      => sAxisSlave);

   U_DUT : entity surf.AxiStreamGearbox
      generic map (
         FORCE_GEARBOX_IMPL_G => true,
         SLAVE_AXI_CONFIG_G   => S_AXI_CONFIG_C,
         MASTER_AXI_CONFIG_G  => M_AXI_CONFIG_C)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

   U_ShimLayerMaster : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => M_INTERFACENAME,
         HAS_TLAST       => M_HAS_TLAST,
         HAS_TKEEP       => M_HAS_TKEEP,
         HAS_TSTRB       => M_HAS_TSTRB,
         HAS_TREADY      => M_HAS_TREADY,
         TUSER_WIDTH     => M_TUSER_WIDTH,
         TID_WIDTH       => M_TID_WIDTH,
         TDEST_WIDTH     => M_TDEST_WIDTH,
         TDATA_NUM_BYTES => M_TDATA_NUM_BYTES)
      port map (
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
         axisClk        => open,
         axisRst        => open,
         axisMaster     => mAxisMaster,
         axisSlave      => mAxisSlave);

end architecture mapping;
