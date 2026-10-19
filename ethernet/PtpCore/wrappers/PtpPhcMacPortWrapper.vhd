-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PtpPhcCore driving the PtpMacPortEthMac timing-port fixture.
--
-- Composes the real standalone PHC subsystem with PtpMacPortEthMacWrapper, so
-- the port and both passive-adapter oracles consume the core's registered
-- phcTime/phcStatus/captureAbort tuple instead of a bench model. The core is
-- reached through its AXI-Lite bank (owner and policy commits) and its
-- external command port (cycle-placed RATE/SET/PHASE/VALID commands). The
-- live tuple is exposed under the inner fixture's PHC port names for
-- observation. All other ports pass through unchanged.
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
use surf.AxiLitePkg.all;
use surf.PtpPkg.all;

entity PtpPhcMacPortWrapper is
   generic (
      TPD_G      : time     := 1 ns;
      PHY_TYPE_G : string   := "GMII";
      CLK_FREQ_G : positive := 125000000);
   port (
      -- Shared Ethernet/PHC clock and system reset (active high)
      clk                : in  sl;
      rst                : in  sl;

      -- PHC core AXI-Lite bank
      axil_awaddr        : in  slv(31 downto 0);
      axil_awvalid       : in  sl;
      axil_awready       : out sl;
      axil_wdata         : in  slv(31 downto 0);
      axil_wstrb         : in  slv(3 downto 0);
      axil_wvalid        : in  sl;
      axil_wready        : out sl;
      axil_bresp         : out slv(1 downto 0);
      axil_bvalid        : out sl;
      axil_bready        : in  sl;
      axil_araddr        : in  slv(31 downto 0);
      axil_arvalid       : in  sl;
      axil_arready       : out sl;
      axil_rdata         : out slv(31 downto 0);
      axil_rresp         : out slv(1 downto 0);
      axil_rvalid        : out sl;
      axil_rready        : in  sl;

      -- PHC core external command client
      commandValid       : in  sl;
      commandKind        : in  slv(2 downto 0);
      commandGeneration  : in  slv(31 downto 0);
      commandSeconds     : in  slv(47 downto 0);
      commandNanoseconds : in  slv(31 downto 0);
      commandFraction    : in  slv(31 downto 0);
      phaseSeconds       : in  slv(63 downto 0);
      phaseFraction      : in  slv(63 downto 0);
      commandRate        : in  slv(63 downto 0);
      commandValue       : in  sl;
      commandReady       : out sl;
      commandAck         : out sl;
      commandError       : out sl;
      externalOwner      : out sl;

      -- Live PHC tuple from the core, as seen by the port and oracles
      phcSeconds         : out slv(47 downto 0);
      phcNanoseconds     : out slv(31 downto 0);
      phcFraction        : out slv(31 downto 0);
      phcGeneration      : out slv(31 downto 0);
      phcTicks           : out slv(63 downto 0);
      phcIncrement       : out slv(63 downto 0);
      phcTimeValid       : out sl;
      captureAbort       : out sl;
      statusAck          : out sl;
      discontinuity      : out sl;

      -- Timing-port fixture (unchanged)
      phyReady          : in  sl;
      openAdmission     : in  sl;
      drainRequest      : in  sl;
      abortRequest      : in  sl;
      cancelAck         : in  sl;
      admissionOpen     : out sl;
      drainIdle         : out sl;
      cancelRequest     : out sl;
      abortDone         : out sl;
      generation        : out slv(15 downto 0);
      faults            : out slv(2 downto 0);
      counters          : out slv(8*32-1 downto 0);
      sAxisTValid       : in  sl;
      sAxisTData        : in  slv(127 downto 0);
      sAxisTKeep        : in  slv(15 downto 0);
      sAxisTLast        : in  sl;
      sAxisTReady       : out sl;
      sAxisSof          : in  sl;
      sAxisEofe         : in  sl;
      txCookie          : in  slv(31 downto 0);
      txTimestamp       : in  sl;
      txFrameLength     : in  slv(15 downto 0);
      txGeneration      : in  slv(15 downto 0);
      cmplValid         : out sl;
      cmplData          : out slv(PTP_MAC_PORT_TX_COMPLETION_BITS_C-1 downto 0);
      cmplReady         : in  sl;
      mAxisTValid       : out sl;
      mAxisTData        : out slv(127 downto 0);
      mAxisTKeep        : out slv(15 downto 0);
      mAxisTLast        : out sl;
      mAxisTId          : out slv(7 downto 0);
      mAxisTReady       : in  sl;
      mAxisSof          : out sl;
      mAxisEofe         : out sl;
      rxMeta            : out slv(PTP_MAC_PORT_RX_META_BITS_C-1 downto 0);
      rxInject          : in  sl;
      injXgmiiRxd       : in  slv(63 downto 0);
      injXgmiiRxc       : in  slv(7 downto 0);
      injGmiiRxd        : in  slv(7 downto 0);
      injGmiiRxDv       : in  sl;
      injGmiiRxEr       : in  sl;
      xgmiiTxd          : out slv(63 downto 0);
      xgmiiTxc          : out slv(7 downto 0);
      gmiiTxd           : out slv(7 downto 0);
      gmiiTxEn          : out sl;
      gmiiTxEr          : out sl;
      rxOracleSof       : out sl;
      rxOracleCapture   : out slv(PTP_RX_CAPTURE_BITS_C-1 downto 0);
      txOracleSof       : out sl;
      txOracleCapture   : out slv(PTP_RX_CAPTURE_BITS_C-1 downto 0));
