# Micron device tests

`test_DdrSpd.py` exercises the read-only DDR4 SPD proxy with real Rogue memory
transactions and a simulated FPGA I2C register window. It checks page cache
isolation, serialization, address translation, failure recovery, transaction
expiration, and worker lifetime. It also checks that variable writes, forced
bulk writes, and raw write requests cannot modify the EEPROM. Private page
selection still uses hardware writes. The suite does not require an FPGA or
an HDL simulator.

With Rogue installed and the SURF Python package on `PYTHONPATH`, run:

```sh
PYTHONPATH="$PWD/python" python -m pytest -q -n 0 tests/devices/micron/test_DdrSpd.py
```

The suite skips when Rogue is unavailable and runs explicitly in the Rogue
CI job. See [the test methodology](../../README.md) for shared conventions.
