# Ethernet PTP workstream

The reusable fixed-source Layer-2 E2E TimeReceiver is implemented, with
one-/two-step Sync reception and autonomous numerical PHC/servo control.
Hardware accuracy and standards/profile acceptance remain open. Software
configures and observes the endpoint; it is outside the timing loop.

## Document map

| Question | Owning document |
| --- | --- |
| How does the implemented endpoint work, and why was it designed this way? | [Architecture and design decisions](../../../ethernet/PtpCore/architecture.md) |
| What are the exact ownership, clock-edge, RAM and scheduling contracts? | [Interface and service contracts](../../../ethernet/PtpCore/interfaces.md) |
| What does software configure and observe? | [Register map](../../../ethernet/PtpCore/register-map.md) |
| How do I compose the MAC/PHY and find sources or tests? | [PtpCore integration guide](../../../ethernet/PtpCore/README.md), [test guide](../../../tests/ethernet/PtpCore/README.md) |
| What is still unqualified or undecided? | [Acceptance and open decisions](acceptance.md), [specification coverage](../../../tests/ethernet/PtpCore/specification-coverage.md) |
| What would physical clock control require? | [Physical-clock requirements](../../../ethernet/PtpCore/physical-clock.md); prospective integration, not an implemented actuator |
| What would a replaceable-controller timing port look like? | [Timing-port contract](../../../ethernet/PtpCore/timing-port.md); records, stage audit and a simulation-verified `PtpMacPort`/`PtpMacPortEthMac` composition for GMII and XGMII; no register bank or hardware result. Owned by the consuming project's composable PTP plan |
| Why were alternatives rejected, and what evidence remains? | [Major design decisions and provenance](history/decisions.md), [validation milestones](history/verification.md), [deferred studies](history/design-studies.md) |

## Current validation

The baseline table was reconciled October 13, 2026, at SURF `68e5dbfaa`;
later rows identify their own source and test selection. Results do not
accumulate into qualification of the latest source automatically.

