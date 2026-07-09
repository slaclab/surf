-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing CoaXPressRx wrapper using the core output path
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

entity CoaXPressRxCorePathWrapper is
   generic (
      NUM_LANES_G        : positive range 1 to 8  := 1;
      RX_FSM_CNT_WIDTH_G : positive range 1 to 24 := 8);
   port (
      dataClk        : in  sl;
      dataRst        : in  sl;
      cfgClk         : in  sl;
      cfgRst         : in  sl;
      txClk          : in  sl;
      txRst          : in  sl;
      rxClk          : in  sl;
      rxRst          : in  sl;
      rxData         : in  slv(32*NUM_LANES_G-1 downto 0);
      rxDataK        : in  slv(4*NUM_LANES_G-1 downto 0);
      rxLinkUp       : in  slv(NUM_LANES_G-1 downto 0);
      rxFsmRst       : in  sl;
      rxNumberOfLane : in  slv(2 downto 0);
      dataTValid     : out sl;
      dataTData      : out slv(31 downto 0);
      dataTKeep      : out slv(3 downto 0);
      dataTLast      : out sl;
      dataTUser      : out slv(0 downto 0);
      dataTReady     : in  sl;
      hdrTValid      : out sl;
      hdrTData       : out slv(31 downto 0);
      hdrTKeep       : out slv(3 downto 0);
      hdrTLast       : out sl;
      hdrTUser       : out slv(0 downto 0);
      hdrTReady      : in  sl;
      cfgTValid      : out sl;
      cfgTData       : out slv(63 downto 0);
      cfgTKeep       : out slv(7 downto 0);
      cfgTLast       : out sl;
      eventAck       : out sl;
      eventTag       : out slv(7 downto 0);
      trigAck        : out sl;
      rxOverflow     : out sl;
      rxFsmError     : out sl);
end entity CoaXPressRxCorePathWrapper;

architecture rtl of CoaXPressRxCorePathWrapper is

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(dataBytes => 4);

   signal dataMaster     : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal dataSlave      : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal imageHdrMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal imageHdrSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal cfgRxMaster    : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;

   signal rxClkVec    : slv(NUM_LANES_G-1 downto 0);
   signal rxRstVec    : slv(NUM_LANES_G-1 downto 0);
   signal rxDataVec   : slv32Array(NUM_LANES_G-1 downto 0);
   signal rxDataKVec  : Slv4Array(NUM_LANES_G-1 downto 0);
   signal rxLinkUpVec : slv(NUM_LANES_G-1 downto 0);

   signal unusedDataClk : sl;
   signal unusedDataRst : sl;
   signal unusedHdrClk  : sl;
   signal unusedHdrRst  : sl;

begin

   GEN_LANE : for i in 0 to NUM_LANES_G-1 generate
   begin
      rxClkVec(i)    <= rxClk;
      rxRstVec(i)    <= rxRst;
      rxDataVec(i)   <= rxData(32*i+31 downto 32*i);
      rxDataKVec(i)  <= rxDataK(4*i+3 downto 4*i);
      rxLinkUpVec(i) <= rxLinkUp(i);
   end generate GEN_LANE;

   cfgTValid <= cfgRxMaster.tValid;
   cfgTData  <= cfgRxMaster.tData(63 downto 0);
   cfgTKeep  <= cfgRxMaster.tKeep(7 downto 0);
   cfgTLast  <= cfgRxMaster.tLast;

   U_Data : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_DATA",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 1,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         TDATA_NUM_BYTES => 4)
      port map (
         M_AXIS_ACLK    => dataClk,
         M_AXIS_ARESETN => not dataRst,
         M_AXIS_TVALID  => dataTValid,
         M_AXIS_TDATA   => dataTData,
         M_AXIS_TSTRB   => open,
         M_AXIS_TKEEP   => dataTKeep,
         M_AXIS_TLAST   => dataTLast,
         M_AXIS_TDEST   => open,
         M_AXIS_TID     => open,
         M_AXIS_TUSER   => dataTUser,
         M_AXIS_TREADY  => dataTReady,
         axisClk        => unusedDataClk,
         axisRst        => unusedDataRst,
         axisMaster     => dataMaster,
         axisSlave      => dataSlave);

   U_Hdr : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_HDR",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => 1,
         TID_WIDTH       => 1,
         TDEST_WIDTH     => 1,
         TDATA_NUM_BYTES => 4)
      port map (
         M_AXIS_ACLK    => dataClk,
         M_AXIS_ARESETN => not dataRst,
         M_AXIS_TVALID  => hdrTValid,
         M_AXIS_TDATA   => hdrTData,
         M_AXIS_TSTRB   => open,
         M_AXIS_TKEEP   => hdrTKeep,
         M_AXIS_TLAST   => hdrTLast,
         M_AXIS_TDEST   => open,
         M_AXIS_TID     => open,
         M_AXIS_TUSER   => hdrTUser,
         M_AXIS_TREADY  => hdrTReady,
         axisClk        => unusedHdrClk,
         axisRst        => unusedHdrRst,
         axisMaster     => imageHdrMaster,
         axisSlave      => imageHdrSlave);

   U_DUT : entity surf.CoaXPressRx
      generic map (
         TPD_G              => 1 ns,
         NUM_LANES_G        => NUM_LANES_G,
         RX_FSM_CNT_WIDTH_G => RX_FSM_CNT_WIDTH_G,
         AXIS_CONFIG_G      => AXIS_CONFIG_C)
      port map (
         dataClk        => dataClk,
         dataRst        => dataRst,
         dataMaster     => dataMaster,
         dataSlave      => dataSlave,
         imageHdrMaster => imageHdrMaster,
         imageHdrSlave  => imageHdrSlave,
         cfgClk         => cfgClk,
         cfgRst         => cfgRst,
         cfgRxMaster    => cfgRxMaster,
         eventAck       => eventAck,
         eventTag       => eventTag,
         txClk          => txClk,
         txRst          => txRst,
         trigAck        => trigAck,
         rxClk          => rxClkVec,
         rxRst          => rxRstVec,
         rxData         => rxDataVec,
         rxDataK        => rxDataKVec,
         rxLinkUp       => rxLinkUpVec,
         rxOverflow     => rxOverflow,
         rxFsmError     => rxFsmError,
         rxFsmRst       => rxFsmRst,
         rxNumberOfLane => rxNumberOfLane);

end architecture rtl;
