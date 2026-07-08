# PGP4 Fixed-Latency Link Implementation Plan

## Status

Planning document only. No RTL has been changed for this effort yet.

This plan captures a proposed PGP4 fixed-latency extension. A high-bandwidth trigger-primitive transport is used as an example application, but the core FL mechanism should remain general enough to carry occasional fixed-latency triggers alongside ordinary PGP4 virtual-channel traffic.

## Goals

Add an optional fixed-latency (FL) path to PGP4 with these properties:

- Deterministic latency from accepted FL transmit word/block to received FL output.
- Higher bandwidth than the existing 48-bit opcode path.
- Similar semantic role to PGP2FC `fcWord/fcValid`, but adapted to PGP4 64b/66b transport.
- Optional coexistence with standard PGP4 virtual-channel frame traffic.
- Configurable FL payload length, analogous to PGP2FC `FC_WORDS_G`.
- A degenerate high-throughput configuration suitable for links carrying only FL traffic.
- No hidden dependence on the normal AXI Stream packetizer/depacketizer path for FL payload transport.

Out of scope for the first implementation:

- Making normal PGP4 virtual-channel AXI Stream traffic itself a fixed-latency interface.
- Supporting arbitrary runtime FL payload lengths.
- Guaranteeing deterministic GT latency without a matching fixed-latency GT profile and alignment procedure.
- Replacing all existing PGP4 wrappers. This should initially be a new fixed-latency-capable profile or explicitly-gated optional behavior.

## Existing PGP4 Context

Relevant files:

- `protocols/pgp/pgp4/core/rtl/Pgp4Pkg.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4Core.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4Tx.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4TxProtocol.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4Rx.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4RxProtocol.vhd`
- `protocols/pgp/pgp4/core/rtl/Pgp4RxEb.vhd`
- `protocols/pgp/pgp4/gtyUs+/rtl/Pgp4GtyUs.vhd`
- `protocols/pgp/pgp4/gtyUs+/rtl/Pgp4GtyUsIpFecWrapper.vhd`

Important current behavior:

- PGP4 uses 64b/66b-style `phy*Data(63 downto 0)` plus `phy*Header(1 downto 0)`.
- `PGP4_D_HEADER_C = "01"` and `PGP4_K_HEADER_C = "10"`.
- K-code words use:
  - `63:56`: BTF.
  - `55:48`: K-code CRC8.
  - `47:0`: BTF-specific payload.
- Existing K-code BTFs are `IDLE`, `SOF`, `EOF`, `SOC`, `EOC`, `SKP`, and `USER`.
- Current `USER` opcode carries 48 bits because the K-code word reserves 8 bits for the K-code CRC.
- `Pgp4TxProtocol` emits IDLE by default, accepts packetized data, lets USER override data, and lets SKP/status IDLEs override data in specific cases.
- `Pgp4RxProtocol` parses K-code words before the depacketizer path. USER opcodes are detected there and exposed as `pgpRxOut.opCodeEn/opCodeData`.
- Normal VC traffic goes through `AxiStreamMux`, `AxiStreamPacketizer2`, PGP4 SOF/DATA/EOF mapping, `AxiStreamDepacketizer2`, and optional RX demux. This path is not a good fixed-latency contract because arbitration, packet boundaries, CRC tail handling, flow control, and backpressure affect timing.
- `Pgp4RxEb` can bypass its elastic buffer when `SKIP_EN_G = false`, but the current high-speed wrappers do not expose/use a complete fixed-latency profile.
- GT wrappers currently use PGP3 GT IP wrappers for PGP4.
- PGP4 GTY US+ has optional FEC through `PGP_FEC_ENABLE_G`, wrapping Xilinx `ieee802d3_clause74_fec:1.0`.

## Proposed FL Wire Format

Add a new PGP4 K-code BTF for fixed-latency blocks:

```vhdl
constant PGP4_FL_C : slv(7 downto 0) := <choose-unused-value>;
```

The FL block has fixed length at synthesis/elaboration time:

```text
1 FL header K word
FL_WORDS_G data words
FL_GAP_WORDS_G ordinary scheduler words before another FL block may be accepted
```

Header word:

```text
header[1:0] = PGP4_K_HEADER_C
data[63:56] = PGP4_FL_C
data[55:48] = pgp4KCodeCrc(data)
data[47:16] = CRC32 over the FL payload data words
data[15:8]  = PGP4_VERSION_C
data[7:0]   = sequence/flags/type, exact allocation TBD
```

