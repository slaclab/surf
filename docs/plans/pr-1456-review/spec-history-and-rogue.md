# RSSI specification, history, and Rogue follow-up

## Specification correction reported

The user reports updating the live Confluence RSSI page after agreeing to remove
BUSY from the prohibited-with-DATA list and explicitly allow DATA+BUSY as
receive-side backpressure information. The attempted live-page retrieval failed,
so the published wording has not been independently verified here. The archived
HTML below remains historical evidence of the contradiction that informed the
original tests; it must not be treated as the corrected current specification.
The RTL and RX test expectation still need to be aligned with the agreed rule.

## Scope and conclusion

Follow-up to the PR 1456 review: determine how the regressions escaped, recover
the saved specifications, trace implementation intent, and compare the receive
contract with `/Users/bareese/rogue`.

The evidence points to three distinct problems: contradictory expected protocol
behavior, incomplete combinations of connection state and backpressure, and a
leaf fixture that does not exercise production checksum timing with consecutive
frames. The PR split then left core integration gated. This is stronger evidence
than simply saying the suite needs more tests.

DATA+BUSY deserves a qualification to the original review: the prohibition was
not invented without a source. One paragraph in the saved Confluence page says
to prohibit it. But that paragraph contradicts the same page's flow-control
section, its Word attachment, existing SURF TX, and Rogue TX/RX. Treating that
paragraph as a sufficient reason to change established wire compatibility was
the error. The compatibility finding and recommendation to preserve DATA+BUSY
remain unchanged.

An additional PR regression was reproduced during this comparison: rejecting
duplicate DATA before buffering also suppresses its valid reverse-direction ACK.

## Sources and provenance

- SURF PR head: `e0a05a9abb9f764355110efd634fc49319889c47`.
- SURF PR base: `f145a9620fe7bfd518effec9879b0a29b7cab507`.
- Saved reference bundle introduced by `459f91e7f` on May 22, 2026.
- Recovered the earlier task directory from `b1d43434e` to
  `/tmp/surf-pr1456-history/docs/plans/rssi-regression/` using `git archive`.
- Primary source: `references/confluence/reliable-slac-streaming-protocol-rssi.html`.
- Also read the Word attachment `references/confluence/attachments/RssiDoc.docx`,
  inspected the connection and flow-control diagrams, and checked the RUDP draft
  header/teardown language. RFC 908/1151 and the RUDP draft are background;
  RSSI explicitly omits transfer-state, auto-reset, and EACK functionality.
- The saved RSSI Discussions files contain SSO/rate-limit responses, not the
  discussion content. No intent is inferred from those failed exports.
- Extracted readable text: `/tmp/surf-pr1456-history/spec-page.txt` and
  `/tmp/surf-pr1456-history/spec-docx.txt`. These are derived reading aids;
  the archived HTML/DOCX remain the sources.
- Rogue checkout: `88ead8fe08be2bf5150f3d15b8bc185fc04d43cf`.
  `Header.cpp` and `Controller.cpp` are unchanged from the Rogue commit
  `e30812114e7e6c338d8ab204d2ec2f61aa1527e8` cited by the PR.
  Rogue's existing unrelated deleted planning files were left untouched.

The July 7 split plan explicitly says to avoid carrying the large local reference
bundle into the replacement PRs. This explains why the files were in the older
branch history but absent from the reviewed PR head and current checkout.

## What the specification actually says about BUSY

The saved HTML header section says:

> User data cannot be present in packets with the NULL, BUSY, or RST bits set.

The same page's flow-control section says:

> the receiver should apply BUSY flag to outgoing data segments

The Word attachment's corresponding header sentence excludes only NULL and RST,
and its flow-control section also calls for BUSY on outgoing DATA. The attachment
metadata says it was last modified October 11, 2016; this alone does not establish
which source is authoritative or explain when the HTML discrepancy appeared.

The earlier `rtl-spec-review.md` repeats the inconsistency internally:

- Item 1 directs tests to reject DATA+BUSY.
- Item 8 directs tests to verify BUSY on outgoing ACK/DATA headers.

Thus the test oracle was contradictory before RTL changes began. The header
generator tests and RX tests can both pass while disagreeing about whether the
same frame is legal. The RUDP background draft has no RSSI BUSY flag and cannot
resolve this RSSI-specific contradiction.

Preservation decision supported by implementation evidence: accept DATA+ACK+BUSY,
interpret BUSY as the peer's receive backpressure, process the header ACK, and
deliver only eligible in-order payload. Do not turn a documentation discrepancy
into an incompatible receiver change without an explicit protocol migration.

## Reconstructed history and intent

