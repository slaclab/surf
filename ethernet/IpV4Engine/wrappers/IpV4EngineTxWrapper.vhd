-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for IpV4EngineTx
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

entity IpV4EngineTxWrapper is
   generic (
      TPD_G          : time            := 1 ns;
      RST_POLARITY_G : sl              := '1';
      RST_ASYNC_G    : boolean         := false;
      TTL_G          : slv(7 downto 0) := x"20");
   port (
      clk          : in  sl;
      rst          : in  sl;
      localMac     : in  slv(47 downto 0);
      sProtTValid  : in  sl;
      sProtTData   : in  slv(127 downto 0);
      sProtTKeep   : in  slv(15 downto 0);
      sProtTLast   : in  sl;
      sProtTReady  : out sl;
      sProtSof     : in  sl;
      sProtEofe    : in  sl;
      mIpv4TValid  : out sl;
      mIpv4TData   : out slv(127 downto 0);
      mIpv4TKeep   : out slv(15 downto 0);
      mIpv4TLast   : out sl;
      mIpv4TReady  : in  sl := '1';
      mIpv4Sof     : out sl;
      mIpv4Eofe    : out sl;
      mLocalTValid : out sl;
      mLocalTData  : out slv(127 downto 0);
      mLocalTKeep  : out slv(15 downto 0);
      mLocalTLast  : out sl;
      mLocalTReady : in  sl := '1';
      mLocalSof    : out sl;
      mLocalEofe   : out sl);
end entity IpV4EngineTxWrapper;

architecture rtl of IpV4EngineTxWrapper is

   constant PROTOCOL_C : Slv8Array(0 downto 0) := (0 => UDP_C);

   signal sProtMaster       : AxiStreamMasterType              := AXI_STREAM_MASTER_INIT_C;
   signal sProtSlave        : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal obProtocolMasters : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal mIpv4Master       : AxiStreamMasterType              := AXI_STREAM_MASTER_INIT_C;
   signal mIpv4Slave        : AxiStreamSlaveType               := AXI_STREAM_SLAVE_INIT_C;
   signal mLocalMaster      : AxiStreamMasterType              := AXI_STREAM_MASTER_INIT_C;
   signal mLocalSlave       : AxiStreamSlaveType               := AXI_STREAM_SLAVE_INIT_C;

begin

   -- Flatten the single protocol-source stream that feeds the TX engine.
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

   obProtocolMasters(0) <= sProtMaster;
   sProtTReady          <= sProtSlave(0).tReady;
   mIpv4Slave.tReady    <= mIpv4TReady;
   mLocalSlave.tReady   <= mLocalTReady;

   -- Re-expand the external-IPv4 output path.
   mIpv4View : process (mIpv4Master) is
   begin
      mIpv4TValid <= mIpv4Master.tValid;
      mIpv4TData  <= mIpv4Master.tData(127 downto 0);
      mIpv4TKeep  <= mIpv4Master.tKeep(15 downto 0);
      mIpv4TLast  <= mIpv4Master.tLast;
      mIpv4Sof    <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mIpv4Master, EMAC_SOF_BIT_C, 0);
      mIpv4Eofe   <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mIpv4Master, EMAC_EOFE_BIT_C);
   end process mIpv4View;

   -- Re-expand the localhost shortcut output path separately.
   mLocalView : process (mLocalMaster) is
   begin
      mLocalTValid <= mLocalMaster.tValid;
      mLocalTData  <= mLocalMaster.tData(127 downto 0);
      mLocalTKeep  <= mLocalMaster.tKeep(15 downto 0);
      mLocalTLast  <= mLocalMaster.tLast;
      mLocalSof    <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mLocalMaster, EMAC_SOF_BIT_C, 0);
      mLocalEofe   <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mLocalMaster, EMAC_EOFE_BIT_C);
   end process mLocalView;

   U_DUT : entity surf.IpV4EngineTx
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         PROTOCOL_SIZE_G => 1,
         PROTOCOL_G      => PROTOCOL_C,
         TTL_G           => TTL_G)
      port map (
         localMac          => localMac,
         obIpv4Master      => mIpv4Master,
         obIpv4Slave       => mIpv4Slave,
         localhostMaster   => mLocalMaster,
         localhostSlave    => mLocalSlave,
         obProtocolMasters => obProtocolMasters,
         obProtocolSlaves  => sProtSlave,
         clk               => clk,
         rst               => rst);

end architecture rtl;
