# EthMacCore Regressions

These benches make the default (non-RoCEv2) behaviour of `ethernet/EthMacCore`
an executable contract. They follow the repository [test guide](../../README.md),
[protocol guidance](../../protocols/README.md) and
[runner conventions](../../common/README.md); this page adds the
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

`test_EthMacTopScoreboard.py` runs seven short default configurations:

| Case | Integration contract |
| --- | --- |
| `gmii_defaults` | GMII framing, default generics, reset during an observed TX frame |
| `gmii_filter_pause` | Filtering/pause with a common primary clock |
| `xgmii_defaults` | XGMII framing with default generics |
| `xgmii_bypass_async_prim` | Bypass and slow-primary CDC, reset during an observed TX frame |
| `xgmii_drop_err_false` | Forward RX errors with EOFE |
| `xgmii_jumbo` | A guaranteed 9000-byte frame in each direction |
| `xgmii_small_fifo` | Deliberately blocked RX, required overflow, ordered survivors and recovery |

Each runs 6–12 frames per direction in two bursts with an idle link-down
window. Directed first packets exercise each configured route and error mode,
then seeded traffic adds variety. RX order is checked independently per output;
all exposed beat fields must remain stable under stalls, and drains reject
partial AXI or PHY frames. Runtime checksum checks are disabled in this routing
scoreboard; `test_EthMacRxChecksumIntegration.py` separately exercises actual
PHY input with all three checksum enables set, both error-drop policies,
fragments, one-byte final beats and tight receive spacing.

Select one case with `-k`, for example:

```bash
./.venv/bin/python -m pytest -n 2 -q tests/ethernet/EthMacCore/test_EthMacTopScoreboard.py -k xgmii_bypass
```

`test_ethmac_models.py` is a fast simulator-free check of checksum/FCS known
answers and deliberately corrupted observations that the scoreboards must reject.

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

This retains the original seven cases on each PHY (30 GMII / 80 XGMII
frames, smaller jumbo cases), runs each with three seeds and four times those
frame counts, and repeats mid-traffic reset in every configuration. It also
includes a GMII 1-in-10 `ethClkEn` (100 Mb/s) TX-only case. This slow coverage
is gated separately from unresolved RTL defects.

## Known issues

The unresolved defect reproducers below assert the intended behavior, fail on
the current RTL for the documented reason, and run only with
`RUN_KNOWN_ISSUE_TESTS=1`. The two policy candidates have default recovery tests
that are expected to pass; their proposed stricter requirements remain undecided. Promote a case
to the default run together with its fix. With cocotb 2.1, a `skip=True`
entrypoint still runs whenever a `COCOTB_TEST_FILTER` matches it, including an
exclusion pattern that does not name it. Benches therefore name known-issue
entrypoints in a filter only when the gate is set, and exclude them explicitly
from any other filter while it is not.

```bash
RUN_KNOWN_ISSUE_TESTS=1 ./.venv/bin/python -m pytest -n 2 -q tests/ethernet/EthMacCore/test_EthMacKnownIssues.py
```

Reports are numbered in recommended fix order, with scope and severity from
the review. **High** denotes data integrity or sustained loss in an affected
supported path; **Medium** a bounded functional/configuration failure; **Low**
a diagnostic, startup or unusual-configuration issue. Priority also accounts
for default-path exposure and strength of the reproducer. Keep these IDs stable
in subsequent fix PRs; `Old` preserves the initial PR review numbering.
Reports #16 and #17 remain policy candidates, not confirmed contract violations.

