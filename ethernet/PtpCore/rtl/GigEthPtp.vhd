-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Common GMII MAC/PTP endpoint, Ethernet management and AXI-Lite CDC.
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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.EthMacPkg.all;
use surf.GigEthPkg.all;
use surf.PtpPkg.all;

entity GigEthPtp is
   generic (
      TPD_G             : time                 := 1 ns;
      AXIL_BASE_ADDR_G  : slv(31 downto 0)     := (others => '0');
      -- Relative offsets allow a board to retain an existing register map.
      ETH_OFFSET_G      : slv(31 downto 0)     := x"00000000";
      PTP_OFFSET_G      : slv(31 downto 0)     := x"00008000";
      -- Timing-port bank (MAC_MODE_G = "TIMING_PORT" only; 4 KiB).
      PORT_OFFSET_G     : slv(31 downto 0)     := x"00001000";
      COMMON_CLK_G      : boolean              := false;
      PACKET_LIFETIME_G : positive             := 125000000;
      FIFO_ADDR_WIDTH_G : positive             := 9;
      TLV_EN_G          : boolean              := true;
      MAX_FRAME_G       : PtpFrameCapacityType := PTP_ETH_MAX_FRAME_C;
      INGRESS_LATENCY_G : slv(63 downto 0)     := (others => '0');
      EGRESS_LATENCY_G  : slv(63 downto 0)     := (others => '0');
      CONTROL_MODE_G    : string               := "SELECTABLE";
      -- "TAPPED": EthMacPtpEndpoint (bypass MAC, passive taps, application
      -- stream). "TIMING_PORT": PtpMacPortEndpoint (timing-port MAC, PTP-only;
      -- application TX is accepted and discarded, no RX is presented).
      MAC_MODE_G        : string               := "TAPPED");
   port (
      -- Host management clock domain. Cross once before local bank decode.
      axilClk        : in  sl;
      axilRst        : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;

      -- Continuous full-rate GMII and PHC domain; application streams use it too.
      sysClk125      : in  sl;
      sysRst125      : in  sl;
      extRst         : in  sl := '0';  -- Port/PCS reset only; does not reset PHC.
      localMac       : in  slv(47 downto 0);
      sAxisMaster    : in  AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      sAxisSlave     : out AxiStreamSlaveType;
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType := AXI_STREAM_SLAVE_FORCE_C;
      phcTime        : out PtpTimeType;
      phcStatus      : out PtpPhcStatusType;
      pps            : out sl;
      irq            : out sl;
      portActive     : out sl;
      phyReady       : out sl;
      servoState     : out slv(2 downto 0);
      primaryDropped : out slv(31 downto 0);

      -- PHY adapter: GMII is synchronous to sysClk125. No MAC-side CDC here.
      coreRst    : out sl;
      coreConfig : out slv(4 downto 0);
      coreStatus : in  slv(15 downto 0);
      gmiiTxd    : out slv(7 downto 0);
      gmiiTxEn   : out sl;
      gmiiTxEr   : out sl;
      gmiiRxd    : in  slv(7 downto 0);
      gmiiRxDv   : in  sl;
      gmiiRxEr   : in  sl);
end entity GigEthPtp;

