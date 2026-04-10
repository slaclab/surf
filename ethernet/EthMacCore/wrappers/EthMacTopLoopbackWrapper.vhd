-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing XGMII loopback wrapper for EthMacTop
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

entity EthMacTopLoopbackWrapper is
   generic (
      TPD_G             : time                     := 1 ns;
      RST_POLARITY_G    : sl                       := '1';
      PAUSE_EN_G        : boolean                  := false;
      PAUSE_512BITS_G   : positive range 1 to 1024 := 8;
      DROP_ERR_PKT_G    : boolean                  := true;
      JUMBO_G           : boolean                  := false;
      INT_PIPE_STAGES_G : natural                  := 1;
      PIPE_STAGES_G     : natural                  := 1;
      FIFO_ADDR_WIDTH_G : positive                 := 11;
      SYNTH_MODE_G      : string                   := "inferred";
      MEMORY_TYPE_G     : string                   := "block";
      ROCEV2_EN_G       : boolean                  := false;
      FILT_EN_G         : boolean                  := false);
   port (
      ethClk           : in  sl;
      ethRst           : in  sl;
      phyReady         : in  sl;
      sAxisTValid      : in  sl;
      sAxisTData       : in  slv(127 downto 0);
      sAxisTKeep       : in  slv(15 downto 0);
      sAxisTLast       : in  sl;
      sAxisTDest       : in  slv(7 downto 0);
      sAxisTReady      : out sl;
      sAxisSof         : in  sl;
      sAxisEofe        : in  sl;
      mAxisTValid      : out sl;
      mAxisTData       : out slv(127 downto 0);
      mAxisTKeep       : out slv(15 downto 0);
      mAxisTLast       : out sl;
      mAxisTDest       : out slv(7 downto 0);
      mAxisTReady      : in  sl := '1';
      mAxisSof         : out sl;
      mAxisEofe        : out sl;
      localMac         : in  slv(47 downto 0);
      filtEnable       : in  sl;
      pauseEnable      : in  sl;
      pauseTime        : in  slv(15 downto 0);
      pauseThresh      : in  slv(15 downto 0);
      ipCsumEn         : in  sl;
      tcpCsumEn        : in  sl;
      udpCsumEn        : in  sl;
      dropOnPause      : in  sl;
      rxPauseCnt       : out sl;
      rxOverFlow       : out sl;
      rxCountEn        : out sl;
      rxCrcErrorCnt    : out sl;
      txCountEn        : out sl;
      txUnderRunCnt    : out sl;
      txNotReadyCnt    : out sl);
end entity EthMacTopLoopbackWrapper;

architecture rtl of EthMacTopLoopbackWrapper is

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal ethConfig   : EthMacConfigType    := ETH_MAC_CONFIG_INIT_C;
   signal ethStatus   : EthMacStatusType    := ETH_MAC_STATUS_INIT_C;
   signal xgmiiTxd    : slv(63 downto 0)    := (others => '0');
   signal xgmiiTxc    : slv(7 downto 0)     := (others => '1');

begin

   -- Flatten the primary AXIS source used by the test.
   sAxisComb : process (sAxisEofe, sAxisSof, sAxisTData, sAxisTDest, sAxisTKeep, sAxisTLast, sAxisTValid) is
      variable v : AxiStreamMasterType;
   begin
      v := AXI_STREAM_MASTER_INIT_C;
      v.tValid := sAxisTValid;
      v.tData(127 downto 0) := sAxisTData;
      v.tKeep(15 downto 0) := sAxisTKeep;
      v.tLast := sAxisTLast;
      v.tDest(7 downto 0) := sAxisTDest;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sAxisSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sAxisEofe);
      sAxisMaster <= v;
   end process sAxisComb;

   sAxisTReady <= sAxisSlave.tReady;
   mAxisSlave.tReady <= mAxisTReady;

   -- Re-expand the received primary AXIS stream for cocotb checks.
   mAxisView : process (mAxisMaster) is
   begin
      mAxisTValid <= mAxisMaster.tValid;
      mAxisTData <= mAxisMaster.tData(127 downto 0);
      mAxisTKeep <= mAxisMaster.tKeep(15 downto 0);
      mAxisTLast <= mAxisMaster.tLast;
      mAxisTDest <= mAxisMaster.tDest(7 downto 0);
      mAxisSof <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_SOF_BIT_C, 0);
      mAxisEofe <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_EOFE_BIT_C);
   end process mAxisView;

   -- Flatten the public EthMacTop config record.
   ethConfig.macAddress <= localMac;
   ethConfig.filtEnable <= filtEnable;
   ethConfig.pauseEnable <= pauseEnable;
   ethConfig.pauseTime <= pauseTime;
   ethConfig.pauseThresh <= pauseThresh;
   ethConfig.ipCsumEn <= ipCsumEn;
   ethConfig.tcpCsumEn <= tcpCsumEn;
   ethConfig.udpCsumEn <= udpCsumEn;
   ethConfig.dropOnPause <= dropOnPause;

   -- Flatten the small status record for direct cocotb observation.
   rxPauseCnt <= ethStatus.rxPauseCnt;
   rxOverFlow <= ethStatus.rxOverFlow;
   rxCountEn <= ethStatus.rxCountEn;
   rxCrcErrorCnt <= ethStatus.rxCrcErrorCnt;
   txCountEn <= ethStatus.txCountEn;
   txUnderRunCnt <= ethStatus.txUnderRunCnt;
   txNotReadyCnt <= ethStatus.txNotReadyCnt;

   -- Instantiate the real top-level MAC in XGMII loopback mode.
   U_DUT : entity surf.EthMacTop
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         PAUSE_EN_G        => PAUSE_EN_G,
         PAUSE_512BITS_G   => PAUSE_512BITS_G,
         PHY_TYPE_G        => "XGMII",
         DROP_ERR_PKT_G    => DROP_ERR_PKT_G,
         JUMBO_G           => JUMBO_G,
         INT_PIPE_STAGES_G => INT_PIPE_STAGES_G,
         PIPE_STAGES_G     => PIPE_STAGES_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         SYNTH_MODE_G      => SYNTH_MODE_G,
         MEMORY_TYPE_G     => MEMORY_TYPE_G,
         ROCEV2_EN_G       => ROCEV2_EN_G,
         FILT_EN_G         => FILT_EN_G,
         PRIM_COMMON_CLK_G => true,
         PRIM_CONFIG_G     => EMAC_AXIS_CONFIG_C,
         BYP_EN_G          => false,
         BYP_COMMON_CLK_G  => false,
         BYP_CONFIG_G      => EMAC_AXIS_CONFIG_C)
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
