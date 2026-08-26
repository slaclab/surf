# Serialized DDR ADC Readout

`adcDdr` is the device-neutral receive and monitoring layer for Analog Devices
ADCs that send source-synchronous serialized DDR data with a forwarded data
clock (DCO) and frame clock (FCO). AD9249, AD9252, and AD9681 provide the
part-specific physical-lane topology around this common layer.

## Layout

- [`rtl/AdcDdrPhy.vhd`](rtl/AdcDdrPhy.vhd) selects the FPGA-family input PHY.
- [`rtl/AdcDdrCore.vhd`](rtl/AdcDdrCore.vhd) owns FCO word alignment, delay
  controls, coherent samples, debug snapshots, counters, and the normalized
  AXI-Lite map.
- [`rtl/AdcDdrPatternTester.vhd`](rtl/AdcDdrPatternTester.vhd) optionally checks
  ADC test patterns in hardware over a bounded sample window.
- [`7Series/`](7Series/) and [`UltraScale/`](UltraScale/) contain the family
  implementations of the programmable input delays and deserializers.
- [`sim/`](sim/) contains simulation-only pattern helpers.
- [`migration-guide.md`](migration-guide.md) maps the removed AD9681 and
  AD9249 Group2 interfaces to their replacements.

The PyRogue register model is
[`_AdcDdr.py`](../../../python/surf/devices/analog_devices/_AdcDdr.py), and the
device-neutral software calibration process is
[`_AdcDdrCalibration.py`](../../../python/surf/devices/analog_devices/_AdcDdrCalibration.py).
Device adapters in `_Ad9249.py`, `_Ad9252.py`, and `_Ad9681.py` supply the
physical-lane mapping and ADC configuration behavior. Their configuration
devices expose the same `DigitalReset()` and `ResetPNLong()` commands for
direct use from PyRogue and for the common calibration sequence.

## Delay Controller Readiness

The `idelayCtrlRdy` input defaults low so an omitted 7-Series connection holds
the capture PHY safely in reset. A 7-Series target must instantiate or reuse an
`IDELAYCTRL`, match its `IODELAY_GROUP`, and connect the controller's `RDY`
output. UltraScale and UltraScale+ use `IDELAYE3` count mode; their selected PHY
does not use `idelayCtrlRdy`.

If readiness drops after startup, the common core clears frame alignment,
resets the deserializers, stops sample writes, and aborts an outstanding debug
snapshot with `SLVERR`. Programmed data and FCO delays remain retained. When
readiness returns, the core reloads every retained delay before releasing the
PHY and reacquiring alignment.

The target owns `IDELAYCTRL` reset generation because it also owns the reference
clock and knows when that clock is stable. If `RDY` deasserts, the target must
reset the controller according to the AMD primitive requirements; the common
readout does not generate that reset request.

## Calibration Model

Calibration finds a stable sampling point for every FCO and physical data lane.
It uses the ADC's alternating checkerboard test mode by default. For a 14-bit
sample the two expected logical values are `0x2AAA` and `0x1555`; their order is
not important during individual lane scans, but it is enforced during final
full-channel qualification.

The distinction between a physical lane and a logical channel matters. AD9249
and AD9252 use one physical data lane per channel. AD9681 uses two lanes per
channel: one contributes logical bits `[5:0]`, and the other contributes bits
`[13:6]`. The calibration adapter supplies a channel number and meaningful-bit
mask for every physical lane so each contribution can be measured separately.

### Full calibration algorithm

The `Full calibration` operation performs these phases:

1. **Preserve state.** Software reads the current ADC test mode and all FCO and
   data delay settings. These values can be restored after a stop or failure.
2. **Scan each FCO lane.** For every tap from `DelayStart` through `DelayStop`,
   inclusive, software programs that FCO delay, commands `Relock`, waits for
   `SettleTime`, and tests the corresponding `LockedMask` bit.
3. **Extract FCO eyes.** Consecutive passing taps form candidate eyes. An eye
   must be at least `MinimumEyeWidth` taps wide and must provide at least
   `GuardBand` passing taps on both sides of its selected center. For an
   even-width eye, the lower center tap is selected. When `CircularDelays` is
   enabled, passing runs at the two ends of the scan are merged. All qualifying
   FCO eyes are retained, ordered by widest eye and then lowest center tap; the
   first eye is the initial choice.
4. **Enable and synchronize the checkerboard pattern.** The ADC is placed in
   its device-specific test mode after the initial FCO delays have been selected
   and frame lock has been reacquired. Calibration then calls the configuration
   device's normalized `DigitalReset()` command, waits for the converter output
   to settle, and relocks the FPGA receiver. This establishes one deterministic
   sample epoch before any data eye is measured.
