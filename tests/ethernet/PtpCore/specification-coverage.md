# PTP specification coverage

The verification baseline selected by the maintainer on October 9, 2026 is
**IEEE 1588-2019, with explicit IEEE 1588-2008 compatibility coverage**.
This page maps the selected endpoint contract to tests and identifies the next
standards review. It is not a declaration of IEEE or profile conformance.
Execution results belong in the [acceptance record](../../../docs/plans/ethernet-ptp/rtl-review.md).

## Scope and source authority

The implemented scope is a configured-source Layer-2 E2E TimeReceiver, with
one-/two-step Sync reception and Delay_Req transmission. Its lack of BMCA,
management/signaling, Pdelay, VLAN/UDP, security and one-step transmission is
explicit in the [endpoint contract](../../../docs/plans/ethernet-ptp/autonomous-endpoint.md#port-policy-and-numerical-envelope).
Do not call this a conformant default-profile ordinary clock merely because
the selected exchanges work. In particular, the applicability and requirements
of 2019 manual port configuration must be checked before using it to justify
the configured-source behavior. A named deployment profile has not been selected.

Primary references checked October 9, 2026:

- [IEEE 1588-2019 publisher record](https://standards.ieee.org/ieee/1588/6825/):
  selected normative edition. The complete normative text was not available
  in the checkout or successfully retrieved during this review. Exact 2019
  clause references, amendments/corrigenda and requirement wording remain to
  be verified against an authoritative copy. Do not silently carry 2008 clause
  numbers into the 2019 column.
- [IEEE's 2008 interpretations](https://standards.ieee.org/wp-content/uploads/import/documents/interpretations/1588-2008_interp.pdf):
  accessible primary clarification. Responses 26 and 25/27 address timestamp
  location and correction-field special-value semantics respectively. These
  clarify 2008; they do not replace a 2019 review. Response 25 identifies the
  signed maximum sentinel, whereas response 27 uses ambiguous all-ones prose;
  resolve the encoding against the selected normative edition before writing
  an assertion. Receiver handling is described there as implementation/profile
  specific.
- [NISTIR 8002 / NIST and UNH-IOL Power Profile test plan](https://nvlpubs.nist.gov/nistpubs/ir/2014/NIST.IR.8002.pdf):
  a useful example of applicability, references, setup, stimulus and observable
  results for each case. Its C37.238/P2P requirements are not this endpoint's
  requirements. Appendix C independently documents the common 2008 header layout.

## Traceability matrix

"Existing" means an assertion/fixture exists, not that every applicable IEEE
requirement is covered or that the current regression passed. The 2019 clause
audit is open for every row. Test filenames below are relative to this directory.

| ID / subject | Existing evidence | Standards gap or next directed case |
| --- | --- | --- |
| PTP-S01: common header and transport | `test_ptp_rx_rtl.py`, `test_ptp_rx_reference.py`, physical port tests check parsing, lengths, FCS and byte order. `test_ptp_wire_vectors.py` independently anchors the shared Sync builder with four literal Ethernet frames before FCS insertion. | Extend golden packets to other received messages and emitted Delay_Req, and drive them through production RTL. Check all header fields, padding versus messageLength, and message-specific reserved-field rules. Do not generate the expected bytes with the stimulus encoder. |
| PTP-S02: version and domain | RX fixtures exercise minor versions 0/1; port fixtures reject foreign domains/identities. | Exercise both receive versions and configured transmit versions through the complete endpoint. Audit 2019 SDO/minor-version/reserved-octet rules and their 2008 interpretation; changing only the minor nibble does not prove compatibility. |
| PTP-S03: timestamp point | `test_ptp_rx_rtl.py` and wire observers independently check GMII and XGMII lane phase, signed latency and frame provenance. | Anchor to 2008 interpretation response 26, clauses 7.3.4.1/7.3.4.2; verify the corresponding 2019 rule. Simulation covers the MAC-side plane; connector calibration and reset-dependent PHY latency require hardware. |
| PTP-S04: one-/two-step Sync | `test_ptp_port_samples.py::exact_mode_equivalence`, physical port and both endpoint modes. | Map originTimestamp, preciseOriginTimestamp and correction usage to 2019 requirements. Preserve positive cases for each legal flag combination under the selected profile, not only current exact flags `0x0000`/`0x0200`. |
| PTP-S05: correction arithmetic | Signed/fractional/widened correction vectors in port and E2E fixtures; independent rational calculations. | Separate ordinary signed bounds from the reserved overflow indication. Resolve sentinel encoding and receiver policy explicitly; audit transparent-clock contributions, overflow and special-value propagation. Current full signed64 arithmetic tests do not establish semantic validity of every wire value. |
| PTP-S06: E2E exchange | `test_ptp_e2e.py`, `test_ptp_reference.py`, independent-master endpoint phase/path checks. `test_ptp_wire_vectors.py` anchors the rational and fixed-point solvers to hand-worked 100 ns delay / +40 ns offset examples, including fractional corrections and rate mismatch. | Trace equations/sign conventions to the 2019 standard and drive fixed vectors through RTL, retaining split one-/two-step correction cases. Test known path asymmetry as an expected bias/calibration case, not as an unexplained lock error. |
| PTP-S07: response matching | Ledger and port tests cover source/requesting identity, sequence, reordering, wrap, late completion and reset. | Map required matching fields separately from local key retirement, replay bounds and duplicate/collision policy. Mutate one required field at a time and verify no sample plus later recovery. |
| PTP-S08: Delay_Req transmission and intervals | Wire observer checks request/FCS; port tests exercise held TX and restart; implementation documents its three-point schedule. | Review all emitted bytes and logMessageInterval handling against E2E rules. Determine whether the three-point 0.5/1/1.5 schedule meets the selected edition/profile's interval-distribution requirement; bounded jitter alone is not proof. Test matched-response interval updates and ignored foreign/stale responses. |
| PTP-S09: flags, reserved fields and TLVs | Structural TLV length/error coverage, exact flag/control rejection and recovery. | Build per-message legal/ignored/rejected field tables from the spec. Check odd lengths, unknown TLVs, permitted optional TLVs, reserved bits and message-specific flag significance. Do not classify a legal unsupported message as malformed. |
| PTP-S10: Announce and time properties | Physical port test checks metadata and restart on source grandmaster/timescale changes. | Audit UTC offset validity, leap flags, traceability, timescale and timeout semantics. No BMCA or management conformance is established by metadata capture. Select and document the configured-source operating profile. |
| PTP-S11: external interoperability | Synthetic independent master and separate real-MAC lifecycle fixtures. | Pin a LinuxPTP or instrument release/configuration, exercise both receive modes, retain packet captures and check exchanges with an independent decoder. An interoperability pass supplements, rather than replaces, normative cases. |
| PTP-I01: implementation safety and quality | Math/PHC/servo/register tests, cancellation, queues, backpressure, holdover and snapshots. | Keep PI gains, rounding, lock thresholds, finite buffers and lifecycle timing labeled as implementation contracts. The accelerated simulation's phase bounds are not an IEEE accuracy guarantee or a hardware requirement. |

## Construction and acceptance rules

For each new normative case, record the edition, verified clause/table, applicable
role/profile/options, a short paraphrase, stimulus and independently calculated
expected observation. Link its ID above in the Python methodology. A requirement
needs positive, negative and recovery observations where applicable. Use distinct
statuses for covered/pass, covered/fail, missing, not applicable with rationale,
and interpretation pending; never treat an absent feature as automatically not
applicable to a claimed profile.

Anchor shared packet helpers with fixed known-answer packets before expanding
randomized tests. Drive the production RX/protocol/MAC boundaries using those
bytes, and compare complete outgoing packets with an independent decoder. Keep
expected time based on independent master simulation time and hand-worked
arithmetic; never derive the expected answer from DUT PHC/offset registers.
Use selected field mutations and deliberate known-bad comparisons to show the
assertions detect the relevant defect. Follow the [protocol test guidance](../../protocols/README.md).

The first seven oracle anchors are implemented in `test_ptp_wire_vectors.py`.
The common-header layout is cross-checked with NISTIR 8002 Appendix C. The
literal v2.1 nibble is an implementation-compatibility anchor pending the full
2019 audit. These are hand-authored examples, not IEEE-published test vectors.
Their passing result checks helper/model consistency with independent fixed
answers; it does not close the corresponding normative or RTL coverage rows.

Next: obtain the authoritative 2019 text and any selected corrigenda, settle the
profile/applicability declaration, then audit S04/S05/S08/S09 first. Their current
restrictions or arithmetic coverage could otherwise make mutually consistent
RTL and Python tests pass while missing a standards issue. Extend the independent
wire vectors and map existing assertions before claiming conformance percentages.
