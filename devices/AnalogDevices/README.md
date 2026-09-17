# Analog Devices

This tree contains register interfaces, readout RTL, simulation models, and
FPGA-family wrappers for supported Analog Devices parts.

## Serialized DDR ADCs

AD9249, AD9252, and AD9681 use the shared [`adcDdr`](adcDdr/) infrastructure
for their normalized readout implementations. The device directories retain
the part-specific pin topology, sample assembly, configuration interface, and
simulation model:

- [`ad9249/`](ad9249/) provides two independent eight-channel readout banks
  and a detailed guide for migrating the retained legacy
  `Ad9249ReadoutGroup` firmware and software.
- [`ad9252/`](ad9252/) provides one eight-channel readout.
- [`ad9681/`](ad9681/) assembles two physical serialized lanes per logical
  channel and captures both halves with one selected DCLK.

The shared [`adcDdr` README](adcDdr/README.md) describes the RTL boundary,
software calibration algorithm, measurement backends, and target-owned timing
responsibilities.
The matching PyRogue models are under
[`python/surf/devices/analog_devices`](../../python/surf/devices/analog_devices/).
AD9249 configuration/readout classes live in `_Ad9249.py`; the
unchanged `Ad9249ReadoutGroup` map and related legacy helper are isolated in
`_Ad9249Legacy.py` while remaining available through the package namespace.

### PyRogue Readout Classes

Application code should instantiate the device-specific readout class instead
of repeating normalized `AdcDdr` geometry. For example, the AD9681
map is:

```python
self.add(surf.devices.analog_devices.Ad9681Readout(
    enabled      = True,
    name         = 'Ad9681Readout',
    offset       = 0x00000000,
    deviceFamily = '7SERIES'))
```

The device classes supply these mappings:

| Class | Data lanes | FCO lanes | Channels | Sample bits | Serialization |
|---|---:|---:|---:|---:|---:|
| `Ad9249ReadoutBank` | 8 | 1 | 8 | 14 | 14 |
| `Ad9252Readout` | 8 by default | 1 | 8 by default | 14 | 14 |
| `Ad9681Readout` | 16 | 2 | 8 | 14 | 8 |

`Ad9249Readout` represents the full converter and contains two independent
`Ad9249ReadoutBank` children at offsets `0x0000` and `0x1000`. AD9252 exposes a
`channels` argument because its RTL supports `NUM_CHANNELS_G` from
one through eight. All three classes expose `deviceFamily`, matching RTL
`DEVICE_FAMILY_G`; the models derive five delay bits for 7-Series and nine for
UltraScale/UltraScale+. Migration from the
removed AD9681 and AD9249 Group2 interfaces is documented in the
[serialized DDR ADC migration guide](adcDdr/migration-guide.md).
Migration from the retained legacy `Ad9249ReadoutGroup` interface is documented
in the [AD9249 readout migration guide](ad9249/README.md).

### Device Simulation Timing

The three serialized-DDR ADC directories provide primitive-free `*Sim` models
with the device pin topology, a binary ideal DCO, coherent frame serialization,
and datasheet conversion latency. Normal conversion data is delayed by 16
sample clocks for AD9249 and AD9681 and by eight sample clocks for AD9252.
Digitally generated test patterns are selected after that conversion pipeline.

For all three models, `vin` is differential voltage (`VIN+ - VIN-`), with a
nominal full-scale range of -1 V to +1 V. Out-of-range inputs saturate; zero
volts maps to offset-binary `0x2000` or two's-complement `0x0000`. The AD9249
and AD9681 reset to two's-complement output (register `0x14 = 0x01`); AD9252
resets to offset binary (`0x14 = 0x00`). AD9252 coding changes are buffered
until a device-update write to `0xFF`; AD9249/AD9681 apply them immediately.
The normal-data coding helpers live in `surf.StdRtlPkg`.

The retained `ad9249/tb/Ad9249Group` model uses the same differential input
range and honors its existing output-format register for normal conversion.
Downstream benches that previously added a 1 V bias to the model's `vin` input
must remove it. This change does not alter the physical input common mode.

The flattened `*SimWrapper` adapters normally accept offset-binary input codes
independently of the selected device output coding. `INPUT_MILLIVOLTS_G=true`
instead interprets each 16-bit input slot as signed differential millivolts,
allowing direct voltage and overrange tests. These test wrappers are supplied
explicitly by the cocotb runners and are not loaded by ruckus manifests.

Their serializer timing controls have the same meaning:

- `DATA_PHASE_G` and `FCO_PHASE_G` apply a common static displacement relative
  to DCO to all data or FCO transitions.
- `DATA_SKEW_G` applies independent physical-data-lane displacement.
  `FCO_SKEW_G` is per FCO for AD9249 and AD9681 and scalar for AD9252.
- `JITTER_G` alternates each actual data/FCO transition between `-JITTER_G`
  and `+JITTER_G`. It does not introduce `X` values or jitter DCO.
- `TIMING_BIAS_G` delays data, FCO, and DCO together. Set it to at least
  `JITTER_G` when no positive phase/skew already makes the early transition
  schedulable. Because it is common-mode, it does not change setup time.

All timing controls default to zero, preserving an ideal centered eye. A
useful nonzero regression starting point is 50 ps of jitter with 50 ps of
timing bias, then measured or deliberately stressed per-lane skew. The models
assert if an early edge would fall before simulation time or a late data/FCO
edge would cross its following DCO sampling edge. The flattened cocotb wrappers
express timing controls in integer picoseconds and expose representative lane
zero/FCO-zero skew; instantiate the `*Sim` entity directly to provide complete
`TimeArray` lane maps.

Other part directories contain independent control or datapath cores and do
not use the serialized-DDR calibration flow unless their readout is explicitly
built on the normalized `AdcDdr` map.
