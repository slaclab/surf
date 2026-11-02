# Transceiver device tests

`test_QsfpRogue.py` exercises the PyRogue `Qsfp` upper-page proxy with real
Rogue memory transactions against a simulated SFF-8636 memory map (lower page,
page-select byte 127, upper page 00h). It checks that an I2C failure on an
upper-page access is reported to the caller instead of being returned as
zeros, that the retrying string LinkVariables recover from a single failure
without counting an error, that the page-select byte is rewritten after any
failure, and that the proxy worker is a daemon thread. The suite does not
require an FPGA or an HDL simulator.

With Rogue installed and the SURF Python package on `PYTHONPATH`, run:

```sh
PYTHONPATH="$PWD/python" python -m pytest -q -n 0 tests/devices/transceivers/test_QsfpRogue.py
```
