-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for CoaXPressRx
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

entity CoaXPressRxWrapper is
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
      eventTValid    : out sl;
      eventTData     : out slv(31 downto 0);
      eventTKeep     : out slv(3 downto 0);
      eventTDest     : out slv(7 downto 0);
      eventTUser     : out slv(31 downto 0);
      eventTLast     : out sl;
      eventTReady    : in  sl;
      eventAck       : out sl;
      eventTag       : out slv(7 downto 0);
      trigAck        : out sl;
      rxOverflow     : out sl;
      rxFsmError     : out sl);
end entity CoaXPressRxWrapper;

architecture rtl of CoaXPressRxWrapper is

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(dataBytes => 4);

   signal dataMaster     : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal dataSlave      : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal imageHdrMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal imageHdrSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal cfgRxMaster    : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal eventMaster    : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal eventSlave     : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal rxClkVec    : slv(NUM_LANES_G-1 downto 0);
   signal rxRstVec    : slv(NUM_LANES_G-1 downto 0);
   signal rxDataVec   : slv32Array(NUM_LANES_G-1 downto 0);
   signal rxDataKVec  : Slv4Array(NUM_LANES_G-1 downto 0);
   signal rxLinkUpVec : slv(NUM_LANES_G-1 downto 0);

begin

   GEN_LANE : for i in 0 to NUM_LANES_G-1 generate
   begin
      rxClkVec(i)    <= rxClk;
      rxRstVec(i)    <= rxRst;
      rxDataVec(i)   <= rxData(32*i+31 downto 32*i);
      rxDataKVec(i)  <= rxDataK(4*i+3 downto 4*i);
      rxLinkUpVec(i) <= rxLinkUp(i);
   end generate GEN_LANE;

   dataSlave.tReady     <= dataTReady;
   imageHdrSlave.tReady <= hdrTReady;
   eventSlave.tReady    <= eventTReady;

   dataTValid <= dataMaster.tValid;
   dataTData  <= dataMaster.tData(31 downto 0);
   dataTKeep  <= dataMaster.tKeep(3 downto 0);
   dataTLast  <= dataMaster.tLast;
   dataTUser(0) <= ssiGetUserEofe(AXIS_CONFIG_C, dataMaster);

   hdrTValid <= imageHdrMaster.tValid;
   hdrTData  <= imageHdrMaster.tData(31 downto 0);
   hdrTKeep  <= imageHdrMaster.tKeep(3 downto 0);
   hdrTLast  <= imageHdrMaster.tLast;
   hdrTUser  <= imageHdrMaster.tUser(0 downto 0);

   cfgTValid <= cfgRxMaster.tValid;
   cfgTData  <= cfgRxMaster.tData(63 downto 0);
   cfgTKeep  <= cfgRxMaster.tKeep(7 downto 0);
   cfgTLast  <= cfgRxMaster.tLast;

   eventTValid <= eventMaster.tValid;
   eventTData  <= eventMaster.tData(31 downto 0);
   eventTKeep  <= eventMaster.tKeep(3 downto 0);
   eventTDest  <= eventMaster.tDest(7 downto 0);
   eventTUser  <= eventMaster.tUser(31 downto 0);
   eventTLast  <= eventMaster.tLast;

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
         eventMaster    => eventMaster,
         eventSlave     => eventSlave,
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
