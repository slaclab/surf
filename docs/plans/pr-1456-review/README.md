# PR 1456 review

Review the RSSI receive FSM change for regressions in heavily used infrastructure.

- PR: https://github.com/slaclab/surf/pull/1456
- Base: `f145a9620fe7bfd518effec9879b0a29b7cab507`
- Head: `e0a05a9abb9f764355110efd634fc49319889c47`
- Scope: receive filtering, SYN parameter publication, payload RAM timing,
  application pause/close behavior, and diagnostic compatibility.
- Follow-up: [specification, history, and Rogue comparison](spec-history-and-rogue.md)
  explains the coverage failures, resolves the DATA+BUSY source contradiction,
  and records an additional reproduced duplicate-ACK regression.
- Status: historical review of the original PR head. The user subsequently
  authorized repairs; see [implementation and current validation](implementation.md).
  The findings and original-head results below are retained as evidence.

## Findings

### P1: Preserve DATA carrying BUSY

`RssiRxFsm.vhd:419-423` requires `busy=0` before accepting DATA.
`RssiHeaderReg.vhd:164` explicitly emits DATA with the captured BUSY bit;
`RssiCore.vhd` connects that bit to local receive-application FIFO occupancy.
BUSY describes backpressure in the opposite direction and does not make this
payload illegal. A backed-up receiver that is also transmitting can therefore
send valid DATA that the changed peer discards. The piggybacked ACK is also lost
because the core qualifies ACK handling with `rxValidSeg`.

The foundation header-generator test explicitly expects DATA+ACK+BUSY, while the
RX test enabled by this PR calls that same combination illegal. Keep legal BUSY
propagation and change that RX expectation; cover bidirectional traffic with one
application paused.

Directed proof: send an in-order, two-word DATA+ACK+BUSY frame with valid checksum
status and sequence 1. Base pulses `rxValidSeg`; head times out waiting for it.

### P1: Abort the new READ state when the connection closes

`RssiRxFsm.vhd:708-739` does not handle `connActive_i=0`. Selection now leaves
`CHECK_BUFFER_S` even while the application is paused. Previously that first-beat
wait remained in `CHECK_BUFFER_S`, where the inactive-connection path still ran.

Directed proof: buffer two DATA words with application pause asserted, close the
connection, receive a valid new SYN with sequence `0x40`, reopen, and release
pause. Head emits application output despite receiving no DATA for the new
connection; base remains silent and initializes the application ACK sequence
to `0x40`. The new SYN clears window metadata, but the stranded READ state does
not recheck occupancy/type before using the old RAM contents. The reset metadata
has a full keep mask and zero last-word index, so this can emit an old payload
word as a new one-word frame and then overwrite receive ACK bookkeeping.

Give connection closure priority while waiting for the first application beat,
and exercise close/reopen while paused in addition to ordinary reset.

### P2: Capture SYN EOF once, from the accepted final header beat

`RssiRxFsm.vhd:495-502` resamples SYN fields whenever the registered input is valid,
while `rxHeaderAddr` stays at 2 awaiting checksum completion. The next frame can
already be valid while stalled. Its header then overwrites `synEof`/`synEofe`
before the new checks at lines 518-519 run, causing a valid SYN to be rejected
according to the following frame's boundary flags.

Directed proof uses the real `RssiChksum`, connected exactly as in `RssiCore`,
plus the leaf wrapper's registered segment RAM. A contiguous valid SYN passes
alone. The same SYN immediately followed by a DATA header and payload fails
acceptance on head and passes on base. The sender holds each beat until ready;
no malformed SYN or artificial checksum-valid timing is needed. Freeze the
final header snapshot after its accepted beat until validation completes.

### P2: Preserve or update the public application-state decoding

`RssiRxFsm.vhd:709,743,784` changes the numeric state values to
`READ=1`, `DATA=2`, `SENT=3`. `python/surf/protocols/rssi/_RssiCore.py:447-451`
still decodes `1=DATA`, `2=SENT`, and has no value 3. Existing PyRogue diagnostics
thus misreport the state. Prefer retaining DATA=1 and SENT=2 and assigning the
new state an unused value, then adding its enum entry in the same change.

