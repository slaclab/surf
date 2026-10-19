# Timing-port contract

Source and transport contract for a timing-capable Ethernet MAC port: complete
frames with associated wire captures on receive, cookie-tracked requests with
terminal completions on transmit, and a replaceable controller behind them.
The declarations live in [EthMacPkg](../EthMacCore/rtl/EthMacPkg.vhd) and
[PtpPkg](rtl/PtpPkg.vhd); this guide fixes their meaning, the MAC-stage audit
that selected the carrier, the supported modes and the DMA projection.

**Status (October 18, 2026): Phase 1 implementation and simulation gates closed.**
The GMII/XGMII timing leaves, retire owners, forced-abort sequencer,
`PtpMacPort` and `PtpMacPortEthMac` are committed in `744fdcbc2`; merge
`babf2234e` adds the default-MAC regression suite. The third contract review
traced the implemented capture, admission, release and abort paths. It found
that RX checksum checking could erase a bad-FCS frame's EOFE before the
FIFO, so the port now retains `doneError` as a rejected-frame verdict until
MAC retirement or output consumption. The focused reproducer fails on both
PHYs before that fix. Current verification is recorded in §8.

The review also clarifies the physical capture edge, the uniform Ethernet
byte cap, completion capacity, stale-request generation and the aggregate
owner-abort acknowledgement. These are the interfaces for the subsequent
independent-PHC and backend work. The legacy `EthMacPtpEndpoint` composition
and passive taps remain usable; their contracts are in [interfaces.md](interfaces.md).
No AXI-Lite port bank, timing-port area/routing qualification or hardware
result is implied. The [composable PTP plan](../../../../../docs/plans/composable-ptp/README.md)
owns phase status; §10 maps this contract to the implementation.

## 1. Scope and modes

| Supported | Not in initial timing mode |
| --- | --- |
| GMII at 125 MHz and XGMII at 156.25 MHz, one continuously running Ethernet/PHC clock. | XLGMII, GMII 10/100 clock enables, clock-enable gating. |
| Store-and-forward delivery of good frames, FCS stripped, 1500-byte network MTU, no VLAN stripping (tagged frames pass through untouched up to the byte limit). | Jumbo frames, VLAN offload, one-step TX timestamp insertion. |
| Ordinary post-transmission timestamps; capture at the first destination-MAC octet. | Correction-field editing, PHY/PCS-plane capture providers. |
| Pause RX/TX, MAC-address filter, IPv4/UDP/TCP checksum offload (RX check, TX insertion). | RoCEv2 (`ROCEV2_EN_G`) — its iCRC stage is unaudited for tokens and elaboration must reject the combination. |
| One controller per port, selected at elaboration. | Runtime backend handover; two controllers transmitting PTP or steering one PHC. |

The timing port is a build-time alternative to the legacy composition, not a
mode bit inside it. Elaboration assertions reject unsupported combinations.

## 2. Decision D1: tag-through with an opt-in TID token

### 2.1 Stage audit

Each MAC stage was read at SURF `ecbf833a2` for how it treats `tId` and where
it can consume a frame without emitting it. "Record copy" means the stage
assigns the whole `AxiStreamMasterType`, which preserves `tId`.

| Direction | Stage | `tId` through the stage | Frame consumed without output | Existing indication |
| --- | --- | --- | --- | --- |
| TX | `EthMacTxFifo` (primary and bypass `AxiStreamFifoV2`) | Packed; width is the lesser of `PRIM_CONFIG_G`/`BYP_CONFIG_G` and `INT_EMAC_AXIS_CONFIG_C` | None | — |
| TX | `EthMacTxBypass` | Record copy | None; interleaves the two inputs at frame boundaries | — |
| TX | `EthMacTxCsum` | Record copy into `sMaster`; `Fifo_Cache` packs with `INT_EMAC_AXIS_CONFIG_C`; record copy into `txMaster` | **Yes:** `DROP_ERR_PKT_G` clears `tValid` for the whole frame after the cache when EOFE was detected. **Oversize is broken today:** the oversize branch (lines 385-401) writes a transaction and enters `BLOWOFF_S` without forwarding a `tLast` into `Fifo_Cache`, so the read side keeps the error transaction open across the *next* frame, drops that frame too, and `Fifo_Trans` is permanently off by one. The port never presents an oversize frame (§4), so this path is unreachable in timing mode, but it is a latent MAC defect to file separately. | None |
| TX | `EthMacTxRoCEv2` | Not audited | Not audited | Rejected in timing mode |
| TX | `EthMacTxPause` | Record copy in `PASS_S` | None; **inserts** a 46-byte pause frame from `AXI_STREAM_MASTER_INIT_C` (`tId` = 0). **Holds** tokened frames while `locPauseCnt /= 0`; that counter survives `phyReady` loss and is cleared only by `ethRst` or `pauseEnable = '0'`. | `pauseTx` pulse |
| TX | `EthMacTxExportXgmii` | `DATA_MUX` packs 128→64 with `AXI_CONFIG_C` derived from `INT_EMAC_AXIS_CONFIG_C` | **No dump exists:** `curState` is forced to `ST_IDLE_C` on every cycle `phyReady = '0'` (line 190), so `ST_DUMP_C` is unreachable; a frame at SOF during link loss is **held** in `DATA_MUX` and transmitted when the link returns. A frame mid-flight at link loss has its FSM reset while `DATA_MUX` keeps the remainder, which is then sent as a new, correctly-CRC'd frame with a fresh preamble. Underrun transmits with inverted FCS. | `txLinkNotReady` (combinational level while IDLE sees `tValid` with `phyReady = '0'`), `txUnderRun` pulse |
| TX | `EthMacTxExportGmii` | `AxiStreamResize` copies `tId` | **Yes:** `DUMP_S` on `phyReady = '0'` at SOF. `phyReady` is checked only in `IDLE_S` (line 172); a frame mid-flight at link loss is driven to completion on the dead link. Underrun asserts `gmiiTxEr` and dumps. | `txLinkNotReady`, `txUnderRun` pulses |
| RX | `EthMacRxImportXgmii` | Builds a fresh master with `tId` = 0; `AxiStreamResize` 64→128 copies it | **Partial frames are not discarded:** on `phyReady = '0'` the shift chain and CRC state reset (line 326) but the output pipeline (`intAdvance`, `intLastLine`, lines 460-515) resets only on `ethRst`, so the importer keeps emitting `tValid` beats with **no `tLast`** until the following frame's end; that following frame's SOF lands mid-stream. A nested `/S/` without `/T/` (lines 357-373) re-asserts `frameShift0` and re-initializes the CRC: the first frame is terminated with a bad CRC at the eventual `/T/` and the nested frame's bytes are appended to it. | None |
| RX | `EthMacRxImportGmii` | Builds a fresh master; `DATA_MUX` packs 8→128 with `INT_EMAC_AXIS_CONFIG_C` | **Yes:** `WAIT_DATA_S` returns to `WAIT_SFD_S` if `RX_DV` drops or `RX_ER` asserts within the first four octets, emitting no beat. After that, `RX_ER` or `phyReady = '0'` emits `tLast`+EOFE (line 187). | None |
| RX | `EthMacRxPause` | Record copy in `PASS_S` | **Yes:** every frame whose first beat matches the pause DMAC/type/opcode is consumed, regardless of FCS, including a single-beat header match. | `rxPauseReq` pulse (good FCS only; not a per-frame consumption indication) |
| RX | `EthMacRxCsum` | Record copy through the pipeline array | **Yes, indirectly:** on `byteCnt > 1500` (16-byte granular, so up to 1520 delivered) it forces `tLast`+EOFE and enters `BLOWOFF_S`, which discards every beat **of the following frame** until a `tLast` arrives if the current frame has none (the XGMII link-loss case above). | `tUser` error bits |
| RX | `EthMacRxBypass` | Record copy | None; routes by EtherType to the bypass FIFO, whose frames the port does not see | — |
| RX | `EthMacRxFilter` | Record copy | **Yes:** `tValid` cleared for the frame on address mismatch or `dropOnPause` | None |
| RX | `EthMacRxFifo` (`SsiFifo`, `VALID_THOLD_G = 0` under `DROP_ERR_PKT_G`) | Packed; width is the lesser of `INT_EMAC_AXIS_CONFIG_C` and `PRIM_CONFIG_G`/`BYP_CONFIG_G` | **Yes, two mechanisms, one owner:** `SsiIbFrameFilter` on overflow at the SOF beat swallows the frame; on **mid-frame** overflow it writes a synthetic `tLast`+EOFE onto the already-stored partial frame (lines 252-281) and `SsiObFrameFilter` drops that stored frame later on the read side (lines 131-141). `PREVENT_LOCKUP` (active because `VALID_THOLD_G /= 1`) can pulse `fifoRst` and discard all stored frames while the filters keep their state. No stage checks runts. | `sAxisDropFrame` → `rxFifoDrop` (inbound only); `mAxisDropFrame` and `lockupRstEvent` **unconnected** |
| Both | `EthMacTxShift` / `EthMacRxShift` | `AxiStreamShift` copies `tId` | None | Not instantiated by `EthMacTop` |

