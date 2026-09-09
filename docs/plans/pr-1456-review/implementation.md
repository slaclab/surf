# PR 1456 implementation

Implemented locally on `rssi-rx-fsm-fixes`, starting at reviewed PR head
`e0a05a9abb9f764355110efd634fc49319889c47`. The user authorized repairing the
five findings and the validation needed to review those repairs. Nothing was
staged, committed, pushed, or posted to GitHub. Rogue was not modified.

The [original review](README.md) and [specification/history investigation](spec-history-and-rogue.md)
are historical evidence. They describe the original head, not the revised RTL.

## Changes

- Accept DATA+BUSY, consistent with the specification clarification, existing
  SURF header generator, and Rogue. Keep ACK required and reject DATA carrying
  NULL, RST, or unsupported EACK.
- Drain duplicate DATA without payload RAM writes or window metadata updates.
  A clean, validated duplicate still publishes `rxValidSeg_o`, preserving the
  ACK event used by TX. Bad checksum, invalid ACK window, and bad EOF do not
  validate a duplicate's ACK. This preserves the existing accepted sequence
  range; it does not add arbitrary out-of-order buffering.
- Freeze the final accepted SYN word's parameters and EOF flags while waiting
  for checksum completion. The following stalled frame cannot overwrite them.
- Give inactive connection status priority over every application state,
  clearing pending output and resetting the application read pointers. A valid
  new SYN still initializes the receive window and sequence as before.
- Keep public application debug values CHECK_BUFFER=0, DATA=1, SENT=2; assign
  READ=3 and add that entry to PyRogue.
- Saturate the connection timeout counter in its two wait states. This narrow
  prerequisite prevents a range error before timeout handling runs; it does
  not import the companion connection branch's parameter-policy changes.

The original PR's registered-RAM READ state and final payload-size correction
remain. `segSize` records the last zero-based payload word address, using the
increment already computed into `v.rxSegmentAddr`. No additional payload
pipeline stage or production interface was introduced by this revision.

The RX test wrapper now instantiates production `SimpleDualPortRam` and can
select real `RssiChksum` or externally supplied checksum status. New test-only
outputs expose final SYN fields and payload write enable. Its existing ruckus
manifest already imports the wrapper directory; no HDL manifest change is needed.

The transport test monitor and formatter now parse the complete captured frame.
Previously they supplied only eight bytes to the strict SYN parser, causing a
valid 24-byte SYN to be classified as malformed.

## Validation

Environment: GHDL 6.0.0, cocotb 2.0.1, installed `.venv`. Ruckus import passed.

```sh
make MODULES="$PWD" import
.venv/bin/pytest -q tests/protocols/rssi
```

Result: **8 pytest entries passed, 19 existing gated entries skipped** in 80.13 s.
The newly enabled checks do not depend on `RUN_RSSI_KNOWN_ISSUE_TESTS`.

| Focused check | Result |
| --- | --- |
| RX, injected checksum status | 17 cocotb cases pass |
| RX, checksum disabled | 1 cocotb case passes |
| RX, real checksum | 3 cocotb cases pass: standalone SYN, contiguous SYN/DATA, malformed SYN followed by valid SYN |
| Connection retries/timeouts | Client and server timeout cases pass |
| Core RX with independent wire peer | DATA+BUSY, duplicate suppression, sequence wrap, and close/reopen with unread FIFO data pass |
| Real client/server pair | Negotiation and no unexpected application output pass |
| Existing checksum and header-generator pytest entries | Pass |
| VSG | All three edited VHDL files pass, zero violations |
| Flake8 | All edited/new Python files pass |
| `git diff --check` | Pass |
| Simulator process cleanup | No matching simulator/pytest processes remain |

The RX tests cover one-, two-, and four-word payloads, partial final keep,
occupied-window pointer wrap, duplicate ACK progress both before and after
application delivery, no duplicate writes, invalid duplicate checksum/EOFE,
and closure before first output, mid-frame, before final output, and at frame
completion, with pause asserted and clear. Debug observations are checked
against the actual PyRogue enum without importing PyRogue.

The core RX test uses real checksum, RAM, FIFO, and connection logic. It checks
all application data and framing and does not discard unexpected output before
payload checks or after reopening. It is distinct from full bidirectional
payload integration.

## Original-head comparisons

An isolated source export at `/tmp/surf-pr1456-review` was used for forced fresh
compiles with the new test fixture and the original RX RTL. The revised PyRogue
map was copied too, so diagnostic observations could be compared to the intended
public values. The original RTL fails DATA+BUSY acceptance, duplicate ACK
validation after delivery and with an occupied wrapped window, contiguous
real-checksum SYN/DATA, and close/reopen. The closure reproduction reaches the
functional assertion: stale application output appears after reopening with no
new DATA. Ordinary valid DATA and standalone real-checksum SYN remain passing
controls on the original head.

The two timeout regressions also fail with the original connection RTL at the
counter increment bounds checks, and pass with saturation.

Logs:

- `/tmp/surf-pr1456-revision-subsystem.log`: final default suite.
- `/tmp/surf-pr1456-revision-original.log`: original RX and connection RTL.
- `/tmp/surf-pr1456-revision-original-close.log`: original RX closure failure,
  after moving diagnostic checks later so they do not mask stale output.
- `/tmp/surf-pr1456-revision-core.log`: attempted broad integration with revised RX.
- `/tmp/surf-pr1456-revision-original-core.log`: same TX payload failure with
  original RX and only the timeout prerequisite applied.
- `/tmp/surf-pr1456-revision-vsg-final.log`: final VHDL lint.

## Remaining integration and timing limits

The existing bidirectional core payload test still fails before receiver
processing: the client transport payload is zero instead of
`0x1122334455667788`. Its assertion explicitly checks the transmitted frame
before server RX. The same failure occurs with original and revised RX after
applying only timeout saturation. The existing broad close/reopen test also
stops on its initial payload comparison. These failures are not hidden by the
new default RX integration tests. The initially selected extended backpressure
case returned without stimulus because its internal gate did not recognize a
comma-separated testcase selection; that run is not coverage evidence.

Full TX/core/wrapper regressions retain their existing gate and need separate
investigation. This revision does not merge companion TX, monitor, connection
parameter-policy, or core changes simply to turn the suite green.

No FPGA synthesis, resource comparison, or static timing analysis was available.
The segment-size conversion is constrained integer interpretation of the existing
incremented address; simulation cannot establish its fanout or placed timing.
Representative target timing and the outstanding broad integration failure remain
necessary considerations for merge approval of this heavily used code.
