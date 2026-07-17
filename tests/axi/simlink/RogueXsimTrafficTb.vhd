-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Multi-instance Vivado xsim DPI-C live-traffic test harness
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Test methodology:
-- - Instantiate the full eight-instance topology -- four Stream, two Memory and
--   two SideBand xsim/DPI models -- each on its own endpoint pair, and exchange
--   a per-instance tagged traffic family with a dedicated external peer.
-- - Hold off all outbound traffic for a fixed settle delay after reset so the
--   peers are connected and draining first (accepted transport contract; no
--   readiness handshake).
-- - Each Stream instance drives inbound beats tagged 0x80+i and checks the
--   outbound byte equals its peer's 0x10+i.
-- - Each Memory instance is an AXI-Lite MASTER (driven by its peer's
--   write-then-read transaction); the TB acts as a tiny per-instance AXI-Lite
--   SLAVE that completes the write handshake, then returns this instance's
--   tagged data on the read. The observed awaddr/araddr is asserted equal to
--   0x100+0x10*i and the observed wdata equals this instance's tagged vector,
--   so cross-instance address/data leakage is caught.
-- - Each SideBand instance transmits its tagged opcode 0x60+i then remData
--   0x70+i outbound to its peer, and receives its peer's inbound opcode 0x20+i
--   and remData 0x40+i; the TB asserts the received tags match so a foreign
--   instance's opcode/remData is caught.
-- - Report the success banner only after all instances pass; $fatal on any
--   wrong/missing tag or wrong address. $fatal exits 0 under xsim -R, so pytest
--   judges success by the banner plus per-peer exit codes/JSON, not the xsim
--   return code.
--
-- Endpoint port map (single source of truth is shared with
-- test_RogueXsimTraffic.py -- keep both in sync):
--   Stream   i -> 19740 + 2*i  (19740..19747)
--   Memory   i -> 19748 + 2*i  (19748..19751)
--   SideBand i -> 19752 + 2*i  (19752..19755)
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity RogueXsimTrafficTb is
end entity RogueXsimTrafficTb;

