# Serialized DDR ADC Migration Guide

## Scope

This guide covers the coordinated migrations required by removal of:

- the old 7-Series `Ad9681Readout` RTL and its corresponding PyRogue map;
- the transitional `Ad9681Readout2` development name;
- `Ad9249ReadoutGroup2` RTL and its PyRogue map.

The replacements use the normalized `AdcDdr` register map. They are
not register-compatible aliases. Update RTL, AXI-Lite address allocation,
PyRogue construction, command paths, constraints, and characterized delay
values together.

These downstream migrations are expected after the SURF release containing the
AdcDdr-based interfaces. A consumer that still uses a removed interface must stay
pinned to its previous SURF revision until its firmware and software are
migrated together.

The permanently retained 7-Series and UltraScale `Ad9249ReadoutGroup`
interfaces are unaffected. Projects choosing to move those widely deployed
legacy interfaces to the AdcDdr-based readout should use the dedicated
[AD9249 readout migration guide](../ad9249/README.md).

## Common Integration Changes

Each AdcDdr readout region occupies `0x1000` bytes. Its normalized registers
extend through the pattern-tester window beginning at `0x800`. Do not retain an
old `0x100`-byte AXI-Lite slot or place the next endpoint inside this window.

AdcDdr-based wrappers add two target-facing inputs:

- `idelayCtrlRdy` reports that the target-owned input-delay controller is ready
  and defaults low. Drive the real ready indication in 7-Series hardware. The
  UltraScale/UltraScale+ PHY ignores this input.
- `adcStreamRst` resets the coherent stream-domain FIFO and output state. Drive
  the reset synchronous to `adcStreamClk` according to the target reset plan.

The target must also provide an `IDELAYCTRL` with an `IODELAY_GROUP` matching
`IODELAY_GROUP_G` where the selected FPGA family requires it. Source-synchronous
pin and timing constraints remain target-owned; update the project's top-level
XDC for its actual pinout, ADC mode, DCO frequency, datasheet timing, PCB skew,
and clocking hierarchy.

If `IDELAYCTRL.RDY` deasserts after startup, the readout holds its PHY in reset,
clears alignment, stops sample writes, aborts an outstanding snapshot with
`SLVERR`, and waits for readiness to return before reloading every retained
delay. The target must reset `IDELAYCTRL` after its reference clock is stable;
the readout intentionally does not generate the target-owned controller reset.

The normalized stream contract is:

- one fixed two-byte transfer per logical channel and sample epoch;
- `tDest` equals the logical channel number;
- `tUser(0)` is asserted when the sample was captured while FCO alignment was
  not locked;
- `tLast` remains deasserted;
- a stopped or slow stream clock can cause coherent group drops, reported by
  `AnyOverflow` and `OverflowCount`; asserting `adcStreamRst` instead flushes
  any samples queued in the stream-domain FIFO.

AXI-Lite state is owned in the ADC capture domain. Do not access a readout while
its selected DCO is absent.

## warm-tdm: AD9681

### RTL entity and generics

The entity remains `surf.Ad9681Readout`, but it now refers to the family-neutral
wrapper in `ad9681/core/Ad9681Readout.vhd`.

| Old generic | Replacement |
|---|---|
| `TPD_G` | `TPD_G` |
| `SIMULATION_G` | Remove; simulation selection belongs to the build/PHY environment. |
| `IODELAY_GROUP_G` | `IODELAY_GROUP_G` |
| `IDELAYCTRL_FREQ_G` | `IDELAYCTRL_FREQ_G` |
| `DEFAULT_DELAY_G` | Expand into all entries of `DATA_DELAY_INIT_G` and `FCO_DELAY_INIT_G`, then characterize independently. |
| `INVERT_G` | No blind one-to-one mapping. Use `ADC_INVERT_CH_G` for physical P/N lane inversion and `OFFSET_BINARY_G` for ADC numeric coding. |
| `NEGATE_G` | `NEGATE_G` |

Set these new generics deliberately:

- `DEVICE_FAMILY_G => "7SERIES"` for the current warm-tdm 7-Series target;
- `CAPTURE_DCLK_IDX_G => 0` to preserve the old DCLK0 single-domain behavior,
  or `1` only after separately validating DCLK1;
