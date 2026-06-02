-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for UdpEngineArp
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

entity UdpEngineArpFlatWrapper is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      CLK_FREQ_G     : real     := 4.0;
      COMM_TIMEOUT_G : positive := 2;
      RESP_TIMEOUT_G : positive := 2);
   port (
      clk                  : in  sl;
      rst                  : in  sl;
      localIp              : in  slv(31 downto 0);
      arpTabFound          : in  sl;
      arpTabMacAddr        : in  slv(47 downto 0);
      arpTabIpWe           : out sl;
      arpTabMacWe          : out sl;
      arpTabMacAddrW       : out slv(47 downto 0);
      clientRemoteDetValid : in  sl;
      clientRemoteDetIp    : in  slv(31 downto 0);
      clientRemoteIp       : in  slv(31 downto 0);
      clientRemoteMac      : out slv(47 downto 0);
      arpReqTValid         : out sl;
      arpReqTData          : out slv(127 downto 0);
      arpReqTKeep          : out slv(15 downto 0);
      arpReqTLast          : out sl;
      arpReqTReady         : in  sl := '1';
      arpReqSof            : out sl;
      arpReqEofe           : out sl;
      arpAckTValid         : in  sl;
      arpAckTData          : in  slv(127 downto 0);
      arpAckTKeep          : in  slv(15 downto 0);
      arpAckTLast          : in  sl;
      arpAckTReady         : out sl;
      arpAckSof            : in  sl;
      arpAckEofe           : in  sl);
end entity UdpEngineArpFlatWrapper;

architecture rtl of UdpEngineArpFlatWrapper is

   signal arpReqMasters          : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal arpReqSlaves           : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal arpAckMasters          : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal arpAckSlaves           : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal arpTabMacAddrWArray    : Slv48Array(0 downto 0);
   signal clientRemoteDetIpArray : Slv32Array(0 downto 0);
   signal clientRemoteIpArray    : Slv32Array(0 downto 0);
   signal clientRemoteMacArray   : Slv48Array(0 downto 0);

begin

   arpAckComb : process (arpAckEofe, arpAckSof, arpAckTData, arpAckTKeep,
                         arpAckTLast, arpAckTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := arpAckTValid;
      v.tData(127 downto 0) := arpAckTData;
      v.tKeep(15 downto 0)  := arpAckTKeep;
      v.tLast               := arpAckTLast;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, arpAckSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, arpAckEofe);
      arpAckMasters(0)      <= v;
   end process arpAckComb;

   arpReqView : process (arpReqMasters) is
   begin
      arpReqTValid <= arpReqMasters(0).tValid;
      arpReqTData  <= arpReqMasters(0).tData(127 downto 0);
      arpReqTKeep  <= arpReqMasters(0).tKeep(15 downto 0);
      arpReqTLast  <= arpReqMasters(0).tLast;
      arpReqSof    <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, arpReqMasters(0), EMAC_SOF_BIT_C, 0);
      arpReqEofe   <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, arpReqMasters(0), EMAC_EOFE_BIT_C);
   end process arpReqView;

   arpReqSlaves(0).tReady <= arpReqTReady;
   arpAckTReady           <= arpAckSlaves(0).tReady;

   clientRemoteDetIpArray(0) <= clientRemoteDetIp;
   clientRemoteIpArray(0)    <= clientRemoteIp;
   clientRemoteMac           <= clientRemoteMacArray(0);
   arpTabMacAddrW            <= arpTabMacAddrWArray(0);

   U_DUT : entity surf.UdpEngineArp
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         CLIENT_SIZE_G  => 1,
         CLK_FREQ_G     => CLK_FREQ_G,
         COMM_TIMEOUT_G => COMM_TIMEOUT_G,
         RESP_TIMEOUT_G => RESP_TIMEOUT_G)
      port map (
         localIp                 => localIp,
         arpReqMasters           => arpReqMasters,
         arpReqSlaves            => arpReqSlaves,
         arpAckMasters           => arpAckMasters,
         arpAckSlaves            => arpAckSlaves,
         arpTabFound(0)          => arpTabFound,
         arpTabMacAddr(0)        => arpTabMacAddr,
         arpTabIpWe(0)           => arpTabIpWe,
         arpTabMacWe(0)          => arpTabMacWe,
         arpTabMacAddrW          => arpTabMacAddrWArray,
         clientRemoteDetValid(0) => clientRemoteDetValid,
         clientRemoteDetIp       => clientRemoteDetIpArray,
         clientRemoteIp          => clientRemoteIpArray,
         clientRemoteMac         => clientRemoteMacArray,
         clk                     => clk,
         rst                     => rst);

end architecture rtl;
