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
--   write-then-read transaction); the TB wires it to its OWN instance of
--   surf.AxiDualPortRam acting as a real AXI-Lite SLAVE (a block RAM). The
--   peer writes this instance's tagged vector to 0x100+0x10*i, then reads it
--   back -- a real RAM returns exactly what was written, so the peer's own
--   read-back equality check still proves isolation, and because each instance
--   owns a distinct RAM, cross-instance leakage is impossible by construction.
--   A lightweight per-instance concurrent assertion additionally checks the
--   observed awaddr/araddr equals 0x100+0x10*i so a wrong-address regression
--   still $fatals inside the TB.
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity RogueXsimTrafficTb is
end entity RogueXsimTrafficTb;

architecture test of RogueXsimTrafficTb is

   constant CLK_HALF_C     : time    := 5 ns;
   -- Fixed sim-time hold-off (Option B, see design.md "Readiness"): no
   -- outbound HDL traffic is driven for this many clock edges after reset
   -- deassert. Its purpose is to guarantee the DUT does not issue a
   -- (synchronous, blocking) outbound ZMQ send before its peer is connected
   -- and draining -- the accepted transport contract, since the ported Rogue-
   -- TCP protocol has no readiness handshake. What actually establishes
   -- connectedness is the SIM ORDERING enforced by the test: each peer is
   -- Popen'd after xelab, just before the xsim run, so by the time reset
   -- deasserts the peers have already imported and connected. This constant
   -- is therefore defense-in-depth against startup jitter, not the primary
   -- guarantee. At 5 ns half-period the clock period is 10 ns, and the settle
   -- loop counts one rising_edge per period (10 ns/edge), so 2000 edges is
   -- ~20 us of sim time -- microseconds of wall-clock -- a generous margin
   -- that stress testing (10 clean + 6 under full-core load) showed zero
   -- instability. Do NOT reduce below this value; increase (and note the new
   -- margin) only if instability appears.
   constant SETTLE_EDGES_C : natural := 2000;
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

   -- Memory instances: each Memory model is an AXI-Lite MASTER whose raw scalar
   -- master/slave ports are wired directly to the record-typed AXI-Lite buses of
   -- its OWN surf.AxiDualPortRam slave (a real block RAM). Record-typed buses per
   -- instance -- the model drives the *Master fields, the RAM drives the *Slave
   -- fields, and both the RAM and the TB assertion observe the same records.
   signal memReadMaster  : AxiLiteReadMasterArray(1 downto 0)  := (others => AXI_LITE_READ_MASTER_INIT_C);
   signal memReadSlave   : AxiLiteReadSlaveArray(1 downto 0);
   signal memWriteMaster : AxiLiteWriteMasterArray(1 downto 0) := (others => AXI_LITE_WRITE_MASTER_INIT_C);
   signal memWriteSlave  : AxiLiteWriteSlaveArray(1 downto 0);

   -- RAM address width in WORDS (1024 words); the peer's byte addresses
   -- 0x100+0x10*i are word-aligned and fit comfortably.
   constant MEM_ADDR_WIDTH_C : positive := 10;

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
      -- Expected AXI byte address the peer transacts against for this instance;
      -- a foreign instance's address would differ (in-DUT cross-talk check).
      constant EXP_ADDR_C : std_logic_vector(31 downto 0) :=
         std_logic_vector(to_unsigned(16#100# + (16#10# * i), 32));
   begin

      -- The Memory model is the AXI-Lite MASTER: its raw scalar ports are
      -- glued directly to this instance's record-typed AXI-Lite bus. The model
      -- drives the *Master fields; the RAM below drives the *Slave fields.
      U_MEMORY : entity work.RogueTcpMemory
         port map (
            clock   => clock,
            reset   => reset,
            portNum => std_logic_vector(to_unsigned(19748 + (2*i), 16)),
            -- axiReadMaster (model drives -> record master fields)
            araddr  => memReadMaster(i).araddr,
            arprot  => memReadMaster(i).arprot,
            arvalid => memReadMaster(i).arvalid,
            rready  => memReadMaster(i).rready,
            -- axiReadSlave (RAM drives -> model inputs)
            arready => memReadSlave(i).arready,
            rdata   => memReadSlave(i).rdata,
            rresp   => memReadSlave(i).rresp,
            rvalid  => memReadSlave(i).rvalid,
            -- axiWriteMaster (model drives -> record master fields)
            awaddr  => memWriteMaster(i).awaddr,
            awprot  => memWriteMaster(i).awprot,
            awvalid => memWriteMaster(i).awvalid,
            wdata   => memWriteMaster(i).wdata,
            wstrb   => memWriteMaster(i).wstrb,
            wvalid  => memWriteMaster(i).wvalid,
            bready  => memWriteMaster(i).bready,
            -- axiWriteSlave (RAM drives -> model inputs)
            awready => memWriteSlave(i).awready,
            wready  => memWriteSlave(i).wready,
            bresp   => memWriteSlave(i).bresp,
            bvalid  => memWriteSlave(i).bvalid);

      -- Real AXI-Lite slave: a per-instance block RAM. The peer writes this
      -- instance's tagged vector then reads it back; a real RAM returns exactly
      -- what was written, so the peer's own read-back equality check passes and
      -- proves isolation (each instance owns a DISTINCT RAM, so cross-instance
      -- leakage is impossible by construction). SYNTH_MODE_G="inferred" keeps
      -- the closure free of XPM/vendor primitives.
      U_MEMORY_RAM : entity surf.AxiDualPortRam
         generic map (
            SYNTH_MODE_G  => "inferred",
            MEMORY_TYPE_G => "block",
            READ_LATENCY_G => 2,
            AXI_WR_EN_G   => true,
            COMMON_CLK_G  => true,
            ADDR_WIDTH_G  => MEM_ADDR_WIDTH_C,
            DATA_WIDTH_G  => 32)
         port map (
            axiClk         => clock,
            axiRst         => reset,
            axiReadMaster  => memReadMaster(i),
            axiReadSlave   => memReadSlave(i),
            axiWriteMaster => memWriteMaster(i),
            axiWriteSlave  => memWriteSlave(i));
      -- Standard Port side (clk/en/we/addr/din/dout/...) left at defaults; only
      -- the AXI side is exercised.

      -- Preserved isolation safety net (option a): whenever the model asserts a
      -- write/read address it must equal this instance's expected address, so a
      -- wrong-address regression still $fatals inside the TB even though a plain
      -- RAM would otherwise silently accept any in-range address.
      assert (memWriteMaster(i).awvalid /= '1') or (memWriteMaster(i).awaddr = EXP_ADDR_C)
         report "Memory " & integer'image(i) & ": wrong write address"
         severity failure;
      assert (memReadMaster(i).arvalid /= '1') or (memReadMaster(i).araddr = EXP_ADDR_C)
         report "Memory " & integer'image(i) & ": wrong read address"
         severity failure;

      -- Completion detector. The model runs a write-then-read: it first drives
      -- a write (completing when bvalid & bready handshake) and then a read
      -- (completing when rvalid & rready handshake). memDone(i) asserts once
      -- BOTH have been observed, so the banner cannot stop the sim before this
      -- instance's full transaction has been serviced by its RAM.
      done : process is
         variable waited  : natural := 0;
         variable wrote   : boolean := false;
         variable readback : boolean := false;
      begin
         wait until reset = '0';
         loop
            wait until rising_edge(clock);
            waited := waited + 1;

            if (memWriteSlave(i).bvalid = '1') and (memWriteMaster(i).bready = '1') then
               wrote := true;
            end if;
            if (memReadSlave(i).rvalid = '1') and (memReadMaster(i).rready = '1') then
               readback := true;
            end if;

            exit when wrote and readback;

            assert waited < WAIT_EDGES_C
               report "Memory " & integer'image(i) & ": timed out on transaction"
               severity failure;
         end loop;

         memDone(i) <= '1';
         wait;
      end process done;
   end generate GEN_MEMORY;

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
