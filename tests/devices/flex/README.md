# Flex device tests

`test_FlexPmbus.py` exercises the `Bmr467` and `Bmr474` PyRogue drivers with
real Rogue memory transactions against a simulated `AxiLitePMbusMasterCore`
register window (one PMBus command per 32-bit word). It checks the shared
LINEAR16 decoder in `surf.protocols.i2c` against datasheet `VOUT_MODE` and
`READ_VOUT` values for both exponents, LINEAR11 decoding of `VIN`, `IOUT` and
`TEMPERATURE[1]`, and the reduced node map: only `VIN`, `VOUT`, `IOUT` and
`TEMPERATURE[1]` are visible, the five raw registers behind them are hidden
and RO at their PMBus offsets, nothing is polled, and `ReadAll` touches only
those five registers while `WriteAll` issues no transaction. The suite does not require
an FPGA or an HDL simulator.

The SMBus transfer-type overrides in `protocols/pmbus/rtl/FlexPMbusPkg.vhd`
are not modelled here; they are covered by the VHDL lint and analysis flow.

References:

- Flex technical specification 1/28701-BMR467 Rev E, "PMBus Command Summary"
  and "VOUT_MODE (0x20)": `VOUT_MODE` = 0x13, exponent -13.
- Flex technical specification 1/28701-BMR474 Rev A, "PMBus Command Summary"
  and "VOUT_MODE (0x20)": `VOUT_MODE` = 0x16, exponent -10.
- PMBus Power System Management Protocol Specification Part II, section 8.2:
  the LINEAR16 mantissa is a 16-bit unsigned integer.

With Rogue installed and the SURF Python package on `PYTHONPATH`, run:

```sh
PYTHONPATH="$PWD/python" python -m pytest -q -n 0 tests/devices/flex
```

The suite skips when Rogue is unavailable and runs explicitly in the Rogue
CI job. See [the test methodology](../../README.md) for shared conventions.
