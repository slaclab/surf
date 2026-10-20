-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Timing-port RX to the RTL backend's validated PTP records.
--
-- Replaces PtpRxTimestampTap in the timing-port build. The port delivers
-- MAC-accepted frames, FCS stripped, 16 bytes per beat with backpressure and
-- the complete capture in metadata on every beat. An AxiStreamResize narrows
-- each frame to the shared PtpRxFrontend's 8-byte input, holding every port
-- beat until both halves are emitted. The resize may emit the narrowed SOF
-- in the same cycle the port's SOF beat transfers, so the frontend sees the
-- port's live metadata capture on that cycle and a copy registered on the
-- transfer edge afterwards; either way it is the capture of the frame whose
-- SOF it samples. The
-- frontend runs with FCS_PRESENT_G = false, so its parsing, validation, queue,
-- abort and counters are those of the tapped build.
--
-- The port drains stored frames at the frontend's full 8 bytes per cycle,
-- without the wire's preamble and gap, which is faster than the frontend
-- decodes minimum-length records. The port's SOF beat therefore enters the
-- resize only while the frontend's frameReady shows room for the frame still
-- ending in the resize and this one; a SOF beat already offered to the
-- resize stays offered. A backlog waits in the port, whose RX table then
-- bounds it, instead of overflowing the frontend queue. Records, ready, abort and
-- overflow keep the tap's interface. Contract: ethernet/PtpCore/timing-port.md
-- section 11.1.
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
use surf.EthMacPkg.all;
use surf.PtpPkg.all;

entity PtpMacPortRxAdapter is
   generic (
      TPD_G          : time                 := 1 ns;
      RST_POLARITY_G : sl                   := '1';
      RST_ASYNC_G    : boolean              := false;
      FIFO_DEPTH_G   : positive             := 4;
      TLV_EN_G       : boolean              := true;
      MAX_FRAME_G    : PtpFrameCapacityType := PTP_ETH_MAX_FRAME_C);
   port (
      -- Common Ethernet/PHC clock domain
      clk        : in  sl;
      rst        : in  sl;
      rxFlush    : in  sl;
      generation : in  slv(31 downto 0);

      -- Timing-port RX frames with metadata
      portRxMaster : in  PtpMacPortRxMasterType;
      portRxReady  : out sl;

      -- Validated messages; transfer excludes rxAbort and system reset
      messageMaster : out PtpRxMessageMasterType;
      messageReady  : in  sl;
      rxAbort       : out sl;
      queueOverflow : out sl;
      rxEpoch       : out slv(31 downto 0);
      counters      : out PtpRxCountersType);
end entity PtpMacPortRxAdapter;

architecture rtl of PtpMacPortRxAdapter is

   type RegType is record
      capture : PtpRxCaptureType;
      -- A beat offered to the resize stays offered until it transfers.
      offered : sl;
   end record;

   constant REG_INIT_C : RegType := (
      capture => PTP_RX_CAPTURE_INIT_C,
      offered => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal resizeSlave  : AxiStreamSlaveType;
   signal narrowMaster : AxiStreamMasterType;
   signal capture      : PtpRxCaptureType;
   signal frameReady   : sl;
   signal gatedMaster  : AxiStreamMasterType;

begin

   U_Resize : entity surf.AxiStreamResize
      generic map (
         TPD_G               => TPD_G,
         RST_POLARITY_G      => RST_POLARITY_G,
         RST_ASYNC_G         => RST_ASYNC_G,
         SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => PTP_RX_AXIS_CONFIG_C)
      port map (
         axisClk     => clk,                       -- [in]
         axisRst     => rst,                       -- [in]
         sAxisMaster => gatedMaster,               -- [in]
         sAxisSlave  => resizeSlave,               -- [out]
         mAxisMaster => narrowMaster,              -- [out]
         mSideBand   => open,                      -- [out]
         mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C); -- [in]

   comb : process (all) is
      variable v        : RegType;
      variable hold     : boolean;
      variable gated    : AxiStreamMasterType;
      variable sofEnter : boolean;
   begin
      v := r;

      -- The port's ready is the resize's, except that a SOF beat waits for
      -- the frontend's queue; the frontend itself never backpressures. Only
      -- a beat not yet offered may wait: an offered one keeps tValid.
      hold  := ssiGetUserSof(EMAC_AXIS_CONFIG_C, portRxMaster.frame) = '1' and frameReady = '0' and
               r.offered = '0';
      gated := portRxMaster.frame;
      if hold then
         gated.tValid := '0';
      end if;
      v.offered := gated.tValid and not resizeSlave.tReady;

      -- The frame's capture travels in metadata; latch it as its SOF beat
      -- enters the resize.
      sofEnter := gated.tValid = '1' and resizeSlave.tReady = '1' and
                  ssiGetUserSof(EMAC_AXIS_CONFIG_C, gated) = '1';

      if sofEnter then
         v.capture := portRxMaster.meta.capture;
      end if;

      -- Sideband aligned with the narrowed SOF: live on the entry cycle, which
      -- the resize may pass straight through, registered thereafter.
      if sofEnter then
         capture <= portRxMaster.meta.capture;
      else
         capture <= r.capture;
      end if;

      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;

      rin <= v;

      gatedMaster <= gated;
      if hold then
         portRxReady <= '0';
      else
         portRxReady <= resizeSlave.tReady;
      end if;
   end process comb;

   seq : process (clk, rst) is
   begin

      if RST_ASYNC_G and rst = RST_POLARITY_G then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;

   end process seq;

   U_Validator : entity surf.PtpRxFrontend
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         FIFO_DEPTH_G   => FIFO_DEPTH_G,
         TLV_EN_G       => TLV_EN_G,
         MAX_FRAME_G    => MAX_FRAME_G,
         FCS_PRESENT_G  => false)
      port map (
         clk           => clk,            -- [in]
         rst           => rst,            -- [in]
         rxFlush       => rxFlush,        -- [in]
         generation    => generation,     -- [in]
         rxMaster      => narrowMaster,   -- [in]
         rxCapture     => capture,        -- [in]
         messageMaster => messageMaster,  -- [out]
         messageReady  => messageReady,   -- [in]
         queueOverflow => queueOverflow,  -- [out]
         frameReady    => frameReady,     -- [out]
         rxAbort       => rxAbort,        -- [out]
         rxEpoch       => rxEpoch,        -- [out]
         counters      => counters);      -- [out]

end architecture rtl;