5. **Build safe data-lane sweep groups.** Lanes on different logical channels
   can move together. Lanes on the same channel can also move together when
   their meaningful-bit masks do not overlap. Lanes with overlapping masks are
   put in separate groups so a failure remains attributable to one physical
   lane. Consequently, all sixteen AD9681 lanes form one sweep group even
   though each pair contributes to the same logical channel.
6. **Scan each data group.** At a given tap, all lanes in the group are updated
   in one bulk transaction and then measured from the same settled sampling
   point. Ordered four-sample snapshots acquire phase independently per lane so
   one channel leaving its eye cannot truncate another channel's passing window.
   A per-lane verdict uses only its logical sample-bit mask, so an unaligned
   partner half does not contaminate it.
   Each lane gets its own passing map and centered eye even though compatible
   lanes are swept together.
7. **Qualify the assembled checkerboard samples.** With every data lane centered, software
   checks the complete sample width. Channel zero establishes the checkerboard
   A/B phase, and every logical channel must match the same ordered sequence.
   This catches half-word or sample-epoch errors that individual masked lane
   tests and a repetitive FCO word cannot detect.
8. **Run the optional deep checkerboard window.** When `UsePatternTester` is
   enabled, the hardware pattern tester checks `PatternTesterSamples` complete
   samples at line rate. Every channel must maintain one shared alternating
   phase, and every selected FCO word observed during the window must match.
   Per-channel word-error counts and accumulated bit-error masks, plus per-FCO
   error counts, are retained in the final result.
9. **Qualify PN23 coherence and recurrence.** When `VerifyPn23` is enabled,
   software switches the ADC to PN23, pulses the PN-long reset, and reads one
   atomic four-sample debug snapshot. All logical channels must contain the
   same four words. The reference channel's 56 captured bits must also satisfy
   the `x^23 + x^18 + 1` recurrence after the first 23 bits establish its
   arbitrary phase. This second condition rejects a common malformed sequence
   that channel equality alone would accept. The checker considers the ADC's
   possible sample-MSB format conversion and full output inversion; it does not
   require the snapshot to begin at the PN seed. When `UsePatternTester` is
   enabled, the selected transformation is then applied to a deep hardware
   window. The tester acquires an arbitrary nonzero 23-bit history, checks all
   subsequent reference bits against the recurrence, and verifies every other
   channel remains word-for-word coherent with the reference.
10. **Try alternate FCO windows if necessary.** More than one FCO eye can appear
   valid because the repetitive frame pattern may lock in equivalent-looking
   unit intervals. If the snapshot, deep checkerboard, or PN23 qualification fails,
   calibration tries the Cartesian product of the retained FCO eyes, relocking
   and restoring checkerboard mode before each attempt. Data delays are not
   rescanned because the FCO choice establishes frame/sample phase without
   changing the data-eye centers. The first combination that passes both final
   checks is retained.
11. **Publish or restore.** A successful full calibration restores the normal
   ADC output mode but leaves the qualified FCO and data delays installed. A
   stop, exception, or failed final qualification restores the original test
   mode and delays. `ApplyResults` can later reinstall only a complete result
   whose final qualification passed.

This is an eye-centering algorithm, not a bit-error-rate characterization. A
passing tap means every bounded measurement requested by `SampleCount` passed;
it does not prove an arbitrarily low error rate.

### Snapshot and deep measurements

Every data tap and the initial full-channel qualification use atomic debug
snapshots. One `SampleCount` unit requests one four-sample snapshot, and the
same coherent samples are reused for every lane mask in a sweep group. The
checker enforces an ordered pattern independently per lane instead of merely
requiring both checkerboard values to appear. The final assembled snapshot and
deep hardware window then require one shared phase across all channels.

`UsePatternTester` adds deep full-channel measurements after the centered
snapshots pass; it does not replace the tap-scan backend. It defaults to the
readout model's `patternCheck` construction parameter, which must match the RTL
`PATTERN_CHECK_G` generic, and remains user-writable. The bounded checker
in `AdcDdrPatternTester` evaluates `PatternTesterSamples` consecutive valid
samples without transferring them to software. Alternating mode uses one
reference channel for the complete channel group. PN23 mode checks the
reference recurrence from an arbitrary stream phase and checks every other
channel for coherence. Every selected FCO lane must also be observed and remain
error-free. The deep checker requires the `PatternCheck` capability.

### Verification operations

`Verify current` checks each installed FCO and data delay without retaining any
temporary changes. `Verify guard band` also checks the taps at `selected -
GuardBand` and `selected + GuardBand`. A requested guard point outside
`DelayStart` through `DelayStop` is a failure. Each lane is restored before the
next lane is tested because multiple physical lanes can contribute to one
logical sample; the complete original configuration is restored when the
verification operation ends.

## Calibration Controls

