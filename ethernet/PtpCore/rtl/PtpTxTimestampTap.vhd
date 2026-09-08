-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Passive Delay_Req completion capture at the physical MAC TX
-- output.
--
-- Reuses PtpRxTimestampAdapter and PtpRxFrontend in TX-observation mode to
-- decode GMII/XGMII framing, validate the transmitted frame and publish its
-- PTP wire identity together with the physical start timestamp. Captures refer
-- to the first destination-MAC octet, include XGMII lane phase, and add the
-- signed Q16 egress calibration to reach the configured timestamp reference
-- plane.
--
-- Observation occurs after MAC queuing, arbitration, pause, padding and FCS
-- generation. PtpTxLedger uses the resulting record as evidence of actual
-- transmission, independently of when the stream was accepted. A two-entry
-- completion queue provides a ready/valid interface with an abort indication
-- for invalidated observations.
--
-- Port restart and PHC discontinuity do not flush this observer: an older
-- queued request can still appear on the wire and must resolve its retained
-- ledger entry. Capture validity/error remains separate from physical
-- identity. PHY loss flushes observation, and system reset must accompany
-- reset of the physical MAC TX pipeline.
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
use surf.AxiStreamPkg.all;
use surf.PtpPkg.all;

entity PtpTxTimestampTap is
   generic (
      TPD_G            : time             := 1 ns;
      RST_POLARITY_G   : sl               := '1';
      RST_ASYNC_G      : boolean          := false;
      PHY_TYPE_G       : string           := "XGMII";
      EGRESS_LATENCY_G : slv(63 downto 0) := (others => '0'));
   port (
      clk             : in  sl;
      rst             : in  sl;
      phyReady        : in  sl;
      phcTime         : in  PtpTimeType;
      phcStatus       : in  PtpPhcStatusType;
      captureAbort    : in  sl;
      xgmiiTxd        : in  slv(63 downto 0) := (others => '0');
      xgmiiTxc        : in  slv(7 downto 0)  := (others => '1');
      gmiiTxd         : in  slv(7 downto 0)  := (others => '0');
      gmiiTxEn        : in  sl               := '0';
      gmiiTxEr        : in  sl               := '0';
      completion      : out PtpRxMessageType;
      completionValid : out sl;
      completionReady : in  sl;
      completionAbort : out sl);
end entity PtpTxTimestampTap;

architecture rtl of PtpTxTimestampTap is

   signal master  : AxiStreamMasterType;
   signal capture : PtpRxCaptureType;
   signal flush   : sl;

begin

   assert EGRESS_LATENCY_G /= x"8000000000000000"
      report "PTP egress latency must be negatable in the signed 64-bit ingress adapter" severity failure;
   -- Port reset and PHC discontinuity deliberately do not flush this observer.
   -- A frame accepted by the MAC may appear much later, in a new generation.
   -- The port's persistent ledger distinguishes useful and retired completions.
   flush <= not phyReady;

   U_Adapter : entity surf.PtpRxTimestampAdapter
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         PHY_TYPE_G        => PHY_TYPE_G,
         TX_OBSERVE_G      => true,
         INGRESS_LATENCY_G => slv(-signed(EGRESS_LATENCY_G)))
      port map (
         clk          => clk,                   -- [in]
         rst          => rst,                   -- [in]
         rxFlush      => '0',                   -- [in]
         phyReady     => phyReady,              -- [in]
         generation   => phcStatus.generation,  -- [in]
         phcTime      => phcTime,               -- [in]
         phcIncrement => phcStatus.increment,   -- [in]
         tickCount    => phcStatus.ticks,       -- [in]
         timeValid    => phcStatus.timeValid,   -- [in]
         captureAbort => captureAbort,          -- [in]
         xgmiiRxd     => xgmiiTxd,              -- [in]
         xgmiiRxc     => xgmiiTxc,              -- [in]
         gmiiRxd      => gmiiTxd,               -- [in]
         gmiiRxDv     => gmiiTxEn,              -- [in]
         gmiiRxEr     => gmiiTxEr,              -- [in]
         rxMaster     => master,                -- [out]
         rxCapture    => capture);              -- [out]

   U_Validator : entity surf.PtpRxFrontend
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         TX_OBSERVE_G   => true,
         FIFO_DEPTH_G   => 2)
      port map (
         clk           => clk,                   -- [in]
         rst           => rst,                   -- [in]
         rxFlush       => flush,                 -- [in]
         generation    => phcStatus.generation,  -- [in]
         rxMaster      => master,                -- [in]
         rxCapture     => capture,               -- [in]
         message       => completion,            -- [out]
         messageValid  => completionValid,       -- [out]
         messageReady  => completionReady,       -- [in]
         rxAbort       => completionAbort,       -- [out]
         rxEpoch       => open,                  -- [out]
         acceptedCount => open,                  -- [out]
         droppedCount  => open,                  -- [out]
         overflowCount => open);                 -- [out]

end architecture rtl;
