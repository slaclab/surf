-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing physical-port and bypass adapter for PTP experiments
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

entity EthMacPtpExperimentWrapper is
   generic (
      TPD_G             : time                     := 1 ns;
      RST_POLARITY_G    : sl                       := '1';
      PTP_RX_EN_G       : boolean                  := false;
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
      ethClk         : in  sl;
      ethRst         : in  sl;
      ptpFlush       : in sl               := '0';
      ptpGeneration  : in slv(31 downto 0) := (others => '0');
      ptpSeconds     : in slv(47 downto 0) := (others => '0');
      ptpNanoseconds : in slv(31 downto 0) := (others => '0');
      ptpFraction    : in slv(31 downto 0) := (others => '0');
      ptpTicks       : in slv(63 downto 0) := (others => '0');
      ptpMessage     : out slv(743 downto 0);
      ptpValid       : out sl;
      ptpReady       : in sl               := '1';
      ptpAbort       : out sl;
      ptpOverflow    : out slv(31 downto 0);
      bypRst         : in  sl;
      xgmiiRxd       : in  slv(63 downto 0);
      xgmiiRxc       : in  slv(7 downto 0);
      xgmiiTxd       : out slv(63 downto 0);
      xgmiiTxc       : out slv(7 downto 0);
      rxFifoDrop     : out sl;
      phyReady       : in  sl;
      sAxisTValid    : in  sl;
      sAxisTData     : in  slv(127 downto 0);
      sAxisTKeep     : in  slv(15 downto 0);
      sAxisTLast     : in  sl;
      sAxisTDest     : in  slv(7 downto 0);
      sAxisTReady    : out sl;
      sAxisSof       : in  sl;
      sAxisEofe      : in  sl;
      mAxisTValid    : out sl;
      mAxisTData     : out slv(127 downto 0);
      mAxisTKeep     : out slv(15 downto 0);
      mAxisTLast     : out sl;
      mAxisTDest     : out slv(7 downto 0);
      mAxisTReady    : in  sl              := '1';
      mAxisSof       : out sl;
      mAxisEofe      : out sl;
      sBypTValid     : in  sl;
      sBypTData      : in  slv(127 downto 0);
      sBypTKeep      : in  slv(15 downto 0);
      sBypTLast      : in  sl;
      sBypTDest      : in  slv(7 downto 0);
      sBypTReady     : out sl;
      sBypSof        : in  sl;
      sBypEofe       : in  sl;
      mBypTValid     : out sl;
      mBypTData      : out slv(127 downto 0);
      mBypTKeep      : out slv(15 downto 0);
      mBypTLast      : out sl;
      mBypTDest      : out slv(7 downto 0);
      mBypTReady     : in  sl              := '1';
      mBypSof        : out sl;
      mBypEofe       : out sl;
      localMac       : in  slv(47 downto 0);
      filtEnable     : in  sl;
      pauseEnable    : in  sl;
      pauseTime      : in  slv(15 downto 0);
      pauseThresh    : in  slv(15 downto 0);
      ipCsumEn       : in  sl;
      tcpCsumEn      : in  sl;
      udpCsumEn      : in  sl;
      dropOnPause    : in  sl;
      rxPauseCnt     : out sl;
      rxOverFlow     : out sl;
      rxCountEn      : out sl;
      rxCrcErrorCnt  : out sl;
      txCountEn      : out sl;
      txUnderRunCnt  : out sl;
      txNotReadyCnt  : out sl);
end entity EthMacPtpExperimentWrapper;

architecture rtl of EthMacPtpExperimentWrapper is

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal sBypMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sBypSlave : AxiStreamSlaveType := AXI_STREAM_SLAVE_INIT_C;
   signal mBypMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mBypSlave : AxiStreamSlaveType := AXI_STREAM_SLAVE_INIT_C;
   signal ethConfig   : EthMacConfigType    := ETH_MAC_CONFIG_INIT_C;
   signal ethStatus   : EthMacStatusType    := ETH_MAC_STATUS_INIT_C;

