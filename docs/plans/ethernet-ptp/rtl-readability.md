# PTP RTL flow and interface review

Status: VHDL changes prepared for maintainer review. **Do not run regressions
until the maintainer approves the VHDL.** Only lint and compile/link smoke checks
are authorized in the meantime. Earlier simulation results precede this cleanup.

## Control flow

The review covers every VHDL file under `ethernet/PtpCore`, including the thin
simulation wrappers. Simple wiring and record flattening remain wiring; protocol
eligibility, cancellation, state-dependent handshakes and reset decisions belong
in the appropriate combinational process.

| Module | Organization |
| --- | --- |
| `PtpPort` | Local active configuration; receive identity/provenance checks; Announce and lifecycle cancellation; TX draining and request scheduling; association expiry and message dispatch; rate/E2E completion; cancellation priority; local status/snapshot/register service; output publication. Next-state fields carry decisions forward without reading back generated signal flags. |
| `PtpServo` | Configuration and work lifetime; sample acceptance/filtering; named arithmetic operations; PHC acceptance/acknowledgement; lock hysteresis; cancellation/disable/fault priority; local registers and outputs. Anti-windup checks frequency and total-rate saturation separately before deciding whether to integrate. |
| `PtpPhc` | Command-owner selection; ordinary time advancement; pending-command commit and overflow/validity handling; local AXI/manual preparation and snapshots; reset and outputs. Manual preparation remains distinct from the numerical target. |
| `PtpReg` | Decode requests against pre-edge ownership; prepare/validate/apply state progression; snapshot qualification/completion; IRQ event priority; reset and publication. Coordination strobes are generated in that flow. |
| `PtpTxLedger` | Separate ordered sweeps for lifetime accounting, wire completion, response matching and publication, then allocation and reset/retirement policy. Ascending-slot publication priority and pre-edge allocation availability remain explicit. |
| `PtpE2e`, `PtpMath` | Accept immutable operands, issue/consume arithmetic stages and hold results. E2E arithmetic operations have names instead of numeric stage IDs; cancellation remains the final override. |
| `PtpPhcRead` | Request admission/write/response completion in the read-domain process; request capture/response write in the PHC-domain process. FIFO acknowledgements and each domain's reset qualification are handled locally. |
| `PtpRxFrontend`, `PtpRxTimestampAdapter` | Physical decoding, frame validation, publication and final invalidation remain ordered. EOF validation now shows framing/FCS, protocol and length checks separately. |
| `PtpPrimaryGuard` | Output drain, initial-beat classification, frame continuation, then reset/output publication. |
| `PtpEndpoint`, `EthMacPtpEndpoint` | Composition remains thin. Endpoint lifecycle/IRQ decisions use `comb`; MAC reset confirmation uses `RegType`/`comb`/`seq`. |
| `PtpTxTimestampTap`, package and wrappers | Passive composition and flattening are retained. Package records carry shared semantics; the register fixture groups its override/reset/observation wiring in `comb`. Port maps and indentation follow SURF style. |

`PtpPort`, `PtpPhc` and `PtpServo` always use their local AXI banks. The
optional AXI switches and bypass configuration inputs are removed. The PHC
retains its servo command interface and the servo consumes the port-owned
shared limits. Standalone PHC and servo fixtures expose AXI through the standard
SURF adapter; Python programs their shadows and drives prepare/apply strobes.

## Package records

- `PtpMeasurementType` remains the arithmetic payload, usable by `PtpE2e`
  without transport semantics.
- `PtpMeasurementMasterType` carries `data`, `valid` and `abort` from port to
  servo. `PtpMeasurementSlaveType` carries `ready` in the reverse direction.
  Transfer requires valid and ready with abort low. Abort also invalidates
  previous work and is meaningful when valid is low. These are common-clock
  interfaces, not CDC primitives.
- `PtpPortStatusType` groups live activity/ratio/Announce qualification, lifecycle
  indications, exchange/Announce data, ledger state and diagnostic counters.
  `PtpPort` constructs it from pre-edge state and snapshots locally. The central
  coordinator still receives only narrow summary bits, not the diagnostic bank.
