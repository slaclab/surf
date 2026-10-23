# Serialized DDR ADC Cleanup Follow-Up

## Goal

Complete real-hardware validation of the normalized ADC DDR readout and keep
the alignment/calibration path deterministic, fast, and diagnostically useful.

## Current Status

- AD9681 register `0x100` fields remain intentionally absent from the PyRogue
  model because hardware readback did not support verified writes.
- Relock now resets the deserializers for a bounded interval before reloading
  retained delays and restarting FCO alignment.
- Hardware AD9681 calibration produces bounded eyes for all sixteen physical
  data lanes and completes successfully.
- Calibration tap scans use coherent ordered snapshots. `UsePatternTester`
  enables one deep final checkerboard window instead of replacing every tap
  measurement with repeated hardware windows.
- AD9249 UltraScale hardware initially took about 60 seconds per bank with
  debug diagnostics enabled, but was quick with debug disabled. Calibration
  therefore retains the deterministic exhaustive scan and avoids repeatedly
  publishing the growing diagnostics tree.
- AD9249 hardware showed channel-dependent checkerboard epochs even though a
  PN23 snapshot was coherent across every channel. Pulsing the ADC bank's
  digital reset while checkerboard mode was selected restored coherence.
  Each ADC configuration model now exposes a normalized `DigitalReset()`
  command. Common calibration calls that command before data-eye measurement
  and restarts the FPGA receiver afterward. Because the failure was observed
  primarily while eight banks calibrated in parallel, calibration now repeats
  that checkerboard/reset/relock sequence immediately before every final
  qualification attempt as well. This removes the long data-scan interval from
  the ADC pattern-epoch assumption.

## Calibration UI Contract

- Delay thresholds and results explicitly use native `tap` units. UltraScale
  uses `IDELAYE3` uncalibrated `COUNT` mode, so ADC sample rate alone cannot
  turn those counts into a portable picosecond value.
- `Debug=True` retains the per-tap diagnostics privately and publishes one
  completed copy at process termination. Failed and stopped operations still
  publish their evidence when debug is disabled.
- Calibration exposes an explicit terminal `Outcome` (`PASSED`, `FAILED`, or
  `STOPPED`). `Message` retains PyRogue's normal process status instead of
  duplicating that outcome.

## Deep Qualification Contract

- `SampleCount` controls the shallow four-sample snapshot depth at each tap.
- `PatternTesterSamples` controls the final hardware checkerboard depth and
  defaults to 4096 valid samples per deep window.
- `UsePatternTester` defaults to the readout model's `patternCheck` construction
  parameter and remains user-writable.
- The deep result retains per-channel word-error counts and accumulated
  bit-error masks plus per-FCO error counts.
- A deep-check failure participates in the existing alternate-FCO-eye retry.
- PN23 first uses the four-sample snapshot to select the ADC output/format
  transformation. The hardware tester then acquires an arbitrary nonzero
  23-bit history and deeply checks reference-channel recurrence plus
  word-for-word coherence across every other enabled channel.

## Validation

Focused PyRogue model and calibration regressions cover strict snapshot order,
deep-check success and failure, detailed error reporting, capability rejection,
alternate FCO-eye retries, shallow and deep PN23 qualification, and state
restoration.

- `test_AdcDdrCalibration.py` and `test_AdcDdrModel.py`: 72 passed.
- `test_AdcDdrPatternTester.py`: 1 passed with GHDL/cocotb.
- VSG: no violations in `AdcDdrPkg.vhd` or `AdcDdrPatternTester.vhd`.

## Open Hardware Checks

- Compare normal calibration run time with deep qualification disabled and
  enabled.
- Confirm a 4096-sample deep window reports all-zero channel and FCO errors on
  the target board.
- Confirm the 4096-sample PN23 window acquires phase and reports all-zero
  reference recurrence and cross-channel coherence errors.
- Confirm repeated AD9249 calibrations retain shared checkerboard phase after
  the automatic digital-datapath reset, including all eight banks running in
  parallel and alternating between banks.
- Increase `PatternTesterSamples` if a longer bounded checkerboard stress test
  is useful; this remains qualification, not a claimed BER measurement.