architecture rtl of GigEthPtp is

   constant TIMING_PORT_C : boolean := MAC_MODE_G = "TIMING_PORT";

   constant NUM_AXIL_MASTERS_C : positive := ite(TIMING_PORT_C, 3, 2);

   constant PHY_INDEX_C      : natural := 0;
   constant ENDPOINT_INDEX_C : natural := 1;
   constant PORT_INDEX_C     : natural := 2;

   -- Default aperture: Ethernet 4 KiB at +0, timing-port bank 4 KiB at
   -- +0x1000 (timing-port build only), endpoint 32 KiB at +0x8000. Parent
   -- allocation must enclose every bank if the offsets are overridden.
   constant ETH_BASE_C : slv(31 downto 0) :=
      slv(unsigned(AXIL_BASE_ADDR_G) + unsigned(ETH_OFFSET_G));
   constant PTP_BASE_C : slv(31 downto 0) :=
      slv(unsigned(AXIL_BASE_ADDR_G) + unsigned(PTP_OFFSET_G));
   constant PORT_BASE_C : slv(31 downto 0) :=
      slv(unsigned(AXIL_BASE_ADDR_G) + unsigned(PORT_OFFSET_G));

   function axilConfig return AxiLiteCrossbarMasterConfigArray is
      variable retVar : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0);
   begin
      retVar(PHY_INDEX_C)      := (baseAddr => ETH_BASE_C, addrBits => 12, connectivity => x"0001");
      retVar(ENDPOINT_INDEX_C) := (baseAddr => PTP_BASE_C, addrBits => 15, connectivity => x"0001");
      if TIMING_PORT_C then
         retVar(PORT_INDEX_C) := (baseAddr => PORT_BASE_C, addrBits => 12, connectivity => x"0001");
      end if;
      return retVar;
   end function axilConfig;

   constant AXIL_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := axilConfig;

   signal localReadMaster  : AxiLiteReadMasterType;
   signal localReadSlave   : AxiLiteReadSlaveType;
   signal localWriteMaster : AxiLiteWriteMasterType;
   signal localWriteSlave  : AxiLiteWriteSlaveType;
   signal readMasters      : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal readSlaves       : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal writeMasters     : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal writeSlaves      : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);

   signal config   : GigEthConfigType;
   signal status   : GigEthStatusType;
   signal phyReset : sl;
   signal pcsReset : sl;

