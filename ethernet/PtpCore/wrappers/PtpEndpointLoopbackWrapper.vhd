-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Physical and AXI-Lite verification fixture for the PTP
-- endpoint.
--
-- With MAC_ENABLE_G set, instantiates EthMacPtpEndpoint and exposes
-- GMII/XGMII, primary application traffic, pause control and flattened
-- AXI-Lite channels. Tests can observe PHC time/status, PPS and servo state
-- while an independent Python master drives packet traffic. System, port and
-- register resets remain separately controllable.
--
-- With MAC_ENABLE_G clear, instantiates the same production endpoint and
-- physical capture/validation modules but connects the Delay_Req stream to a
-- Python MAC/wire encoder through the model ports. This accelerates
-- closed-loop tests while preserving protocol association, timestamp
-- observation, arithmetic and servo behavior. Separate real-MAC tests cover
-- MAC arbitration, pause and queued-frame lifetime.
--
-- The wrapper supplies record adaptation and the selected integration
-- topology. Packet stimulus, simulated master time, wire encoding in model
-- mode and scoreboards live in cocotb; despite its name, the wrapper does not
-- internally loop TX bytes back to RX.
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
use surf.AxiStreamPkg.all;
use surf.EthMacPkg.all;
use surf.PtpPkg.all;

entity PtpEndpointLoopbackWrapper is
   generic (
      MAC_ENABLE_G      : boolean  := true;
      PHY_TYPE_G        : string   := "XGMII";
      CLK_FREQ_G        : positive := 156250000;
      PACKET_LIFETIME_G : positive := 10000);
   port (
      clk                : in  sl;
      rst                : in  sl;
      portRst            : in  sl                := '0';
      regRst             : in  sl                := '0';
      phyReady           : in  sl;
      localMac           : in  slv(47 downto 0);
      pauseEnable        : in  sl                := '0';
      xgmiiRxd           : in  slv(63 downto 0)  := (others => '0');
      xgmiiRxc           : in  slv(7 downto 0)   := (others => '1');
      xgmiiTxd           : out slv(63 downto 0);
      xgmiiTxc           : out slv(7 downto 0);
      gmiiRxd            : in  slv(7 downto 0)   := (others => '0');
      gmiiRxDv           : in  sl                := '0';
      gmiiRxEr           : in  sl                := '0';
      gmiiTxd            : out slv(7 downto 0);
      gmiiTxEn           : out sl;
      gmiiTxEr           : out sl;
      sAxisTValid        : in  sl                := '0';
      sAxisTReady        : out sl;
      sAxisTData         : in  slv(127 downto 0) := (others => '0');
      sAxisTKeep         : in  slv(15 downto 0)  := (others => '0');
      sAxisTLast         : in  sl                := '0';
      sAxisSof           : in  sl                := '0';
      sAxisEofe          : in  sl                := '0';
      sAxisTDest         : in  slv(7 downto 0)   := (others => '0');
      mAxisTValid        : out sl;
      mAxisTReady        : in  sl                := '1';
      mAxisTData         : out slv(127 downto 0);
      mAxisTKeep         : out slv(15 downto 0);
      mAxisTLast         : out sl;
      mAxisSof           : out sl;
      mAxisEofe          : out sl;
      mAxisTDest         : out slv(7 downto 0);
      axil_awaddr        : in  slv(11 downto 0);
      axil_awvalid       : in  sl;
      axil_awready       : out sl;
      axil_wdata         : in  slv(31 downto 0);
      axil_wstrb         : in  slv(3 downto 0);
      axil_wvalid        : in  sl;
      axil_wready        : out sl;
      axil_bresp         : out slv(1 downto 0);
      axil_bvalid        : out sl;
      axil_bready        : in  sl;
      axil_araddr        : in  slv(11 downto 0);
      axil_arvalid       : in  sl;
      axil_arready       : out sl;
      axil_rdata         : out slv(31 downto 0);
      axil_rresp         : out slv(1 downto 0);
      axil_rvalid        : out sl;
      axil_rready        : in  sl;
      timeSeconds        : out slv(47 downto 0);
      timeNanoseconds    : out slv(31 downto 0);
      timeFraction       : out slv(31 downto 0);
      timeTicks          : out slv(63 downto 0);
      timeGeneration     : out slv(31 downto 0);
      timeIncrement      : out slv(63 downto 0);
      timeValid          : out sl;
      timeFault          : out sl;
      timeDiscontinuity  : out sl;
      pps                : out sl;
      irq                : out sl;
      portActive         : out sl;
      servoState         : out slv(2 downto 0);
      modelXgmiiTxd      : in  slv(63 downto 0)  := (others => '0');
      modelXgmiiTxc      : in  slv(7 downto 0)   := (others => '1');
      modelGmiiTxd       : in  slv(7 downto 0)   := (others => '0');
      modelGmiiTxEn      : in  sl                := '0';
      modelTxValid       : out sl;
      modelTxReady       : in  sl                := '1';
      modelTxData        : out slv(63 downto 0);
      modelTxKeep        : out slv(7 downto 0);
      modelTxLast        : out sl;
      modelTxSof         : out sl;
      primaryDropped     : out slv(31 downto 0));
