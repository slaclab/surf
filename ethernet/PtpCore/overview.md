# PTP architecture walkthrough

This walkthrough describes the October 15, 2026 checkout at SURF
`ed7d30cbe`. It is an orientation snapshot; the maintained SURF
[architecture guide](architecture.md),
[interface contracts](interfaces.md)
and [workstream](../../docs/plans/ethernet-ptp/README.md)
own evolving behavior and validation status.

The current design is an **autonomous PTP receiver built around three main
blocks: protocol processing → servo → PHC**. The PHC supplies timestamps back
to protocol processing, closing the loop entirely in FPGA logic.

The biggest recent changes are the decomposition of protocol processing into
smaller owners, removal of the general shared compute engine, and migration
to record-based interfaces.

## Start at PtpEndpoint

[PtpEndpoint.vhd](rtl/PtpEndpoint.vhd)
is the integration boundary for the autonomous timing subsystem. It receives
**validated messages with their physical captures already attached**, emits
Delay_Req frames, and exports time, PPS, validity and status.

Its current hierarchy is:

```text
PtpEndpoint
├── PtpEndpointControl       Global enable, commit, snapshot, restart, IRQ
├── PtpProtocolEngine        Messages → timing measurements
│   ├── PtpProtocolReg       Protocol configuration and diagnostics
│   ├── PtpPortPolicy        Source/domain admission and lifecycle
│   ├── PtpSyncFlow          Coordinates association and measurement work
│   │   ├── PtpSyncPair      Completes Sync / Follow_Up transactions
│   │   ├── PtpSyncHistory   Retains completed Syncs for delay exchanges
│   │   ├── PtpTableScan     Shared table age/distance comparisons
│   │   ├── PtpRateEstimator Master-time / raw-local-clock ratio
│   │   └── PtpE2e           End-to-end path-delay arithmetic
│   ├── PtpDelayReqTx        Request scheduling and frame production
│   └── PtpTxLedger          Reservations, actual TX, and response matching
├── PtpServo                 Measurements → clock commands
│   ├── PtpServoFilter       Path-delay median
│   └── PtpServoPi           Acquisition, PI control, holdover
├── PtpPhc                   Running clock and command application
├── PtpSecondService         Shared seconds/remainder conversion
├── PtpVariableDivide        Shared variable division
└── AXI-Lite crossbar / optional TX stream resize
```

The endpoint runs in one continuously running Ethernet/PHC clock domain:
125 MHz for GMII or 156.25 MHz for XGMII. Each endpoint has its own PHC, servo
and arithmetic services.

## Physical observation outside the endpoint

`EthMacPtpEndpoint` combines the endpoint with `EthMacTop`, passive RX/TX
timestamp taps and a primary-stream guard.

The RX tap captures time at the first destination-MAC octet, validates the
frame—including FCS—and delivers one atomic message/capture record. The TX
tap observes when a Delay_Req actually reaches the physical interface. Thus
MAC queueing, pause and backpressure do not become timestamp errors.

The guard reserves untagged EtherType `0x88F7` for the endpoint's private PTP
producer. Above this composition, `GigEthPtp` adds Ethernet registers and
management CDC; family wrappers add the PHY.

## Protocol policy and execution

[PtpProtocolEngine.vhd](rtl/PtpProtocolEngine.vhd)
is now a structural coordinator. Its children own the actual state:

- **`PtpProtocolReg`** owns configuration, identity and diagnostic banks.
- **`PtpPortPolicy`** decides whether traffic belongs to the configured
  source/domain, tracks receipt deadlines and Announce information, and
  initiates cancellation/reacquisition.
- **`PtpSyncFlow`** coordinates accepted work and publishes measurements.
- **`PtpDelayReqTx` and `PtpTxLedger`** handle the outgoing exchange and its
  physical lifetime.

The implemented scope remains a **fixed-source Layer-2 E2E TimeReceiver**,
with per-message one-step/two-step Sync reception. Upstream selection is
configured; BMCA, UDP/VLAN PTP and peer-delay operation are outside the
current implementation.

## Follow a Sync through pairing and history

[PtpSyncPair.vhd](rtl/PtpSyncPair.vhd)
answers: *“Do these received messages form one usable Sync sample?”*

It owns four association rows, including expiry, duplicate handling and
completion:

- A one-step Sync supplies the origin timestamp directly.
- A two-step Sync contributes the local RX capture; its Follow_Up supplies
  the precise remote origin timestamp.
- Sync and Follow_Up may arrive in either order.
- Correction fields are combined according to the selected mode.
- Conflicting duplicates and invalid associations are retired according to
  the receiver policy.

A particularly useful detail when reading its interface is that
**`result.done` does not necessarily mean a usable sample exists**. It means
processing of that RX record completed; `result.sampleValid` identifies a
completed Sync sample.

