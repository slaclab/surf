-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Shared PTP hardware clock subsystem: PtpPhc and its control.
--
-- One upstream AXI-Lite interface, an optional AxiLiteAsync crossing from an
-- independent management clock, and a local crossbar: PtpPhcControl at
-- 0x0000 and the PtpPhc bank at 0x1000 in an 8 KiB aperture. A private
-- one-client PtpSecondService normalizes manual PHASE commands; the core has
-- no protocol engine, servo or variable divider.
--
-- CONTROL_MODE_G selects the command sources at elaboration: "AXI" (manual
-- steering only), "EXTERNAL" (external client only; the manual operand path
-- and private SECOND converter are omitted) or "SELECTABLE" (both, with a
-- committed runtime owner that changes only at a drained command boundary).
-- Admission is gated at the owner, which externalOwner reports. AXI PPS
-- control remains available in every mode. Standalone, the
-- control bank coordinates commits and snapshots; with EXT_COORDINATION_G an
-- enclosing coordinator's records reach both participants on the same edges
-- as its other banks, and this core returns its prepare/validity/snapshot
-- handshakes. clearValid revokes qualification only for the owning client.
--
-- The live phcTime/phcStatus/captureAbort tuple, commands and coordination
-- records stay in clk; only AXI-Lite crosses domains. regRst and axilRst cancel
-- bus state only: with a crossing, axilRst is synchronized into clk and resets
-- the crossbar and bank responses with regRst, so a transaction abandoned by
-- the crossing cannot leave downstream bus state waiting. restart and commandAbort cancel external work only. System
-- reset clears the clock and must also reset its capture/transport consumers.
-- Contract and register map: ethernet/PtpCore/phc.md.
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
use surf.PtpMathPkg.all;
use surf.AxiLitePkg.all;
use surf.PtpPkg.all;

entity PtpPhcCore is
   generic (
      TPD_G              : time             := 1 ns;
      RST_POLARITY_G     : sl               := '1';
      RST_ASYNC_G        : boolean          := false;
      AXIL_BASE_ADDR_G   : slv(31 downto 0) := (others => '0');
      CLK_FREQ_G         : positive         := 156250000;
      COMMON_CLK_G       : boolean          := true;
      -- "AXI": fixed software steering, no external client. "EXTERNAL": fixed
      -- external client, no manual SET/PHASE/RATE/VALID path or private SECOND
      -- converter. "SELECTABLE": both, with a committed runtime owner.
      CONTROL_MODE_G     : string           := "SELECTABLE";
      EXT_COORDINATION_G : boolean          := false);
   port (
      -- Management clock domain, used only when COMMON_CLK_G = false.
      -- axilRst is active high, like the AXI-only reset it crosses into.
      axilClk        : in  sl := '0';
      axilRst        : in  sl := '0';
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;

      -- PHC clock domain and lifecycle
      clk          : in  sl;
      rst          : in  sl;
      regRst       : in  sl := '0';
      restart      : in  sl := '0';
      commandAbort : in  sl := '0';

      -- External command client and its qualification revocation
      commandMaster : in  PtpPhcCommandMasterType := PTP_PHC_COMMAND_MASTER_INIT_C;
      commandSlave  : out PtpPhcCommandSlaveType;
      clearValid    : in  sl                      := '0';
      externalOwner : out sl;

      -- Enclosing coordinator, used only when EXT_COORDINATION_G = true
      configControl    : in  PtpConfigControlType   := PTP_CONFIG_CONTROL_INIT_C;
      snapshotControl  : in  PtpSnapshotControlType := PTP_SNAPSHOT_CONTROL_INIT_C;
      configPrepared   : out sl;
      configValid      : out sl;
      snapshotPrepared : out sl;
      manualBusy       : out sl;

      -- Live clock tuple, PPS and interrupt
      phcTime      : out PtpTimeType;
      phcStatus    : out PtpPhcStatusType;
      captureAbort : out sl;
      pps          : out sl;
      irq          : out sl);
