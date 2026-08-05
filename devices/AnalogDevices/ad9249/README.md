# AD9249 Readout Migration Guide

## Purpose

This guide explains how to move a downstream design from the retained legacy
`Ad9249ReadoutGroup` RTL/PyRogue interface to the AdcDdr-based serialized-DDR ADC
readout. It is written for firmware and software repositories that consume SURF
as a submodule and may need to schedule the migration independently.

The legacy implementation is not removed by this migration effort. Both
family-specific legacy RTL files and the matching PyRogue class remain available
for existing projects:

- [7-Series legacy RTL](7Series/rtl/Ad9249ReadoutGroup.vhd)
- [UltraScale legacy RTL](UltraScale/rtl/Ad9249ReadoutGroup.vhd)
- [legacy PyRogue map](../../../python/surf/devices/analog_devices/_Ad9249Legacy.py)

The replacements are:

- [Ad9249ReadoutBank](core/Ad9249ReadoutBank.vhd) for one independently clocked
  eight-channel DCO/FCO bank;
- [Ad9249Readout](core/Ad9249Readout.vhd) for a complete 16-channel ADC with two
  independent banks;
- `Ad9249ReadoutBank` and `Ad9249Readout` in the
  [PyRogue module](../../../python/surf/devices/analog_devices/_Ad9249.py);
- `Ad9249ReadoutBankCalibration` and `Ad9249ReadoutCalibration` for software
  eye calibration and verification.

This is not a drop-in entity rename. The register map, address-window size,
clock/reset boundary, stream behavior, and software operations change.

## Choose the Replacement

Use `Ad9249ReadoutBank` when the existing `Ad9249ReadoutGroup` represents one
physical DCO/FCO bank. This is the normal migration and preserves the existing
one-bank integration boundary.

Use full `Ad9249Readout` only when one module owns both physical banks and can
provide:

- both `Ad9249SerialGroupType` records;
- one `0x2000`-byte AXI-Lite device window;
- separate initial data/FCO delays and `IODELAY_GROUP` values for each bank;
- one common stream clock/reset for all 16 logical channel streams.

The full wrapper places bank 0 at offset `0x0000`, bank 1 at `0x1000`, and maps
stream destinations to `0..15`. Two separate `Ad9249ReadoutBank` instances are
equally valid when banks belong to different modules, AXI crossbars, resets, or
software devices.

## Migration Gates

Review these conditions before editing the instantiation. A project that hits a
gate should retain the legacy wrapper until the required target or SURF support
is designed and validated.

| Legacy behavior | AdcDdr behavior | Required decision |
|---|---|---|
| `NUM_CHANNELS_G` may be `1..8`. | RTL bank supports `1..8`, but the typed `Ad9249ReadoutBank` PyRogue model and calibration adapter currently describe eight channels. | Eight-channel banks migrate directly. For reduced-channel software, retain legacy support or add and test a matching typed model before migration. |
| UltraScale `USE_MMCME_G=false` accepts shared external bit/divided clocks and resets. | The AdcDdr PHY derives its capture clocks internally from the bank DCO and has no external-clock ports. | Confirm per-bank clock-resource use is acceptable. If shared external clocking is required, retain legacy support or extend the AdcDdr PHY boundary first. |
| UltraScale `adcReady[ch]` can stall each channel FIFO independently. | AdcDdr output has no ready input and crosses all channels coherently through one wide FIFO. | Remove `adcReady` only when the consumer can accept every asserted `tValid`. Otherwise add an explicit downstream buffering/flow-control adapter. |
| Runtime `Invert` register complements every sample. | AdcDdr inversion/coding choices are compile-time generics or ADC configuration settings. | Replace runtime changes with a fixed `ADC_INVERT_CH_G`, `OFFSET_BINARY_G`, `NEGATE_G`, or ADC output-format policy. |
| Legacy AXI-Lite remains responsive from `axilClk` without DCO. | The normalized endpoint is crossed into the capture domain. | Do not access the readout while its DCO is absent. Sequence ADC clock startup before readout software access. |
| Legacy unlocked behavior differs by family. | AdcDdr output preserves cadence and marks unlocked samples with `tUser(0)`. | Consumers must inspect or intentionally ignore `tUser(0)`; do not assume the old all-ones or suppressed-valid behavior. |

