-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Passive GMII/XGMII reception of timestamped PTP messages.
--
-- Composes PtpRxTimestampAdapter and PtpRxFrontend without adding state or
-- latency. The adapter captures the first destination-MAC byte and forwards
-- normalized frame bytes with their capture through the existing register
-- boundary. The frontend validates PTP/FCS and queues complete message records.
--
-- All interfaces use the continuously running Ethernet/PHC clock: 125 MHz
-- for full-rate GMII or 156.25 MHz for XGMII. Physical input cannot stall;
-- message transfer requires messageValid AND messageReady AND NOT rxAbort.
-- Consumers give abort priority. INGRESS_LATENCY_G is signed Q16 PHC ns.
-- The owner must assert rxFlush for link loss and protocol restart, reaching
-- both children together. PHC generation changes invalidate RX work in both
-- children. System reset preserves their existing reset and pipeline behavior.
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
use surf.PtpPkg.all;

entity PtpRxTimestampTap is
   generic (
      TPD_G             : time                 := 1 ns;
      RST_POLARITY_G    : sl                   := '1';
      RST_ASYNC_G       : boolean              := false;
      PHY_TYPE_G        : string               := "XGMII";
      INGRESS_LATENCY_G : slv(63 downto 0)     := (others => '0');
      FIFO_DEPTH_G      : positive             := 4;
      MAX_FRAME_G       : PtpFrameCapacityType := PTP_ETH_MAX_FRAME_C);
   port (
      -- Common Ethernet/PHC clock domain.
      clk           : in  sl;
      rst           : in  sl;
      rxFlush       : in  sl;
      phyReady      : in  sl;
      phcTime       : in  PtpTimeType;
      phcStatus     : in  PtpPhcStatusType;
      captureAbort  : in  sl               := '0';

      -- Selected physical interface; no backpressure.
      xgmiiRxd      : in  slv(63 downto 0) := (others => '0');
      xgmiiRxc      : in  slv(7 downto 0)  := (others => '1');
      gmiiRxd       : in  slv(7 downto 0)  := (others => '0');
      gmiiRxDv      : in  sl               := '0';
      gmiiRxEr      : in  sl               := '0';

      -- Validated messages; transfer excludes rxAbort and system reset.
      message       : out PtpRxMessageType;
      messageValid  : out sl;
      messageReady  : in  sl;
      rxAbort       : out sl;
      queueOverflow : out sl;
      rxEpoch       : out slv(31 downto 0);
      counters      : out PtpRxCountersType);
end entity PtpRxTimestampTap;

architecture rtl of PtpRxTimestampTap is

   signal master  : AxiStreamMasterType;
   signal capture : PtpRxCaptureType;

begin

   U_Adapter : entity surf.PtpRxTimestampAdapter
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         PHY_TYPE_G        => PHY_TYPE_G,
         INGRESS_LATENCY_G => INGRESS_LATENCY_G)
      port map (
         clk          => clk,           -- [in]
         rst          => rst,           -- [in]
         rxFlush      => rxFlush,       -- [in]
         phyReady     => phyReady,      -- [in]
         phcTime      => phcTime,       -- [in]
         phcStatus    => phcStatus,     -- [in]
         captureAbort => captureAbort,  -- [in]
         xgmiiRxd     => xgmiiRxd,      -- [in]
         xgmiiRxc     => xgmiiRxc,      -- [in]
         gmiiRxd      => gmiiRxd,       -- [in]
         gmiiRxDv     => gmiiRxDv,      -- [in]
         gmiiRxEr     => gmiiRxEr,      -- [in]
         rxMaster     => master,        -- [out]
         rxCapture    => capture);      -- [out]

   U_Validator : entity surf.PtpRxFrontend
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         FIFO_DEPTH_G   => FIFO_DEPTH_G,
         MAX_FRAME_G    => MAX_FRAME_G)
      port map (
         clk           => clk,                   -- [in]
         rst           => rst,                   -- [in]
         rxFlush       => rxFlush,               -- [in]
         generation    => phcStatus.generation,  -- [in]
         rxMaster      => master,                -- [in]
         rxCapture     => capture,               -- [in]
         message       => message,               -- [out]
         messageValid  => messageValid,          -- [out]
         messageReady  => messageReady,          -- [in]
         rxAbort       => rxAbort,               -- [out]
         queueOverflow => queueOverflow,         -- [out]
         rxEpoch       => rxEpoch,               -- [out]
         counters      => counters);             -- [out]

end architecture rtl;
