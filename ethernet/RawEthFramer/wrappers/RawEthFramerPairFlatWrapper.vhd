-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing loopback wrapper for two RawEthFramer instances
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
use surf.RawEthFramerPkg.all;

entity RawEthFramerPairFlatWrapper is
   generic (
      TPD_G      : time             := 1 ns;
      ETH_TYPE_G : slv(15 downto 0) := x"0010");
   port (
      clk              : in  sl;
      rst              : in  sl;
      serverLocalMac   : in  slv(47 downto 0);
      clientLocalMac   : in  slv(47 downto 0);
      sServerAppTValid : in  sl;
      sServerAppTData  : in  slv(63 downto 0);
      sServerAppTKeep  : in  slv(7 downto 0);
      sServerAppTLast  : in  sl;
      sServerAppTReady : out sl;
      sServerAppTDest  : in  slv(7 downto 0);
      sServerAppSof    : in  sl;
      sServerAppBcf    : in  sl;
      sServerAppEofe   : in  sl;
      mServerAppTValid : out sl;
      mServerAppTData  : out slv(63 downto 0);
      mServerAppTKeep  : out slv(7 downto 0);
      mServerAppTLast  : out sl;
      mServerAppTReady : in  sl := '1';
      mServerAppTDest  : out slv(7 downto 0);
      mServerAppSof    : out sl;
      mServerAppBcf    : out sl;
      mServerAppEofe   : out sl;
      sClientAppTValid : in  sl;
      sClientAppTData  : in  slv(63 downto 0);
      sClientAppTKeep  : in  slv(7 downto 0);
      sClientAppTLast  : in  sl;
      sClientAppTReady : out sl;
      sClientAppTDest  : in  slv(7 downto 0);
      sClientAppSof    : in  sl;
      sClientAppBcf    : in  sl;
      sClientAppEofe   : in  sl;
      mClientAppTValid : out sl;
      mClientAppTData  : out slv(63 downto 0);
      mClientAppTKeep  : out slv(7 downto 0);
      mClientAppTLast  : out sl;
      mClientAppTReady : in  sl := '1';
      mClientAppTDest  : out slv(7 downto 0);
      mClientAppSof    : out sl;
      mClientAppBcf    : out sl;
      mClientAppEofe   : out sl);
end entity RawEthFramerPairFlatWrapper;

