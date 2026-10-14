# Deferred PTP design studies

These options remain unimplemented unless the current
[architecture](../../../../ethernet/PtpCore/architecture.md) says otherwise.
They are not commitments or prerequisites for the initial endpoint. This summary
retains each idea's purpose, reason for deferral and conditions for revisiting it;
the original detailed proposals and source survey are recoverable through the
[provenance index](decisions.md#source-provenance). Previously gathered vendor
and literature findings must be checked against the chosen hardware before reuse.

## Application scheduling

Keep the time service separate from application actions. Software could arm an
absolute future PHC time on each endpoint through ordinary Rogue/AXI access;
sequential writes need not cause execution skew when all endpoints execute the
same future deadline. A custom PTP TLV or multicast command protocol is not
required to establish that basic model.

A future scheduler needs generation-tagged atomic enqueue, bounded lead time,
first-crossing-edge execution, explicit late/invalid/holdover policy, and retained
results. Exact equality with a fractional PHC is not a reliable trigger. A
clock step must invalidate old events; crossing to another domain must preserve
payload and destination capacity. Queue depth, ABI and cancellation priority are
not frozen. Multi-endpoint cancellation is best effort; all-or-none physical
action needs an application interlock. A once-started free-running local counter
will drift unless reanchored or physically disciplined.

Revisit for a concrete application's timing and failure requirements. The old
provisional register groups and detailed enqueue workflow are retired proposals.

## Shared simulation time

Retain two different purposes: real packet/PHY simulation for endpoint behavior,
and a fast common time model for multi-endpoint application tests. A proposed
process-local publisher/subscriber registry would distribute time anchors and
rates without a software process advancing every tick. Session/generation tags,
absent/stale publisher handling and a deterministic effective-time edge are needed.

An external SimLink Timing transport would be a separate protocol; existing
Stream/Memory/SideBand do not supply this timing contract. Multiple simulators
also require time grants or rendezvous: exchanging anchors alone cannot prevent
one process from advancing past another's future event. Revisit when an application
fixture needs it; neither registry nor external bridge gates hardware PTP.

## Physical frequency output and advanced timing

A fabric accumulator reference with external PLL/VCXO cleanup and repeated MMCM
phase stepping were studied as physical-output candidates. Use the **applied**
PHC increment with explicit units; a computed servo diagnostic can precede command
commit. Fine average-frequency control does not eliminate edge quantization,
deterministic spurs or reset discontinuities. The maintained
[physical-clock requirements](../../../../ethernet/PtpCore/physical-clock.md)
own actuator separation, continuity, epoch and qualification policy.

The earlier survey considered external DPLL/VCXO control, fabric MMCM phase walk,
per-channel GT phase interpolation (PICXO), and fractional GT PLL control (FRACXO).
A shared PLL affects every lane using it; a useful fabric output may require an
available clocked GT channel. Literature measurements from other boards were
not project accuracy results and are not retained as selection targets here.

The 7-series XAPP589 study found that the inspected legacy GTX checkpoint's
attributes/tie-offs and wrapper clock/DRP ownership were not ready for that
actuator. A supported regeneration and new clock/reset/arbitration integration
would be required; wrapping the existing DCP alone would not suffice. This was
a historical inspection, not a qualification of current assets. Full settings,
references (XAPP589/1241/1276/1383, clocking guides and Light Rabbit) remain in
the original survey in Git.

SyncE/White Rabbit needs recovered-clock frequency transfer, fine phase control,
PHY latency/asymmetry calibration and protocol integration beyond a numerical
PHC. Revisit only with a selected board, clock route and measurable jitter,
phase, holdover and interoperability requirements. No surveyed actuator alone
establishes complete White Rabbit support.

## Additional PHYs and protocol modes

Extend the common GMII/XGMII composition for concrete consumers, qualifying each
FPGA/GT/IP/rate/reset combination. The previous family coverage matrix and
GTX7-first roadmap were proposals, not supported-device claims. Clock continuity,
reset-dependent latency and calibration cannot be inferred from another wrapper;
a shared clock net does not turn independent endpoints into a boundary clock.

BMCA, VLAN/UDP, Pdelay, one-step transmit, transparent/boundary clocks, unicast,
security, higher Ethernet rates and additional timestamp/event channels need
separate requirements and interface work. Refer to the
[current composition guide](../../../../ethernet/PtpCore/README.md#1g-phy-compositions)
for implemented paths. Earlier direct-link error objectives were planning numbers;
[acceptance](../acceptance.md#phy-and-hardware-acceptance) requires explicit
measurement limits at a named reference plane.

## Arithmetic alternatives

**Feedback raw-rate estimation was deferred October 13, 2026.** The study at
`52dfa266f` compared the quotient estimator with residual-update and phase/rate
observers. Feedback would change convergence, filtering and qualification, while
other clients still require the shared divider. Net LUT savings were unproven.
The production estimator and its reference model were unchanged.

The executable [rate-feedback study](../../../../tests/ethernet/PtpCore/rate_feedback_study.py)
retains reproducible equations and comparisons. Seventy synthetic comparisons
covered ±100 ppm, 8 Hz traffic, both endpoint clocks, seeded 100 ns delay jitter,
delay steps/ramps, oscillator change and packet gaps. Lower-noise candidates paid
in transient response; all models interpreted a persistent delay ramp as rate
bias. A fixed feedback shift can become unstable after a long observation gap.
These were numerical experiments, not RTL, closed-loop endpoint or hardware tests.
Revisit with rate-error/acquisition requirements, correlated path-delay models,
validity/expiry policy and measured integrated area; do not reuse the current
two-interval qualification count without analysis.

**Floating-point servo arithmetic is also deferred.** It could simplify controller
experiments, but neither precision nor resource benefit is established. Form epoch
differences in integer/fixed point before conversion; large absolute timestamps
can lose small differences. Evaluate binary64 before assuming binary32 is adequate,
and test small accumulated corrections, conversion/rounding, saturation and
non-finite results. Keep PHC accumulation/capture, E2E/rate arithmetic and final
commands fixed point unless a separate case justifies change. Preserve cancellation
and command-acknowledgement ownership in any prototype.
