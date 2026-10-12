# PTP logic and storage optimization

October 9, 2026. Goal: reduce combinational logic while preserving numerical,
packet-validation, queue and cancellation behavior. The maintainer reported
high LUT use relative to registers; synthesis reports are on another machine.
Optimization baseline: SURF `6db41ad53ed5d17491fcfddfcff30325755d244f`. Subsequent
FIFO validation uses `2bb198b10efc964f1d861ebc34a33d214052afd7` plus the local
optimization patch. Independent protocol/specification changes are outside
this optimization. The October 11 placed reports below now provide an area
reference; no before/after resource reduction has been measured yet.

## Implemented changes

| Module | Change | Preserved behavior |
| --- | --- | --- |
| `PtpServo` | Nine fixed compare/swaps replace the five-pass, four-comparison-per-pass bubble sort | Same-cycle sample admission; lower median of populated samples; all Q16 bits; circular replacement |
| `PtpRxFrontend` parser | Align each beat once, write fixed prefix bytes, and compute frame byte count once | Contiguous partial beats of widths 0 through 8, sparse-keep rejection, saturated frame count and no input backpressure |
| `PtpRxFrontend` header/TLV | Cache base/message end before the first TLV; bound remaining count by frame capacity | Validate all 16 received length bits before narrowing; permit split headers, zero-length TLVs and multiple transitions per beat |
| `PtpRxFrontend` queue | SURF synchronous FWFT FIFO replaces the custom payload queue; register writes and retain the output head | Exact logical capacity including pipeline stages, stalls, simultaneous consume/enqueue, full-before-edge discard-all, reset/flush, generation and epoch rules; delivery now takes three clocks after completion |
| `PtpPkg` | Paired 809-bit lossless storage helpers | Existing 744-bit verification format stays unchanged; capture increment/error now survive memory transport |