- The [interface record review](interface-records.md) adds directional PHC
  command records, servo diagnostics, configuration-commit and snapshot-control
  records, and named RX counters. The timestamp adapter reuses `PtpPhcStatusType`.
- All new records have package initialization constants. Named servo-quality
  constants retain the existing three-bit register ABI.

Measurements and diagnostics are separate because their validity rules differ.
The response direction is separate because ready is driven by the consumer.
Clock/reset and AXI interfaces retain the existing SURF types. No universal PTP
control record is introduced: configuration coordination, PHC command completion
and RX/TX physical provenance have different owners and lifetimes.

The software register map is unchanged. The PHC and servo fixtures add
flattened AXI and prepare/apply ports; the PHC removes its monotonic input.
The subsequent interface-record pass preserves those flattened fixture ports.
Direct VHDL instantiators must adopt the records documented in the interface
review; all in-repository instantiations have been updated.

## Validation and next step

Build-only checks compile and link the RTL entities and simulation wrappers;
VSG checks the PTP VHDL. No regression simulation is authorized before VHDL
approval.

Final build-only results after the combinational-state pass (GHDL 6.0.0):
all 21 RTL entities/wrappers compiled and
linked successfully using the imported SURF sources and existing MAC source list.
The package is analyzed as their dependency. VSG passes all 22 VHDL files, and
`git diff --check` passes. No simulation executable was run. The updated PHC and servo Python stimulus
has only been syntax checked; its AXI setup and PHC ownership timing still
require behavioral verification after VHDL approval. Existing shared-RAM
and optional RoCE binding warnings remain in the build; this is not FPGA timing,
resource, CDC or behavioral qualification.

After approval, the relevant behavioral checks are cancellation versus a
coincident measurement transfer, immutable PHC commands, commit/snapshot reset
recovery, ledger completion ordering, mailbox clock/reset recovery, and the
GMII/XGMII endpoint lifecycle regressions.

## Combinational intermediate state

The additional guidance was found in the SURF checkout under
`~/warm-tdm/firmware/submodules/surf/AGENTS.md` and copied into this repository's
[Two-Process VHDL Style guidance](../../../AGENTS.md#two-process-vhdl-style).
Intermediate calculations and diagnostics belong in `RegType` where practical;
process-local scratch remains appropriate for helper APIs and small loop work.

- `PtpPort` now has only `v` and `ep` in `comb` (previously 22 variables).
  Qualification, selected association slots, corrected remote time, rate span,
  nearest-Sync search and live status use named `v` fields. Configuration reads
  use `r.activeConfig` directly; the request builder accepts that local type.
- `PtpServo` reads active local/shared configuration directly. Sample tick delta
  and integral correction have distinct fields and units. Frequency limiting
  works directly on the existing `v.workFrequency` destination. Alongside `v`, only the AXI endpoint helper and the median-sort array/swap
  temporary remain local.
- PHC command selection, signed time advancement, range/rejection decisions and
  manual command decoding use next-state fields. The central register block's
  command strobes and qualified transaction decisions follow the same pattern.
- Ledger occupancy/search, RX frame qualification and CRC work, physical capture
  lane/count, and math result magnitude/range checks use next-state fields.
  E2E delay calculation writes `v.resultValue.delayValue` directly. Small parser
  byte/index temporaries stay local and receive unconditional defaults.

`v := r` initializes the complete next-state record. Per-cycle pulse/qualification
fields are overwritten in their owning logic sections; intermediate diagnostic
values can retain their last calculation while the corresponding stage is idle.
Consumers of current-cycle calculations read `v`, so this does not add a protocol
pipeline stage. Existing registered outputs still read `r`.

When an output uses a current-cycle `v` field, output publication precedes the
final synchronous reset assignment to `v`. Explicit reset gating of abort and
ready remains in place. This preserves the original same-edge output equations
while `rin` receives the reset value. Asynchronous reset remains solely in `seq`.

The build smoke checks do not qualify synthesis resource use or behavior.
Intermediate fields without observable registered consumers may be optimized
away; adding AXI diagnostics later would make their storage observable and must
be reviewed as a separate hardware/register-map change. Regression approval is
still required before behavioral verification.