## Firmware Migration

### Entity replacement

Replace:

```vhdl
U_AdcReadout : entity surf.Ad9249ReadoutGroup
```

with:

```vhdl
U_AdcReadout : entity surf.Ad9249ReadoutBank
```

`Ad9249ReadoutBank` is family-neutral. `DEVICE_FAMILY_G` selects exactly one
PHY implementation and its native delay width:

| Target | `DEVICE_FAMILY_G` | Delay bits |
|---|---|---:|
| 7-Series | `"7SERIES"` | `5` |
| UltraScale | `"ULTRASCALE"` | `9` |
| UltraScale+ | `"ULTRASCALE_PLUS"` | `9` |

The legacy Python `fpga` choice exposed six or ten bits because its register
definition included the adjacent legacy load-control bit. AdcDdr delay
values contain only the physical tap count. RTL and software derive five bits
for 7-Series and nine bits for UltraScale/UltraScale+ from the family.

### Generic mapping

| Legacy generic | AdcDdr bank generic | Migration |
|---|---|---|
| `TPD_G` | `TPD_G` | Copy unchanged. |
| `NUM_CHANNELS_G` | `NUM_CHANNELS_G` | Copy for RTL; review the reduced-channel software gate above. |
| none | `AXIL_BASE_ADDR_G` | Set to the absolute base address visible on the incoming AXI-Lite master. |
| none | `DEVICE_FAMILY_G` | Select `7SERIES`, `ULTRASCALE`, or `ULTRASCALE_PLUS`. |
| `IODELAY_GROUP_G` | `IODELAY_GROUP_G` | Copy, then verify the target constraints and controller ownership. |
| `IDELAYCTRL_FREQ_G` | `IDELAYCTRL_FREQ_G` | Copy for 7-Series; it describes the target-owned `IDELAYCTRL` reference clock. |
| `DEFAULT_DELAY_G` | `DATA_DELAY_INIT_G`, `FCO_DELAY_INIT_G` | Expand the common legacy default into independent numeric tap values. |
| `ADC_INVERT_CH_G` | `ADC_INVERT_CH_G` | Copy the active channel bits. |
| none | `PATTERN_CHECK_G` | Enable to include hardware-assisted bounded pattern measurements. |
| legacy runtime `Invert` | `OFFSET_BINARY_G`, `NEGATE_G`, or `ADC_INVERT_CH_G` | Choose fixed numeric/polarity behavior deliberately; there is no runtime register equivalent. |

UltraScale-only legacy generics do not have direct AdcDdr equivalents:

| UltraScale legacy generic | AdcDdr handling |
|---|---|
| `SIM_DEVICE_G` | Replace with `DEVICE_FAMILY_G`. |
| `D_DELAY_CASCADE_G`, `F_DELAY_CASCADE_G` | No wrapper-level equivalent; the AdcDdr PHY delay topology is fixed. Revalidate timing/range. |
| `USE_MMCME_G` | Removed; the AdcDdr PHY owns DCO-derived capture clocking. |
| `SIM_SPEEDUP_G` | Removed; simulation selection belongs to the selected PHY/build environment. |

### Initial delay conversion

The legacy wrapper already has independent runtime data and frame delays, but
only one scalar compile-time default. `Ad9249ReadoutBank` has an independent
compile-time value for every data lane and FCO lane.

For an initial, behavior-preserving seed:

```vhdl
constant LEGACY_DELAY_TAPS_C : natural := 12;

constant ADC_DATA_DELAY_INIT_C : NaturalArray(NUM_CHANNELS_C-1 downto 0) :=
   (others => LEGACY_DELAY_TAPS_C);

constant ADC_FCO_DELAY_INIT_C : NaturalArray(0 downto 0) :=
   (0 => LEGACY_DELAY_TAPS_C);
```

Replace the replicated seed with characterized per-lane values after running
AdcDdr calibration. Each array value must fit the width selected by
`DEVICE_FAMILY_G`; elaboration asserts otherwise.

If the old software saved `ChannelDelay[ch]` and `FrameDelay`, copy those actual
tap values—not the legacy Python field width—into `DATA_DELAY_INIT_G(ch)` and
`FCO_DELAY_INIT_G(0)`.

