-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flattened adversarial lifetime fixture for PtpTxLedger.
--
-- Adapts test-controlled allocation, physical wire-completion and Delay_Resp
-- fields into the production ledger records. Exposes sequence allocation,
-- completed sample provenance, response acceptance and status counters, with
-- direct control of raw ticks, generation, logical restart and MAC reset
-- confirmation.
--
-- Defaults to two entries and a two-bit sequence counter so cocotb can
-- exhaust capacity and force key wrap quickly. PACKET_LIFETIME_G controls the
-- quarantine interval. Wire and response inputs can be driven independently to
-- test reordered events, duplicate/late traffic, unknown transmission fate and
-- output backpressure. The wrapper supplies record defaults only; packet
-- validation, stimulus sequencing and expected ownership state are handled
-- outside this fixture.
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
use surf.PtpProtocolPkg.all;
use surf.PtpPkg.all;

entity PtpTxLedgerWrapper is
   generic (
      PACKET_LIFETIME_G : positive := 100;
      DEPTH_G           : positive := 2;
      SEQUENCE_BITS_G   : positive := 2;
      MEMORY_TYPE_G     : string   := "distributed");
   port (
      clk                     : in  sl;
      rst                     : in  sl;
      restart                 : in  sl;
      macResetDone            : in  sl;
      ticks                   : in  slv(63 downto 0);
      generation              : in  slv(31 downto 0);
      timeout                 : in  slv(63 downto 0);
      identity                : in  slv(79 downto 0);
      domainNumber            : in  slv(7 downto 0);
      allocate                : in  sl;
      allocateReady           : out sl;
      allocateSequence        : out slv(15 downto 0);
      wireValid               : in  sl;
      wireReady               : out sl;
      wireSequence            : in  slv(15 downto 0);
      wireIdentity            : in  slv(79 downto 0);
      wireDomain              : in  slv(7 downto 0);
      wireTicks               : in  slv(63 downto 0);
      wireGeneration          : in  slv(31 downto 0);
      wireError               : in  sl;
      wireTimestamp           : in  slv(95 downto 0)                      := (others => '0');
      wireIncrement           : in  slv(63 downto 0)                      := (others => '0');
      wirePhase               : in  slv(PTP_TICK_PHASE_BITS_C-1 downto 0) := (others => '0');
      wireTimeValid           : in  sl                                    := '0';
      responseValid           : in  sl;
      responseReady           : out sl;
      responseAccepted        : out sl;
      responseSequence        : in  slv(15 downto 0);
      responseIdentity        : in  slv(79 downto 0);
      responseDomain          : in  slv(7 downto 0);
      responseTicks           : in  slv(63 downto 0);
      responseGeneration      : in  slv(31 downto 0);
      responseTimestamp       : in  slv(79 downto 0)                      := (others => '0');
      responseCorrection      : in  slv(63 downto 0)                      := (others => '0');
      sampleValid             : out sl;
      sampleReady             : in  sl;
      sampleSequence          : out slv(15 downto 0);
      sampleTicks             : out slv(63 downto 0);
      sampleGeneration        : out slv(31 downto 0);
      sampleTimestamp         : out slv(95 downto 0);
      sampleIncrement         : out slv(63 downto 0);
      samplePhase             : out slv(PTP_TICK_PHASE_BITS_C-1 downto 0);
      sampleTimeValid         : out sl;
      sampleCaptureGeneration : out slv(31 downto 0);
      sampleError             : out sl;
      sampleRemoteTime        : out slv(79 downto 0);
      sampleCorrection        : out slv(63 downto 0);
      sampleResponseTicks     : out slv(63 downto 0);
      ledgerStatus            : out slv(31 downto 0);
      timeoutCount            : out slv(31 downto 0);
      rejectedCount           : out slv(31 downto 0));
end entity PtpTxLedgerWrapper;

