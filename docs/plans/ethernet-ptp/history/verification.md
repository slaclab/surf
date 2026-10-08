# Historical PTP verification evidence

These milestones predate the current RTL approval gate. They are retained as
bounded evidence, not current pass claims or permission to rerun simulations.
Use the [current review/acceptance record](../rtl-review.md) for outstanding work
and the [test guide](../../../../tests/ethernet/PtpCore/README.md) for procedures.

Consolidated October 8, 2026 from the Phase 0, RX proof, autonomous-endpoint and
register-ownership records in SURF `39604a8aba78163c47d32e9de712f6942a2d1d4c`
plus the existing staged documentation edits. The source notes did not record
an exact RTL revision for every run; this is document provenance, not a new
verification baseline. Historical entity names and tool availability refer to
those runs. No new behavioral checks were executed for this consolidation.

## Phase 0 counterexamples

The final pure-Python run passed 35 tests. These cover exact unequal-rate
exchanges, signed correction/asymmetry, large epochs, 8,000 randomized PHC
ticks/commands, 2,000 fixed-point delay vectors, atomic queue overflow/flush,
snapshot cancellation, and a small sequence space that forces TX-key wrap.
They validate proposed contracts, not an RTL implementation or CDC circuit.

The unequal-rate counterexample is reproduced: a fast local clock can yield
negative path delay on a short link before the servo starts. A rate estimate
from two Sync observations can recover delay without first requiring valid
delay. The tested fixed-point alternative reconstructs elapsed master time
from an unsteered tick span and Q16.48 nanoseconds per tick; over the tested
interval/rate envelope its delay error is at most one Q16-nanosecond LSB.
This excludes rate-estimator uncertainty and packet-delay variation.

### Real-MAC results

All three cocotb scenarios passed with GHDL 6.0.0 and cocotb 2.0.1. They use
the unchanged `EthMacTop`, 156.25 MHz XGMII, a 512-word RX FIFO, common primary
and bypass clocks, and error-frame dropping enabled. Timestamps and the
rejected matcher are Python models observing the actual physical input;
there is no production PTP timestamp RTL in this experiment.

| Experiment | Observed result | Consequence |
| --- | --- | --- |
| Byte order | Wire `88 F7` reached bypass; `F7 88` reached primary. | The corrected `x"F788"` bypass generic is required. |
| CRC-bad A followed by valid same-key B | A was dropped by the MAC; the modeled header-only tap still emitted its physically valid event. Delaying B's event let the proposed join choose A for B, 1,040 ns early. | A unique live header-key pair is not proof of physical frame identity. |
| CRC drop indication | `rxCrcErrorCnt` asserted, but `rxFifoDrop` never asserted for that discard. | Flushing on aggregate FIFO-drop status alone misses this failure. |
| Backpressured RX FIFO | 240 valid wire frames produced 130 delivered duplicates and 1,234 asserted drop-status cycles. A subsequent fresh-key frame passed. | Captures and delivered packets diverge. Drop-status cycles are not a one-to-one count or identity of lost packets. |
| Timestamp-side restart with retained RX data | Modeled capture 239 paired with the previously observed, stalled FIFO-head frame 0. | Clearing timestamp tables without invalidating/draining the packet path can reverse the aliasing error. |
| Logical restart during TX pause | An accepted Delay_Req reached the wire after logical restart and repeated pause refresh. Its retired ledger entry rejected completion/response. | Protocol retirement cannot cancel a frame accepted by the MAC. |

Both legal XGMII start lanes are exercised. The physical observer checks FCS
independently against the real MAC and records message-point timestamps.
Oracle-only wire identities are used to detect mismatches; they are never
available to the proposed header-key algorithm. The CRC test deliberately
withholds the oracle's CRC knowledge from that algorithm, matching a tap that
checks coding/header fields but delegates FCS validation to the MAC.

### Reference contracts and interpretation

Use these concrete reference contracts for the next design iteration:

- PHC reset wins over a pending command. Discontinuity commits suppress capture
  and PPS, clear validity, and invalidate old-generation work. A phase/epoch
  delta applies at the commit edge after the ordinary increment; a new rate
  applies beginning with the following increment. Watchdogs use unsteered time.
- A snapshot reset cancels the pending transaction. After reset recovery, a
  fresh session/token is required; an old completion cannot satisfy the new
  request. This is a behavioral requirement, not a modeled synchronizer.