Two facts decide the carrier. Every stage that rebuilds a master record copies
`tId`, so no state machine needs a new field. Every stage that loses `tId` is
a stream FIFO whose packed width is `min(slave, master) TID_BITS_C`, and all of
them take at least one side from `INT_EMAC_AXIS_CONFIG_C` or `PRIM_CONFIG_G`.
Replacing those with a configuration that has TID bits restores the token end
to end, with no change to the default constants other MAC users see.

The audit also shows that several promises an earlier draft made about
existing MAC behaviour are false: there is no XGMII dump at SOF, neither
exporter handles mid-frame link loss, the XGMII importer does not terminate a
frame on link loss or nested start, the RX FIFO's two drop mechanisms act on
one frame, and no drop indication carries a token. §2.4, §4.0 and §6 therefore
state **required leaf and FIFO changes**, not existing behaviour, and the
elaboration generics in §5 pin the configuration those changes assume.

### 2.2 Carrier selection

| Mechanism | Decision |
| --- | --- |
| **Tag-through (TID)** | **Selected.** `EMAC_TIMING_AXIS_CONFIG_C` adds eight TID bits to the internal configuration. A timing-capable `EthMacTop` threads it through `EthMacTxFifo`, `EthMacTxCsum.Fifo_Cache`, the exporter `DATA_MUX`/resize, the importer `DATA_MUX`/resize and `EthMacRxFifo`; record-copy stages need no change. Packed FIFO word grows from 141 to 149 bits, which exceeds the 2×72-bit BRAM aspect the current width was chosen for; measure, do not assume, the area cost. |
| Additional TUSER | Alternative only if the TID path is rejected on review. TUSER is already allocated (first: FRAG, SOF; last: EOFE, IPERR, TCPERR, UDPERR) and `TUSER_FIRST_LAST_C` mode transports only the first and last byte's fields through FIFOs, so a frame-wide token would have to be duplicated on both. Rejected as the baseline. |
| Wire identity | Retained for the legacy observers (`PtpDelayReqObserver`) and as the test oracle. Cannot distinguish identical arbitrary frames and would need controller-supplied match keys. Not the port baseline. |
| Order-based | Rejected. `EthMacTxBypass` interleaves two inputs, `EthMacTxPause` inserts frames with no request and the drop points above shift positional association silently. |

`TDEST` stays at zero bits internally; `EthMacTxCsum` and `EthMacRxCsum` write
`tDest(0)` for RoCEv2 and that use is not disturbed. No cookie is hidden in
`TDEST`.

### 2.3 Token rules

- Width eight (`EMAC_TOKEN_BITS_C`), bounded by `AxiStreamMasterType.tId`.
  Token zero (`EMAC_TOKEN_NONE_C`) means **unowned**: generated pause frames,
  legacy traffic admitted without a reservation. Tokens 1..255 index the
  port's table; `EMAC_TOKEN_COUNT_C` is the outstanding limit per direction.
- The port allocates a token at admission (TX request SOF, or RX wire start)
  and the token travels on **every beat** of the frame. Stages that copy the
  record preserve this automatically; a reviewer checks that no new stage
  constructs a master from `AXI_STREAM_MASTER_INIT_C` for a tokened frame.
- **Wire finished and ownership released are different events.** A table
  entry passes through at most three states: *allocated*, *wire-resolved*
  (a `done` or wire-plane retire has fixed the capture and outcome), and
  *released*. Release happens only when the last downstream reference is
  gone:
  - TX: the completion record has been **accepted** by the controller
    (`completionReady` with valid), or the request was consumed before
    admission and no completion is owed.
  - RX: the frame's last beat has been **accepted** by the controller, or a
    `retire` pulse has confirmed the frame was consumed by a MAC stage, or
    forced abort has cleared every owner (§6).
  A token is never reallocated while any FIFO, filter, completion slot or
  consumer can still reference it; `rxLost` retirement (§2.4) is the only
  release without a `done`, and it is proven by the wire, not by time.
- At most one terminal event resolves an entry. A `done` followed by a
  `retire` for the same token (a frame that reached the wire and was then
  filtered or dropped by the RX FIFO) is the normal RX case, not a double
  release: `done` resolves the wire state, `retire` releases ownership. A
  second `done` or a `retire` after release is a protocol fault counted in
  the port's fault register and must be caught in simulation.
- Exhaustion stops admission (TX backpressure; RX counted drop). It never
  aliases an older token.

### 2.4 Leaf events

Capture and completion are **not** derived by joining a second framer to the
MAC through a FIFO. The timing-capable import/export leaves publish
`EthMacFrameEventType` at the MAC-side pins: `start` with the lane and token
of the first destination-MAC octet, `done` with the token, wire error and
Ethernet length of the frame that just finished.

**Capture alignment.** `ptpRxCapture` computes the timestamp from `phcTime`
at the edge it is evaluated; `ticks` is provenance only. The legacy adapter
evaluates it on the same edge that decodes the lane from the pin word, with
`phcStatus.increment/generation/timeValid` and `captureAbort` from that same
edge ([PtpRxTimestampAdapter.vhd:253-256](rtl/PtpRxTimestampAdapter.vhd)).
The port must produce an identical result, so:

- The oracle's tuple is the PHC state **as it stands during the cycle in
  which the pin word is present on the MAC-side pins**: for RX, the cycle
  before the importer samples the word; for TX, the cycle after the exporter
  loads its output register. The leaf registers `start` on the edge that
  **ends** that cycle, and the port registers its own copy of `phcTime`,
  `phcStatus` and `captureAbort` on every edge. On the edge after `start`
  becomes visible, the port's copy holds exactly the tuple the oracle used;
  the port evaluates `ptpRxCapture` from that copy. The result is identical
  to the oracle, delayed one cycle.

  | | RX (importer) | TX (exporter) |
  | --- | --- | --- |
  | Pin word `W` present on pins | cycle (N, N+1] | cycle (N, N+1], after the output register loaded `W` at edge N |
  | Oracle tuple | `phcTime`/`phcStatus`/`captureAbort` values established at edge N, read as inputs during (N, N+1] | same |
  | Oracle registers its capture | edge N+1 | edge N+1 |
  | Leaf registers `start`/`startLane`/`startToken` | edge N+1 (the sampling edge) | edge N+1 (one edge **after** launch; never on the launch edge) |
  | Port registers PHC copy `C` | every edge; `C` at edge N+1 holds the edge-N values | same |
  | Port evaluates `ptpRxCapture(C, lane, …)` and ORs `C.captureAbort` | during (N+1, N+2], registers at N+2 | same |

  An event may be coincident with the pins (as above) but may never lead
  them: a `start` raised from exporter state before `W` is on the pins has
  no oracle tuple and is prohibited.
- Subtracting cycles from `ticks` is **not** an alignment mechanism and is
  prohibited; it leaves `timestamp`, `increment`, `generation`, `timeValid`
  and inhibition from the wrong edge.
- If a leaf cannot be pin-coincident, the leaf consumes the PHC state itself
  and publishes the complete `PtpRxCaptureType` beside `start`. That is a
  different leaf interface and must be declared as such; it is not the
  baseline. The GMII leaves need no such interface: `EthMacRxImportTimingGmii`
  registers `start` on the edge that samples the first destination-MAC octet,
  and the timing `EthMacTxExportGmii` one edge after launching it, both the
  edge on which the passive adapter registers its capture (§8). The legacy
  `EthMacRxImportGmii`, whose SFD detection is not pin-qualified and which is
  blind to the pins for three cycles after each frame, is not used in timing
  mode.
- `captureAbort` from the pin-sample edge is ORed into `capture.error`
  exactly as the legacy adapter does. A SET/PHASE admitted on that edge
  inhibits the capture; one admitted a cycle later does not.

Phase 1 verification must drive RATE, SET and PHASE commits on the pin-sample
edge, one cycle before, and one cycle after, for both PHYs and both XGMII
start lanes, and show bit-identical captures between the port and the passive
adapter oracle. A generation change or `captureAbort` between `start` and
`done` clears `captureValid` on the TX completion (§4).

**Start qualification.** The timing-capable leaves locate the first
destination-MAC octet with the passive adapter's rule, not today's importer
rule: GMII requires seven `0x55` preamble octets then `0xD5` with `RX_DV`
high and `RX_ER` low throughout; XGMII requires `/S/` in lane 0 or 4, six
`0x55` data octets and `0xD5`, and treats a data-valued `0xFB` as data. A
frame with a shortened or corrupted preamble is drained to its terminator
with no `start` and no beats, counted in `rxLost`. This makes the oracle
comparison in §8 total: every frame either produces a `start` in both the
leaf and the adapter, or in neither.

**Retire sources.** Stages that consume a tokened frame publish
`EthMacTokenRetireType`, with the token latched from the beat that caused the
drop (today's drop pulses are bare and one cycle late; the timing-mode stage
must carry the token to the pulse):

