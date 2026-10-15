# Arithmetic architecture evidence, October 13–15, 2026

This record retains the measurements that informed the [fixed-function arithmetic
choice](decisions.md#fixed-function-arithmetic-architecture). Current behavior
belongs in [PtpCore](../../../../ethernet/PtpCore/architecture.md#compute-boundary-review);
unfinished work belongs in [acceptance](../acceptance.md#arithmetic-prototype-sequence).
Experiment harnesses, CSV/JSON exports, manifests and raw reports are retired from
maintained sources. They are recoverable through the source and cache locations below.

## October 13 operator comparison

A 41-case KU040 study compared native fabric, DSP and handwritten operators.
Native carry chains remained the choice for critical adds/subtracts: the 64-bit
native add took 1.486 ns, versus 3.397 ns for the two-DSP form and 3.510 ns for
handwritten carry-select. DSP mapping saved LUTs at some sites but did not justify
a blanket DSP directive. Isolated delays do not establish endpoint timing.

## October 14 primitive and connected experiments

The campaign passed 57 focused behavioral configurations and retained 52 routed
primitive cases. The first ten product-mapping runs did not apply the intended
attributes and were excluded; corrected product-v2 runs informed the decision.

| Comparison at 156.25 MHz | LUTs | DSPs | Setup WNS (ns) | Decision |
| --- | ---: | ---: | ---: | --- |
| SECOND128 serial | 657 | 0 | +2.382 | Selected; 104-clock primitive latency. |
| SECOND128 reciprocal | 1,039 | 32 | +1.187 | Six-clock latency did not justify the cost. |
| E2E 68×64 explicit tree | 506 | 16 | +1.685 | Selected internal pipeline; four-clock primitive latency. |
| E2E product with three output registers | 249 | 16 | −0.331 | Output registers did not break the internal critical path. |

Complete connected comparisons included arbitration, operand selection and held
responses. Sharing SECOND saved 573 LUTs in the revised 156.25 MHz comparison;
sharing the measurement divider saved 1,588 LUTs. Epoch conversion used three DSPs.
The revised servo slice still cost **6,258 LUTs versus 3,692** for its matched
legacy slice, with WNS +0.817 ns versus +1.022 ns. These slice savings did not
predict a whole-endpoint area reduction.

An initial PI rounding/clamp/anti-windup path took 14.09 ns; registering those
equations repaired the measured path. Four final 125 MHz servo-v2/second-v2 runs
were pending at collection and remain uncollected evidence. The connected chain
checks exercised real PHC ticks, cancellation, generation and conditional service
ceilings at both clocks, but excluded packet/history/median admission. They do
not prove the production endpoint bound. Keep the **70,347,776-tick association
floor**; this is a minimum configured age limit, not a mandatory startup wait.

## October 15 matched production comparison

Both runs used Vivado 2025.2 on `rdsrv419`, `xcku040-ffva1156-2-e`, SFP-only
KCU105, `flatten_hierarchy=none`, identical constraints, ingress calibration
+7.25 ns and egress −3.5 ns. The baseline was SURF
`4d3439185f2fcadbeb68a7c747e92218705314a0`. The repaired run used an overlay on
`63f6cfade`; its changed VHDL hashes matched the subsequently committed
`44c85ff35e2195eeafa51287b41a20dfd55d7d51`.

`PtpEndpoint` excludes the external MAC/PHY and physical timestamp taps:

| Resource | Legacy endpoint | Fixed-function endpoint | Change |
| --- | ---: | ---: | ---: |
| LUTs | 15,586 | 23,804 | +8,218 (+52.7%) |
| Flip-flops | 13,436 | 23,297 | +9,861 (+73.4%) |
| DSPs | 4 | 28 | +24 |
| RAMB18 | 7 | 6 | −1 |
| RAMB36 | 0 | 0 | 0 |

Servo contributed 5,328 LUTs of growth (2,673 → 8,001), or 64.8% of the net
endpoint increase. Protocol grew 8,597 → 11,081; PHC grew 2,114 → 2,155.
The 1,541-LUT compute engine disappeared; SECOND and variable-divider services
cost 605 and 1,309 LUTs. The new PI child alone uses 5,339 LUTs. Hierarchy rows
include their children and must not all be added together. The enclosing
`EthMacPtpEndpoint` grew 24,276 → 33,088 LUTs.

Both routed comparisons exited zero with zero black boxes or failing setup,
hold and pulse endpoints. Whole-design setup WNS was +0.584/+0.133 ns before/after;
hold slack was +0.029/+0.030 ns and pulse slack +0.243/+0.243 ns. Both had zero
missing clocks or unconstrained internal endpoints, but five inputs without input
delay and nine outputs without output delay. Both logs had seven `Project 1-863`
critical warnings about unused OOC checkpoints and no errors. DRC warnings grew
27 → 64; the repaired report included 3 DPIP-2, 24 DPOP-3 and 33 DPOP-4 findings
plus CFGBVS-1, REQP-1753, REQP-1853 and RTSTAT-10. CDC reports contained 26/24 unsafe
and 12/12 unknown findings. Constraint/CDC/DRC scope review remains open; copper
and physical hardware were not qualified by these builds.

## Production verification and limits

The repair follow-up passed 25 distinct focused configurations: ten arithmetic
leaf, eleven E2E/tree/protocol and four PHC/service cases. Earlier servo checks
passed all three clock configurations; four register-schema checks passed.
All 202 PTP pytest configurations collected, all 32 wrapper fixture calls named
their sources explicitly, and all ten wrappers elaborated. The six changed VHDL
files passed VSG with zero violations. These were separate selections, not a full
suite pass on one source. Existing compliance findings elsewhere remain open.

Two endpoint runs on `63f6cfade` failed to observe TX frames. Repaired GMII two-step
and XGMII one-step reruns were incomplete at this evidence capture. Endpoint and
real-MAC lifecycle, the complete service bound, constraint/CDC review, external
master and hardware acceptance remain open. Successful routing is not simulation
or hardware acceptance.

## Sources and recovery

The consuming **ptp-dev** project commit `d135a02` retains the retired
`firmware/benchmarks/ptp-arithmetic/`, `firmware/benchmarks/ptp-constant-divide/`,
long architecture specification and original reports/CSV/JSON under
`docs/reference/ptp-arithmetic-architecture-2026-10-14/`. The October 13 table was
`docs/reference/ptp-arithmetic-2026-10-13.csv` at that commit. Recover these from
ptp-dev Git history, not SURF Git history. Original manifests identify earlier
or dirty experiment snapshots; the final recovery tree alone does not establish
every run's source.

Full production reports, source hashes and validation logs remain in the consuming
project's ignored `.planning/remote-builds/20261015-production-arithmetic/` cache
and on `rdsrv419:/u1/bareese/agent-builds/ptp-dev/20261015-production-arithmetic/`.
The local `retired-reference-backup/` preserves the material removed during cleanup.
These locations aid inspection while available; this concise record is the
maintained evidence. Production regressions remain in SURF
`tests/ethernet/PtpCore/`, including the arithmetic and lifecycle cases that caught
the implementation failures.