end entity PtpPhcMacPortWrapper;

architecture mapping of PtpPhcMacPortWrapper is

   signal resetN         : sl;
   signal axiReadMaster  : AxiLiteReadMasterType;
   signal axiReadSlave   : AxiLiteReadSlaveType;
   signal axiWriteMaster : AxiLiteWriteMasterType;
   signal axiWriteSlave  : AxiLiteWriteSlaveType;
   signal commandMaster  : PtpPhcCommandMasterType;
   signal commandSlave   : PtpPhcCommandSlaveType;
   signal timeValue      : PtpTimeType;
   signal status         : PtpPhcStatusType;
   signal abortCapture   : sl;

begin

   resetN <= not rst;

   commandMaster.data.kind                <= commandKind;
   commandMaster.data.generation          <= commandGeneration;
   commandMaster.data.setTime.seconds     <= commandSeconds;
   commandMaster.data.setTime.nanoseconds <= commandNanoseconds;
   commandMaster.data.setTime.fraction    <= commandFraction;
   commandMaster.data.phaseSeconds        <= phaseSeconds;
   commandMaster.data.phaseFraction       <= phaseFraction;
   commandMaster.data.rate                <= commandRate;
   commandMaster.data.value               <= commandValue;
   commandMaster.valid                    <= commandValid;
   commandMaster.cancel                   <= '0';
   commandMaster.stale                    <= '0';

   commandReady   <= commandSlave.ready;
   commandAck     <= commandSlave.ack;
   commandError   <= commandSlave.error;
   phcSeconds     <= timeValue.seconds;
   phcNanoseconds <= timeValue.nanoseconds;
   phcFraction    <= timeValue.fraction;
   phcGeneration  <= status.generation;
   phcTicks       <= status.ticks;
   phcIncrement   <= status.increment;
   phcTimeValid   <= status.timeValid;
   captureAbort   <= abortCapture;
   statusAck      <= status.ack;
   discontinuity  <= status.discontinuity;

   U_Axi : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         ADDR_WIDTH    => 32,
         EN_ERROR_RESP => true,
         HAS_WSTRB     => 1,
         FREQ_HZ       => CLK_FREQ_G)
      port map (
         S_AXI_ACLK      => clk,             -- [in]
         S_AXI_ARESETN   => resetN,          -- [in]
         S_AXI_AWADDR    => axil_awaddr,     -- [in]
         S_AXI_AWPROT    => "000",           -- [in]
         S_AXI_AWVALID   => axil_awvalid,    -- [in]
         S_AXI_AWREADY   => axil_awready,    -- [out]
         S_AXI_WDATA     => axil_wdata,      -- [in]
         S_AXI_WSTRB     => axil_wstrb,      -- [in]
         S_AXI_WVALID    => axil_wvalid,     -- [in]
         S_AXI_WREADY    => axil_wready,     -- [out]
         S_AXI_BRESP     => axil_bresp,      -- [out]
         S_AXI_BVALID    => axil_bvalid,     -- [out]
         S_AXI_BREADY    => axil_bready,     -- [in]
         S_AXI_ARADDR    => axil_araddr,     -- [in]
         S_AXI_ARPROT    => "000",           -- [in]
         S_AXI_ARVALID   => axil_arvalid,    -- [in]
         S_AXI_ARREADY   => axil_arready,    -- [out]
         S_AXI_RDATA     => axil_rdata,      -- [out]
         S_AXI_RRESP     => axil_rresp,      -- [out]
         S_AXI_RVALID    => axil_rvalid,     -- [out]
         S_AXI_RREADY    => axil_rready,     -- [in]
         axilClk         => open,            -- [out]
         axilRst         => open,            -- [out]
         axilReadMaster  => axiReadMaster,   -- [out]
         axilReadSlave   => axiReadSlave,    -- [in]
         axilWriteMaster => axiWriteMaster,  -- [out]
         axilWriteSlave  => axiWriteSlave);  -- [in]

   U_Phc : entity surf.PtpPhcCore
      generic map (
         TPD_G      => TPD_G,
         CLK_FREQ_G => CLK_FREQ_G)
      port map (
         axiReadMaster  => axiReadMaster,   -- [in]
         axiReadSlave   => axiReadSlave,    -- [out]
         axiWriteMaster => axiWriteMaster,  -- [in]
         axiWriteSlave  => axiWriteSlave,   -- [out]
         clk            => clk,             -- [in]
         rst            => rst,             -- [in]
         commandMaster  => commandMaster,   -- [in]
         commandSlave   => commandSlave,    -- [out]
         externalOwner  => externalOwner,   -- [out]
         phcTime        => timeValue,       -- [out]
         phcStatus      => status,          -- [out]
         captureAbort   => abortCapture,    -- [out]
         pps            => open,            -- [out]
         irq            => open);           -- [out]

   U_Port : entity surf.PtpMacPortEthMacWrapper
      generic map (
         TPD_G      => TPD_G,
         PHY_TYPE_G => PHY_TYPE_G)
      port map (
         clk             => clk,                 -- [in]
         rst             => rst,                 -- [in]
         phcSeconds      => timeValue.seconds,   -- [in]
         phcNanoseconds  => timeValue.nanoseconds,  -- [in]
         phcFraction     => timeValue.fraction,  -- [in]
         phcGeneration   => status.generation,   -- [in]
         phcTicks        => status.ticks,        -- [in]
         phcIncrement    => status.increment,    -- [in]
         phcTimeValid    => status.timeValid,    -- [in]
         captureAbort    => abortCapture,        -- [in]
         phyReady        => phyReady,           -- [in]
         openAdmission   => openAdmission,      -- [in]
         drainRequest    => drainRequest,       -- [in]
         abortRequest    => abortRequest,       -- [in]
         cancelAck       => cancelAck,          -- [in]
         admissionOpen   => admissionOpen,      -- [out]
         drainIdle       => drainIdle,          -- [out]
         cancelRequest   => cancelRequest,      -- [out]
         abortDone       => abortDone,          -- [out]
         generation      => generation,         -- [out]
         faults          => faults,             -- [out]
         counters        => counters,           -- [out]
         sAxisTValid     => sAxisTValid,        -- [in]
         sAxisTData      => sAxisTData,         -- [in]
         sAxisTKeep      => sAxisTKeep,         -- [in]
         sAxisTLast      => sAxisTLast,         -- [in]
         sAxisTReady     => sAxisTReady,        -- [out]
         sAxisSof        => sAxisSof,           -- [in]
         sAxisEofe       => sAxisEofe,          -- [in]
         txCookie        => txCookie,           -- [in]
         txTimestamp     => txTimestamp,        -- [in]
         txFrameLength   => txFrameLength,      -- [in]
         txGeneration    => txGeneration,       -- [in]
         cmplValid       => cmplValid,          -- [out]
         cmplData        => cmplData,           -- [out]
         cmplReady       => cmplReady,          -- [in]
         mAxisTValid     => mAxisTValid,        -- [out]
         mAxisTData      => mAxisTData,         -- [out]
         mAxisTKeep      => mAxisTKeep,         -- [out]
         mAxisTLast      => mAxisTLast,         -- [out]
         mAxisTId        => mAxisTId,           -- [out]
         mAxisTReady     => mAxisTReady,        -- [in]
         mAxisSof        => mAxisSof,           -- [out]
         mAxisEofe       => mAxisEofe,          -- [out]
         rxMeta          => rxMeta,             -- [out]
         rxInject        => rxInject,           -- [in]
         injXgmiiRxd     => injXgmiiRxd,        -- [in]
         injXgmiiRxc     => injXgmiiRxc,        -- [in]
         injGmiiRxd      => injGmiiRxd,         -- [in]
         injGmiiRxDv     => injGmiiRxDv,        -- [in]
         injGmiiRxEr     => injGmiiRxEr,        -- [in]
         xgmiiTxd        => xgmiiTxd,           -- [out]
         xgmiiTxc        => xgmiiTxc,           -- [out]
         gmiiTxd         => gmiiTxd,            -- [out]
         gmiiTxEn        => gmiiTxEn,           -- [out]
         gmiiTxEr        => gmiiTxEr,           -- [out]
         rxOracleSof     => rxOracleSof,        -- [out]
         rxOracleCapture => rxOracleCapture,    -- [out]
         txOracleSof     => txOracleSof,        -- [out]
         txOracleCapture => txOracleCapture);   -- [out]

end architecture mapping;
