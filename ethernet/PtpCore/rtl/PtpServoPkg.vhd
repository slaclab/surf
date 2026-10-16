-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PTP servo interface records.
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

package PtpServoPkg is

   -- Filter request in clk, held through inputReady. Delay/limit are Q16 ns and
   -- ticks are raw cycles. cancel/reset invalidates acceptance and filter history.
   type PtpFilterRequestType is record
      valid        : sl;
      delayValue   : slv(127 downto 0);
      ticks        : slv(63 downto 0);
      maxPathDelay : slv(63 downto 0);
   end record;

   constant PTP_FILTER_REQUEST_INIT_C : PtpFilterRequestType := (
      valid        => '0',
      delayValue   => (others => '0'),
      ticks        => (others => '0'),
      maxPathDelay => (others => '0'));

   -- Live registered median in clk, without backpressure. valid qualifies Q16 ns
   -- delayValue and raw ticks; count is the retained sample count. Update/reject
   -- events are separate pulses. Cancel/reset clears validity and count.
   type PtpFilterStatusType is record
      valid      : sl;
      delayValue : slv(127 downto 0);
      count      : slv(2 downto 0);
      ticks      : slv(63 downto 0);
   end record;

   constant PTP_FILTER_STATUS_INIT_C : PtpFilterStatusType := (
      valid      => '0',
      delayValue => (others => '0'),
      count      => (others => '0'),
      ticks      => (others => '0'));

   -- PI request in clk, held through inputReady. Forward is signed Q16 ns,
   -- ratio is Q48 ns/raw cycle; ticks/generation retain capture provenance.
   -- Filter status/configuration are sampled separately at acceptance.
   -- Cancel/reset invalidates acceptance and outstanding PHC commands.
   type PtpPiRequestType is record
      valid        : sl;
      ticks        : slv(63 downto 0);
      generation   : slv(31 downto 0);
      forwardValue : slv(127 downto 0);
      ratio        : slv(63 downto 0);
      ratioValid   : sl;
   end record;

   constant PTP_PI_REQUEST_INIT_C : PtpPiRequestType := (
      valid        => '0',
      ticks        => (others => '0'),
      generation   => (others => '0'),
      forwardValue => (others => '0'),
      ratio        => (others => '0'),
      ratioValid   => '0');

end package PtpServoPkg;