| Owner | Retires when | Notes |
| --- | --- | --- |
| Port TX admission | Shape/length/generation rejection (§4) | Before the MAC; the port's own store, not a MAC stage. |
| `EthMacTxCsum` | EOFE frame dropped after `Fifo_Cache` | Oversize never reaches it (§4). |
| Exporter | `phyReady = '0'` at SOF: dump through `tLast` | **Required change** (§4.0); the XGMII dump is unreachable today. |
| `EthMacRxPause` | Any frame whose first beat matches the pause header, regardless of FCS or length | Not `rxPauseReq`, which fires only for good-FCS pause frames. |
| `EthMacRxFilter` | Address mismatch or `dropOnPause` | — |
| `EthMacRxFifo` | **One pulse per frame across two indices** (`EMAC_RX_RETIRE_FIFO_IB_C`, `_OB_C`): the inbound filter retires only when it swallows the SOF beat (nothing stored); otherwise the synthetic `tLast`+EOFE terminator reaches the outbound filter, which retires on the read-side drop. | **Required change:** connect `mAxisDropFrame` with the token (`SsiFifo`/`SsiObFrameFilter` now publish `mAxisDropTId`); suppress the inbound pulse for mid-frame overflow. |
| Port RX output stage | A frame marked *rejected* at `done` (wire error or length outside 60..1518, §3) reaches the FIFO output; the stage consumes it through `tLast` and retires at that beat | No MAC stage checks runts and `EthMacRxCsum` admits up to 1520. The token stays owned while the rejected bytes are buffered. |
| Timing-capable importer | Frame whose sampled `nextToken` was `EMAC_TOKEN_NONE_C` | Emits **no beats** for it, drains to its terminator and publishes `start`/`done` with token zero; the port counts `rxDropped`. Nothing untokened enters packet storage (§3). Not a retire. |
| Timing-capable importer (`EMAC_RX_RETIRE_IMPORT_C`) | Owned start that ended before any frame byte followed the four FCS octets | Replaces `done` for that start; no beat exists anywhere; the port counts `rxLost`. Token zero is never retired. |

Every source is a separate owner and at most one pulse per source per cycle.
Under forced abort (§6) owners publish **no** retire; they discard and
acknowledge, and the port releases every remaining entry once after all
acknowledgements.

**Importer termination on link loss or nested start.** Today the XGMII
importer leaves `tValid` high with no `tLast` after `phyReady` falls, and a
nested `/S/` without `/T/` appends the second frame to the first (§2.1). The
timing-capable importers must, on `phyReady` falling or on an illegal nested
start while a frame is open, emit exactly one `tLast`+EOFE beat for the open
frame and one `done` with `doneError = '1'` and the open token, then emit
nothing until the next qualified start. The nested frame produces no `start`
and no beats and is counted in `rxLost`. With this rule, `EthMacRxCsum`'s
`BLOWOFF_S` can never swallow a following frame, because every frame on its
input has a `tLast`.

**Abandoned RX starts.** With the start-qualification rule above, a GMII
start whose frame ends (RX_DV low, RX_ER or `phyReady` loss) after one to
four octets is the only way a leaf publishes `start` without `done`: those
octets can only be FCS, so no frame byte exists. The leaf then emits no beat
and publishes a `retire` with the token on the edge it ends the frame; the
port counts it in `rxLost`. No capture or beat exists downstream, so release
is immediate. A frame with at least one byte beyond the FCS octets ends in
`done` (with `doneError` when its CRC fails). Every start has exactly one
terminal event from the leaf itself. A burst whose first destination-MAC
cycle is not a clean octet has no start; it is reported as `lost`, matching
the passive adapter, which takes no capture for it.

The passive `PtpRxTimestampAdapter`/`PtpTxTimestampTap` path remains the
legacy composition's producer and the independent oracle in regressions: a
timing-port test compares every port capture against the passive adapter's
capture for the same frame.

## 3. Receive transaction

`PtpMacPortRxMasterType` carries an SSI stream (`frame`) and `PtpMacPortRxMetaType`
(`meta`) in the port's primary configuration; the reverse ready is separate.

| Rule | Contract |
| --- | --- |
| Delivery | Store-and-forward. The SOF beat is presented only after the frame's `done` event has been observed with `doneError = '0'`, the MAC-address/pause/checksum stages accepted it and FIFO storage holds it completely. `meta` is valid on every beat and stable until the last beat is accepted. |
| Ownership | The RX table entry is *wire-resolved* at `done` and **released** only when the controller accepts the last beat, or a `retire` confirms the frame was consumed (pause, filter, FIFO overflow, FIFO error drop), or forced abort clears every owner. A frame stalled in `EthMacRxFifo` or at the consumer keeps its token and capture; a later `retire` for it releases the entry without a second `done`. |
| FCS | Stripped by the existing importer; `frameLength` counts destination MAC through the last payload byte. Minimum delivered length is 60 (padding retained); the port applies a uniform 1518-byte cap, independent of EtherType or VLAN tags. A controller enforcing a 1500-byte network MTU permits 1514 untagged or 1518 with one tag; the port does not parse headers to enforce that network policy (§5). |
| Capture | Complete `PtpRxCaptureType` at the first destination-MAC octet, aligned per §2.4. `capture.error` marks an unusable timestamp (epoch range or capture inhibited) but does **not** suppress the frame; `capture.timeValid` reports clock quality and may be low during acquisition. |
| Transport generation | `meta.transportGeneration` is the live generation when the frame's wire `start` was admitted (§6.1). A consumer discards frames whose generation it has not observed. |
| Dropped frames | Never appear. `rxDropped` counts tokened frames consumed by a MAC stage, by the port's length/token-zero stages, or released by forced abort; `rxLost` counts abandoned and unqualified starts (§2.4). Loss is counted, never re-associated. |
| Counting rule | Every token increments exactly one `PtpMacPortCountersType` field, at its **release** event: a CRC-bad RX frame counts in `rxDropped` when a MAC drop retires it or the port consumes its last buffered beat, never at `done`. Counters saturate. `PtpRxCountersType` is the legacy frontend's unrelated diagnostic record and is not mapped onto these. |
| Token allocation | The port holds a registered `nextToken` (or `EMAC_TOKEN_NONE_C` when the table is full) that the import leaf samples on the pin edge of the first destination-MAC octet, stamps on every beat and echoes in `start`. The echoed value is the allocation; the port's table entry is created on the `start` edge. |
| Admission under pressure | If `nextToken` was `EMAC_TOKEN_NONE_C` at start, the timing-capable importer emits **no beats** for the frame: it drains to the terminator and publishes `start`/`done` with token zero, which the port counts in `rxDropped`. No untokened frame enters packet storage, so the RX FIFO holds at most *table depth* frames and is sized for `tableDepth × maxFrameWords + tableDepth` words (one synthetic terminator per frame); overflow is then impossible, the inbound-overflow retire is a fault indication, and the §6 lockup-monitor argument holds. Dropping at the FIFO output instead would let unbounded token-zero traffic queue behind one stalled tokened frame. The wire cannot be backpressured. PTP frames have no reserved priority in the initial port; coexistence policy belongs to the composition. |
| Wire verdict and length | At `done`, `doneError = '1'` or `doneLength` below 60 or above 1518 marks the entry *rejected*. The wire verdict is independent of EOFE because the legacy checksum stage can overwrite it. The bytes are already buffered, so the token stays owned; the port's RX output stage consumes the rejected frame through `tLast` and releases the entry at that beat (`rxDropped`). `EthMacRxCsum` admits up to 1520 and nothing checks runts, so this is a port stage. |
| Sidebands at the port boundary | Delivered frames carry SSI SOF on the first beat; EOFE is never set (the FIFO error drop and port wire-verdict check enforce this, except for the explicit abort terminator in §6); `FRAG`, `IPERR`, `TCPERR`, `UDPERR` are forwarded as the MAC set them and are informational. `tId` is cleared to zero and `tDest` is zero at the port output; the token is never exposed to the controller. |
| Generation change mid-frame | A frame whose `phcStatus.generation` at `done` differs from `capture.generation` is delivered with `capture.error = '1'`; it is not dropped. The passive adapter discards such a frame, so §8's oracle comparison excludes frames the adapter dropped on a generation change and checks only that the port flagged them. |

The timing port does **not** instantiate the legacy RX bypass drain or
`PtpPrimaryGuard`. The selected controller owns untagged `0x88F7` on both
directions. Attaching the new records to the old application stream is not a
substitute for this path.

## 4. Transmit request and completion

`PtpMacPortTxMasterType` carries an SSI stream (`frame`) and
`PtpMacPortTxRequestType` (`request`), meaningful on the SOF beat. The reverse
ready is separate. `PtpMacPortTxCompletionMasterType` returns one terminal
completion per accepted request through a valid/ready channel.