architecture rtl of PtpTxLedgerWrapper is

   signal config      : PtpPortConfigType := PTP_PORT_CONFIG_INIT_C;
   signal wireMessage : PtpRxMessageType  := PTP_RX_MESSAGE_INIT_C;
   signal response    : PtpRxMessageType  := PTP_RX_MESSAGE_INIT_C;

   signal dutWireMaster     : PtpRxMessageMasterType;
   signal dutResponseMaster : PtpRxMessageMasterType;
   signal dutSampleMaster   : PtpDelaySampleMasterType;
   signal dutAllocation     : PtpLedgerAllocationType;

begin

   dutWireMaster <=
   (
      valid => wireValid,
      data  => wireMessage
   );
   dutResponseMaster <=
   (
      valid => responseValid,
      data  => response
   );
   sampleValid      <= dutSampleMaster.valid;
   allocateReady    <= dutAllocation.ready;
   allocateSequence <= dutAllocation.sequenceId;

   config.localIdentity           <= identity;
   config.domainNumber            <= domainNumber;
   config.associationTimeout      <= timeout;
   wireMessage.messageType        <= PTP_MSG_DELAY_REQ_C;
   wireMessage.sequenceId         <= wireSequence;
   wireMessage.sourcePortIdentity <= wireIdentity;
   wireMessage.domainNumber       <= wireDomain;
   wireMessage.capture.ticks      <= wireTicks;
   wireMessage.capture.generation <= wireGeneration;
   wireMessage.capture.error      <= wireError;
   wireMessage.capture.timestamp  <= wireTimestamp;
   wireMessage.capture.increment  <= wireIncrement;
   wireMessage.capture.tickPhase  <= wirePhase;
   wireMessage.capture.timeValid  <= wireTimeValid;
   response.sequenceId            <= responseSequence;
   response.messageBody(159 downto 80) <= responseIdentity;
   response.messageBody(239 downto 160) <= responseTimestamp;
   response.correction         <= responseCorrection;
   response.domainNumber       <= responseDomain;
   response.capture.ticks      <= responseTicks;
   response.capture.generation <= responseGeneration;
   sampleSequence              <= dutSampleMaster.data.sequenceId;
   sampleTicks                 <= dutSampleMaster.data.capture.ticks;
   sampleGeneration            <= dutSampleMaster.data.generation;
   sampleTimestamp             <= dutSampleMaster.data.capture.timestamp;
   sampleIncrement             <= dutSampleMaster.data.capture.increment;
   samplePhase                 <= dutSampleMaster.data.capture.tickPhase;
   sampleTimeValid             <= dutSampleMaster.data.capture.timeValid;
   sampleCaptureGeneration     <= dutSampleMaster.data.capture.generation;
   sampleError                 <= dutSampleMaster.data.capture.error;
   sampleRemoteTime            <= dutSampleMaster.data.remoteTime;
   sampleCorrection            <= dutSampleMaster.data.correction;
   sampleResponseTicks         <= dutSampleMaster.data.responseTicks;

   U_DUT : entity surf.PtpTxLedger
      generic map (
         DEPTH_G           => DEPTH_G,
         SEQUENCE_BITS_G   => SEQUENCE_BITS_G,
         PACKET_LIFETIME_G => PACKET_LIFETIME_G,
         MEMORY_TYPE_G     => MEMORY_TYPE_G)
      port map (
         clk              => clk,                -- [in]
         rst              => rst,                -- [in]
         restart          => restart,            -- [in]
         macResetDone     => macResetDone,       -- [in]
         ticks            => ticks,              -- [in]
         generation       => generation,         -- [in]
         config           => config,             -- [in]
         allocate         => allocate,           -- [in]
         allocation       => dutAllocation,      -- [out]
         wireMaster       => dutWireMaster,      -- [in]
         wireReady        => wireReady,          -- [out]
         responseMaster   => dutResponseMaster,  -- [in]
         responseReady    => responseReady,      -- [out]
         sampleMaster     => dutSampleMaster,    -- [out]
         sampleReady      => sampleReady,        -- [in]
         ledgerStatus     => ledgerStatus,       -- [out]
         responseAccepted => responseAccepted,   -- [out]
         timeoutCount     => timeoutCount,       -- [out]
         rejectedCount    => rejectedCount);     -- [out]

end architecture rtl;