Payload words:

```text
header[1:0] = PGP4_D_HEADER_C
data[63:0]  = one FL payload word
```

No tail BTF is used. Both endpoints must be configured with the same `FL_WORDS_G`.

Rationale:

- Avoids the bandwidth cost of an FL tail word.
- Keeps the header as a normal protected PGP4 K word.
- Uses the existing K-code CRC8 to protect the FL header interpretation.
- Uses CRC32 to protect the multiword FL payload.
- Gives payload efficiency:

```text
FL payload efficiency = FL_WORDS_G / (1 + FL_WORDS_G + FL_GAP_WORDS_G)
```

Examples:

- `FL_WORDS_G = 8`, `FL_GAP_WORDS_G = 1`: 8/10 = 80% of 64b words carry FL payload.
- `FL_WORDS_G = 8`, `FL_GAP_WORDS_G = 0`: 8/9 = 88.9% of 64b words carry FL payload.

## Proposed Generics

Add optional FL generics at the PGP4 core/protocol levels. Names can be adjusted to match final code style.

```vhdl
FL_EN_G        : boolean := false;
FL_WORDS_G     : positive range 1 to 8 := 1;
FL_GAP_WORDS_G : natural range 0 to 1 := 1;
```

Behavior:

- `FL_EN_G = false`: existing PGP4 behavior should be preserved.
- `FL_WORDS_G`: number of 64-bit FL payload words following one FL header.
- `FL_GAP_WORDS_G`: number of ordinary scheduler opportunities forced after an FL block before another FL block may be accepted.

Do not add a separate `FL_ONLY_G`.

The FL-only use case is achieved by normal generics and system integration:

```vhdl
FL_EN_G        => true
FL_WORDS_G     => 8
FL_GAP_WORDS_G => 0
SKIP_EN_G      => false
NUM_VC_G       => 1
```

The integrator simply does not drive VC traffic.

The mixed traffic use case should typically use:

```vhdl
FL_EN_G        => true
FL_WORDS_G     => 1 or 8
FL_GAP_WORDS_G => 1
```

This lets one ordinary scheduler word, usually IDLE/link-info, occur between back-to-back FL bursts.

## Proposed FL User Interface

Add FL fields to PGP4 package records, or define a separate record type if cleaner. A separate record may reduce churn on existing `Pgp4TxInType/Pgp4RxOutType`, but adding fields is consistent with the existing opcode path.

Candidate package additions:

```vhdl
subtype PGP4_FL_CRC_FIELD_C     is natural range 47 downto 16;
subtype PGP4_FL_VERSION_FIELD_C is natural range 15 downto 8;
subtype PGP4_FL_FLAGS_FIELD_C   is natural range 7 downto 0;

type Pgp4FlTxType is record
   valid : sl;
   data  : slv(FL_WORDS_G*64-1 downto 0); -- Cannot be generic in package record as written.
   user  : slv(7 downto 0);
end record;
```

Because package record widths cannot depend on entity generics in the simple exported type, prefer explicit ports at the entities that need FL:

TX-side candidate ports:

```vhdl
flTxValid : in  sl := '0';
flTxReady : out sl;
flTxData  : in  slv(FL_WORDS_G*64-1 downto 0) := (others => '0');
flTxUser  : in  slv(7 downto 0) := (others => '0');
```

RX-side candidate ports:

```vhdl
flRxValid    : out sl;
flRxData     : out slv(FL_WORDS_G*64-1 downto 0);
flRxUser     : out slv(7 downto 0);
flRxCrcError : out sl;
flRxSeqError : out sl; -- optional, depending on flags/user allocation
```

Handshake contract:

- `flTxReady` marks the deterministic acceptance point.
- `flTxValid and flTxReady` samples the full FL payload block and user/flags byte.
- Fixed latency is promised from this acceptance event to the corresponding RX `flRxValid`, not from an arbitrary `flTxValid` edge while `flTxReady = '0'`.
- TX must hold `flTxData/flTxUser` stable while asserting `flTxValid` until acceptance.
- RX should assert `flRxValid` for one clock at a fixed cycle after the corresponding FL header/payload block is received and CRC has been checked.
- If CRC fails, either:
  - assert `flRxValid = '0'` and pulse `flRxCrcError`, or
  - assert `flRxValid = '1'` with `flRxCrcError = '1`.