| Rule | Contract |
| --- | --- |
| Admission | The port accepts the SOF beat only after reserving a token, a table entry and a completion slot. Otherwise it withholds ready; the controller sees ordinary stream backpressure. The SOF beat must be a **full 16-byte beat** carrying SSI SOF, the complete 14-byte Ethernet header and `request` with `transportGeneration` equal to the live generation; a stale generation is consumed through EOF and completed `FLUSHED` without reaching the MAC. `request.frameLength` must be **16..1518**: 14- and 15-byte frames are not supported (they cannot fill the first beat) and are completed `DISCARDED` with anything outside the range. The MAC pads short frames to at least 60: the GMII exporter emits **61** octets for 16..59-byte frames (60 for a 60-byte frame), and `doneLength` reports the padded wire length. |
| Stream shape | The port counts bytes from `tKeep` on each accepted beat. On `tLast`, if the count differs from `request.frameLength`, or if any beat before `tLast` has non-full `tKeep`, the frame is **completed `DISCARDED`** and the MAC never sees it: the port holds the frame in its own store until `tLast` is validated, so no partial frame can enter `EthMacTxFifo`. A second SOF before `tLast` discards the current frame `DISCARDED` and the new SOF is evaluated as a fresh request. A beat without SOF when no frame is open is consumed through `tLast`, counted in `txRejected`, and receives no completion because it carried no request context. EOFE set on `tLast` is treated as a controller-declared abort: `DISCARDED`. |
| Missing EOF | A frame whose `tLast` has not arrived after `frameLength + 64` accepted bytes is `DISCARDED` and the stream is drained to the next SOF. This bound is the controller's own declaration plus slack, not a wall-clock timeout. |
| Cookie | 32-bit opaque (`PtpMacPortCookieType`), returned unchanged. It identifies a local request lifetime; it is not a PTP sequence number and the RTL backend keeps its protocol ledger. |
| Capture | Taken at the wire `start` event for the frame's token, aligned per §2.4, and retained until `done`. `captureValid` requires the start capture, `capture.error = '0'`, and no `phcStatus.generation` change or `captureAbort` between the start edge and the `done` edge. |
| Outcome | `SENT`: `done` with `doneError = '0'`. `WIRE_ERR`: `done` with `doneError = '1'` (underrun, link loss or forced abort while the frame is on the pins). `DISCARDED`: consumed before the exporter launched it (port admission/shape checks, checksum error drop, PHY-not-ready dump at SOF). `FLUSHED`: **never produced a wire `start`** — released by forced abort while still in the hold store or MAC FIFOs, or admitted with a stale generation. A frame that has a `start` always completes through its `done`, never `FLUSHED`. |
| Every admitted request completes | The `timestamp` flag controls capture, not retirement. A request without `timestamp` still receives a completion with `captureValid = '0'`. Only `txRejected` frames (no SOF, no request context) receive nothing. Beats drained after a nested-SOF or missing-EOF discard belong to the discarded frame and are not separately counted. |
| Capture when `captureValid = '0'` | `capture` is `PTP_RX_CAPTURE_INIT_C` with `generation` set to the PHC generation at retirement; envelope status bits 3 and 4 are zero. `WIRE_ERR` reported before the first frame octet was driven (GMII underrun on the first data beat) also clears `captureValid`, because the oracle has no capture for that frame. |
| Ordering | Completions are **not** ordered with respect to admission: an admission-time `DISCARDED` precedes earlier frames still in the MAC. Completions for frames that reach the wire are delivered in wire order. The only association is `cookie` with `transportGeneration`. |
| Sidebands | The SOF beat must be a full 16-byte beat with SSI SOF, EOFE clear, and `tId`/`tDest` ignored (the port overwrites `tId` with its token and `tDest` with zero). EOFE set on `tLast` is a controller-declared abort (`DISCARDED`). |
| Ownership | The TX entry is *wire-resolved* by `done` or a wire-plane `retire`, and **released** only when the completion is accepted by the controller. The completion slot is reserved at admission, so the channel can hold its record through ready indefinitely without blocking the wire; it is the only place a completion waits. |
| Reset | System reset of the MAC pipeline clears the table and invalidates a same-edge completion transfer. Forced abort does not; `FLUSHED` completions arrive through this channel and must be accepted before their entries are released. |

The initial port provides post-transmission timestamps only. A PHC
discontinuity between start and done retires the cookie with its outcome and
`captureValid = '0'`; the old capture is never reported as current time.

### 4.0 Exporter changes required for `WIRE_ERR`

The baseline default-mode exporters cannot produce the mid-frame link-loss outcome above.
[EthMacTxExportXgmii.vhd:190](../EthMacCore/rtl/EthMacTxExportXgmii.vhd)
resets `curState` to `ST_IDLE_C` on `phyReady = '0'` while `DATA_MUX` still
holds the frame remainder; on link return the remainder is transmitted as a
new frame with a fresh preamble. [EthMacTxExportGmii.vhd:172](../EthMacCore/rtl/EthMacTxExportGmii.vhd)
checks `phyReady` only in `IDLE_S`, so a frame in flight is driven onto a
dead link to completion. The timing-capable exporters must:

- The leaf keeps two registers per active frame: the token (set at the
  accepted SOF beat, cleared by the terminal event) and `inputEofSeen` (set
  when the input `tLast` is accepted, cleared with the token). Padding and
  FCS are generated after `inputEofSeen`, so a frame can be on the pins with
  no input remainder outstanding.
- On `phyReady` falling, or on `EthMacAbortRequestType.request`, while a
  tokened frame is between `start` and its last pin octet: stop driving
  data. If `inputEofSeen` is clear, enter a drain state that consumes the
  input through `tLast` without emitting pins and publish exactly one `done`
  with `doneError = '1'`, the token and `doneLength` = bytes consumed at that
  `tLast`. If `inputEofSeen` is set, publish that `done` immediately and
  consume nothing further; waiting for another `tLast` would eat the next
  frame or stall forever. Then return to idle. The CRC/mask pipelines are
  reset with the state machine as today.
- On `phyReady = '0'` at SOF: dump through `tLast` as today and publish one
  `retire` with the token (`DISCARDED`), never a `done`.
- GMII applies the link-loss rule from the first preamble octet, not only
  after `start`: a frame cut during its preamble has had octets on the pins
  but no `start`, drains its input and completes `WIRE_ERR` with
  `captureValid = '0'`. `doneLength` counts every input octet consumed,
  including the drained remainder, plus padding already launched.
- On underrun (`tValid` low mid-frame): the XGMII timing leaf ends the
  frame with `/E/` and `/T/`, drains the remainder and publishes `done` with
  `doneError = '1'` at its `tLast` (§10); GMII asserts `TX_ER`, dumps, and
  publishes `done` with `doneError = '1'` at `tLast`. Neither emits a second
  `done` for the same token.
- The token register is cleared only by the terminal event, so a `phyReady`
  toggle cannot start a second frame with the same token, and the exporter
  acknowledges a forced abort only **after** publishing the terminal event
  for any frame that had a `start`.

The pause-insertion frame (`tId = 0`) follows the same drain rule but
publishes no `done`; its `start` carries token zero and the port ignores it.

### 4.1 Relationship to the RTL ledger

`PtpTxLedger` admission still requires `macResetDone` and startup quarantine
for `PACKET_LIFETIME_G`, and known wire completions still retain protocol keys
for the network lifetime. The port's token lifetime proves transmission or
discard of one frame; the ledger's key quarantine prevents a late response from
attaching to a reused sequence number.

The declared records do **not** plug into the existing RTL backend as-is, and
this contract does not claim they do:

- `PtpTxLedger` consumes `PtpRxMessageMasterType` with decoded PTP identity
  (domain, requester identity, sequence). `PtpMacPortTxCompletionType` carries a
  cookie, outcome and capture. Phase 3 adds a controller-owned cookie→protocol
  key table and a new ledger wire input `(cookie, outcome, capture)` with
  explicit rules: `SENT`/`WIRE_ERR` enter key quarantine as today, preserving
  the known wire outcome; `DISCARDED` releases the key immediately, because
  every `DISCARDED` source (§4) acts before the exporter launches the frame;
  `FLUSHED` is **also quarantined**. The port guarantees a `FLUSHED` frame
  produced no wire `start`, but the ledger treats transmission fate it did not
  observe conservatively, and abort is rare enough that the quarantine costs
  nothing.
- `PtpRxFrontend` and `PtpDelayReqObserver` expect destination-MAC-through-FCS
  bytes on an 8-byte stream with no ready and a 64-byte minimum.
  `PtpMacPortRxMasterType` is FCS-stripped, 16 bytes wide, ready/valid, 60-byte
  minimum. **Decision, October 19, 2026:** the autonomous endpoint keeps
  both MAC implementations as a build-time option. The tapped build keeps
  the passive adapters. The timing-port build has no pin tap: a shim resizes
  the port's RX stream to 8 bytes and supplies the capture from RX metadata
  at SOF, and `PtpRxFrontend` gains a no-FCS input mode (the timing-mode MAC
  already drops bad-CRC frames). The frontend's parsing and validation stay
  shared. Phase 3 slice 3a measures this against the passive path before
  the RX change is implemented.
- In the timing-port build, a completion adapter maps `SENT` to the existing
  observed-Delay_Req record and emits nothing for `WIRE_ERR`, `DISCARDED` or
  `FLUSHED`, so `PtpTxLedger` and its quarantine rules are unchanged in both
  builds. The key-release rules in the first item are a later optional
  ledger improvement.

Both protections survive either choice.

## 5. Capacity, routing and capabilities

