-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for UdpEngineTx
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

entity UdpEngineTxFlatWrapper is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      IS_CLIENT_G    : boolean  := false;
      PORT_G_VALUE   : positive := 8192);
   port (
      clk           : in  sl;
      rst           : in  sl;
      localMac      : in  slv(47 downto 0);
      localIp       : in  slv(31 downto 0);
      remotePort    : in  slv(15 downto 0);
      remoteIp      : in  slv(31 downto 0);
      remoteMac     : in  slv(47 downto 0);
      linkUp        : out sl;
      arpTabPos     : out slv(7 downto 0);
      arpTabFound   : in  sl;
      arpTabIpAddr  : in  slv(31 downto 0);
      arpTabMacAddr : in  slv(47 downto 0);
      sAppTValid    : in  sl;
      sAppTData     : in  slv(127 downto 0);
      sAppTKeep     : in  slv(15 downto 0);
      sAppTLast     : in  sl;
      sAppTReady    : out sl;
      sAppTDest     : in  slv(7 downto 0);
      sAppSof       : in  sl;
      sAppEofe      : in  sl;
      sDhcpTValid   : in  sl;
      sDhcpTData    : in  slv(127 downto 0);
      sDhcpTKeep    : in  slv(15 downto 0);
      sDhcpTLast    : in  sl;
      sDhcpTReady   : out sl;
      sDhcpSof      : in  sl;
      sDhcpEofe     : in  sl;
      mUdpTValid    : out sl;
      mUdpTData     : out slv(127 downto 0);
      mUdpTKeep     : out slv(15 downto 0);
      mUdpTLast     : out sl;
      mUdpTReady    : in  sl := '1';
      mUdpSof       : out sl;
      mUdpEofe      : out sl);
end entity UdpEngineTxFlatWrapper;

architecture rtl of UdpEngineTxFlatWrapper is

   signal sAppMasters   : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal sAppSlaves    : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal arpTabPosA    : Slv8Array(0 downto 0);
   signal remotePortA   : Slv16Array(0 downto 0);
   signal remoteIpA     : Slv32Array(0 downto 0);
   signal remoteMacA    : Slv48Array(0 downto 0);
   signal arpTabIpAddrA : Slv32Array(0 downto 0);
   signal arpTabMacA    : Slv48Array(0 downto 0);
   signal linkUpA       : slv(0 downto 0);
   signal sDhcpMaster   : AxiStreamMasterType              := AXI_STREAM_MASTER_INIT_C;
   signal sDhcpSlave    : AxiStreamSlaveType               := AXI_STREAM_SLAVE_INIT_C;
   signal mUdpMaster    : AxiStreamMasterType              := AXI_STREAM_MASTER_INIT_C;
   signal mUdpSlave     : AxiStreamSlaveType               := AXI_STREAM_SLAVE_INIT_C;

begin

   sAppComb : process (sAppEofe, sAppSof, sAppTData, sAppTDest, sAppTKeep,
                       sAppTLast, sAppTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sAppTValid;
      v.tData(127 downto 0) := sAppTData;
      v.tKeep(15 downto 0)  := sAppTKeep;
      v.tLast               := sAppTLast;
      v.tDest(7 downto 0)   := sAppTDest;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sAppSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sAppEofe);
      sAppMasters(0)        <= v;
   end process sAppComb;

   sDhcpComb : process (sDhcpEofe, sDhcpSof, sDhcpTData, sDhcpTKeep,
                        sDhcpTLast, sDhcpTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sDhcpTValid;
      v.tData(127 downto 0) := sDhcpTData;
      v.tKeep(15 downto 0)  := sDhcpTKeep;
      v.tLast               := sDhcpTLast;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sDhcpSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sDhcpEofe);
      sDhcpMaster           <= v;
   end process sDhcpComb;

   mUdpView : process (mUdpMaster) is
   begin
      mUdpTValid <= mUdpMaster.tValid;
      mUdpTData  <= mUdpMaster.tData(127 downto 0);
      mUdpTKeep  <= mUdpMaster.tKeep(15 downto 0);
      mUdpTLast  <= mUdpMaster.tLast;
      mUdpSof    <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mUdpMaster, EMAC_SOF_BIT_C, 0);
      mUdpEofe   <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mUdpMaster, EMAC_EOFE_BIT_C);
   end process mUdpView;

   sAppTReady       <= sAppSlaves(0).tReady;
   sDhcpTReady      <= sDhcpSlave.tReady;
   mUdpSlave.tReady <= mUdpTReady;

   linkUp           <= linkUpA(0);
   arpTabPos        <= arpTabPosA(0);
   remotePortA(0)   <= remotePort;
   remoteIpA(0)     <= remoteIp;
   remoteMacA(0)    <= remoteMac;
   arpTabIpAddrA(0) <= arpTabIpAddr;
   arpTabMacA(0)    <= arpTabMacAddr;

   U_DUT : entity surf.UdpEngineTx
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         SIZE_G         => 1,
         TX_FLOW_CTRL_G => true,
         IS_CLIENT_G    => IS_CLIENT_G,
         PORT_G         => (0 => PORT_G_VALUE))
      port map (
         obUdpMaster    => mUdpMaster,
         obUdpSlave     => mUdpSlave,
         linkUp         => linkUpA,
         localMac       => localMac,
         localIp        => localIp,
         remotePort     => remotePortA,
         remoteIp       => remoteIpA,
         remoteMac      => remoteMacA,
         ibMasters      => sAppMasters,
         ibSlaves       => sAppSlaves,
         arpTabPos      => arpTabPosA,
         arpTabFound(0) => arpTabFound,
         arpTabIpAddr   => arpTabIpAddrA,
         arpTabMacAddr  => arpTabMacA,
         obDhcpMaster   => sDhcpMaster,
         obDhcpSlave    => sDhcpSlave,
         clk            => clk,
         rst            => rst);

end architecture rtl;
