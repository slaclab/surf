-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.PgpRxVcFifo
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
use surf.Pgp4Pkg.all;

entity PgpRxVcFifoWrapper is
   port (
      pgpClk         : in  sl;
      pgpRst         : in  sl;
      axisClk        : in  sl;
      axisRst        : in  sl;
      rxlinkReady    : in  sl;
      pgpRxPause     : out sl;
      pgpRxOverflow  : out sl;
      pgpRxReady     : out sl;
      S_AXIS_TVALID  : in  sl;
      S_AXIS_TDATA   : in  slv(63 downto 0);
      S_AXIS_TKEEP   : in  slv(7 downto 0);
      S_AXIS_TLAST   : in  sl;
      S_AXIS_TDEST   : in  slv(0 downto 0);
      S_AXIS_TID     : in  slv(0 downto 0);
      S_AXIS_TUSER   : in  slv(0 downto 0);
      S_AXIS_TREADY  : out sl;
      M_AXIS_TVALID  : out sl;
      M_AXIS_TDATA   : out slv(63 downto 0);
      M_AXIS_TKEEP   : out slv(7 downto 0);
      M_AXIS_TLAST   : out sl;
      M_AXIS_TDEST   : out slv(0 downto 0);
      M_AXIS_TID     : out slv(0 downto 0);
      M_AXIS_TUSER   : out slv(0 downto 0);
      M_AXIS_TREADY  : in  sl);
end entity PgpRxVcFifoWrapper;

architecture rtl of PgpRxVcFifoWrapper is

   constant TUSER_WIDTH_C     : positive := 1;
   constant TID_WIDTH_C       : positive := 1;
   constant TDEST_WIDTH_C     : positive := 1;
   constant TDATA_NUM_BYTES_C : positive := 8;

   signal pgpAResetN  : sl := '1';
   signal axisAResetN : sl := '1';

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal pgpRxCtrlInt  : AxiStreamCtrlType := AXI_STREAM_CTRL_UNUSED_C;
   signal pgpRxSlaveInt : AxiStreamSlaveType := AXI_STREAM_SLAVE_FORCE_C;

begin

   pgpAResetN  <= not pgpRst;
   axisAResetN <= not axisRst;

   pgpRxPause    <= pgpRxCtrlInt.pause;
   pgpRxOverflow <= pgpRxCtrlInt.overflow;
   pgpRxReady    <= pgpRxSlaveInt.tReady;

   -- Flatten the PGP-side stream so the cocotb bench can drive it directly.
   U_ShimLayerSlave : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => TUSER_WIDTH_C,
         TID_WIDTH       => TID_WIDTH_C,
         TDEST_WIDTH     => TDEST_WIDTH_C,
         TDATA_NUM_BYTES => TDATA_NUM_BYTES_C)
      port map (
         S_AXIS_ACLK    => pgpClk,
         S_AXIS_ARESETN => pgpAResetN,
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

   U_DUT : entity surf.PgpRxVcFifo
      generic map (
         ROGUE_SIM_EN_G      => true,
         INT_PIPE_STAGES_G   => 0,
         PIPE_STAGES_G       => 0,
         VALID_THOLD_G       => 1,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 4,
         FIFO_PAUSE_THRESH_G => 2,
         CASCADE_SIZE_G      => 1,
         PHY_AXI_CONFIG_G    => PGP4_AXIS_CONFIG_C,
         APP_AXI_CONFIG_G    => PGP4_AXIS_CONFIG_C)
      port map (
         pgpClk      => pgpClk,
         pgpRst      => pgpRst,
         rxlinkReady => rxlinkReady,
         pgpRxMaster => sAxisMaster,
         pgpRxCtrl   => pgpRxCtrlInt,
         pgpRxSlave  => pgpRxSlaveInt,
         axisClk     => axisClk,
         axisRst     => axisRst,
         axisMaster  => mAxisMaster,
         axisSlave   => mAxisSlave);

   -- Flatten the application-side output stream for cocotb consumption.
   U_ShimLayerMaster : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => TUSER_WIDTH_C,
         TID_WIDTH       => TID_WIDTH_C,
         TDEST_WIDTH     => TDEST_WIDTH_C,
         TDATA_NUM_BYTES => TDATA_NUM_BYTES_C)
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

end architecture rtl;
