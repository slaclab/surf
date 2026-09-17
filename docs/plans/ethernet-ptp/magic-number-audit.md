# PtpCore RTL magic-number audit

Reviewed all 15 files in `ethernet/PtpCore/rtl` on 2026-09-17, using the
`ethernet-ptp` working tree based on `d8f9c5867`, including the pending readability
changes. The initial audit was static; the implementation below followed it.
Existing simulation results predate the pending refactors. The maintainer VHDL
approval gate remains in force.

## Implementation status

The recommended cleanup is implemented in 13 RTL files. `PtpMath` and
`PtpTxTimestampTap` retain the justified literals identified by the audit.

- `PtpPkg` owns EtherType byte orders, message lengths, profile
  encodings, flags, fixed-point formats, separate seconds/ppb scales, IRQ bit
  names, and message-specific body accessors. The flattened RX width derives
  from the serialized fields and remains 744 bits.
- The frontend, primary guard, MAC bypass, port builder and ledger consume
  those definitions. Delay_Req remains 58 bytes before padding/FCS, with eight
  eight-byte beats and a final two-byte beat. CRC and physical framing symbols
  have local names; exact accepted flag masks and byte ordering are preserved.
  Following readability review, the Delay_Req builder uses explicit byte
  positions with field/range comments, while retaining named protocol values
  and shared sizes. The primary guard likewise uses the explicit EtherType slice
  `111 downto 96`, with a comment identifying frame bytes 12..13. These are
  intentional exceptions to A3's offset recommendation. The RX frontend also
  uses explicit, commented wire positions for header validation and decoding;
  the unused header-offset constants were removed from the package. Shared
  frame-size limits and protocol values remain named.
- The port names policy limits and separate association/history depths, uses
  explicit depth-derived integer ranges for search scratch, and explains timeout
  defaults and LFSR bit ordering. The servo names its median depth and actuator
  envelope; arithmetic scale conversions derive from documented formats.
- The PHC read mailbox uses one private layout definition for packing and
  unpacking, retaining its 209-bit payload and four-slot FIFOs. AXI aperture
  constants now also drive the base-alignment assertion. Register offsets,
  identification value, configuration defaults and interface timing are unchanged.

The `2048`-cycle association floor and `200000`-ppb actuator cap remain existing
implementation policy. Inspection of their introducing commit (`dc18c9ba2`)
found no additional rationale. Their names/comments preserve that uncertainty;
this cleanup does not claim a proven latency budget or hardware qualification.
The independently documented oscillator qualification limit has its own constant.

Validation: VSG passes all 15 RTL files (689 rules per file); GHDL 6.0.0 compiles
and links all 21 RTL entities/wrappers. The package is analyzed as their
dependency. Existing shared-RAM, optional RoCE binding and wrapper open-association
warnings remain. `git diff --check` passes. No simulation executable or pytest
regression was run; behavioral and device-mapped qualification remain pending.

The findings below retain the original review rationale. Source links identify
the owning files; the cited literals describe their pre-cleanup form.

The useful targets are values whose protocol meaning, units, policy, or coupling
to another expression are hidden. Explicit AXI offsets, ordinary byte arithmetic,
zero/one tests, and documented interface widths do not need names merely because
they are numeric. The findings below identify maintenance risks; they do not
establish an arithmetic or protocol defect.

## Findings

### A1. EtherType and existing message constants: shared protocol definitions

The PTP EtherType appears in four places with two byte orders:

- [EthMacPtpEndpoint](../../../ethernet/PtpCore/rtl/EthMacPtpEndpoint.vhd):
  MAC bypass `x"F788"`.
- [PtpPrimaryGuard](../../../ethernet/PtpCore/rtl/PtpPrimaryGuard.vhd):
  first-beat EtherType comparison `x"F788"`.
- [PtpRxFrontend](../../../ethernet/PtpCore/rtl/PtpRxFrontend.vhd):
  network-order comparison `x"88F7"`.
- [PtpPort](../../../ethernet/PtpCore/rtl/PtpPort.vhd):
  transmitted octets `x"88"`, `x"F7"`.

Define the network-order EtherType in `PtpPkg`, and derive its low-byte-first
stream/MAC representation explicitly. Do not replace both byte orders with the
same bit pattern. No suitable exported constant was found in the inspected
`EthMacPkg`.