| Commit/date | Evidence and significance |
| --- | --- |
| `8b25deb74`, May 28, 2019 | Removed SYN+BUSY rejection to fix dropped SYN when remote BUSY was asserted. This is historical compatibility evidence, not a claim that the current base still accepts SYN+BUSY. |
| `de20189fb`, May 31, 2019 | Fixed BUSY-related TX checksum instability by capturing BUSY and inserting it into DATA, ACK, NULL, and RST headers. DATA+BUSY is longstanding intentional TX behavior. |
| `459f91e7f`, May 22, 2026, 10:09 | Added the saved specifications and the contradictory initial RTL/spec review. |
| `e617d27da`, May 22, 10:49 | Added an opt-in negative DATA+BUSY test, explicitly described as an expectation from the regression plan. |
| `9c42c8ce3`, May 22, 11:48 | Changed RTL to require ACK and exclude BUSY. The commit message explicitly states that intent. |
| `13ab51eb1`, May 22, 11:50 | Removed the known-issue gate and changed the test comment from provisional characterization to an unconditional prohibition. |
| `2f55cf1b9`, May 22, 16:03 | Added SYN staging and final EOF/EOFE checks to prevent malformed SYN parameter publication. This is a sound objective; the saved boundary snapshot was not frozen. |
| `e6151de4a`, May 23, 00:47 | Added READ_S, incremented-address length storage, write-data staging, and final-beat pause handling after integrated payload tests exposed RAM timing problems. The new waiting state omitted connection-close handling. |
| `48678c3d5`, May 23, 01:03 | Moved duplicate DATA rejection ahead of payload buffering after retransmission tests exposed duplicate-buffer side effects. The change also removes the valid-segment event used to qualify incoming ACKs. |
| `b1d43434e`, July 7 | Planned reconstruction of the larger RSSI branch into a foundation plus separate RTL fixes; explicitly gated failing tests and omitted the large references. |
| `93567d65c`, July 7 | Added the reconstructed test foundation, including opt-in core integration. |
| `2c3453294`, July 7 | Reintroduced the RX fixes together and ungated the RX tests; production diff is RssiRxFsm only. |

These commits establish the recorded objectives and sequence. They do not prove
anything about an author's private reasoning or whether other unrecorded testing
occurred. Earlier full-suite pass notes also refer to a different, broader branch
containing companion fixes; they are not proof for this isolated PR stack.

## Why each defect escaped the tests

1. **DATA+BUSY: wrong expected result, not missing stimulus.**
   `test_RssiRxFsm.py:399` deliberately expects a drop, while
   `test_RssiHeaderReg.py:152-157` expects DATA+BUSY generation. The core BUSY
   scenarios send payload in one direction and observe BUSY/ACK returning;
   they do not require DATA delivery in the opposite direction while BUSY is set.
   No test connects those contradictory leaf contracts under duplex pressure.

2. **Paused close/reopen: the relevant combination is absent.**
   The RX leaf configures connection state at setup and does not close while
   the first application beat is paused. The core close/reopen scenario at
   `test_RssiCore.py:987` awaits complete delivery of the first payload before
   closing. It also calls `drain_app_outputs()` after reopening, which discards
   unsolicited output rather than asserting that the new connection starts
   cleanly. That drain is a further coverage weakness; the existing test does
   not actually put the receiver into the stranded READ_S condition.

3. **SYN snapshot: fixture timing avoids the hazardous overlap.**
   `send_transport_word()` returns the source to idle and waits an extra cycle
   after every beat. `send_syn_segment()` uses synthetic checksum success and
   explicitly asserts checksum-valid after sending the header. The leaf wrapper
   contains registered RAM but no real checksum block. Therefore this suite
   checks isolated frames at one favorable timing pattern, not a following
   frame held valid while RssiChksum completes. The real-checksum review probe
   catches the failure without corrupting the SYN.

4. **State enum: no cross-language agreement check.**
   READ_S renumbered diagnostics but the change did not update PyRogue. Tests
   of a register accepting arbitrary state bits do not validate what the live
   RX FSM emits against the Python enum.

5. **Duplicate ACK: the scoreboard watches payload and drop status only.**
   The duplicate test expects no second application output and a drop pulse.
   It does not change the ACK number on the duplicate or verify TX-window
   release. It consequently rewards suppressing the entire packet even when
   one header field must still advance the opposite direction.

At the PR revision, core tests are gated by `RUN_RSSI_KNOWN_ISSUE_TESTS` and CI's
pytest command does not enable that flag. The PR reports 4 passed/19 skipped for
the RSSI suite. The README at this revision nevertheless calls its broad
integration inventory default coverage. The existing integration attempt also
fails on the known connection timeout-counter bounds issue. A test's presence,
or a historical broader-branch pass, does not mean it protected this PR.

## Comparison with the local Rogue implementation