end entity PtpPhcCore;

architecture mapping of PtpPhcCore is

   constant MANUAL_EN_C   : boolean := CONTROL_MODE_G /= "EXTERNAL";
   constant EXTERNAL_EN_C : boolean := CONTROL_MODE_G /= "AXI";

   constant NUM_AXIL_MASTERS_C   : positive := 2;
   constant CONTROL_AXIL_INDEX_C : natural  := 0;
   constant PHC_AXIL_INDEX_C     : natural  := 1;
   constant AXIL_APERTURE_BITS_C : positive := 13;  -- 8 KiB core.
   constant AXIL_BANK_BITS_C     : positive := 12;  -- 4 KiB per bank.
   constant AXIL_CONFIG_C        : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) :=
      genAxiLiteConfig(NUM_AXIL_MASTERS_C, AXIL_BASE_ADDR_G, AXIL_APERTURE_BITS_C, AXIL_BANK_BITS_C);

   signal axiReset        : sl;
   signal busRst          : sl;
   signal syncReadMaster  : AxiLiteReadMasterType;
   signal syncReadSlave   : AxiLiteReadSlaveType;
   signal syncWriteMaster : AxiLiteWriteMasterType;
   signal syncWriteSlave  : AxiLiteWriteSlaveType;
   signal readMasters     : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal readSlaves      : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal writeMasters    : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal writeSlaves     : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);

   signal localConfigControl    : PtpConfigControlType;
   signal localSnapshotControl  : PtpSnapshotControlType;
   signal activeConfigControl   : PtpConfigControlType;
   signal activeSnapshotControl : PtpSnapshotControlType;
   signal ownerExternal         : sl;
   signal phcManualBusy         : sl;
   signal phcCommandIdle        : sl;
   signal phcSnapshotPrepared   : sl;
   signal timeValue             : PtpTimeType;
   signal status                : PtpPhcStatusType;
   signal abortCapture          : sl;
   signal externalMaster        : PtpPhcCommandMasterType;
   signal externalSlave         : PtpPhcCommandSlaveType;

   signal secondReady       : slv(0 downto 0);
   signal secondCancel      : slv(0 downto 0);
   signal secondResultReady : slv(0 downto 0);
   signal secondRequests    : PtpConstDivideRequestArray(1-1 downto 0)(operand(128-1 downto 0));
   signal secondResults     : PtpConstDivideResultArray(1-1 downto 0)(value(128-1 downto 0), remainder(128-1 downto 0));

