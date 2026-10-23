-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for SrpV3Axi integration testing
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
use surf.AxiPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity SrpV3AxiWrapper is
   port (
      AXIS_ACLK     : in  std_logic;
      AXIS_ARESETN  : in  std_logic;
      S_AXIS_TVALID : in  std_logic;
      S_AXIS_TDATA  : in  std_logic_vector(31 downto 0);
      S_AXIS_TKEEP  : in  std_logic_vector(3 downto 0);
      S_AXIS_TLAST  : in  std_logic;
      S_AXIS_TDEST  : in  std_logic_vector(3 downto 0);
      S_AXIS_TID    : in  std_logic_vector(0 downto 0);
      S_AXIS_TUSER  : in  std_logic_vector(1 downto 0);
      S_AXIS_TREADY : out std_logic;
      M_AXIS_TVALID : out std_logic;
      M_AXIS_TDATA  : out std_logic_vector(31 downto 0);
      M_AXIS_TKEEP  : out std_logic_vector(3 downto 0);
      M_AXIS_TLAST  : out std_logic;
      M_AXIS_TDEST  : out std_logic_vector(3 downto 0);
      M_AXIS_TID    : out std_logic_vector(0 downto 0);
      M_AXIS_TUSER  : out std_logic_vector(1 downto 0);
      M_AXIS_TREADY : in  std_logic);
end entity SrpV3AxiWrapper;

architecture rtl of SrpV3AxiWrapper is

   constant FSM_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);
   constant SRP_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(8);

   constant AXI_CONFIG_C : AxiConfigType := (
      ADDR_WIDTH_C => 12,
      DATA_BYTES_C => 8,
      ID_BITS_C    => 1,
      LEN_BITS_C   => 8);

   constant TPD_C : time := 10 ns / 4;

   signal axisRst : sl := '0';

   signal axiWriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal axiWriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;
   signal axiReadMaster  : AxiReadMasterType  := AXI_READ_MASTER_INIT_C;
   signal axiReadSlave   : AxiReadSlaveType   := AXI_READ_SLAVE_INIT_C;

   signal sAxisMaster32 : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave32  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal srpIbMaster   : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal srpIbSlave    : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal srpObMaster   : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal srpObSlave    : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal mAxisMaster32 : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave32  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   axisRst <= not AXIS_ARESETN;

   U_ShimLayerSlave : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 4,
         TDATA_NUM_BYTES => 4)
      port map (
         S_AXIS_ACLK    => AXIS_ACLK,
         S_AXIS_ARESETN => AXIS_ARESETN,
         S_AXIS_TVALID  => S_AXIS_TVALID,
         S_AXIS_TDATA   => S_AXIS_TDATA,
         S_AXIS_TKEEP   => S_AXIS_TKEEP,
         S_AXIS_TLAST   => S_AXIS_TLAST,
         S_AXIS_TDEST   => S_AXIS_TDEST,
         S_AXIS_TID     => S_AXIS_TID,
         S_AXIS_TUSER   => S_AXIS_TUSER,
         S_AXIS_TREADY  => S_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => sAxisMaster32,
         axisSlave      => sAxisSlave32);

   U_ShimLayerMaster : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 4,
         TDATA_NUM_BYTES => 4)
      port map (
         M_AXIS_ACLK    => AXIS_ACLK,
         M_AXIS_ARESETN => AXIS_ARESETN,
         M_AXIS_TVALID  => M_AXIS_TVALID,
         M_AXIS_TDATA   => M_AXIS_TDATA,
         M_AXIS_TKEEP   => M_AXIS_TKEEP,
         M_AXIS_TLAST   => M_AXIS_TLAST,
         M_AXIS_TDEST   => M_AXIS_TDEST,
         M_AXIS_TID     => M_AXIS_TID,
         M_AXIS_TUSER   => M_AXIS_TUSER,
         M_AXIS_TREADY  => M_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => mAxisMaster32,
         axisSlave      => mAxisSlave32);

   U_MEM : entity surf.AxiRam
      generic map (
         TPD_G        => TPD_C,
         AXI_CONFIG_G => AXI_CONFIG_C)
      port map (
         axiClk          => AXIS_ACLK,
         axiRst          => axisRst,
         sAxiWriteMaster => axiWriteMaster,
         sAxiWriteSlave  => axiWriteSlave,
         sAxiReadMaster  => axiReadMaster,
         sAxiReadSlave   => axiReadSlave);

   U_SRPv3 : entity surf.SrpV3Axi
      generic map (
         TPD_G               => TPD_C,
         AXI_CONFIG_G        => AXI_CONFIG_C,
         AXI_STREAM_CONFIG_G => SRP_AXIS_CONFIG_C)
      port map (
         sAxisClk       => AXIS_ACLK,
         sAxisRst       => axisRst,
         sAxisMaster    => srpIbMaster,
         sAxisSlave     => srpIbSlave,
         mAxisClk       => AXIS_ACLK,
         mAxisRst       => axisRst,
         mAxisMaster    => srpObMaster,
         mAxisSlave     => srpObSlave,
         axiClk         => AXIS_ACLK,
         axiRst         => axisRst,
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave);

   U_TxResize : entity surf.AxiStreamResize
      generic map (
         TPD_G               => TPD_C,
         SLAVE_AXI_CONFIG_G  => FSM_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => SRP_AXIS_CONFIG_C)
      port map (
         axisClk     => AXIS_ACLK,
         axisRst     => axisRst,
         sAxisMaster => sAxisMaster32,
         sAxisSlave  => sAxisSlave32,
         mAxisMaster => srpIbMaster,
         mAxisSlave  => srpIbSlave);

   U_RxResize : entity surf.AxiStreamResize
      generic map (
         TPD_G               => TPD_C,
         SLAVE_AXI_CONFIG_G  => SRP_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => FSM_AXIS_CONFIG_C)
      port map (
         axisClk     => AXIS_ACLK,
         axisRst     => axisRst,
         sAxisMaster => srpObMaster,
         sAxisSlave  => srpObSlave,
         mAxisMaster => mAxisMaster32,
         mAxisSlave  => mAxisSlave32);

end architecture rtl;