| Contract | Rogue source behavior | SURF implication |
| --- | --- | --- |
| DATA plus local BUSY | `Controller::applicationRx()` sets ACK; `transportTx():609-615` and `retransmit():662-668` add BUSY according to appQueue occupancy, including DATA. | The PR must continue accepting these deployed wire combinations. |
| Incoming BUSY | `transportRx():221-235` handles ACK and updates remote BUSY before selecting payload behavior. `stateOpen()` suppresses retransmission while remote BUSY is asserted. | BUSY and payload validity are independent decisions. |
| Duplicate with newer ACK | The ACK is consumed before duplicate/out-of-window payload handling at `transportRx():221-330`. Retransmit refreshes ACK fields. | Early payload rejection must preserve validated reverse-direction ACK progress. |
| Header ownership | `Header::verify():119-150` validates bytes belonging to one Frame; Controller rejects errors/failed verification before consuming its metadata. | A staged RTL header must likewise remain associated with its accepted frame through checksum completion. |
| SYN followed by DATA | `stateSendSynAck():869-874` transmits SYN+ACK and immediately enters StOpen; `applicationRx()` then permits sending DATA. | Back-to-back SYN+ACK/DATA is a realistic peer behavior, unlike the RTL server's WAIT_ACK sequencing. |
| Close cleanup | `stateError():960-968` moves to StClosed and resets appQueue, out-of-order queue, and state queue. DATA is queued only in StOpen. | RTL must invalidate pending application work across connection lifetime changes. Static source comparison does not prove Rogue free of concurrent teardown races. |
| Out-of-order buffering | Rogue queues eligible future sequences; the current hardware rejects them and relies on retransmission. | This established implementation difference does not require adding software-style reordering to this PR. |
| Strict flag validation | Rogue does not decode/reject EACK explicitly and its DATA RX branch does not require ACK, although its DATA transmitter sets ACK. | Rogue is a compatibility reference, not a complete normative invalid-packet oracle. |
| SYN extent/checksum options | Header verify checks minimum header availability and checksum; it does not enforce exact total SYN length or implement the RTL's checksum-disable option. | The PR's stricter SYN policy needs its own explicit contract/tests; citing Rogue verify alone does not establish equivalence. |

Additional pre-existing differences noted during source comparison, outside this
PR: Rogue Header reads/writes `connectionId` with a single `data[18]` access,
whereas RTL maps all 32 bits; Rogue frame allocation caps payload-plus-header
against its segment-size limit, while SURF documentation describes a payload
limit. These deserve separate interoperability characterization, not incidental
changes in this RX fix. No claim of complete RSSI equivalence is justified by
matching ordinary payload delivery alone.

## Additional reproduced regression: duplicate DATA loses a newer ACK

PR location: `RssiRxFsm.vhd:425-437`. Core consumer:
`RssiCore.vhd:780` computes `s_rxAck = s_rxValidSeg and s_rxFlags.ack and s_connActive`.

Reproduction: accept and deliver DATA sequence 1/ACK 0, then receive the same
DATA sequence carrying ACK 1 with a valid header and legal ACK window. The base
produces the valid-segment/ACK event and no duplicate application payload.
The PR drops before DATA_S, so that ACK event never occurs. The peer may be
acknowledging newly received traffic when retransmitting an older payload;
Rogue explicitly refreshes that header on retransmit. The consequence is lost
TX-window progress and potentially unnecessary retransmission or stalled duplex
progress, depending on later ACK traffic.

The directed test fails on head and passes with only the base RX RTL restored.
It observes the exact signals used by the production ACK qualification; it does
not establish a complete-core deadlock or connection-loss scenario. Preserve ACK
processing for a validated duplicate while preventing duplicate RAM writes and
application delivery. Treat this as an additional P2 review finding.

Test: `/tmp/surf-pr1456-review/tests/protocols/rssi/test_pr1456_duplicate_ack_review.py`.
Logs: `/tmp/surf-pr1456-duplicate-ack-head.log` and
`/tmp/surf-pr1456-duplicate-ack-base.log`. Both comparisons forced compilation;
the temporary RTL was subsequently restored to the PR head.

## Recommended verification before merge

1. Resolve and document the actual flag compatibility matrix with citations to
   the contradictory sources and deployed peer behavior. Require positive RX
   coverage for the combinations generated by SURF and Rogue.
2. Add RX+RssiChksum+production-RAM tests with contiguous frames, input gaps,
   stalls at each SYN word, and the next frame held valid. Verify that all
   negotiated fields remain those of the checksummed frame.
3. Cross connection close/reopen with each application state and first/middle/
   last-beat pause. Assert no old DATA or ACK state survives. Do not silently
   drain post-reopen output in these checks.
4. Exercise simultaneous bidirectional DATA with one side BUSY and duplicate
   retransmits carrying newer ACKs, including sequence wrap and window release.
5. Unblock the existing connection-FSM bounds issue and make a practical core
   integration subset a required check for this RX change. Companion fixes can
   be explicit stack prerequisites rather than hidden test-only alterations.
6. Add real Rogue-to-RTL interoperability using pinned builds. Current SURF
   integration pairs RTL with RTL; Rogue's existing UDP loopback pairs software
   with software and is skipped on macOS. Neither proves cross-implementation
   compatibility. No live Rogue-to-RTL run was performed in this follow-up.
7. Preserve existing diagnostic encodings and check the PyRogue enum against
   observed RTL states when adding READ_S.

No production edits, staging, commits, GitHub comments, or Rogue modifications
were made. This follow-up adds documentation and isolated review stimulus only.
