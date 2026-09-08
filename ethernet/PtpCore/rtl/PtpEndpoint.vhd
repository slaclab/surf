-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Autonomous PTP protocol, clock-control and register subsystem.
--
-- Connects PtpPort, PtpServo, PtpReg and one PtpPhc in a single clock domain.
-- Validated RX records and observed TX completion records arrive from the
-- physical frontends. The port produces Delay_Req frames and timing
-- measurements; the servo turns qualified measurements into PHC commands. The
-- surrounding EthMacPtpEndpoint supplies the MAC and physical timestamp
-- adapters.
--
-- Arbitrates software and servo commands at the PHC ready/valid interface and
-- retains producer ownership until acknowledgement, so a delayed response
-- reaches the correct requester. Manual steering requires automatic control to
-- be disabled, while PPS control remains available in either mode. A disabled
-- servo continues to drain measurements.
--
-- Coordinates protocol restart, stale-work cancellation and clock validity
-- without feeding a PHC command's own capture invalidation back into that
-- command's commit. Port and register resets preserve the PHC; system reset
-- clears the complete subsystem. AXI-Lite status, snapshots, PPS and IRQ
-- expose the resulting time and endpoint state.
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
use surf.PtpPkg.all;

entity PtpEndpoint is
   generic (
      TPD_G             : time             := 1 ns;
      RST_POLARITY_G    : sl               := '1';
      RST_ASYNC_G       : boolean          := false;
      CLK_FREQ_G        : positive         := 156250000;
      PACKET_LIFETIME_G : positive         := 156250000;
      INGRESS_LATENCY_G : slv(63 downto 0) := (others => '0');
      EGRESS_LATENCY_G  : slv(63 downto 0) := (others => '0'));
   port (
      clk             : in  sl;
      rst             : in  sl;
      regRst          : in  sl := '0';
      portRst         : in  sl := '0';
      linkReady       : in  sl;
      macResetDone    : in  sl;
      localMac        : in  slv(47 downto 0);
      axiReadMaster   : in  AxiLiteReadMasterType;
      axiReadSlave    : out AxiLiteReadSlaveType;
      axiWriteMaster  : in  AxiLiteWriteMasterType;
      axiWriteSlave   : out AxiLiteWriteSlaveType;
      rxMessage       : in  PtpRxMessageType;
      rxValid         : in  sl;
      rxReady         : out sl;
      rxQueueOverflow : in  sl := '0';
      rxAbort         : in  sl;
      rxCounters      : in  Slv32Array(0 to 2);
      txMessage       : in  PtpRxMessageType;
      txValid         : in  sl;
      txAbort         : in  sl;
      txMaster        : out AxiStreamMasterType;
      txSlave         : in  AxiStreamSlaveType;
      phcTime         : out PtpTimeType;
      phcStatus       : out PtpPhcStatusType;
      captureAbort    : out sl;
      rxFlush         : out sl;
      pps             : out sl;
      irq             : out sl;
      portActive      : out sl;
      servoState      : out slv(2 downto 0));
end entity PtpEndpoint;

architecture rtl of PtpEndpoint is

   type OwnerType is (
      NONE_S,
      MANUAL_S,
      AUTO_S);

   type RegType is record
      owner     : OwnerType;
      abortSeen : sl;
   end record;

   constant REG_INIT_C : RegType := (
   owner     => NONE_S,
   abortSeen => '0');

   signal r                : RegType := REG_INIT_C;
   signal rin              : RegType;
   signal config           : PtpConfigType;
   signal configRestart    : sl;
   signal restart          : sl;
   signal timeValue        : PtpTimeType;
   signal status           : PtpPhcStatusType;
   signal abortCapture     : sl;
   signal phcCommand       : PtpPhcCommandType;
   signal phcCommandValid  : sl;
   signal phcCommandReady  : sl;
   signal phcCommandCancel : sl;
   signal manualCommand    : PtpPhcCommandType;
   signal manualValid      : sl;
   signal manualReady      : sl;
   signal manualAck        : sl;
   signal autoCommand      : PtpPhcCommandType;
   signal autoValid        : sl;
   signal autoReady        : sl;
   signal autoAck          : sl;
   signal portCommandAbort : sl;
   signal autoStale        : sl;
   signal autoCancel       : sl;
   signal clearValid       : sl;
   signal measurement      : PtpMeasurementType;
   signal measurementValid : sl;
   signal measurementReady : sl;
   signal measurementAbort : sl;
   signal active           : sl;
   signal quality          : slv(2 downto 0);
   signal delayValue       : slv(127 downto 0);
   signal offsetValue      : slv(127 downto 0);
   signal ratePpb          : slv(63 downto 0);
   signal filterCount      : slv(2 downto 0);
   signal exchange         : PtpExchangeType;
   signal announceBody     : slv(239 downto 0);
   signal ledgerStatus     : slv(31 downto 0);
   signal announceValid    : sl;
   signal gmIdentity       : slv(63 downto 0);
   signal announceFlags    : slv(15 downto 0);
   signal utcOffset        : slv(15 downto 0);
   signal counters         : Slv32Array(0 to 7);

