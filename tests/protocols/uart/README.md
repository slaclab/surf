# UART regressions

Follow the shared [regression methodology](../../README.md),
[protocol guidance](../README.md), and [runner instructions](../../common/README.md).

`test_UartRx.py` drives the receiver directly with independently generated UART
frames. It covers EVEN/ODD/NONE parity, 7- and 8-bit data, and baud multipliers
8 and 16. Checks include parity polarity, actual ready/valid transfers,
back-to-back reception with ready high, delayed acknowledgment during reception
of the next frame, and reset of pending or partially received results.

The receiver publishes parity status with the corresponding data. Reception
continues while ready is low: a newly completed frame replaces any unread
result. The tests verify that data and status change together under this
existing overrun policy; they do not assume lossless backpressure or an overrun
indicator. Framing errors, baud-rate mismatch, and transmitter/wrapper
integration are outside this focused regression.

From the repository root, after preparing the regression environment:

```bash
make MODULES="$PWD" import
./.venv/bin/python -m pytest -n 0 -q tests/protocols/uart/test_UartRx.py
```
