# EthMacCore Regressions

These benches make the default (non-RoCEv2) behaviour of `ethernet/EthMacCore`
an executable contract. They follow the repository [test guide](../../README.md)
and [runner conventions](../../common/README.md); this page adds the
EthMacCore-specific selection guide, the known-issue list and the soak command.

## Layers and shared helpers

| Helper | Contents |
| --- | --- |
| `ethmac_test_utils.py` | Flattened EMAC stream endpoints, packet builders (Ethernet, IPv4/UDP, pause), reset/clock helpers and the `ETHMAC_RTL_SOURCES` list. |
| `ethmac_line_models.py` | RTL-independent GMII/XGMII line models: encoders with error injection (bad FCS, `RX_ER`, short or missing preamble/SFD, `/E/`, unterminated frames for nested `/S/`, both XGMII start lanes), receive-pin drivers that honour `ethClkEn`, transmit-pin monitors that decode `LineFrame` records (preamble, FCS, error, interframe gap), `StatusPulseCounter`, IPv4/UDP/TCP checksum builders and `verify_frame_checksums`, and the `FrameExpectation`/`describe_case` scoreboard helpers. |

Wrappers live in `ethernet/EthMacCore/wrappers/`. Two are aimed at line-level
benches: `EthMacImportExportWrapper` exposes the exporter's transmit pins and
the importer's receive pins separately, with separate `phyReady` inputs, and
`EthMacTopPhyWrapper` exposes `EthMacTop` with separate PHY transmit/receive
pins, primary and bypass streams, independent clocks and the full
configuration and status records.

## Selecting tests

Run the smallest set that covers a change, then the integration benches if the
change crosses stages. All commands run from the repository root after
`make MODULES="$PWD" import`.

| Changed stage | Focused files |
| --- | --- |
| `EthMacTxExport*` (GMII/XGMII exporters) | `test_EthMacTxExportLine.py` (all PHY cases), `test_EthMacTxExport.py` |
| `EthMacRxImport*` (GMII/XGMII importers) | `test_EthMacRxImportLine.py`, `test_EthMacRxImport.py` |
| `EthMacTxCsum` | `test_EthMacTxCsumDepth.py`, `test_EthMacTxCsum.py` |
| `EthMacRxCsum`, `getEthMacCsum` in `EthMacPkg` | `test_EthMacRxCsumDepth.py`, `test_EthMacRxCsum.py` |
| `EthMacRxFifo`, `SsiFifo`/`SsiObFrameFilter`/`SsiIbFrameFilter` in the MAC configuration | `test_EthMacRxFifoFlow.py`, `test_EthMacRxFifo.py` |
| `EthMacTxPause`, `EthMacRxPause`, `EthMacFlowCtrl` | `test_EthMacTxPauseTiming.py`, `test_EthMacTxPause.py`, `test_EthMacRxPause.py`, `test_EthMacFlowCtrl.py`, `test_EthMacTopPause.py` |
| `EthMacRxFilter` | `test_EthMacRxFilterPolicy.py`, `test_EthMacRxFilter.py` |
| `EthMacRxBypass`, `EthMacTxBypass` | `test_EthMacRxBypass.py`, `test_EthMacTxBypass.py`, `test_EthMacTopScoreboard.py -k bypass` |
| `EthMacRxShift`, `EthMacTxShift` | `test_EthMacRxShift.py`, `test_EthMacTxShift.py` |
| `EthMacTxFifo` | `test_EthMacTxFifo.py`, `test_EthMacTopScoreboard.py -k "async_prim or defaults"` |
| `EthMacRx`, `EthMacTx` wrappers | `test_EthMacRx.py`, `test_EthMacTx.py` |
| `EthCrc32Parallel` | `test_EthCrc32Parallel.py` |
| `EthMacTop` or any change crossing stages | `test_EthMacTopScoreboard.py`, `test_EthMacTop.py`, `test_EthMacTopPause.py` |

`test_EthMacTopScoreboard.py` is the integration contract. Its pytest IDs are
`<phy>_<case>` for `gmii`/`xgmii` and the cases `defaults`, `filter_pause`,
`bypass_async`, `async_prim`, `drop_err_false`, `jumbo` and `small_fifo`. Each
runs a seeded random scoreboard (traffic in bursts
separated by idle `phyReady` drops) and a mid-traffic reset scenario. Select
one PHY or case with `-k`, for example:

