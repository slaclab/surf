# PTP specification coverage

The maintainer selected **IEEE 1588-2019 with IEEE 1588-2008 compatibility**
on October 9, 2026. This page maps the implemented subset to verified clauses,
directed checks and remaining gaps. It is not a declaration of IEEE or profile
conformance. Execution results belong in the
[acceptance record](../../../docs/plans/ethernet-ptp/rtl-review.md#october-9-directed-specification-checks).

## Scope and source authority

The implemented scope is a configured-source Layer-2 E2E TimeReceiver, with
one-/two-step Sync reception and Delay_Req transmission. BMCA, management/signaling,
Pdelay, VLAN/UDP, security and one-step transmission are outside the current
[endpoint contract](../../../docs/plans/ethernet-ptp/autonomous-endpoint.md#port-policy-and-numerical-envelope).
A named deployment profile has not been selected. A fixed source alone does
not establish conformance to the external port configuration option in 17.6.

The authoritative 2019 text supplied by the maintainer was reviewed October 9,
2026. The original is preserved in the ptp-dev workspace at
[docs/reference/1588-2019.pdf](../../../../../../docs/reference/1588-2019.pdf), SHA-256
`85bcd0f039c2553337ccf1756c40921b027549d0327eb580d2931e227611274b`.
The licensed PDF is not bundled in SURF itself; extracted text remains temporary.
Clause/table numbers below refer to that edition, not carried-over 2008 numbers.
This audit does not yet include separate amendments or corrigenda.

Supporting references:

- [IEEE 1588-2019 publisher record](https://standards.ieee.org/ieee/61588/10624/1588/6825/)
  and [Xplore edition record](https://ieeexplore.ieee.org/document/9120376).
- [IEEE 1588-2008 interpretations](https://standards.ieee.org/wp-content/uploads/import/documents/interpretations/1588-2008_interp.pdf),
  especially responses 11 (Follow_Up twoStepFlag), 25/27 (correction semantics)
  and 26 (timestamp point). These supplement compatibility coverage; a complete
  clause-by-clause 2008 audit has not been performed.
- [NISTIR 8002](https://nvlpubs.nist.gov/nistpubs/ir/2014/NIST.IR.8002.pdf),
  Appendix C, independently documents the common 2008 header. Its C37.238/P2P
  profile requirements are not imported into this endpoint.

Keep the edition reference separate from deployment settings. Reception accepts
major version 2 with any minor version per 19.2. Transmit minor version 1 uses
the 2019 Layer-2 controlField value zero; selecting minor version 0 explicitly
uses the legacy 2008 Delay_Req control value one. The latter is a compatibility
mode, not a claim that 2019 permits nonzero Layer-2 controlField transmission.
Clause 19.1 makes compatibility depend on profile, enabled options and settings;
changing the version nibble alone is not sufficient evidence.

## Traceability matrix

All rows remain partial. “Covered” below means the named assertion exists;
current execution evidence and limits are recorded separately. Filenames are
relative to this directory.

| ID / subject | Verified 2019 reference and existing evidence | Remaining coverage or implementation gap |
| --- | --- | --- |
| PTP-S01: headers and Layer-2 transport | 13.2, 13.3/Table 35, 13.5–13.8, Annex F. Literal Sync/Follow_Up/Delay_Resp/Announce RX records and complete emitted Delay_Req bytes in `test_ptp_specification.py`; shared builder anchors in `test_ptp_wire_vectors.py`; existing FCS/framing tests. | Full message-body semantics and optional-field applicability. TX golden comparison ends before MAC padding/FCS; separate physical observer checks those. |
| PTP-S02: versions and domain | 19.2/19.3; 7.1.2.1; 13.3.2.10. All 16 minor values accepted with major 2; major 1/3 rejection in selected fixtures; ignored messageTypeSpecific and minorSdoId in non-isolated operation; both TX versions checked. Existing port fixtures check foreign source/domain rejection. | 7.1.4/Table 2 reserves domains 128–255 for the selected sdoId=000, but configuration currently permits them. No domain-range validation test/fix yet. No profile-isolation option 16.5. |
| PTP-S03: timestamp point | 7.3.4.1/7.3.4.2: first symbol after SFD at the reference plane, with capture-point and ingress/egress latency corrections. Existing `test_ptp_rx_rtl.py` and wire observers check GMII/XGMII phase, signed calibration and provenance. | Independently map every configured latency sign/plane to these equations. Connector calibration and reset-dependent PHY latency require hardware; MAC-side simulation is insufficient. |
| PTP-S04: one-/two-step Sync | 11.2; 13.3.2.8/Table 37; 13.6/13.7. `test_ptp_port_samples.py` checks exact mode equivalence; the specification fixture checks reordered Follow_Up, cleared Follow_Up twoStepFlag and reserved-bit tolerance. | Complete per-message applicability of assigned flags under the selected profile; collision/replay policies remain local contracts. |
| PTP-S05: corrections | 13.3.2.9/Table 38; 11.2/11.3.2. Signed fractional correction and widened sums have independent numerical expectations. The direct protocol fixture uses finite signed bounds. | The overflow indication is definitively `0x7fffffffffffffff`, not `-1`. RTL still treats it numerically. Select and test explicit receiver handling; the standard's encoding does not prescribe a universal discard action. Arithmetic boundary coverage does not establish semantic validity. |
| PTP-S06: E2E equations | 11.2/11.3.2. Existing E2E RTL vectors and rational/fixed-point oracle anchors cover symmetric-path delay/offset, split corrections and rate mismatch. | Map the complete independent end-to-end vector set to the clauses; add known path-asymmetry/calibration sign tests and fractional Delay_Resp contributions at the protocol boundary. |
| PTP-S07: response association | 9.5.7; 11.3.2; 13.8. Ledger/port fixtures check requesting identity, sequence, source, reordering, wrap and late completion. | Explicit one-field-at-a-time clause mapping, response acceptance and later recovery. Separate required association fields from local retirement/quarantine bounds. New header-admission tests do not prove successful response matching. |
| PTP-S08: Delay_Req and intervals | 11.3.2; 13.3.2.13/13.3.2.14/Table 42; 13.6. New independent emitted-byte check covers destination/source, length, identity, initial sequence, version-specific control, log interval 0x7f, zero correction/origin/reserved fields and stable backpressure. | **Known departure:** the three-point schedule fails the default multicast distribution in 9.5.11.2(c)(1). Mean/granularity, matched-response interval updates and foreign/stale-response immunity need directed scheduler acceptance. |
| PTP-S09: ignored fields and TLVs | 13.2; 13.3.2.8/.10/.13; 5.3.8; 14.1/14.1.2; 14.4.2. Directed checks cover reserved flag bits, ignored control values, even/odd TLV lengths, unknown TLV followed by PAD, truncation and recovery. | Assigned options and recognized optional TLVs need per-message/profile analysis. Skip semantics do not imply support for the option. Rejecting malformed TLVs is the endpoint's policy, distinct from the sender encoding rules. |
| PTP-S10: Announce/time properties and configured ports | 13.5/Table 37; 17.6. Existing physical-port checks cover metadata and acquisition restart on GM/timescale changes. | UTC-offset validity, leap/traceability/timescale behavior and receipt timeouts need explicit requirement mapping. External configuration requires its specified data sets, state behavior and initialization; current fixed-source operation has not demonstrated that contract. |
| PTP-S11: external interoperability | Clause 19's compatibility scope. Synthetic master and separate real-MAC fixtures exercise the selected exchange. | Pin a LinuxPTP/instrument configuration, both versions/modes and independent packet captures. No external-master or hardware result yet. |
| PTP-I01: implementation quality | Math/PHC/servo/register, queue, cancellation, holdover and snapshot tests. | PI gains, rounding, lock thresholds and finite buffers are implementation choices. Simulated phase bounds are not IEEE or hardware accuracy guarantees. |

## Construction and acceptance rules

For each normative assertion, record the edition, verified clause/table,
applicable role/options/profile, stimulus and independently calculated expected
observation. Keep sender formatting requirements distinct from receiver actions:
13.1 explicitly separates these. Use positive, negative and recovery cases where
the rule requires them; identify local malformed-input policy separately.

Hand-authored packets anchor shared builders. Compare actual production RTL
records and emitted bytes with independent constants; expected time must come
from independent master time and hand-worked arithmetic. The vectors are ours,
not IEEE-published conformance vectors. Retain known-bad evidence showing that
an assertion detects its target defect. Follow the
[protocol test guidance](../../protocols/README.md).

Use covered/pass, covered/fail, missing, and not applicable with rationale.
An omitted feature is not automatically inapplicable to a claimed profile.
The present matrix is not an exhaustive inventory of normative requirements,
so no conformance percentage is meaningful.

## Source-backed directed checks

`test_ptp_specification.py` provides seven separately selectable cocotb cases.
Existing benches supply transport/transaction mechanics; golden packets and
arithmetic remain independent of the shared encoder and model.
See the [execution record](../../../docs/plans/ethernet-ptp/rtl-review.md#october-9-directed-specification-checks).

| Scenario | References / observation | Limit |
| --- | --- | --- |
| `literal_rx_headers` | S01/S02: 13.3, 13.5–13.8, Annex F; four literal received types, independent decoded fields/body, signed correction/interval, upper seconds, padding outside messageLength, bad length/major/FCS and recovery. | Body preservation does not prove downstream semantics; drop counters are local policy. Legacy nonzero received control values are intentional. |
| `interpreted_two_step_correction` | S04/S05: 11.2, Table 37 and 2008 interpretations 11/25. Sync +10.5 ns and Follow_Up −2.25 ns, t1=1000 ns/t2=1040 ns, give exactly 31.75 ns forward difference in either arrival order; retains Sync capture. | Rejecting a Follow_Up with twoStepFlag set is local malformed-input policy. |
| `minor_versions` | S02/S09: 19.2, 7.1.2.1, 13.3.2.10. All minor nibbles, nonzero ignored minorSdoId and messageTypeSpecific. | The selected SDO is non-isolated; no isolation-option claim. |
| `tlv_suffix` | S09: 5.3.8, 14.1/14.1.2, 14.4.2. Unknown experimental TLV followed by empty/nonempty zero PAD; odd first/second length, partial header and truncated second value rejected with recovery. | Demonstrates structural skipping and local malformed-input policy, not every recognized TLV. |
| `receive_control` | S04/S09: 13.3.2.13. Values 0/1/2/3/5/ff ignored for Sync/Follow_Up/Delay_Resp/Announce. | Sync pair has exact measurement checks; Delay_Resp/Announce check header admission only. |
| `reserved_flags` | S04/S09: 13.2, Table 37. Bits masked by 0x9880 ignored individually and together in the four received types. | Assigned unsupported flags remain restricted by endpoint policy. |
| `delay_request_headers` | S01/S02/S08: 11.3.2, 13.3/13.6, Annex F. Complete 58-byte pre-MAC request in 2019 and selected 2008 modes, including stable data/sidebands under stalls. | Initial sequence only; scheduling distribution, physical timestamp and MAC padding/FCS are separate. |

The first four new rule scenarios failed on the previous RTL, exposing minor
version rejection, control-based rejection, reserved-bit rejection and acceptance
of odd TLV lengths. These are now corrected. The transmit check covers the
additional 2019 controlField correction.

## Remaining normative work

1. **Deployment/profile contract:** identify the intended profile, options,
   domain and external-port behavior. Under 17.6, manufacturer selection of the
   option is possible, but requires its data sets and state semantics.
   `externalPortConfigurationEnabled` has specification initialization FALSE;
   `desiredState` defaults to PASSIVE unless otherwise specified. Check permitted
   profile variations and observable behavior before claiming compliance.
2. **Scheduler:** 9.5.11.2 requires mean interval at least 0.9 times the advertised
   interval. Default multicast timing draws a new uniform value over zero to
   twice that interval, with granularity no greater than 2^(logSyncInterval−4)
   seconds. Current 0.5/1/1.5 timing is a known departure. A profile can specify
   another distribution; no such profile is currently selected. Fix/design and
   short deterministic distribution/interval-update regressions remain open.
3. **Correction overflow:** encoding is resolved; select receiver policy and
   test it across Sync, Follow_Up and Delay_Resp without publishing a finite
   estimate from an overflow indication.
4. **Domain configuration:** restrict or explicitly resolve domains 128–255
   under sdoId=000; add prepare/apply boundary checks for 127/128/255.
5. **Protocol semantics:** finish E2E/asymmetry, response interval updates,
   assigned flags/optional TLVs and time-property/timeout cases identified above.
6. **Qualification:** external-master compatibility, calibrated reference-plane
   timestamps, hardware timing/CDC and accuracy remain separate acceptance.

Run only the affected cases from the [selection guide](README.md#selecting-tests).
The complete suite is reserved for substantial integration or release validation.
