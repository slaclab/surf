# Silicon Labs Python devices

Device classes are exported from `surf.devices.silabs`.

## Si570 programming

`Si570(factory_freq=...)` uses MHz and the configuration bank at registers 7–12.
Supply the fitted oscillator's **factory NVM output frequency**, even if another
controller has already reprogrammed its current output. The 7 ppm variant with
registers 13–18 is not supported by this map. Check the part's output format and
speed grade before choosing a rate; finding legal dividers is not sufficient.

After constructing/starting the containing Root, hold clock consumers in reset
and invoke these operations explicitly:

```python
oscillator.Calibrate()          # Recalls NVM; changes the output clock.
oscillator.Frequency.set(125.0)  # Example operating frequency in MHz.
print(oscillator.Frequency.get())
```

`Calibrate` estimates the crystal frequency from the recalled dividers, RFREQ
and supplied factory frequency. It stores that estimate for subsequent changes;
it is not recomputed from a changed output configuration. Before calibration,
`fxtal` and `Frequency` return NaN, and frequency programming raises an error.
Recalibrate when reconnecting to a different physical device. Register-derived
frequency is not an independent measurement of the output clock.

The helper freezes the DCO, writes and checks the six configuration bytes,
unfreezes, issues NewFreq, waits for command completion and verifies final
readback. It conservatively rejects a host interval of 10 ms or more spanning
the unfreeze/NewFreq writes. Host scheduling, network and bus latency still need
qualification; this is not a real-time guarantee. Polls are bounded and bus
errors propagate. Failed programming can leave the DCO frozen or its state
uncertain; keep consumers reset and explicitly recover before retrying.

No oscillator I/O occurs during construction. Bulk operations are disabled to
prevent unscheduled clock changes. `Config[7]`–`Config[12]`, `N1`, `HS_DIV_INT`,
`RFREQ`, `FreezeDCO`, `FreezeM`, `RECALL` and `NewFreq` remain available for expert
access. Field setters honor `write=False`; raw writes do not perform a complete
frequency-update sequence. Serialize access to the device while programming.

The register layout and update procedure follow the
[Si570/Si571 data sheet, revision 1.6, sections 3.1–3.2 and 4](https://www.skyworksinc.com/-/media/skyworks/sl/documents/public/data-sheets/si570-71.pdf).

## Python-only verification

With an explicitly selected installed Rogue/PyRogue environment, run from the
SURF checkout:

```sh
python tests/devices/silabs/test_Si570.py
```

The unittest suite loads this device source directly and uses real PyRogue with
an in-memory register slave. It covers distinct factory calibrations, repeated
frequency changes, all 38 RFREQ bits, N1=128, deferred/bulk writes, invalid input,
command timeout, bus failure and final readback mismatch. Its deterministic
software timer verifies error handling, not physical latency. No RTL simulator,
FPGA, network transport or installed SURF package is required. It does not
qualify clock accuracy or board reset/I2C routing.