- Recommended initial policy: suppress `flRxValid` on CRC failure and pulse `flRxCrcError`.

## CRC Strategy

Keep both CRCs:

- CRC8 is the existing K-code CRC and protects the FL header BTF, embedded CRC32, version, and flags.
- CRC32 protects the `FL_WORDS_G` 64-bit payload words.

Use the same CRC32 polynomial already defined for PGP4 frame data:

```vhdl
constant PGP4_CRC_POLY_C : slv(31 downto 0) := X"04C11DB7";
```

Implementation options:

- Combinational CRC32 over the full `FL_WORDS_G*64` vector.
- Fixed-depth pipelined CRC32 if timing requires it.

For fixed latency, the CRC implementation may be pipelined as long as:

- The number of pipeline cycles is fixed.
- `flTxReady` accounts for the pipeline schedule.
- RX `flRxValid` is delayed by a fixed number of cycles to allow CRC comparison.

Recommended first implementation:

- Use a fixed pipeline with a generic or local constant for CRC latency if timing at 371.429 MHz is uncertain.
- For `FL_WORDS_G <= 8`, consider one or two pipeline stages rather than fully combinational 512-bit CRC if timing is difficult.
- Document the fixed latency contribution of the CRC pipeline.

## TX Scheduler Design

Modify `Pgp4TxProtocol`, not the normal AXI packetizer path.

Add TX state:

```vhdl
type FlStateType is (FL_IDLE_S, FL_HDR_S, FL_DATA_S, FL_GAP_S);
```

or integrate equivalent counters into the existing two-process `RegType`.

Suggested registered fields:

```vhdl
flActive      : sl;
flDataIndex   : natural range 0 to FL_WORDS_G-1;
flGapCount    : natural range 0 to FL_GAP_WORDS_G;
flDataLatched : slv(FL_WORDS_G*64-1 downto 0);
flUserLatched : slv(7 downto 0);
flCrcLatched  : slv(31 downto 0);
flReady       : sl;
```

Priority rules:

1. If currently emitting an FL block, complete the block without interruption.
2. If in FL gap, run the ordinary scheduler for `FL_GAP_WORDS_G` word opportunities and do not accept a new FL block.
3. If `FL_EN_G` and `flTxValid` and the link is ready and no FL gap is active, accept the FL block and emit the FL header.
4. Otherwise run the existing scheduler priority unchanged as much as possible:
   - IDLE default.
   - Packetized data.
   - USER opcode override.
   - SKP override if enabled.
   - forced IDLE after EOF when `RX_CRC_PIPELINE_G = 1`.
   - pause/overflow urgent IDLEs.

Important design decision:

- FL should preempt normal VC traffic and opcode traffic once accepted, similar to PGP2FC `fcWord`.
- FL acceptance should be blocked when the link is not ready.
- For the trigger-primitive application, flow control is disabled/irrelevant and no VC data is driven.

Priority decision:

- FL always has priority over the existing USER opcode when both are presented in the same cycle.
- Rationale: FL is the fixed-latency interface and USER opcode acceptance is already best-effort through `opCodeReady`.
- A system that continuously drives FL can starve USER opcode transmission. This is expected behavior, not a scheduler exception. Mixed-use systems that need USER opcode progress must leave ordinary scheduler opportunities through `FL_GAP_WORDS_G` and upstream FL rate control.

Header construction:

```vhdl
flHeader := (others => '0');
flHeader(PGP4_BTF_FIELD_C)        := PGP4_FL_C;
flHeader(PGP4_FL_CRC_FIELD_C)     := flCrc;
flHeader(PGP4_FL_VERSION_FIELD_C) := PGP4_VERSION_C;
flHeader(PGP4_FL_FLAGS_FIELD_C)   := flUser;
flHeader(PGP4_K_CODE_CRC_FIELD_C) := pgp4KCodeCrc(flHeader);
```

Payload word order:

- Choose and document bit ordering.
- Recommended:

```vhdl
word 0: flTxData(63 downto 0)
word 1: flTxData(127 downto 64)
...
```

or the reverse if it better matches local packet conventions. The RX must mirror it exactly.

For the trigger-primitive use case, choose the ordering that maps naturally to the upstream FC-domain primitive register.

## RX Parser Design

Modify `Pgp4RxProtocol`, before normal K-code and D-code forwarding to the depacketizer.

Add RX state/counters:

```vhdl
flReceiving    : sl;
flDataIndex    : natural range 0 to FL_WORDS_G-1;
flDataLatched  : slv(FL_WORDS_G*64-1 downto 0);
flCrcExpected  : slv(31 downto 0);
flUserLatched  : slv(7 downto 0);
flCrcError     : sl;
```

RX rules:

1. When linked and `protRxHeader = PGP4_K_HEADER_C` and BTF is `PGP4_FL_C`, parse the FL header.
2. Check `PGP4_VERSION_C` in the FL header. Version mismatch should assert link/protocol error or an FL-specific error.
3. Capture expected CRC32 and flags/user.
4. Consume exactly `FL_WORDS_G` following `PGP4_D_HEADER_C` words into the FL buffer.
5. Do not forward those data words into the normal `pgpRawRxMaster`/depacketizer path.
6. After the last word, compute/compare CRC32 with fixed latency and pulse `flRxValid` when valid.
7. If an unexpected K word, invalid header, or missing data word appears during FL receive, assert an FL/protocol error and abort the FL block.

Link maintenance:

- Current RX link logic resets its linked count on valid IDLE/SOF/SOC link-info words.
- Continuous FL with `FL_GAP_WORDS_G = 0` must not make the link appear idle/broken.
- Treat valid FL headers with matching `PGP4_VERSION_C` as link-maintenance events for the RX link counter.
- For mixed mode with `FL_GAP_WORDS_G = 1`, the ordinary gap word can still carry IDLE/link-info.

Initial FL-only application:

- It is acceptable for the RX link readiness mechanism to rely on FL headers as valid protocol K words, because normal flow-control/link-info is intentionally unused.

## Interaction With SKP, Elastic Buffer, And Flow Control

For fixed latency:

- `SKIP_EN_G` should be false.
- RX elastic buffer should be bypassed.
- The PGP4 RX protocol clock must be the deterministic PHY RX word clock or a deterministic same-clock bridge.
- Flow control should be disabled for the trigger-primitive application.

For mixed traffic:

- `FL_GAP_WORDS_G = 1` is recommended so that normal IDLE/link-info/flow-control can make progress between frequent FL bursts.
- If an integrator sets `FL_GAP_WORDS_G = 0` while also expecting ordinary PGP4 flow-control status, that configuration should be documented as unsafe or unsupported.

Suggested assertions:

```vhdl
assert not (FL_EN_G and SKIP_EN_G and fixed_latency_profile)
   report "PGP4 fixed-latency FL profile requires SKIP_EN_G=false"
   severity warning or failure;
```

The exact assertion should depend on whether the code can distinguish the fixed-latency GT profile from ordinary PGP4.

## FEC Considerations

At the target high-rate use case, plan for FEC:

```vhdl
PGP_FEC_ENABLE_G => true
```

Current SURF PGP4 GTY US+ FEC:

- Uses Xilinx `ieee802d3_clause74_fec:1.0`.
- Is wrapped by `Pgp4GtyUsIpFecWrapper`.
- Sits between the PGP4 66-bit stream and GT 66-bit stream.
- Does not reduce 66-bit word throughput from the PGP4 scheduler perspective.
- Adds fixed TX/RX pipeline latency if its lock/alignment state is deterministic.

Fixed-latency concerns:

- FEC lock/alignment must be part of the final ready condition.
- The FEC wrapper can drive `rx_din_slip`; this must be included in the RX alignment strategy.
- Verify whether the FEC decoder has multiple possible locked latency phases.
- If FEC lock has reset-dependent latency, extend the reset-until-target-phase checker to include FEC phase/status.

For the first serious hardware profile, keep FEC enabled. Disabling later is easier than proving fixed latency after adding FEC late.

## GT Fixed-Latency Profile

PGP4 fixed latency requires a new or explicit GT profile. The current full high-speed PGP4 wrappers are not fixed-latency-ready by default.

Required GT/profile properties:

- TX/RX elastic buffers disabled or bypassed.
- No RX clock correction/SKP compensation.
- Deterministic RX output clock and user clock phase.
- Deterministic TX user clock path.
- Deterministic 64b/66b gearbox/block alignment.
- No reset-dependent latency variation from RX word alignment, gearbox, or FEC.

The existing `GtRxAlignCheck` reads comma/latency DRP fields that are relevant to 8b10b comma/byte alignment. It must not be reused as-is for PGP4 fixed latency. PGP4 uses 64b/66b sync headers, GT RX gearbox slip, optional Clause 74 FEC alignment, and a different set of possible latency/phase observables.

