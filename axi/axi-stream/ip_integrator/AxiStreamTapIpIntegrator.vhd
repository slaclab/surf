-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP integrator wrapper for surf.AxiStreamTap
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

entity AxiStreamTapIpIntegrator is
   generic (
      TPD_G                : time                   := 1 ns;
      RST_POLARITY_G       : sl                     := '1';
      RST_ASYNC_G          : boolean                := false;
      TAP_DEST_G           : natural range 0 to 255 := 5;
      PIPE_STAGES_G        : natural range 0 to 16  := 0;
      ILEAVE_ON_NOTVALID_G : boolean                := false;
      ILEAVE_REARB_G       : natural                := 0;
      DATA_BYTES_G         : positive               := 4);
   port (
      axisClk        : in  sl;
      axisRst        : in  sl;
      S_AXIS_TVALID  : in  sl                             := '0';
      S_AXIS_TDATA   : in  slv(DATA_BYTES_G*8-1 downto 0) := (others => '0');
      S_AXIS_TKEEP   : in  slv(DATA_BYTES_G-1 downto 0)   := (others => '0');
      S_AXIS_TLAST   : in  sl                             := '0';
      S_AXIS_TDEST   : in  slv(7 downto 0)                := (others => '0');
      S_AXIS_TID     : in  slv(7 downto 0)                := (others => '0');
      S_AXIS_TUSER   : in  slv(1 downto 0)                := (others => '0');
      S_AXIS_TREADY  : out sl;
      TS_AXIS_TVALID : in  sl                             := '0';
      TS_AXIS_TDATA  : in  slv(DATA_BYTES_G*8-1 downto 0) := (others => '0');
      TS_AXIS_TKEEP  : in  slv(DATA_BYTES_G-1 downto 0)   := (others => '0');
      TS_AXIS_TLAST  : in  sl                             := '0';
      TS_AXIS_TDEST  : in  slv(7 downto 0)                := (others => '0');
      TS_AXIS_TID    : in  slv(7 downto 0)                := (others => '0');
      TS_AXIS_TUSER  : in  slv(1 downto 0)                := (others => '0');
      TS_AXIS_TREADY : out sl;
      TM_AXIS_TVALID : out sl;
      TM_AXIS_TDATA  : out slv(DATA_BYTES_G*8-1 downto 0);
      TM_AXIS_TKEEP  : out slv(DATA_BYTES_G-1 downto 0);
      TM_AXIS_TLAST  : out sl;
      TM_AXIS_TDEST  : out slv(7 downto 0);
      TM_AXIS_TID    : out slv(7 downto 0);
      TM_AXIS_TUSER  : out slv(1 downto 0);
      TM_AXIS_TREADY : in  sl                             := '0';
      M_AXIS_TVALID  : out sl;
      M_AXIS_TDATA   : out slv(DATA_BYTES_G*8-1 downto 0);
      M_AXIS_TKEEP   : out slv(DATA_BYTES_G-1 downto 0);
      M_AXIS_TLAST   : out sl;
      M_AXIS_TDEST   : out slv(7 downto 0);
      M_AXIS_TID     : out slv(7 downto 0);
      M_AXIS_TUSER   : out slv(1 downto 0);
      M_AXIS_TREADY  : in  sl                             := '0');
end entity AxiStreamTapIpIntegrator;

architecture rtl of AxiStreamTapIpIntegrator is

   signal axisAResetN  : sl                  := '1';
   signal sAxisMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal tsAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal tsAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal tmAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal tmAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   axisAResetN <= not axisRst when (RST_POLARITY_G = '1') else axisRst;

   U_ShimLayerSlave : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
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

   U_TapInsertSlave : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "TS_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 8,
         TDEST_WIDTH     => 8,
         TDATA_NUM_BYTES => DATA_BYTES_G)
      port map (
         S_AXIS_ACLK    => axisClk,
         S_AXIS_ARESETN => axisAResetN,
         S_AXIS_TVALID  => TS_AXIS_TVALID,
         S_AXIS_TDATA   => TS_AXIS_TDATA,
         S_AXIS_TSTRB   => (others => '0'),
         S_AXIS_TKEEP   => TS_AXIS_TKEEP,
         S_AXIS_TLAST   => TS_AXIS_TLAST,
         S_AXIS_TDEST   => TS_AXIS_TDEST,
         S_AXIS_TID     => TS_AXIS_TID,
         S_AXIS_TUSER   => TS_AXIS_TUSER,
         S_AXIS_TREADY  => TS_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => tsAxisMaster,
         axisSlave      => tsAxisSlave);

   U_TapMaster : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "TM_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 8,
         TDEST_WIDTH     => 8,
         TDATA_NUM_BYTES => DATA_BYTES_G)
      port map (
         M_AXIS_ACLK    => axisClk,
         M_AXIS_ARESETN => axisAResetN,
         M_AXIS_TVALID  => TM_AXIS_TVALID,
         M_AXIS_TDATA   => TM_AXIS_TDATA,
         M_AXIS_TSTRB   => open,
         M_AXIS_TKEEP   => TM_AXIS_TKEEP,
         M_AXIS_TLAST   => TM_AXIS_TLAST,
         M_AXIS_TDEST   => TM_AXIS_TDEST,
         M_AXIS_TID     => TM_AXIS_TID,
         M_AXIS_TUSER   => TM_AXIS_TUSER,
         M_AXIS_TREADY  => TM_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => tmAxisMaster,
         axisSlave      => tmAxisSlave);

   U_MainMaster : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 8,
         TDEST_WIDTH     => 8,
         TDATA_NUM_BYTES => DATA_BYTES_G)
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
         M_AXIS_TUSER   => M_AXIS_TUSER,
         M_AXIS_TREADY  => M_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => mAxisMaster,
         axisSlave      => mAxisSlave);

   U_DUT : entity surf.AxiStreamTap
      generic map (
         TPD_G                => TPD_G,
         RST_POLARITY_G       => RST_POLARITY_G,
         RST_ASYNC_G          => RST_ASYNC_G,
         TAP_DEST_G           => TAP_DEST_G,
         PIPE_STAGES_G        => PIPE_STAGES_G,
         ILEAVE_ON_NOTVALID_G => ILEAVE_ON_NOTVALID_G,
         ILEAVE_REARB_G       => ILEAVE_REARB_G)
      port map (
         sAxisMaster  => sAxisMaster,
         sAxisSlave   => sAxisSlave,
         mAxisMaster  => mAxisMaster,
         mAxisSlave   => mAxisSlave,
         tmAxisMaster => tmAxisMaster,
         tmAxisSlave  => tmAxisSlave,
         tsAxisMaster => tsAxisMaster,
         tsAxisSlave  => tsAxisSlave,
         axisClk      => axisClk,
         axisRst      => axisRst);

end architecture rtl;
