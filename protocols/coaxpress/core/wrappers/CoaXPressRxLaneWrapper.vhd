-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for CoaXPressRxLane
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

entity CoaXPressRxLaneWrapper is
   port (
      rxClk           : in  sl;
      rxRst           : in  sl;
      rxLinkUp        : in  sl;
      rxData          : in  slv(31 downto 0);
      rxDataK         : in  slv(3 downto 0);
      cfgTValid       : out sl;
      cfgTData        : out slv(63 downto 0);
      dataTValid      : out sl;
      dataTData       : out slv(31 downto 0);
      dataTKeep       : out slv(3 downto 0);
      dataTUser       : out slv(3 downto 0);
      dataTLast       : out sl;
      heartbeatTValid : out sl;
      heartbeatTData  : out slv(95 downto 0);
      heartbeatTLast  : out sl;
      eventTValid     : out sl;
      eventTData      : out slv(31 downto 0);
      eventTDest      : out slv(7 downto 0);
      eventTUser      : out slv(31 downto 0);
      eventTLast      : out sl;
      ioAck           : out sl;
      eventAck        : out sl;
      eventTag        : out slv(7 downto 0);
      rxError         : out sl);
end entity CoaXPressRxLaneWrapper;

architecture rtl of CoaXPressRxLaneWrapper is

   signal cfgMaster      : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal dataMaster     : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal heartbeatMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal eventMaster    : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal imageHdrMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;

begin

   -- Flatten the DUT's observable stream outputs into fixed-width scalar ports.
   cfgTValid       <= cfgMaster.tValid;
   cfgTData        <= cfgMaster.tData(63 downto 0);
   dataTValid      <= dataMaster.tValid;
   dataTData       <= dataMaster.tData(31 downto 0);
   dataTKeep       <= dataMaster.tKeep(3 downto 0);
   dataTUser       <= dataMaster.tUser(3 downto 0);
   dataTLast       <= dataMaster.tLast;
   heartbeatTValid <= heartbeatMaster.tValid;
   heartbeatTData  <= heartbeatMaster.tData(95 downto 0);
   heartbeatTLast  <= heartbeatMaster.tLast;
   eventTValid     <= eventMaster.tValid;
   eventTData      <= eventMaster.tData(31 downto 0);
   eventTDest      <= eventMaster.tDest(7 downto 0);
   eventTUser      <= eventMaster.tUser(31 downto 0);
   eventTLast      <= eventMaster.tLast;

   -- Instantiate the real receive-lane decoder with the flattened ports.
   U_DUT : entity surf.CoaXPressRxLane
      generic map (
         TPD_G => 1 ns)
      port map (
         rxClk          => rxClk,
         rxRst          => rxRst,
         cfgMaster      => cfgMaster,
         dataMaster     => dataMaster,
         heatbeatMaster => heartbeatMaster,
         eventMaster    => eventMaster,
         imageHdrMaster => imageHdrMaster,
         ioAck          => ioAck,
         eventAck       => eventAck,
         eventTag       => eventTag,
         rxError        => rxError,
         rxData         => rxData,
         rxDataK        => rxDataK,
         rxLinkUp       => rxLinkUp);

end architecture rtl;
