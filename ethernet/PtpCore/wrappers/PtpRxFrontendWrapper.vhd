-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Thin cocotb adapter for physical and normalized PTP RX proof
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

entity PtpRxFrontendWrapper is
   generic (
      TPD_G             : time             := 1 ns;
      RST_POLARITY_G    : sl               := '1';
      RST_ASYNC_G       : boolean          := false;
      PHY_TYPE_G        : string           := "XGMII";
      FIFO_DEPTH_G      : positive         := 4;
      INGRESS_LATENCY_G : slv(63 downto 0) := (others => '0'));
   port (
      clk              : in  sl;
      rst              : in  sl;
      rxFlush          : in  sl               := '0';
      phyReady         : in  sl               := '1';
      generation       : in  slv(31 downto 0) := (others => '0');
      phcSeconds       : in  slv(47 downto 0) := (others => '0');
      phcNanoseconds   : in  slv(31 downto 0) := (others => '0');
      phcFraction      : in  slv(31 downto 0) := (others => '0');
      phcIncrement     : in  slv(63 downto 0) := x"0000000666666666";
      tickCount        : in  slv(63 downto 0) := (others => '0');
      timeValid        : in  sl               := '0';
      xgmiiRxd         : in  slv(63 downto 0) := (others => '0');
      xgmiiRxc         : in  slv(7 downto 0)  := (others => '1');
      gmiiRxd          : in  slv(7 downto 0)  := (others => '0');
      gmiiRxDv         : in  sl               := '0';
      gmiiRxEr         : in  sl               := '0';
      directValid      : in  sl               := '0';
      directData       : in  slv(63 downto 0) := (others => '0');
      directKeep       : in  slv(7 downto 0)  := (others => '0');
      directSof        : in  sl               := '0';
      directLast       : in  sl               := '0';
      directError      : in  sl               := '0';
      directPhase      : in  slv(2 downto 0)  := (others => '0');
      normValid        : out sl;
      normData         : out slv(63 downto 0);
      normKeep         : out slv(7 downto 0);
      normSof          : out sl;
      normLast         : out sl;
      normError        : out sl;
      normTime         : out slv(95 downto 0);
      normTicks        : out slv(63 downto 0);
      normPhase        : out slv(2 downto 0);
      normGeneration   : out slv(31 downto 0);
      normTimeValid    : out sl;
      normCaptureError : out sl;
      messageData      : out slv(PTP_RX_MESSAGE_BITS_C-1 downto 0);
      messageValid     : out sl;
      messageReady     : in  sl               := '1';
      rxAbort          : out sl;
      rxEpoch          : out slv(31 downto 0);
      acceptedCount    : out slv(31 downto 0);
      droppedCount     : out slv(31 downto 0);
      overflowCount    : out slv(31 downto 0));
end entity PtpRxFrontendWrapper;

architecture rtl of PtpRxFrontendWrapper is

   signal phcTime   : PtpTimeType;
   signal master    : AxiStreamMasterType;
   signal capture   : PtpRxCaptureType;
   signal rxMessage : PtpRxMessageType;
   signal flush     : sl;

begin

   -- The test supplies PHC samples; this wrapper contains no PHC or time model.
   -- Link loss flushes the frontend as well as stopping the physical adapter,
   -- preventing already queued records from surviving an unqualified link.
   phcTime.seconds     <= phcSeconds;
   phcTime.nanoseconds <= phcNanoseconds;
   phcTime.fraction    <= phcFraction;
   flush               <= rxFlush or not phyReady;

   -- Physical tests exercise the real adapter and validator together. The
   -- normalized signals below expose their boundary for the Python scoreboard.
   GEN_PHY : if PHY_TYPE_G /= "DIRECT" generate

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
            generation   => generation,    -- [in]
            phcTime      => phcTime,       -- [in]
            phcIncrement => phcIncrement,  -- [in]
            tickCount    => tickCount,     -- [in]
            timeValid    => timeValid,     -- [in]
            xgmiiRxd     => xgmiiRxd,      -- [in]
            xgmiiRxc     => xgmiiRxc,      -- [in]
            gmiiRxd      => gmiiRxd,       -- [in]
            gmiiRxDv     => gmiiRxDv,      -- [in]
            gmiiRxEr     => gmiiRxEr,      -- [in]
            rxMaster     => master,        -- [out]
            rxCapture    => capture);      -- [out]

   end generate GEN_PHY;

   -- DIRECT bypasses physical framing so tests can target exact validator
   -- edges, including empty EOF and completion simultaneous with overflow/reset.
   -- Capture inputs are already translated/calibrated in this mode.
   GEN_DIRECT : if PHY_TYPE_G = "DIRECT" generate
      comb : process (directValid, directData, directKeep, directSof, directLast, directError) is
         variable v : AxiStreamMasterType;
      begin
         v                    := AXI_STREAM_MASTER_INIT_C;
         v.tValid             := directValid;
         v.tData(63 downto 0) := directData;
         v.tKeep              := (others => '0');
         v.tKeep(7 downto 0)  := directKeep;
         v.tLast              := directLast;
         ssiSetUserSof(PTP_RX_AXIS_CONFIG_C, v, directSof);
         ssiSetUserEofe(PTP_RX_AXIS_CONFIG_C, v, directError);
         master               <= v;
      end process comb;
      capture.timestamp  <= phcSeconds & phcNanoseconds & phcFraction(31 downto 16);
      capture.ticks      <= tickCount;
      capture.tickPhase  <= directPhase;
      capture.generation <= generation;
      capture.increment  <= phcIncrement;
      capture.timeValid  <= timeValid;
      capture.error      <= '0';
   end generate GEN_DIRECT;

   -- Observation only: these ports add no queue or independent capture delay.
   -- The scoreboard samples valid/ready/abort before the rising-edge TPD update.
   normValid        <= master.tValid;
   normData         <= master.tData(63 downto 0);
   normKeep         <= master.tKeep(7 downto 0);
   normSof          <= ssiGetUserSof(PTP_RX_AXIS_CONFIG_C, master);
   normLast         <= master.tLast;
   normError        <= ssiGetUserEofe(PTP_RX_AXIS_CONFIG_C, master);
   normTime         <= capture.timestamp;
   normTicks        <= capture.ticks;
   normPhase        <= capture.tickPhase;
   normGeneration   <= capture.generation;
   normTimeValid    <= capture.timeValid;
   normCaptureError <= capture.error;
   messageData      <= toSlv(rxMessage);

   U_DUT : entity surf.PtpRxFrontend
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         FIFO_DEPTH_G   => FIFO_DEPTH_G)
      port map (
         clk           => clk,             -- [in]
         rst           => rst,             -- [in]
         rxFlush       => flush,           -- [in]
         generation    => generation,      -- [in]
         rxMaster      => master,          -- [in]
         rxCapture     => capture,         -- [in]
         message       => rxMessage,       -- [out]
         messageValid  => messageValid,    -- [out]
         messageReady  => messageReady,    -- [in]
         rxAbort       => rxAbort,         -- [out]
         rxEpoch       => rxEpoch,         -- [out]
         acceptedCount => acceptedCount,   -- [out]
         droppedCount  => droppedCount,    -- [out]
         overflowCount => overflowCount);  -- [out]

end architecture rtl;
