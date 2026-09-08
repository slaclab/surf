-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Thin E2E fixed-point verification adapter
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

entity PtpE2eWrapper is
   generic (
      INGRESS_LATENCY_G : slv(63 downto 0) := (others => '0');
      EGRESS_LATENCY_G  : slv(63 downto 0) := (others => '0'));
   port (
      clk                : in  sl;
      rst                : in  sl;
      cancel             : in  sl;
      inputValid         : in  sl;
      inputReady         : out sl;
      syncTime           : in  slv(95 downto 0);
      syncTicks          : in  slv(63 downto 0);
      syncPhase          : in  slv(2 downto 0);
      syncIncrement      : in  slv(63 downto 0);
      syncRemote         : in  slv(79 downto 0);
      syncCorrection     : in  slv(127 downto 0);
      txTicks            : in  slv(63 downto 0);
      txPhase            : in  slv(2 downto 0);
      txIncrement        : in  slv(63 downto 0);
      responseRemote     : in  slv(79 downto 0);
      responseCorrection : in  slv(63 downto 0);
      ratio              : in  slv(63 downto 0);
      maxPathDelay       : in  slv(63 downto 0);
      forwardValue       : out slv(127 downto 0);
      delayValue         : out slv(127 downto 0);
      resultValid        : out sl;
      resultReady        : in  sl;
      resultError        : out sl);
end entity PtpE2eWrapper;

architecture rtl of PtpE2eWrapper is

   signal syncSample  : PtpSyncSampleType := PTP_SYNC_SAMPLE_INIT_C;
   signal delaySample : PtpDelaySampleType := PTP_DELAY_SAMPLE_INIT_C;
   signal measurement : PtpMeasurementType;

begin

   syncSample.capture.timestamp  <= syncTime;
   syncSample.capture.ticks      <= syncTicks;
   syncSample.capture.tickPhase  <= syncPhase;
   syncSample.capture.increment  <= syncIncrement;
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
         EGRESS_LATENCY_G  => EGRESS_LATENCY_G)
      port map (
         clk          => clk,           -- [in]
         rst          => rst,           -- [in]
         cancel       => cancel,        -- [in]
         inputValid   => inputValid,    -- [in]
         inputReady   => inputReady,    -- [out]
         syncSample   => syncSample,    -- [in]
         delaySample  => delaySample,   -- [in]
         ratio        => ratio,         -- [in]
         maxPathDelay => maxPathDelay,  -- [in]
         resultValue  => measurement,   -- [out]
         resultValid  => resultValid,   -- [out]
         resultReady  => resultReady,   -- [in]
         resultError  => resultError);  -- [out]

end architecture rtl;
