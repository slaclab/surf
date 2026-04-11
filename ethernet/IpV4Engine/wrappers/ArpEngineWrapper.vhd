-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for ArpEngine
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

entity ArpEngineWrapper is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false;
      CLK_FREQ_G     : real    := 100.0E+06);
   port (
      clk         : in  sl;
      rst         : in  sl;
      localMac    : in  slv(47 downto 0);
      localIp     : in  slv(31 downto 0);
      reqTValid   : in  sl;
      reqTData    : in  slv(127 downto 0);
      reqTKeep    : in  slv(15 downto 0);
      reqTLast    : in  sl;
      reqTReady   : out sl;
      reqSof      : in  sl;
      reqEofe     : in  sl;
      ackTValid   : out sl;
      ackTData    : out slv(127 downto 0);
      ackTKeep    : out slv(15 downto 0);
      ackTLast    : out sl;
      ackTReady   : in  sl := '1';
      ackSof      : out sl;
      ackEofe     : out sl;
      sArpTValid  : in  sl;
      sArpTData   : in  slv(127 downto 0);
      sArpTKeep   : in  slv(15 downto 0);
      sArpTLast   : in  sl;
      sArpTReady  : out sl;
      sArpSof     : in  sl;
      sArpEofe    : in  sl;
      mArpTValid  : out sl;
      mArpTData   : out slv(127 downto 0);
      mArpTKeep   : out slv(15 downto 0);
      mArpTLast   : out sl;
      mArpTReady  : in  sl := '1';
      mArpSof     : out sl;
      mArpEofe    : out sl);
end entity ArpEngineWrapper;

architecture rtl of ArpEngineWrapper is

   signal reqMaster      : AxiStreamMasterType             := AXI_STREAM_MASTER_INIT_C;
   signal reqSlave       : AxiStreamSlaveArray(0 downto 0) := (others => AXI_STREAM_SLAVE_INIT_C);
   signal ackMaster      : AxiStreamMasterArray(0 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal ackSlave       : AxiStreamSlaveArray(0 downto 0)  := (others => AXI_STREAM_SLAVE_INIT_C);
   signal sArpMaster     : AxiStreamMasterType             := AXI_STREAM_MASTER_INIT_C;
   signal sArpSlave      : AxiStreamSlaveType              := AXI_STREAM_SLAVE_INIT_C;
   signal mArpMaster     : AxiStreamMasterType             := AXI_STREAM_MASTER_INIT_C;
   signal mArpSlave      : AxiStreamSlaveType              := AXI_STREAM_SLAVE_INIT_C;

begin

   -- Flatten the client ARP request sideband stream.
   reqComb : process (reqEofe, reqSof, reqTData, reqTKeep, reqTLast, reqTValid) is
      variable v : AxiStreamMasterType;
   begin
      v := AXI_STREAM_MASTER_INIT_C;
      v.tValid := reqTValid;
      v.tData(127 downto 0) := reqTData;
      v.tKeep(15 downto 0) := reqTKeep;
      v.tLast := reqTLast;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, reqSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, reqEofe);
      reqMaster <= v;
   end process reqComb;

   -- Flatten the inbound ARP frame stream from the MAC side.
   sArpComb : process (sArpEofe, sArpSof, sArpTData, sArpTKeep, sArpTLast, sArpTValid) is
      variable v : AxiStreamMasterType;
   begin
      v := AXI_STREAM_MASTER_INIT_C;
      v.tValid := sArpTValid;
      v.tData(127 downto 0) := sArpTData;
      v.tKeep(15 downto 0) := sArpTKeep;
      v.tLast := sArpTLast;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sArpSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sArpEofe);
      sArpMaster <= v;
   end process sArpComb;

   reqTReady <= reqSlave(0).tReady;
   sArpTReady <= sArpSlave.tReady;
   ackSlave(0).tReady <= ackTReady;
   mArpSlave.tReady <= mArpTReady;

   -- Re-expand the client-facing ARP acknowledgement stream.
   ackView : process (ackMaster(0)) is
   begin
      ackTValid <= ackMaster(0).tValid;
      ackTData <= ackMaster(0).tData(127 downto 0);
      ackTKeep <= ackMaster(0).tKeep(15 downto 0);
      ackTLast <= ackMaster(0).tLast;
      ackSof <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, ackMaster(0), EMAC_SOF_BIT_C, 0);
      ackEofe <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, ackMaster(0), EMAC_EOFE_BIT_C);
   end process ackView;

   -- Re-expand the outbound ARP frame stream for direct payload checks.
   mArpView : process (mArpMaster) is
   begin
      mArpTValid <= mArpMaster.tValid;
      mArpTData <= mArpMaster.tData(127 downto 0);
      mArpTKeep <= mArpMaster.tKeep(15 downto 0);
      mArpTLast <= mArpMaster.tLast;
      mArpSof <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mArpMaster, EMAC_SOF_BIT_C, 0);
      mArpEofe <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mArpMaster, EMAC_EOFE_BIT_C);
   end process mArpView;

   U_DUT : entity surf.ArpEngine
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         CLIENT_SIZE_G  => 1,
         CLK_FREQ_G     => CLK_FREQ_G)
      port map (
         localMac      => localMac,
         localIp       => localIp,
         arpReqMasters(0) => reqMaster,
         arpReqSlaves  => reqSlave,
         arpAckMasters => ackMaster,
         arpAckSlaves  => ackSlave,
         ibArpMaster   => sArpMaster,
         ibArpSlave    => sArpSlave,
         obArpMaster   => mArpMaster,
         obArpSlave    => mArpSlave,
         clk           => clk,
         rst           => rst);

end architecture rtl;
