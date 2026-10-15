-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flattened numerical verification interface for PtpE2e.
--
-- Constructs Sync and delay-sample records from scalar/vector ports and
-- exposes the production engine's forward value, path delay, error and
-- ready/valid handshakes. Tests directly control remote timestamps, correction
-- fields, raw tick/phase separation, the rate ratio and each capture's PHC
-- increment. Latency generics select the ingress and egress reference-plane
-- offsets.
--
-- Unexposed record fields retain package initialization values. The wrapper performs no arithmetic or packet
-- association of its own. Cocotb supplies stimulus and independent expected
-- results, including rate changes between captures, numerical boundaries,
-- output backpressure and cancellation.
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
use surf.PtpPkg.all;
use surf.PtpSyncPkg.all;

entity PtpE2eWrapper is
   generic (
      INGRESS_LATENCY_G : slv(63 downto 0) := (others => '0');
      EGRESS_LATENCY_G  : slv(63 downto 0) := (others => '0');
      NORMALIZED_SYNC_G : boolean          := false);
   port (
      clk                 : in  sl;
      rst                 : in  sl;
      cancel              : in  sl;
      normalizedValid     : in  sl               := '0';
      normalizedReady     : out sl;
      normalizedWord      : in  slv(2 downto 0)  := (others => '0');
      normalizedData      : in  slv(31 downto 0) := (others => '0');
      inputValid          : in  sl;
      inputReady          : out sl;
      syncTime            : in  slv(95 downto 0);
      syncTicks           : in  slv(63 downto 0);
      syncPhase           : in  slv(2 downto 0);
      syncIncrement       : in  slv(63 downto 0);
      syncRemote          : in  slv(79 downto 0);
      syncCorrection      : in  slv(127 downto 0);
      txTicks             : in  slv(63 downto 0);
      txPhase             : in  slv(2 downto 0);
      txIncrement         : in  slv(63 downto 0);
      responseRemote      : in  slv(79 downto 0);
      responseCorrection  : in  slv(63 downto 0);
      syncGeneration      : in  slv(31 downto 0) := (others => '0');
      delayGeneration     : in  slv(31 downto 0) := (others => '0');
      syncSequence        : in  slv(15 downto 0) := (others => '0');
      delaySequence       : in  slv(15 downto 0) := (others => '0');
      ratio               : in  slv(63 downto 0);
      maxPathDelay        : in  slv(63 downto 0);
      forwardValue        : out slv(127 downto 0);
      delayValue          : out slv(127 downto 0);
      resultGeneration    : out slv(31 downto 0);
      resultSyncSequence  : out slv(15 downto 0);
      resultDelaySequence : out slv(15 downto 0);
      resultTicks         : out slv(63 downto 0);
      resultRatio         : out slv(63 downto 0);
      resultRatioValid    : out sl;
      resultIsDelay       : out sl;
      resultValid         : out sl;
      resultReady         : in  sl;
      resultError         : out sl);
end entity PtpE2eWrapper;

architecture rtl of PtpE2eWrapper is

   signal syncSample        : PtpSyncSampleType  := PTP_SYNC_SAMPLE_INIT_C;
   signal delaySample       : PtpDelaySampleType := PTP_DELAY_SAMPLE_INIT_C;
   signal measurement       : PtpMeasurementType;
   signal divideValid       : slv(1 downto 0);
   signal divideReady       : slv(1 downto 0);
   signal divideOperandA    : Slv128Array(1 downto 0);
   signal divideOperandB    : slv(159 downto 0);
   signal divideCancel      : slv(1 downto 0);
   signal divideResultValid : slv(1 downto 0);
   signal divideResultReady : slv(1 downto 0);
   signal divideResultValue : Slv128Array(1 downto 0);
   signal divideResultError : slv(1 downto 0);

   signal normalizedMaster : PtpSyncNormalizedMasterType;

begin

   normalizedMaster <=
   (
      valid => normalizedValid,
      word  => normalizedWord,
      data  => normalizedData
   );

   U_Divide : entity surf.PtpVariableDivide
      generic map (
         NUM_CLIENTS_G   => 2,
         DIVISOR_WIDTH_G => 80)
      port map (
         clk          => clk,                 -- [in]
         rst          => rst,                 -- [in]
         cancel       => divideCancel,        -- [in]
         inputValid   => divideValid,         -- [in]
         inputReady   => divideReady,         -- [out]
         roundNearest => "11",                -- [in]
         operandA     => divideOperandA,      -- [in]
         operandB     => divideOperandB,      -- [in]
         resultValid  => divideResultValid,   -- [out]
         resultReady  => divideResultReady,   -- [in]
         resultValue  => divideResultValue,   -- [out]
         resultError  => divideResultError);  -- [out]

   syncSample.capture.timestamp  <= syncTime;
   syncSample.capture.ticks      <= syncTicks;
   syncSample.capture.tickPhase  <= syncPhase;
   syncSample.capture.increment  <= syncIncrement;
   syncSample.capture.generation <= syncGeneration;
   syncSample.sequenceId         <= syncSequence;
   delaySample.generation        <= delayGeneration;
   delaySample.sequenceId        <= delaySequence;
   resultGeneration              <= measurement.generation;
   resultSyncSequence            <= measurement.syncSequence;
   resultDelaySequence           <= measurement.delaySequence;
   resultTicks                   <= measurement.ticks;
   resultRatio                   <= measurement.ratio;
   resultRatioValid              <= measurement.ratioValid;
   resultIsDelay                 <= measurement.isDelay;
   syncSample.remoteTime         <= syncRemote;
   syncSample.correction         <= syncCorrection;
   delaySample.capture.ticks     <= txTicks;
   delaySample.capture.tickPhase <= txPhase;
   delaySample.capture.increment <= txIncrement;
   delaySample.remoteTime        <= responseRemote;
   delaySample.correction        <= responseCorrection;
   forwardValue                  <= measurement.forward;
   delayValue                    <= measurement.delayValue;

   U_DUT : entity surf.PtpE2e
      generic map (
         INGRESS_LATENCY_G => INGRESS_LATENCY_G,
         EGRESS_LATENCY_G  => EGRESS_LATENCY_G,
         NORMALIZED_SYNC_G => NORMALIZED_SYNC_G)
      port map (
         normalizedMaster  => normalizedMaster,  -- [in]
         normalizedReady   => normalizedReady,  -- [out]
         divideValid       => divideValid(1),
         divideReady       => divideReady(1),
         divideOperandA    => divideOperandA(1),
         divideOperandB    => divideOperandB(159 downto 80),
         divideCancel      => divideCancel(1),
         divideResultValid => divideResultValid(1),
         divideResultReady => divideResultReady(1),
         divideResultValue => divideResultValue(1),
         divideResultError => divideResultError(1),
         clk               => clk,           -- [in]
         rst               => rst,           -- [in]
         cancel            => cancel,        -- [in]
         inputValid        => inputValid,    -- [in]
         inputReady        => inputReady,    -- [out]
         syncSample        => syncSample,    -- [in]
         delaySample       => delaySample,   -- [in]
         ratio             => ratio,         -- [in]
         maxPathDelay      => maxPathDelay,  -- [in]
         resultValue       => measurement,   -- [out]
         resultValid       => resultValid,   -- [out]
         resultReady       => resultReady,   -- [in]
         resultError       => resultError);  -- [out]

end architecture rtl;
