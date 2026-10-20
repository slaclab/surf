-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flat-port simulation wrapper for PtpTelemetry.
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
use surf.SsiPkg.all;
use surf.PtpPkg.all;

entity PtpTelemetryWrapper is
   generic (
      TPD_G          : time                   := 1 ns;
      TELEMETRY_ID_G : natural                := 5);
   port (
      clk                : in  sl;
      rst                : in  sl;
      phcSeconds         : in  slv(47 downto 0);
      phcNanoseconds     : in  slv(31 downto 0);
      phcFraction        : in  slv(31 downto 0);
      phcTicks           : in  slv(63 downto 0);
      phcRate            : in  slv(63 downto 0);
      phcIncrement       : in  slv(63 downto 0);
      phcGeneration      : in  slv(31 downto 0);
      phcTimeValid       : in  sl;
      phcDiscontinuity   : in  sl;
      phcFault           : in  sl;
      portActive         : in  sl;
      linkReady          : in  sl;
      measValid          : in  sl;
      measReady          : in  sl;
      measAbort          : in  sl;
      measIsDelay        : in  sl;
      measGeneration     : in  slv(31 downto 0);
      measTicks          : in  slv(63 downto 0);
      measSyncSequence   : in  slv(15 downto 0);
      measDelaySequence  : in  slv(15 downto 0);
      measForward        : in  slv(127 downto 0);
      measDelay          : in  slv(127 downto 0);
      measRatio          : in  slv(63 downto 0);
      measRatioValid     : in  sl;
      exT1               : in  slv(79 downto 0);
      exT2               : in  slv(95 downto 0);
      exT3               : in  slv(95 downto 0);
      exT4               : in  slv(79 downto 0);
      exSyncCorrection   : in  slv(127 downto 0);
      exDelayCorrection  : in  slv(63 downto 0);
      exGeneration       : in  slv(31 downto 0);
      exSyncSequence     : in  slv(15 downto 0);
      exDelaySequence    : in  slv(15 downto 0);
      cmdValid           : in  sl;
      cmdReady           : in  sl;
      cmdKind            : in  slv(2 downto 0);
      cmdGeneration      : in  slv(31 downto 0);
      cmdSetSeconds      : in  slv(47 downto 0);
      cmdSetNanoseconds  : in  slv(31 downto 0);
      cmdSetFraction     : in  slv(31 downto 0);
      cmdPhaseSeconds    : in  slv(63 downto 0);
      cmdPhaseFraction   : in  slv(63 downto 0);
      cmdRate            : in  slv(63 downto 0);
      cmdValue           : in  sl;
      servoState         : in  slv(2 downto 0);
      servoFilteredDelay : in  slv(127 downto 0);
      servoOffset        : in  slv(127 downto 0);
      servoRatePpb       : in  slv(63 downto 0);
      servoFilterCount   : in  slv(2 downto 0);
      servoRejected      : in  slv(31 downto 0);
      -- Records
      outValid : out sl;
      outData  : out slv(63 downto 0);
      outLast  : out sl;
      outSof   : out sl;
      outKeep  : out slv(7 downto 0);
      outReady : in  sl;
      dropped  : out slv(31 downto 0));
end entity PtpTelemetryWrapper;

architecture mapping of PtpTelemetryWrapper is

   signal phcTime           : PtpTimeType;
   signal phcStatus         : PtpPhcStatusType;
   signal measurementMaster : PtpMeasurementMasterType;
   signal measurementSlave  : PtpMeasurementSlaveType;
   signal exchange          : PtpExchangeType;
   signal commandMaster     : PtpPhcCommandMasterType;
   signal commandSlave      : PtpPhcCommandSlaveType;
   signal servoStatus       : PtpServoStatusType;
   signal telemetryMaster   : AxiStreamMasterType;
   signal telemetrySlave    : AxiStreamSlaveType;