### Port mapping

The following ports retain their roles:

- `axilClk`, `axilRst`, and all four AXI-Lite records;
- `adcClkRst`;
- `adcSerial : Ad9249SerialGroupType`;
- `adcStreamClk`;
- `adcStreams` with the active logical channel range.

AdcDdr bank integration adds:

```vhdl
idelayCtrlRdy => adcIdelayCtrlRdy, -- [in]
adcStreamRst  => adcStreamRst,     -- [in]
```

For 7-Series, instantiate or reuse a target-owned `IDELAYCTRL`, match its
`IODELAY_GROUP` to `IODELAY_GROUP_G`, constrain its reference clock at
`IDELAYCTRL_FREQ_G`, and connect `RDY` to `idelayCtrlRdy`. Do not tie readiness
high merely to bypass startup sequencing in hardware.

UltraScale/UltraScale+ uses `IDELAYE3` count mode and does not use
`IDELAYCTRL`; tie `idelayCtrlRdy` high explicitly or accept its default.

`adcStreamRst` resets the coherent stream-domain FIFO/output state and must be
valid in the `adcStreamClk` domain.

Remove the UltraScale legacy ports `adcBitClkIn`, `adcBitClkDiv4In`,
`adcBitRstIn`, `adcBitRstDiv4In`, and `adcReady`. Before doing so, resolve the
shared-clock and backpressure migration gates described above.

### One-bank example

```vhdl
U_AdcReadout : entity surf.Ad9249ReadoutBank
   generic map (
      TPD_G             => TPD_G,
      AXIL_BASE_ADDR_G  => ADC_READOUT_BASE_ADDR_C,
      NUM_CHANNELS_G    => 8,
      DEVICE_FAMILY_G   => ADC_DEVICE_FAMILY_C,
      IODELAY_GROUP_G   => "ADC_BANK_0",
      IDELAYCTRL_FREQ_G => 200.0,
      DATA_DELAY_INIT_G => ADC_DATA_DELAY_INIT_C,
      FCO_DELAY_INIT_G  => ADC_FCO_DELAY_INIT_C,
      ADC_INVERT_CH_G   => ADC_INVERT_CH_C,
      PATTERN_CHECK_G   => true,
      OFFSET_BINARY_G   => false,
      NEGATE_G          => false)
   port map (
      axilClk         => axilClk, -- [in]
      axilRst         => axilRst, -- [in]
      axilWriteMaster => adcWriteMaster, -- [in]
      axilWriteSlave  => adcWriteSlave, -- [out]
      axilReadMaster  => adcReadMaster, -- [in]
      axilReadSlave   => adcReadSlave, -- [out]
      adcClkRst       => adcClkRst, -- [in]
      idelayCtrlRdy   => adcIdelayCtrlRdy, -- [in]
      adcSerial       => adcSerial, -- [in]
      adcStreamClk    => adcStreamClk, -- [in]
      adcStreamRst    => adcStreamRst, -- [in]
      adcStreams      => adcStreams); -- [out]
```

Set `ADC_DELAY_BITS_C` and `ADC_DEVICE_FAMILY_C` from the target family table;
do not infer them from the old PyRogue `fpga` field width.

### Full-device example boundary

`Ad9249Readout` has two fixed eight-channel banks. Its important differences
from one bank are:

- `adcSerial` is `Ad9249SerialGroupArray(1 downto 0)`;
- `idelayCtrlRdy` is a two-bit vector;
- `IODELAY_GROUP_0_G` and `IODELAY_GROUP_1_G` are independent;
- `DATA_DELAY_INIT_G(7 downto 0)` belongs to bank 0 and
  `(15 downto 8)` belongs to bank 1;
- `FCO_DELAY_INIT_G(0)` and `(1)` belong to banks 0 and 1;
- AXI offsets are `0x0000` and `0x1000` relative to `AXIL_BASE_ADDR_G`;
- output streams/destinations are channels `0..7` for bank 0 and `8..15` for
  bank 1.

Do not wrap two existing one-bank AXI regions with full `Ad9249Readout` unless
the surrounding crossbar and Python hierarchy are changed to the single
`0x2000`-byte device layout at the same time.

