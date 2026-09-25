# RSSI RX and keepalive integration

## Goal and source

Prepare a candidate for the Warm-TDM column SRP failures without adding an
instrumented datapath. Branch: `fix/rssi-rx-keepalive-integration`.

- Base: `8d256ca84`, the keepalive branch with additional regression coverage.
  Its production monitor includes `6b6771a9f`, the fix loaded in Warm-TDM image
  `0b73019`: valid ACK/BUSY traffic refreshes server receive liveness.
- Incoming: [SURF PR #1456](https://github.com/slaclab/surf/pull/1456), reviewed
  head `5641e673f9d4d4481a79b945b476331d66d094a3`.
- Applied the PR changes relative to common ancestor `9248a10e6` as a source
  integration on the keepalive branch, without recording a Git merge of the
  PR branch. Warm-TDM pins the combined candidate through its SURF gitlink.

## Implementation

`RssiRxFsm.vhd` now aligns payload RAM writes/reads, prevents duplicate DATA
from modifying buffers, validates complete SYN headers, preserves payload
sidebands and final-beat pause, and cancels delivery when a connection closes.
The production-RAM/checksum RX wrapper, PyRogue READ-state enum and directed RX,
core-RX and connection-timeout tests accompany the change.

The keepalive monitor RTL and both its unit and core tests remain unchanged
from the base. `RssiConnFsm.vhd` already matches the PR's prerequisite, so no
additional connection-FSM RTL change was needed. Documentation combines both
coverage descriptions. Production interfaces, buffer/window settings, clocks
and the Warm-TDM datapath are unchanged.

## Validation

The source import and VSG checks on both edited VHDL files passed (zero
violations). Flake8 on the changed Python files and the RSSI test compliance
audit passed (zero findings). With GHDL 6.0.0 and cocotb 2.1.0, all 10 focused
pytest cases passed: RX, core-RX, monitor, core-keepalive and connection-FSM.
The remaining checksum, header-register and TX leaf tests also passed (three
pytest cases). The AXI-Lite register-interface case was skipped by its existing
`RUN_RSSI_KNOWN_ISSUE_TESTS` gate; it is not included in passing coverage.

An isolated comparison kept the keepalive fix and new tests but restored the
original RX RTL from `8d256ca84`. Both selected RX cocotb cases failed:

- `data_busy_payload_and_partial_keep_test`: extra zero payload words preceded
  the expected final word, which lost its SOF marker.
- `close_at_each_payload_stage_cancels_old_connection_test`: old payload words
  appeared after reconnect, preceding the new payload without its SOF marker.

Both cases pass in the integrated focused run. This demonstrates that the tests
detect the original RX defects; it does not establish the bench root cause.

Local tooling uses `/Users/bareese/surf/.venv/bin/python` and sibling ruckus:

```bash
make MODULES=/Users/bareese/warm-tdm/firmware/submodules import
/Users/bareese/surf/.venv/bin/python -m pytest -n 0 -q \
  tests/protocols/rssi/test_RssiRxFsm.py \
  tests/protocols/rssi/test_RssiCoreRx.py \
  tests/protocols/rssi/test_RssiMonitor.py \
  tests/protocols/rssi/test_RssiCoreKeepalive.py \
  tests/protocols/rssi/test_RssiConnFsm.py
/Users/bareese/surf/.venv/bin/python -m pytest -n 0 -q \
  tests/protocols/rssi/test_RssiChksum.py \
  tests/protocols/rssi/test_RssiHeaderReg.py \
  tests/protocols/rssi/test_RssiTxFsm.py \
  tests/protocols/rssi/test_RssiAxiLiteRegItf.py
```

Generated outputs stay outside this handoff. Local import/lint/test logs are
`/private/tmp/rssi-integration-{import,vsg,audit,focused,knownbad,leaf}.log`.

## Remaining acceptance

Warm-TDM's follow-up report at commit `3736f28` records the combined candidate
loaded as column image `96a974f`: clean controls passed 4/4, while all four
first-read probes after batched-read resets still failed. This candidate does
not resolve that hardware reproducer.

A subsequent directed characterization, `test_RssiBusyThreshold.py`, demonstrates
that RX application delivery can pause without asserting local/wire BUSY. With
segment address width 7, FIFO pause is 112 words while BUSY requires count bit 7
(128 words). Four 32-word segments with a stalled sink leave the fourth ACK
pending and BUSY clear; releasing the sink delivers all payloads and advances
the ACK. The one pytest/cocotb case, Flake8 and test compliance audit passed.
This is an inferred-memory core characterization with accelerated timers, not
an end-to-end reproduction of the hardware reset or subsequent request loss.
No RTL change has been made for this threshold finding.

### Local depacketizer recovery correction

The packetizer correction is isolated in commit `2b58e8251`, including its
standalone regressions. It is beyond pinned `7504a23b3` and the hardware image
discussed above, and remains awaiting hardware acceptance. After the operator
tests it, cherry-pick that commit onto a clean branch from `pre-release` for
review; the RSSI characterization and integration harness are separate commits.

The integrated `test_RssiSrpRecovery.py` uses the real RSSI wrapper, V2 FULL CRC, SRPv3 and
async FIFOs at 156.25/125 MHz, eight 1024-byte segments and inferred memories.
There is no global reset or output drain between RSSI connections.

| Scenario | Original `7504a23b3` | Corrected implementation |
| --- | --- | --- |
| 16 reads, host BUSY and eight unacknowledged replies, then RST/reconnect | Both new reads pass | Both pass |
| Partial request, ACKed first packetizer fragment, then RST/reconnect | No termination; first new read lost, next succeeds | EOFE delivered; both pass |
| 293 complete reads with AXI response blocked, then RST/reconnect/release | First new read lost, next succeeds | Both pass; internal trace confirms EOFE precedes first new SOF |
| 560 complete reads, host BUSY/withheld reply ACKs, AXI continuously enabled, then RST+BUSY/reconnect | First new read never reaches AXI; second succeeds | Both reach AXI and return exact CRC-checked replies |
| Four active destinations, output stalled across link loss | Three RAM configurations fail; unregistered distributed RAM passes this all-active case | All four pass |
| Mixed open/closed destinations at both address boundaries | Not rerun on original | Registered block and unregistered distributed pass |
| Global reset during termination, then fresh traffic | Not rerun on original | All six curated parameter cases pass |

The address change clears the RAM entry just examined during `TERMINATE_S`,
using `r.activeTDest` for termination writes instead of the already-advanced
`rin.activeTDest`. An isolated address-only comparison fixes both integrated
reproducers, but exposes duplicate termination beats under output backpressure.
The pending output beat's valid flag is therefore cleared when moved forward.
That combined implementation passes the four RAM/register combinations and
the previously exercised normal/error depacketizer regressions.

In the complete-read burst, the trace records link loss in depacketizer
`MOVE_S` with an active frame and pending non-final output beats. Buffered old
request tid 1261 begins at the limiter after RSSI drops. The corrected sweep
emits EOFE for destination 0; the limiter consumes it in `MOVE_S` and then sees
fresh tid 20 in `IDLE_S`. Both new reads return exact replies. Without that
termination, the limiter consumes the new SOF as the old frame's error ending.
This accounts for the one-request loss in the directed burst simulation.

The host-only burst produces the same one-request loss without stalling AXI.
Both variants stop at 560 requests sent and 268 AXI reads (including the initial
control), cumulative ACK 0x49 and local/wire BUSY clear. After explicit host
RST+BUSY (0x11) and reconnect, original RTL sees fresh tid 30 in limiter
`MOVE_S` and loses it, then accepts tid 31 in `IDLE_S`. The correction emits
EOFE first and sees both fresh SOFs in `IDLE_S`; both exact replies return.
Original fails at 97.2170 us simulated; corrected passes at 97.3066 us.
The test waits for the second reply before checking both, separating old
backlog latency from first-request loss. This uses a Python wire peer and an
explicit reset, not Rogue scheduling or automatic retransmission exhaustion.

The corrected checkout passes the clean and partial RSSI/SRP scenarios. Its
functional RTL is identical to the combined scratch candidate used for the
multi-destination and internally traced burst checks. VSG, Flake8 and compliance
audit pass. Tests are kept in the repository; raw traces and build products stay
outside Git, under `/private/tmp/rssi-srp-address-experiment/` and the paths
recorded in Warm-TDM's register-timeout handoff.

Remaining checks include additional reset/disconnect timing boundaries and
configurations outside the curated matrix, XPM/Vivado timing and actual
hardware acceptance. The BUSY-threshold mismatch remains a separate unmodified issue. Do not claim that
correct reconnect recovery prevents the original congestion/reset.

The PR reports a separate broad bidirectional integration failure; gated tests
are not passing-coverage claims. The operator built and loaded the candidate;
Vivado resource and timing reports have not been reviewed locally.

Further candidates require Vivado 2024.1 builds, recorded source/image identities,
and comparison against these failed baselines. Follow Warm-TDM's
`docs/plans/register-timeout/hardware-handoff/README.md`: idle keepalive,
SAFb/AxiVersion batched versus sequential reads, full-column reads, and first
reads after clean close versus after a batched-read reset. Keep raw evidence
outside Git. Preserve the keepalive fix in every candidate; do not replace the
base with the older PR head wholesale. Bench root cause remains unproven.

Run the recovery tests from the SURF root after the normal ruckus import:

```bash
python -m pytest -n 0 -q tests/protocols/packetizer/test_AxiStreamDepacketizer2.py \
  tests/protocols/packetizer/test_AxiStreamDepacketizer2Recovery.py
python -m pytest -n 0 -q tests/protocols/rssi/test_RssiSrpRecovery.py
RUN_RSSI_EXTENDED_TESTS=1 python -m pytest -n 0 -q \
  tests/protocols/rssi/test_RssiSrpRecovery.py -k 'blocked_axi or busy_host'
```

The default RSSI/SRP selection runs the clean and partial-frame cases; the
two FIFO-filling bursts are extended coverage, without a known-issue gate.
To reproduce the old failures, use
an isolated build with only `AxiStreamDepacketizer2.vhd` restored from
`7504a23b3`, keeping the same wrapper, other RTL and Python stimulus. Keep
per-variant GHDL build directories separate. The clean branch and PR are deferred
until hardware testing; no hardware pass is claimed by these commits.
