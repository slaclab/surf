# PtpServo and PtpRxFrontend LUT optimization

October 9, 2026. Goal: reduce combinational logic while preserving numerical,
packet-validation, queue and cancellation behavior. The maintainer reported
high LUT use relative to registers; synthesis reports are on another machine.
Optimization baseline: SURF `6db41ad53ed5d17491fcfddfcff30325755d244f`. Subsequent
FIFO validation uses `2bb198b10efc964f1d861ebc34a33d214052afd7` plus the local
optimization patch. Independent protocol/specification changes are outside
this optimization. No resource reduction has been measured yet.

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
