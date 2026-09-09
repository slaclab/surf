# SimLink HDL Integration

Use the three record-based `Rogue*Wrap` entities as the downstream VHDL
interface. They preserve one design-facing contract across GHDL, VCS, and
Vivado xsim; only the simulator leaf and native shared library change.

Start with [getting started](getting-started.md) if the simulator environment
and Rogue packages are not ready yet. Software connections are covered in the
[Rogue client guide](rogue-clients.md).

## Import and backend selection

The top-level SURF `ruckus.tcl` imports `simlink/ruckus.tcl`. A downstream
project that already imports SURF should not list the SimLink leaves or backend
directories itself. The manifest loads:

- `simlink/sim/`, containing the public simulation components; and
- exactly one of `simlink/ghdl`, `simlink/vcs`, or `simlink/xsim`.

Set `RUCKUS_SIM_BACKEND=ghdl`, `vcs`, or `xsim` before the project simulation
target when automatic environment detection would be ambiguous. SimLink
sources are simulation-only and do not belong in a synthesis source set.

## Direction convention

Wrapper signal names use the DUT's point of view:

| Wrapper path | VHDL direction | Meaning |
| --- | --- | --- |
| Stream `sAxisMaster/sAxisSlave` | DUT to Rogue | The DUT is the AXI Stream source; Rogue receives the frame |
| Stream `mAxisMaster/mAxisSlave` | Rogue to DUT | Rogue supplies an AXI Stream frame to the DUT |
| Memory AXI-Lite masters | Rogue to DUT | Rogue initiates reads and writes against the simulated register map |
| SideBand `tx*` | DUT to Rogue | The DUT publishes opcode events or local-data state |
| SideBand `rx*` | Rogue to DUT | Rogue supplies opcode events or remote-data state |

Each wrapper binds only to loopback. Remote-host use is outside the current
SimLink transport contract.

## Allocate port pairs first

Every live leaf owns an adjacent TCP pair `N/N+1`, even if traffic happens in
only one direction. Use base ports from 1024 through 49151 and make the pairs
disjoint across all Stream channels, Memory links, SideBand links, and other
simulator processes on the host.

One simple allocation is:

| Function | Base port | Reserved pair |
| --- | ---: | --- |
| Stream VC 0 | 9000 | 9000/9001 |
| Stream VC 1 | 9002 | 9002/9003 |
| Memory | 9010 | 9010/9011 |
| SideBand | 9032 | 9032/9033 |

The process-wide registry rejects a changed port after initialization and any
overlap between live instances, including an overlap between different model
types. A bind error can still occur when a different process owns the pair.

## Reset, clock, and startup

The wrappers are clocked models. Hold reset asserted while the rest of the
testbench initializes, then keep the clock running and release reset. The leaf
captures its port and creates its worker-owned sockets on the first rising edge
after reset is released:

```text
elaborate -> clock with reset asserted -> release reset -> rising edge
 -> bind N/N+1 -> print Listening message -> exchange traffic
```

The Rogue process may be created before or after the bind because ZeroMQ
connection establishment is asynchronous. Memory users should call
`waitReady()` before the first register transaction. Stream and SideBand users
need an application-level or test-orchestration barrier when first-frame loss
would matter.

Reset clears model-visible transaction state but does not change the configured
base port. Keep each wrapper in one clock/reset domain and use normal SURF CDC
or reset primitives outside it when the DUT crosses domains.

## Memory wrapper

`RogueTcpMemoryWrap` presents an AXI-Lite master. Connect it to the same
crossbar or subordinate used by a hardware control path:

```vhdl
U_RogueMemory : entity surf.RogueTcpMemoryWrap
   generic map (
      TPD_G      => TPD_G,
      PORT_NUM_G => 9010)
   port map (
      axilClk         => axilClk,         -- [in]
      axilRst         => axilRst,         -- [in]
      axilReadMaster  => axilReadMaster,  -- [out]
      axilReadSlave   => axilReadSlave,   -- [in]
      axilWriteMaster => axilWriteMaster, -- [out]
      axilWriteSlave  => axilWriteSlave); -- [in]
```

