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

`test_Tse2004av.py` checks the sensor's configuration fields against a simulated
sensor. Writable controls retain readback verification; `EventStatus` is
read-only and `ClearEvent` is a command. Tests cover each control's bit position
and verification, changing status, hardware locks, failed writes, and clear
commands followed by control/bulk writes. Alarm-limit writes remain verified.

`Configuration` is now a read-only summary assembled from the fields; use
`Configuration.get()` for one hardware read or `get(read=False)` for the cache.
Replace raw `Configuration.set(...)` calls with named controls, for example:

```python
sensor.EventMode.set(1)       # Interrupt mode
sensor.EventEnable.set(True)
sensor.ClearEvent()          # Pulse CLEAR, then leave its cached bit at zero
```

The other controls are `EventPolarity`, `CriticalOnly`, `EventLock`,
`CriticalLock`, `Shutdown`, and `Hysteresis`. The lock fields remain set until
the sensor's power-on reset; rejected changes to locked controls fail verification.

References:

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
- [Renesas TSE2004GB2B0 datasheet](https://www.renesas.com/en/document/dst/tse2004gb2b0-datasheet),
  PDF page 25: Configuration bit 5 (CLEAR) is write-only and reads zero;
  bit 4 (EVENT_STS) is read-only.

With Rogue installed and the SURF Python package on `PYTHONPATH`, run:

```sh
PYTHONPATH="$PWD/python" python -m pytest -q -n 0 tests/devices/micron
```

The suite skips when Rogue is unavailable and runs explicitly in the Rogue
CI job. See [the test methodology](../../README.md) for shared conventions.
