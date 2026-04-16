-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.PgpTxVcFifo
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

entity PgpTxVcFifoWrapper is
   port (
      axisClk       : in  sl;
      axisRst       : in  sl;
      pgpClk        : in  sl;
      pgpRst        : in  sl;
      rxlinkReady   : in  sl;
      txlinkReady   : in  sl;
      S_AXIS_TVALID : in  sl;
      S_AXIS_TDATA  : in  slv(63 downto 0);
      S_AXIS_TKEEP  : in  slv(7 downto 0);
      S_AXIS_TLAST  : in  sl;
      S_AXIS_TDEST  : in  slv(0 downto 0);
      S_AXIS_TID    : in  slv(0 downto 0);
      S_AXIS_TUSER  : in  slv(0 downto 0);
      S_AXIS_TREADY : out sl;
      M_AXIS_TVALID : out sl;
      M_AXIS_TDATA  : out slv(63 downto 0);
      M_AXIS_TKEEP  : out slv(7 downto 0);
      M_AXIS_TLAST  : out sl;
      M_AXIS_TDEST  : out slv(0 downto 0);
      M_AXIS_TID    : out slv(0 downto 0);
      M_AXIS_TUSER  : out slv(0 downto 0);
      M_AXIS_TREADY : in  sl);
end entity PgpTxVcFifoWrapper;

architecture rtl of PgpTxVcFifoWrapper is

   constant TUSER_WIDTH_C     : positive := 1;
   constant TID_WIDTH_C       : positive := 1;
   constant TDEST_WIDTH_C     : positive := 1;
   constant TDATA_NUM_BYTES_C : positive := 8;

   signal axisAResetN : sl := '1';
   signal pgpAResetN  : sl := '1';

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   axisAResetN <= not axisRst;
   pgpAResetN  <= not pgpRst;

   -- Flatten the application-side AXIS source into the record interface that
   -- the shared VC FIFO expects.
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

   U_DUT : entity surf.PgpTxVcFifo
      generic map (
         INT_PIPE_STAGES_G => 0,
         PIPE_STAGES_G     => 0,
         VALID_THOLD_G     => 1,
         GEN_SYNC_FIFO_G   => false,
         FIFO_ADDR_WIDTH_G => 4,
         CASCADE_SIZE_G    => 1,
         APP_AXI_CONFIG_G  => PGP4_AXIS_CONFIG_C,
         PHY_AXI_CONFIG_G  => PGP4_AXIS_CONFIG_C)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         axisMaster  => sAxisMaster,
         axisSlave   => sAxisSlave,
         pgpClk      => pgpClk,
         pgpRst      => pgpRst,
         rxlinkReady => rxlinkReady,
         txlinkReady => txlinkReady,
         pgpTxMaster => mAxisMaster,
         pgpTxSlave  => mAxisSlave);

   -- Flatten the PGP-side output stream back into a cocotb-friendly AXIS bus.
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
         M_AXIS_ACLK    => pgpClk,
         M_AXIS_ARESETN => pgpAResetN,
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