begin

   restart          <= portRst or configRestart;
   rxFlush          <= restart or not linkReady or abortCapture;
   counters(0 to 2) <= rxCounters;

   U_Phc : entity surf.PtpPhc
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         CLK_FREQ_G     => CLK_FREQ_G)
      port map (
         clk           => clk,               -- [in]
         rst           => rst,               -- [in]
         monotonic     => config.monotonic,  -- [in]
         command       => phcCommand,        -- [in]
         commandValid  => phcCommandValid,   -- [in]
         commandReady  => phcCommandReady,   -- [out]
         commandCancel => phcCommandCancel,  -- [in]
         clearValid    => clearValid,        -- [in]
         phcTime       => timeValue,         -- [out]
         status        => status,            -- [out]
         pps           => pps,               -- [out]
         captureAbort  => abortCapture);     -- [out]

   U_Port : entity surf.PtpPort
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         CLK_FREQ_G        => CLK_FREQ_G,
         PACKET_LIFETIME_G => PACKET_LIFETIME_G,
         INGRESS_LATENCY_G => INGRESS_LATENCY_G,
         EGRESS_LATENCY_G  => EGRESS_LATENCY_G)
      port map (
         clk                 => clk,               -- [in]
         rst                 => rst,               -- [in]
         restart             => restart,           -- [in]
         linkReady           => linkReady,         -- [in]
         macResetDone        => macResetDone,      -- [in]
         localMac            => localMac,          -- [in]
         config              => config,            -- [in]
         phcStatus           => status,            -- [in]
         captureAbort        => abortCapture,      -- [in]
         rxMessage           => rxMessage,         -- [in]
         rxValid             => rxValid,           -- [in]
         rxReady             => rxReady,           -- [out]
         rxAbort             => rxAbort,           -- [in]
         rxQueueOverflow     => rxQueueOverflow,   -- [in]
         commandAbort        => portCommandAbort,  -- [out]
         txMessage           => txMessage,         -- [in]
         txValid             => txValid,           -- [in]
         txAbort             => txAbort,           -- [in]
         txMaster            => txMaster,          -- [out]
         txSlave             => txSlave,           -- [in]
         measurement         => measurement,       -- [out]
         measurementValid    => measurementValid,  -- [out]
         measurementReady    => measurementReady,  -- [in]
         measurementAbort    => measurementAbort,  -- [out]
         active              => active,            -- [out]
         ratioValid          => open,              -- [out]
         announceValid       => announceValid,     -- [out]
         exchange            => exchange,          -- [out]
         announceBody        => announceBody,      -- [out]
         ledgerStatus        => ledgerStatus,      -- [out]
         grandmasterIdentity => gmIdentity,        -- [out]
         announceFlags       => announceFlags,     -- [out]
         utcOffset           => utcOffset,         -- [out]
         rejectedCount       => counters(3),       -- [out]
         syncCount           => counters(4),       -- [out]
         delayCount          => counters(5),       -- [out]
         timeoutCount        => counters(6));      -- [out]

   U_Servo : entity surf.PtpServo
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         CLK_FREQ_G     => CLK_FREQ_G)
      port map (
         clk              => clk,               -- [in]
         rst              => rst,               -- [in]
         cancel           => measurementAbort,  -- [in]
         restart          => restart,           -- [in]
         config           => config,            -- [in]
         phcStatus        => status,            -- [in]
         measurement      => measurement,       -- [in]
         measurementValid => measurementValid,  -- [in]
         measurementReady => measurementReady,  -- [out]
         command          => autoCommand,       -- [out]
         commandValid     => autoValid,         -- [out]
         commandReady     => autoReady,         -- [in]
         commandAck       => autoAck,           -- [in]
         commandError     => status.error,      -- [in]
         cancelCommand    => autoCancel,        -- [out]
         staleCommand     => autoStale,         -- [out]
         expireTime       => clearValid,        -- [out]
         servoState       => quality,           -- [out]
         filteredDelay    => delayValue,        -- [out]
         offsetValue      => offsetValue,       -- [out]
         ratePpb          => ratePpb,           -- [out]
         filterCount      => filterCount,       -- [out]
         rejectedCount    => counters(7));      -- [out]

   U_Reg : entity surf.PtpReg
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         CLK_FREQ_G        => CLK_FREQ_G,
         INGRESS_LATENCY_G => INGRESS_LATENCY_G,
         EGRESS_LATENCY_G  => EGRESS_LATENCY_G,
         PACKET_LIFETIME_G => PACKET_LIFETIME_G)
      port map (
         clk                 => clk,             -- [in]
         rst                 => rst,             -- [in]
         regRst              => regRst,          -- [in]
         axiReadMaster       => axiReadMaster,   -- [in]
         axiReadSlave        => axiReadSlave,    -- [out]
         axiWriteMaster      => axiWriteMaster,  -- [in]
         axiWriteSlave       => axiWriteSlave,   -- [out]
         localMac            => localMac,        -- [in]
         config              => config,          -- [out]
         configRestart       => configRestart,   -- [out]
         phcTime             => timeValue,       -- [in]
         phcStatus           => status,          -- [in]
         captureAbort        => abortCapture,    -- [in]
         command             => manualCommand,   -- [out]
         commandValid        => manualValid,     -- [out]
         commandReady        => manualReady,     -- [in]
         commandAck          => manualAck,       -- [in]
         commandError        => status.error,    -- [in]
         portActive          => active,          -- [in]
         servoState          => quality,         -- [in]
         filteredDelay       => delayValue,      -- [in]
         offsetValue         => offsetValue,     -- [in]
         ratePpb             => ratePpb,         -- [in]
         filterCount         => filterCount,     -- [in]
         announceValid       => announceValid,   -- [in]
         exchange            => exchange,        -- [in]
         announceBody        => announceBody,    -- [in]
         ledgerStatus        => ledgerStatus,    -- [in]
         grandmasterIdentity => gmIdentity,      -- [in]
         announceFlags       => announceFlags,   -- [in]
         utcOffset           => utcOffset,       -- [in]
         counters            => counters,        -- [in]
         irq                 => irq);            -- [out]

   -- Ownership extends through acknowledgement, not just command admission.
   -- Thus a delayed PHC response can never acknowledge the other producer.
   comb : process (r, rst, manualCommand, manualValid, autoCommand, autoValid, autoCancel, autoStale, portCommandAbort, restart, config, phcCommandReady, status) is
      variable v : RegType;
   begin
      v := r;

      v.abortSeen      := portCommandAbort;
      phcCommand       <= PTP_PHC_COMMAND_INIT_C;
      phcCommandValid  <= '0';
      manualReady      <= '0';
      autoReady        <= '0';
      manualAck        <= '0';
      autoAck          <= '0';
      phcCommandCancel <= '0';
      case r.owner is
         when NONE_S =>
            if manualValid = '1' then
               phcCommand      <= manualCommand;
               phcCommandValid <= manualValid;
               manualReady     <= phcCommandReady;
               if phcCommandReady = '1' then
                  v.owner := MANUAL_S;
               end if;
            elsif autoValid = '1' and autoCancel = '0' then
               phcCommand      <= autoCommand;
               phcCommandValid <= autoValid;
               autoReady       <= phcCommandReady;
               if phcCommandReady = '1' then
                  v.owner := AUTO_S;
               end if;
            end if;
         when MANUAL_S =>
            manualAck <= status.ack;
            if status.ack = '1' then
               v.owner := NONE_S;
            end if;
         when AUTO_S =>
            -- A PHC command's own capture flush cannot cancel its commit.
            -- Only independent protocol lifecycle causes cancel an accepted
            -- automatic command; producer invalidation still cancels queued work.
            phcCommandCancel <= (portCommandAbort and not r.abortSeen) or restart or autoStale or not config.servoEnable;
            autoAck          <= status.ack;
            if status.ack = '1' then
               v.owner := NONE_S;
            end if;
      end case;
      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;
      rin <= v;
   end process comb;
   phcTime      <= timeValue;
   phcStatus    <= status;
   captureAbort <= abortCapture;
   portActive   <= active;
   servoState   <= quality;
   seq : process (clk, rst) is
   begin
      if RST_ASYNC_G and rst = RST_POLARITY_G then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
