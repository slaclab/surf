# PTP registered module boundaries

## Goal and status

Implement the user's stronger preference for registered functional outputs.
This reopens the combinational exceptions accepted by the earlier conventions
review. Unconditional publication alone does not establish a timing boundary.
Implementation complete; simulation and pytest remain paused under the
[maintainer VHDL gate](../ethernet-ptp/README.md#current-validation).

## Design decisions

- Register RX queue selection with its valid, epoch and invalidation events.
  An event detected at edge N is visible after N and consumed downstream at
  N+1. Consumers give the visible event priority over transfer; already consumed
  work is not retroactively revoked. Trace cancellation through every boundary.
- Stage complete port-to-ledger responses and port-to-E2E operands. Hold valid
  until acceptance and freeze associated payload/configuration. Serialize E2E
  ownership through result consumption so an exchange tag cannot be overwritten.
- Register the allocation request and create TX data only on the actual ledger
  handshake. Preserve every accepted TX frame across logical restart, including
  an allocation coincident with local cancellation before that cancellation is
  visible at the ledger.
- Register port measurement and lifecycle records. PHC cancellation is sampled
  at its interface; its existing acceptance-to-commit window remains explicit.
- Register PHC completion routing. Announce potential SET/PHASE capture
  invalidation at command admission, before the commit edge, and retain the
  indication with discontinuity/fault state afterward.
- Broadcast a registered snapshot request/sequence. All banks capture pre-edge
  state on its consumption edge; the coordinator reports completion on that same
  edge. A later invalidation does not withdraw an issued observational snapshot.
- Register endpoint lifecycle/event assembly and mailbox FIFO strobes. Preserve
  reset primitives and memory inference. Retain only specifically justified
  combinational readiness, reset distribution and structural/fixture wiring.

## Validation and handoff

Source inspection traced transactions, reset, stalls, cancellation,
consume/refill and whole-record overrides. Production entity declarations and
the register ABI are unchanged; the register/ledger simulation wrappers add
observation outputs. Documentation and tests describe changed cycle semantics,
not behavioral equivalence with the previous RTL.

| Boundary | Detection/issue and consumption |
| --- | --- |
| RX queue | An enqueue/pop at N updates the registered head/valid after N. Overflow/flush at N publishes abort after N, consumed at N+1. An old head may transfer at N before that event. |
| Port lifecycle/measurement | Local decisions at N publish after N; PHC/servo/children consume at N+1. The port also suppresses new local work while that registered child cancellation is consumed. |
| Endpoint restart/flush/events | Inputs sampled at N publish after N; consumers act at N+1. MAC-change detection in the port plus endpoint assembly therefore takes two hops. |
| Ledger allocation | Port offers a registered request; its actual ready/valid handshake reserves the key and registers the first TX beat. Local cancellation coincident with acceptance must preserve that frame. |
| Ledger response | Port receives RX at N and stages the entire response. Ledger processes it at N+1 and registers acceptance. Port consumes that result with retained log-interval metadata at N+2. |
| E2E | Port stages the selected Sync, Delay, ratio and limit together. Valid holds until child acceptance. Busy owns the diagnostic exchange tag until result consumption or cancellation; no second request overwrites it. |
| PHC | Registered capacity-ready; admission at N, commit/registered response at N+1. Potential SET/PHASE capture inhibition publishes at N before commit, even if subsequently rejected. Fault/discontinuity retain inhibition with resulting state. |
| Snapshot | Registered request/sequence issue at N; all banks sample coherent pre-edge state and coordinator completes at N+1. Later inhibition cannot withdraw an issued request. |
| Mailbox | Registered FIFO writes pulse with a gap for the registered acknowledgement and retry only if unacknowledged. FIFO read data is latched on the registered take edge. SURF asynchronous resets clear a session even with a stopped clock. |

The [boundary survey](../ethernet-ptp/output-register-survey.md) covers every
module and wrapper, including remaining reverse-ready, reset/polarity and
fixture-wiring exceptions. The shared conventions now require a concrete
requirement or buffering/latency tradeoff for any exception; preserving the
old implementation alone is insufficient.

Validation on 2026-09-17:

- All 22 PTP VHDL files pass VSG with `vsg-linter.yml`. Temporary log:
  `/private/tmp/ptp-registered-boundaries-vsg.log`.
- All 21 entities/wrappers compile and link with GHDL 6.0.0, including
  `EthMacPtpEndpoint`. Used `--std=08 --ieee=synopsys -frelaxed-rules -fexplicit`
  and the isolated ruckus import from the
  [prior build handoff](../ptp-vhdl-conventions-review/README.md#validation-and-constraints),
  supplemented by `EthMacCore/rtl` and `DspXor.vhd` as in the MAC test helper.
  Manifests and source membership are unchanged. No executable was run.
  Temporary log: `/private/tmp/ptp-conventions-build-7cubpyge/registered-boundaries-compile.log`.
- Ten edited Python files pass flake8 and AST parsing without imports or
  execution. Stale `ROCE_ANALYSIS_SOURCES` imports were removed from five tests;
  those dependencies already belong to the normal ruckus import.
- Checked changed-group VHDL alignment without changing non-whitespace tokens,
  documentation link targets, production declarations and diff whitespace.

Prepared but **not executed**: RX between-edge output stability and queue
consume/overflow ordering (including every configured depth); PHC registered
ready/ack/error/capture-inhibition stability and cancel-qualified transfer;
ledger registered capacity/response pulse checks; snapshot stability and
inhibition after issue; and the two-hop MAC-change restart observation. Existing
PHC mailbox reset/stopped-peer, E2E arithmetic, port association, servo and
GMII/XGMII endpoint/MAC tests remain the integration coverage to run after
approval. The RX frame/queue oracle retains its detection-edge model; its RTL
scoreboard explicitly models the registered publication boundary.

No known-bad comparison or simulation was run because of the approval gate.
The between-edge checks would reject the old input-dependent controls, while
the queue and metadata checks exercise the new storage/ownership behavior.
After VHDL approval, execute the focused leaf and register tests first, then
port/servo and both endpoint modes. Register/operand storage has increased;
FPGA timing, resource use and physical CDC qualification remain unmeasured.
Staging and commits remain under the user's control.