architecture test of RogueXsimTrafficTb is

   constant CLK_HALF_C     : time    := 5 ns;
   constant SETTLE_EDGES_C : natural := 2000;   -- tuned later; generous margin
   -- Bounded busy-poll watchdog, shared across the Stream, Memory and SideBand
   -- families. This is deliberately large: the models receive their peer's
   -- request via a non-blocking ZMQ poll and the TB busy-polls the model I/O
   -- every edge, so nothing paces the (otherwise free-running) simulation to
   -- wall-clock while a peer process is still starting up and connecting. A
   -- tight watchdog can therefore burn out before a slow-to-start peer delivers
   -- its first request. At this bound the worst-case genuine hang runs ~10 s of
   -- wall-clock busy-poll before tripping -- comfortably covering peer startup
   -- jitter, and still well under the 120 s pytest run timeout. Each family
   -- exits this loop as soon as its traffic is exchanged, so the larger bound
   -- only affects the wait, never the happy path.
   constant WAIT_EDGES_C   : natural := 1000000;

   -- Number of single-beat inbound frames each Stream instance drives, and the
   -- inter-frame gap (in clock edges) between them. STREAM_FRAMES_C must match
   -- STREAM_TAG_FRAME_COUNT in rogue_tcp_peer.py.
   constant STREAM_FRAMES_C : natural := 3;
   constant IB_GAP_EDGES_C  : natural := 5;

   -- Edges to keep the SideBand tx* values driven after the remData change, so
   -- the model's synchronous ZMQ send of the outbound remData frame is issued
   -- (and the peer can drain it) before the banner can stop the sim.
   constant SB_SEND_GUARD_C : natural := 8;

   signal clock : std_logic := '0';
   signal reset : std_logic := '1';

   type slv32_array is array (natural range <>) of std_logic_vector(31 downto 0);
   type slv8_array  is array (natural range <>) of std_logic_vector(7 downto 0);

   signal sObValid : std_logic_vector(3 downto 0);
   signal sObData  : slv32_array(3 downto 0);
   signal sIbValid : std_logic_vector(3 downto 0) := (others => '0');
   signal sIbData  : slv32_array(3 downto 0)      := (others => (others => '0'));
   signal sIbKeep  : slv8_array(3 downto 0)       := (others => (others => '0'));
   signal sIbLast  : std_logic_vector(3 downto 0) := (others => '0');

   signal streamDone : std_logic_vector(3 downto 0) := (others => '0');

   -- Memory instances: the DUT drives the AXI-Lite master ports (m*), the TB
   -- responds as a slave (arready/rdata/rresp/rvalid, awready/wready/bresp/
   -- bvalid) via per-instance responder processes.
   signal mArAddr  : slv32_array(1 downto 0);
   signal mArValid : std_logic_vector(1 downto 0);
   signal mRReady  : std_logic_vector(1 downto 0);
   signal mArReady : std_logic_vector(1 downto 0) := (others => '0');
   signal mRData   : slv32_array(1 downto 0)      := (others => (others => '0'));
   signal mRValid  : std_logic_vector(1 downto 0) := (others => '0');

   signal mAwAddr  : slv32_array(1 downto 0);
   signal mAwValid : std_logic_vector(1 downto 0);
   signal mWData   : slv32_array(1 downto 0);
   signal mWValid  : std_logic_vector(1 downto 0);
   signal mBReady  : std_logic_vector(1 downto 0);
   signal mAwReady : std_logic_vector(1 downto 0) := (others => '0');
   signal mWReady  : std_logic_vector(1 downto 0) := (others => '0');
   signal mBValid  : std_logic_vector(1 downto 0) := (others => '0');

   signal memDone : std_logic_vector(1 downto 0) := "00";

   -- SideBand instances: the DUT (TB) drives tx* to transmit outbound to its
   -- peer and observes rx* for the peer's inbound opcode/remData.
   signal sbTxOpCode   : slv8_array(1 downto 0)      := (others => (others => '0'));
   signal sbTxOpCodeEn : std_logic_vector(1 downto 0) := (others => '0');
   signal sbTxRemData  : slv8_array(1 downto 0)      := (others => (others => '0'));
   signal sbRxOpCode   : slv8_array(1 downto 0);
   signal sbRxOpCodeEn : std_logic_vector(1 downto 0);
   signal sbRxRemData  : slv8_array(1 downto 0);

   signal sbDone : std_logic_vector(1 downto 0) := "00";