## AXI-Lite Register Migration

One legacy bank typically fits inside a small `0x100`-byte region. One
AdcDdr bank requires a non-overlapping `0x1000`-byte region because the
normalized map includes delay, counter, debug snapshot, and pattern-test
windows. Expand both the firmware crossbar allocation and the PyRogue stride.

| Legacy offset/path | AdcDdr offset/path | Notes |
|---|---|---|
| `0x00+4*ch`, `ChannelDelay[ch]` | `0x100+4*ch`, `DataDelay[ch]` | Same physical data-lane tap concept; AdcDdr readback is the retained programmed setting. |
| `0x20`, `FrameDelay` | `0x200`, `FcoDelay[0]` | Same physical FCO tap concept. |
| `0x30[15:0]`, `LostLockCount` | `0x340`, `LostLockCount[0]` | The AdcDdr counter is 32-bit saturating. |
| `0x30[16]`, `Locked` | `0x020[0]`, `LockedMask`; `0x01C[2]`, `AllLocked` | Use the mask for per-FCO state or aggregate status for startup. |
| `0x34`, `AdcFrame` | `0x300`, `FcoWord[0]` | Most recent deserialized FCO word. |
| `0x38`, `LostLockCountReset()` | `0x018`, `ClearCounters()` | Also clears overflow count/sticky overflow. |
| `0x40`, `Invert` | no runtime register | Select compile-time wrapper/ADC coding behavior. |
| `0x80+4*ch`, `AdcChannel[ch]` | `0x600+0x10*ch`, four `DebugSample` words | Legacy packs two rolling samples; AdcDdr publishes four coherent samples after `Snapshot()`. |
| `0xA0`, `FreezeDebug` | `0x014`, `Snapshot()` | Snapshot is explicit, atomic across every channel, and blocking. |

AdcDdr-specific controls/status include:

- `Version`, geometry, delay-width, and pattern-check capabilities;
- `CaptureReset` and explicit `Relock`;
- `DelayReady`, `AllLocked`, and `AnyOverflow`;
- `SnapshotSequence`;
- `OverflowCount`;
- optional `PatternTester` configuration and result windows.

Unmapped AdcDdr accesses return `DECERR`. Do not retain hard-coded legacy
offsets in C++, Python, YAML-generated maps, notebooks, or command scripts.

## Stream Behavior Migration

Payload placement remains compatible: the 14-bit ADC code is right-justified
in `tData(13 downto 0)` and bits `15:14` are zero during locked, normal
operation. `tDest` remains the logical channel number.

The following timing-visible behavior changes:

- AdcDdr capture moves all active channels through one wide asynchronous
  FIFO, preserving channel coherence for each sample epoch.
- AdcDdr output has no ready/backpressure input. A full internal FIFO drops
  the newest complete channel group, sets `AnyOverflow`, and increments
  `OverflowCount`; it does not stall the ADC.
- AdcDdr output does not suppress cadence when FCO alignment is lost.
  `tUser(0)` marks affected samples.
- `tLast` remains deasserted; this is not SSI framing.
- `adcStreamRst` explicitly resets the stream crossing.

Legacy 7-Series emits all-ones data while unlocked. Legacy UltraScale
suppresses channel `tValid` while unlocked and can independently stall channels
with `adcReady`. Any consumer depending on either behavior must be updated to
use `tValid`, `tUser(0)`, and overflow status deliberately.

## PyRogue Migration

### One bank

Replace:

```python
self.add(surf.devices.analog_devices.Ad9249ReadoutGroup(
    name     = 'Ad9249Readout',
    offset   = ADC_READOUT_OFFSET,
    fpga     = '7series',
    channels = 8))
```

with:

```python
self.add(surf.devices.analog_devices.Ad9249ReadoutBank(
    name         = 'Ad9249Readout',
    offset       = ADC_READOUT_OFFSET,
    deviceFamily = '7SERIES'))
```

Use `deviceFamily='ULTRASCALE'` or `'ULTRASCALE_PLUS'` for those FPGA families.
The Python and RTL models derive the same native delay width from this value.