- `PATTERN_CHECK_G => true` when hardware-assisted calibration is desired;
- `LEFT_JUSTIFY_G => true` to preserve warm-tdm's previous sample placement in
  stream bits `[15:2]`.

The old shared delay for half `i` affected its FCO and all eight data lanes.
For an initial like-for-like conversion, copy it to:

```vhdl
DATA_DELAY_INIT_G => (
   15 downto 8 => OLD_DELAY_1_C,
   7 downto 0  => OLD_DELAY_0_C),
FCO_DELAY_INIT_G => (
   1 => OLD_DELAY_1_C,
   0 => OLD_DELAY_0_C),
```

Then replace those seed values with per-lane calibration results. Physical
data lane `(8*half)+channel` maps to `DATA_DELAY_INIT_G((8*half)+channel)`.

Add the new ports to the instantiation:

```vhdl
idelayCtrlRdy => adcIdelayCtrlRdy, -- [in]
adcStreamRst  => adcStreamRst,     -- [in]
```

All existing AXI-Lite, `adcClkRst`, `adcSerial`, `adcStreamClk`, and
eight-channel `adcStreams` connections retain their roles.

### PyRogue and scripts

Continue constructing `surf.devices.analog_devices.Ad9681Readout`, but replace
the old `fpga` and `channels` arguments with the RTL device-family selection:

```python
self.add(surf.devices.analog_devices.Ad9681Readout(
    name         = 'Ad9681Readout',
    offset       = 0x00000000,
    deviceFamily = '7SERIES',
    enabled      = True))
```

The RTL and PyRogue models derive a five-bit delay value for `7SERIES` and a
nine-bit delay value for `ULTRASCALE` or `ULTRASCALE_PLUS`.

Update script paths as follows:

| Removed node or command | AdcDdr node or command |
|---|---|
| `Delay[i]` | `FcoDelay[i]` plus `DataDelay[(8*i)+ch]` for channels `0..7` |
| `EnUsrDelay` | Remove; programmed delays are always authoritative after startup. |
| `Relock()` | `Relock()` |
| `LostLockCountReset()` | `ClearCounters()` |
| `Locked[i]` | bit `i` of `LockedMask`; use `AllLocked` for the aggregate condition |
| `LostLockCount[i]` | `LostLockCount[i]` |
| `AdcFrameSync[i]` | `FcoWord[i]` |
| `AdcChannel[ch]` | call `Snapshot()`, then read the four coherent values in `DebugSample[ch]` |
| `AdcVoltage[ch]` | call `Snapshot()`, then use `DebugVoltage[ch]` for the oldest captured sample after configuring its range/format |
| `FreezeDebug` | Remove; `Snapshot()` publishes one atomic four-sample bank. |
| `Invert`, `Negate` | Set the corresponding compile-time wrapper semantics and ADC output format; there are no runtime normalized-map equivalents. |
| `ErrorDetCount[i]` | No direct equivalent; use `LostLockCount[i]`, lock state, and calibration/pattern-test diagnostics. |

In warm-tdm initialization, the existing `Relock()` call can remain and the
immediately following `LostLockCountReset()` call should become
`ClearCounters()`.

### AD9681 validation

Before accepting the migration:

1. Confirm the AXI crossbar reserves at least `0x1000` bytes.
2. Elaborate the target with exactly one `Ad9681Readout` entity declaration.
3. Check `idelayCtrlRdy`, DCLK selection, generated clocks, CDC, and both
   source-synchronous input halves in Vivado reports.
4. Verify stream samples remain left-justified and preserve channel ordering.
5. Run full calibration, save per-lane/FCO centers, then run verify-current.
6. Exercise relock, counter clear, stopped-DCO diagnostics, and overflow status.

## ldmx-firmware: AD9249

### RTL entity and generics

Replace each one-bank `surf.Ad9249ReadoutGroup2` instantiation with
`surf.Ad9249ReadoutBank`. Do not use full `Ad9249Readout` unless one integration
owns both independent DCO/FCO banks and can allocate its `0x2000`-byte,
two-region map.

