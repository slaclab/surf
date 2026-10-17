-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing XGMII loopback wrapper for EthMacTop that exposes
-- the TID sideband on both primary streams.
--
-- Selects the MAC-internal stream configuration through INT_CONFIG_G so one
-- bench can run the default (zero TID bits) and the timing configuration
-- (eight TID bits) and observe whether a frame's tId survives the TX FIFO,
-- checksum cache, exporter, importer and RX FIFO. Everything else matches
-- EthMacTopLoopbackWrapper.
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

entity EthMacTopTidLoopbackWrapper is
   generic (
      TPD_G             : time     := 1 ns;
      RST_POLARITY_G    : sl       := '1';
      TIMING_EN_G       : boolean  := false;
      FIFO_ADDR_WIDTH_G : positive := 11);
   port (
      ethClk        : in  sl;
      ethRst        : in  sl;
      phyReady      : in  sl;
      sAxisTValid   : in  sl;
      sAxisTData    : in  slv(127 downto 0);
      sAxisTKeep    : in  slv(15 downto 0);
      sAxisTLast    : in  sl;
      sAxisTId      : in  slv(7 downto 0);
      sAxisTReady   : out sl;
      sAxisSof      : in  sl;
      sAxisEofe     : in  sl;
      mAxisTValid   : out sl;
      mAxisTData    : out slv(127 downto 0);
      mAxisTKeep    : out slv(15 downto 0);
      mAxisTLast    : out sl;
      mAxisTId      : out slv(7 downto 0);
      mAxisTReady   : in  sl := '1';
      mAxisSof      : out sl;
      mAxisEofe     : out sl;
      localMac      : in  slv(47 downto 0);
      rxCrcErrorCnt : out sl;
      rxFifoDropCnt : out sl);
end entity EthMacTopTidLoopbackWrapper;

architecture rtl of EthMacTopTidLoopbackWrapper is

   -- The controller-facing streams carry TID only when timing mode is on, so
   -- the bench can prove the default configuration still truncates it.
   constant PRIM_CONFIG_C : AxiStreamConfigType := ite(TIMING_EN_G, EMAC_TIMING_AXIS_CONFIG_C, EMAC_AXIS_CONFIG_C);
   constant INT_CONFIG_C  : AxiStreamConfigType := ite(TIMING_EN_G, EMAC_TIMING_AXIS_CONFIG_C, INT_EMAC_AXIS_CONFIG_C);

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal ethConfig   : EthMacConfigType    := ETH_MAC_CONFIG_INIT_C;
   signal ethStatus   : EthMacStatusType    := ETH_MAC_STATUS_INIT_C;
   signal xgmiiTxd    : slv(63 downto 0)    := (others => '0');
   signal xgmiiTxc    : slv(7 downto 0)     := (others => '1');

begin

   sAxisComb : process (sAxisEofe, sAxisSof, sAxisTData, sAxisTId, sAxisTKeep,
                        sAxisTLast, sAxisTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sAxisTValid;
      v.tData(127 downto 0) := sAxisTData;
      v.tKeep(15 downto 0)  := sAxisTKeep;
      v.tLast               := sAxisTLast;
      v.tId                 := sAxisTId;
      axiStreamSetUserBit(PRIM_CONFIG_C, v, EMAC_SOF_BIT_C, sAxisSof, 0);
      axiStreamSetUserBit(PRIM_CONFIG_C, v, EMAC_EOFE_BIT_C, sAxisEofe);
      sAxisMaster           <= v;
   end process sAxisComb;

   sAxisTReady       <= sAxisSlave.tReady;
   mAxisSlave.tReady <= mAxisTReady;

   mAxisView : process (mAxisMaster) is
   begin
      mAxisTValid <= mAxisMaster.tValid;
      mAxisTData  <= mAxisMaster.tData(127 downto 0);
      mAxisTKeep  <= mAxisMaster.tKeep(15 downto 0);
      mAxisTLast  <= mAxisMaster.tLast;
      mAxisTId    <= mAxisMaster.tId;
      mAxisSof    <= axiStreamGetUserBit(PRIM_CONFIG_C, mAxisMaster, EMAC_SOF_BIT_C, 0);
      mAxisEofe   <= axiStreamGetUserBit(PRIM_CONFIG_C, mAxisMaster, EMAC_EOFE_BIT_C);
   end process mAxisView;

   -- Filtering and checksum offload are disabled so the bench isolates the
   -- sideband path; pause stays enabled because its generated frames carry
   -- tId zero and must not disturb neighbouring tokens.
   ethConfig.macAddress  <= localMac;
   ethConfig.filtEnable  <= '0';
   ethConfig.pauseEnable <= '1';
   ethConfig.pauseTime   <= x"0020";
   ethConfig.pauseThresh <= x"0008";
   ethConfig.ipCsumEn    <= '0';
   ethConfig.tcpCsumEn   <= '0';
   ethConfig.udpCsumEn   <= '0';
   ethConfig.dropOnPause <= '0';

   rxCrcErrorCnt <= ethStatus.rxCrcErrorCnt;
   rxFifoDropCnt <= ethStatus.rxFifoDropCnt;

   U_DUT : entity surf.EthMacTop
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         PAUSE_EN_G        => true,
         PAUSE_512BITS_G   => 8,
         PHY_TYPE_G        => "XGMII",
         DROP_ERR_PKT_G    => true,
         JUMBO_G           => false,
         INT_PIPE_STAGES_G => 1,
         PIPE_STAGES_G     => 1,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         SYNTH_MODE_G      => "inferred",
         MEMORY_TYPE_G     => "block",
         ROCEV2_EN_G       => false,
         FILT_EN_G         => false,
         PRIM_COMMON_CLK_G => true,
         PRIM_CONFIG_G     => PRIM_CONFIG_C,
         INT_CONFIG_G      => INT_CONFIG_C,
         BYP_EN_G          => false,
         BYP_COMMON_CLK_G  => false,
         BYP_CONFIG_G      => PRIM_CONFIG_C)
      port map (
         ethClkEn        => '1',
         ethClk          => ethClk,
         ethRst          => ethRst,
         primClk         => ethClk,
         primRst         => ethRst,
         ibMacPrimMaster => sAxisMaster,
         ibMacPrimSlave  => sAxisSlave,
         obMacPrimMaster => mAxisMaster,
         obMacPrimSlave  => mAxisSlave,
         bypClk          => '0',
         bypRst          => '0',
         ibMacBypMaster  => AXI_STREAM_MASTER_INIT_C,
         ibMacBypSlave   => open,
         obMacBypMaster  => open,
         obMacBypSlave   => AXI_STREAM_SLAVE_FORCE_C,
         xlgmiiRxd       => (others => '0'),
         xlgmiiRxc       => (others => '1'),
         xgmiiRxd        => xgmiiTxd,
         xgmiiRxc        => xgmiiTxc,
         xgmiiTxd        => xgmiiTxd,
         xgmiiTxc        => xgmiiTxc,
         gmiiRxDv        => '0',
         gmiiRxEr        => '0',
         gmiiRxd         => (others => '0'),
         gmiiTxEn        => open,
         gmiiTxEr        => open,
         gmiiTxd         => open,
         phyReady        => phyReady,
         ethConfig       => ethConfig,
         ethStatus       => ethStatus);

end architecture rtl;