Ensure the next device offset is at least `ADC_READOUT_OFFSET + 0x1000`. If
several banks are created in a loop, change any legacy `0x100` stride to
`0x1000` or larger.

### Full device

For the full RTL wrapper:

```python
self.add(surf.devices.analog_devices.Ad9249Readout(
    name         = 'Ad9249Readout',
    offset       = ADC_READOUT_OFFSET,
    deviceFamily = ADC_DEVICE_FAMILY))
```

Software then accesses `Ad9249Readout.Bank[0]` and `.Bank[1]`, matching RTL
offsets `0x0000` and `0x1000` inside the device.

### Operational path mapping

| Legacy software | AdcDdr software |
|---|---|
| `ChannelDelay[ch]` | `DataDelay[ch]` |
| `FrameDelay` | `FcoDelay[0]` |
| `Locked` | `AllLocked` or `LockedMask & 0x1` |
| `LostLockCount` | `LostLockCount[0]` |
| `LostLockCountReset()` | `ClearCounters()` |
| `AdcFrame` | `FcoWord[0]` |
| background/explicit `AdcChannel[ch]` read | call `Snapshot()`, then read `DebugSample[ch]` or the raw `DebugSampleRaw` array |
| `FreezeDebug` | remove; `Snapshot()` owns atomic publication |
| `Invert` | no runtime path; use the selected RTL/ADC coding policy |

`Snapshot()` holds its AXI-Lite write response until four valid coherent sample
groups are captured. It can return `SLVERR` during reset/startup and cannot
complete without a running DCO and valid samples. Do not call it from a generic
startup `ReadAll` path.

## Calibration Integration

AdcDdr calibration uses the ADC checkerboard pattern to measure FCO and
every data-lane eye independently, performs full-channel qualification, and can
verify the selected settings at startup.

For one bank:

```python
readout = surf.devices.analog_devices.Ad9249ReadoutBank(
    name         = 'Ad9249Readout',
    offset       = ADC_READOUT_OFFSET,
    deviceFamily = ADC_DEVICE_FAMILY)
self.add(readout)

calibration = surf.devices.analog_devices.Ad9249ReadoutBankCalibration(
    name    = 'Ad9249Calibration',
    config  = self.Ad9249Config.BankConfig[0],
    readout = readout)
self.add(calibration)
```

For full-device RTL/Python, use `Ad9249ReadoutCalibration` with the complete
`Ad9249Config` and `Ad9249Readout`; it creates `Bank[0]` and `Bank[1]`
calibration processes.

Recommended bring-up flow:

1. Configure the ADC output format and enable its DCO/FCO/data outputs.
2. Wait for target resets and 7-Series `IDELAYCTRL.RDY` where applicable.
3. Read `Version`, geometry, `DelayBits`, and `DelayReady`; verify they match
   the software/target configuration.
4. Run full calibration per bank with the complete delay range.
5. Review every FCO/data eye, selected tap, and left/right margin.
6. Copy stable characterized centers into `DATA_DELAY_INIT_G` and
   `FCO_DELAY_INIT_G` for that board/target.
7. On later startups, run verify-current or guard-band verification rather than
   assuming a successful lock bit proves adequate margin.

Calibration is disruptive: it changes ADC test mode, delay taps, and alignment
while running. Schedule it before normal data taking and prevent concurrent
readout-control access.

The shared [adcDdr README](../adcDdr/README.md) documents calibration controls,
measurement backends, results, cleanup behavior, and limitations.

## Constraints and Timing

Keep the AD9249 constraints in the board target's top-level XDC. Update its pin
queries and timing values using the selected ADC mode, datasheet `tCO`, PCB
flight times, board skew, DCO frequency, and actual target hierarchy.

For a complete ADC, apply the bank constraint independently to both DCO/FCO/data
groups. Calibration does not replace `create_clock`, DDR rise/fall input delays,
clock-placement review, or min/max timing analysis.

At minimum, inspect:

```tcl
report_clocks
check_timing -verbose
report_timing -from [get_ports <adc-data-and-fco-ports>] -max_paths 50
report_timing -from [get_ports <adc-data-and-fco-ports>] -delay_type min -max_paths 50
report_methodology
report_cdc -details
```