- An atomic capture queue carries the validated message's identity and its
  timestamp as one item. The candidate model gives overflow/flush priority
  over same-edge consumption and invalidates the queue generation. This
  prevents aliasing by construction only if the producer really binds the
  message to its capture before any independent drop.
- A logically retired request with unknown wire fate keeps both its key and
  outstanding slot reserved. Continuous pause can exhaust admission capacity;
  it cannot make the endpoint reuse unresolved keys. A known TX capture starts
  a bounded network-lifetime quarantine. Link-only restart preserves that state.


### Files, validation, and limits

- [Experiment wrapper](../../../../ethernet/EthMacCore/wrappers/EthMacPtpExperimentWrapper.vhd)
  and its nearest ruckus simulation manifest entry.
- [MAC experiments](../../../../tests/ethernet/PtpCore/test_ptp_mac_association.py)
  and [wire helpers](../../../../tests/ethernet/PtpCore/ptp_wire_utils.py).
- [Reference models](../../../../tests/ethernet/PtpCore/ptp_reference.py) and
  [reference tests](../../../../tests/ethernet/PtpCore/test_ptp_reference.py).

Validation run:

```sh
make MODULES="$PWD" import
./.venv/bin/vsg -c vsg-linter.yml -f ethernet/EthMacCore/wrappers/EthMacPtpExperimentWrapper.vhd
./.venv/bin/flake8 tests/ethernet/PtpCore
./.venv/bin/python -m pytest -n 0 -q --log-cli-level=INFO tests/ethernet/PtpCore
./.venv/bin/python -m pytest -n 0 -q tests/ethernet/PtpCore/test_ptp_reference.py
git diff --check
```

Import, lint, and whitespace checks passed. The combined run passed its three
cocotb scenarios and 34 then-current reference cases in about 232 seconds.
After tightening the reference ledger's outstanding-slot bound, its focused
rerun passed all 35 reference cases; no MAC RTL or wire stimulus changed after
the combined run. The installed VSG requires `-f` to separate the VHDL input
from `-c` configuration arguments. Simulator-process checks found no stale
children after completion. Local documentation links and SVG XML were checked.

The GHDL import excludes the Ethernet RTL subtree by its existing architecture
guard; the cocotb runner explicitly analyzes the actual MAC and experiment
wrapper as the existing Ethernet suites do. Vivado manifest execution,
GMII integration, hardware latency, a production parser/timestamp tap, servo
convergence under jitter, and real CDC are not validated by this pass. The
standard import needed sandbox escalation for Tcl temporary-file handling;
an initial captured-log run was interrupted to enable live diagnostics, then
the focused and combined MAC runs passed.

## RX boundary model

[The executable model](../../../../tests/ethernet/PtpCore/ptp_rx_reference.py)
consumes normalized wire bytes and computes CRC using an independent bitwise
oracle; [the tests](../../../../tests/ethernet/PtpCore/test_ptp_rx_reference.py)
encode FCS with zlib. The 25 tests pass CRC-bad/valid duplicates, distinct
same-key captures, retained-head restart, mid-frame/EOF reset, stale generation,
overflow simultaneous with consumption, 1/8-byte groups, signed correction,
all final-byte positions, empty termination, sub-cycle unsteered provenance,
four message types, malformed lengths/TLVs, maximum
frame length, bounded unterminated input, and 400 randomized frames with stalls
and restart. Combined with the existing arithmetic/PHC suite: 60 tests passed.
Flake8 and documentation/whitespace checks also passed.


## RX RTL proof

At this milestone, the producer was implemented before the integrated protocol
consumer. TX completion and PHC/servo integration described as future work in
the source note are now implemented; current timing comes from the maintained
contracts. The historical scoreboard used detection-edge abort semantics.

The final physical regression passed three configurations: direct/depth-one,
XGMII/depth-four with +7.25 ns ingress calibration, and GMII/depth-four with
−3.5 ns calibration and active-low asynchronous reset. Each compares queue
head, complete record fields, generation/epoch, transfer/abort, and admission/
overflow counters against the independent bounded model on every edge.

The real-MAC proof passed: all 240 valid frontend records retained their own
wire timestamps while a stalled 512-word MAC RX FIFO dropped copies. A bad-FCS
duplicate emitted no record. Restarting the frontend while old MAC data stayed
buffered did not publish that old data when the MAC later drained. Independent
frontend overflow flushed its queue and recovered on a fresh frame.