Also reuse the existing `PTP_MSG_*_C` definitions in
[PtpRxFrontend.baseLength](../../../ethernet/PtpCore/rtl/PtpRxFrontend.vhd)
and [PtpTxLedger](../../../ethernet/PtpCore/rtl/PtpTxLedger.vhd).
These still use `x"0"`, `x"1"`, `x"8"`, `x"9"`, and `x"B"` directly despite
the named definitions already used by the port.

### A2. Packet geometry: derive related sizes from shared definitions

[PtpRxFrontend](../../../ethernet/PtpCore/rtl/PtpRxFrontend.vhd),
[baseLength](../../../ethernet/PtpCore/rtl/PtpRxFrontend.vhd), and
[EOF validation](../../../ethernet/PtpCore/rtl/PtpRxFrontend.vhd)
explain many lengths, but their literals remain independently repeated:

- Ethernet header 14 bytes, FCS 4 bytes, combined overhead 18 bytes.
- PTP common header 34 bytes; fixed messages 44, 54, and 64 bytes.
- Saved prefix 78 bytes, array upper bound 77, and 30-byte message body.
- Minimum received frame 64 bytes; `MAX_FRAME_G` range 82 through 1518.
  The lower generic bound accommodates Ethernet + Announce + FCS; it is distinct
  from the minimum accepted Ethernet frame length.
- Four-byte TLV header and its two-byte length field.

[PtpPort.buildRequest](../../../ethernet/PtpCore/rtl/PtpPort.vhd)
independently encodes the Delay_Req length as `x"2C"`, stores 58 bytes in
`463 downto 0`, and uses an eight-beat TX sequence with final keep `x"03"`
([TX](../../../ethernet/PtpCore/rtl/PtpPort.vhd)).

Add shared wire-length constants; derive prefix storage, frame storage, final
beat, and final-byte mask from those lengths and the stream width. Preserve the
static beat-selection mux and its synthesis intent. Keep ordinary eight-bit
octet arithmetic readable rather than naming every multiplication by eight.

### A3. Header offsets and body slices: expose the decoded field

The frontend's [field extraction](../../../ethernet/PtpCore/rtl/PtpRxFrontend.vhd)
and port's [builder](../../../ethernet/PtpCore/rtl/PtpPort.vhd)
share offsets such as 12 (EtherType), 14 (PTP start), 34 (source identity),
44 (sequence), 46 (control), and 48 (body), but do not share their definitions.
Use named header-relative offsets plus the Ethernet header size where practical.

More opaque are the body slices in
[PtpPort](../../../ethernet/PtpCore/rtl/PtpPort.vhd),
[PtpPort](../../../ethernet/PtpCore/rtl/PtpPort.vhd),
[PtpPort](../../../ethernet/PtpCore/rtl/PtpPort.vhd), and
[PtpTxLedger](../../../ethernet/PtpCore/rtl/PtpTxLedger.vhd):
`239:160` is the timestamp, `191:160` its nanoseconds, `159:80` the Delay_Resp
requesting identity, `87:24` the Announce grandmaster identity, and `159:144`
the Announce UTC offset. Small message-specific accessors in `PtpPkg` would
explain these uses and centralize the layout. Avoid a generic packet framework.

### A4. Version/profile and flags: name semantics without weakening checks

[PtpRxFrontend](../../../ethernet/PtpCore/rtl/PtpRxFrontend.vhd)
accepts major version 2 and minor versions 0/1;
[PtpPort](../../../ethernet/PtpCore/rtl/PtpPort.vhd) validates the same
minor-version range, and the builder transmits major version 2. The port also
requires transport-specific zero at
[the corresponding stage](../../../ethernet/PtpCore/rtl/PtpPort.vhd).
Represent these as the supported endpoint profile, not unexplained nibbles.

The port's `x"0200"` Sync flags, timescale bit 3, mutually exclusive leap bits
1:0, and reserved upper octet deserve named flags/masks:
[Announce checks](../../../ethernet/PtpCore/rtl/PtpPort.vhd),
[identity change](../../../ethernet/PtpCore/rtl/PtpPort.vhd), and
[message validation](../../../ethernet/PtpCore/rtl/PtpPort.vhd).
Keep exact-mask acceptance equivalent; replacing equality with a single-bit
test would change the accepted profile. A zero-flags comparison is reasonable
once the surrounding policy is explicit.

