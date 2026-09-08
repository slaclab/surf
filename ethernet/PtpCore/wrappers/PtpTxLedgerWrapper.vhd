-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Thin bounded wire-key lifecycle verification adapter
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

entity PtpTxLedgerWrapper is
   generic (
      PACKET_LIFETIME_G : positive := 100);
   port (
      clk                : in  sl;
      rst                : in  sl;
      restart            : in  sl;
      macResetDone       : in  sl;
      ticks              : in  slv(63 downto 0);
      generation         : in  slv(31 downto 0);
      timeout            : in  slv(63 downto 0);
      identity           : in  slv(79 downto 0);
      domainNumber       : in  slv(7 downto 0);
      allocate           : in  sl;
      allocateReady      : out sl;
      allocateSequence   : out slv(15 downto 0);
      wireValid          : in  sl;
      wireSequence       : in  slv(15 downto 0);
      wireIdentity       : in  slv(79 downto 0);
      wireDomain         : in  slv(7 downto 0);
      wireTicks          : in  slv(63 downto 0);
      wireGeneration     : in  slv(31 downto 0);
      wireError          : in  sl;
      responseValid      : in  sl;
      responseSequence   : in  slv(15 downto 0);
      responseIdentity   : in  slv(79 downto 0);
      responseDomain     : in  slv(7 downto 0);
      responseTicks      : in  slv(63 downto 0);
      responseGeneration : in  slv(31 downto 0);
      sampleValid        : out sl;
      sampleReady        : in  sl;
      sampleSequence     : out slv(15 downto 0);
      sampleTicks        : out slv(63 downto 0);
      sampleGeneration   : out slv(31 downto 0);
      timeoutCount       : out slv(31 downto 0);
      rejectedCount      : out slv(31 downto 0));
end entity PtpTxLedgerWrapper;

architecture rtl of PtpTxLedgerWrapper is

   signal config      : PtpConfigType := PTP_CONFIG_INIT_C;
   signal wireMessage : PtpRxMessageType := PTP_RX_MESSAGE_INIT_C;
   signal response    : PtpRxMessageType := PTP_RX_MESSAGE_INIT_C;
   signal sample      : PtpDelaySampleType;

begin

   config.localIdentity                <= identity;
   config.domainNumber                 <= domainNumber;
   config.associationTimeout           <= timeout;
   wireMessage.messageType             <= x"1";
   wireMessage.sequenceId              <= wireSequence;
   wireMessage.sourcePortIdentity      <= wireIdentity;
   wireMessage.domainNumber            <= wireDomain;
   wireMessage.capture.ticks           <= wireTicks;
   wireMessage.capture.generation      <= wireGeneration;
   wireMessage.capture.error           <= wireError;
   response.sequenceId                 <= responseSequence;
   response.messageBody(159 downto 80) <= responseIdentity;
   response.domainNumber               <= responseDomain;
   response.capture.ticks              <= responseTicks;
   response.capture.generation         <= responseGeneration;
   sampleSequence                      <= sample.sequenceId;
   sampleTicks                         <= sample.capture.ticks;
   sampleGeneration                    <= sample.generation;

   U_DUT : entity surf.PtpTxLedger
      generic map (
         DEPTH_G           => 2,
         SEQUENCE_BITS_G   => 2,
         PACKET_LIFETIME_G => PACKET_LIFETIME_G)
      port map (
         clk              => clk,               -- [in]
         rst              => rst,               -- [in]
         restart          => restart,           -- [in]
         macResetDone     => macResetDone,      -- [in]
         ticks            => ticks,             -- [in]
         generation       => generation,        -- [in]
         config           => config,            -- [in]
         allocate         => allocate,          -- [in]
         allocateReady    => allocateReady,     -- [out]
         allocateSequence => allocateSequence,  -- [out]
         wireMessage      => wireMessage,       -- [in]
         wireValid        => wireValid,         -- [in]
         response         => response,          -- [in]
         responseValid    => responseValid,     -- [in]
         sample           => sample,            -- [out]
         sampleValid      => sampleValid,       -- [out]
         sampleReady      => sampleReady,       -- [in]
         timeoutCount     => timeoutCount,      -- [out]
         rejectedCount    => rejectedCount);    -- [out]

end architecture rtl;