The existing `Pgp3RxGearboxAligner` is also not sufficient by itself. It is still useful as the block-sync mechanism because it monitors 64b/66b headers and issues `rxGearboxSlip` until valid headers are found. However, it only answers "am I on a valid 66-bit boundary?" It does not answer "did this link come up with the same deterministic RX latency phase as last time?"

Open AMD documentation items:

- Identify the correct UltraScale+ GTY DRP/status fields for 64b/66b gearbox/FEC alignment phase.
- Determine whether `RXGBOX_FIFO_LATENCY` or related async gearbox latency fields are present/relevant in the intended GT wizard configuration.
- Determine whether a synchronous gearbox/buffer-bypass configuration exposes deterministic phase information suitable for reset-until-target-phase.
- Determine the correct FEC alignment status/phase observability.

Potential implementation approach:

- Create a new PGP4 GTY US+ fixed-lat wrapper/profile rather than silently changing existing PGP4 wrappers.
- Expose `SKIP_EN_G` and fixed-latency generics through the wrapper.
- Wire `pgpRxClk` to the deterministic RX PHY word clock when bypassing `Pgp4RxEb`, or otherwise ensure a deterministic same-clock relationship.
- Add a new 64b/66b/FEC-aware fixed-latency alignment checker. This should be analogous in purpose to `GtRxAlignCheck`, but must not be based on 8b10b comma-latency fields.

## Required 64b/66b Fixed-Latency Aligner

Implement a new aligner/checker for fixed-latency PGP4. The exact name is open, but a descriptive name would be:

```text
Pgp4RxFixedLatAligner
```

or, if it is kept generic to GTY/GTH and not PGP4-specific:

```text
GtRxFixedLat64b66bAlignCheck
```

This block should be a new RTL module. Do not extend `GtRxAlignCheck` in place because the existing module is specifically tied to comma/latency DRP behavior used by 8b10b-style links.

### Aligner Responsibilities

The new aligner must perform three distinct jobs:

1. Establish valid 64b/66b block alignment.
2. Verify optional FEC alignment/lock when FEC is enabled.
3. Verify that the final deterministic RX latency phase equals a configured target phase.

Only after all three are true should the fixed-latency PGP4 RX path be considered ready.

### Proposed Inputs And Outputs

Candidate ports:

```vhdl
clk              : in  sl;
rst              : in  sl;

rxHeader         : in  slv(1 downto 0);
rxHeaderValid    : in  sl;
rxData           : in  slv(63 downto 0);
rxDataValid      : in  sl;
rxStartOfSeq     : in  sl := '0';

rxFecEnable      : in  sl := '0';
rxFecLock        : in  sl := '1';
rxFecCorInc      : in  sl := '0';
rxFecUnCorInc    : in  sl := '0';

rxGearboxSlip    : out sl;
rxResetReq       : out sl;
locked           : out sl;
phaseLocked      : out sl;
phaseValue       : out slv(PHASE_WIDTH_G-1 downto 0);
phaseError       : out sl;
```

If the final implementation uses DRP-visible phase/latency fields, add a DRP read interface or connect to an existing DRP access helper:

```vhdl
drpReq           : out sl;
drpRdy           : in  sl;
drpAddr          : out slv(...);
drpData          : in  slv(15 downto 0);
```

The exact DRP interface should follow the local GT wrapper pattern selected for the fixed-latency profile.

### Block-Sync Stage

Reuse the `Pgp3RxGearboxAligner` algorithm or instantiate it internally:

- Treat `rxHeader = "01"` and `rxHeader = "10"` as valid 64b/66b sync headers.
- Treat `rxHeader = "00"` and `rxHeader = "11"` as invalid.
- While unlocked, issue `rxGearboxSlip` on invalid headers and wait the AMD-recommended slip settling interval before checking again.
- Once locked, keep monitoring headers and drop lock if too many invalid headers occur.

This stage replaces neither FEC lock nor phase checking. It only establishes a valid 66-bit word boundary.

### FEC-Aware Stage

When `PGP_FEC_ENABLE_G = true`:

- Require `rxFecLock = '1'` before fixed-latency lock can assert.
- Route FEC-generated slip requests correctly. The current `Pgp4GtyUsIpFecWrapper` drives `rx_din_slip` as `rxGearboxSlipOut` when FEC is not bypassed. The fixed-latency aligner must be placed so that there is exactly one owner of the final GT `rxGearboxSlip` input.
- Treat FEC lock loss as fixed-latency lock loss.
- Count/report FEC corrected and uncorrected events, but do not allow corrected events to change timing.
- On uncorrected events, the RX FL path should report an error or force relock, depending on final policy.