```bash
./.venv/bin/python -m pytest -n 2 -q tests/ethernet/EthMacCore/test_EthMacTopScoreboard.py -k xgmii_bypass_async
```

Random benches take their seed from the case (`SEED` for the scoreboard,
`ETHMAC_LINE_SEED` for the line benches, `ETHMAC_CSUM_SEED` for the checksum
benches); every failure message reports the seed and frame index.

XLGMII has no line model; `test_EthMacTxExport.py` and `test_EthMacRxImport.py`
keep checking that its placeholder leaves stay inert.

## Extended soak

```bash
RUN_ETHMAC_EXTENDED_TESTS=1 ./.venv/bin/python -m pytest -n auto -q \
    tests/ethernet/EthMacCore/test_EthMacTopScoreboard.py -k extended
```

This runs every scoreboard case with three further seeds and four times the
frame count, plus a GMII 1-in-10 `ethClkEn` (100 Mb/s) TX-only case. It is stable coverage that is too slow for the default run, not a
known-issue gate.

## Known issues

Each case below asserts the correct behaviour, fails on the current RTL for the
documented reason, and runs only with `RUN_KNOWN_ISSUE_TESTS=1`. Promote a case
to the default run together with its fix. With cocotb 2.1, a `skip=True`
entrypoint still runs whenever a `COCOTB_TEST_FILTER` matches it, including an
exclusion pattern that does not name it. Benches therefore name known-issue
entrypoints in a filter only when the gate is set, and exclude them explicitly
from any other filter while it is not.

```bash
RUN_KNOWN_ISSUE_TESTS=1 ./.venv/bin/python -m pytest -n 2 -q tests/ethernet/EthMacCore/test_EthMacKnownIssues.py
```

| Defect | Reproduction |
| --- | --- |
| `EthMacTxCsum` oversize branch leaves a `tLast`-less frame in `Fifo_Cache`, drops the next frame and misaligns `Fifo_Trans`, so later frames get the previous frame's length/checksum. | `test_EthMacKnownIssues.py::tx_csum_oversize_frame_misaligns_transactions_known_issue_test` |
| `EthMacRxImportXgmii` keeps emitting beats with no `tLast` after `phyReady` loss; at `EthMacTop` level `EthMacRxCsum`'s blow-off then swallows the next frame. | `rx_xgmii_import_link_loss_emits_beats_known_issue_test`, `rx_xgmii_top_link_loss_swallows_next_frame_known_issue_test` |
| XGMII nested `/S/`: with the first frame in lane 4 and the nested `/S/` in lane 0 the second frame is appended to the first; with both in lane 0 the second frame is discarded silently. A nested `/S/` in lane 4 is handled. | `rx_xgmii_import_nested_start_known_issue_test`, `rx_xgmii_top_nested_start_loses_frame_known_issue_test` |
| `EthMacTxExportXgmii` sends the remainder of a frame interrupted by link loss as a fresh, correctly-CRC'd frame after the link returns. | `tx_xgmii_link_loss_sends_valid_fragment_known_issue_test` |
| `EthMacTxExportGmii` checks `phyReady` only in idle, so a frame in flight is driven to completion on a dead link with no `txLinkNotReady`. | `tx_gmii_link_loss_completes_frame_known_issue_test` |
| `EthMacRxFifo` leaves `mAxisDropFrame` and `lockupRstEvent` unconnected, so outbound EOFE drops are not counted in `rxFifoDropCnt`. | `rx_fifo_outbound_drop_not_counted_known_issue_test` |
| With `DROP_ERR_PKT_G = false`, EOFE frames reach the line with a valid FCS: the GMII exporter ignores EOFE, and the XGMII exporter loses it for frames of 57 bytes or more (tLast on the 8th or later 64-bit word). | `tx_eofe_frame_leaves_with_valid_fcs_known_issue_test` (GMII and XGMII nodes) |
| `EthMacRxImportGmii` re-arms its SFD search while `RX_DV` is still high, so after an `RX_ER` abort a later `0xD5` octet starts a spurious frame with EOFE and `rxCrcError`. | `rx_gmii_import_sfd_rearm_after_rx_er_known_issue_test` |
| `EthMacRxImportGmii` loses every frame when `ethClkEn` is gated (10/100 Mb/s): the one-clock `delRxDv` pulse is cleared before the next enabled clock shifts it. | `test_EthMacRxImportLine.py::rx_clk_en_1_in_10_known_issue`, `rx_clk_en_1_in_100_known_issue` |
| `EthMacRxCsum` assigns EOFE from the last enabled check instead of OR-ing it with IPERR, the inbound EOFE and the oversize EOFE. | `test_EthMacRxCsumDepth.py::rx_eofe_overwrite_known_issue_test` |
| On a 16n+1-byte frame `EthMacRxCsum` treats the one-byte last beat as SOF (lane-0 alias) and overwrites EOFE with FRAG. | `test_EthMacRxCsumDepth.py::rx_one_byte_last_beat_known_issue_test` |
| Back-to-back frames (0–1 idle cycles, or an oversize cut followed directly) corrupt `EthMacRxCsum`'s IPv4 verdict: the live header is compared with a sum from three cycles earlier. | `test_EthMacRxCsumDepth.py::rx_back_to_back_known_issue_test` |
| `EthMacRxCsum` loses FRAG on a fragment when a `tValid` gap follows SOF while the previous frame is still flushing. | `test_EthMacRxCsumDepth.py::rx_frag_after_sof_gap_known_issue_test` |
| An RX FIFO frame larger than the FIFO with `DROP_ERR_PKT_G = true` is dropped or delivered depending on a stale last-frame entry that reset does not clear; it should always be delivered truncated with EOFE, as in cut-through. | `test_EthMacRxFifoFlow.py::rx_fifo_oversized_frame_history_known_issue_test` |
| `EthMacRxFifo` clamps `pauseThresh` to depth−1 but the write count tops out at depth−2, so a threshold at or above depth−1 (including the default 562 with `FIFO_ADDR_WIDTH_G = 9`) never pauses. | `test_EthMacRxFifoFlow.py::rx_fifo_pause_threshold_clamp_known_issue_test` |
| The RX FIFO pause flag reads busy in reset, so `EthMacTop` transmits a pause frame after every reset with an empty FIFO. | `test_EthMacTopPause.py::top_no_pause_frame_after_reset_known_issue_test` |
| `EthMacTxPause` sizes its quantum pre-counter with `bitSize(PAUSE_512BITS_G-1)`, so a quantum is the next power of two (2 cycles for a setting of 1). | `test_EthMacTxPauseTiming.py::tx_pause_quantum_length_known_issue_test` |