### A5. Physical framing and CRC: name recognizable wire symbols

[PtpRxTimestampAdapter](../../../ethernet/PtpCore/rtl/PtpRxTimestampAdapter.vhd)
uses XGMII start `x"FB"`, terminate `x"FD"`, preamble `x"55"`, and SFD `x"D5"`.
Name these locally unless an appropriate existing shared Ethernet definition is
available. Explain legal start lanes 0/4 and name or derive the six remaining
XGMII versus seven GMII preamble octets. These are wire rules, unlike ordinary
lane-array indexing.

[PtpRxFrontend](../../../ethernet/PtpCore/rtl/PtpRxFrontend.vhd)
uses CRC residue `x"C704DD7B"`. Its nearby comment correctly identifies the
`CrcPkg` register convention; a local Ethernet-good-residue constant would make
the comparison self-explanatory. No exported residue constant was found in the
inspected `CrcPkg`. Preserve the convention and bit ordering.

[EthMacPtpEndpoint](../../../ethernet/PtpCore/rtl/EthMacPtpEndpoint.vhd)
sets pause-quantum cycles to 64 for GMII and 8 for XGMII. A short derivation
(`512 bits / physical bits per cycle`) is sufficient; this does not require
another package constant.

### A6. One billion has two different units: separate conversion constants

The existing `PTP_NANOSECONDS_PER_SECOND_C` should replace the literal divisor
in [PtpServo](../../../ethernet/PtpCore/rtl/PtpServo.vhd): this stage
converts elapsed nanoseconds to seconds.

Conversely, [PtpServo](../../../ethernet/PtpCore/rtl/PtpServo.vhd) and
the denominator of [PtpPort.RATE_MARGIN_C](../../../ethernet/PtpCore/rtl/PtpPort.vhd)
use one billion as a **parts-per-billion scale**. Add a separately named ppb
scale rather than using the nanoseconds constant for these calculations.

[PtpServo](../../../ethernet/PtpCore/rtl/PtpServo.vhd) currently reuses
`SECOND_Q16_C` for conversion from Q16 ppb to a PHC rate addend. The numeric value
is right, but the name has the wrong units there. Use a ppb-scale Q16 constant
for that stage; retain the seconds constant for phase normalization. This is a
semantic cleanup, not evidence that the current arithmetic result is wrong.

### A7. Fixed-point shifts: derive scale changes from the interface formats

The most significant repeated conversions are:

- [PtpE2e](../../../ethernet/PtpCore/rtl/PtpE2e.vhd): shift 35 is
  `3 + 48 - 16` for raw tick-phase times rate ratio to Q16 nanoseconds.
- [PtpPort](../../../ethernet/PtpCore/rtl/PtpPort.vhd): the inverse
  ratio calculation uses the same shift 35; raw tick limits use shift 3.
- [PtpE2e](../../../ethernet/PtpCore/rtl/PtpE2e.vhd) and
  [PtpPort](../../../ethernet/PtpCore/rtl/PtpPort.vhd): shift 16 aligns
  the Q32 PHC increment with the Q48 rate ratio.
- [PtpServo](../../../ethernet/PtpCore/rtl/PtpServo.vhd) and
  [the corresponding stage](../../../ethernet/PtpCore/rtl/PtpServo.vhd): shifts 30 and 62
  remove gain fractional bits and gain-plus-elapsed-seconds fractional bits.
- [PtpPhc](../../../ethernet/PtpCore/rtl/PtpPhc.vhd),
  [PtpServo](../../../ethernet/PtpCore/rtl/PtpServo.vhd), and
  [PtpPkg](../../../ethernet/PtpCore/rtl/PtpPkg.vhd): Q16/Q32 phase
  conversion and normalization.

The package already documents the units. Add a small set of shared fractional
bit counts and derive these compound shifts, or put the conversion in a named
helper where that reads better. Keep actual arithmetic widths and signed
widening deliberate. Do not confuse a format shift with a filter coefficient.
The E2E final division by two is the mathematical mean, already clear in context.

### A8. Limits needing provenance: 2048 ticks and 200000 ppb

[PtpPort.validConfig](../../../ethernet/PtpCore/rtl/PtpPort.vhd)
requires an association timeout of at least 2048 raw clock cycles. The reviewed
RTL and PTP task documentation do not explain why this threshold is sufficient
or necessary. Give it a local minimum-timeout name and document the actual
latency budget or design rationale. Do not claim that it follows from the
128-step math engine without accounting for the full operation sequence.

