-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.AxiStreamMon
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

entity AxiStreamMonIpIntegrator is
   generic (
      TPD_G : time := 1 ns);
   port (
      axiClk         : in  sl;
      axiRst         : in  sl;
      axisReady      : in  sl;
      S_AXIS_TVALID  : in  sl;
      S_AXIS_TDATA   : in  slv(31 downto 0);
      S_AXIS_TKEEP   : in  slv(3 downto 0);
      S_AXIS_TLAST   : in  sl;
      S_AXIS_TDEST   : in  slv(0 downto 0);
      S_AXIS_TID     : in  slv(0 downto 0);
      S_AXIS_TUSER   : in  slv(0 downto 0);
      S_AXIS_TREADY  : out sl;
      frameCnt       : out slv(63 downto 0);
      frameSize      : out slv(31 downto 0);
      frameSizeMax   : out slv(31 downto 0);
      frameSizeMin   : out slv(31 downto 0);
      frameRate      : out slv(31 downto 0);
      frameRateMax   : out slv(31 downto 0);
      frameRateMin   : out slv(31 downto 0);
      bandwidth      : out slv(63 downto 0);
      bandwidthMax   : out slv(63 downto 0);
      bandwidthMin   : out slv(63 downto 0));
end entity AxiStreamMonIpIntegrator;

architecture rtl of AxiStreamMonIpIntegrator is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 4,
      TDEST_BITS_C  => 1,
      TID_BITS_C    => 1,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 1,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   signal axiResetN  : sl := '1';
   signal axisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal axisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   ---------------------------------------------------------------------------
   -- AXI-Stream shim
   ---------------------------------------------------------------------------
   axiResetN <= not axiRst;
   axisSlave.tReady <= axisReady;

   U_S_AXIS : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 1,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         TDATA_NUM_BYTES => 4)
      port map (
         S_AXIS_ACLK    => axiClk,
         S_AXIS_ARESETN => axiResetN,
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
         axisMaster     => axisMaster,
         axisSlave      => open);

   ---------------------------------------------------------------------------
   -- DUT
   ---------------------------------------------------------------------------
   U_DUT : entity surf.AxiStreamMon
      generic map (
         TPD_G           => TPD_G,
         COMMON_CLK_G    => true,
         AXIS_CLK_FREQ_G => 1000.0,
         AXIS_CONFIG_G   => AXIS_CONFIG_C)
      port map (
         axisClk      => axiClk,
         axisRst      => axiRst,
         axisMaster   => axisMaster,
         axisSlave    => axisSlave,
         statusClk    => axiClk,
         statusRst    => axiRst,
         frameCnt     => frameCnt,
         frameSize    => frameSize,
         frameSizeMax => frameSizeMax,
         frameSizeMin => frameSizeMin,
         frameRate    => frameRate,
         frameRateMax => frameRateMax,
         frameRateMin => frameRateMin,
         bandwidth    => bandwidth,
         bandwidthMax => bandwidthMax,
         bandwidthMin => bandwidthMin);

end architecture rtl;