[PtpSyncFlow.vhd](rtl/PtpSyncFlow.vhd)
takes that sample through `PtpRateEstimator`. The estimator compares corrected
master-time progression with **unsteered local ticks and phase**, producing
master nanoseconds per raw local cycle.

That separation matters: changing the PHC increment must not distort the
estimate of the underlying oscillator's rate. It also lets rate qualification
begin before path delay is known.

An accepted Sync is appended to `PtpSyncHistory`, and the flow publishes a
forward measurement for the servo. These are distinct responsibilities:

| Block | What it retains |
| --- | --- |
| `PtpSyncPair` | Messages being associated into a Sync sample |
| `PtpSyncHistory` | Completed Sync samples available for later delay calculation |
| `PtpSyncFlow` | Coordination and outstanding measurement/publication work |

Pair and history share `PtpTableScan` for word-serial age/distance calculations.
Each table still owns its RAM and state machine.

## Delay_Req supplies the other half of the measurement

`PtpDelayReqTx` schedules a request and reserves its key in `PtpTxLedger`
before presenting the first frame beat. The ledger then joins:

- The reservation identifying this request.
- Its actual physical TX capture, **t3**.
- The matching Delay_Resp carrying the remote receive timestamp, **t4**.

Physical completion and response can reach the ledger in either order.

Once the exchange is complete, history chooses the nearest eligible Sync
capture **t2**, with its corresponding remote Sync timestamp **t1**.
`PtpE2e` uses those values and the qualified rate ratio to calculate path delay.

For intuition, with equal-rate clocks:

```text
forward   = t2 − corrected t1
reverse   = corrected t4 − t3
meanDelay = (forward + reverse) / 2
```

The actual implementation accounts for oscillator-rate difference and
capture-specific ingress/egress calibration.

The ledger's central rule is worth remembering: **logical cancellation cannot
prove a queued frame disappeared from the MAC**. Restart or timeout therefore
preserves unresolved physical ownership, preventing a late transmission or
response from being associated with a reused key.

## The servo consumes two kinds of measurements

Forward Sync measurements and completed delay measurements share the
measurement interface, but serve different purposes.

`PtpServoFilter` retains up to five path-delay samples and publishes their
median. `PtpServoPi` evaluates forward measurements against that filtered delay:

```text
localMinusMaster = forward − filteredDelay − configuredAsymmetry
```

[PtpServoPi.vhd](rtl/PtpServoPi.vhd)
owns the control behavior:

- **Acquisition:** while time is invalid, an allowed large phase adjustment
  can establish the epoch.
- **Tracking:** the qualified raw-clock ratio bootstraps frequency control;
  proportional/integral corrections adjust the PHC increment, with clamps
  and anti-windup.
- **Holdover:** phase slew is removed, the last committed frequency is
  retained, and validity eventually expires without fresh evidence.

A computed command remains a candidate until the PHC acknowledges it
successfully. Frequency and sample history commit on successful RATE
acknowledgement.

## PtpPhc is the continuously running timekeeper

It owns seconds, nanoseconds and fractional time, plus raw ticks, generation,
validity and PPS. Its ordinary tick path never waits for packet arithmetic.

It arbitrates manual and automatic commands and applies them at defined
commit edges. Captures retain generation and the active increment, allowing
later processing to reject obsolete samples and interpret calibration using
the rate that existed at capture time.

This is currently **numerical clock discipline**. `PtpServoPi` changes the
PHC increment; it does not tune the oscillator supplying `clk`. Physical
PLL/VCXO discipline and application epoch/event generation remain separate
integration work.

## Records and arithmetic ownership

[PtpSyncPkg.vhd](rtl/PtpSyncPkg.vhd)
and
[PtpServoPkg.vhd](rtl/PtpServoPkg.vhd)
now group related payloads and qualifiers into records.

Read the comments above each record carefully: some results are held until
accepted, some completion signals pulse, and some payloads remain borrowed
from their original owner after completion. Clocks, cancellation and reverse
handshakes remain separate where their lifetimes differ. The record conversion
was intended to preserve datapaths, storage layouts and cycle behavior.

The other major change is arithmetic ownership: **`PtpCompute` and its
addressed operand workspaces are gone**. Algorithms retain named local state;
only variable division and seconds conversion remain shared. That makes the
algorithm flow easier to follow, although the recorded replacement has an
area cost.

Software reaches four endpoint banks—control, PHC, protocol and servo—with
coordinated configuration commits and snapshots. Rogue configures and observes
these banks; it is outside the timing loop.

## Validation at the time of this walkthrough

The latest record-interface work has 59 recorded focused passing
configurations. Full closed-loop endpoint/real-MAC validation of the latest
source, the replacement service-bound proof, and hardware accuracy
qualification remain open. The maintained
[architecture guide](architecture.md)
and [interface contracts](interfaces.md)
provide the next level of detail; the
[workstream](../../docs/plans/ethernet-ptp/README.md)
tracks subsequent validation.