[PtpPort](../../../ethernet/PtpCore/rtl/PtpPort.vhd) limits estimated
oscillator deviation to 200000 ppb, while
[PtpServo](../../../ethernet/PtpCore/rtl/PtpServo.vhd) caps the configurable
actuator limit at the same value. The [implementation record](autonomous-endpoint.md)
documents the estimator's 200 ppm envelope. Name both purposes; share a single
policy value only if their equality is intentional. The actuator cap also needs
its rationale. Neither should be confused with the default 150000 ppb total
correction setting.

### A9. Port policy and repeated table sizes

[PtpPort](../../../ethernet/PtpCore/rtl/PtpPort.vhd) and
[the corresponding stage](../../../ethernet/PtpCore/rtl/PtpPort.vhd) repeat the supported
log-interval range -10 through +22. Define the bounds once and explain why this
implementation chooses them. The range is documented in the implementation
record; it is not the full range of the signed eight-bit wire field.

The three-period receipt timeout is already explained beside
[receiptTimeout](../../../ethernet/PtpCore/rtl/PtpPort.vhd). Add equally
local explanation or a named policy value for the twice-Sync Announce cap.
The [rate update](../../../ethernet/PtpCore/rtl/PtpPort.vhd) should name
the two-interval qualification requirement and quarter-weight IIR shift.

The four-entry association table and four-entry Sync history repeat upper bound
3 and modulo 4 across declarations/searches/updates
([tables](../../../ethernet/PtpCore/rtl/PtpPort.vhd)). Use separate local
depth constants and array attributes; equal depths need not imply one policy.
Retain the no-match sentinel and the separately reviewed bounded-index behavior.

The jitter distribution is already explained in
[the scheduling section](../../../ethernet/PtpCore/rtl/PtpPort.vhd), but the LFSR taps
15/13/12/10 need a polynomial/bit-order comment. Reuse a named
nonzero fallback seed for the repeated `x"0001"` reset/recovery values. A
constant per individual tap would obscure the recurrence rather than help it.

### A10. Servo median depth and frequency-derived defaults

[PtpServo](../../../ethernet/PtpCore/rtl/PtpServo.vhd) and
[filter](../../../ethernet/PtpCore/rtl/PtpServo.vhd) implement the
documented five-sample median, repeating 5, 4, and 3 in count bounds, pointer
wrap, and sorting loops. Use one local filter-depth constant and derived bounds.
Keep `(count-1)/2` visible as the lower populated median selection.

[PtpPort.initialConfig](../../../ethernet/PtpCore/rtl/PtpPort.vhd) and
[PtpServo.initialConfig](../../../ethernet/PtpCore/rtl/PtpServo.vhd)
recompute package timer defaults with shifts. Add short duration comments here
(1 s, 3 s, 2 s, 0.5 s, 4 s; 4 s, 64 s, 1/64 s, 2 s respectively), matching
the existing package comments. A shared default-construction helper is optional;
the immediate deficiency is having to decode shifts to recover policy.

### A11. Packed records: make layout widths auditable

[PtpPhcRead](../../../ethernet/PtpCore/rtl/PtpPhcRead.vhd) names its width
`WIDTH_C := 209`, but the derivation and
[unpack slices](../../../ethernet/PtpCore/rtl/PtpPhcRead.vhd) are separate.
Derive `48 + 32 + 32 + 32 + 64 + 1` from field widths and centralize the
private pack/unpack layout or its offsets locally. It need not become a public
package format. The four-slot FIFO choices (`ADDR_WIDTH_G => 2`) would benefit
from a short sizing rationale given the one-outstanding-request contract.

[PtpPkg](../../../ethernet/PtpCore/rtl/PtpPkg.vhd) already names the
744-bit flattened RX format. Its
[concatenation](../../../ethernet/PtpCore/rtl/PtpPkg.vhd) is clear, but a
field-width sum or elaboration check would prevent the separate width constant
from silently drifting. Preserve the intentional selection of serialized fields.

### A12. Register and integration literals: limited optional improvements