architecture rtl of RawEthFramerPairFlatWrapper is

   signal serverObMacMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal serverObMacSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal serverIbMacMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal serverIbMacSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal clientObMacMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal clientObMacSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal clientIbMacMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal clientIbMacSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal sServerAppMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sServerAppSlave   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mServerAppMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mServerAppSlave   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal sClientAppMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sClientAppSlave   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mClientAppMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mClientAppSlave   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   ---------------------------------------------------------------------------
   -- Application-side stream flattening
   ---------------------------------------------------------------------------
   sServerAppComb : process (sServerAppBcf, sServerAppEofe, sServerAppSof,
                             sServerAppTData, sServerAppTDest, sServerAppTKeep,
                             sServerAppTLast, sServerAppTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                    := AXI_STREAM_MASTER_INIT_C;
      v.tValid             := sServerAppTValid;
      v.tData(63 downto 0) := sServerAppTData;
      v.tKeep(7 downto 0)  := sServerAppTKeep;
      v.tLast              := sServerAppTLast;
      v.tDest(7 downto 0)  := sServerAppTDest;
      ssiSetUserSof(RAW_ETH_CONFIG_INIT_C, v, sServerAppSof);
      ssiSetUserBcf(RAW_ETH_CONFIG_INIT_C, v, sServerAppBcf);
      ssiSetUserEofe(RAW_ETH_CONFIG_INIT_C, v, sServerAppEofe);
      sServerAppMaster     <= v;
   end process sServerAppComb;

   sClientAppComb : process (sClientAppBcf, sClientAppEofe, sClientAppSof,
                             sClientAppTData, sClientAppTDest, sClientAppTKeep,
                             sClientAppTLast, sClientAppTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                    := AXI_STREAM_MASTER_INIT_C;
      v.tValid             := sClientAppTValid;
      v.tData(63 downto 0) := sClientAppTData;
      v.tKeep(7 downto 0)  := sClientAppTKeep;
      v.tLast              := sClientAppTLast;
      v.tDest(7 downto 0)  := sClientAppTDest;
      ssiSetUserSof(RAW_ETH_CONFIG_INIT_C, v, sClientAppSof);
      ssiSetUserBcf(RAW_ETH_CONFIG_INIT_C, v, sClientAppBcf);
      ssiSetUserEofe(RAW_ETH_CONFIG_INIT_C, v, sClientAppEofe);
      sClientAppMaster     <= v;
   end process sClientAppComb;

   sServerAppTReady       <= sServerAppSlave.tReady;
   sClientAppTReady       <= sClientAppSlave.tReady;
   mServerAppSlave.tReady <= mServerAppTReady;
   mClientAppSlave.tReady <= mClientAppTReady;

   ---------------------------------------------------------------------------
   -- Application-side output flattening
   ---------------------------------------------------------------------------
   mServerAppView : process (mServerAppMaster) is
   begin
      mServerAppTValid <= mServerAppMaster.tValid;
      mServerAppTData  <= mServerAppMaster.tData(63 downto 0);
      mServerAppTKeep  <= mServerAppMaster.tKeep(7 downto 0);
      mServerAppTLast  <= mServerAppMaster.tLast;
      mServerAppTDest  <= mServerAppMaster.tDest(7 downto 0);
      mServerAppSof    <= ssiGetUserSof(RAW_ETH_CONFIG_INIT_C, mServerAppMaster);
      mServerAppBcf    <= ssiGetUserBcf(RAW_ETH_CONFIG_INIT_C, mServerAppMaster);
      mServerAppEofe   <= ssiGetUserEofe(RAW_ETH_CONFIG_INIT_C, mServerAppMaster);
   end process mServerAppView;

   mClientAppView : process (mClientAppMaster) is
   begin
      mClientAppTValid <= mClientAppMaster.tValid;
      mClientAppTData  <= mClientAppMaster.tData(63 downto 0);
      mClientAppTKeep  <= mClientAppMaster.tKeep(7 downto 0);
      mClientAppTLast  <= mClientAppMaster.tLast;
      mClientAppTDest  <= mClientAppMaster.tDest(7 downto 0);
      mClientAppSof    <= ssiGetUserSof(RAW_ETH_CONFIG_INIT_C, mClientAppMaster);
      mClientAppBcf    <= ssiGetUserBcf(RAW_ETH_CONFIG_INIT_C, mClientAppMaster);
      mClientAppEofe   <= ssiGetUserEofe(RAW_ETH_CONFIG_INIT_C, mClientAppMaster);
   end process mClientAppView;

   ---------------------------------------------------------------------------
   -- Cross-connect the MAC-side ports as a direct link
   ---------------------------------------------------------------------------
   serverObMacMaster <= clientIbMacMaster;
   clientIbMacSlave  <= serverObMacSlave;
   clientObMacMaster <= serverIbMacMaster;
   serverIbMacSlave  <= clientObMacSlave;

   ---------------------------------------------------------------------------
   -- DUT instantiation
   ---------------------------------------------------------------------------
   U_Server : entity surf.RawEthFramer
      generic map (
         TPD_G      => TPD_G,
         ETH_TYPE_G => ETH_TYPE_G)
      port map (
         localMac    => serverLocalMac,
         remoteMac   => clientLocalMac,
         tDest       => open,
         obMacMaster => serverObMacMaster,
         obMacSlave  => serverObMacSlave,
         ibMacMaster => serverIbMacMaster,
         ibMacSlave  => serverIbMacSlave,
         ibAppMaster => mServerAppMaster,
         ibAppSlave  => mServerAppSlave,
         obAppMaster => sServerAppMaster,
         obAppSlave  => sServerAppSlave,
         clk         => clk,
         rst         => rst);

   U_Client : entity surf.RawEthFramer
      generic map (
         TPD_G      => TPD_G,
         ETH_TYPE_G => ETH_TYPE_G)
      port map (
         localMac    => clientLocalMac,
         remoteMac   => serverLocalMac,
         tDest       => open,
         obMacMaster => clientObMacMaster,
         obMacSlave  => clientObMacSlave,
         ibMacMaster => clientIbMacMaster,
         ibMacSlave  => clientIbMacSlave,
         ibAppMaster => mClientAppMaster,
         ibAppSlave  => mClientAppSlave,
         obAppMaster => sClientAppMaster,
         obAppSlave  => sClientAppSlave,
         clk         => clk,
         rst         => rst);

end architecture rtl;
