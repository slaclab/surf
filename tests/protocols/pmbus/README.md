# PMBus tests

`test_AxiLitePMbusMasterCore.py` drives `AxiLitePMbusMasterCore` through
`protocols/pmbus/wrappers/AxiLitePMbusMasterCoreWrapper.vhd` against the
cycle-level SMBus slave in `smbus_test_utils.py`. It covers read-data masking
to the transfer size and a write read back through the slave.

`protocols/pmbus` is only loaded by ruckus for Vivado builds, so the test adds
its RTL through `extra_vhdl_sources`.

```sh
make MODULES="$PWD" import
./.venv/bin/python -m pytest -n 0 -q tests/protocols/pmbus
```

See [the regression style guide](../../README.md) and
[the protocol test guidance](../README.md) for shared conventions.
