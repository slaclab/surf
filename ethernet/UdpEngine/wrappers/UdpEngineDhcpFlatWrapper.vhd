-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for UdpEngineDhcp
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

entity UdpEngineDhcpFlatWrapper is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      CLK_FREQ_G     : real     := 4.0;
      COMM_TIMEOUT_G : positive := 3;
      SYNTH_MODE_G   : string   := "inferred");
   port (
      clk         : in  sl;
      rst         : in  sl;
      localMac    : in  slv(47 downto 0);
      localIp     : in  slv(31 downto 0);
      dhcpIp      : out slv(31 downto 0);
      sDhcpTValid : in  sl;
      sDhcpTData  : in  slv(127 downto 0);
      sDhcpTKeep  : in  slv(15 downto 0);
      sDhcpTLast  : in  sl;
      sDhcpTReady : out sl;
      sDhcpSof    : in  sl;
      sDhcpEofe   : in  sl;
      mDhcpTValid : out sl;
      mDhcpTData  : out slv(127 downto 0);
      mDhcpTKeep  : out slv(15 downto 0);
      mDhcpTLast  : out sl;
      mDhcpTReady : in  sl := '1';
      mDhcpSof    : out sl;
      mDhcpEofe   : out sl);
end entity UdpEngineDhcpFlatWrapper;

architecture rtl of UdpEngineDhcpFlatWrapper is

   signal sDhcpMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sDhcpSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mDhcpMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mDhcpSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

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

   mDhcpView : process (mDhcpMaster) is
   begin
      mDhcpTValid <= mDhcpMaster.tValid;
      mDhcpTData  <= mDhcpMaster.tData(127 downto 0);
      mDhcpTKeep  <= mDhcpMaster.tKeep(15 downto 0);
      mDhcpTLast  <= mDhcpMaster.tLast;
      mDhcpSof    <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mDhcpMaster, EMAC_SOF_BIT_C, 0);
      mDhcpEofe   <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mDhcpMaster, EMAC_EOFE_BIT_C);
   end process mDhcpView;

   sDhcpTReady       <= sDhcpSlave.tReady;
   mDhcpSlave.tReady <= mDhcpTReady;

   U_DUT : entity surf.UdpEngineDhcp
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         CLK_FREQ_G     => CLK_FREQ_G,
         COMM_TIMEOUT_G => COMM_TIMEOUT_G,
         SYNTH_MODE_G   => SYNTH_MODE_G)
      port map (
         localMac     => localMac,
         localIp      => localIp,
         dhcpIp       => dhcpIp,
         ibDhcpMaster => sDhcpMaster,
         ibDhcpSlave  => sDhcpSlave,
         obDhcpMaster => mDhcpMaster,
         obDhcpSlave  => mDhcpSlave,
         clk          => clk,
         rst          => rst);

end architecture rtl;
