-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing loopback wrapper for EthMacTx
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

entity EthMacTxLoopbackWrapper is
   generic (
      TPD_G           : time                     := 1 ns;
      RST_POLARITY_G  : sl                       := '1';
      PAUSE_EN_G      : boolean                  := true;
      PAUSE_512BITS_G : positive range 1 to 1024 := 1;
      PHY_TYPE_G      : string                   := "XGMII";
      DROP_ERR_PKT_G  : boolean                  := true;
      JUMBO_G         : boolean                  := false;
      BYP_EN_G        : boolean                  := true;
      SYNTH_MODE_G    : string                   := "inferred");
   port (
      ethClk         : in  sl;
      ethRst         : in  sl;
      ethClkEn       : in  sl := '1';
      phyReady       : in  sl;
      sPrimTValid    : in  sl;
      sPrimTData     : in  slv(127 downto 0);
      sPrimTKeep     : in  slv(15 downto 0);
      sPrimTLast     : in  sl;
      sPrimTReady    : out sl;
      sPrimSof       : in  sl;
      sPrimFrag      : in  sl;
      sPrimEofe      : in  sl;
      sBypTValid     : in  sl;
      sBypTData      : in  slv(127 downto 0);
      sBypTKeep      : in  slv(15 downto 0);
      sBypTLast      : in  sl;
      sBypTReady     : out sl;
      sBypSof        : in  sl;
      sBypFrag       : in  sl;
      sBypEofe       : in  sl;
      mAxisTValid    : out sl;
      mAxisTData     : out slv(127 downto 0);
      mAxisTKeep     : out slv(15 downto 0);
      mAxisTLast     : out sl;
      mAxisSof       : out sl;
      mAxisFrag      : out sl;
      mAxisEofe      : out sl;
      clientPause    : in  sl;
      rxPauseReq     : in  sl;
      rxPauseValue   : in  slv(15 downto 0);
      pauseEnable    : in  sl;
      pauseTime      : in  slv(15 downto 0);
      macAddress     : in  slv(47 downto 0);
      ipCsumEn       : in  sl;
      tcpCsumEn      : in  sl;
      udpCsumEn      : in  sl;
      pauseTx        : out sl;
      txCountEn      : out sl;
      txUnderRun     : out sl;
      txLinkNotReady : out sl);
end entity EthMacTxLoopbackWrapper;

architecture rtl of EthMacTxLoopbackWrapper is

   signal sPrimMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sPrimSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal sBypMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sBypSlave   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal xgmiiTxd    : slv(63 downto 0)    := (others => '0');
   signal xgmiiTxc    : slv(7 downto 0)     := (others => '1');
   signal gmiiTxEn    : sl                  := '0';
   signal gmiiTxEr    : sl                  := '0';
   signal gmiiTxd     : slv(7 downto 0)     := (others => '0');
   signal ethConfig   : EthMacConfigType    := ETH_MAC_CONFIG_INIT_C;