begin

   -- Flatten the primary AXIS source used by the test.
   sAxisComb : process (sAxisEofe, sAxisSof, sAxisTData, sAxisTDest,
                        sAxisTKeep, sAxisTLast, sAxisTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sAxisTValid;
      v.tData(127 downto 0) := sAxisTData;
      v.tKeep(15 downto 0)  := sAxisTKeep;
      v.tLast               := sAxisTLast;
      v.tDest(7 downto 0)   := sAxisTDest;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sAxisSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sAxisEofe);
      sAxisMaster           <= v;
   end process sAxisComb;

   sAxisTReady       <= sAxisSlave.tReady;
   mAxisSlave.tReady <= mAxisTReady;

   -- Re-expand the received primary AXIS stream for cocotb checks.
   mAxisView : process (mAxisMaster) is
   begin
      mAxisTValid <= mAxisMaster.tValid;
      mAxisTData  <= mAxisMaster.tData(127 downto 0);
      mAxisTKeep  <= mAxisMaster.tKeep(15 downto 0);
      mAxisTLast  <= mAxisMaster.tLast;
      mAxisTDest  <= mAxisMaster.tDest(7 downto 0);
      mAxisSof    <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_SOF_BIT_C, 0);
      mAxisEofe   <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mAxisMaster, EMAC_EOFE_BIT_C);
   end process mAxisView;

   -- Flatten the bypass AXIS source used by the test.
   sBypComb : process (sBypEofe, sBypSof, sBypTData, sBypTDest,
                       sBypTKeep, sBypTLast, sBypTValid) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := sBypTValid;
      v.tData(127 downto 0) := sBypTData;
      v.tKeep(15 downto 0)  := sBypTKeep;
      v.tLast               := sBypTLast;
      v.tDest(7 downto 0)   := sBypTDest;
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_SOF_BIT_C, sBypSof, 0);
      axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v, EMAC_EOFE_BIT_C, sBypEofe);
      sBypMaster           <= v;
   end process sBypComb;

   sBypTReady       <= sBypSlave.tReady;
   mBypSlave.tReady <= mBypTReady;

   -- Re-expand the received bypass AXIS stream for cocotb checks.
   mBypView : process (mBypMaster) is
   begin
      mBypTValid <= mBypMaster.tValid;
      mBypTData  <= mBypMaster.tData(127 downto 0);
      mBypTKeep  <= mBypMaster.tKeep(15 downto 0);
      mBypTLast  <= mBypMaster.tLast;
      mBypTDest  <= mBypMaster.tDest(7 downto 0);
      mBypSof    <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mBypMaster, EMAC_SOF_BIT_C, 0);
      mBypEofe   <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mBypMaster, EMAC_EOFE_BIT_C);
   end process mBypView;

   -- Flatten the public EthMacTop config record.
   ethConfig.macAddress  <= localMac;
   ethConfig.filtEnable  <= filtEnable;
   ethConfig.pauseEnable <= pauseEnable;
   ethConfig.pauseTime   <= pauseTime;
   ethConfig.pauseThresh <= pauseThresh;
   ethConfig.ipCsumEn    <= ipCsumEn;
   ethConfig.tcpCsumEn   <= tcpCsumEn;
   ethConfig.udpCsumEn   <= udpCsumEn;
   ethConfig.dropOnPause <= dropOnPause;

   -- Flatten the small status record for direct cocotb observation.
   rxFifoDrop    <= ethStatus.rxFifoDropCnt;
   rxPauseCnt    <= ethStatus.rxPauseCnt;
   rxOverFlow    <= ethStatus.rxOverFlow;
   rxCountEn     <= ethStatus.rxCountEn;
   rxCrcErrorCnt <= ethStatus.rxCrcErrorCnt;
   txCountEn     <= ethStatus.txCountEn;
   txUnderRunCnt <= ethStatus.txUnderRunCnt;
   txNotReadyCnt <= ethStatus.txNotReadyCnt;

   -- Instantiate the real top-level MAC in XGMII mode with independently driven RX and TX.
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
         BYP_EN_G          => true,
         BYP_ETH_TYPE_G    => x"F788",
         BYP_COMMON_CLK_G  => true,
         BYP_CONFIG_G      => EMAC_AXIS_CONFIG_C)
      port map (
         ethClkEn        => '1',             -- [in]
         ethClk          => ethClk,          -- [in]
         ethRst          => ethRst,          -- [in]
         primClk         => ethClk,          -- [in]
         primRst         => ethRst,          -- [in]
         ibMacPrimMaster => sAxisMaster,     -- [in]
         ibMacPrimSlave  => sAxisSlave,      -- [out]
         obMacPrimMaster => mAxisMaster,     -- [out]
         obMacPrimSlave  => mAxisSlave,      -- [in]
         bypClk          => ethClk,          -- [in]
         bypRst          => bypRst,          -- [in]
         ibMacBypMaster  => sBypMaster,      -- [in]
         ibMacBypSlave   => sBypSlave,       -- [out]
         obMacBypMaster  => mBypMaster,      -- [out]
         obMacBypSlave   => mBypSlave,       -- [in]
         xlgmiiRxd       => (others => '0'), -- [in]
         xlgmiiRxc       => (others => '1'), -- [in]
         xgmiiRxd        => xgmiiRxd,        -- [in]
         xgmiiRxc        => xgmiiRxc,        -- [in]
         xgmiiTxd        => xgmiiTxd,        -- [out]
         xgmiiTxc        => xgmiiTxc,        -- [out]
         gmiiRxDv        => '0',             -- [in]
         gmiiRxEr        => '0',             -- [in]
         gmiiRxd         => (others => '0'), -- [in]
         gmiiTxEn        => open,            -- [out]
         gmiiTxEr        => open,            -- [out]
         gmiiTxd         => open,            -- [out]
         phyReady        => phyReady,        -- [in]
         ethConfig       => ethConfig,       -- [in]
         ethStatus       => ethStatus);      -- [out]

   GEN_PTP : if PTP_RX_EN_G generate
      U_PtpRx : entity surf.PtpRxFrontendWrapper
         generic map (
            PHY_TYPE_G => "XGMII", RST_POLARITY_G => RST_POLARITY_G)
         port map (
            clk              => ethClk,         -- [in]
            rst              => ethRst,         -- [in]
            rxFlush          => ptpFlush,       -- [in]
            phyReady         => phyReady,       -- [in]
            generation       => ptpGeneration,  -- [in]
            phcSeconds       => ptpSeconds,     -- [in]
            phcNanoseconds   => ptpNanoseconds, -- [in]
            phcFraction      => ptpFraction,    -- [in]
            tickCount        => ptpTicks,       -- [in]
            xgmiiRxd         => xgmiiRxd,       -- [in]
            xgmiiRxc         => xgmiiRxc,       -- [in]
            normValid        => open,           -- [out]
            normData         => open,           -- [out]
            normKeep         => open,           -- [out]
            normSof          => open,           -- [out]
            normLast         => open,           -- [out]
            normError        => open,           -- [out]
            normTime         => open,           -- [out]
            normTicks        => open,           -- [out]
            normPhase        => open,           -- [out]
            normGeneration   => open,           -- [out]
            normTimeValid    => open,           -- [out]
            normCaptureError => open,           -- [out]
            messageData      => ptpMessage,     -- [out]
            messageValid     => ptpValid,       -- [out]
            messageReady     => ptpReady,       -- [in]
            rxAbort          => ptpAbort,       -- [out]
            rxEpoch          => open,           -- [out]
            acceptedCount    => open,           -- [out]
            droppedCount     => open,           -- [out]
            overflowCount    => ptpOverflow);   -- [out]
   end generate GEN_PTP;
   GEN_NO_PTP : if not PTP_RX_EN_G generate
      ptpMessage <= (others => '0');
      ptpValid <= '0';
      ptpAbort <= '0';
      ptpOverflow <= (others => '0');
   end generate GEN_NO_PTP;

end architecture rtl;