The final model/RTL run passed 63 pytest cases: 60 Python reference cases and
three cocotb configurations. Coverage includes both minor versions, rejected
EtherType/version/type/length, every final-byte alignment, empty termination,
maximum-length TLVs, unterminated oversize, exact twelve-slot XGMII gaps,
non-nominal PHC increments, second carry/borrow, epoch-underflow rejection,
stalls, full-before-edge overflow with ready high, and flush/generation/reset
at physical or completed-frame boundaries. Clocks are 125 MHz for GMII and
156.25 MHz for XGMII. `TPD_G` is the default 1 ns in these runs.

The three legacy MAC counterexample scenarios also passed. The final RX/MAC
scenario passed in a separate rerun after correcting a wrapper-formatting
compile error in the combined invocation; the error did not alter production
RTL. In total, 60 reference cases and seven cocotb scenarios passed. The last
wrapper formatting pass was checked to preserve all non-comment VHDL tokens.
All five edited VHDL files passed VSG, Python passed flake8, the final ruckus
import passed, and local documentation links/SVG XML and whitespace were checked.

GHDL synthesis succeeded for the validator and both physical adapter choices.
Inspection prompted moving capture arithmetic out of the eight-lane decoding
loop so it is computed once per accepted SOF. Synthesis passed again after
that change. This source restructuring is not a measured device-area saving.
Generated netlists and logs stay in temporary storage. They are
generic synthesis evidence, not a device utilization or timing report. Vivado
and Yosys are unavailable on this host; routed 125/156.25 MHz timing and FPGA
LUT/FF/BRAM counts remain unverified.

Historical commands from the repository root (not permission to resume tests):

```sh
make MODULES="$PWD" import
./.venv/bin/python -m pytest -n 0 -q tests/ethernet/PtpCore
./.venv/bin/flake8 tests/ethernet/PtpCore
./.venv/bin/vsg -c vsg-linter.yml -f ethernet/PtpCore/rtl/*.vhd ethernet/PtpCore/wrappers/*.vhd ethernet/EthMacCore/wrappers/EthMacPtpExperimentWrapper.vhd
git diff --check
```

GHDL synthesis used a temporary `surf` library analyzing `StdRtlPkg`, `AxiPkg`,
`AxiStreamPkg`, `SsiPkg`, `CrcPkg`, and the three PTP RTL files, with
`--std=08 --ieee=synopsys -frelaxed-rules`. `ghdl --synth` then targeted
`PtpRxFrontend` and `PtpRxTimestampAdapter` with default XGMII and with
`-gPHY_TYPE_G=GMII`. Calibration was zero for these generic synthesis runs;
the nonzero signed calibration cases were simulated. Device qualification must
check the unrolled decode/length paths and wide capture normalizer, adding
pipelines if needed while preserving capture, completion, and abort together.

## Autonomous endpoint milestone

- **The original autonomous milestone passed 101 distinct pytest cases.** This
  includes 84 pure reference cases and 17 parameterized RTL cases; some RTL cases
  contain more than one cocotb scenario. The two PHY closed-loop cases also pass
  independent absolute-phase checks after acquisition and reacquisition.
- Baseline: 60 reference cases and seven cocotb scenarios for the RX proof.
- New focused arithmetic/PHC/E2E/ledger/servo/reference run: 31 pytest cases pass.
  PHC cases also exercise independent-clock snapshot cancellation, a stopped
  PHC peer clock, and validity/PPS revocation coincident with seconds rollover. The ledger uses narrow sequences to force wrap and retirement.
- Register/PHC test passes shadow atomicity, alignment/strobes, command operand
  latching, backpressure, register-only reset, snapshots, identity changes and IRQ.
- XGMII +100 ppm with initial phase step and GMII −100 ppm without a step pass
  acquisition, lock, holdover expiry and reacquisition. At both lock checkpoints,
  PHC time compared directly with independent simulated master time has absolute
  error below 100 ns; generation counts also confirm the intended step policy.
  These two cases took 800.50 s with two workers on this machine.
- Physical adversarial port tests pass Follow_Up reordering, duplicate/conflicting
  keys, foreign source, invalid timestamps, completed-slot retirement, Sync
  timeout, grandmaster/timescale-change abort, Announce metadata, and every TX beat held
  across port reset and drained afterward.
- VSG and Python lint pass. Generic GHDL synthesis passes PHC, arithmetic, E2E,
  ledger, port, servo, registers, endpoint, primary guard and TX timestamp tap.
  The TX builder uses static slices after GHDL rejected its variable part select.
