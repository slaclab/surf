# Depacketizer2 link-loss cleanup history

Status: source-history investigation, 2026-09-25. No RTL or protocol change is
selected here. See the [work record](README.md), [findings](findings.md), and
[current specification](../../../protocols/packetizer/spec/packetizer2.md).

## Origin and stated purpose

`linkGood` and `TERMINATE_S` were introduced together on 2017-04-17 in commit
`feaceb989ace1d85469e0cfdd6c7a64ec6cf7ada`, ten days after the initial
Depacketizer2 creation (`c3c596121`, 2017-04-07). The original file was
`axi/rtl/AxiStreamDepacketizer2.vhd`.

The introduction's complete commit message states:

> Added a TERMINATE_S state and linkGood input. When linkGood falls, any active frames are terminated with EOFE.

The immediately following integration commit,
`8746188234343640660d5343656764a303ce1549`, connected PGP3's local receive
link-ready indication to this input. Its message is "Make use of new linkGood
frame termination in Depacketizer". This establishes an early PGP3 origin.
PGP4 and RSSI subsequently inherited the mechanism.

The introducing commits do not cite a particular field failure or provide
a separate recovery contract. The surrounding PGP3 and Depacketizer2 commits
describe early development and incomplete testing. That is historical context,
not proof that a particular later defect was already present or untested.

## Evolution established by the diffs

| Date | Commit | Relevant change |
| --- | --- | --- |
| 2017-04-07 | `c3c596121` | Creates Depacketizer2 with header/move states and per-destination sequence/active/error state; no `linkGood` input |
| 2017-04-17 | `feaceb989` | Adds link-driven termination, walks destination state, clears it, and emits EOF+EOFE for active entries |
| 2017-04-17 | `874618823` | Connects the new mechanism to PGP3 receive link readiness |
| 2018-01-31 | `ac3334929` | Adds RSSI interleaving/V2 integration and connects `linkGood` to RSSI connection status |
| 2018-02-26 | `0dc93f70a` | Adds delayed link status and falling-edge detection; reset now enters `TERMINATE_S`; changes the scan to stop at an address limit and wait for link return |
| 2018-02-27 | `1b1c1db32` | Adds block-RAM configuration and associated state/read-latency handling |
| 2018-03-02 | `35f544ab8` | Adds configurable destination width, a descending sweep, and explicit `initDone` completion state |
| 2019-06-19 | `e52f5db32` | Adds explicit 0/1/2-cycle read-latency tracking for termination across RAM/register combinations and exposes retained `debug.initDone` |
| 2022-11-21 | `5c2715889` | Adds zero-sequence RX configuration using a shared register instead of the destination RAM; this later requires special care during cleanup |
| 2026-09-24 | `cdde579cb` | Corrects which destination entry is cleared and consumes output stages when advancing them; adds focused cleanup regressions |
| 2026-09-25 | `5c9aca7c4` | Retains pending final termination through reconnect and restarts initial RAM latency; adds reconnect/traffic/backpressure regressions |
| 2026-09-25 | `5520beec2` | Defers clearing shared no-sequence state until consumption and corrects zero-width termination destination handling |

The original 2017 implementation was materially different from the current
one. Low `linkGood` requested termination, the scan advanced while output had
capacity, and high `linkGood` returned directly to header processing. There
was no full-sweep completion condition. A quick reconnect could therefore
end the scan before all contexts were visited. Register reset still started
in `HEADER_S` at that point.

The 2018 changes made completion independent of early link return and reused
the termination path for initialization. The later RAM and pipeline options
added scheduling obligations to the same state. These are observations from
the diffs; the brief commit messages do not establish every design rationale.

The original termination feature also predates the present per-destination
CRC-remainder implementation. Its 2017 context RAM held sixteen sequence bits
and two flags. Aborting open output frames was already a problem independent
of the later CRC-state machinery.

