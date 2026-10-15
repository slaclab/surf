# PTP validation milestones

Recorded evidence through October 15, 2026. These results apply to the named
source/configuration, not automatically to later RTL. The [workstream](../README.md)
owns current status and [acceptance](../acceptance.md) owns remaining work.
Original commands, per-case tables, fixture corrections and source hashes are
recoverable using the [provenance index](decisions.md#source-provenance).

## Capture-boundary experiments

The early records were consolidated at `39604a8a`; not every run recorded an
exact RTL revision. That is document provenance, not a reproducible build pin.
The Phase 0 experiment used real `EthMacTop`, a 512-word RX FIFO and 156.25 MHz
XGMII with GHDL 6.0.0/cocotb 2.0.1. Captures and the rejected matcher were models,
not production PTP RTL.

| Observation | Design consequence |
| --- | --- |
| Wire `88 F7` went to bypass; `F7 88` went to primary. | Use MAC literal `x"F788"`; keep independent wire encoders. |
| CRC-bad A followed by valid same-key B produced a modeled join 1,040 ns early. CRC status asserted without FIFO-drop status. | Header keys and aggregate drop flush cannot establish frame identity. |
| Backpressure delivered only 130 of 240 frames; timestamp-only restart could associate a new capture with retained frame zero. | Independent queues and reset sessions need an atomic producer boundary. |
| Paused TX reached the wire after logical restart. | Retiring protocol work cannot release unresolved physical fate. |

All three MAC scenarios and the final 35 pure-model cases passed. The subsequent
RX replacement proof retained all 240 valid frontend records with their own
captures despite downstream MAC loss, rejected the bad-FCS duplicate and recovered
from independent frontend overflow. Its final evidence covers 60 reference cases
and seven cocotb scenarios, including GMII/XGMII, nonzero signed calibration,
minimum gaps, queue pressure, malformed framing and reset/generation boundaries.
These were boundary proofs, not hardware accuracy or physical CDC qualification.
The executable regressions remain indexed in the [test guide](../../../../tests/ethernet/PtpCore/README.md).

## Early endpoint and ownership milestones

The autonomous milestone recorded acquisition/holdover/recovery with XGMII
+100 ppm and GMII -100 ppm; independent simulated-master error was below 100 ns
at the stated lock checkpoints. Real-MAC lifecycle passed on both PHYs.
These accelerated cases do not establish long-duration default settling or
connector-plane accuracy.

The register-ownership refactor passed nine focused cases covering local banks,
atomic candidates, immutable commands and AXI-reset recovery. Its final endpoint,
real-MAC and physical-port runs were stopped before completion and were not
counted as passes. Initial record conversion and later registered-boundary
reviews had lint/compile evidence only during the verification pause. The
October 9 baseline below supplies subsequent behavioral evidence.

The optional snapshot mailbox passed simulation, but an early GHDL synthesis
attempt failed in the shared RAM's write-enable width handling. Device synthesis
and physical CDC remain separate gates; this historical result did not justify
an incidental shared-RAM change.

## October 9 baseline

Production RTL baseline `f8e6ba1729a4ebf1faa2bf88b295c43bc9ed0ba4`:
**121 distinct cases passed** (24 RTL configurations and 97 Python/static cases),
with no remaining failures/skips after correcting a GMII fixture timeout.
Production RTL did not change in that run. The fixture had allowed receipt expiry
to flush an association during its collision test; separating timeout and collision
scenarios preserved both checks. Tools were GHDL 6.0.0, Python 3.13.2,
pytest 9.0.2 and cocotb 2.1.0.

The selection included both PHYs and receive modes in endpoint/real-MAC fixtures.
Math and servo also passed the same bounded assertions with their pre-width-change
source from `4319702d0`; that comparison is not formal equivalence. Runtime examples
were about 25 s for direct protocol samples, 65 s for math/servo, and 39 minutes
for eight endpoint configurations with six workers. These timings explain focused
test selection; they are machine/batch observations, not service bounds.

## October 9 specification and exchange fixes

| Source context | Result and limit |
| --- | --- |
| Header/TLV working-tree fixes on `ddf7aa41d7180852a40c00202c8502735cdee75f` | 11 RTL configurations and 27 RX-model cases passed. Four new receive-rule cases failed on preceding RTL, detecting minor-version, control, reserved-flag and odd-TLV defects. TX checks covered both 2008/2019 control encodings. Full endpoint/MAC lifecycle was not rerun. |
| Exchange working-tree fixes on `6db41ad53ed5d17491fcfddfcff30325755d244f` | 10 configurations passed in 196.17 s with four workers. Prior RTL failed correction-overflow checks; the fixes retire affected keys and prevent a rejected response's interval from changing scheduling. Identity/provenance rejection and ordinary multicast traffic were exercised. |

The ordinary-master fixture advances independent timestamp/raw-tick inputs at
1 Hz and skips idle seconds. It is not continuous-time PHY/PHC/servo operation at
that rate. The [specification matrix](../../../../tests/ethernet/PtpCore/specification-coverage.md)
retains clause coverage and outstanding normative work. No external-master or
full-profile acceptance follows from these checks.

## Connected compute and subsequent focused checks

| Source/change | Recorded evidence | Limit |
| --- | --- | --- |
| Connected compute/storage, `52dfa266f`, from baseline `75a49f427` | 171 distinct configurations across batches: 74 RTL and 97 Python/static. Includes four endpoint and four real-MAC lifecycle configurations and eight raw/normalized E2E calibration cases. VSG covered 25 changed/new VHDL files. | Fixture corrections and scenario-filtered reruns are part of the result; this was not one uninterrupted suite run. |
| Counter, six BRAM selections and interval decoding, `0d27ddbba` | 20 focused final configurations passed, covering ledger storage/ages, concurrent rejection, interval decoding, register banks and protocol associations. | No full endpoint/PHY or routed qualification in that pass. |
| Protocol scan word ALU, follow-up to `0d27ddbba` | Nine configurations passed: full-width ages/distances, ties, overlapping scans, cancellation, publication priority and a GMII consumer. | XGMII and real-MAC endpoint lifecycle were not rerun. Source patch/hashes are in the original review. |
| Initial critical-path pass against `8c97ed404` | 18 selected final configurations passed. | Final endpoint/MAC lifecycle remained unrun; routed timing still failed as below. |
| Native arithmetic/admission R4, project `500cdd6` / SURF `8bb158b9a` plus patch | 15 initial focused configurations, four final protocol configurations and an extra TLV stress scenario passed. | Final endpoint/MAC lifecycle was not run. |
| Sparse RX/TX specialization, project `de738ca` / SURF `a37e036d1` plus patch | Seven final RX configurations, TX storage on the unchanged selected TX source, and final real-MAC RX passed. | Superseded 78-byte prototype's interrupted lifecycle run is not a pass; final endpoint lifecycle remains unrun. |

Connected/counter/scan runs used GHDL 6.0.0 and the recorded Python 3.13.2
runtime; later timing/storage passes used Python 3.12.7 with GHDL 6.0.0.
These are historical environment identities, not instructions to select an
interpreter today. Use the consuming workspace's preflight and focused test guide.

## Area and timing evidence

All LUT counts below retain their flow-stage/configuration limits. Parent-project
report directories remain the artifact owners; detailed early hierarchy tables
need not be duplicated here.

| Milestone | Observation | Attribution limit |
| --- | --- | --- |
| Ledger/table/private-arithmetic stages, October 11–12 | Whole-design synthesis progressed from 133,016 to 121,455 to 102,977 LUTs. | Reference/checkpoint selection and then Vivado 2025.2 versus 2025.1 changed; PHY black boxes remained. These are not isolated per-patch savings. Unchanged MAC/FIFO hierarchies also changed mapping. |
| Connected design `52dfa266f`, Vivado 2025.2 | Copper endpoint screenshot: 18,483 LUTs, 13,618 registers, 0.5 BRAM tile and four DSPs. | Earlier comparison used different tools/configuration; include the shared compute cost and avoid double-counting children. |
| Initial SFP-only routed baseline `8c97ed404` | Setup WNS -8.039 ns. Initial timing fixes reached -2.829 ns; native/admission R4 reached +0.182 ns. | Same selected KU040 flow; constraints, physical CDC and hardware still require review. |
| Selected 70-byte RX + TX specialization | Matched synthesis 51,411 -> 50,641 LUTs (-770, 1.50%). Routed: 50,668 LUTs, 58,873 registers, 33.5 BRAM tiles, nine DSPs; WNS +0.247 ns with zero setup/hold/pulse-width failures. | SFP-only. Synthesis deferred PHY binding; the routed checkpoint had no black boxes. This result predates the capacity/arbiter follow-up. |

In the consuming `ptp-dev` repository, artifact indexes are under
`docs/reference/ptpkcu105-utilization-2026-10-{11,12,13}/README.md` and
`docs/reference/ptpkcu105-implementation-2026-10-13/README.md`. The latter records
source overlays, checkpoint hashes, build directories and constraint/CDC/DRC limits.
Builds used Vivado 2025.2 on `rdsrv419`, `xcku040-ffva1156-2-e`, SFP-only and
`-flatten_hierarchy none` for the matched timing/storage follow-ups. Bitstreams
were not programmed. Do not compare these totals directly with dual-endpoint
or synthesis-only runs.

## Capacity and arbiter follow-up

`016771843`, based on `2933fe8c7`: **48 focused configurations passed** across
RX RTL/storage/reference, specification and compute tests, including both compute
RAM types. Capacity/TLV tests include negative controls that fail with the generic
left at its default. Endpoint lifecycle, real-MAC integration and the full suite
were not run for this pass.

Matched SFP-only KU040/Vivado 2025.2 synthesis with both PHY black boxes unbound
measured -803 LUTs for constant-owner arbiter eligibility and -1,176 for 128-byte
frame capacity. Disabling TLVs saved another 2,754 but was **not selected** because
it rejects TLV-bearing messages. A routed build of the combined source is
outstanding; the preceding +0.247 ns result is not its timing evidence.
Remaining PHC-owner loaded-word bookkeeping is a measurement-driven optimization
candidate, not an acceptance gate. See the [decision](decisions.md#treat-capacity-and-tlv-removal-as-deployment-restrictions).

## Recorded servo model envelope

Independent rational PI sweeps covered ±100 ppm, initial ±10 µs and Sync periods
1/8, 1/4 and 1 s. Peak error was below 12 µs and every sampled error after 120 s
was below 100 ns for those cases. Separate estimator sweeps included ±100 ns
packet-delay variation. These are model cases, not hardware accuracy guarantees
or a combined arbitrary-jitter stability proof. Accelerated physical endpoint
fixtures test state/command composition rather than long-duration default settling.

## October 15 servo lifecycle repair

Source: working-tree changes over `d4c78ad5b`, following the fixed-function
servo split. The unmodified 125 MHz regression failed command cancellation
and median retention. Diagnostics established a two-register cancellation path
where the PHC commit veto permits only one; fixed median test delays also fell
after the new filter had finished. A sweep at the actual publication boundary
exposed a stale filter update undoing the parent's invalidation. Continuing the
numerical test exposed omitted PI rejection accounting.

The parent now resolves cancellation into the children's state updates, keeping
public command/cancel and median/count registered. Measurement ownership lasts
until the active child returns idle; the filter preserves ready on its accepting
edge instead of consuming and then rejecting the same held sample. Association
expiry covers pending child work, and the aggregate counter includes PI
rejections. The [interface guide](../../../../ethernet/PtpCore/interfaces.md#registered-command-and-expiry-interface)
records the cancellation timing requirement.

The servo test derives cancellation windows from observed completion latency,
checks every in-flight median cycle, distinguishes cancellation after completion,
and checks that invalidation persists and accepted samples do not increment the
rejection counter. Numerical results still use the independent rational oracle.
The original cancellation-edge assertions remain in place.

Validation uses Python 3.12.7, cocotb 2.1.0 and GHDL 6.0.0 on `PC100431`.
Both edited RTL files pass VSG (689 rules, zero violations each). The PHC
`registered_command_lifecycle` scenario passes at 125 MHz. All three
`test_ptp_servo.py` configurations (125 MHz, 156.25 MHz and the wide nominal
divisor at 31.25 kHz) pass both cocotb scenarios: six scenario executions.
The selected `test_ptp_endpoint[two-step-GMII-False]` run was interrupted after
261 seconds, during its first Sync interval; it is **incomplete**, not a pass or
an RTL assertion failure. The preceding saved result for the same configuration
records 5,143 seconds (about 86 minutes) on this host. Full endpoint/MAC
integration remains open. No synthesis or routed timing validation ran.

Focused commands from the SURF root used
`/Users/bareese/ptp-dev/.planning/timing-venv/bin/python`:

```bash
python -m pytest -n 3 -q tests/ethernet/PtpCore/test_ptp_servo.py
COCOTB_TEST_FILTER=registered_command_lifecycle python -m pytest -n 0 -q 'tests/ethernet/PtpCore/test_ptp_phc.py::test_ptp_phc[125000000-1-False]'
```