begin

   assert unsigned(AXIL_BASE_ADDR_G) <= unsigned(not ETH_OFFSET_G) and
          unsigned(AXIL_BASE_ADDR_G) <= unsigned(not PTP_OFFSET_G)
      report "GigEthPtp address addition overflows" severity failure;
   assert ETH_BASE_C(11 downto 0) = (11 downto 0 => '0') and
          PTP_BASE_C(14 downto 0) = (14 downto 0 => '0')
      report "GigEthPtp requires 4 KiB Ethernet and 32 KiB PTP alignment" severity failure;
   assert ETH_BASE_C(31 downto 15) /= PTP_BASE_C(31 downto 15)
      report "GigEthPtp register banks overlap" severity failure;
   assert not TIMING_PORT_C or
          (unsigned(AXIL_BASE_ADDR_G) <= unsigned(not PORT_OFFSET_G) and
           PORT_BASE_C(11 downto 0) = (11 downto 0 => '0') and
           PORT_BASE_C(31 downto 12) /= ETH_BASE_C(31 downto 12) and
           PORT_BASE_C(31 downto 15) /= PTP_BASE_C(31 downto 15))
      report "GigEthPtp timing-port bank must be 4 KiB aligned and clear of the other banks" severity failure;

   -- Cross complete transactions into the PHC domain before selecting a bank.
   U_Async : entity surf.AxiLiteAsync
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G)
      port map (
         sAxiClk         => axilClk,           -- [in]
         sAxiClkRst      => axilRst,           -- [in]
         sAxiReadMaster  => axiReadMaster,     -- [in]
         sAxiReadSlave   => axiReadSlave,      -- [out]
         sAxiWriteMaster => axiWriteMaster,    -- [in]
         sAxiWriteSlave  => axiWriteSlave,     -- [out]
         mAxiClk         => sysClk125,         -- [in]
         mAxiClkRst      => sysRst125,         -- [in]
         mAxiReadMaster  => localReadMaster,   -- [out]
         mAxiReadSlave   => localReadSlave,    -- [in]
         mAxiWriteMaster => localWriteMaster,  -- [out]
         mAxiWriteSlave  => localWriteSlave);  -- [in]

   U_Crossbar : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => AXIL_CONFIG_C)
      port map (
         axiClk              => sysClk125,         -- [in]
         axiClkRst           => sysRst125,         -- [in]
         sAxiReadMasters(0)  => localReadMaster,   -- [in]
         sAxiReadSlaves(0)   => localReadSlave,    -- [out]
         sAxiWriteMasters(0) => localWriteMaster,  -- [in]
         sAxiWriteSlaves(0)  => localWriteSlave,   -- [out]
         mAxiReadMasters     => readMasters,       -- [out]
         mAxiReadSlaves      => readSlaves,        -- [in]
         mAxiWriteMasters    => writeMasters,      -- [out]
         mAxiWriteSlaves     => writeSlaves);      -- [in]

   -- Reset-combining is intentional: the PCS needs asynchronous assertion.
   -- Soft reset/watchdog resets the PCS and flushes PTP association, but does
   -- not reset the PHC or MAC. Only sysRst125 clears the entire TX pipeline.
   pcsReset <= sysRst125 or extRst or config.softRst;

   U_PcsReset : entity surf.PwrUpRst
      generic map (
         TPD_G       => TPD_G,
         RST_ASYNC_G => true,  -- Assert even if oscillator programming stops sysClk125.
         DURATION_G  => 1000)
      port map (
         clk    => sysClk125,  -- [in]
         arst   => pcsReset,   -- [in]
         rstOut => phyReset);  -- [out]

   U_Registers : entity surf.GigEthReg
      generic map (
         TPD_G        => TPD_G,
         EN_AXI_REG_G => true)
      port map (
         clk            => sysClk125,                  -- [in]
         rst            => sysRst125,                  -- [in]
         localMac       => localMac,                   -- [in]
         axiReadMaster  => readMasters(PHY_INDEX_C),   -- [in]
         axiReadSlave   => readSlaves(PHY_INDEX_C),    -- [out]
         axiWriteMaster => writeMasters(PHY_INDEX_C),  -- [in]
         axiWriteSlave  => writeSlaves(PHY_INDEX_C),   -- [out]
         config         => config,                     -- [out]
         status         => status);                    -- [in]

   assert MAC_MODE_G = "TAPPED" or MAC_MODE_G = "TIMING_PORT"
      report "GigEthPtp: MAC_MODE_G must be TAPPED or TIMING_PORT" severity failure;

   GEN_TAPPED : if MAC_MODE_G = "TAPPED" generate

      U_Endpoint : entity surf.EthMacPtpEndpoint
         generic map (
            TPD_G             => TPD_G,
            AXIL_BASE_ADDR_G  => AXIL_CONFIG_C(ENDPOINT_INDEX_C).baseAddr,
            PHY_TYPE_G        => "GMII",
            CLK_FREQ_G        => 125000000,
            PACKET_LIFETIME_G => PACKET_LIFETIME_G,
            FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
            TLV_EN_G          => TLV_EN_G,
            MAX_FRAME_G       => MAX_FRAME_G,
            INGRESS_LATENCY_G => INGRESS_LATENCY_G,
            EGRESS_LATENCY_G  => EGRESS_LATENCY_G,
            CONTROL_MODE_G    => CONTROL_MODE_G)
         port map (
            clk            => sysClk125,                       -- [in]
            rst            => sysRst125,                       -- [in]
            portRst        => phyReset,                        -- [in]
            phyReady       => status.phyReady,                 -- [in]
            ethConfig      => config.macConfig,                -- [in]
            ethStatus      => status.macStatus,                -- [out]
            sAxisMaster    => sAxisMaster,                     -- [in]
            sAxisSlave     => sAxisSlave,                      -- [out]
            mAxisMaster    => mAxisMaster,                     -- [out]
            mAxisSlave     => mAxisSlave,                      -- [in]
            axiReadMaster  => readMasters(ENDPOINT_INDEX_C),   -- [in]
            axiReadSlave   => readSlaves(ENDPOINT_INDEX_C),    -- [out]
            axiWriteMaster => writeMasters(ENDPOINT_INDEX_C),  -- [in]
            axiWriteSlave  => writeSlaves(ENDPOINT_INDEX_C),   -- [out]
            xgmiiTxd       => open,                            -- [out]
            xgmiiTxc       => open,                            -- [out]
            gmiiRxd        => gmiiRxd,                         -- [in]
            gmiiRxDv       => gmiiRxDv,                        -- [in]
            gmiiRxEr       => gmiiRxEr,                        -- [in]
            gmiiTxd        => gmiiTxd,                         -- [out]
            gmiiTxEn       => gmiiTxEn,                        -- [out]
            gmiiTxEr       => gmiiTxEr,                        -- [out]
            phcTime        => phcTime,                         -- [out]
            phcStatus      => phcStatus,                       -- [out]
            pps            => pps,                             -- [out]
            irq            => irq,                             -- [out]
            portActive     => portActive,                      -- [out]
            servoState     => servoState,                      -- [out]
            primaryDropped => primaryDropped);                 -- [out]

   end generate GEN_TAPPED;

   GEN_TIMING_PORT : if MAC_MODE_G = "TIMING_PORT" generate

      -- PTP-only port: discard application TX, present no application RX.
      sAxisSlave     <= AXI_STREAM_SLAVE_FORCE_C;
      mAxisMaster    <= AXI_STREAM_MASTER_INIT_C;
      primaryDropped <= (others => '0');

      U_Endpoint : entity surf.PtpMacPortEndpoint
         generic map (
            TPD_G             => TPD_G,
            AXIL_BASE_ADDR_G  => AXIL_CONFIG_C(ENDPOINT_INDEX_C).baseAddr,
            PHY_TYPE_G        => "GMII",
            CLK_FREQ_G        => 125000000,
            PACKET_LIFETIME_G => PACKET_LIFETIME_G,
            TLV_EN_G          => TLV_EN_G,
            MAX_FRAME_G       => MAX_FRAME_G,
            INGRESS_LATENCY_G => INGRESS_LATENCY_G,
            EGRESS_LATENCY_G  => EGRESS_LATENCY_G,
            CONTROL_MODE_G    => CONTROL_MODE_G)
         port map (
            clk            => sysClk125,                       -- [in]
            rst            => sysRst125,                       -- [in]
            portRst        => phyReset,                        -- [in]
            phyReady       => status.phyReady,                 -- [in]
            ethConfig      => config.macConfig,                -- [in]
            ethStatus      => status.macStatus,                -- [out]
            axiReadMaster  => readMasters(ENDPOINT_INDEX_C),   -- [in]
            axiReadSlave   => readSlaves(ENDPOINT_INDEX_C),    -- [out]
            axiWriteMaster => writeMasters(ENDPOINT_INDEX_C),  -- [in]
            axiWriteSlave  => writeSlaves(ENDPOINT_INDEX_C),   -- [out]
            portAxiReadMaster  => readMasters(PORT_INDEX_C),   -- [in]
            portAxiReadSlave   => readSlaves(PORT_INDEX_C),    -- [out]
            portAxiWriteMaster => writeMasters(PORT_INDEX_C),  -- [in]
            portAxiWriteSlave  => writeSlaves(PORT_INDEX_C),   -- [out]
            xgmiiTxd       => open,                            -- [out]
            xgmiiTxc       => open,                            -- [out]
            gmiiRxd        => gmiiRxd,                         -- [in]
            gmiiRxDv       => gmiiRxDv,                        -- [in]
            gmiiRxEr       => gmiiRxEr,                        -- [in]
            gmiiTxd        => gmiiTxd,                         -- [out]
            gmiiTxEn       => gmiiTxEn,                        -- [out]
            gmiiTxEr       => gmiiTxEr,                        -- [out]
            phcTime        => phcTime,                         -- [out]
            phcStatus      => phcStatus,                       -- [out]
            pps            => pps,                             -- [out]
            irq            => irq,                             -- [out]
            portActive     => portActive,                      -- [out]
            servoState     => servoState,                      -- [out]
            portStatus     => open,                            -- [out]
            portCounters   => open);                           -- [out]

   end generate GEN_TIMING_PORT;

   -- These are structural connections, not additional registered boundaries.
   coreRst           <= phyReset;
   coreConfig        <= config.coreConfig;
   status.coreStatus <= coreStatus;
   status.phyReady   <= coreStatus(1);
   phyReady          <= status.phyReady;

end architecture rtl;