begin

   clock <= not clock after CLK_HALF_C;

   GEN_STREAM : for i in 0 to 3 generate
      U_STREAM : entity work.RogueTcpStream
         port map (
            clock      => clock,
            reset      => reset,
            portNum    => std_logic_vector(to_unsigned(19740 + (2*i), 16)),
            ssi        => '0',
            obValid    => sObValid(i),
            obReady    => '1',
            obDataLow  => sObData(i),
            obDataHigh => open,
            obUserLow  => open,
            obUserHigh => open,
            obKeep     => open,
            obLast     => open,
            ibValid    => sIbValid(i),
            ibReady    => open,
            ibDataLow  => sIbData(i),
            ibDataHigh => (others => '0'),
            ibUserLow  => (others => '0'),
            ibUserHigh => (others => '0'),
            ibKeep     => sIbKeep(i),
            ibLast     => sIbLast(i));
   end generate GEN_STREAM;

   GEN_STREAM_DRV : for i in 0 to 3 generate
      -- One process per instance handles both directions concurrently: it
      -- counts outbound (ob) frames on EVERY edge from reset deassert, and
      -- after a fixed settle drives three inbound (ib) frames. Outbound must
      -- be watched continuously because obReady is hardwired '1', so the
      -- model presents each peer-pushed frame for a single edge as soon as it
      -- arrives (well before the inbound-drive phase); a counter that only
      -- looked after the settle would miss those early frames. streamDone is
      -- asserted only once BOTH the three inbound frames have been driven and
      -- three outbound frames have been counted, so the banner cannot stop
      -- the sim before every peer has exchanged its full tagged family.
      drv : process is
         variable expByte : std_logic_vector(7 downto 0);
         variable tagByte : std_logic_vector(7 downto 0);
         variable rxCount : natural := 0;
         variable waited  : natural := 0;
         variable phase   : natural := 0;  -- edges elapsed during settle
         variable frame   : natural := 0;  -- inbound frames driven so far
         variable step    : natural := 0;  -- sub-step within one inbound frame
      begin
         wait until reset = '0';
         tagByte := std_logic_vector(to_unsigned((16#80# + i), 8));
         expByte := std_logic_vector(to_unsigned((16#10# + i), 8));

         loop
            wait until rising_edge(clock);
            waited := waited + 1;

            -- Outbound: count each single-beat frame the model presents.
            if sObValid(i) = '1' then
               assert sObData(i)(7 downto 0) = expByte
                  report "Stream " & integer'image(i) & ": wrong outbound tag" severity failure;
               rxCount := rxCount + 1;
            end if;

            -- Inbound: after the settle, push three frames, one every few
            -- edges, deasserting valid the edge after each single beat.
            if phase < SETTLE_EDGES_C then
               phase := phase + 1;
            elsif frame < STREAM_FRAMES_C then
               if step = 0 then
                  sIbData(i)  <= tagByte & tagByte & tagByte & tagByte;
                  sIbKeep(i)  <= x"0F";
                  sIbLast(i)  <= '1';
                  sIbValid(i) <= '1';
                  step        := 1;
               elsif step = 1 then
                  sIbValid(i) <= '0';
                  sIbLast(i)  <= '0';
                  step        := 2;
               elsif step < IB_GAP_EDGES_C then
                  step := step + 1;
               else
                  step  := 0;
                  frame := frame + 1;
               end if;
            end if;

            exit when (frame = STREAM_FRAMES_C) and (rxCount >= STREAM_FRAMES_C);

            assert waited < WAIT_EDGES_C
               report "Stream " & integer'image(i) & ": timed out exchanging traffic" severity failure;
         end loop;

         streamDone(i) <= '1';
         wait;
      end process drv;
   end generate GEN_STREAM_DRV;

   GEN_MEMORY : for i in 0 to 1 generate
      U_MEMORY : entity work.RogueTcpMemory
         port map (
            clock   => clock,
            reset   => reset,
            portNum => std_logic_vector(to_unsigned(19748 + (2*i), 16)),
            -- axiReadMaster (DUT drives)
            araddr  => mArAddr(i),
            arprot  => open,
            arvalid => mArValid(i),
            rready  => mRReady(i),
            -- axiReadSlave (TB drives)
            arready => mArReady(i),
            rdata   => mRData(i),
            rresp   => "00",
            rvalid  => mRValid(i),
            -- axiWriteMaster (DUT drives)
            awaddr  => mAwAddr(i),
            awprot  => open,
            awvalid => mAwValid(i),
            wdata   => mWData(i),
            wstrb   => open,
            wvalid  => mWValid(i),
            bready  => mBReady(i),
            -- axiWriteSlave (TB drives)
            awready => mAwReady(i),
            wready  => mWReady(i),
            bresp   => "00",
            bvalid  => mBValid(i));
   end generate GEN_MEMORY;

   GEN_MEMORY_RSP : for i in 0 to 1 generate
      -- Per-instance AXI-Lite slave responder. The Memory model is the master:
      -- its peer sends a write-then-read transaction, so the model first
      -- presents a write (awvalid & wvalid) and then a read (arvalid). We
      -- complete each handshake by sampling the master outputs every edge in a
      -- bounded loop, mirroring the native _memory_cycle timing -- the model
      -- holds a request until its ready is seen, then drops it, so we must not
      -- assume the request persists. Outbound is held off until the same
      -- SETTLE_EDGES_C the Stream drivers use, so the memory peer is connected
      -- and draining before the model tries its synchronous response send.
      rsp : process is
         constant expAddr : std_logic_vector(31 downto 0) :=
            std_logic_vector(to_unsigned(16#100# + (16#10# * i), 32));
         -- Tagged read data packed little-endian: bytes
         -- [0x40+i,0x50+i,0x60+i,0x70+i] -> rdata(7:0)=0x40+i ... (31:24)=0x70+i.
         constant rdataTag : std_logic_vector(31 downto 0) :=
            std_logic_vector(to_unsigned(16#70# + i, 8)) &
            std_logic_vector(to_unsigned(16#60# + i, 8)) &
            std_logic_vector(to_unsigned(16#50# + i, 8)) &
            std_logic_vector(to_unsigned(16#40# + i, 8));
         variable waited : natural := 0;
         variable phase  : natural := 0;

         procedure tick is
         begin
            wait until rising_edge(clock);
            waited := waited + 1;
            assert waited < WAIT_EDGES_C
               report "Memory " & integer'image(i) & ": timed out on handshake"
               severity failure;
         end procedure tick;
      begin
         wait until reset = '0';

         -- Settle: let the peer connect and start draining before the model
         -- issues its first (synchronous-send) response.
         while phase < SETTLE_EDGES_C loop
            tick;
            phase := phase + 1;
         end loop;

         -- WRITE handshake: wait for the model (ST_START) to present awvalid &
         -- wvalid; both are held until the model sees their ready in ST_WRESP.
         while not (mAwValid(i) = '1' and mWValid(i) = '1') loop
            tick;
         end loop;
         assert mAwAddr(i) = expAddr
            report "Memory " & integer'image(i) & ": wrong write address"
            severity failure;
         -- The peer writes the same tagged vector it later expects to read
         -- back (rdataTag); checking it here covers write-data isolation --
         -- a foreign instance's payload would differ.
         assert mWData(i) = rdataTag
            report "Memory " & integer'image(i) & ": wrong write data"
            severity failure;

         -- Accept address+data and complete the response in one step: the FSM's
         -- ST_WRESP samples awready, wready and bvalid together, drops awvalid/
         -- wvalid and sends the write response on the edge it sees them. Hold
         -- all three until awvalid drops (the observable completion; bready is
         -- pinned high by the model and never falls, so do not wait on it).
         mAwReady(i) <= '1';
         mWReady(i)  <= '1';
         mBValid(i)  <= '1';
         while mAwValid(i) = '1' loop
            tick;
         end loop;
         mAwReady(i) <= '0';
         mWReady(i)  <= '0';
         mBValid(i)  <= '0';

         -- READ handshake: wait for the model (ST_START) to present arvalid.
         while mArValid(i) /= '1' loop
            tick;
         end loop;
         assert mArAddr(i) = expAddr
            report "Memory " & integer'image(i) & ": wrong read address"
            severity failure;

         -- Accept the read address; the model (ST_RADDR) drops arvalid and
         -- advances to ST_RDATA on the edge it sees arready.
         mArReady(i) <= '1';
         while mArValid(i) = '1' loop
            tick;
         end loop;
         mArReady(i) <= '0';

         -- In ST_RDATA the model captures rdata/rresp on the edge it sees
         -- rvalid, then sends the read response and returns to idle (rready is
         -- pinned high, so there is no ready-fall to observe). Present the
         -- tagged data and hold rvalid across a short guard so the single
         -- capture edge cannot be missed to delta-ordering, then release.
         mRData(i)  <= rdataTag;
         mRValid(i) <= '1';
         for e in 0 to 3 loop
            tick;
         end loop;
         mRValid(i) <= '0';

         memDone(i) <= '1';
         wait;
      end process rsp;
   end generate GEN_MEMORY_RSP;

   GEN_SIDEBAND : for i in 0 to 1 generate
      U_SIDEBAND : entity work.RogueSideBand
         port map (
            clock      => clock,
            reset      => reset,
            portNum    => std_logic_vector(to_unsigned(19752 + (2*i), 16)),
            txOpCode   => sbTxOpCode(i),
            txOpCodeEn => sbTxOpCodeEn(i),
            txRemData  => sbTxRemData(i),
            rxOpCode   => sbRxOpCode(i),
            rxOpCodeEn => sbRxOpCodeEn(i),
            rxRemData  => sbRxRemData(i));
   end generate GEN_SIDEBAND;

   GEN_SIDEBAND_DRV : for i in 0 to 1 generate
      -- One process per instance handles both directions concurrently. The
      -- peer pushes its inbound opcode/remData frames at startup, and the model
      -- pulses rxOpCodeEn for a SINGLE clock the edge it drains the opcode (rx
      -- opcode/remData then latch), so -- like the Stream outbound path -- rx*
      -- must be sampled on EVERY edge from reset deassert; a checker that only
      -- looked after the settle could miss the pulse. Outbound tx is held off
      -- until the same SETTLE_EDGES_C the other families use, so the peer is
      -- connected and draining before the model issues its synchronous sends:
      -- txOpCodeEn is strobed high for one clock (model sends opcode 0x60+i),
      -- then after a short gap txRemData is changed to 0x70+i (model forwards
      -- the remData, carrying the opcode along). sbDone(i) is asserted only
      -- once BOTH the inbound opcode+remData have been observed AND the
      -- outbound frames have been driven and held past the send guard.
      drv : process is
         variable txOp    : std_logic_vector(7 downto 0);
         variable txRem   : std_logic_vector(7 downto 0);
         variable expOp   : std_logic_vector(7 downto 0);
         variable expRem  : std_logic_vector(7 downto 0);
         variable rxOpCap : std_logic_vector(7 downto 0) := (others => '0');
         variable rxRemCap : std_logic_vector(7 downto 0) := (others => '0');
         variable gotOp   : std_logic := '0';
         variable gotRem  : std_logic := '0';
         variable txDone  : boolean   := false;
         variable waited  : natural   := 0;
         variable phase   : natural   := 0;  -- edges elapsed during settle
         variable step    : natural   := 0;  -- sub-step within the tx sequence
      begin
         wait until reset = '0';
         txOp   := std_logic_vector(to_unsigned((16#60# + i), 8));
         txRem  := std_logic_vector(to_unsigned((16#70# + i), 8));
         expOp  := std_logic_vector(to_unsigned((16#20# + i), 8));
         expRem := std_logic_vector(to_unsigned((16#40# + i), 8));

         loop
            wait until rising_edge(clock);
            waited := waited + 1;

            -- Inbound: capture the one-clock rxOpCodeEn pulse and the first
            -- nonzero rxRemData (reset clears rxRemData to 0x00).
            if gotOp = '0' and sbRxOpCodeEn(i) = '1' then
               rxOpCap := sbRxOpCode(i);
               gotOp   := '1';
            end if;
            if gotRem = '0' and sbRxRemData(i) /= x"00" then
               rxRemCap := sbRxRemData(i);
               gotRem   := '1';
            end if;

            -- Outbound: after the settle, strobe the opcode for one clock,
            -- gap, then change remData; hold both past the send guard.
            if phase < SETTLE_EDGES_C then
               phase := phase + 1;
            elsif not txDone then
               if step = 0 then
                  sbTxOpCode(i)   <= txOp;
                  sbTxOpCodeEn(i) <= '1';
                  step            := 1;
               elsif step = 1 then
                  sbTxOpCodeEn(i) <= '0';
                  step            := 2;
               elsif step < IB_GAP_EDGES_C then
                  step := step + 1;
               elsif step = IB_GAP_EDGES_C then
                  sbTxRemData(i) <= txRem;
                  step           := step + 1;
               elsif step < IB_GAP_EDGES_C + SB_SEND_GUARD_C then
                  step := step + 1;
               else
                  txDone := true;
               end if;
            end if;

            exit when (gotOp = '1') and (gotRem = '1') and txDone;

            assert waited < WAIT_EDGES_C
               report "SideBand " & integer'image(i) & ": timed out exchanging traffic"
               severity failure;
         end loop;

         assert rxOpCap = expOp
            report "SideBand " & integer'image(i) & ": wrong inbound opcode"
            severity failure;
         assert rxRemCap = expRem
            report "SideBand " & integer'image(i) & ": wrong inbound remData"
            severity failure;

         sbDone(i) <= '1';
         wait;
      end process drv;
   end generate GEN_SIDEBAND_DRV;

   banner : process is
   begin
      for e in 0 to 2 loop
         wait until rising_edge(clock);
      end loop;
      reset <= '0';
      wait until (streamDone = "1111") and (memDone = "11") and (sbDone = "11");
      report "Rogue xsim traffic test passed" severity note;
      stop;
      wait;
   end process banner;

end architecture test;