| Control | Default | Meaning |
|---|---:|---|
| `Operation` | `Full calibration` | Full scan, current-tap verification, or guard-band verification. |
| `DelayStart` | `0` | First delay tap included in a scan or allowed verification range. |
| `DelayStop` | Maximum tap | Last delay tap included in a scan or allowed verification range. |
| `MinimumEyeWidth` | `8` taps | Minimum physical passing-window width. |
| `GuardBand` | `2` taps | Required passing margin on each side of the selected center. |
| `CircularDelays` | `False` | Whether the first and last passing scan runs are one wrapped eye. |
| `SampleCount` | `2` | Number of four-sample measurement groups checked at each data tap. |
| `UsePatternTester` | `patternCheck` | Add deep hardware checkerboard and, when enabled, PN23 qualification after centering. |
| `PatternTesterSamples` | `4096` | Valid samples checked by each deep hardware window. |
| `VerifyPn23` | Device dependent | Enable PN23 coherence and recurrence qualification when the adapter provides a PN-long reset control. |
| `SettleTime` | `1 ms` | Wall-clock wait after delay, relock, or ADC test-mode changes. |
| `Debug` | `True` | Retain detailed per-tap diagnostics and publish one completed tree when the operation ends. |

The full delay range is the safest initial scan. Narrow `DelayStart` and
`DelayStop` only when the board has a characterized region and the entire
expected eye, including failing boundary taps, remains visible. An eye touching
a scan boundary is reported as unbounded on that side unless circular scanning
merges it with the opposite boundary.

Delay controls are reported in native `tap` units. A tap is not the same
physical interval on every FPGA family. In particular, the UltraScale PHY uses
`IDELAYE3` in uncalibrated `COUNT` mode, so software must not present those tap
counts as a portable time value. ADC sample rate describes the unit interval
but is not sufficient to convert an uncalibrated count into picoseconds.

## Results and Diagnostics

`Results` contains the selected eye, complete passing map, and margins for each
FCO and data lane. FCO entries also contain every retained candidate eye. The
`Final` entry contains full-channel qualification captures plus every attempted
FCO-eye combination. `Final.patternTester` reports whether the optional deep
window ran, its requested and checked sample counts, channel/FCO pass masks,
and detailed error counts and masks. When enabled, `Final.pn23` reports the four
samples from every channel, channel-coherence results, each recurrence
transformation tried, the selected valid transformation, and the nested deep
pattern-tester result. A failed scan may publish partial results for the lane
that could not produce a qualifying eye.

`Diagnostics` contains the measurement backend, expected patterns, raw and
masked data captures, FCO words and lock masks, and the currently active scan
point. The private working tree is not repeatedly copied into the public
variable during a scan. A successful run publishes it once at termination when
`Debug` is enabled; a failed or stopped run publishes it regardless of the
debug setting so failure evidence is retained.

`Outcome` reports `IDLE`, `RUNNING`, `PASSED`, `FAILED`, or `STOPPED`
independently of PyRogue's generic process state. Successful GUI-driven runs
finish with PyRogue's normal process message. `RunTime` and process progress
provide the remaining operational monitoring.

## Device-Specific Behavior

- **AD9249:** calibration is exposed per eight-channel bank because each bank
  has its own DCO, FCO, delays, and capture domain.
- **AD9252:** one calibration process covers the configured logical channels;
  ADC test-mode changes are committed with `DeviceUpdate`.
- **AD9681:** one process covers sixteen physical data lanes, eight assembled
  logical channels, and two FCO lanes. Disjoint lower/upper sample masks permit
  one common data sweep, while final shared-phase qualification verifies that
  both serialized halves represent the same sample epoch. ADC test-mode changes
  are committed with `DeviceUpdate`.

## Relationship to Static Timing

Runtime calibration compensates supported input-delay variation and chooses a
robust point inside the observed eye. It does not create timing constraints,
prove PCB skew limits, or guarantee that the FPGA DCO routing and I/O resources
are legal.

SURF does not install target XDC for these readouts. The integrating project
owns the package-pin assignments, DCO clock definition, DDR rise/fall input
delays, clock-placement constraints, `IODELAY_GROUP` assignments, and any
board-specific skew budgets in its top-level constraints. Derive timing values
from the selected ADC mode, datasheet timing, PCB flight times, and actual
target hierarchy, then review both min and max timing.

## Validation Status

The common RTL, register model, calibration process, pattern tester, and
primitive-free device simulations have focused GHDL/PyRogue regressions. A full
32-tap AD9681 snapshot-based calibration has also completed in VCS
co-simulation: both FCO lanes and all sixteen physical data lanes produced
bounded eyes, and final coherent eight-channel checkerboard qualification
passed. This simulation evidence does not replace target implementation timing
or hardware validation.
