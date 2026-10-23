# Silicon Labs device tests

`test_Si570.py` exercises the Si570 programmable XO model with real Rogue
memory transactions against a simulated Si570 register window. It checks the
datasheet frequency-programming example, per-part fxtal calibration, the
freeze/write/unfreeze/NewFreq sequence, RFREQ and N1 packing in register 8,
deferred field writes, divider and output-range limits including the
`max_freq` speed-grade limit, recovery from a failed configuration write while
the DCO is frozen, glitch-free small changes under Freeze M within +/-3500 ppm
of the last large change, RFREQ rounding, bulk writes (`LoadConfig`,
`WriteAll`) that apply registers 7-12 only through the full freeze/NewFreq
sequence, and that cached RST_REG/NewFreq/RECALL bits are never replayed by
later register 135 or forced bulk writes. The suite does not require an FPGA or an HDL simulator.

The driver calibrates fxtal by executing `RECALL`, which reloads the factory
configuration, so `factory_freq` must be the part's start-up frequency. The
first `Frequency` write does this automatically; later writes reuse the
calibration. A calibration more than 3000 ppm from the nominal 114.285 MHz
(the datasheet allows +/-2000 ppm) raises `ValueError` before any
configuration write, which catches a wrong `factory_freq` or a 7 ppm part.
Until calibrated, `Frequency` readback uses the nominal fxtal and can be off by
up to +/-2000 ppm.

Reference:

- [Skyworks Si570/Si571 datasheet rev 1.6](https://www.skyworksinc.com/-/media/Skyworks/SL/documents/public/data-sheets/si570-71.pdf):
  section 3.2 for the programming example used as the golden vector, Table 11
  for output ranges and the 10 ms unfreeze to NewFreq limit, and the register
  135/137 descriptions for the self-clearing and reserved bits. Parts with 7 ppm
  temperature stability use registers 13-18 and are not modeled.

With Rogue installed and the SURF Python package on `PYTHONPATH`, run:

```sh
PYTHONPATH="$PWD/python" python -m pytest -q -n 0 tests/devices/silabs
```

The suite skips when Rogue is unavailable and runs explicitly in the Rogue
CI job. See [the test methodology](../../README.md) for shared conventions.