begin

   assert AXIL_BASE_ADDR_G(AXIL_APERTURE_BITS_C-1 downto 0) = toSlv(0, AXIL_APERTURE_BITS_C)
      report "PtpPhcCore: AXI-Lite base address must be 8 KiB aligned" severity failure;
   assert CONTROL_MODE_G = "AXI" or CONTROL_MODE_G = "EXTERNAL" or CONTROL_MODE_G = "SELECTABLE"
      report "PtpPhcCore: CONTROL_MODE_G must be AXI, EXTERNAL or SELECTABLE" severity failure;

   -- AXI-only bus reset in clk: regRst, plus the management reset when the
   -- bus crosses from axilClk. RstSync asserts asynchronously and releases on
   -- clk, so a management reset always reaches the crossbar and both banks.
   -- It clears bus state only; time, owner and accepted commands continue.
   GEN_COMMON_BUS_RST : if COMMON_CLK_G generate
      busRst <= regRst;
   end generate GEN_COMMON_BUS_RST;

   GEN_ASYNC_BUS_RST : if not COMMON_CLK_G generate
      signal axilRstSync : sl;
   begin

      U_AxilRstSync : entity surf.RstSync
         generic map (
            TPD_G          => TPD_G,
            IN_POLARITY_G  => '1',
            OUT_POLARITY_G => '1')
         port map (
            clk      => clk,           -- [in]
            asyncRst => axilRst,       -- [in]
            syncRst  => axilRstSync);  -- [out]

      busRst <= regRst or axilRstSync;

   end generate GEN_ASYNC_BUS_RST;

   -- Bus reset is combinational, as in the endpoint coordinator: system or
   -- AXI-only reset clears bus state without touching the clock.
   axiReset <= toSl(rst = RST_POLARITY_G) or busRst;

   -- Structural forwarding preserves each child's registered boundary.
   phcTime          <= timeValue;
   phcStatus        <= status;
   captureAbort     <= abortCapture;
   externalOwner    <= ownerExternal;
   manualBusy       <= phcManualBusy;
   snapshotPrepared <= phcSnapshotPrepared;

   U_Async : entity surf.AxiLiteAsync
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         COMMON_CLK_G   => COMMON_CLK_G)
      port map (
         sAxiClk         => axilClk,          -- [in]
         sAxiClkRst      => axilRst,          -- [in]
         sAxiReadMaster  => axiReadMaster,    -- [in]
         sAxiReadSlave   => axiReadSlave,     -- [out]
         sAxiWriteMaster => axiWriteMaster,   -- [in]
         sAxiWriteSlave  => axiWriteSlave,    -- [out]
         mAxiClk         => clk,              -- [in]
         mAxiClkRst      => axiReset,         -- [in]
         mAxiReadMaster  => syncReadMaster,   -- [out]
         mAxiReadSlave   => syncReadSlave,    -- [in]
         mAxiWriteMaster => syncWriteMaster,  -- [out]
         mAxiWriteSlave  => syncWriteSlave);  -- [in]

   U_Xbar : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => AXIL_CONFIG_C)
      port map (
         axiClk              => clk,              -- [in]
         axiClkRst           => axiReset,         -- [in]
         sAxiWriteMasters(0) => syncWriteMaster,  -- [in]
         sAxiWriteSlaves(0)  => syncWriteSlave,   -- [out]
         sAxiReadMasters(0)  => syncReadMaster,   -- [in]
         sAxiReadSlaves(0)   => syncReadSlave,    -- [out]
         mAxiWriteMasters    => writeMasters,     -- [out]
         mAxiWriteSlaves     => writeSlaves,      -- [in]
         mAxiReadMasters     => readMasters,      -- [out]
         mAxiReadSlaves      => readSlaves);      -- [in]

   -- One coordinator drives the participant strobes: the enclosing one, or
   -- the local control bank.
   GEN_LOCAL_COORDINATION : if not EXT_COORDINATION_G generate
      activeConfigControl   <= localConfigControl;
      activeSnapshotControl <= localSnapshotControl;
   end generate GEN_LOCAL_COORDINATION;

   GEN_EXT_COORDINATION : if EXT_COORDINATION_G generate
      activeConfigControl   <= configControl;
      activeSnapshotControl <= snapshotControl;
   end generate GEN_EXT_COORDINATION;

   -- A compiled-out external client is tied idle and never admitted.
   GEN_EXT_COMMAND : if EXTERNAL_EN_C generate
      externalMaster <= commandMaster;
      commandSlave   <= externalSlave;
   end generate GEN_EXT_COMMAND;

   GEN_NO_EXT_COMMAND : if not EXTERNAL_EN_C generate
      externalMaster <= PTP_PHC_COMMAND_MASTER_INIT_C;
      commandSlave   <= PTP_PHC_COMMAND_SLAVE_INIT_C;
   end generate GEN_NO_EXT_COMMAND;

   U_Control : entity surf.PtpPhcControl
      generic map (
         TPD_G              => TPD_G,
         RST_POLARITY_G     => RST_POLARITY_G,
         RST_ASYNC_G        => RST_ASYNC_G,
         COMMON_CLK_G       => COMMON_CLK_G,
         CONTROL_MODE_G     => CONTROL_MODE_G,
         EXT_COORDINATION_G => EXT_COORDINATION_G)
      port map (
         clk                  => clk,                                 -- [in]
         rst                  => rst,                                 -- [in]
         regRst               => busRst,                              -- [in]
         axiReadMaster        => readMasters(CONTROL_AXIL_INDEX_C),   -- [in]
         axiReadSlave         => readSlaves(CONTROL_AXIL_INDEX_C),    -- [out]
         axiWriteMaster       => writeMasters(CONTROL_AXIL_INDEX_C),  -- [in]
         axiWriteSlave        => writeSlaves(CONTROL_AXIL_INDEX_C),   -- [out]
         localConfigControl   => localConfigControl,                  -- [out]
         localSnapshotControl => localSnapshotControl,                -- [out]
         configControl        => activeConfigControl,                 -- [in]
         snapshotControl      => activeSnapshotControl,               -- [in]
         configPrepared       => configPrepared,                      -- [out]
         configValid          => configValid,                         -- [out]
         commandIdle          => phcCommandIdle,                      -- [in]
         manualBusy           => phcManualBusy,                       -- [in]
         phcSnapshotPrepared  => phcSnapshotPrepared,                 -- [in]
         captureAbort         => abortCapture,                        -- [in]
         phcStatus            => status,                              -- [in]
         externalOwner        => ownerExternal,                       -- [out]
         irq                  => irq);                                -- [out]

   U_Phc : entity surf.PtpPhc
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         CLK_FREQ_G     => CLK_FREQ_G,
         MANUAL_EN_G    => MANUAL_EN_C)
      port map (
         clk               => clk,                             -- [in]
         rst               => rst,                             -- [in]
         regRst            => busRst,                          -- [in]
         axiReadMaster     => readMasters(PHC_AXIL_INDEX_C),   -- [in]
         axiReadSlave      => readSlaves(PHC_AXIL_INDEX_C),    -- [out]
         axiWriteMaster    => writeMasters(PHC_AXIL_INDEX_C),  -- [in]
         axiWriteSlave     => writeSlaves(PHC_AXIL_INDEX_C),   -- [out]
         configControl     => activeConfigControl,             -- [in]
         snapshotControl   => activeSnapshotControl,           -- [in]
         snapshotPrepared  => phcSnapshotPrepared,             -- [out]
         configValid       => open,                            -- [out]
         externalOwner     => ownerExternal,                   -- [in]
         restart           => restart,                         -- [in]
         portCommandAbort  => commandAbort,                    -- [in]
         manualBusy        => phcManualBusy,                   -- [out]
         commandIdle       => phcCommandIdle,                  -- [out]
         clearValid        => clearValid,                      -- [in]
         phcTime           => timeValue,                       -- [out]
         status            => status,                          -- [out]
         pps               => pps,                             -- [out]
         captureAbort      => abortCapture,                    -- [out]
         commandMaster     => externalMaster,                  -- [in]
         commandSlave      => externalSlave,                   -- [out]
         secondRequest     => secondRequests(0),               -- [out]
         secondReady       => secondReady(0),                  -- [in]
         secondCancel      => secondCancel(0),                 -- [out]
         secondResult      => secondResults(0),                -- [in]
         secondResultReady => secondResultReady(0));           -- [out]

   -- The private converter serves manual PHASE only; fixed external control
   -- omits it and leaves the PHC's request path idle.
   GEN_NO_SECOND : if not MANUAL_EN_C generate
      secondReady   <= (others => '0');
      secondResults <= (others => PTP_SECOND_RESULT_INIT_C);
   end generate GEN_NO_SECOND;

   GEN_SECOND : if MANUAL_EN_C generate

      U_Second : entity surf.PtpSecondService
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            RST_ASYNC_G    => RST_ASYNC_G,
            NUM_CLIENTS_G  => 1,
            WIDTH_G        => 128)
         port map (
            clk         => clk,                 -- [in]
            rst         => rst,                 -- [in]
            cancel      => secondCancel,        -- [in]
            requests    => secondRequests,      -- [in]
            inputReady  => secondReady,         -- [out]
            results     => secondResults,       -- [out]
            resultReady => secondResultReady);  -- [in]

   end generate GEN_SECOND;

end architecture mapping;
