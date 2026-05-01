-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for IpV4Engine
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

entity IpV4EngineTopWrapper is
   generic (
      TPD_G          : time            := 1 ns;
      RST_POLARITY_G : sl              := '1';
      RST_ASYNC_G    : boolean         := false;
      CLK_FREQ_G     : real            := 100.0E+06;
      TTL_G          : slv(7 downto 0) := x"20");
   port (
      clk          : in  sl;
      rst          : in  sl;
      localMac     : in  slv(47 downto 0);
      localIp      : in  slv(31 downto 0);
      sMacTValid   : in  sl;
      sMacTData    : in  slv(127 downto 0);
      sMacTKeep    : in  slv(15 downto 0);
      sMacTLast    : in  sl;
      sMacTReady   : out sl;
      sMacSof      : in  sl;
      sMacEofe     : in  sl;
      mMacTValid   : out sl;
      mMacTData    : out slv(127 downto 0);
      mMacTKeep    : out slv(15 downto 0);
      mMacTLast    : out sl;
      mMacTReady   : in  sl := '1';
      mMacSof      : out sl;
      mMacEofe     : out sl;
      sProtTValid  : in  sl;
      sProtTData   : in  slv(127 downto 0);
      sProtTKeep   : in  slv(15 downto 0);
      sProtTLast   : in  sl;
      sProtTReady  : out sl;
      sProtSof     : in  sl;
      sProtEofe    : in  sl;
      mProtTValid  : out sl;
      mProtTData   : out slv(127 downto 0);
      mProtTKeep   : out slv(15 downto 0);
      mProtTLast   : out sl;
      mProtTReady  : in  sl := '1';
      mProtSof     : out sl;
      mProtEofe    : out sl;
      arpReqTValid : in  sl;
      arpReqTData  : in  slv(127 downto 0);
      arpReqTKeep  : in  slv(15 downto 0);
      arpReqTLast  : in  sl;
      arpReqTReady : out sl;
      arpReqSof    : in  sl;
      arpReqEofe   : in  sl;
      arpAckTValid : out sl;
      arpAckTData  : out slv(127 downto 0);
      arpAckTKeep  : out slv(15 downto 0);
      arpAckTLast  : out sl;
      arpAckTReady : in  sl := '1';
      arpAckSof    : out sl;
      arpAckEofe   : out sl);
end entity IpV4EngineTopWrapper;

architecture rtl of IpV4EngineTopWrapper is

   constant PROTOCOL_C : Slv8Array(0 downto 0) := (0 => UDP_C);

   signal sMacMaster   : AxiStreamMasterType              := AXI_STREAM_MASTER_INIT_C;
   signal sMacSlave    : AxiStreamSlaveType               := AXI_STREAM_SLAVE_INIT_C;
   signal mMacMaster   : AxiStreamMasterType              := AXI_STREAM_MASTER_INIT_C;
   signal mMacSlave    : AxiStreamSlaveType               := AXI_STREAM_SLAVE_INIT_C;
   signal sProtMaster  : AxiStreamMasterType              := AXI_STREAM_MASTER_INIT_C;
   signal sProtSlave   : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal mProtMaster  : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal mProtSlave   : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal arpReqMaster : AxiStreamMasterType              := AXI_STREAM_MASTER_INIT_C;
   signal arpReqSlave  : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal arpAckMaster : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal arpAckSlave  : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal igmpIp       : Slv32Array(0 downto 0)           := (others => (others => '0'));

