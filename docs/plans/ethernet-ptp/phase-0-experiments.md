# Phase 0 experiments

Status: experiment complete; the original RX association proposal is rejected.
The four implementation gates are not all closed. This work exercises the real Ethernet MAC with independent
Python timestamp/association models, then defines arithmetic, PHC discontinuity,
and request-lifecycle contracts. It does not implement the production PTP core.

## Work and evidence

- Add a thin physical-XGMII/bypass adapter around unchanged `EthMacTop`.
- Reproduce dropped-frame/duplicate ambiguity using real CRC and FIFO behavior.
- Exercise independent consumer stalls, event overflow, recovery, and TX pause.
- Build exact rational arithmetic and integer PHC models with directed and
  randomized tests, including epoch changes and delayed transaction completion.
- Record results and distinguish model evidence from RTL/hardware validation.

## Design gates

R3: timestamp/frame identity under loss; R4: time generation and command order;
R5: acquisition under unequal clock rates; R6: queued TX and retired wire keys.
See the [review](review-2026-09-08.md) for the original counterexamples.

## Reference-model results

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

## Real-MAC results

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

## Decisions and remaining gates

| Gate | Current status | What must happen before freezing production interfaces |
| --- | --- | --- |
| R3: association | Original key-only join and timestamp-only flush are experimentally rejected. The subsequent [RX frontend design](rx-frontend-design.md) selects and models an atomic replacement. | Verify physical adapter/validator RTL against the model and original loss stimuli; prove abort priority in its consumer and line-rate throughput. |
| R4: PHC lifecycle | Integer model passes commit-edge, generation, reset, PPS suppression, and coherent snapshot-session contracts. | Wire the generation/flush handshake through capture, packet, measurement, and command queues; verify finite token widths and independent reset recovery in RTL. |
| R5: acquisition | Equal-rate failure reproduced; unsteered-counter correction passes exact and fixed-point vectors. | Freeze rate-estimator qualification under changing path delay/oscillator rate, minimum observation span, delay-filter startup, and stale-estimate policy. |
| R6: TX lifecycle | Real MAC proves late TX; ledger tests cover early response, quarantine, wrap, and bounded outstanding work. | Freeze quiesce/drain/reset handshakes and the supported stale-packet lifetime, including key-storage/resource limits and full-reset recovery. |

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

The subsequent [R3 design comparison](rx-frontend-design.md) selects a passive
PTP receive frontend that validates CRC and emits bounded decoded-message/time
records atomically, using the bypass only to drain the MAC's redundant RX copy.
This duplicates receive validation and moves structural parser ownership out
of the port. Its reference model passes 25 additional tests; the physical
adapter and validator are not yet implemented or resource-qualified in RTL.

## Files, validation, and limits

- [Experiment wrapper](../../../ethernet/EthMacCore/wrappers/EthMacPtpExperimentWrapper.vhd)
  and its nearest ruckus simulation manifest entry.
- [MAC experiments](../../../tests/ethernet/PtpCore/test_ptp_mac_association.py)
  and [wire helpers](../../../tests/ethernet/PtpCore/ptp_wire_utils.py).
- [Reference models](../../../tests/ethernet/PtpCore/ptp_reference.py) and
  [reference tests](../../../tests/ethernet/PtpCore/test_ptp_reference.py).

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