Open question for implementation:

- Determine from AMD documentation and hardware testing whether Clause 74 FEC can lock in multiple deterministic latency phases. If yes, the phase-check stage must include FEC phase, not only GT gearbox phase.

### Phase-Check Stage

This is the part that does not exist today.

After 64b/66b block sync and FEC lock, the aligner must measure a reset-dependent phase/latency indicator and compare it against a target:

```vhdl
if measuredPhase = TARGET_PHASE_G then
   phaseLocked <= '1';
else
   phaseError  <= '1';
   rxResetReq  <= '1';
end if;
```

The preferred phase measurement is a GT/FEC status or DRP field that directly exposes RX gearbox/FEC latency or phase. The implementation must consult AMD documentation for the selected UltraScale+ GTY configuration and record the exact field/address in comments and documentation.

If no suitable DRP/status field exists in the selected fixed-latency 64b/66b configuration, use a protocol training phase measurement:

- During link bring-up, the TX emits a deterministic alignment pattern on a known local event phase.
- Candidate pattern: repeated IDLE/FL alignment words containing a small modulo phase counter.
- The RX captures the received phase counter at the first fixed-latency-safe boundary after block/FEC lock.
- The RX compares the captured counter to `TARGET_PHASE_G`.
- If the phase is wrong, assert `rxResetReq` and retry GT/FEC alignment.

The DRP/status method is preferred because it is lower-level and does not consume protocol format space. The training-pattern method is acceptable if it is deterministic and fully specified.

### Reset-Until-Target-Phase Loop

The fixed-latency profile should use a reset loop similar in spirit to PGP2FC's fixed-latency bring-up:

1. Reset RX datapath/GT/FEC.
2. Wait for GT RX reset done.
3. Run 64b/66b block-sync slip until valid headers are stable.
4. Wait for FEC lock if enabled.
5. Measure phase.
6. If phase equals `TARGET_PHASE_G`, assert fixed-latency lock.
7. If phase does not match, reset RX and retry.
8. If too many attempts fail, expose an error/status bit and leave the link down.

Recommended generics:

```vhdl
FIXED_LAT_ALIGN_EN_G : boolean := false;
TARGET_PHASE_G       : natural := 0;
MAX_ALIGN_RETRIES_G  : natural := 255;
PHASE_WIDTH_G        : positive := <depends on selected measurement>;
```

Recommended status outputs:

```vhdl
alignDone       : sl;
alignError      : sl;
alignRetryCount : slv(7 downto 0);
alignPhase      : slv(PHASE_WIDTH_G-1 downto 0);
```

### Integration Point

For the fixed-latency PGP4 profile:

- Replace or wrap the current direct `Pgp3RxGearboxAligner` instantiation in `Pgp4Rx.vhd`.
- In ordinary non-fixed-latency PGP4 builds, preserve current behavior.
- The fixed-latency aligner output should gate `phyRxActive`/`linkReady` so PGP4 does not declare the link ready until phase lock is achieved.
- The aligner must drive the GT/FEC slip/reset path in the wrapper, not only internal PGP4 status.
- Expose status through AXI-Lite if `EN_PGP_MON_G` is enabled.

### Validation Requirements

Simulation:

- Prove the aligner performs ordinary 64b/66b block sync from invalid header phases.
- Prove it does not assert fixed-latency lock until FEC lock is present when FEC is enabled.
- Mock phase measurements and verify target match/mismatch behavior.
- Verify retry counter and align-error behavior.

Hardware:

- Record measured phase across many RX resets.
- Confirm the aligner retries until the configured phase is reached.
- Confirm final FL latency is identical across RX resets.
- Confirm final FL latency is identical across full link reinitialization.
- If practical, confirm final FL latency is identical across power cycles.
- Run the above with FEC enabled, because FEC is part of the target high-rate profile.

## Example Application: Trigger-Primitives

This section is a non-normative example application used to check whether the proposed FL mechanism has enough bandwidth and a useful cadence. Do not bake these clocks, line rates, payload sizes, or lane counts into the generic PGP4 FL protocol.

System clocks:

```text
FC clock      = 1300/7 MHz = 185.714285 MHz
event rate    = FC/5       = 37.142857 MHz
```