The link carries 32-bit AXI-Lite operations. Preserve the subordinate's normal
`OKAY`, `SLVERR`, and `DECERR` behavior; SimLink returns the completion to the
Rogue transaction rather than hiding it. The production readiness probe uses
the socket request/response path but intentionally generates no AXI-Lite
cycle.

## Single-channel Stream wrapper

`AXIS_CONFIG_G` is the actual DUT-side AXI Stream configuration. The foreign
boundary adopts its `TDATA_BYTES_C` value from 1 through 128 and the internal
resizers normalize `TKEEP` and `TUSER` representation without changing the
payload width.

This eight-byte example uses explicit record initialization and accepts SSI
metadata:

```vhdl
constant SIM_AXIS_CONFIG_C : AxiStreamConfigType := (
   TSTRB_EN_C    => false,
   TDATA_BYTES_C => 8,
   TDEST_BITS_C  => 8,
   TID_BITS_C    => 0,
   TKEEP_MODE_C  => TKEEP_NORMAL_C,
   TUSER_BITS_C  => 8,
   TUSER_MODE_C  => TUSER_NORMAL_C);

signal simTxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
signal simTxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
signal simRxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
signal simRxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

U_RogueStream : entity surf.RogueTcpStreamWrap
   generic map (
      TPD_G         => TPD_G,
      PORT_NUM_G    => 9000,
      SSI_EN_G      => true,
      CHAN_COUNT_G  => 1,
      TDEST_MASK_G  => x"02",
      AXIS_CONFIG_G => SIM_AXIS_CONFIG_C)
   port map (
      axisClk     => axisClk,     -- [in]
      axisRst     => axisRst,     -- [in]
      sAxisMaster => simTxMaster, -- [in]
      sAxisSlave  => simTxSlave,  -- [out]
      mAxisMaster => simRxMaster, -- [out]
      mAxisSlave  => simRxSlave); -- [in]
```

With one channel, all HDL-to-Rogue frames use the one port pair regardless of
their input `TDEST`. `TDEST_MASK_G` sets `TDEST` on Rogue-to-HDL frames; in the
example the DUT receives `x"02"`. Set `SSI_EN_G=false` for a raw AXI Stream
whose first-user, last-user, and error fields must not be interpreted as SSI.

`TKEEP` controls which byte lanes enter the Rogue frame, and `TLAST` completes
it. A DUT that never asserts `TLAST` can eventually exceed the 20,000,000-byte
model limit and fail rather than silently truncate the frame.

## Multi-channel Stream wrapper

One wrapper can expose several Rogue `TcpClient` instances behind a routed AXI
Stream interface. For the usual dense mapping, set `CHAN_COUNT_G` and leave
`CHAN_MASK_G=x"00"`:

```vhdl
U_RogueStreams : entity surf.RogueTcpStreamWrap
   generic map (
      TPD_G         => TPD_G,
      PORT_NUM_G    => 9000,
      SSI_EN_G      => true,
      CHAN_COUNT_G  => 4,
      CHAN_MASK_G   => x"00",
      AXIS_CONFIG_G => SIM_AXIS_CONFIG_C)
   port map (
      axisClk     => axisClk,     -- [in]
      axisRst     => axisRst,     -- [in]
      sAxisMaster => simTxMaster, -- [in]
      sAxisSlave  => simTxSlave,  -- [out]
      mAxisMaster => simRxMaster, -- [out]
      mAxisSlave  => simRxSlave); -- [in]
```

The resulting mapping is:

| AXI `TDEST` route | Rogue client base | Pair |
| ---: | ---: | --- |
| 0 | 9000 | 9000/9001 |
| 1 | 9002 | 9002/9003 |
| 2 | 9004 | 9004/9005 |
| 3 | 9006 | 9006/9007 |