| Group2 generic | AdcDdr bank replacement |
|---|---|
| `TPD_G` | `TPD_G` |
| `SIM_DEVICE_G` | `DEVICE_FAMILY_G`; use `"ULTRASCALE_PLUS"` for the current tracker target |
| `NUM_CHANNELS_G` | `NUM_CHANNELS_G` |
| `SIMULATION_G` | Remove; simulation selection belongs to the build/PHY environment. |
| `DEFAULT_DELAY_G` | Expand into every active `DATA_DELAY_INIT_G` entry and `FCO_DELAY_INIT_G(0)`. |
| `ADC_INVERT_CH_G` | `ADC_INVERT_CH_G` |

The selected `DEVICE_FAMILY_G` also selects the native delay width. Provide
`IODELAY_GROUP_G`/`IDELAYCTRL_FREQ_G`, and decide `OFFSET_BINARY_G`,
`NEGATE_G`, and `PATTERN_CHECK_G` explicitly.

For a like-for-like starting point from the old common delay:

```vhdl
DATA_DELAY_INIT_G => (others => DEFAULT_DELAY_TAPS_C),
FCO_DELAY_INIT_G  => (0 => DEFAULT_DELAY_TAPS_C),
```

Declare `DEFAULT_DELAY_TAPS_C` as a `natural` when converting the old
`slv(8 downto 0)` generic value. The readout checks that each natural tap count
fits the five- or nine-bit width selected by `DEVICE_FAMILY_G`. Characterized
per-lane values should replace the replicated seed after calibration.

Add `idelayCtrlRdy` and `adcStreamRst` connections as described above. The
`Ad9249SerialGroupType`, AXI-Lite ports, stream clock, and per-channel stream
array retain their roles. AD9249 samples remain right-justified in
stream bits `[13:0]`, matching Group2's placement.

### PyRogue and address layout

Replace:

```python
surf.devices.analog_devices.Ad9249ReadoutGroup2(...)
```

with:

```python
surf.devices.analog_devices.Ad9249ReadoutBank(
    name         = f'Ad9249Readout[{i}]',
    offset       = i * 0x1000,
    deviceFamily = 'ULTRASCALE_PLUS',
    enabled      = True)
```

The old tracker code used `i*0x100`; that stride must become at least
`i*0x1000`, and the containing AXI crossbar must expose the same expanded
windows.

Update nodes and commands as follows:

| Group2 node or command | AdcDdr bank node or command |
|---|---|
| `Delay` | `FcoDelay[0]` and each active `DataDelay[ch]` |
| `Relock()` | `Relock()` |
| `LostLockCountReset()` | `ClearCounters()` |
| `Locked` | `AllLocked` or bit 0 of `LockedMask` |
| `LostLockCount` | `LostLockCount[0]` |
| `AdcFrameSync` | `FcoWord[0]` |
| `AdcChannel[ch]` | call `Snapshot()`, then read `DebugSample[ch]` |
| `AdcVoltage[ch]` | call `Snapshot()`, then read `DebugVoltage[ch]` for the oldest captured sample |
| `FreezeDebug` | Remove; use atomic `Snapshot()`. |
| `Invert` | Configure `ADC_INVERT_CH_G`, `OFFSET_BINARY_G`, and the ADC output format deliberately. |
| `ErrorDetCount` | No direct equivalent; use `LostLockCount[0]` and pattern/calibration diagnostics. |

### AD9249 validation

Before accepting the LDMX migration:

1. Confirm every bank receives a non-overlapping `0x1000` AXI-Lite window.
2. Confirm each physical bank still uses its own DCO/FCO capture domain.
3. Elaborate the UltraScale+ target and review delay-controller, clock, CDC,
   and input timing reports.
4. Verify sample channel order, right justification, `tDest`, and unlock marking.
5. Run full calibration per bank, save independent FCO/data centers, then run
   verify-current.
6. Exercise relock, counter clear, overflow, and stopped-clock diagnostics.

## Removed and Retained Interfaces

After this coordinated change, SURF no longer supplies
`Ad9249ReadoutGroup2`, `Ad9681Readout2`, or `Ad9681ReadoutManual`. The old
AD9681 7-Series implementation has been replaced by the family-neutral
`Ad9681Readout`.

The existing 7-Series and UltraScale `Ad9249ReadoutGroup` RTL entities and
matching PyRogue class remain supported and unchanged. The public
names are final; no additional readout rename is planned as part of this work.