Target trigger primitive sizes discussed:

- 64 bytes/event.
- Larger event sizes were considered during sizing, but are outside the single-lane scope of this example at the preferred profile.

Recommended single-lane 64-byte mapping:

```text
PGP4 word clock = 2 * FC = 371.428571 MHz
GT line rate    = 66 * 371.428571 MHz = 24.514286 Gbps
FL_WORDS_G      = 8
FL_GAP_WORDS_G  = 1
```

One event interval:

```text
5 FC cycles = 10 PGP4 word cycles
```

One FL event:

```text
1 FL header word
8 FL data words = 64 bytes
1 gap/IDLE word
```

This maps exactly to one 64-byte primitive per event on one lane.

Application payload:

```text
64 bytes * 37.142857 MHz = 19.017143 Gbps
```

Line rate:

```text
24.514286 Gbps
```

Efficiency:

```text
8 payload words / 10 total words = 80%
```

Larger event sizes would not fit on one lane with this exact profile without either increasing line rate, changing the event cadence, reducing overhead, or changing the data requirement.

Alternative lower-rate mapping:

```text
PGP4 word clock = 1 * FC = 185.714286 MHz
GT line rate    = 12.257143 Gbps
FL_WORDS_G      = 4
FL_GAP_WORDS_G  = 0
```

One event:

```text
1 FL header + 4 data words = 5 PGP4 words = 32 bytes/event on one lane
```

This lower-rate mapping is useful as a simpler GT/fabric timing reference, but it does not meet a 64-byte/event single-lane target.

Example recommendation:

- First explore the `2*FC`, `24.514286 Gbps`, `FL_WORDS_G=8`, `FL_GAP_WORDS_G=1` profile.
- It uses one GTY lane for 64 bytes/event.
- It preserves a natural link-maintenance gap while aligning exactly to the 5-FC-cycle event cadence.

## Implementation Stages

### Stage 1: Protocol Package And FL RTL Skeleton

Files:

- `Pgp4Pkg.vhd`
- `Pgp4TxProtocol.vhd`
- `Pgp4RxProtocol.vhd`
- `Pgp4Core.vhd`
- `Pgp4Tx.vhd`
- `Pgp4Rx.vhd`

Tasks:

- Add `PGP4_FL_C`.
- Add FL header field subtypes.
- Add FL generics to core/protocol entities.
- Add FL ports to core/protocol entities.
- Preserve existing behavior when `FL_EN_G = false`.
- Add TX FL scheduler skeleton.
- Add RX FL parser skeleton.
- Add FL error/status outputs.

Validation:

- Compile/elaborate existing PGP4 tests/configurations with `FL_EN_G=false`.
- Confirm no interface breakage unless explicitly accepted.

### Stage 2: FL CRC32 And Deterministic TX/RX Behavior

Tasks:

- Implement FL CRC32 helper or reuse existing CRC infrastructure.
- Decide pipeline depth.
- Add TX CRC generation and header formation.
- Add RX CRC generation/check.
- Add RX valid/error timing.
- Add clear comments documenting fixed latency in protocol clock cycles.

Validation:

- Unit-level simulation of TX/RX protocol with known FL payloads.
- Check correct FL word ordering.
- Check CRC pass/fail.
- Check `flTxReady` gap behavior.
- Check FL preempts normal VC data after acceptance.
- Check USER opcode priority decision.

### Stage 3: Cocotb Regression

Add focused tests under the appropriate `tests/protocols/pgp/pgp4` location, following `tests/README.md`.

Test cases:

- `FL_EN_G=false` legacy smoke test.
- Single FL block, `FL_WORDS_G=1`.
- Single FL block, `FL_WORDS_G=8`.
- Back-to-back FL with `FL_GAP_WORDS_G=0`.
- Back-to-back FL with `FL_GAP_WORDS_G=1`.
- FL mixed with idle-only ordinary scheduler.
- FL mixed with USER opcode request.
- FL mixed with VC data request.
- CRC error injection.
- Unexpected K word during FL payload.
- Unexpected D/K header sequence error.
- RX link counter remains healthy under continuous FL.

Assertions:

- Latency from TX acceptance to RX valid is constant across repeated blocks.
- `flTxReady` deasserts during active FL block and configured gap.
- Normal VC words are not emitted into the RX depacketizer during FL payload capture.
- Existing opcode still works when no FL is active.