For HDL-to-Rogue traffic, `sAxisMaster.tDest` selects the client. For
Rogue-to-HDL traffic, the mux sets `mAxisMaster.tDest` to the route associated
with the client that supplied the frame.

Non-power-of-two `CHAN_COUNT_G` values are supported; for example, three
channels use routes 0, 1, and 2. A nonzero `CHAN_MASK_G` overrides
`CHAN_COUNT_G`, creates `2**popcount(CHAN_MASK_G)` channels, and uses every
subset of the mask as a route. For example, `CHAN_MASK_G=x"0C"` creates routes
0, 4, 8, and 12, whose base ports are 9000, 9008, 9016, and 9024. Check the
largest derived pair against other allocations.

`TDEST_MASK_G` is only meaningful when the effective channel count is one.

## SideBand wrapper

SideBand carries one-cycle opcode events and retained remote-data state:

```vhdl
U_RogueSideBand : entity surf.RogueSideBandWrap
   generic map (
      TPD_G      => TPD_G,
      PORT_NUM_G => 9032)
   port map (
      sysClk     => sysClk,      -- [in]
      sysRst     => sysRst,      -- [in]
      txOpCode   => txOpCode,    -- [in]
      txOpCodeEn => txOpCodeEn,  -- [in]
      txRemData  => localData,   -- [in]
      rxOpCode   => rxOpCode,    -- [out]
      rxOpCodeEn => rxOpCodeEn,  -- [out]
      rxRemData  => remoteData); -- [out]
```

Pulse `txOpCodeEn` for one clock to publish `txOpCode`. Changes to `txRemData`
are sent as state updates. A received opcode raises `rxOpCodeEn` for one clock;
`rxRemData` retains the most recently received byte.

The PGP simulation wrappers provide durable allocation examples. They reserve
one Stream pair per virtual channel and place SideBand at a fixed unused
offset: PGP2b uses `PORT_NUM_G+8`, while PGP3, PGP4, and HTSP use
`PORT_NUM_G+32`. Preserve the complete reserved range when composing those
wrappers with another SimLink instance.

## Optional Stream pacing

The three rate generics apply only to `RogueTcpStreamWrap`:

```vhdl
AXIS_CLK_FREQ_G       => 100.0E+6,
S_AXIS_PAYLOAD_RATE_G => 1.0E+9,
M_AXIS_PAYLOAD_RATE_G => 1.0E+9
```

Rates are aggregate payload bits per simulated second, not wire rate. The
`S_AXIS` budget is shared before the channel demultiplexer, and the `M_AXIS`
budget is shared after the channel multiplexer. Zero is the compatibility
bypass. When either rate is nonzero, `AXIS_CLK_FREQ_G` must be positive and the
requested rate must not exceed
`8 * AXIS_CONFIG_G.TDATA_BYTES_C * AXIS_CLK_FREQ_G`.

Pacing counts only bytes selected by `TKEEP` on completed handshakes. It does
not assign a simulation timestamp to software-generated frames, so it controls
serialization after admission rather than host-process launch timing.

## Integration checklist

- Import the top-level SURF manifest and load exactly one backend.
- Instantiate `Rogue*Wrap`, not a backend leaf or cocotb flat wrapper.
- Allocate every complete `N/N+1` pair, including derived Stream channels.
- Match the wrapper clock/reset domain to the connected AXI interface.
- Keep the simulator clock running after reset release.
- Treat Stream `sAxis` as DUT-to-Rogue and `mAxis` as Rogue-to-DUT.
- Supply `TLAST`, `TKEEP`, and SSI metadata consistent with `AXIS_CONFIG_G`.
- Set a positive clock frequency whenever Stream pacing is enabled.
- Use Memory `waitReady()` or an explicit application barrier before traffic.

The checked wrapper sources are
[`RogueTcpStreamWrap.vhd`](../sim/RogueTcpStreamWrap.vhd),
[`RogueTcpMemoryWrap.vhd`](../sim/RogueTcpMemoryWrap.vhd), and
[`RogueSideBandWrap.vhd`](../sim/RogueSideBandWrap.vhd).
