-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper on the native VHDL iCRC engine, Recv direction.
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

entity EthMacCrcAxiStreamWrapperRecv is
   generic (
      TPD_G          : time := 1 ns;   -- simulation propagation delay
      RST_POLARITY_G : sl   := '1');    -- '1' = active-HIGH reset, '0' = active-LOW
   port (
      -- Clock and Reset
      ethClk      : in  sl;
      ethRst      : in  sl;
      -- Slave ports
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      -- Master ports
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end EthMacCrcAxiStreamWrapperRecv;

architecture rtl of EthMacCrcAxiStreamWrapperRecv is

   -- BlueRdma
   signal blueRstN         : sl;
   signal bluetValidSlave  : sl;
   signal bluetDataSlave   : slv(255 downto 0);
   signal bluetKeepSlave   : slv(31 downto 0);
   signal bluetUserSlave   : sl;
   signal bluetLastSlave   : sl;
   signal bluetReadySlave  : sl;
   signal bluetDataMaster  : slv(31 downto 0);
   signal bluetValidMaster : sl;
   signal bluetReadyMaster : sl;

begin

   blueRstN <= not ethRst when (RST_POLARITY_G = '1') else ethRst;

   -----------------------------------------------------------------------------
   -- IP integrator
   -----------------------------------------------------------------------------
   MasterAxiStreamIpIntegrator_1 : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         TUSER_WIDTH     => 1,
         TDATA_NUM_BYTES => 32)
      port map (
         M_AXIS_ACLK     => ethClk,
         M_AXIS_ARESETN  => blueRstN,
         M_AXIS_TVALID   => bluetValidSlave,
         M_AXIS_TDATA    => bluetDataSlave,
         M_AXIS_TKEEP    => bluetKeepSlave,
         M_AXIS_TLAST    => bluetLastSlave,
         M_AXIS_TUSER(0) => bluetUserSlave,
         M_AXIS_TREADY   => bluetReadySlave,
         axisClk         => open,
         axisRst         => open,
         axisMaster      => sAxisMaster,
         axisSlave       => sAxisSlave);

   SlaveAxiStreamIpIntegrator_1 : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         TDATA_NUM_BYTES => 4)
      port map (
         S_AXIS_ACLK    => ethClk,
         S_AXIS_ARESETN => blueRstN,
         S_AXIS_TVALID  => bluetValidMaster,
         S_AXIS_TDATA   => bluetDataMaster,
         S_AXIS_TKEEP   => x"F",
         S_AXIS_TLAST   => '1',
         S_AXIS_TREADY  => bluetReadyMaster,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => mAxisMaster,
         axisSlave      => mAxisSlave);

   -----------------------------------------------------------------------------
   -- CRC calculator
   -----------------------------------------------------------------------------
   -- SEND_MODE_G below selects the generate form of the CRC as opposed to
   -- the verify form; the same entity serves both directions of this pair
   -- of wrappers, distinguished only by this one boolean.
   EthMacCrcAxiStreamWrapperRecv_1 : entity surf.RoCEv2ICrc
      generic map (
         TPD_G       => TPD_G,
         SEND_MODE_G => false)
      port map (
         CLK                => ethClk,
         RST_N              => blueRstN,
         s_axis_tvalid      => bluetValidSlave,
         s_axis_tdata       => bluetDataSlave,
         s_axis_tkeep       => bluetKeepSlave,
         s_axis_tlast       => bluetLastSlave,
         s_axis_tuser       => bluetUserSlave,
         s_axis_tready      => bluetReadySlave,
         m_crc_stream_data  => bluetDataMaster,
         m_crc_stream_valid => bluetValidMaster,
         m_crc_stream_ready => bluetReadyMaster);

end rtl;
