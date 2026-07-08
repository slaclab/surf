-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for CoaXPressConfig
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
use surf.SsiPkg.all;

entity CoaXPressConfigWrapper is
   port (
      cfgClk          : in  sl;
      cfgRst          : in  sl;
      configTimerSize : in slv(31 downto 0);
      configErrResp   : in  sl;
      configPktTag    : in  sl;
      S_CFG_IB_TVALID : in sl;
      S_CFG_IB_TDATA  : in slv(255 downto 0);
      S_CFG_IB_TKEEP  : in slv(31 downto 0);
      S_CFG_IB_TLAST  : in sl;
      S_CFG_IB_TUSER  : in slv(1 downto 0);
      S_CFG_IB_TREADY : out sl;
      M_CFG_OB_TVALID : out sl;
      M_CFG_OB_TDATA  : out slv(255 downto 0);
      M_CFG_OB_TKEEP  : out slv(31 downto 0);
      M_CFG_OB_TLAST  : out sl;
      M_CFG_OB_TUSER  : out slv(1 downto 0);
      M_CFG_OB_TREADY : in  sl;
      M_CFG_TX_TVALID : out sl;
      M_CFG_TX_TDATA  : out slv(7 downto 0);
      M_CFG_TX_TKEEP  : out slv(0 downto 0);
      M_CFG_TX_TLAST  : out sl;
      M_CFG_TX_TUSER  : out slv(0 downto 0);
      M_CFG_TX_TREADY : in  sl;
      cfgRxTValid     : in  sl;
      cfgRxTData      : in  slv(63 downto 0));
end entity CoaXPressConfigWrapper;

architecture rtl of CoaXPressConfigWrapper is

   constant CFG_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(dataBytes => 32);

   signal cfgIbMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal cfgIbSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal cfgObMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal cfgObSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal cfgTxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal cfgTxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal cfgRxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;

   signal unusedClk : sl;
   signal unusedRst : sl;

begin

   U_CfgIb : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_CFG_IB",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         TDATA_NUM_BYTES => 32)
      port map (
         S_AXIS_ACLK    => cfgClk,
         S_AXIS_ARESETN => not cfgRst,
         S_AXIS_TVALID  => S_CFG_IB_TVALID,
         S_AXIS_TDATA   => S_CFG_IB_TDATA,
         S_AXIS_TSTRB   => (others => '1'),
         S_AXIS_TKEEP   => S_CFG_IB_TKEEP,
         S_AXIS_TLAST   => S_CFG_IB_TLAST,
         S_AXIS_TDEST   => "0",
         S_AXIS_TID     => "0",
         S_AXIS_TUSER   => S_CFG_IB_TUSER,
         S_AXIS_TREADY  => S_CFG_IB_TREADY,
         axisClk        => unusedClk,
         axisRst        => unusedRst,
         axisMaster     => cfgIbMaster,
         axisSlave      => cfgIbSlave);

   U_CfgOb : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_CFG_OB",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 2,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         TDATA_NUM_BYTES => 32)
      port map (
         M_AXIS_ACLK    => cfgClk,
         M_AXIS_ARESETN => not cfgRst,
         M_AXIS_TVALID  => M_CFG_OB_TVALID,
         M_AXIS_TDATA   => M_CFG_OB_TDATA,
         M_AXIS_TSTRB   => open,
         M_AXIS_TKEEP   => M_CFG_OB_TKEEP,
         M_AXIS_TLAST   => M_CFG_OB_TLAST,
         M_AXIS_TDEST   => open,
         M_AXIS_TID     => open,
         M_AXIS_TUSER   => M_CFG_OB_TUSER,
         M_AXIS_TREADY  => M_CFG_OB_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => cfgObMaster,
         axisSlave      => cfgObSlave);

   U_CfgTx : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_CFG_TX",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 1,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         TDATA_NUM_BYTES => 1)
      port map (
         M_AXIS_ACLK    => cfgClk,
         M_AXIS_ARESETN => not cfgRst,
         M_AXIS_TVALID  => M_CFG_TX_TVALID,
         M_AXIS_TDATA   => M_CFG_TX_TDATA,
         M_AXIS_TSTRB   => open,
         M_AXIS_TKEEP   => M_CFG_TX_TKEEP,
         M_AXIS_TLAST   => M_CFG_TX_TLAST,
         M_AXIS_TDEST   => open,
         M_AXIS_TID     => open,
         M_AXIS_TUSER   => M_CFG_TX_TUSER,
         M_AXIS_TREADY  => M_CFG_TX_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => cfgTxMaster,
         axisSlave      => cfgTxSlave);

   cfgRxMaster.tValid           <= cfgRxTValid;
   cfgRxMaster.tLast            <= cfgRxTValid;
   cfgRxMaster.tKeep(7 downto 0) <= (others => '1');
   cfgRxMaster.tData(63 downto 0) <= cfgRxTData;

   U_DUT : entity surf.CoaXPressConfig
      generic map (
         TPD_G         => 1 ns,
         AXIS_CONFIG_G => CFG_AXIS_CONFIG_C)
      port map (
         cfgClk          => cfgClk,
         cfgRst          => cfgRst,
         configTimerSize => configTimerSize,
         configErrResp   => configErrResp,
         configPktTag    => configPktTag,
         cfgIbMaster     => cfgIbMaster,
         cfgIbSlave      => cfgIbSlave,
         cfgObMaster     => cfgObMaster,
         cfgObSlave      => cfgObSlave,
         cfgTxMaster     => cfgTxMaster,
         cfgTxSlave      => cfgTxSlave,
         cfgRxMaster     => cfgRxMaster);

end architecture rtl;