### Stage 4: Fixed-Latency GTY/FEC Profile

Files likely involved:

- `protocols/pgp/pgp4/gtyUs+/rtl/Pgp4GtyUs.vhd`
- `protocols/pgp/pgp4/gtyUs+/rtl/Pgp4GtyUsWrapper.vhd`
- Existing PGP3 GTY US+ IP wrapper files.
- New fixed-latency GTY wrapper/profile files, if needed.
- `xilinx/general/rtl/GtRxAlignCheck.vhd` as reference only, not as direct reuse for 64b/66b.

Tasks:

- Define fixed-latency GT wizard settings for 24.514286 Gbps.
- Disable/bypass GT RX/TX buffers as required.
- Disable SKP/clock correction.
- Integrate FEC enabled profile.
- Expose deterministic clocks.
- Ensure `Pgp4RxEb` is bypassed (`SKIP_EN_G=false`) and clocks are wired correctly.
- Implement the new 64b/66b/FEC fixed-latency aligner described above; do not reuse `GtRxAlignCheck` as the implementation.
- Define link-ready condition that includes FEC lock and target phase.

Validation:

- Hardware reset cycling test measuring FL latency across many resets.
- Power-cycle test if hardware is available.
- FEC enabled/disabled comparison.

### Stage 5: Example Application Integration Prototype

Example application assumptions:

- FC clock distributed to all endpoints.
- Data acquisition path is already in FC clock domain.
- Trigger primitive event rate is `FC/5`.
- Initial target: 64 bytes/event on one 24.514286 Gbps GTY lane.

Tasks:

- Add FC-domain primitive staging register.
- Build deterministic FC-to-2xFC launch schedule.
- Compute CRC32 in fixed latency before launch or as part of launch schedule.
- Launch one FL block every 5 FC cycles.
- On RX, present primitive in FC domain with deterministic phase.

Validation:

- Simulate FC-to-PGP schedule.
- Confirm one FL block per event.
- Confirm no drift between FC event phase and PGP FL block phase.
- Measure latency from FC-domain source register to FC-domain RX primitive valid.
- Confirm reset-to-reset latency repeatability.

## Open Questions

Protocol:

- Exact unused BTF value for `PGP4_FL_C`.
- Exact bit allocation of FL header low 16 bits.
- Whether RX should suppress `flRxValid` on CRC error or assert valid with error.
- Whether the FL header should include a sequence counter by default.

CRC:

- Final CRC32 bit ordering and initialization/finalization convention.
- Whether to reuse PGP4 frame CRC convention exactly or define FL-specific helper.
- Required CRC pipeline depth for 371.429 MHz.

GT/FEC:

- Exact GT wizard settings for 24.514286 Gbps with fixed latency and FEC.
- Whether Clause 74 FEC alignment has reset-dependent latency phases.
- Which DRP/status fields are appropriate for 64b/66b phase checking.
- Whether current PGP3 GTY IP wrapper can be extended or a new fixed-lat wrapper should be created.

Example application:

- Final trigger primitive size that can be supported on one lane.
- Whether one gap/IDLE word per event is acceptable in the final throughput budget.
- Required error policy for corrupted trigger primitives.

## Suggested Implementation Guidance For A Future Agent

1. Start with the protocol-only FL path in simulation. Do not change GT IP first.
2. Keep `FL_EN_G=false` legacy behavior bit-for-bit as much as practical.
3. Add the FL ports and generics through the core hierarchy in a narrow, mechanical pass.
4. Implement TX/RX FL state machines in `Pgp4TxProtocol` and `Pgp4RxProtocol`.
5. Add tests that prove deterministic cycle counts at the protocol boundary before touching GT wrappers.
6. Only after protocol simulation passes, create a separate fixed-latency GTY profile/wrapper.
7. Treat FEC as part of the fixed-latency phase problem, not just a status feature.
8. For the example trigger-primitive prototype, target:

```vhdl
FL_EN_G         => true
FL_WORDS_G      => 8
FL_GAP_WORDS_G  => 1
SKIP_EN_G       => false
PGP_FEC_ENABLE_G => true
```

with:

```text
PGP word clock = 371.428571 MHz
GT line rate   = 24.514286 Gbps
payload        = 64 bytes/event on one lane
event rate     = 37.142857 MHz
```

9. Document measured fixed latency in both PGP word clocks and FC clocks once known.
10. Do not claim fixed latency until reset/power-cycle measurements show no phase variation.