| Source/change | Recorded result | Boundary |
| --- | --- | --- |
| October 9 resumed baseline | 121 distinct cases passed after a fixture-timeout correction. [Evidence](history/verification.md#october-9-baseline) | Earlier source; later specification fixes have separate focused checks. |
| Connected compute/word-storage design, `52dfa266f` | 171 configurations passed across batches, including endpoint and real-MAC lifecycle in both PHYs/receive modes and raw/normalized E2E calibration. [Evidence](history/verification.md#connected-compute-and-subsequent-focused-checks) | Not one uninterrupted run; later optimizations were not part of this selection. |
| Counter/BRAM/interval pass, `0d27ddbba`, and subsequent scan ALU | 20 and 9 focused configurations passed respectively. [Evidence](history/verification.md#connected-compute-and-subsequent-focused-checks) | The milestone summary preserves scope; original patch provenance is recoverable through its Git source index. |
| Arithmetic/timing and RX/TX storage follow-ups | Selected SFP-only KCU105 source routes with WNS +0.247 ns and zero setup/hold/pulse-width failures; final RX leaf and real-MAC RX checks pass. [Evidence](history/verification.md#area-and-timing-evidence) | Final endpoint lifecycle, copper, constraint/CDC review and hardware acceptance remain open. |
| Compute arbiter, frame capacity and optional TLVs, `016771843` | 48 focused configurations pass. Matched synthesis reports -803 LUTs for arbiter indexing and -1,176 for 128-byte capacity. TLV rejection is implemented but not selected. [Evidence](history/verification.md#capacity-and-arbiter-follow-up) | Synthesis has PHY black boxes unbound. Final endpoint/MAC lifecycle and a routed build of the combined source remain outstanding. |
| October 15 servo lifecycle repair over `d4c78ad5b` | All three servo clock cases and the 125 MHz PHC command-lifecycle scenario pass; both edited RTL files pass VSG. [Evidence](history/verification.md#october-15-servo-lifecycle-repair) | Selected endpoint run was interrupted and remains incomplete; no new synthesis, routed timing or hardware qualification. |
| October 15 fixed-function repairs, through `44c85ff35` | 25 focused arithmetic/E2E/protocol/PHC/service configurations pass; 202 configurations collect, ten wrappers elaborate, six changed RTL files pass VSG. Matched SFP-only routing has +0.133 ns setup WNS and zero black boxes. [Evidence](history/arithmetic.md) | Area increases; endpoint/real-MAC integration, full service bound, constraint/CDC/DRC review and hardware acceptance remain open. |
| October 15 Delay_Req TX extraction and test-runtime follow-up over `a3f821fd9` | Three reservation/stall cases, four ordinary exchange edition/mode cases and the interval fixture pass. All six separated GMII/XGMII port scenarios pass (278.24 s including builds); the two strengthened rejection cases pass again in 56.54 s. Both edited RTL files pass VSG. | Earlier long port runs were interrupted, then replaced by completion-driven validation. No new closed-loop endpoint/real-MAC, synthesis, timing or hardware result. |
| October 15 protocol ownership split and direct-test runtime repair over `a3f821fd9` | 32 distinct simulation configurations pass across focused batches: all 18 table/negative-guard cases, both direct-sample RAM modes, four ordinary exchange cases, three rejection cases, three TX cases and two protocol-specification cases. Five refined/new RTL files pass VSG; source import resolves. The matched 14-case batch fell from 458.24 s to 167.65 s; summed case execution time fell 52%. [Method and scope](../../../tests/ethernet/PtpCore/README.md#selecting-tests) | Both RAM modes retain all sixteen history-cancellation phases. Public engine ports and table word packing are unchanged. No new continuous-clock endpoint/real-MAC, synthesis, routed timing or hardware result. |
| October 15 Sync transaction records over `513abd870` | Eleven focused configurations pass: history selection/cancellation/publication priority, pair cancellation/expiry and negative-result guard in both RAM modes, plus normalized E2E with both calibration planes. All six changed VHDL files pass VSG; source import resolves. | Pair/history/E2E state transitions and datapaths also compare unchanged after field substitution; completion fields are registered on their existing edge. One case needed a rebuild after a concurrent formatting edit invalidated GHDL analysis. No full-suite, synthesis, timing or hardware result. |

| October 15 PtpCore-wide port records over `649bea094` | 59 distinct configurations pass with Python 3.12.7/GHDL 6.0.0: 14 math/service/servo/PHC/E2E/register cases; four ledger cases; 41 arithmetic-leaf, exchange/rejection, interval, TX, pair/history/negative-guard, direct-sample, RX and GMII/XGMII port cases. All 48 changed/new VHDL files pass VSG. [Record interfaces](../../../ethernet/PtpCore/interfaces.md#record-interfaces-and-source-compatibility) | VHDL source API changes; register/wire formats and operand widths retained. Initial integration failures exposed a duplicated RX-wrapper declaration and a missing scalar monitor alias; both are fixed and affected cases pass. Final formatting preserves tested VHDL tokens. No full-suite, closed-loop endpoint/real-MAC, synthesis, routed timing or hardware result. |

The October 18 timing-port Phase 1 closure over `babf2234e` is recorded in
[timing-port verification](../../../ethernet/PtpCore/timing-port.md#october-18-closure-verification).
Paired default MAC/SSI suites, ten differential configurations, selected
timing/legacy integration, retained packing and full generation exhaustion
pass. The closure patch fixes timing-port RX wire-error rejection and keeps
test wrappers outside the Ruckus import. Matched default-MAC synthesis has
unchanged storage and no black boxes; timing-port area/routing, the management
register bank and hardware acceptance remain open. These closure edits are
working-tree changes, not a new source pin.

The [October 15 test-suite follow-up](history/verification.md#october-15-test-suite-follow-up)
over `ed7d30cbe` passes **91 distinct selected cases**, including all eight
endpoint/real-MAC mode/PHY configurations; one strict expected failure exposes
the retained scheduler distribution departure. Selective CI and register schema
gaps are fixed; domain boundaries, disturbance/freshness and signed asymmetry
have directed checks. Shorter integration fixtures reduce simulated cycle cost
about 95–97% relative to the former fixed waits alone. This closes the functional
integration gap in the historical rows above, not service-envelope, normative,
timing/CDC or hardware qualification.

The October 18–19 shared PHC subsystem (composable-PTP Phase 2) over
`91a6bc5d6` adds `PtpPhcCore`/`PtpPhcControl` and owner-gated `PtpPhc`
admission, and rebuilds `PtpEndpoint` around the core in a 32 KiB map; see the
[PHC subsystem contract](../../../ethernet/PtpCore/phc.md). With Python
3.12.7/GHDL 6.0.0: the three standalone `test_ptp_phc_core.py` cases, both
`test_ptp_phc_mac_port.py` PHYs, both `test_ptp_phc.py` and `test_ptp_reg.py`
cases, the 13 static map checks, GMII two-step/XGMII one-step closed-loop
endpoints, the three GMII port scenarios and the GMII two-step real-MAC
endpoint pass. Four standalone and one composed RTL mutation each fail. It
also fixes a pre-existing manual-PHASE result handshake that hung every manual
PHASE after the first until system reset. Other endpoint/port/real-MAC
configurations, synthesis/resources, routed timing and hardware remain unrun.

Slice 2e (October 19, working tree over `0704a92b4`) adds build-time PHC
control modes (`CONTROL_MODE_G`) and restores endpoint `ServoEnable` as servo
run/stop. The four standalone mode cases, three register cases (including a
fixed `"EXTERNAL"` endpoint), static map, both PHC leaf cases, GMII composed
timing port, two closed-loop endpoint configurations, one GMII port scenario
and the GMII two-step real-MAC endpoint pass (27 nodes). Synthesis and the
matched resource comparison are not run.

Behavioral verification has been authorized since October 9, 2026. Use the
[focused test-selection policy](../../../tests/ethernet/PtpCore/README.md#selecting-tests);
the acceptance backlog does not require a full-suite replay after routine edits.

## PHY composition implementation

UltraScale GTH, UltraScale+ GTY and gigabit-only UltraScale LVDS/Marvell copper
compositions share `GigEthPtp` and the autonomous endpoint. The
[integration guide](../../../ethernet/PtpCore/README.md#1g-phy-compositions) owns
reference selection, address apertures, hierarchy and reset differences.
The dual-mode GTH checkpoint is present and has bound in the recorded KCU105
SFP-only routed build; the former missing-checkpoint task is resolved for that
build. This does not qualify all reference modes, PHY families or boards.

Copper PCS reset clears its PHC/configuration; the externally clocked GTH/GTY
compositions retain PHC time during PCS reset. Stopped-clock recovery requires
invalidation and reacquisition. RFMC board integration remains a consuming-project
scaffold. Pin/clock assumptions, oscillator programming and measurement outputs
belong in project target guides.

## Open decisions and next work

The [October 15 test-suite review](acceptance.md#october-15-test-suite-review)
records the 211-case inventory, standards/coverage assessment and confirmed
selective-CI and register-schema gaps at the reviewed source. The
[follow-up](acceptance.md#review-follow-up) fixes those two gaps and adds domain,
scheduler and disturbance acceptance. An existing profile is the working
direction; selection and configured-source applicability remain open. The
three-point scheduler is planned for retention in controlled deployments, with
its departure documented and a strict expected-failure check. Qualification,
rather than mandatory scheduler replacement, is the outstanding work.

The [acceptance backlog](acceptance.md#next-acceptance-work) owns remaining
integration, normative, timing/CDC, external-master and hardware checks.
The fixed-function arithmetic migration and focused repairs are implemented through
`44c85ff35`; the [decision record](history/decisions.md#fixed-function-arithmetic-architecture)
and [source-specific measurements](history/arithmetic.md) capture the choice and
its area cost. Local state and specialized services replace compute workspaces.
Simulation wrappers load explicitly in test fixtures, outside the production manifest.

The protocol-engine decomposition now gives `PtpProtocolReg` configuration and
snapshot ownership, `PtpPortPolicy` admission/deadline/lifecycle ownership, and
`PtpSyncFlow` admission arbitration and measurement sequencing. The first flow
extraction remained too broad: its pairing, history and shared scan state now
live in `PtpSyncPair`, `PtpSyncHistory` and `PtpTableScan`. Their boundaries are
held transactions, not exported private FSM state. History also owns append
sequencing, leaving one coordination FSM in the flow. A subsequent interface
pass uses cohesive `PtpSyncPkg` records for pair completion, lookup command/result,
append command/status and normalized words through E2E. Result records have one
state owner; borrowed payloads retain their existing storage and lifetimes.
Lookup's separately retained Delay sample remains distinct from its start command.

The wider PtpCore interface pass extends records to RX/TX message heads, completed
ledger samples, policy admission and events, configuration scans, PHC read results,
filter/PI inputs and arithmetic requests/results. Shared services now use arrays
of client records. `PtpProtocolPkg`, `PtpServoPkg` and `PtpMathPkg` keep those
contracts with their owners; existing common, Sync and register packages retain
their related interfaces. Generic math records constrain each operand/result to
the existing width. Published records live in the owning state, with explicit
views for existing FIFO/DSP storage and narrower arithmetic operands. Clocks,
reset/cancel, reverse handshakes and physical pins remain separate. All callers
are migrated; cocotb wrappers preserve their flat signal interfaces. This changes
the VHDL source API, with no intended datapath, storage-layout or cycle change.
See [record contracts and migration](../../../ethernet/PtpCore/interfaces.md#record-interfaces-and-source-compatibility).

`PtpDelayReqTx` retains scheduling, reservation requests and stalled-frame drain;
`PtpTxLedger` retains its existing physical ownership contract. The parent is
structural. Diagnostic serialization stays with held RX/E2E payloads in the flow;
registered word writes/commits reach the register owner. The
[ownership rationale](../../../ethernet/PtpCore/architecture.md#composition-and-ownership)
and [edge contracts](../../../ethernet/PtpCore/interfaces.md#output-ownership-and-exceptions)
record why these boundaries avoid payload copies and additional pipeline stages.
This is a structural change; no new area or timing measurement is available.

Validation of the split exposed two stale register-fixture assumptions from the
arithmetic migration. `PtpRegWrapper` connected PHC and servo to the same SECOND
client slot, causing multiple request/cancel drivers and a manual-command timeout;
it now matches the production endpoint's two independent clients. The final
phase-overflow oracle also used the former signed64-seconds preparation bound.
It now checks signed96 Q16 admission from all four submitted words, including
both adjacent out-of-range values and late epoch faults at the signed96 extrema.
Both register bases passed after these fixture fixes (161.54 s); four schema
checks passed. The production PHC arithmetic and register ABI are unchanged.

The [test-runtime follow-up](../../../tests/ethernet/PtpCore/README.md#selecting-tests)
replaces physical-port fixed service delays with bounded retirement/publication
checks. Direct protocol negative checks now wait for actual ledger/table/rate/E2E
retirement instead of fixed 512/16,000-cycle windows. The matched fourteen-case
table batch fell from 458.24 s to 167.65 s with three workers (63% less wall time).
Summed cocotb execution time excluding builds fell 52%. A dedicated regression
checks that these faster guards still catch late valid work; all sixteen history
cancellation phases remain. TX restart is independently selectable on each PHY.
The continuous-clock endpoint/MAC schedule and production acceptance limits are
unchanged.

Complete endpoint/real-MAC validation, review the matched routed findings and
finish the full service proof. Keep **70,347,776 ticks** until that proof and
contention/expiry tests justify a separate change. The 200,000-ppb actuator cap
still needs physical/control rationale and deployment qualification. The
[remaining review items](acceptance.md#review-response-and-simplification-plan)
include RX overload policy, composition/reset guarantees and localized maintenance.

The [saved-checkpoint area follow-up](history/arithmetic.md#area-follow-up-on-the-saved-production-checkpoint)
identifies PI clamp/limit logic, median data movement and qualified rate-filter
widths as the next bounded optimization candidates. No candidate savings have
been measured; preserve numerical and cancellation behavior and compare one
change at a time. Further area work remains measurement-driven. Historical compute-owner
bookkeeping observations in the [area record](history/verification.md#capacity-and-arbiter-follow-up)
refer to the retired engine.
Halving LUT usage was motivation, not an acceptance threshold. Shared MAC/checksum
changes, feedback estimation, floating-point servo arithmetic, additional protocol
modes and application/physical timing are deferred rather than prerequisites.

## Maintaining this workstream

Keep only status and unfinished acceptance here. Update the owning architecture,
interface or register guide when a task changes enduring behavior or rationale;
do not create another permanent sub-task plan. Preserve unique dated experiments,
source revisions, rejected alternatives and consequential test outcomes in the
concise history records. Keep detailed transcripts in Git history and
generated logs outside maintained documentation; do not retain a separate review
file for each date or implementation increment.
See the parent [planning guide](../README.md).