begin

   -- Flatten the inbound MAC stream for end-to-end top-level stimulus.
   sMacComb : process (sMacEofe, sMacSof, sMacTData, sMacTKeep, sMacTLast,
                       sMacTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sMacTValid;
      v.tData(127 downto 0) := sMacTData;
      v.tKeep(15 downto 0)  := sMacTKeep;
      v.tLast               := sMacTLast;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sMacSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sMacEofe);
      sMacMaster            <= v;
   end process sMacComb;

   -- Flatten the single external protocol-engine source slot.
   sProtComb : process (sProtEofe, sProtSof, sProtTData, sProtTKeep,
                        sProtTLast, sProtTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sProtTValid;
      v.tData(127 downto 0) := sProtTData;
      v.tKeep(15 downto 0)  := sProtTKeep;
      v.tLast               := sProtTLast;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sProtSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sProtEofe);
      sProtMaster           <= v;
   end process sProtComb;

   -- Flatten the single ARP client request slot.
   arpReqComb : process (arpReqEofe, arpReqSof, arpReqTData, arpReqTKeep,
                         arpReqTLast, arpReqTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := arpReqTValid;
      v.tData(127 downto 0) := arpReqTData;
      v.tKeep(15 downto 0)  := arpReqTKeep;
      v.tLast               := arpReqTLast;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, arpReqSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, arpReqEofe);
      arpReqMaster          <= v;
   end process arpReqComb;

   sMacTReady            <= sMacSlave.tReady;
   sProtTReady           <= sProtSlave(0).tReady;
   arpReqTReady          <= arpReqSlave(0).tReady;
   mMacSlave.tReady      <= mMacTReady;
   mProtSlave(0).tReady  <= mProtTReady;
   arpAckSlave(0).tReady <= arpAckTReady;

   -- Re-expand the top-level outbound MAC stream.
   mMacView : process (mMacMaster) is
   begin
      mMacTValid <= mMacMaster.tValid;
      mMacTData  <= mMacMaster.tData(127 downto 0);
      mMacTKeep  <= mMacMaster.tKeep(15 downto 0);
      mMacTLast  <= mMacMaster.tLast;
      mMacSof    <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mMacMaster, EMAC_SOF_BIT_C, 0);
      mMacEofe   <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mMacMaster, EMAC_EOFE_BIT_C);
   end process mMacView;

   -- Re-expand the exposed protocol slot that receives inbound UDP traffic.
   mProtView : process (mProtMaster) is
   begin
      mProtTValid <= mProtMaster(0).tValid;
      mProtTData  <= mProtMaster(0).tData(127 downto 0);
      mProtTKeep  <= mProtMaster(0).tKeep(15 downto 0);
      mProtTLast  <= mProtMaster(0).tLast;
      mProtSof    <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mProtMaster(0), EMAC_SOF_BIT_C, 0);
      mProtEofe   <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mProtMaster(0), EMAC_EOFE_BIT_C);
   end process mProtView;

   -- Re-expand the single client ARP acknowledgement slot.
   arpAckView : process (arpAckMaster) is
   begin
      arpAckTValid <= arpAckMaster(0).tValid;
      arpAckTData  <= arpAckMaster(0).tData(127 downto 0);
      arpAckTKeep  <= arpAckMaster(0).tKeep(15 downto 0);
      arpAckTLast  <= arpAckMaster(0).tLast;
      arpAckSof    <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, arpAckMaster(0), EMAC_SOF_BIT_C, 0);
      arpAckEofe   <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, arpAckMaster(0), EMAC_EOFE_BIT_C);
   end process arpAckView;

   U_DUT : entity surf.IpV4Engine
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         PROTOCOL_SIZE_G => 1,
         PROTOCOL_G      => PROTOCOL_C,
         CLIENT_SIZE_G   => 1,
         CLK_FREQ_G      => CLK_FREQ_G,
         TTL_G           => TTL_G,
         IGMP_G          => false,
         IGMP_GRP_SIZE   => 1)
      port map (
         localMac          => localMac,
         localIp           => localIp,
         igmpIp            => igmpIp,
         obMacMaster       => sMacMaster,
         obMacSlave        => sMacSlave,
         ibMacMaster       => mMacMaster,
         ibMacSlave        => mMacSlave,
         obProtocolMasters => (0 => sProtMaster),
         obProtocolSlaves  => sProtSlave,
         ibProtocolMasters => mProtMaster,
         ibProtocolSlaves  => mProtSlave,
         arpReqMasters     => (0 => arpReqMaster),
         arpReqSlaves      => arpReqSlave,
         arpAckMasters     => arpAckMaster,
         arpAckSlaves      => arpAckSlave,
         clk               => clk,
         rst               => rst);

end architecture rtl;