Enduring interfaces and implementation rationale belong in the
[source guide](../../../ethernet/PtpCore/README.md) and
[RX queue contract](autonomous-endpoint.md#rx-queue-storage).
The public production ports, register ABI, arithmetic scaling and command
lifecycle are unchanged. No manifest change is required: all edited RTL and
the reused `Fifo` already belong to the source import.

The median sorts a scratch copy of the circular history. Unpopulated entries
use signed64 maximum, then counts one/two select index zero, three/four index
one, and five index two. A populated maximum-valued sample can tie the sentinel
without affecting the result. The network is:

```text
(0,3), (1,4), (0,2), (1,3), (0,1), (2,4), (1,2), (3,4), (2,3)
```

The queue accepts the synchronous FIFO's latency instead of retaining custom
asynchronous RAM control. A registered completion passes through the FIFO's
write and FWFT read before entering the head three clocks after EOF. Logical
occupancy includes all stages, independently of the FIFO's larger physical
allocation. Writes/reset publish from `r`; the read acknowledgement uses the
documented SURF FWFT consumer pattern. Reset clears validity without clearing
payload RAM. Include the write register, FIFO output register and head in
synthesis comparisons. The initial `LutRam` version and its registered-write
follow-up are superseded; preserving their immediate head delivery is no longer
a requirement. Public ready/valid, abort priority and capture timestamps remain
unchanged.

## October 11 ledger storage and counter pass

Source baseline: SURF `1bd476a89cac78f5945007b8975ef95755899a8d`. The consuming
`ptp-dev` repository preserves supplied reports in
`docs/reference/ptpkcu105-utilization-2026-10-11/`, added by `d4f94c9`.
They describe Vivado 2025.2, `xcku040-ffva1156-2-e`, after placement; routing did
not complete. They do not embed the exact source revision/patch or complete
strategy, so confirm those before attributing a later difference to this pass.

| Placed reference | LUTs | FFs | DSPs |
| --- | ---: | ---: | ---: |
| SFP lane, including MAC/PHY | 53,802 | 39,009 | 48 |
| SFP protocol engine, own logic | 15,954 | 11,827 | 30 |
| SFP TX ledger | 6,959 | 3,566 | 0 |
| SFP servo, own logic | 7,817 | 3,932 | 0 |
| Copper TX ledger | 6,931 | 3,566 | 0 |

These rows mix parent totals and explicitly exclusive own-logic rows; do not
sum them. Both ledger instances benefit from the same reusable source change.

`PtpTxLedger` now puts the entire 636-bit entry in synchronous
`SimpleDualPortRam`, distributed by default with an optional block setting at
the leaf. The wide `r.entries` array is removed. Four ownership bits per slot
remain in registers so restart/reset can invalidate associations immediately
without clearing memory. A shared scan replaces the parallel key comparisons,
age arithmetic, record updates and chained counter increments. Each row is
visited every `2*DEPTH_G+2` clocks, ten at the default depth four.

Wire and response records remain stable through explicit ready/valid handshakes
at the end of the scan. Completion readiness is wired through the protocol and
endpoint to the existing TX tap queue. The protocol holds a response and its
log interval until the ledger acknowledges it. Those low-level entity interfaces
now require ready wiring; the MAC/PHY wrapper interfaces, software ABI and
numeric precision are unchanged. The [ledger storage contract](autonomous-endpoint.md#tx-ledger-storage)
owns timing, capacity, simultaneous-event priority and cancellation rules.

Only one row contributes to each diagnostic update. Local rejection events are
summed before one 33-bit saturating addition; timeout has one increment site.
For initial count `c` and nonnegative events `e`, repeated saturation equals
`min(2^32-1, c+e)`. The local event bound is two, so the carry is retained at the
maximum count. This is an arithmetic bound, not a billions-of-events simulation
or a measured LUT saving.

The [October 11 checks](rtl-review.md#october-11-ledger-optimization-checks)
record leaf and consumer evidence. Existing ruckus manifests already load all
modified entities and the reused RAM selector; no source-list change is needed.

Next step: compare both ledgers in the same Vivado configuration, including
LUT-as-logic, LUTRAM, FF, carry, BRAM and critical paths. Account for the write
register, RAM read register and retained sample; 636 bits per slot is a storage
width, not a promised resource reduction. Confirm actual inferred RAM mapping.
Subsequent candidates are shared protocol timestamp conversion and the servo's
local clamp/median logic. Those changes are outside this ledger pass.

## Evidence and remaining acceptance

The [acceptance record](rtl-review.md#october-9-lut-optimization-checks) owns
executed checks and limits. The initial algorithm exploration checked all 120
permutations of five distinct values and 9,330 populated-count/boundary cases;
those Python-only results are separate from RTL verification.

Focused RTL coverage comprises the servo leaf, direct/GMII/XGMII RX oracle,
TX storage and real-MAC RX fixture, plus the selected TLV rules. The new tests
cover median population/order/duplicates/full range/circular replacement,
RX depths one through four, TX depths two/three, full capture fields,
simultaneous consume/enqueue, three-clock delivery, invalidation throughout the
FIFO pipeline, overflow, reset/flush, malformed keeps and large TLV lengths.
The MAC association fixture is historical model/counterexample
coverage; it is not production TX-observer coverage. Full endpoint settling,
all generic combinations and hardware qualification remain outside this run.

## Vivado comparison

Next step: synthesize this source and the baseline with the same FPGA part,
Vivado version, clock constraints, generics, strategy and flattening. Record
the source revision and local patch, and distinguish post-synthesis results
from post-implementation results. Compare the median, parser and queue changes
separately when attributing improvements, then check the integrated result.

Capture LUT-as-logic, LUT-as-memory, FF, carry, DSP and BRAM use plus critical
path/slack. Judge absolute resources and timing rather than minimizing LUT/FF
ratio: eliminating registers can increase that ratio while reducing area.
AMD documents hierarchical and cell-scoped reports and changes across flow
stages in [UG906 Report Utilization](https://docs.amd.com/r/en-US/ug906-vivado-design-analysis/Report-Utilization)
(2026.1; accessed October 9, 2026). Keep reports outside maintained sources.

Measure the servo's own logic separately from `U_Math`, and RX separately from
TX observation. At the baseline, the complete record contains 809 logical bits;
four register entries plus a head declare 4,045 payload bits, or 2,427 for the
two-entry TX queue. These are source counts, not measured FF savings. Distributed
RAM consumes LUTs, and synthesis can remove unused fields or constant bits.

The GMII adapter drives only byte lane zero. `GigEthPtp` selects GMII at 125 MHz,
so integrated synthesis may already remove seven parser lanes and the wider
CRC alternatives. An unconstrained standalone frontend is not representative
of that configuration. XGMII must continue accepting eight bytes every cycle.

## Deferred follow-ups

These remain conditional on measured attribution rather than part of the
current RTL change:

- Serialize the median through one comparator if the fixed network is still
  too expensive. This changes backpressure and publication latency and needs
  busy/cancellation/snapshot checks plus an affected endpoint integration case.
- Share clamp/rounding datapaths or prove narrower intermediate widths if the
  servo's own arithmetic dominates. Preserve anti-windup decisions and exact
  overflow/rounding behavior; the [existing width audit](autonomous-endpoint.md#fixed-point-width-audit)
  already narrowed rate state and does not authorize globally narrowing epochs.
- Redesign `PtpMath` sharing or DSP use if its child utilization dominates.
  Multiplication/division is already serialized; an attribute alone does not
  replace its shift/add algorithm with a new architecture.
- Compare CRC sharing if the full-width alternatives survive synthesis and
  consume significant LUTs. The existing `Crc32Parallel` uses the same general
  parallel-transform selection and is not an automatic area improvement.

Verification follows the [focused selection policy](../../../tests/ethernet/PtpCore/README.md#selecting-tests).
Successful simulation does not establish memory mapping, LUT savings or timing
closure; retain the baseline comparison as the outstanding acceptance item.