end entity PtpEndpointLoopbackWrapper;

architecture rtl of PtpEndpointLoopbackWrapper is

   signal readMaster  : AxiLiteReadMasterType;
   signal readSlave   : AxiLiteReadSlaveType;
   signal writeMaster : AxiLiteWriteMasterType;
   signal writeSlave  : AxiLiteWriteSlaveType;
   signal config      : EthMacConfigType := ETH_MAC_CONFIG_INIT_C;
   signal sMaster     : AxiStreamMasterType;
   signal sSlave      : AxiStreamSlaveType;
   signal mMaster     : AxiStreamMasterType;
   signal mSlave      : AxiStreamSlaveType;
   signal timeValue   : PtpTimeType;
   signal status      : PtpPhcStatusType;
   signal resetN      : sl;

begin

   resetN             <= not rst;
   config.macAddress  <= localMac;
   config.pauseEnable <= pauseEnable;
   config.filtEnable  <= '0';
   config.ipCsumEn    <= '0';
   config.tcpCsumEn   <= '0';
   config.udpCsumEn   <= '0';

   U_Axi : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         ADDR_WIDTH    => 12,
         EN_ERROR_RESP => true,
         HAS_WSTRB     => 1,
         FREQ_HZ       => CLK_FREQ_G)
      port map (
         S_AXI_ACLK      => clk,           -- [in]
         S_AXI_ARESETN   => resetN,        -- [in]
         S_AXI_AWADDR    => axil_awaddr,   -- [in]
         S_AXI_AWPROT    => "000",         -- [in]
         S_AXI_AWVALID   => axil_awvalid,  -- [in]
         S_AXI_AWREADY   => axil_awready,  -- [out]
         S_AXI_WDATA     => axil_wdata,    -- [in]
         S_AXI_WSTRB     => axil_wstrb,    -- [in]
         S_AXI_WVALID    => axil_wvalid,   -- [in]
         S_AXI_WREADY    => axil_wready,   -- [out]
         S_AXI_BRESP     => axil_bresp,    -- [out]
         S_AXI_BVALID    => axil_bvalid,   -- [out]
         S_AXI_BREADY    => axil_bready,   -- [in]
         S_AXI_ARADDR    => axil_araddr,   -- [in]
         S_AXI_ARPROT    => "000",         -- [in]
         S_AXI_ARVALID   => axil_arvalid,  -- [in]
         S_AXI_ARREADY   => axil_arready,  -- [out]
         S_AXI_RDATA     => axil_rdata,    -- [out]
         S_AXI_RRESP     => axil_rresp,    -- [out]
         S_AXI_RVALID    => axil_rvalid,   -- [out]
         S_AXI_RREADY    => axil_rready,   -- [in]
         axilClk         => open,          -- [out]
         axilRst         => open,          -- [out]
         axilReadMaster  => readMaster,    -- [out]
         axilReadSlave   => readSlave,     -- [in]
         axilWriteMaster => writeMaster,   -- [out]
         axilWriteSlave  => writeSlave);   -- [in]

   comb : process (sAxisTValid, sAxisTData, sAxisTKeep, sAxisTLast, sAxisSof, sAxisEofe, sAxisTDest) is
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
      sMaster               <= v;
   end process comb;
   sAxisTReady   <= sSlave.tReady;
   mSlave.tReady <= mAxisTReady;
   mAxisTValid   <= mMaster.tValid;
   mAxisTData    <= mMaster.tData(127 downto 0);
   mAxisTKeep    <= mMaster.tKeep(15 downto 0);
   mAxisTLast    <= mMaster.tLast;
   mAxisTDest    <= mMaster.tDest(7 downto 0);
   mAxisSof      <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mMaster, EMAC_SOF_BIT_C, 0);
   mAxisEofe     <= axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, mMaster, EMAC_EOFE_BIT_C);
   GEN_MAC : if MAC_ENABLE_G generate

      U_DUT : entity surf.EthMacPtpEndpoint
         generic map (
            PHY_TYPE_G        => PHY_TYPE_G,
            CLK_FREQ_G        => CLK_FREQ_G,
            PACKET_LIFETIME_G => PACKET_LIFETIME_G)
         port map (
            clk            => clk,              -- [in]
            rst            => rst,              -- [in]
            portRst        => portRst,          -- [in]
            regRst         => regRst,           -- [in]
            phyReady       => phyReady,         -- [in]
            ethConfig      => config,           -- [in]
            ethStatus      => open,             -- [out]
            sAxisMaster    => sMaster,          -- [in]
            sAxisSlave     => sSlave,           -- [out]
            mAxisMaster    => mMaster,          -- [out]
            mAxisSlave     => mSlave,           -- [in]
            axiReadMaster  => readMaster,       -- [in]
            axiReadSlave   => readSlave,        -- [out]
            axiWriteMaster => writeMaster,      -- [in]
            axiWriteSlave  => writeSlave,       -- [out]
            xgmiiRxd       => xgmiiRxd,         -- [in]
            xgmiiRxc       => xgmiiRxc,         -- [in]
            xgmiiTxd       => xgmiiTxd,         -- [out]
            xgmiiTxc       => xgmiiTxc,         -- [out]
            gmiiRxd        => gmiiRxd,          -- [in]
            gmiiRxDv       => gmiiRxDv,         -- [in]
            gmiiRxEr       => gmiiRxEr,         -- [in]
            gmiiTxd        => gmiiTxd,          -- [out]
            gmiiTxEn       => gmiiTxEn,         -- [out]
            gmiiTxEr       => gmiiTxEr,         -- [out]
            phcTime        => timeValue,        -- [out]
            phcStatus      => status,           -- [out]
            pps            => pps,              -- [out]
            irq            => irq,              -- [out]
            portActive     => portActive,       -- [out]
            servoState     => servoState,       -- [out]
            primaryDropped => primaryDropped);  -- [out]

      modelTxValid <= '0';
      modelTxData  <= (others => '0');
      modelTxKeep  <= (others => '0');
      modelTxLast  <= '0';
      modelTxSof   <= '0';
   end generate GEN_MAC;
   -- The fast fixture replaces only the MAC with an independent Python wire
   -- encoder. PHC, RX validation, TX observation, port, arithmetic and servo are
   -- the same production entities. Separate runs select the real MAC above.
   GEN_MODEL : if not MAC_ENABLE_G generate
      signal normalized      : AxiStreamMasterType;
      signal capture         : PtpRxCaptureType;
      signal rxMessage       : PtpRxMessageType;
      signal rxValid         : sl;
      signal rxReady         : sl;
      signal rxQueueOverflow : sl;
      signal rxAbort         : sl;
      signal flush           : sl;
      signal captureAbort    : sl;
      signal rxCounters      : Slv32Array(0 to 2);
      signal txMessage       : PtpRxMessageType;
      signal txValid         : sl;
      signal txAbort         : sl;
      signal txMaster        : AxiStreamMasterType;
      signal txSlave         : AxiStreamSlaveType;

   begin
      mMaster        <= AXI_STREAM_MASTER_INIT_C;
      sSlave         <= AXI_STREAM_SLAVE_FORCE_C;
      primaryDropped <= (others => '0');
      xgmiiTxd       <= modelXgmiiTxd;
      xgmiiTxc       <= modelXgmiiTxc;
      gmiiTxd        <= modelGmiiTxd;
      gmiiTxEn       <= modelGmiiTxEn;
      gmiiTxEr       <= '0';
      modelTxValid   <= txMaster.tValid;
      modelTxData    <= txMaster.tData(63 downto 0);
      modelTxKeep    <= txMaster.tKeep(7 downto 0);
      modelTxLast    <= txMaster.tLast;
      modelTxSof     <= axiStreamGetUserBit(PTP_RX_AXIS_CONFIG_C, txMaster, EMAC_SOF_BIT_C, 0);
      txSlave.tReady <= modelTxReady;

      U_Adapter : entity surf.PtpRxTimestampAdapter
         generic map (
            PHY_TYPE_G => PHY_TYPE_G)
         port map (
            clk          => clk,                -- [in]
            rst          => rst,                -- [in]
            rxFlush      => flush,              -- [in]
            phyReady     => phyReady,           -- [in]
            generation   => status.generation,  -- [in]
            phcTime      => timeValue,          -- [in]
            phcIncrement => status.increment,   -- [in]
            tickCount    => status.ticks,       -- [in]
            timeValid    => status.timeValid,   -- [in]
            xgmiiRxd     => xgmiiRxd,           -- [in]
            xgmiiRxc     => xgmiiRxc,           -- [in]
            gmiiRxd      => gmiiRxd,            -- [in]
            gmiiRxDv     => gmiiRxDv,           -- [in]
            gmiiRxEr     => gmiiRxEr,           -- [in]
            rxMaster     => normalized,         -- [out]
            rxCapture    => capture);           -- [out]

      U_Rx : entity surf.PtpRxFrontend
         port map (
            clk           => clk,                -- [in]
            rst           => rst,                -- [in]
            rxFlush       => flush,              -- [in]
            generation    => status.generation,  -- [in]
            rxMaster      => normalized,         -- [in]
            rxCapture     => capture,            -- [in]
            message       => rxMessage,          -- [out]
            messageValid  => rxValid,            -- [out]
            messageReady  => rxReady,            -- [in]
            rxAbort       => rxAbort,            -- [out]
            queueOverflow => rxQueueOverflow,    -- [out]
            rxEpoch       => open,               -- [out]
            acceptedCount => rxCounters(0),      -- [out]
            droppedCount  => rxCounters(1),      -- [out]
            overflowCount => rxCounters(2));     -- [out]

      U_Tx : entity surf.PtpTxTimestampTap
         generic map (
            PHY_TYPE_G => PHY_TYPE_G)
         port map (
            clk             => clk,            -- [in]
            rst             => rst,            -- [in]
            phyReady        => phyReady,       -- [in]
            phcTime         => timeValue,      -- [in]
            phcStatus       => status,         -- [in]
            captureAbort    => captureAbort,   -- [in]
            xgmiiTxd        => modelXgmiiTxd,  -- [in]
            xgmiiTxc        => modelXgmiiTxc,  -- [in]
            gmiiTxd         => modelGmiiTxd,   -- [in]
            gmiiTxEn        => modelGmiiTxEn,  -- [in]
            gmiiTxEr        => '0',            -- [in]
            completion      => txMessage,      -- [out]
            completionValid => txValid,        -- [out]
            completionReady => '1',            -- [in]
            completionAbort => txAbort);       -- [out]

      U_DUT : entity surf.PtpEndpoint
         generic map (
            CLK_FREQ_G        => CLK_FREQ_G,
            PACKET_LIFETIME_G => PACKET_LIFETIME_G)
         port map (
            clk             => clk,              -- [in]
            rst             => rst,              -- [in]
            regRst          => regRst,           -- [in]
            portRst         => portRst,          -- [in]
            linkReady       => phyReady,         -- [in]
            macResetDone    => resetN,           -- [in]
            localMac        => localMac,         -- [in]
            axiReadMaster   => readMaster,       -- [in]
            axiReadSlave    => readSlave,        -- [out]
            axiWriteMaster  => writeMaster,      -- [in]
            axiWriteSlave   => writeSlave,       -- [out]
            rxMessage       => rxMessage,        -- [in]
            rxValid         => rxValid,          -- [in]
            rxReady         => rxReady,          -- [out]
            rxAbort         => rxAbort,          -- [in]
            rxQueueOverflow => rxQueueOverflow,  -- [in]
            rxCounters      => rxCounters,       -- [in]
            txMessage       => txMessage,        -- [in]
            txValid         => txValid,          -- [in]
            txAbort         => txAbort,          -- [in]
            txMaster        => txMaster,         -- [out]
            txSlave         => txSlave,          -- [in]
            phcTime         => timeValue,        -- [out]
            phcStatus       => status,           -- [out]
            captureAbort    => captureAbort,     -- [out]
            rxFlush         => flush,            -- [out]
            pps             => pps,              -- [out]
            irq             => irq,              -- [out]
            portActive      => portActive,       -- [out]
            servoState      => servoState);      -- [out]

   end generate GEN_MODEL;
   timeSeconds       <= timeValue.seconds;
   timeNanoseconds   <= timeValue.nanoseconds;
   timeFraction      <= timeValue.fraction;
   timeTicks         <= status.ticks;
   timeGeneration    <= status.generation;
   timeIncrement     <= status.increment;
   timeValid         <= status.timeValid;
   timeFault         <= status.fault;
   timeDiscontinuity <= status.discontinuity;

end architecture rtl;