begin

   -- Flatten the primary client stream that feeds the TX assembly.
   sPrimComb : process (sPrimEofe, sPrimFrag, sPrimSof, sPrimTData, sPrimTKeep,
                        sPrimTLast, sPrimTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sPrimTValid;
      v.tData(127 downto 0) := sPrimTData;
      v.tKeep(15 downto 0)  := sPrimTKeep;
      v.tLast               := sPrimTLast;
      axiStreamSetUserBit(INT_EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sPrimSof, 0);
      axiStreamSetUserBit(INT_EMAC_AXIS_CONFIG_C, v, EMAC_FRAG_BIT_C, sPrimFrag, 0);
      axiStreamSetUserBit(INT_EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sPrimEofe);
      sPrimMaster           <= v;
   end process sPrimComb;

   -- Flatten the bypass stream independently so the test can drive both ports.
   sBypComb : process (sBypEofe, sBypFrag, sBypSof, sBypTData, sBypTKeep,
                       sBypTLast, sBypTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sBypTValid;
      v.tData(127 downto 0) := sBypTData;
      v.tKeep(15 downto 0)  := sBypTKeep;
      v.tLast               := sBypTLast;
      axiStreamSetUserBit(INT_EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sBypSof, 0);
      axiStreamSetUserBit(INT_EMAC_AXIS_CONFIG_C, v, EMAC_FRAG_BIT_C, sBypFrag, 0);
      axiStreamSetUserBit(INT_EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sBypEofe);
      sBypMaster            <= v;
   end process sBypComb;

   sPrimTReady <= sPrimSlave.tReady;
   sBypTReady  <= sBypSlave.tReady;

   -- Present the recovered on-wire frame back to cocotb as a flat AXIS view.
   mAxisView : process (mAxisMaster) is
   begin
      mAxisTValid <= mAxisMaster.tValid;
      mAxisTData  <= mAxisMaster.tData(127 downto 0);
      mAxisTKeep  <= mAxisMaster.tKeep(15 downto 0);
      mAxisTLast  <= mAxisMaster.tLast;
      mAxisSof    <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_SOF_BIT_C, 0);
      mAxisFrag   <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_FRAG_BIT_C, 0);
      mAxisEofe   <= axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_EOFE_BIT_C);
   end process mAxisView;

   -- Flatten the relevant TX config fields under software control.
   ethConfig.macAddress  <= macAddress;
   ethConfig.filtEnable  <= '0';
   ethConfig.pauseEnable <= pauseEnable;
   ethConfig.pauseTime   <= pauseTime;
   ethConfig.pauseThresh <= (others => '0');
   ethConfig.ipCsumEn    <= ipCsumEn;
   ethConfig.tcpCsumEn   <= tcpCsumEn;
   ethConfig.udpCsumEn   <= udpCsumEn;
   ethConfig.dropOnPause <= '0';

   -- Drive the full TX assembly, including checksum, pause, and export logic.
   U_DUT : entity surf.EthMacTx
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         PAUSE_EN_G      => PAUSE_EN_G,
         PAUSE_512BITS_G => PAUSE_512BITS_G,
         PHY_TYPE_G      => PHY_TYPE_G,
         DROP_ERR_PKT_G  => DROP_ERR_PKT_G,
         JUMBO_G         => JUMBO_G,
         ROCEV2_EN_G     => false,
         BYP_EN_G        => BYP_EN_G,
         SYNTH_MODE_G    => SYNTH_MODE_G)
      port map (
         ethClkEn       => ethClkEn,
         ethClk         => ethClk,
         ethRst         => ethRst,
         sPrimMaster    => sPrimMaster,
         sPrimSlave     => sPrimSlave,
         sBypMaster     => sBypMaster,
         sBypSlave      => sBypSlave,
         xlgmiiTxd      => open,
         xlgmiiTxc      => open,
         xgmiiTxd       => xgmiiTxd,
         xgmiiTxc       => xgmiiTxc,
         gmiiTxEn       => gmiiTxEn,
         gmiiTxEr       => gmiiTxEr,
         gmiiTxd        => gmiiTxd,
         clientPause    => clientPause,
         rxPauseReq     => rxPauseReq,
         rxPauseValue   => rxPauseValue,
         pauseTx        => pauseTx,
         phyReady       => phyReady,
         ethConfig      => ethConfig,
         txCountEn      => txCountEn,
         txUnderRun     => txUnderRun,
         txLinkNotReady => txLinkNotReady);

   -- Recover the transmitted PHY stream so cocotb can validate frame order.
   U_Loopback : entity surf.EthMacRxImport
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         PHY_TYPE_G     => PHY_TYPE_G,
         SYNTH_MODE_G   => SYNTH_MODE_G)
      port map (
         ethClkEn    => ethClkEn,
         ethClk      => ethClk,
         ethRst      => ethRst,
         macIbMaster => mAxisMaster,
         xlgmiiRxd   => (others => '0'),
         xlgmiiRxc   => (others => '1'),
         xgmiiRxd    => xgmiiTxd,
         xgmiiRxc    => xgmiiTxc,
         gmiiRxDv    => gmiiTxEn,
         gmiiRxEr    => gmiiTxEr,
         gmiiRxd     => gmiiTxd,
         phyReady    => phyReady,
         rxCountEn   => open,
         rxCrcError  => open);

end architecture rtl;