- The subsequent SURF style pass aligns declarations, record initializers and
  port maps, expands dense statements, and preserves the VHDL token sequence and
  comment text in all 22 PTP sources. Repository VSG and HDL import pass; the
  31-case arithmetic/PHC/E2E/ledger/servo/register/reference regression passes
  again after formatting (47.31 s).
- Optional `PtpPhcRead` generic synthesis is blocked in the existing SURF
  `SimpleDualPortRam.vhd` conditional write-enable assignment: GHDL reports a
  27-versus-1 vector-width mismatch for the 209-bit response FIFO with byte
  writes disabled. Mailbox simulation passes. This feature does not alter the
  shared RAM primitive; its device synthesis/CDC qualification remains open.
- Real-MAC lifecycle tests pass on both GMII and XGMII: primary payload, PTP
  identity guard, pause/port restart, retired late completion and fresh recovery.
  The pair took 1217.69 s with two workers during concurrent verification work.
- All 65 existing RX/reference/MAC-association pytest cases pass after integration.
- PyRogue syntax and 99 register fields were checked for address-bit overlap;
  a live PyRogue import/transport test remains unavailable on this machine.


### Review-gate disposition

| Review finding | Local evidence / remaining boundary |
| --- | --- |
| R3: RX frame identity after hidden MAC drops | Atomic message/capture RX replaces the disproved queue association; physical and real-MAC loss tests pass. |
| R4: generations, raw timers, reset/CDC | PHC cycle model, generation cancellation, stopped-peer snapshot sessions and register-only reset are implemented/tested; physical CDC qualification remains. |
| R5: oscillator-error bootstrap | Independent raw-tick estimator and rate-corrected E2E/calibration models, leaf RTL scoreboards and physical closed-loop cases; see the stated envelope above. |
| R6: persistent TX fate | Bounded keyed ledger, forced wrap/quarantine tests, stalled beat preservation and actual paused MAC requests on both PHYs. |
| R7: numerical encodings and timing | Q-format contracts, serialized checked engines, independent PI sweeps and command scoreboard; generic synthesis passes, device path/resource budgets remain open. |
| R8: timed events | Subsequent application timing milestone; no scheduler is implemented here. |
| R9: profile and interoperability | Concrete fixed-source parser/policy and adversarial packet fixtures exist; pinned external-master/packet-capture interoperability fixture remains open. |
| R10: hardware qualification | Select board, GT path, instrument and part; no hardware accuracy or family-wide timing claim follows from these simulations. |


## Register ownership milestone

- Nine focused pytest cases pass after folding the banks into the functional
  cores: both zero/nonzero AXI bases, four static software/RTL schema checks,
  two PHC clock/reset configurations and the servo regression.
- The register tests cover unrelated-high-address rejection, every bank's
  error/strobe behavior, local validation rejecting all candidates, shadow
  mutation after prepare, authoritative shared limits, common snapshot sequence
  and capture edge, immutable phase commands and register-reset recovery.
- An accepted commit survives AXI reset during preparation and completes once;
  an accepted snapshot survives reset while capture is inhibited. Software
  recovers completion through the surviving sequence registers.
- All PTP VHDL passes the repository VSG rules; changed Python passes flake8.
  Ruckus/GHDL import passes. Generic synthesis passes for `PtpReg`, `PtpPhc`,
  `PtpPort`, `PtpServo` and `PtpEndpoint`, with local AXI enabled in the cores.
- The updated SVG has been rendered and visually checked.
- Final GMII/XGMII autonomous endpoint, real-MAC lifecycle and port regressions
  were stopped at the maintainer's request before completion. They do not count
  as passing validation of the folded cores.
- No Vivado/VCS, physical timing/CDC or live Rogue transport qualification is
  implied. The previously documented optional snapshot FIFO synthesis issue
  remains outside this refactor.


## Interface-record conversion

At the initial record-conversion checkpoint, all 22 PTP VHDL files passed VSG, and all 21 RTL entities/wrappers
compile and link with GHDL; no simulator executable was run. Static comparison
confirms that command/servo/control/capture/frontend combinational equations
are preserved under the field renaming, apart from routing the PHC error into
its owner-specific command response. See the
[current validation record](../README.md#current-validation).
No regression result predating this pass establishes its behavioral correctness.
After approval, rerun command cancellation/ownership, distributed commit and
snapshot, and RX capture/counter checks before the endpoint regressions.


Later registered command/cancellation/expiry timing superseded the conversion
comparison; it cannot be treated as an equivalence proof for the redesign.
