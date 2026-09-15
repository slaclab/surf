# Micron device tests

`test_DdrSpd.py` exercises the read-only DDR4 SPD proxy with real Rogue memory
transactions and a simulated FPGA I2C register window. It checks page cache
isolation, serialization, address translation, failure recovery, transaction
expiration, and worker lifetime. It also checks that variable writes, forced
bulk writes, and raw write requests cannot modify the EEPROM. Private page
selection still uses hardware writes. The suite does not require an FPGA or
an HDL simulator.

Decoder tests cover signed fine timing offsets, nominal speed-bin labels,
3DS die counts, ordinary multi-load stacks, and unsupported timing/rank mixes.
They also verify the values through Rogue LinkVariables and `Page0Summary`.

Decoder references:

- [Advantech SQR-SD4N-16G2K4HBC datasheet](https://advdownload.advantech.com/productfile/Downloadfile2/1-26QU5EP/Advantech_SQR-SD4N-16G2K4HBC_v2.1.pdf),
  PDF pages 17 and 19: a 16 GiB DDR4-2400 module with bytes 18=`0x07` and
  125=`0xD6`, giving a minimum cycle time of 833 ps.
- [JEDEC JESD21-C Annex L, DDR4 SPD release 6 (mirror)](https://studylib.net/doc/28564665/4-01-02-annexl-6r30):
  sections 8.1.7 and 8.1.14 define package organization and capacity; sections
  8.1.18, 8.1.19, and 8.1.52 define timebases, nominal periods, and signed
  fine offsets. Standard periods are mapped to nominal labels with one ps
  tolerance for encoding precision. Other positive periods retain their
  calculated rate. Unsupported timebases and asymmetric rank organizations
  return zero in numeric fields and are labeled unknown in the summary.

With Rogue installed and the SURF Python package on `PYTHONPATH`, run:

```sh
PYTHONPATH="$PWD/python" python -m pytest -q -n 0 tests/devices/micron/test_DdrSpd.py
```

The suite skips when Rogue is unavailable and runs explicitly in the Rogue
CI job. See [the test methodology](../../README.md) for shared conventions.