The integration and leaf benches keep their default-run stimulus clear of
these defects: `phyReady` changes only while the line is idle, TX frames stay
within the checksum stage's size limit, EOFE TX frames are sent only where
`DROP_ERR_PKT_G` drops them, `RX_ER` frames carry no `0xD5` after the error, and
the gated-clock GMII scoreboard case is TX-only.

## Current behaviour pinned by the default run

Some behaviour differs from IEEE 802.3 or from what a reader might expect but
is not treated as a defect. The benches assert it explicitly, with a comment
naming the RTL, so a change is noticed. Notable cases:

- The GMII exporter pads every frame shorter than 60 bytes to 61 bytes; XGMII
  pads to 60. On TX underrun GMII keeps `TX_ER` high with `TX_EN` low until idle.
- The XGMII exporter's back-to-back gap is 28–35 octets, never the 12-octet
  minimum. On underrun it ends the open frame without `/T/` and resumes the
  remainder as a new frame with an inverted CRC; `txUnderRun` is a level on
  every starved clock. With `phyReady` low it holds a frame (GMII drops it) and
  `txLinkNotReady` stays asserted on every waiting clock.
- Both importers deliver good-FCS runts. The GMII importer's outcome for
  `RX_ER` depends on the data octet it hits (silent drop for octets 0–4, a
  truncated EOFE frame later). The XGMII importer does not check preamble or SFD
  values.
- `EthMacRxBypass` compares `BYP_ETH_TYPE_G` with `tData(111 downto 96)`, so
  the generic is the EtherType in lane (byte-swapped) order.
- `EthMacTxCsum` keys fragment handling on the FRAG sideband and rewrites the
  IPv4/UDP length fields from the frame length; both checksum stages admit
  frames up to 1520 bytes (9024 with `JUMBO_G`).
- Generated pause frames carry an all-zero source MAC (`macAddress` is unused
  in `EthMacTxPause`; 802.3 Annex 31B expects the station address), frames
  dropped by `dropOnPause` are not counted, and TX bypass arbitration is strict
  priority. These are candidates for follow-up issues rather than settled
  policy.
- `PREVENT_LOCKUP` cannot trigger in the MAC's RX FIFO configuration: writes
  stop at almost-full, so the FIFO is never full while its output is stalled.
