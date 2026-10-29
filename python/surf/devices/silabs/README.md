# Silicon Labs Python devices

Device classes are exported from `surf.devices.silabs`. See the
[Python package guide](../../../README.md) for shared conventions.

## Si570 programming

`Si570(factory_freq=..., max_freq=...)` uses MHz and configuration registers
7–12. Supply the fitted part's **factory NVM output frequency**, even if its
current output has already been changed. Set `max_freq` for its speed grade.
The 7 ppm variant using registers 13–18 is not supported.

No oscillator I/O occurs during construction. The first `Frequency.set()`
automatically recalls factory NVM and calibrates the device's crystal estimate.
Applications controlling clock-consumer resets can calibrate explicitly:

```python
# After starting the containing Root, with clock consumers held in reset:
oscillator.Calibrate()          # Recalls NVM; changes the output to factory_freq.
oscillator.Frequency.set(125.0)  # Example operating frequency in MHz.
print(oscillator.Frequency.get())
# Verify the output before releasing the application's clock-consumer reset.
```

`Calibrate()` invokes the same operation as `RECALL()`. Later frequency writes
reuse the cached crystal estimate. Recalibrate when reconnecting to a different
physical device. A failed calibration discards the old estimate; the next
frequency write retries calibration. Before calibration, `fxtal` is zero and
`Frequency` uses the nominal crystal estimate, which can differ by up to
±2000 ppm. Register-derived frequency is not an independent clock measurement.

Small changes within ±3500 ppm of the established center use Freeze M.
Larger changes check the DCO freeze, write and verify the configuration,
queue unfreeze/NewFreq together, wait for completion and 10 ms settling,
then verify final readback. A reverted configuration is retried. Host/network
latency and physical clock behavior still require hardware qualification.

Failed full programming invalidates the small-change center, so the next frequency
write performs a full update. Recovery attempts to unfreeze and apply the
registers, which may contain a partial configuration. An exception does not
guarantee the requested output; keep consumers reset and verify recovery.

Serialize access during calibration and programming. Raw fields remain expert
interfaces: their setters honor `write=False` and validate N1/RFREQ bounds,
but immediate raw writes require the caller to manage the freeze/update
sequence. Configuration files store `Frequency`, and bulk writes apply staged
settings through the controlled programming sequence.

See the [Si570 tests](../../../../tests/devices/silabs/README.md) for commands,
coverage and the datasheet reference. Tests use real Rogue with a simulated
register slave; they do not qualify electrical timing or clock accuracy.
