-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for CoaXPressRxHsFsm
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

entity CoaXPressRxHsFsmWrapper is
   generic (
      NUM_LANES_G        : positive range 1 to 8  := 1;
      RX_FSM_CNT_WIDTH_G : positive range 1 to 24 := 16);
   port (
      rxClk       : in  sl;
      rxRst       : in  sl;
      rxFsmRst    : in  sl;
      sAxisTValid : in  sl;
      sAxisTData  : in  slv(32*NUM_LANES_G-1 downto 0);
      sAxisTKeep  : in  slv(4*NUM_LANES_G-1 downto 0);
      sAxisTLast  : in  sl;
      sAxisTReady : out sl;
      hdrTValid   : out sl;
      hdrTData    : out slv(223 downto 0);
      hdrTLast    : out sl;
      hdrTSof     : out sl;
      dataTValid  : out sl;
      dataTData   : out slv(32*NUM_LANES_G-1 downto 0);
      dataTKeep   : out slv(4*NUM_LANES_G-1 downto 0);
      dataTLast   : out sl;
      rxFsmError  : out sl);
end entity CoaXPressRxHsFsmWrapper;

architecture rtl of CoaXPressRxHsFsmWrapper is

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal hdrMaster   : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal dataMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;

begin

   -- Present the flattened source beat as one wide AXI-stream record.
   sAxisComb : process (sAxisTData, sAxisTKeep, sAxisTLast, sAxisTValid) is
      variable v : AxiStreamMasterType;
   begin
      v        := AXI_STREAM_MASTER_INIT_C;
      v.tValid := sAxisTValid;
      v.tData(32*NUM_LANES_G-1 downto 0) := sAxisTData;
      v.tKeep(4*NUM_LANES_G-1 downto 0)  := sAxisTKeep;
      v.tLast  := sAxisTLast;
      sAxisMaster <= v;
   end process sAxisComb;

   sAxisTReady <= sAxisSlave.tReady;

   -- Flatten the observable header and image-data outputs.
   hdrTValid   <= hdrMaster.tValid;
   hdrTData    <= hdrMaster.tData(223 downto 0);
   hdrTLast    <= hdrMaster.tLast;
   hdrTSof     <= hdrMaster.tUser(SSI_SOF_C);
   dataTValid  <= dataMaster.tValid;
   dataTData   <= dataMaster.tData(32*NUM_LANES_G-1 downto 0);
   dataTKeep   <= dataMaster.tKeep(4*NUM_LANES_G-1 downto 0);
   dataTLast   <= dataMaster.tLast;

   -- Instantiate the real high-speed receive FSM behind the shim.
   U_DUT : entity surf.CoaXPressRxHsFsm
      generic map (
         TPD_G              => 1 ns,
         RX_FSM_CNT_WIDTH_G => RX_FSM_CNT_WIDTH_G,
         NUM_LANES_G        => NUM_LANES_G)
      port map (
         rxClk      => rxClk,
         rxRst      => rxRst,
         rxFsmRst   => rxFsmRst,
         rxFsmError => rxFsmError,
         rxMaster   => sAxisMaster,
         rxSlave    => sAxisSlave,
         hdrMaster  => hdrMaster,
         dataMaster => dataMaster);

end architecture rtl;