## Functional need and architectural interpretation

Link loss can leave two different kinds of unfinished work:

1. Internal receive state expects a continuation, with sequence, frame-active,
   and CRC state that should not survive into an unrelated new session.
2. Downstream consumers may already have accepted part of an application
   frame and still be waiting for its end.

Resetting or invalidating the depacketizer's state addresses the first.
It cannot retract payload already delivered or close a frame held by a
downstream consumer that was not also reset. Under the current streaming
interface, synthetic EOF+EOFE supplies that notification. Multiple destinations
can have open frames, which explains the need to enumerate affected contexts.

A table sweep is one way to perform that enumeration and clear RAM-backed
state. The externally meaningful requirement is coherent frame abandonment
and subsequent recovery; the particular scan direction or RAM traversal is
an implementation choice unless a consumer depends on its ordering.

The current `TERMINATE_S` combines several responsibilities:

- Initialization and invalidation of context state.
- Preservation and draining of pending output.
- Generation of per-destination error terminations.
- Waiting for the transport to become usable again.
- Arbitration with normal header processing for RAM and output capacity.

This combination explains why storage latency, backpressure, repeated link
flaps, early fresh traffic, and the no-sequence special case interact. The
2026 fixes protect the existing contract; they do not establish that this is
the clearest possible architecture.

## Alternatives and unresolved contract questions

These are design questions, not approved implementation changes:

- A coordinated reset/flush of the depacketizer and all affected downstream
  frame consumers could abandon frames without in-band terminations. Existing
  downstream reset and buffering assumptions would need to support that.
- An explicit abort request/completion contract could separate transport
  status from reassembly cleanup. The wrapper would translate PGP link loss
  or RSSI disconnection into that request. Renaming the input alone would not
  address pending-output ownership or completion semantics.
- A smaller active-context tracker could avoid scanning inactive entries.
  It would still have to generate and retain required downstream terminations.
- Accepting a fresh SOF as resynchronization can repair internal state on
  demand, but does not immediately close quiet destinations' downstream frames.
  It needs a compatible downstream abandonment rule.

The contract still needs to distinguish context invalidation, sweep completion,
and downstream acceptance of the last termination. Current `debug.initDone`
describes the sweep; it is not a promise that every termination has transferred.
Hard reset and graceful abort also need separate observable expectations.
None of these requirements disappears by selecting independent packet CRCs.

## Evidence and validation

The investigation used local `git log --follow`, pickaxe searches, commit
messages, and diffs through the `5520beec2` RTL baseline. For example:

```sh
git show feaceb989 -- axi/rtl/AxiStreamDepacketizer2.vhd
git show 874618823 -- protocols/pgp/pgp3/core/rtl/Pgp3Rx.vhd
git show 0dc93f70a -- axi/rtl/AxiStreamDepacketizer2.vhd
git show 35f544ab8 -- axi/rtl/AxiStreamDepacketizer2.vhd
git show e52f5db32 -- protocols/packetizer/rtl/AxiStreamDepacketizer2.vhd
```

The 2017 introducing/integration commits did not add a dedicated link-cleanup
test. The existing [V2 VHDL bench](../../../protocols/packetizer/tb/AxiStreamPacketizer2Tb.vhd)
ties `linkGood` high. The standalone
[mid-packet drop test](../../../tests/protocols/packetizer/test_AxiStreamDepacketizer2LinkDrop.py)
appears in the inspected history in June 2026; the broader
[cleanup](../../../tests/protocols/packetizer/test_AxiStreamDepacketizer2Recovery.py)
and [reconnect](../../../tests/protocols/packetizer/test_AxiStreamDepacketizer2Reconnect.py)
regressions accompany the September 2026 fixes. External test coverage has not
been inventoried.

Historical commit messages report regression results for the recent fixes.
Those results were not rerun for this investigation. No HDL or test changes
were made; documentation links and whitespace were checked separately.
