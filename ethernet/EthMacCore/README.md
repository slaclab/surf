# EthMacCore

Common Ethernet MAC: `EthMacTop` composes the TX path (`EthMacTxFifo`,
`EthMacTxBypass`, `EthMacTxCsum`, `EthMacTxPause`, `EthMacTxExport`), the RX
path (`EthMacRxImport`, `EthMacRxPause`, `EthMacRxCsum`, `EthMacRxBypass`,
`EthMacRxFilter`) and `EthMacRxFifo`. Records, stream configurations and
constants are in `rtl/EthMacPkg.vhd`. Return to the [Ethernet index](../README.md).

## Layout

- `rtl/`: synthesizable MAC stages. `EthMacTxExport` and `EthMacRxImport`
  select one PHY leaf per `PHY_TYPE_G` (`*Gmii`, `*Xgmii`, `*Xlgmii`).
- `wrappers/`: cocotb-facing flattening wrappers; simulation only.
- `tb/`: legacy VHDL testbenches, loaded simulation-only.
- `src/`: host-side C++ utility that sends pause frames.

## Timing mode

`INT_CONFIG_G => EMAC_TIMING_AXIS_CONFIG_C` carries an eight-bit frame token
in `tId` through every MAC FIFO. `TIMING_EN_G` additionally selects the timing
leaves (`EthMacRxImportTimingGmii`, `EthMacRxImportTimingXgmii`,
`EthMacTxExportTimingXgmii` and the timing branch of `EthMacTxExportGmii`),
which publish tokened `start`/`done`/`lost` frame events; enables the retire
outputs of the checksum, pause, filter and RX FIFO stages; removes the RX
FIFO lockup self-reset; clears pause counters on link loss; and adds the
forced-abort handshake (`EthMacTimingAbort`). GMII and XGMII only;
`EthMacTop` asserts the required generics. Both default to off and leave
other MAC users unchanged. The contract and its consumer, `PtpMacPort`, are
in the PtpCore [timing-port guide](../PtpCore/timing-port.md).

## Tests

Regressions are under `tests/ethernet/EthMacCore/`; see the
[test guide](../../tests/README.md). `test_EthMacTimingGmiiLeaf.py` and
`test_EthMacTimingXgmiiLeaf.py` check the timing leaves against the passive
PTP adapter; `test_EthMacTimingTid.py`, `test_EthMacTimingRetire.py` and
`test_EthMacTimingAbort.py` check the token carrier, every retire owner and
the abort handshake through a timing-mode `EthMacTop`.
