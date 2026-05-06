-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for EthMacRxCheckICrc
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
use surf.EthMacPkg.all;

entity EthMacRxCheckICrcWrapper is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false);
   port (
      ethClk        : in  sl;
      ethRst        : in  sl;
      sAxisTValid   : in  sl;
      sAxisTData    : in  slv(127 downto 0);
      sAxisTKeep    : in  slv(15 downto 0);
      sAxisTLast    : in  sl;
      sAxisTDest    : in  slv(7 downto 0);
      sAxisTReady   : out sl;
      sAxisSof      : in  sl;
      sAxisFrag     : in  sl;
      sAxisEofe     : in  sl;
      sCrcTValid    : in  sl;
      sCrcTData     : in  slv(31 downto 0);
      sCrcTReady    : out sl;
      mAxisTValid   : out sl;
      mAxisTData    : out slv(127 downto 0);
      mAxisTKeep    : out slv(15 downto 0);
      mAxisTLast    : out sl;
      mAxisTDest    : out slv(7 downto 0);
      mAxisTReady   : in  sl;
      mAxisSof      : out sl;
      mAxisFrag     : out sl;
      mAxisEofe     : out sl;
      mAxisCrcError : out sl);
end entity EthMacRxCheckICrcWrapper;

architecture rtl of EthMacRxCheckICrcWrapper is

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal sCrcMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sCrcSlave   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   ----------------------------------------------------------------------------
   -- Flat cocotb input shims
   ----------------------------------------------------------------------------
   sAxisComb : process (sAxisEofe, sAxisFrag, sAxisSof, sAxisTData, sAxisTDest,
                        sAxisTKeep, sAxisTLast, sAxisTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sAxisTValid;
      v.tData(127 downto 0) := sAxisTData;
      v.tKeep(15 downto 0)  := sAxisTKeep;
      v.tLast               := sAxisTLast;
      v.tDest(7 downto 0)   := sAxisTDest;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_FRAG_BIT_C, sAxisFrag, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sAxisSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sAxisEofe);
      sAxisMaster           <= v;
   end process sAxisComb;

   sAxisTReady <= sAxisSlave.tReady;

   sCrcComb : process (sCrcTData, sCrcTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                    := AXI_STREAM_MASTER_INIT_C;
      v.tValid             := sCrcTValid;
      v.tData(31 downto 0) := sCrcTData;
      v.tKeep(3 downto 0)  := x"F";
      v.tLast              := '1';
      sCrcMaster           <= v;
   end process sCrcComb;

   sCrcTReady <= sCrcSlave.tReady;

   mAxisReadyComb : process (mAxisTReady) is
      variable v : AxiStreamSlaveType;
   begin
      v          := AXI_STREAM_SLAVE_INIT_C;
      v.tReady   := mAxisTReady;
      mAxisSlave <= v;
   end process mAxisReadyComb;

   ----------------------------------------------------------------------------
   -- Flat cocotb output view
   ----------------------------------------------------------------------------
   mAxisView : process (mAxisMaster) is
   begin
      mAxisTValid   <= mAxisMaster.tValid;
      mAxisTData    <= mAxisMaster.tData(127 downto 0);
      mAxisTKeep    <= mAxisMaster.tKeep(15 downto 0);
      mAxisTLast    <= mAxisMaster.tLast;
      mAxisTDest    <= mAxisMaster.tDest(7 downto 0);
      mAxisSof      <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_SOF_BIT_C, 0);
      mAxisFrag     <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_FRAG_BIT_C, 0);
      mAxisEofe     <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_EOFE_BIT_C);
      mAxisCrcError <= mAxisMaster.tUser(2);
   end process mAxisView;

   ----------------------------------------------------------------------------
   -- DUT hookup
   ----------------------------------------------------------------------------
   U_DUT : entity surf.EthMacRxCheckICrc
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         ethClk              => ethClk,
         ethRst              => ethRst,
         sAxisMaster         => sAxisMaster,
         sAxisSlave          => sAxisSlave,
         sAxisCrcCheckMaster => sCrcMaster,
         sAxisCrcCheckSlave  => sCrcSlave,
         mAxisMaster         => mAxisMaster,
         mAxisSlave          => mAxisSlave);

end architecture rtl;