[PtpEndpoint](../../../ethernet/PtpCore/rtl/PtpEndpoint.vhd) passes 14/12
address bits to the crossbar helper and separately asserts 16 KiB alignment.
The aperture is already explained. Local aperture/bank-width constants could
tie the assertion and helper together, but explicit register offsets should stay
hex literals as requested.

The endpoint's [IRQ assignments](../../../ethernet/PtpCore/rtl/PtpEndpoint.vhd)
use event bits 0..3. Named event positions would connect these meanings to the
coordinator's vector and software documentation. Ordinary single-owner register
field positions, PHC command bits, and ledger status packing are acceptable
when kept beside their documented mapping.

[PtpReg](../../../ethernet/PtpCore/rtl/PtpReg.vhd) returns `x"00020000"`
at the existing identification/version offset. A local name or explicit comment
could identify this provisional value. Do not introduce release ABI versioning
or change the register value as part of this cleanup.

## Complete file coverage

| RTL file | Disposition |
| --- | --- |
| `EthMacPtpEndpoint.vhd` | A1 EtherType; A5 pause quantum. Clock and configurable FIFO defaults are explicit integration settings. |
| `PtpE2e.vhd` | A7 fixed-point conversions; division by two and deliberate arithmetic widths are acceptable. |
| `PtpEndpoint.vhd` | A12 optional aperture/IRQ naming. Bank indices already have names. |
| `PtpMath.vhd` | No protocol/policy magic-number finding. The documented 128-step algorithm explains 127/128/129/256. Optional use of operand attributes/local width constants can reduce repeated dimensions; no need to parameterize the public interface. |
| `PtpPhc.vhd` | A7 phase conversion. Command encodings already named; explicit offsets, command-word positions, rollover masks, and widened arithmetic are acceptable. |
| `PtpPhcRead.vhd` | A11 private packed layout and FIFO-sizing explanation. All-ones sequence exhaustion is clear. |
| `PtpPkg.vhd` | Owner for shared definitions in A1-A4/A6-A7; A11 flattened width. Existing unit/default comments, named multicast/MAC insertion constants, command codes, timeout envelope, and servo states are satisfactory. |
| `PtpPort.vhd` | A1-A4 wire definitions; A6-A10 numeric conversions, policy, tables, and timer explanations. Most cleanup opportunities are here. |
| `PtpPrimaryGuard.vhd` | A1 EtherType; A3 EtherType byte offset. The documented 16-byte first-beat/full-keep requirement is clear. |
| `PtpReg.vhd` | A12 optional identification/event naming. Explicit register offsets and bit positions should remain readable. |
| `PtpRxFrontend.vhd` | A1-A5 message codes, lengths, offsets, profile, and CRC residue. Explicit CRC dispatch by byte count is appropriate. |
| `PtpRxTimestampAdapter.vhd` | A5 physical framing symbols/preamble rules; A7 shared lane-phase format. Ordinary lane/byte slicing is acceptable. |
| `PtpServo.vhd` | A6-A8 units, fixed-point shifts, and rate cap; A10 median depth and timer explanations. Saturating byte counters are clear. |
| `PtpTxLedger.vhd` | A1 existing Delay_Req constant; A3 response body accessors. Configurable depth/sequence width and documented status packing are acceptable. |
| `PtpTxTimestampTap.vhd` | No required change: two-entry completion queue is documented; `x"8000000000000000"` explicitly checks the non-negatable signed minimum. |

## Recommended implementation order and validation

1. Reuse existing message constants, add byte-order-explicit EtherType/flag
   definitions, and separate seconds versus ppb scales (A1, A4, A6).
2. Consolidate shared wire geometry/accessors and fixed-point conversions
   (A2, A3, A7); name local physical symbols/residue (A5).
3. Explain policy provenance, then consolidate repeated local limits, filter
   depths and packed layouts (A8-A11). Apply A12 only where it aids readability.

Do not change numerical values, accepted traffic, register maps, synthesis
structure, or handshake timing as a side effect of naming. Keep independent
Python packet/measurement oracles independent rather than importing the same
new constants everywhere and losing cross-checks.

This audit used source inspection, a numeric-literal inventory, existing package
and task-documentation comparison, and coverage/link checks. `git diff --check`
passes. Implementation should receive VSG and GHDL compile/link checks; behavioral
regressions remain deferred until maintainer VHDL approval. Any inferred rationale
for the 2048-tick or actuator bounds remains open until justified explicitly.