Correlate implemented timing margin with measured eyes. Do not treat a wide
simulation or hardware eye as evidence that an unconstrained path is safe.

## Suggested Repository Migration Sequence

For firmware maintained outside the SURF repository:

1. **Pin the current working revision.** Record the existing SURF commit,
   target, FPGA part, ADC mode, delay settings, and known-good bitstream.
2. **Inventory dependencies.** Search RTL, Python, generated maps, scripts,
   YAML, notebooks, and constraints for legacy entity names and register paths.
3. **Evaluate migration gates.** Resolve reduced channels, external UltraScale
   clocks, `adcReady`, runtime inversion, and DCO startup ordering first.
4. **Expand address windows.** Reserve `0x1000` per bank or `0x2000` per full
   ADC in RTL and software before replacing register paths.
5. **Replace RTL and constraints.** Add stream reset and delay readiness,
   select the PHY family, and seed initial delays.
6. **Replace PyRogue and scripts.** Update constructor arguments, paths,
   snapshot use, counter clear, status, and calibration.
7. **Compile and simulate.** Check source selection, entity uniqueness, reset,
   lock/relock, channel order, `tUser(0)`, overflow, and stopped-clock behavior.
8. **Implement and review timing.** Check clocks, placement, min/max input
   timing, CDC, and constraints for every bank.
9. **Validate on hardware.** Compare samples with the known-good revision, run
   calibration, power-cycle, and verify repeatability before deployment.
10. **Keep rollback available.** Do not remove the known-good SURF pin or saved
    delay configuration until production validation is complete.

Useful initial searches include:

```bash
rg -n 'Ad9249ReadoutGroup|ChannelDelay|FrameDelay|LostLockCountReset|FreezeDebug'
rg -n 'USE_MMCME_G|adcBitClkIn|adcBitClkDiv4In|adcReady'
rg -n '0x20|0x30|0x34|0x38|0x40|0x80|0xA0' <register-map-and-script-paths>
```

## Validation Checklist

Do not consider the migration complete until the applicable checks pass.

### Build and static checks

- Exactly one family implementation of `AdcDdrPhy` is loaded.
- `DEVICE_FAMILY_G` names a supported FPGA family and selects the expected delay width.
- Every bank has a non-overlapping `0x1000` AXI-Lite window.
- RTL `AXIL_BASE_ADDR_G` matches the address observed by the endpoint.
- PyRogue `deviceFamily` matches RTL `DEVICE_FAMILY_G`.
- All DCO, FCO, and data input paths are constrained for rising and falling
  capture edges.
- 7-Series `IODELAY_GROUP` and `IDELAYCTRL.RDY` are correctly connected.
- Clock, methodology, CDC, and min/max timing reports have no unexplained ADC
  paths or broad false-path exceptions.

### Functional simulation

- Reset and startup work with unrelated AXI, capture, and stream clocks.
- FCO locks from every bitslip phase and relocks after injected errors.
- Data/FCO delay writes affect exactly the requested lane and read back the
  programmed setting.
- Channel numbering, `tDest`, right-justified sample bits, and physical lane
  inversion match the old design.
- Unlocked samples assert `tUser(0)` and do not masquerade as valid aligned
  data.
- Stream reset and overflow behavior are checked with the stream clock stopped
  or slowed.
- Four-sample snapshots are coherent across every channel.

### Hardware

- Device identity/configuration and output coding are verified before capture.
- All FCO and data lanes produce bounded eyes with acceptable guard bands.
- Selected taps remain valid after relock and power cycle.
- Stream samples match an independent stimulus/reference for every channel.
- Lost-lock recovery, counter clearing, stopped-DCO behavior, and overflow
  diagnostics work as documented.
- Representative voltage/temperature conditions are checked when required by
  the application.

## Compatibility Summary

The public legacy class remains available as
`surf.devices.analog_devices.Ad9249ReadoutGroup`, and the legacy RTL remains in
its family directories. Projects do not need to migrate merely because they
update other SURF modules.

Projects that do migrate should switch firmware, address allocation, PyRogue,
scripts, constraints, and characterized delay settings as one reviewed change.
Mixing the legacy software map with AdcDdr RTL, or AdcDdr software with
legacy RTL, is unsupported and will access the wrong registers.
