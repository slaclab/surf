-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flattened PHC and asynchronous snapshot verification interface.
--
-- Instantiates PtpPhc with configurable clock frequency and reset semantics,
-- packs the exposed command fields into PtpPhcCommandType, and unpacks time,
-- rate, raw ticks, validity, acknowledgement and fault status. PPS,
-- discontinuity and capture-abort outputs allow tests to check edge-specific
-- clock behavior against an independent numerical model.
--
-- Also instantiates PtpPhcRead with a separately driven reader clock/reset and
-- exposes its request, completion, snapshot and sequence fields. Reset
-- polarity is adapted for the mailbox. Cocotb controls both clocks and command
-- timing to exercise coherent snapshots, reset cancellation and stopped-peer
-- recovery; the wrapper adds no clock model or stimulus state machine.
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
use surf.PtpPkg.all;

entity PtpPhcWrapper is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      CLK_FREQ_G     : positive := 156250000);
   port (
      clk                : in  sl;
      rst                : in  sl;
      monotonic          : in  sl := '1';
      commandValid       : in  sl;
      commandReady       : out sl;
      commandKind        : in  slv(2 downto 0);
      commandGeneration  : in  slv(31 downto 0);
      commandSeconds     : in  slv(47 downto 0);
      commandNanoseconds : in  slv(31 downto 0);
      commandFraction    : in  slv(31 downto 0);
      phaseSeconds       : in  slv(63 downto 0);
      phaseFraction      : in  slv(63 downto 0);
      commandRate        : in  slv(63 downto 0);
      commandValue       : in  sl;
      timeSeconds        : out slv(47 downto 0);
      timeNanoseconds    : out slv(31 downto 0);
      timeFraction       : out slv(31 downto 0);
      timeGeneration     : out slv(31 downto 0);
      timeTicks          : out slv(63 downto 0);
      timeIncrement      : out slv(63 downto 0);
      timeRate           : out slv(63 downto 0);
      timeValid          : out sl;
      commandAck         : out sl;
      commandError       : out sl;
      discontinuity      : out sl;
      fault              : out sl;
      pps                : out sl;
      captureAbort       : out sl;
      readClk            : in  sl;
      readRst            : in  sl;
      readRequest        : in  sl;
      readReady          : out sl;
      readValid          : out sl;
      readSeconds        : out slv(47 downto 0);
      readNanoseconds    : out slv(31 downto 0);
      readFraction       : out slv(31 downto 0);
      readGeneration     : out slv(31 downto 0);
      readTicks          : out slv(63 downto 0);
      readTimeValid      : out sl;
      readSequence       : out slv(31 downto 0));
end entity PtpPhcWrapper;

architecture rtl of PtpPhcWrapper is

   signal command      : PtpPhcCommandType;
   signal status       : PtpPhcStatusType;
   signal timeValue    : PtpTimeType;
   signal snapshot     : PtpTimeType;
   signal abortCapture : sl;
   signal resetHigh    : sl;

begin

   command         <=
   (
      kind          => commandKind,
      generation    => commandGeneration,
      setTime       => (seconds => commandSeconds, nanoseconds => commandNanoseconds, fraction => commandFraction),
      phaseSeconds  => phaseSeconds,
      phaseFraction => phaseFraction,
      rate          => commandRate,
      value         => commandValue
   );
   resetHigh       <= '1' when rst = RST_POLARITY_G else '0';
   timeSeconds     <= timeValue.seconds;
   timeNanoseconds <= timeValue.nanoseconds;
   timeFraction    <= timeValue.fraction;
   timeGeneration  <= status.generation;
   timeTicks       <= status.ticks;
   timeIncrement   <= status.increment;
   timeRate        <= status.rate;
   timeValid       <= status.timeValid;
   commandAck      <= status.ack;
   commandError    <= status.error;
   discontinuity   <= status.discontinuity;
   fault           <= status.fault;
   captureAbort    <= abortCapture;
   readSeconds     <= snapshot.seconds;
   readNanoseconds <= snapshot.nanoseconds;
   readFraction    <= snapshot.fraction;

   U_DUT : entity surf.PtpPhc
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         CLK_FREQ_G     => CLK_FREQ_G)
      port map (
         clk          => clk,            -- [in]
         rst          => rst,            -- [in]
         monotonic    => monotonic,      -- [in]
         command      => command,        -- [in]
         commandValid => commandValid,   -- [in]
         commandReady => commandReady,   -- [out]
         phcTime      => timeValue,      -- [out]
         status       => status,         -- [out]
         pps          => pps,            -- [out]
         captureAbort => abortCapture);  -- [out]

   U_Read : entity surf.PtpPhcRead
      generic map (
         TPD_G => TPD_G)
      port map (
         phcClk         => clk,             -- [in]
         phcRst         => resetHigh,       -- [in]
         phcTime        => timeValue,       -- [in]
         phcStatus      => status,          -- [in]
         captureAbort   => abortCapture,    -- [in]
         readClk        => readClk,         -- [in]
         readRst        => readRst,         -- [in]
         readRequest    => readRequest,     -- [in]
         readReady      => readReady,       -- [out]
         readValid      => readValid,       -- [out]
         readTime       => snapshot,        -- [out]
         readGeneration => readGeneration,  -- [out]
         readTicks      => readTicks,       -- [out]
         readTimeValid  => readTimeValid,   -- [out]
         readSequence   => readSequence);   -- [out]

end architecture rtl;