| # | Old | Severity / applicability | Report and reproduction |
| --- | --- | --- | --- |
| 1 | 10 | High; runtime defaults | RX checksum stage clears inbound/earlier EOFE. Leaf: `test_EthMacRxCsumDepth.py::rx_eofe_overwrite_known_issue_test`. PHY: `test_EthMacRxChecksumIntegration.py::rx_bad_fcs_preserves_error_known_issue_test` demonstrates bad-FCS UDP escaping error dropping. |
| 2 | 11 | High; length/error dependent | One-byte final beat aliases IPERR/SOF and FRAG/EOFE. `test_EthMacRxCsumDepth.py::rx_one_byte_last_beat_known_issue_test`. |
| 3 | 1 | High; oversize input | TX checksum cache loses frame/transaction alignment, dropping the next frame and applying prior metadata to later frames. `test_EthMacKnownIssues.py::tx_csum_oversize_frame_misaligns_transactions_known_issue_test`. |
| 4 | 4 | High; XGMII link loss | TX remainder becomes a new frame with valid FCS. `tx_xgmii_link_loss_sends_valid_fragment_known_issue_test`. |
| 5 | 2 | High; XGMII link loss | RX continues unterminated beats and the checksum blow-off swallows recovery. `rx_xgmii_import_link_loss_emits_beats_known_issue_test`, `rx_xgmii_top_link_loss_swallows_next_frame_known_issue_test`. |
| 6 | 9 | Fixed; previously High, GMII 10/100 only | Retain `delRxDv` until the next enabled clock. Default `test_EthMacRxImportLine.py::rx_clk_en_1_in_10_test`, `rx_clk_en_1_in_100_test` and `rx_clk_en_recovery_test` require exact delivery, bad-FCS marking/status and recovery at full rate. |
| 7 | 7 | High; error forwarding | EOFE TX reaches the line with valid FCS (GMII all lengths, XGMII >=57 bytes). Default error dropping normally protects this path. `tx_eofe_frame_leaves_with_valid_fcs_known_issue_test`. |
| 8 | 8 | Medium | GMII RX_ER re-arms SFD detection inside RX_DV, creating a second errored frame at payload 0xD5. `rx_gmii_import_sfd_rearm_after_rx_er_known_issue_test`. |
| 9 | 14 | Medium; frame exceeds FIFO | Oversize RX outcome depends on stale pre-reset metadata. Require deterministic discard or truncated EOFE delivery and clean recovery. `test_EthMacRxFifoFlow.py::rx_fifo_oversized_frame_history_known_issue_test`. |
| 10 | 15 | Medium; threshold boundary | `pauseThresh >= depth-1` is unreachable after writes stop at depth-2; default 562 is affected with a 512-entry FIFO. `test_EthMacRxFifoFlow.py::rx_fifo_pause_threshold_clamp_known_issue_test`. |
| 11 | 12 | Medium; leaf trigger | Adjacent frames compare a delayed IPv4 sum against a live next header. Normal wire incidence remains unproven. `test_EthMacRxCsumDepth.py::rx_back_to_back_known_issue_test`. |
| 12 | 13 | Medium; leaf trigger | Gap after SOF during prior flush misaligns FRAG. Normal wire incidence remains unproven. `test_EthMacRxCsumDepth.py::rx_frag_after_sof_gap_known_issue_test`. |
| 13 | 6 | Low; diagnostics | Outbound EOFE drops do not increment `rxFifoDrop`. Counter semantics need agreement; unconnected lockup-reset reporting is not independently reproduced. `rx_fifo_outbound_drop_not_counted_known_issue_test`. |
| 14 | 16 | Low; startup transient | Empty RX FIFO can generate pause if pause/link are enabled during reset-busy. Not every reset in every configuration. `test_EthMacTopPause.py::top_no_pause_frame_after_reset_known_issue_test`. |
| 15 | 17 | Low; unusual generic | Pause quantum rounds to power of two (setting 1 becomes 2). Normal wrapper values 8/64 work. `test_EthMacTxPauseTiming.py::tx_pause_quantum_length_known_issue_test`. |
| 16 | 3 | Medium robustness candidate; policy unresolved | Nested XGMII /S/ has lane-dependent salvage/discard. This malformed sequence has no termination/legal gap; salvaging its second frame is not an established requirement. Default `rx_xgmii_import_nested_start_recovery_test` and `rx_xgmii_top_nested_start_recovery_test` require clean recovery without accepting clean merged data. |
| 17 | 5 | Low policy candidate; defect unproven | GMII completes an in-flight frame after link loss without a not-ready pulse. No abort deadline is specified. Default `tx_gmii_link_loss_recovery_test` accepts completion or abort and requires intact recovery without fabricated valid frames. |

Unqualified entrypoints above live in `test_EthMacKnownIssues.py`. Its known
failure nodes skip **before simulator launch** unless the gate is enabled;
its three policy/recovery nodes run by default and are expected to pass.


The integration and leaf benches keep their default-run stimulus clear of
confirmed defects: `phyReady` changes only while the line is idle, TX frames stay
within the checksum stage's size limit, EOFE TX frames are sent only where
`DROP_ERR_PKT_G` drops them, `RX_ER` frames carry no `0xD5` after the error, and
the gated-clock GMII scoreboard case is TX-only.

## Current behaviour pinned by the default run

Some behaviour differs from IEEE 802.3 or from what a reader might expect but
is retained as characterization rather than settled acceptance policy. The
benches name the RTL behavior so a deliberate improvement can update the
corresponding characterization in its fix PR. Notable cases:

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

The RX checksum leaf does not yet cover 17–59-byte runt handling or recovery
from it. The importers can deliver these runts without padding; this is an
exposed verification gap, not an unreachable case. Nonzero Ethernet padding
entering transport checksum calculations also needs follow-up classification.