| Item | Initial value and owner |
| --- | --- |
| Primary configuration | `EMAC_TIMING_AXIS_CONFIG_C` inside the MAC and on the port-to-MAC streams; the **controller-facing** streams use `EMAC_AXIS_CONFIG_C` with `tId` cleared, so the token never leaves the port. `EMAC_AXIS_CONFIG_C` remains the default for every other MAC user. |
| Clock and reset | All port records, streams, events and the abort handshake are in `ethClk`. Timing mode requires `PRIM_COMMON_CLK_G = true` with `primClk = ethClk` and `primRst = ethRst`, so one system reset reaches `EthMacTxFifo` storage, both RX FIFO sides and every tokened owner. Any CDC to a DMA or application clock is the adapter's responsibility and must move `meta`/completions in the same FIFO word as the frame beats. `ethClkEn` must be held at `'1'`; the port raises a fault bit if it ever samples `'0'`, since a gated enable cannot be rejected at elaboration. |
| Fixed generics | `DROP_ERR_PKT_G = true` (RX store-and-forward/error dropping and TX checksum-error dropping), `BYP_EN_G = false` (the port is the sole token writer and owner; a bypass producer could inject `tId` and bypass-routed RX frames would hold tokens with no owner), `JUMBO_G = false`, `ROCEV2_EN_G = false`, `FILT_EN_G` free. All asserted at elaboration. |
| MTU and byte limit | 1500 network MTU is the controller policy; the port enforces a uniform 1518 Ethernet-byte cap, FCS excluded, sufficient for that MTU plus one VLAN tag. It does not classify untagged/tagged lengths or VLAN depth. `JUMBO_G = false`. Raising it requires a new capacity check across MAC FIFOs, the capture/completion tables and DMA buffers together. |
| RX storage | Block RAM, `MEMORY_TYPE_G = "block"`; depth at least `tableDepth × ceil(1518/16) + tableDepth` words, so a full table of maximum frames plus one synthetic terminator each fits. Because untokened frames never enter storage (§3), this bound is complete and overflow is impossible; asserted at elaboration. The legacy `EthMacPtpEndpoint` keeps `MEMORY_TYPE_G = "distributed"`, `FIFO_ADDR_WIDTH_G = 9`. |
| Tables | TX and RX table depth each at most `EMAC_TOKEN_COUNT_C`; initial depth 16 per direction, a generic. Admission reserves one completion credit per TX entry. The physical FIFO depth is `2**max(4, bitSize(TX_TABLE_DEPTH_G))`, at least the table depth; unused physical slots do not increase admission capacity. |
| Checksum offload | RX checking and TX insertion may stay enabled; TX `DROP_ERR_PKT_G` drops are completed `DISCARDED`. |
| Pause | Supported in both directions; generated pause frames carry token zero and produce no completion. |
| Filter | `FILT_EN_G` supported; filtered frames are counted in `rxDropped`. |
| Capability word | A read-only register publishes `PTP_MAC_PORT_ABI_VERSION_C`, `PTP_MAC_PORT_PHY_*`, timing-mode present, `EMAC_TOKEN_BITS_C`, `PTP_MAC_PORT_COOKIE_BITS_C`, TX/RX table depths, byte limit, one-step absent and `PTP_MAC_PORT_PLANE_MAC_DMAC_C`; these constants are declared in `PtpPkg` so RTL, PyRogue and the Linux adapter share them. `PtpMacPortStatusType` carries the live generation, `admissionOpen`/`drainIdle`/`cancelRequest`/`abortDone`, and the sticky faults (generation exhaustion, `ethClkEn` observed low, token protocol fault); `PtpMacPortControlType` carries `openAdmission`/`drainRequest`/`abortRequest`/`cancelAck`. An RTL controller connects the records directly; a software controller sees them through the port's AXI-Lite bank. Offsets are assigned when that bank is defined; [register-map.md](register-map.md) is updated at that time. |

Unsupported combinations (`ROCEV2_EN_G`, `JUMBO_G`, `BYP_EN_G`, XLGMII,
`PRIM_COMMON_CLK_G = false`, `DROP_ERR_PKT_G = false`, a MAC-internal
configuration without TID bits in timing mode) fail at elaboration.

The legacy `EthMacPtpEndpoint` composition keeps its bypass path, drain and
guard; it never enters timing mode, so the two compositions do not share a
token space.

## 6. Resets, generations and abort

| Event | Effect on the port |
| --- | --- |
| System reset (`rst`) | Clears MAC pipeline, tables, completion FIFO and counters; sets `transportGeneration` to `PTP_MAC_PORT_GENERATION_RESET_C` and closes admission; a same-edge completion transfer is invalid. Consumers must also reset. |
| Port restart / link loss (`phyReady = '0'`) | **Timing-mode leaf behaviour:** exporter dumps frames at SOF (`DISCARDED`) or drains them `WIRE_ERR` mid-frame (§4.0); importer terminates an open frame with `tLast`+EOFE and `done`/`doneError` (§2.4). The timing-mode `EthMacTxPause` clears `locPauseCnt`/`remPauseCnt` on `phyReady` falling, so a peer's pause quantum does not outlive the link session and cannot park tokened frames with no retire path. Tables are not cleared; every outstanding token still resolves through `done`, `retire` or forced abort, and every completion is still delivered. |
| AXI-Lite reset | Register responses only; no effect on frames, tables or generation. |
| PHC discontinuity / capture inhibit | Captures taken on the affected edge are `error`; outstanding TX requests complete with `captureValid = '0'`. Frames are not dropped and tokens are unaffected. |
| Graceful drain | Controller sets `PtpMacPortControlType.drainRequest`. The port stops accepting **new** TX SOF beats but keeps accepting the remaining beats of a TX frame whose SOF it already admitted, and completes that frame normally; RX starts are given `EMAC_TOKEN_NONE_C` and suppressed at the importer (§3). `PtpMacPortStatusType.drainIdle` rises when every table entry is *released*. Nothing is retired without wire evidence. Drain can stall only on the controller's own backpressure (unaccepted completions or RX frames), visible in the table-occupancy register; it is not a port fault. |
| Forced abort | Controller sets `abortRequest`, after drain or instead of it. The procedure is in four acknowledged steps below. Every TX entry without a `start` completes `FLUSHED`; every entry with a `start` completes through the `done` the exporter is required to publish (§4.0), so a frame that touched the wire keeps `SENT`/`WIRE_ERR` and its capture; every RX entry not yet released is released into `rxDropped`. `transportGeneration` advances (§6.1) and `abortDone` rises. **`FLUSHED` completions remain in the completion channel and are delivered normally**; the port does not release those entries until the controller accepts them. |

Forced abort procedure, all levels registered:

1. **Close.** The port clears `admissionOpen`, withholds TX ready for new
   SOF beats and gives RX starts token zero.
2. **Controller cancellation.** The port raises `cancelRequest`. The
   controller (for Linux, the DMA adapter, which owns the buffers) must:
   terminate any TX frame whose SOF the port accepted by presenting `tLast`
   with EOFE (the port completes it `DISCARDED`); keep accepting RX beats until
   the port has terminated any partially delivered RX frame with `tLast`+EOFE
   (the only case in which a delivered frame carries EOFE; the consumer
   discards it); then raise `cancelAck`. A DMA adapter that has already
   written part of that RX frame to memory invalidates the descriptor. The
   port waits for `cancelAck` before step 3, so no owner is reset while the
   controller boundary still has a transfer in flight.
3. **Owner abort.** The port asserts `EthMacAbortRequestType.request` to
   every tokened owner and waits for all `EthMacAbortAckType.acknowledge`.
   The exporter first publishes the terminal `done` for any frame that had a
   `start` (§4.0), then discards and acknowledges. All other owners stop
   accepting input, discard their tokened contents and acknowledge. **No
   owner publishes a retire during abort**: several stages can hold portions
   of one frame, and independent retires would release a token while another
   stage still references it.
4. **Release.** After every acknowledgement, the port processes any `done`
   events received during step 3, then releases every remaining entry once:
   TX entries without a completion become `FLUSHED`; RX entries are counted
   in `rxDropped`. It advances `transportGeneration`, raises `abortDone`,
   lowers `cancelRequest` and `request`, and the controller lowers
   `cancelAck`/`abortRequest`. Admission reopens on `openAdmission`.

Forced abort is the only path that releases a token without wire evidence,
and it does so only after every owner and the controller have acknowledged
that they hold no reference. A `done` or `retire` that arrives for a token
after its owner acknowledged abort is a protocol fault (§2.3). There is no
timeout-based release.

Forced abort reaches: the port's TX hold store, `EthMacTxFifo`, `EthMacTxCsum`
(both its register pipeline and `Fifo_Cache`/`Fifo_Trans`), `EthMacTxPause`,
the exporter, the importer, `EthMacRxPause`, `EthMacRxCsum`, `EthMacRxFilter`,
`EthMacRxFifo` and the port's RX output stage. Register-stage owners discard
their one frame and acknowledge. FIFO owners (`EthMacTxFifo`,
`Fifo_Cache`/`Fifo_Trans`, exporter `DATA_MUX`, importer `DATA_MUX`,
`EthMacRxFifo`) cannot enumerate stored tokens; the timing-mode wrapper
applies a synchronous flush reset to both FIFO sides on `request` and
uses the four-cycle synchronous flush in `EthMacTimingAbort`, then acknowledges as a group (§10); it does not enumerate stored tokens or wait on per-FIFO acknowledgements.