### P2: Preserve the ACK carried by a duplicate DATA segment

Follow-up source comparison with Rogue and a new directed probe show that
`RssiRxFsm.vhd:425-437` drops the entire duplicate before the valid-segment
event used by `RssiCore` to qualify an incoming ACK. A duplicate DATA segment
can carry a newer ACK for the opposite direction. With sequence 1 delivered,
resending sequence 1 with ACK 1 produces ACK progress and no second payload on
the base, but loses the ACK event on the PR head. Preserve validated header ACK
handling while suppressing duplicate payload-buffer writes. See the follow-up
for the test, source evidence, and limits of the reproduction.

## Validation and limits

Environment: GHDL 6.0.0 and the installed cocotb 2.0.1 environment. The source
was exported from the immutable PR head with `git archive`; the PR head was
rechecked remotely at the end and had not changed.

| Check | Result |
| --- | --- |
| Isolated Ruckus import | Passed; Tcl needed sandbox escalation for temporary-file creation |
| Original PR `test_RssiRxFsm.py` | 2 pytest cases passed |
| Original PR `test_RssiHeaderReg.py` | 1 pytest case passed, including DATA+BUSY generation |
| DATA+BUSY acceptance probe | Fails on head, passes with base RX RTL |
| Paused close/new-SYN/reopen probe | Fails on head, passes with base RX RTL |
| Real-checksum standalone SYN control | Passes on head and base |
| Real-checksum back-to-back SYN acceptance | Fails on head, passes with base RX RTL |
| Direct-core integration | Stops at `RssiConnFsm.vhd:237` timeout-counter bounds check with both head and base RX RTL |

The base comparison replaced only `RssiRxFsm.vhd` in the isolated head export;
it is the only production file changed by the PR. Each comparison forced a fresh
simulation compile. The final isolated source was restored to the PR head.
The initial directed suite contains four cocotb scenarios: head has one pass and three
failures; base passes all four. Two pytest launchers group those scenarios.
The follow-up duplicate-ACK probe adds a fifth scenario, which also fails on
head and passes with the base RX RTL.

The attempted core scenarios were negotiation, bidirectional delivery, partial
keep/EOFE, transport stalls, and close/reopen. The integration failure prevents
claiming those scenarios passed; it is a pre-existing blocker, not an additional
PR finding. No hardware, synthesis, timing-closure, or complete regression proof
was obtained. Leaf tests alone do not establish readiness to merge this change.

## Reproduction material

Temporary source and simulator artifacts are in `/tmp/surf-pr1456-review`.
Review-only stimulus is in:

- `tests/protocols/rssi/test_pr1456_review.py`
- `tests/protocols/rssi/test_pr1456_checksum_review.py`
- `protocols/rssi/v1/wrappers/RssiRxChecksumReviewWrapper.vhd`

From that temporary checkout, run:

```sh
.venv/bin/python -B -m pytest -q -p no:cacheprovider \
    tests/protocols/rssi/test_pr1456_review.py \
    tests/protocols/rssi/test_pr1456_checksum_review.py
```

Logs are `/tmp/surf-pr1456-rx-tests.log`, `/tmp/surf-pr1456-header-tests.log`,
`/tmp/surf-pr1456-final-directed-head.log`, `/tmp/surf-pr1456-directed-base.log`,
`/tmp/surf-pr1456-checksum-base.log`, `/tmp/surf-pr1456-core-tests.log`, and
`/tmp/surf-pr1456-core-base.log`. Temporary files are not durable regression
coverage; promote the defect checks into the RSSI suite when implementing fixes.

No production source in the user's checkout was edited, no files were staged
or committed, and no GitHub review or comment was posted. These notes are the
only addition to the user's working tree. Next step: address the five findings,
then rerun focused leaf tests and unblock the core integration checks.
