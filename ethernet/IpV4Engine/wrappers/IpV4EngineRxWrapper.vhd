-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for IpV4EngineRx
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

entity IpV4EngineRxWrapper is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false);
   port (
      clk         : in  sl;
      rst         : in  sl;
      sIpv4TValid : in  sl;
      sIpv4TData  : in  slv(127 downto 0);
      sIpv4TKeep  : in  slv(15 downto 0);
      sIpv4TLast  : in  sl;
      sIpv4TReady : out sl;
      sIpv4Sof    : in  sl;
      sIpv4Eofe   : in  sl;
      mUdpTValid  : out sl;
      mUdpTData   : out slv(127 downto 0);
      mUdpTKeep   : out slv(15 downto 0);
      mUdpTLast   : out sl;
      mUdpTReady  : in  sl := '1';
      mUdpSof     : out sl;
      mUdpEofe    : out sl;
      mIcmpTValid : out sl;
      mIcmpTData  : out slv(127 downto 0);
      mIcmpTKeep  : out slv(15 downto 0);
      mIcmpTLast  : out sl;
      mIcmpTReady : in  sl := '1';
      mIcmpSof    : out sl;
      mIcmpEofe   : out sl);
end entity IpV4EngineRxWrapper;

architecture rtl of IpV4EngineRxWrapper is

   constant PROTOCOL_C : Slv8Array(1 downto 0) := (0 => UDP_C, 1 => ICMP_C);

   signal sIpv4Master      : AxiStreamMasterType             := AXI_STREAM_MASTER_INIT_C;
   signal sIpv4Slave       : AxiStreamSlaveType              := AXI_STREAM_SLAVE_INIT_C;
   signal localhostSlave   : AxiStreamSlaveType              := AXI_STREAM_SLAVE_INIT_C;
   signal ibProtocolMaster : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal ibProtocolSlave  : AxiStreamSlaveArray(1 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);

begin

   -- Flatten the inbound IPv4 MAC frame stream.
   sIpv4Comb : process (sIpv4Eofe, sIpv4Sof, sIpv4TData, sIpv4TKeep, sIpv4TLast, sIpv4TValid) is
      variable v : AxiStreamMasterType;
   begin
      v := AXI_STREAM_MASTER_INIT_C;
      v.tValid := sIpv4TValid;
      v.tData(127 downto 0) := sIpv4TData;
      v.tKeep(15 downto 0) := sIpv4TKeep;
      v.tLast := sIpv4TLast;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sIpv4Sof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sIpv4Eofe);
      sIpv4Master <= v;
   end process sIpv4Comb;

   sIpv4TReady <= sIpv4Slave.tReady;
   ibProtocolSlave(0).tReady <= mUdpTReady;
   ibProtocolSlave(1).tReady <= mIcmpTReady;

   -- Expose the UDP-routed output slot directly to cocotb.
   mUdpView : process (ibProtocolMaster(0)) is
   begin
      mUdpTValid <= ibProtocolMaster(0).tValid;
      mUdpTData <= ibProtocolMaster(0).tData(127 downto 0);
      mUdpTKeep <= ibProtocolMaster(0).tKeep(15 downto 0);
      mUdpTLast <= ibProtocolMaster(0).tLast;
      mUdpSof <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, ibProtocolMaster(0), EMAC_SOF_BIT_C, 0);
      mUdpEofe <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, ibProtocolMaster(0), EMAC_EOFE_BIT_C);
   end process mUdpView;

   -- Expose the ICMP-routed output slot in the same flattened format.
   mIcmpView : process (ibProtocolMaster(1)) is
   begin
      mIcmpTValid <= ibProtocolMaster(1).tValid;
      mIcmpTData <= ibProtocolMaster(1).tData(127 downto 0);
      mIcmpTKeep <= ibProtocolMaster(1).tKeep(15 downto 0);
      mIcmpTLast <= ibProtocolMaster(1).tLast;
      mIcmpSof <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, ibProtocolMaster(1), EMAC_SOF_BIT_C, 0);
      mIcmpEofe <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, ibProtocolMaster(1), EMAC_EOFE_BIT_C);
   end process mIcmpView;

   U_DUT : entity surf.IpV4EngineRx
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         PROTOCOL_SIZE_G => 2,
         PROTOCOL_G      => PROTOCOL_C)
      port map (
         ibIpv4Master      => sIpv4Master,
         ibIpv4Slave       => sIpv4Slave,
         localhostMaster   => AXI_STREAM_MASTER_INIT_C,
         localhostSlave    => localhostSlave,
         ibProtocolMasters => ibProtocolMaster,
         ibProtocolSlaves  => ibProtocolSlave,
         clk               => clk,
         rst               => rst);

end architecture rtl;