`SsiFifo`'s `PREVENT_LOCKUP` self-reset (`lockupRstEvent`, active today
because `VALID_THOLD_G = 0`) would discard stored frames with no
acknowledgement and no token list. In timing mode the RX FIFO wrapper
**disables** `PREVENT_LOCKUP` while retaining `VALID_THOLD_G = 0` for
store-and-forward, through the new `SsiFifo` generic `PREVENT_LOCKUP_G`
(default `true`, today's behaviour). The lockup condition it guards
against (FIFO full with no readable frame) cannot occur: only tokened frames
enter storage (§3), the table bounds their number, and §5 sizes the FIFO for
a full table of maximum frames. If a defect produced it anyway, forced abort
is the controlled recovery.

### 6.1 Transport generation lifecycle

| Rule | Contract |
| --- | --- |
| Width and owner | 16 bits, owned by the port, readable in its AXI-Lite bank. Only the port writes it. |
| Reset value | `PTP_MAC_PORT_GENERATION_RESET_C` (`0x0000`) after system reset. This value never admits traffic and never appears in a delivered record. |
| First live value | The port advances to `0x0001` when the controller opens admission (register write); it advances again on every acknowledged forced abort. Graceful drain does not advance it. |
| Exhaustion | `PTP_MAC_PORT_GENERATION_EXHAUST_C` (`0xFFFF`) is a fault: admission closes, the fault bit is set, and only system reset recovers. The value never wraps to zero. 65,534 forced aborts between system resets is the budget. |
| Stamping | RX: the live generation at the frame's wire `start`. TX completion: the request's generation, including a stale request completed `FLUSHED`. For a current-generation request this equals the live generation at admission; later aborts do not rewrite it. |
| Stale TX request | A request whose `transportGeneration` differs from the live value is consumed through EOF without entering the MAC and completed `FLUSHED` with the request's own generation echoed. This covers DMA requests built before an abort and delivered after it. |
| Consumer notification | `PtpMacPortStatusType.abortDone` rises (IRQ-capable) with the new `transportGeneration` readable; the controller took part in the abort through `cancelRequest`/`cancelAck` (§6), so it already knows the old generation is dead before issuing new requests. Linux: the netdev driver treats a generation change as a link-down/up pair and drops any queued skbs. |
| Record view | Both envelope records and completions carry the generation, so software can recognise a stale record even after missing the IRQ. |

## 7. DMA envelope (v1 projection)

Byte offsets are little-endian; each record is 8-byte aligned and its length
field counts the complete record including the header. Unknown `version` or
`type` records are discarded and counted by the receiver. The Ethernet frame
follows the header with FCS excluded, exactly as on the port stream.

### 7.1 Common header (16 bytes)

| Offset | Width | Field |
| --- | --- | --- |
| 0 | 1 | `version` = 1 |
| 1 | 1 | `type`: 1 RX frame, 2 TX request, 3 TX completion |
| 2 | 2 | `recordLength` (bytes, including header and padding) |
| 4 | 2 | `frameLength` (Ethernet bytes, FCS excluded; 0 for completions) |
| 6 | 2 | `transportGeneration` (RX: live at wire start; TX request: the value the controller observed, checked by the port; TX completion: the admitted request's value, or the stale request's own value echoed with outcome `FLUSHED`) |
| 8 | 4 | `cookie` (TX request/completion; 0 for RX) |
| 12 | 1 | `status`: bits 1:0 outcome per `PTP_MAC_PORT_OUTCOME_*` (RX frame: always `SENT`; TX request: zero); bit 2 `captureValid` (RX frame: `not capture.error`); bit 3 `capture.error`; bit 4 `capture.timeValid`; bit 5 `timestamp` request flag (TX request only; zero on RX frame and TX completion); bits 7:6 reserved zero |
| 13 | 3 | reserved zero |

Because `SENT` encodes as zero, a receiver must validate `version` and `type`
before interpreting `status`; a zero-filled or truncated record is rejected
on those fields, not read as a successful transmission.

### 7.2 Capture block (24 bytes; RX frame and TX completion only)

| Offset | Width | Field |
| --- | --- | --- |
| 16 | 8 | `seconds` (48 bits in the low six bytes, high two bytes zero) |
| 24 | 4 | `nanoseconds` |
| 28 | 2 | `fractionQ16` |
| 30 | 2 | reserved zero |
| 32 | 4 | `phcGeneration` |
| 36 | 4 | reserved zero |

The projection drops `ticks`, `tickPhase` and `increment`; they serve the
RTL rate/E2E arithmetic and the Linux adapter does not need them. Calibration
is already applied at the capture provider. A future raw-capture diagnostic
record takes a new `type`.

### 7.3 Record layouts

| Type | Layout |
| --- | --- |
| RX frame (1) | Header, capture block, Ethernet frame from offset 40, zero padding to 8-byte alignment. `cookie` is 0. On a 16-byte DMA stream, offset 40 means the adapter shifts every frame beat by 8 bytes and recomputes the last beat's `tKeep` (an `AxiStreamShift`-class stage); this is accepted so the capture block stays 24 bytes. |
| TX request (2) | Header, Ethernet frame from offset 16, zero padding to 8-byte alignment. `status` bit 5 carries the timestamp request; other status bits zero. `frameLength` is authoritative; `recordLength` must equal `16 + frameLength` rounded up to 8, and `frameLength` must be 16..1518. The adapter forms `request.frameLength` from the header field and `request.transportGeneration` from offset 6, and presents them on the SOF beat. Any other combination (including `recordLength < 16` or `frameLength = 0`) is malformed: the adapter discards it, counts it, and emits a `FLUSHED`-outcome completion with the record's cookie and generation so software never waits on it. |
| TX completion (3) | Header, capture block; `recordLength` = 40, `frameLength` = 0. |

Frames and completions may share one DMA destination or use two; either way
the adapter preserves per-destination order and reserves both destinations
exclusively. The envelope is stripped before the MAC and before Linux
networking sees the frame. The adapter enforces §4's stream shape at the port
boundary, so a malformed DMA record never produces a partial frame on the
port stream.

## 8. Baseline evidence and acceptance

Contract baseline evidence at SURF `ecbf833a2` with these declarations added:

- GHDL 6.0.0 analysis (`--std=08 -fsynopsys -frelaxed-rules -fexplicit`) of
  the package chain `StdRtlPkg`, `TextUtilPkg`, `AxiPkg`, `AxiStreamPkg`,
  `SsiPkg`, `EthMacPkg`, `PtpPkg` passes.
- VSG (`vsg-linter.yml`, 689 rules): zero violations on both edited packages.
- A throwaway round-trip bench on the first revision confirmed
  `PTP_RX_CAPTURE_BITS_C = 261`, `PTP_MAC_PORT_RX_META_BITS_C = 293`,
  `PTP_MAC_PORT_TX_COMPLETION_BITS_C = 312`, cookie in the completion MSBs and
  generation in the LSBs, and `getSlvSize(EMAC_TIMING_AXIS_CONFIG_C) = 149`
  versus 141 for the internal default. The request record gained a
  `transportGeneration` field after that bench; the completion/meta layouts it
  checked are unchanged. The throwaway bench is superseded by
  `test_ptp_mac_port_contract.py`, which checks encoding and decoding against
  independent field offsets and bit-walking vectors, plus the initializers
  and stream widths. Its lifecycle case exercises the full generation range
  through public handshakes; execution status is below.

### October 18 closure verification

Sources are `ecbf833a2` (baseline) and merge `babf2234e` plus the working-tree
Phase 1 closure patch. Local tools are Python 3.12.7, cocotb 2.1.0 and GHDL
6.0.0; the isolated rdsrv401 runs use Python 3.10.12, cocotb 2.1.0 and GHDL
1.0.0. Generated sources and logs are outside maintained source in the
consuming project's `.planning/composable-ptp-phase1/20261018-closure/` and
`rdsrv401:/u1/bareese/agent-builds/surf/20261018-phase1-closure/`.

- `test_ptp_mac_port_rx_errors.py`: both GMII/XGMII cases fail before the
  `PtpMacPortRx` fix and pass after (195.79 s locally). Eighteen frames per
  PHY exercise good/bad-FCS/good traffic, checksum checks enabled, a stalled
  earlier frame, exact retirement counts and capture association. The fix
  is confined to the timing port; default MAC behavior is preserved.
- The two older MAC/PTP fixtures pass locally (502.47 s) after explicitly
  loading their experiment/frontend wrappers. EthMacCore's ruckus import no
  longer includes the experiment wrapper; a fresh remote import confirms it.
- All 12 timing/legacy pytest configurations pass on rdsrv401 (2784.50 s):
  GMII/XGMII timing leaves, retire/abort/TID, both port compositions and the
  two legacy MAC/PTP fixtures. The retained record-layout case also passes
  from the final fixture checkout.
- After fixture task-ownership and bounded-wait cleanup, all 14 selected
  configurations pass (682.37 s). This includes both checksum-enabled RX
  error cases, the packing check, and representative timing/port/legacy
  cases. Existing test inventories are unchanged. Focused test compliance,
  Python lint, VSG on changed/new VHDL, and the final local import pass.
- The complete 65,534-abort generation sweep passes locally (1468.25 s):
  each generation advances through the public handshake, exhaustion blocks
  reopen/TX admission/RX tokens, another abort cannot wrap, and system reset
  recovers. The idle-MAC contract wrapper uses `TPD_G=0 ns` to reduce GHDL
  event-scheduling cost; normal-delay wire/capture behavior is covered by
  the separate timing/port benches. The superseded `TPD_G=1 ns` sweep was
  terminated after this pass and is not counted as completed evidence.
  `RUN_PTP_GENERATION_EXHAUSTION=1` opts into this long check.
- All 27 selected baseline known-issue scenarios across 15 pytest nodes fail
  at the documented behavioral assertions. They cover the 15 confirmed
  reports in the [MAC test guide](../../tests/ethernet/EthMacCore/README.md).
- Paired default MAC and SSI selections pass on both isolated trees:
  107 passed and 52 gated skips each, with all 159 named outcomes identical.
  Current runtime is 3431.42 s; baseline is 3424.30 s. The long soak and
  known-defect cases are gated out of this default selection. This selects
  the imported default-MAC files and the two SSI FIFO/filter files; the five
  timing files and new opt-in differential fixture are checked separately.
- Matched default-mode `EthMacTop` synthesis, Vivado 2025.2 on rdsrv401,
  `xcku040-ffva1156-2-e`, OOC with rebuilt hierarchy and zero black boxes:

  | PHY | CLB LUTs, baseline → current | Registers | BRAM36 tiles |
  | --- | --- | --- | --- |
  | GMII | 5067 → 5066 | 8627 unchanged | 12 unchanged |
  | XGMII | 7229 → 7228 | 9866 unchanged | 12 unchanged |

  Distributed RAM and SRL counts are also unchanged. These unconstrained
  synthesis results establish no default-mode storage overhead; they are
  not timing-port area, routed timing or hardware qualification.
- Source review finds 78 instances of changed MAC/SSI entities in 56
  checked-out firmware files, all with named generic and port associations,
  and no matching component declarations. This includes the GigEthCore,
  TenGigEthCore, XauiCore and UDP testbench callers; no direct caller was
  found outside SURF in the checked-out dependencies. Unavailable external
  repositories and vendor PHY simulations are not qualified by this review.
- All ten opt-in differential configurations pass: seven top-level modes
  (seeds 467–473) and three GMII exporter cases (seeds 601/610/700, enable
  divisors 1/10/100). Every original output matches before/after propagation
  on each clock domain. An inverted baseline-ready mutation fails as expected,
  and the restored case passes. Nine configurations completed in the parallel
  batch; the final XGMII common-clock case passed separately (1478.91 s).
  The original batch's duplicate final case was intentionally interrupted;
  its nine completed passes and the independent final pass form this matrix.
  This preserves recorded baseline behavior, including known defects; it is
  not exhaustive equivalence or extended-soak coverage.

### October 17 implementation evidence

Phase 1 leaf evidence, October 17, 2026 (GHDL 6.0.0, cocotb 2.1.0, Python
3.12.7), on SURF `ethernet-ptp` after `c1b7b95e4`:

- `test_EthMacTimingGmiiLeaf.py` (six cocotb tests) places the timing GMII
  importer and exporter each beside a `PtpRxTimestampAdapter` on the same
  pins. Every leaf `start` falls on the adapter's capture-SOF edge and the two
  start sets are equal, across 60..1518-byte RX frames, a one-octet IFG,
  shortened/lengthened/corrupted preambles, RX_ER in preamble, bad SFD,
  RX_ER and link loss mid-frame, early aborts after 0..6 octets, 16..1514-byte
  TX frames, link loss at SOF, in the preamble, mid-frame and in the FCS, and
  TX underrun. RX frames arrive FCS-stripped with the start token on every
  beat; each start has one terminal event; token zero produces no beat or TX
  `done`; TX wire FCS and padding are checked against zlib. Two mutations (TX
  `start` on the launch edge; six preamble octets accepted) fail all six
  tests, the TX one at exactly one cycle.
- `test_EthMacTimingTid.py` was rebuilt: its earlier timing case read the
  boolean generic back as `'1'`, expected tId zero in both cases and passed
  vacuously; RX tId can never equal the TX tId because the importer allocates
  RX tokens. It now runs a GMII timing `EthMacTop` loopback: TX tokens appear
  at the exporter's `start`/`done` after the TX FIFO and checksum cache, and
  importer-allocated RX tokens survive the RX FIFO across a stalled sink. A
  mutation stamping token zero on non-final RX beats fails it. In that run
  two RX tokens went to generated pause frames consumed by `EthMacRxPause`,
  which has no retire yet: the leak the pause retire must close.
- Default paths: all `tests/ethernet/EthMacCore` regressions,
  `test_SsiFifo.py`, `test_SsiObFrameFilter.py` and the two-step GMII and
  XGMII `test_ptp_endpoint_mac.py` cases pass.

Phase 1 port evidence, October 17, 2026 (same tools), on SURF
`ethernet-ptp` after `72c774a2a`:

- `test_EthMacTimingXgmiiLeaf.py` (seven tests) is the XGMII counterpart of
  the GMII leaf bench: starts coincide with the adapter on both `/S/` lanes
  with the same start lane, across every last-word alignment, minimum IFG,
  data-valued `/S/`/`/T/` octets, short/long/corrupted preambles, an illegal
  `/S/` lane, `/E/` and nested `/S/` mid-frame, link loss and early ends; TX
  covers every FCS/terminate split, padding to exactly 60, PHY-not-ready
  dump, link loss in data and FCS, underrun and forced abort. Mutations
  (`/S/` accepted in any lane; TX `start` one edge early) fail it.
- `test_EthMacTimingRetire.py` (timing `EthMacTop`, 2048- and 512-word RX
  FIFO) has a bench ledger require exactly one resolution per RX token:
  filter drop, good- and bad-FCS pause consumption, a CRC error followed at
  minimum spacing by a good frame, and FIFO overflow with a stalled sink that
  exercises both the SOF-swallowed (inbound) and stored-partial (outbound)
  retires; the TX checksum retires an EOFE frame; a received pause quantum
  stops holding TX once the link drops. Letting the inbound retire fire for
  every dropped `tLast` produces a double release and fails it.
- `test_EthMacTimingAbort.py`: abort while idle, with a frame on the pins
  (one `done`/`doneError` before the acknowledge, queued frames flushed with
  no event) and with RX frames stored (never delivered); no event names a
  released token; fresh traffic then flows. Removing the exporter's abort cut
  fails it.
- `test_EthMacTimingTid.py` gained an XGMII timing case.
- `test_ptp_mac_port.py` runs `PtpMacPortEthMac` for GMII and XGMII (nine
  tests each) with a PHC model driving the port and both adapters.
  RATE/SET/PHASE commits and capture aborts placed one cycle before, on and
  after each frame's pin cycle, and mid-frame, give TX completion captures
  bit-identical to the TX tap and RX captures bit-identical to the pin
  oracle, with `captureValid`/`capture.error` exactly as §3/§4 specify;
  injected RX frames (including XGMII lane-4 starts) under random commits
  match the RX adapter. The suite also covers every TX shape rule,
  exhaustion with completions held, PHY-not-ready and link-loss outcomes,
  runt/1518/1519/1520/bad-FCS dispositions, RX table exhaustion, the reset
  generation, drain with a half-presented frame, and forced abort (frame on
  the pins `WIRE_ERR`, queued frames `FLUSHED`, half-presented frame
  `DISCARDED`, partial RX delivery ended with EOFE, held completions
  delivered, generation advanced, stale request `FLUSHED`). Feeding the port
  the live instead of the registered PHC tuple, or dropping the
  generation-change invalidation, fails it.

Production MAC entities changed (opt-in generics and ports, retire outputs
and the `EthMacTop` reset wiring); their default paths were re-run as listed
in the composable plan. The [existing endpoint validation](../../docs/plans/ethernet-ptp/README.md#current-validation)
was not otherwise repeated.

Phase 1 acceptance, per slice in the composable plan:

- Default-MAC regressions pass with timing disabled.
- Capture alignment (§2.4): for each PHY and each XGMII start lane, drive
  RATE, SET and PHASE commits on the pin-sample edge, one cycle before and
  one cycle after, and show bit-identical captures (all fields, including
  `error` from inhibition) between the port and the passive adapter oracle.
- TX: generated pause frames interleaved with tokened frames, identical
  payloads with different cookies, stalls, underrun, `phyReady` low at SOF
  and mid-frame — both before and after the input `tLast` was accepted
  (exactly one `DISCARDED` or `WIRE_ERR`, no second frame on link return, no
  consumption of the following frame), PHC step and generation change between
  start and done, token exhaustion, declared-length mismatch, 14/15-byte
  rejection, missing EOF, nested SOF, EOFE on last, stale-generation request,
  graceful drain with a half-presented frame (must complete, then
  `drainIdle`), forced abort with frames on the pins (must complete
  `SENT`/`WIRE_ERR` with capture, never `FLUSHED`), in the FIFOs (`FLUSHED`),
  half-presented at the controller (`DISCARDED` after `cancelAck`), and with
  completions held unaccepted and then drained.
- Legacy `EthMacPtpEndpoint` mode (unchanged, `BYP_EN_G = true`):
  simultaneous primary/bypass traffic continues to pass its existing
  regressions.
- RX: filter drop, bad-FCS and single-beat pause consumption, SOF-beat and
  mid-frame overflow (exactly one retire each), outbound EOFE drop with the
  consumer stalled on an earlier frame (token must not be reused while the
  stalled frame is undelivered), CRC error followed immediately by a good
  frame, GMII early abort as `rxLost`, shortened preamble producing no start
  in either leaf or adapter, XGMII nested `/S/` terminating the open frame
  with `WIRE_ERR`-class `done` and no start for the nested frame, `phyReady`
  loss mid-frame terminating with exactly one `tLast`+EOFE and one `done`,
  runt and 1519/1520-byte frames marked rejected at `done` and released
  only when the output stage consumes their last beat, table exhaustion with
  the token-zero frame suppressed at the importer while a tokened frame is
  stalled at the consumer (FIFO occupancy must not grow), PHC generation
  change mid-frame delivered with `capture.error`, forced abort with frames
  in the FIFO and one half-delivered to the consumer (terminated with
  `tLast`+EOFE, released only after `cancelAck`).
- Latent MAC defect, tracked separately: `EthMacTxCsum` oversize leaves a
  `tLast`-less frame in `Fifo_Cache` and misaligns `Fifo_Trans` (§2.1); add
  a default-MAC regression that reproduces it before fixing it.

## 9. Open items closed by this contract

| Item | Resolution |
| --- | --- |
| Carrier | TID tag-through via `EMAC_TIMING_AXIS_CONFIG_C` inside the MAC; token zero unowned; 255 outstanding per direction maximum; `tId` cleared at the controller boundary. |
| Capture source | Leaf `start`/`done` events with the passive adapter's start qualification; the §2.4 edge table defines the PHC tuple as the values standing during the cycle the word is on the pins, for RX (before sampling) and TX (after launch) alike, with `start` registered on the edge ending that cycle. No offset correction; a non-coincident leaf must carry the capture itself. Passive adapters retained as oracle and legacy producer; the oracle comparison is total. |
| Ownership | Wire resolution (`done`/wire-plane retire) and release (consumer acceptance, MAC-stage retire, output-stage consumption of a rejected frame, or acknowledged forced abort) are separate states; a token is never reused while any downstream reference exists. |
| Drop ownership | Retire owners at fixed `EthMacPkg` indices (TX: checksum, exporter; RX: pause, filter, FIFO inbound/outbound with one pulse per frame across the two, importer abandoned start) plus the port's admission and rejected-frame output stages; the importer's token-zero suppression before storage is not a retire; every leaf start has exactly one terminal event from the leaf; forced abort releases once, globally, after every owner and the controller acknowledge; no timeout release. |
| Link loss, nested start and abort | §2.4 and §4.0 specify importer termination and exporter drain as **required leaf changes**; the exporter tracks input-EOF separately from wire-EOF so it drains only an outstanding remainder; a frame on the pins at abort completes through `done`, never `FLUSHED`. Pause counters clear on link loss. |
| Abort boundary | §6 four-step procedure: close, controller cancellation (`cancelRequest`/`cancelAck`, adapter terminates its open TX frame and consumes the port's partial-RX terminator), owner abort, single release. `FLUSHED` is provably "no wire start"; the ledger still quarantines it. |
| TX stream shape | Declared-vs-actual length, partial-keep, nested SOF, missing EOF, EOFE-on-last, no-SOF beats and a full 16-byte first beat (minimum frame 16 bytes) all specified; the port holds a frame until `tLast` validates; completions unordered except in wire order. |
| Clock, reset and generics | `ethClk` for everything port-side; `PRIM_COMMON_CLK_G = true`, `primRst = ethRst`, `DROP_ERR_PKT_G = true`, `BYP_EN_G = false`, `JUMBO_G = false`, `ROCEV2_EN_G = false`, `ethClkEn = '1'`; all but the last asserted at elaboration. |
| Generation | 16-bit, reset value never admits, advances on open and on forced abort, exhaustion faults closed, stale requests complete `FLUSHED`; both records and completions carry it. |
| Record widths and ABI | Fixed by `PtpPkg` constants (records, packing, ABI/envelope versions, record types, status bits, plane and PHY identifiers) and the §7 envelope. |
| Frame limits | 1500 MTU, 1518 bytes with one tag, FCS stripped, padding retained, enforced by a port stage because no MAC stage does. |
| Linux projection | §7; raw-cycle fields dropped at the adapter; malformed records complete `FLUSHED`; RX frame at offset 40 accepted with an 8-byte shift stage. |
| RTL backend reuse | §4.1 names the frontend and ledger mismatches; planning default keeps the passive RX path for the RTL backend and moves TX completion onto the port. |

Resolved in Phase 1: the GMII and XGMII leaves are pin-coincident (§2.4,
§8) and the §8 benches pass in simulation. Still open: the port's AXI-Lite
bank (capability, control/status, counters and faults) with its PyRogue
model and `register-map.md` entry; synthesis, area and timing of the port,
its tables and the wider FIFO word; and hardware. The third contract review
is addressed by the October 18 fixes/clarifications above. The default-MAC
suite retains the `EthMacTxCsum` oversize reproducer; fixing that baseline
defect is separate work. The retained lifecycle bench verifies generation
exhaustion and reset recovery (§8).

## 10. Phase 1 implementation map

| Contract item | Implementation |
| --- | --- |
| Opt-in carrier and leaves | `EthMacTop` `INT_CONFIG_G`/`TIMING_EN_G`; `EthMacRxImportTimingGmii`, `EthMacRxImportTimingXgmii`, `EthMacTxExportTimingXgmii` and the `TIMING_EN_G` branch of `EthMacTxExportGmii`, selected by `EthMacRxImport`/`EthMacTxExport`. |
| Retire owners (§2.4) | `EthMacTxCsum`, the exporters, `EthMacRxPause`, `EthMacRxFilter`, `EthMacRxFifo` (inbound only when the SOF beat was swallowed, outbound from `SsiFifo.mAxisDropTId`) and the import leaves, at the `EthMacPkg` indices. |
| Timing RX FIFO and pause (§5, §6) | `EthMacRxFifo` `TIMING_EN_G` sets `PREVENT_LOCKUP_G = false`; `EthMacTxPause` `TIMING_EN_G` clears both pause counters on link loss. |
| Owner abort (§6 step three) | `EthMacTimingAbort` inside `EthMacTop`: the exporter ends a frame on the pins as for link loss and acknowledges when idle, then a four-cycle flush reset clears every other MAC owner. One aggregate `abortReq`/`abortAck` replaces a per-owner acknowledge array; flushed owners publish no retire. The port flushes its own TX hold store in the same step. |
| Port (§3, §4, §6) | `PtpMacPort` (PHC copy, generation lifecycle, drain, four-step abort, counters, faults) over `PtpMacPortTx` (admission, shape checks, store-and-forward hold store, token table, wire capture, completion FIFO) and `PtpMacPortRx` (token offer, per-entry capture/length/generation, output stage, cancel terminator). |
| Composition (plan slice 1d) | `PtpMacPortEthMac`: `PtpMacPort` over a timing `EthMacTop` with an external PHC; asserts the §5 RX FIFO bound. `EthMacPtpEndpoint` is unchanged. |

Refinements made while implementing, within the contract's rules:

- **XGMII underrun, link loss and abort** end the frame with `/E/` and `/T/`
  in lanes 0 and 1, then drain only an outstanding input remainder; the
  legacy exporter's inverted-FCS continuation is not used in timing mode.
  An EOFE input frame is still sent with an inverted FCS and `doneError`.
- **XGMII TX padding** is exactly 60 bytes; GMII keeps the legacy 61 (§4).
- **Abandoned XGMII starts** follow the GMII rule: a start whose frame ends
  with no byte beyond the four FCS octets publishes a retire instead of
  `done`. An in-frame control other than `/T/` (including a nested `/S/`)
  is an error termination; the nested `/S/` is reported `lost`.
- **The flushed import leaf** restarts qualification mid-burst and may report
  one `lost` for the remainder of a frame cut by the flush.
- **Shape rejection happens in the hold store:** frames failing the TX shape
  rules are terminated with EOFE and removed by the store's outbound filter;
  their entries complete `DISCARDED` before the MAC sees any byte.
- **RX capture storage** is a register array per table entry (16 × capture,
  length and generation by default); a RAM-backed table is an area
  optimization for later.