begin

   phcTime.seconds     <= phcSeconds;
   phcTime.nanoseconds <= phcNanoseconds;
   phcTime.fraction    <= phcFraction;

   phcStatus.generation    <= phcGeneration;
   phcStatus.ticks         <= phcTicks;
   phcStatus.increment     <= phcIncrement;
   phcStatus.rate          <= phcRate;
   phcStatus.timeValid     <= phcTimeValid;
   phcStatus.ack           <= '0';
   phcStatus.error         <= '0';
   phcStatus.discontinuity <= phcDiscontinuity;
   phcStatus.fault         <= phcFault;

   measurementMaster.valid              <= measValid;
   measurementMaster.abort              <= measAbort;
   measurementMaster.data.isDelay       <= measIsDelay;
   measurementMaster.data.generation    <= measGeneration;
   measurementMaster.data.ticks         <= measTicks;
   measurementMaster.data.syncSequence  <= measSyncSequence;
   measurementMaster.data.delaySequence <= measDelaySequence;
   measurementMaster.data.forward       <= measForward;
   measurementMaster.data.delayValue    <= measDelay;
   measurementMaster.data.ratio         <= measRatio;
   measurementMaster.data.ratioValid    <= measRatioValid;
   measurementSlave.ready               <= measReady;

   exchange.t1              <= exT1;
   exchange.t2              <= exT2;
   exchange.t3              <= exT3;
   exchange.t4              <= exT4;
   exchange.syncCorrection  <= exSyncCorrection;
   exchange.delayCorrection <= exDelayCorrection;
   exchange.generation      <= exGeneration;
   exchange.syncSequence    <= exSyncSequence;
   exchange.delaySequence   <= exDelaySequence;

   commandMaster.valid                    <= cmdValid;
   commandMaster.cancel                   <= '0';
   commandMaster.stale                    <= '0';
   commandMaster.data.kind                <= cmdKind;
   commandMaster.data.generation          <= cmdGeneration;
   commandMaster.data.setTime.seconds     <= cmdSetSeconds;
   commandMaster.data.setTime.nanoseconds <= cmdSetNanoseconds;
   commandMaster.data.setTime.fraction    <= cmdSetFraction;
   commandMaster.data.phaseSeconds        <= cmdPhaseSeconds;
   commandMaster.data.phaseFraction       <= cmdPhaseFraction;
   commandMaster.data.rate                <= cmdRate;
   commandMaster.data.value               <= cmdValue;
   commandSlave.ready                     <= cmdReady;
   commandSlave.ack                       <= '0';
   commandSlave.error                     <= '0';

   servoStatus.state         <= servoState;
   servoStatus.filteredDelay <= servoFilteredDelay;
   servoStatus.offsetValue   <= servoOffset;
   servoStatus.ratePpb       <= servoRatePpb;
   servoStatus.filterCount   <= servoFilterCount;
   servoStatus.rejectedCount <= servoRejected;

   U_DUT : entity surf.PtpTelemetry
      generic map (
         TPD_G          => TPD_G,
         TELEMETRY_ID_G => TELEMETRY_ID_G)
      port map (
         clk               => clk,                -- [in]
         rst               => rst,                -- [in]
         phcTime           => phcTime,            -- [in]
         phcStatus         => phcStatus,          -- [in]
         portActive        => portActive,         -- [in]
         linkReady         => linkReady,          -- [in]
         measurementMaster => measurementMaster,  -- [in]
         measurementSlave  => measurementSlave,   -- [in]
         exchange          => exchange,           -- [in]
         commandMaster     => commandMaster,      -- [in]
         commandSlave      => commandSlave,       -- [in]
         servoStatus       => servoStatus,        -- [in]
         telemetryMaster   => telemetryMaster,    -- [out]
         telemetrySlave    => telemetrySlave,     -- [in]
         dropped           => dropped);           -- [out]

   telemetrySlave.tReady <= outReady;
   outValid              <= telemetryMaster.tValid;
   outData               <= telemetryMaster.tData(63 downto 0);
   outLast               <= telemetryMaster.tLast;
   outKeep               <= telemetryMaster.tKeep(7 downto 0);
   outSof                <= ssiGetUserSof(PTP_TELEMETRY_AXIS_CONFIG_C, telemetryMaster);

end architecture mapping;
