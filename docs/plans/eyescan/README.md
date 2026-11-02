# Statistical eye scan for the GT drivers

## Goal and scope

A statistical eye scan for the surf Xilinx GT channel drivers: GTHE3 (UltraScale
GTH) and GTYE4 (UltraScale+ GTY) are covered, the GTP and GTX drivers are not
supported. Usage and the API are in
[python/surf/xilinx/README.md](../../../python/surf/xilinx/README.md); this note
keeps the design and validation record.

## Current status

- Emulation: complete for GTHE3 (activation, point measurement, bathtub, tail
  fits, abort and restore); the tests are listed in
  [tests/xilinx/eyescan/README.md](../../../tests/xilinx/eyescan/README.md).
- Hardware: exercised on a KCU1500 (GTHE3). The ResetRx question is answered
  (below). The first one-reset battery, judged by the one-reset contract below,
  failed two repeatability checks on lane 6 (same-reset decade spread 1.21 counts
  against a limit of 1.0, and one left tail that is not monotone, with a 17.7
  sigma drop) and the summed prescale 6 vs 8 test was indeterminate on lane 4 (4
  comparable counts, minimum 5, median -0.132 decade). One repeat battery, fixed
  before the card was touched and judged on its own under the same tolerances,
  passed every repeatability check and the summed prescale 6 vs 8 test on all four
  lanes (same-reset decade spread 0.23 to 0.47 counts, 6 comparable counts per
  lane). The spread across RX resets is measured and reported, not a limit, and
  it is large in both batteries (below). `GTHE3.hwVerified` is `True` on the
  strength of the repeat battery, with the first battery's failure kept on
  record, and is pinned by a test.
- 2D eye and margin summary: run on GTHE3 and measured on KCU1500 lanes 4 to 7
  (section "2D eye and margin (lanes 4 to 7)"). Result files (an npz with
  `eye_`, `horz_` and `vert_` prefixed arrays and a JSON meta string, a
  long-form CSV, bathtub and eye PNGs) and the PyDM surface (`Start`, `Stop`,
  `EtaSeconds`, summary variables) are in place.
- GTYE4: the emulation suite runs the same tests over the GTHE3 and GTYE4 models.
  On a Varium C1100 (lanes 4 to 7, one card) the phase-unification A/B did not
  separate the `sign` and `rate` rules at 6.25, 10.3125, 15.46875 or 25 Gb/s
  (every run passed every criterion under both), so the family default stays
  `sign` (section "GTY phase unification"). The 6.25 Gb/s battery under `sign`
  passed every gating check on all four lanes on its first run, so no rerun was
  needed; the vertical Q-scale fit gate failed on all four lanes, as on GTHE3
  (section "GTY bathtub, eye and margin at 6.25 Gb/s"). The GTH lanes of the
  KCU1500 still pass after the GTY change. `GTYE4.hwVerified` is `True` on the
  strength of that one battery on one card and one image, pinned by a test;
  `GTHE3.hwVerified` stays `True`.

- Lanes without data: a lane whose eye-centre error counter stays full after the
  RX resets, or that counts no errors at either end of the UI, now scans to
  `CLOSED` with a warning naming both causes (sampler out of step, or link
  closed or unlocked) instead of being refused with `NOT_ENABLED`; a missing hook
  or a ready that never returns still ends `NOT_ENABLED`. A margin cross with no
  position at the bathtub floor is labelled `closed`. An interrupted re-arm sets
  both enables again, a Start refused because a scan is running only fills
  `Message`, one worker runs per scan, a result is published before the scan lock
  is released, and an analysis failure after a scan keeps and saves the counts.
  Measured on QSFP[0] with no fiber (section "QSFP[0] no-fiber result").

## Hardware setup

- Card: Xilinx KCU1500, image `XilinxKcu1500Pgp4_6Gbps`, GitHash
  `0xdd69c8bd045862a6631c81899e06a321c68cf314`.
- Lanes 4 to 7 (GTH), QSFP[1] fiber loopback, idle PGP4 link, software PRBS
  disabled, no polling and no read at start.
- Decoded at every scan start: RX_DATA_WIDTH 32 bits, RXOUT_DIV 2, which gives
  a horizontal range of +-64 counts (129 positions, 1/128 UI per count). DFE
  is the default: the error and bit counts of UT_SIGN 0 and 1 are summed; LPM
  uses UT_SIGN 0 only.
- RX reset through the PgpRoot hook: `Pgp4AxiL` `Ctrl.ResetRx` pulsed,
  `RxStatus.PhyRxActive` as the ready signal. No RTL, link configuration or
  `Pgp4AxiL` bit other than `ResetRx` was touched.
- GTY: Varium C1100, lanes 4 to 7 (GTYE4) over the QSFP[1] fiber loopback, idle
  PGP4 link, software PRBS disabled, no polling and no read at start, the same
  PgpRoot `ResetRx` hook as above. The images ran in this order, each flashed
  before its arm: `XilinxVariumC1100Pgp4_15Gbps` (15.46875 Gb/s, Git Hash
  `35b32a001817415e537d83132d1f4107b0decd68`),
  `XilinxVariumC1100Pgp4_10Gbps` (10.3125 Gb/s, Git Hash
  `9dd29a2c2e594cf2735e7bdabaf1b615d647395d`),
  `XilinxVariumC1100Pgp4_25Gbps_Fec` (25 Gb/s with RS-FEC, same Git Hash) and
  `XilinxVariumC1100Pgp4_6Gbps` (6.25 Gb/s, Git Hash
  `dd69c8bd045862a6631c81899e06a321c68cf314`, also used for the battery).
  Decoded at every scan start: RX_DATA_WIDTH 64 bits at every rate; RXOUT_DIV 1
  at 10.3125, 15.46875 and 25 Gb/s (horizontal range +-32 counts, 1/64 UI per
  count) and 2 at 6.25 Gb/s (+-64 counts, 1/128 UI per count). QSFP CDR state
  was not read back. It was most likely disabled for every C1100 run up to and
  including the 6.25 Gb/s battery: the 15.46875 and 10.3125 Gb/s images turn it
  off (the core writes QSFP register 98 = 0x00 through the CMS mailbox
  periodically) and the later images do not turn it back on. After the QSFP
  module was re-seated (CDR back at its power-on state) the 25 Gb/s arm was
  repeated on the same image (below); the other arms and the battery were not.

## ResetRx result

`Pgp4AxiL.ResetRx` through the hook is sufficient on these GTH lanes. It was
not shown to be necessary.

- True cold card (all four lanes OFF with 0 samples) and three soft re-cold
  repetitions (enables cleared plus a reset): enable plus ResetRx reached END
  with samples and both enables set on 4 of 4 lanes cold and 12 of 12
  lane-repetitions soft cold.
- Enabling the sampler with no reset at all also reached END with samples and
  both enables set on every lane, true cold and soft cold (4 of 4 and 12 of
  12). A missing reset therefore did not give `NOT_ENABLED` on this hardware.
- Sampler quality without a reset: about half of the un-reset activations
  returned END with roughly 4.0k to 4.1k samples instead of 65535. In one run
  that scanned an un-reset sampler, the two lanes that had about 4k samples
  returned a closed bathtub in 0.2 s with the error counter saturated at all
  129 positions, while the two lanes with 65535 samples gave a normal bathtub.
  That is one observation per lane, so it is a hypothesis only: an enable
  without a reset can leave the sampler degraded while it still reports END
  with samples. Every activation that followed a reset reached 65535 samples.
- Relock timing: 40 timed resets (10 per lane) all returned ready, 0.551 to
  0.553 s after the pulse. The fall of `PhyRxActive` was never observed (it
  ends inside one poll), so that figure is bounded by the 0.5 s fall wait and
  is an upper bound, not the relock time. The link counters rose once per
  reset, so each reset did take the link down and it recovered.
- Because of the degraded-sampler observation, the `Auto` reset policy now
  resets the RX on every activation instead of trusting enables that are
  already set. `Always` behaves the same, `Never` only sets the enables.
- The same degraded state follows about every second RX reset on the C1100
  GTYE4 lanes (15.46875 Gb/s, W 64): the probe at the eye centre fills the
  error counter (65535 errors in about 2048 samples, 0.25 per UT accumulation)
  and every scan point saturates, while the other resets give a clean centre (0
  errors in 65535 samples). Nearly every reset flips between the two states,
  but one of 33 observed resets kept the out-of-step state. The activation
  therefore also requires the centre probe to leave its error counter short of
  full. A full counter calls the hook again and ends `NOT_ENABLED` with the
  counts in the message when the retries do not clear it or the policy is
  `Never`, so an out-of-step sampler is never reported as a closed eye. This refusal was
  replaced later: a centre that stays full now scans to `CLOSED` with a warning
  (section "QSFP[0] no-fiber result").
- What the out-of-step state is, and why one reset rule does not fit every
  lane (C1100 QSFP[1], lanes 4 to 7, 15.46875 Gb/s): the frozen `es_rdata` and
  `es_sdata` words after an out-of-step probe show error bits exactly where a
  data bit differs from the bit two positions away, on every lane, so the
  offset samples are the data two bits (2 UI) off, far outside the +-32 count
  range. Setting the enables draws that alignment at random (16 of 30
  re-enables in step). A plain RX reset with the enables held then flips it on
  lanes 4 and 6 (about 96 % of resets) but never changes it on lanes 5 and 7
  (0 flips in 60 resets), so the reset-only retry left lane 5 `NOT_ENABLED`
  after 5 resets in the A/B. `ES_HORZ_OFFSET[11]` changes nothing, at the
  reset or after it, and every driver-defined attribute word is the same on
  the four lanes. The first retry is therefore a plain reset, and every later
  retry clears both enables for `REARM_WAIT` (0.1 s), sets them again and then
  resets, a fresh draw on every lane. `SYNC_RESETS` (12) allows ten such
  draws, so a lane whose resets keep the state ends `CLOSED` with the
  two-cause warning about once in a thousand activations. Setting the enables on a running GTYE4 lane drops the
  PGP link once (`LinkDownCnt` and `PhyRxInitCnt` rise before the hook pulse),
  so a re-armed retry costs one link drop beyond its reset; clearing them does
  not.
- Missing hook, on hardware: with the hook removed and policy `Auto`, all four
  lanes return `NOT_ENABLED` in 2 ms with the message "cannot reset the RX
  before the scan with policy Auto: no RX reset hook registered: call
  EyeScan.setRxReset(reset, ready)". Nothing is scanned and no enable is
  written. Before the policy change this negative could not be produced.

## Bathtub checks (lanes 4 to 7)

### One-reset contract

Repeatability is judged by the physical position of the eye, not by a per-point
Poisson test: a tail changes by about a decade of BER per horizontal count, so a
drift of a tenth of a count is larger than the Poisson error of a 100-error point
and a 3-sigma point test fails on a stable eye. Settings are judged on one RX
reset; the spread across RX resets is measured and reported, not a limit. The
tolerances below were fixed before the first one-reset battery and were not
changed for the repeat battery. One count is 1/128 UI at RXOUT_DIV 2.

| Quantity | Tolerance |
|---|---|
| Opening at the 1e-9 floor, 3 back-to-back runs on one RX reset | within 2 counts (0.016 UI) |
| Tail position at each BER decade from 1e-3 to 1e-8, 3 runs on one RX reset | within 1 count (0.008 UI) |
| Fixed prescales 6 and 8 on one RX reset, each count summed over 32 unsaturated accumulations at prescale 6 and 8 at prescale 8 | at least 5 comparable counts per lane and a median BER ratio within 0.1 decade |
| Opening and tail positions across RX resets, measured over 10 RX resets per lane | reported, not a limit |

A count of the prescale pair is comparable when every individual accumulation of
both sets holds at least 1000 samples and has no UT error counter at full scale
(65535), and the errors summed over the accumulations and UTs are at least 100 in
each set. The BER of a set is its summed errors over its summed bits. One
accumulation is one fixed-prescale sweep; the prescale 6 and 8 sweeps are
interleaved (one prescale 8 sweep after every four prescale 6 sweeps) on one RX
reset, so a slow drift reaches both sets. The opening at the floor is the longest
contiguous run of measured points whose one-sided Poisson upper bound (95
percent) is at or below 1e-9. A tail position at a decade is interpolated
linearly in log10(BER) between the first pair of counts that straddles the
decade.

### First one-reset battery results

Per lane: 3 adaptive bathtubs back to back on one RX reset (the first after the
reset), 10 adaptive bathtubs each after its own RX reset, 32 fixed-prescale-6 and
8 fixed-prescale-8 sweeps on one RX reset, and on lane 4 a SIGINT abort. All
lanes were full range (129 counts, W=32, RXOUT_DIV 2).

| Check | Outcome |
|---|---|
| Full range and width, activation, no BER 0, finite upper bound at every measured point | pass on every lane |
| Opening from the engine equals an independent recomputation | pass on every lane |
| Tails monotone | FAIL on lane 6: the left tail of one reset run has one drop of 17.7 sigma (15 points); every other run on every lane passes |
| Continuous through counts -2 to +2, Q-scale fit flags consistent with the fits, UT_SIGN comparison present in every DFE run | pass on every lane |
| Register preservation after success, and after the lane 4 abort | pass (abort: status ABORTED, registers restored) |
| One RX reset per same-reset set and one RX reset before each reset run (link counters) | pass on every lane |
| Same-reset opening spread | pass on every lane (lane 6 at the limit, 2 counts) |
| Same-reset decade spread | FAIL on lane 6 (1.21 counts, limit 1.0) |
| Summed prescale 6 vs 8 | lane 4 INDETERMINATE (4 comparable counts, minimum 5); lanes 5, 6 and 7 pass with 5 comparable counts |

Spreads on one RX reset, in counts (limit in the header):

| Lane | Same-reset opening (2) | Same-reset decade (1.0) |
|---|---|---|
| 4 | 0 | 0.30 |
| 5 | 1 | 0.61 |
| 6 | 2 | 1.21 FAIL |
| 7 | 0 | 0.16 |

Summed prescale 6 vs 8 (median of log10(BER at prescale 8 / BER at prescale 6)):

| Lane | Comparable counts (min 5) | Median (limit 0.10) | Result |
|---|---|---|---|
| 4 | 4 | -0.132 | INDETERMINATE |
| 5 | 5 | -0.009 | pass |
| 6 | 5 | +0.010 | pass |
| 7 | 5 | +0.000 | pass |

Lane 4 is indeterminate because fewer than 5 counts are comparable; its median
lies outside the 0.10 decade limit as well. The window stays narrow: the outer
counts saturate and a few counts next to the comparable ones fall short of 100
summed errors in one set. The comparable counts are on the two tails (counts -57
to -50 and +50 to +55 across the lanes).

### Spread across RX resets (reported, not a limit)

10 RX resets per lane, one adaptive bathtub after each. Two resets of a lane share
a cluster when all twelve tail positions (both tails, decades 1e-3 to 1e-8) agree
within 1 count (single linkage); a reset deviates when a tail position differs
from the lane median over resets by more than 1 count.

| Lane | Opening min / median / max (counts) | Opening spread, counts (UI) | Decade spread, counts (UI) | Cluster sizes | Deviating resets |
|---|---|---|---|---|---|
| 4 | 98 / 106 / 106 | 8 (0.0625) | 6.58 (0.0514) | 6, 3, 1 | 1, 3, 6, 7 |
| 5 | 94 / 101.5 / 103 | 9 (0.0703) | 5.28 (0.0412) | 5, 3, 2 | 3, 4, 9, 10 |
| 6 | 89 / 95.5 / 104 | 15 (0.1172) | 8.33 (0.0650) | 4, 4, 2 | 2, 5, 6, 7, 8, 9, 10 |
| 7 | 96 / 101 / 103 | 7 (0.0547) | 5.16 (0.0403) | 5, 3, 2 | 2, 3, 4, 5, 8 |

- Movement class from the classifier: ENGINE_DEFECT_SUSPECTED (kind none). The only
  classification note is the lane 6 same-reset decade spread of 1.21 counts, above
  the 1 count movement limit. It is reported, gates nothing, and was not
  investigated further.
- The large moves are mostly changes of opening width with a small common shift:
  resets 3, 4 and 10 on lane 5 narrow the opening by 7.4 to 7.7 counts with a
  common shift within 0.3 counts; resets 2 and 5 to 9 on lane 6 change it by 5.4 to
  7.5 counts; resets 2, 3, 4, 5 and 8 on lane 7 by 2.3 to 3.8 counts; reset 6 on
  lane 4 narrows it by 6.87 counts with a common shift of +1.83 counts.
- Cross-lane: 9 of the 10 resets deviate on two or more lanes (reset 3 on lanes
  4, 5 and 7); only reset 1 deviates on one lane. Lane 6 has the longest run of
  consecutive deviating resets (6, resets 5 to 10).

Practical rule: compare settings (prescale, DFE against LPM, step) on one RX
reset. Runs that each follow their own reset differ by the reset-to-reset
movement as well as by the setting.

### Openings

Openings (UI) over the 13 adaptive runs of each lane (3 on one reset, 10 each
after its own reset), counted with the Poisson upper bound at 1e-9 and
extrapolated to 1e-12 from the Q-scale tail fits (every adaptive run reports
`extrapolated` with sufficient data):

| Lane | At 1e-9 | At 1e-12 (extrapolated) |
|---|---|---|
| 4 | 0.7656 to 0.8281 | 0.7170 to 0.7918 |
| 5 | 0.7344 to 0.8047 | 0.6757 to 0.7604 |
| 6 | 0.6953 to 0.8125 | 0.6373 to 0.7791 |
| 7 | 0.7500 to 0.8047 | 0.7099 to 0.7647 |

The fixed-prescale runs end CLOSED with no opening at 1e-9, as expected when a
fixed prescale cannot prove the floor. Their 1e-12 extrapolations are 0.695 to
0.799 UI; 7 of the 160 fixed-prescale sweeps (all on lane 4) had insufficient
data for the fit.

### Repeat battery results

One repeat was decided before the card was touched. It ran the same procedure on
lanes 4 to 7 of the same image, was judged on its own under the same
tolerances, and the first one-reset battery's result stays on record above.

| Check | Outcome |
|---|---|
| Full range and width, activation, no BER 0, finite upper bound at every measured point | pass on every lane |
| Opening from the engine equals an independent recomputation | pass on every lane |
| Tails monotone | pass on every lane |
| Continuous through counts -2 to +2, Q-scale fit flags consistent with the fits, UT_SIGN comparison present in every DFE run | pass on every lane |
| Register preservation after success, and after the lane 4 abort | pass (abort: status ABORTED, registers restored) |
| One RX reset per same-reset set and one RX reset before each reset run (link counters) | pass on every lane |
| Same-reset opening spread | pass on every lane (1 count, limit 2) |
| Same-reset decade spread | pass on every lane |
| Summed prescale 6 vs 8 | pass on every lane with 6 comparable counts |

Spreads on one RX reset, in counts, with the first one-reset battery beside them:

| Lane | Same-reset opening, repeat (first) | Same-reset decade, repeat (first) |
|---|---|---|
| 4 | 1 (0) | 0.47 (0.30) |
| 5 | 1 (1) | 0.33 (0.61) |
| 6 | 1 (2) | 0.29 (1.21 FAIL) |
| 7 | 1 (0) | 0.23 (0.16) |

Summed prescale 6 vs 8 (32 accumulations at prescale 6 and 8 at prescale 8 on
one RX reset), with the first one-reset battery beside it:

| Lane | Comparable counts, repeat (first) | Median, repeat (first) | Result, repeat (first) |
|---|---|---|---|
| 4 | 6 (4) | -0.005 (-0.132) | pass (INDETERMINATE) |
| 5 | 6 (5) | -0.010 (-0.009) | pass (pass) |
| 6 | 6 (5) | -0.023 (+0.010) | pass (pass) |
| 7 | 6 (5) | -0.012 (+0.000) | pass (pass) |

The comparable counts of the repeat battery are on the two tails (lane 4 -58 to
-56 and +52 to +54, lane 5 -54 to -52 and +54 to +56, lane 6 -56 to -54 and +53
to +55, lane 7 -54 to -52 and +51 to +53).

Across RX resets (reported, not a limit), 10 RX resets per lane with the cluster
and deviation rules above:

| Lane | Opening min / median / max (counts) | Opening spread, counts (UI) | Decade spread, counts (UI) | Cluster sizes | Deviating resets |
|---|---|---|---|---|---|
| 4 | 98 / 105 / 106 | 8 (0.0625) | 6.54 (0.0511) | 4, 4, 2 | 2, 4, 5, 6, 7, 8, 9, 10 |
| 5 | 94 / 101.5 / 103 | 9 (0.0703) | 5.40 (0.0422) | 4, 4, 2 | 1, 2, 4, 5, 6, 8, 9, 10 |
| 6 | 89 / 101 / 104 | 15 (0.1172) | 8.11 (0.0634) | 5, 3, 2 | 1 to 10 |
| 7 | 96 / 101 / 103 | 7 (0.0547) | 4.97 (0.0388) | 4, 3, 3 | 1, 2, 5, 6, 7, 9, 10 |

- Movement class from the classifier: ENGINE_DEFECT_SUSPECTED (kind none). The
  only classification note is a one-sided move on lane 7, reset 1 (left tail
  -2.44 counts, right tail +0.26). It is reported, gates nothing, and was not
  investigated further.
- The shifts repeat: on lane 4, resets 5, 7, 9 and 10 move the left tail by about
  +5 counts and the right tail by -1.4 to -1.8 counts (opening 98 to 99 counts
  against 105 to 106); on lane 5, resets 1, 4, 8 and 9 move the left tail by +3.5
  to +3.9 counts and the right tail by -3.1 to -3.3 counts; on lane 6, resets 2
  and 3 move the left tail by +4.5 counts and the right tail by -5.3 counts.
- Cross-lane: 9 of the 10 resets deviate on two or more lanes (resets 2, 5, 6, 9
  and 10 on all four lanes); only reset 3 deviates on one lane (lane 6). Lane 6
  deviates on all 10 resets; the longest run of consecutive deviating resets is 7
  on lane 4 and 3 on lanes 5 and 7.
- Against the old three-reset limits, which are no longer limits, the opening
  spread of lane 6 (15 counts, limit 10) and the decade spread of lanes 4 (6.54)
  and 6 (8.11) against 6.0 would fail.

Openings (UI) over the 13 adaptive runs of each lane (3 on one reset, 10 each
after its own reset), at 1e-9 with the one-sided Poisson upper bound and
extrapolated to 1e-12 from the Q-scale tail fits (every adaptive run reports
`extrapolated` with sufficient data):

| Lane | At 1e-9 | At 1e-12 (extrapolated) |
|---|---|---|
| 4 | 0.7656 to 0.8281 | 0.7181 to 0.7911 |
| 5 | 0.7266 to 0.8047 | 0.6673 to 0.7647 |
| 6 | 0.6953 to 0.8125 | 0.6365 to 0.7811 |
| 7 | 0.7500 to 0.8047 | 0.7059 to 0.7604 |

The fixed-prescale runs end CLOSED with no opening at 1e-9; their 1e-12
extrapolations are 0.736 to 0.791 UI, and none of the 160 fixed-prescale sweeps
had insufficient data for the fit.

### Earlier results

- Three-reset rerun (3 runs on one RX reset, 3 runs each after its own reset,
  unsummed prescale 6 vs 8): passed the same-reset checks on every lane, failed
  its across-reset limits (lane 4 decade spread 6.17 counts; lane 6 opening 13
  counts and decade spread 8.11 counts) and the unsummed prescale comparison
  (4, 4 and 3 comparable counts on lanes 4, 5 and 7).
- First battery (3 adaptive bathtubs per lane with their own resets, fixed
  prescale 4 and 8, an LPM run on lane 4, a SIGINT abort): judged with a 3-sigma
  Poisson point test, which failed on stable eyes for the reason given above. Its
  other outcomes stand: UT_SIGN comparison present (UT0/UT1 BER ratio 0.47 to 2.73
  at the compared count, no systematic side; the LPM BER at the same count on lane
  4 follows UT0), register preservation after success and after abort, and the
  missing-hook refusal on 4 of 4 lanes (see ResetRx result).
- Their across-reset limits and prescale windows are superseded by the one-reset
  contract and the summed prescale test.

## 2D eye and margin (lanes 4 to 7)

Same card, image and lanes as above, driven by `software/scripts/EyeScan.py`
(`--mode Eye`, then `--mode Margin`) with the defaults: DFE, line rate 6.25 Gb/s
set, one RX reset per lane through the hook, no loopback or link setting
written.

- Eye grid 65 x 63 points: horizontal step 2 over +-64 counts (1/128 UI per
  count), vertical step 4 over +-124 codes, eye floor 1e-6 at 95 percent
  confidence. The raw VS_RANGE value is 0 on every lane.
- Margin: the same eye, then the horizontal and vertical bathtubs through the eye
  centre at step 1 down to 1e-9, with the opening extrapolated to 1e-12 from the
  Q-scale fits.
- Every run ended OK on all four lanes with the centre point open, one RX reset
  per lane (`PhyRxInitCnt` and `LinkDownCnt` each rose by 1), the raw words 0x4F,
  0x93, 0x97 and the `Ctrl` word unchanged (0x3C only in bits 9:8), no loopback
  record, and the npz, CSV and PNG files of each lane written.

Eye run (one RX reset per lane, 4095 points each):

| Lane | Eye time | Opening at 1e-6 (UI by codes, measured) | Centre offset (UI / codes) | Centre BER |
|---|---|---|---|---|
| 4 | 11.6 s | 0.781 by 100.0 | +0.000 / -6.0 | < 3.6e-07 at 95% |
| 5 | 12.3 s | 0.812 by 160.0 | +0.000 / +0.0 | < 3.6e-07 at 95% |
| 6 | 12.2 s | 0.844 by 152.0 | +0.000 / +0.0 | < 3.6e-07 at 95% |
| 7 | 12.7 s | 0.812 by 228.0 | -0.016 / +2.0 | < 3.6e-07 at 95% |

Margin run (a separate RX reset per lane):

| Lane | Time | Horizontal at 1e-12 (UI) | Vertical at 1e-9 (codes) | Open area (UI x codes) | Centre offset (UI / codes) | LR asym | TB asym | Centre BER |
|---|---|---|---|---|---|---|---|---|
| 4 | 565 s | 0.766 (extrapolated) | 172.0 (measured) | 152.2 | -0.016 / -10.0 | -0.021 | +0.038 | < 2.6e-10 at 95% |
| 5 | 484 s | 0.752 (extrapolated) | 136.0 (measured) | 113.4 | +0.000 / +2.0 | -0.024 | -0.013 | < 2.6e-10 at 95% |
| 6 | 363 s | 0.719 (extrapolated) | 80.0 (measured) | 70.4 | -0.008 / -2.0 | -0.054 | +0.013 | < 2.6e-10 at 95% |
| 7 | 366 s | 0.717 (extrapolated) | 81.0 (measured) | 65.6 | +0.000 / -4.0 | -0.019 | +0.006 | < 2.6e-10 at 95% |

- Horizontal: both tail fits pass every gate on all four lanes (r2 0.975 to
  0.998), so the 1e-12 opening is extrapolated. The measured opening at 1e-9 is
  0.820, 0.789, 0.758 and 0.766 UI on lanes 4 to 7.
- Vertical: no lane has an extrapolated opening. The vertical tail fits at step 1
  fail the r2 gate (0.95) on at least one tail of every lane (lane 4: 0.829 and
  0.734; lane 5: 0.896 left, 0.953 right passes; lane 6: 0.972 left passes, 0.844
  right; lane 7: 0.883 and 0.913), so each lane reports `insufficient_data` and
  the vertical opening is the measured open run at 1e-9, not a 1e-12 value.
- No axis reached the scan range limit on any lane, so no opening is a lower
  bound (`clipped` is False on both axes everywhere).
- The openings move between RX resets (receiver re-adaptation), by 7 to 15
  counts horizontally on these lanes (spread across RX resets above), so settings
  are compared within one RX reset. The vertical opening at the 1e-6 floor moves
  much more: the eye run and the eye of the margin run (different resets) give 100
  and 196 codes on lane 4, 160 and 148 on lane 5, 152 and 92 on lane 6, and 228
  and 88 on lane 7 (factor 2.6 on lane 7); two more resets on lane 4 gave 212 and
  104. The horizontal opening at 1e-6 of the two runs differs by at most 0.0625
  UI (8 counts). Compare vertical openings only within one RX reset as well.
- At the centre column of the eye run, the first closed row above the open run
  shows errors on UT_SIGN 0 only and the first closed row below it on UT_SIGN 1
  only, on every lane.

Start and Stop through the PyRogue surface on lane 4 (`PgpRoot` with
`lineRate=6.25`):

- Stop mid-eye (progress 0.34) returned in 0.037 s and Stop mid-cross (progress
  0.014) in 0.056 s, bound 1.0 s. Both ended `ABORTED` with the npz and CSV saved,
  no PNG, `ES_CONTROL` cleared and the raw words unchanged.
- A full `Start` Eye run ended OK and set `HorzOpeningUI` 0.844, `VertOpeningCodes`
  212.0, `BerAtCenter` "BER < 3.6e-07 at 95%", `ResultFile` (npz, CSV and eye PNG
  present) and `HwVerified` True.
- A client in another process read `Progress` 10 times during that scan, largest
  read latency 0.5 ms (bound 0.5 s).
- Scan time estimate (`EtaSeconds`, worst case with every point running to its
  floor, activation included): Eye 11.4 s against 11.6, 12.3, 12.2 and 12.7 s on
  lanes 4 to 7 (ratios 1.02, 1.08, 1.07 and 1.11; lane 7 is 0.01 above the 1.1
  bound) and 11.9 s through `Start` (EtaSeconds 11.4 s, ratio 1.04); Margin 736 s
  against 565, 484, 363 and 366 s (ratios 0.77 to 0.49). The point model uses the
  calibration of the first eye scan: median point 2.5 ms (3.0 ms at open points,
  2.4 ms at closed ones), per-run overhead 0.56 ms (0.81 ms at open points),
  sampler efficiency 0.965 of the line rate.
- `LineRateGbps` 0: the scan measured 6.462 Gb/s against the 6.25 Gb/s set (3.4
  percent high), recorded the source `measured` and the warning in `Message` and
  the meta. With no rate set, `EtaSeconds` before the first scan prices no bits:
  5.7 s against an actual 10.3 s.

## GTY phase unification (lanes 4 to 7)

Bit 11 of `ES_HORZ_OFFSET` is not documented the same way everywhere, so the
GTYE4 descriptor carries a rule, `phaseUnification`, and the engine writes the
bit through it on every run of a scan (activation probe, line-rate run and every
point). Two rules were compared on the C1100 lanes:

- `sign`: bit 11 is 1 only for a negative count (the UG576 and AMD AR 33098
  reading, also in newer UG578).
- `rate`: bit 11 is 1 for every count when the line rate is above 10 Gb/s
  (`rateThresholdGbps`) and 0 at or below it (the UG578 v1.3 reading).

The rules write different words for counts >= 0 above 10 Gb/s and for counts < 0
at or below it, so the discriminating counts are 0 and +1 at 10.3125, 15.46875
and 25 Gb/s and -1 and -2 at 6.25 Gb/s.

### Method and criteria

Per lane and rate, three full bathtubs (step 1, floor 1e-9, DFE, the line rate
of the image) on one RX reset, in the order `sign`, `rate`, `sign`: the first
`sign` run with reset policy `Always`, the other two with `Never`, so the
second `sign` run measures the drift of one reset. The criteria and their
tolerances were written down before the first run and were not changed after
data existed:

| Criterion | Definition |
|---|---|
| OPEN | status OK and an open run at the 1e-9 floor (95 percent Poisson bound at or below the floor at every point) |
| CONT | continuous through counts -2 to +2 |
| MONO | both tails monotone |
| SYM | the centre of the open run is within 0.10 UI of zero |
| CONTROL | the two `sign` runs agree on all four criteria and, when open, their openings differ by at most 2 counts and their centres by at most 2 counts |

A rule wins at one rate only if its runs pass on all four lanes, the other rule
fails at least one criterion on every lane, and CONTROL passes on all four lanes.
Anything else is `undecided` (here: both rules passing on all four lanes). The
combined verdict is a rule only if both arms (15.46875 and 6.25 Gb/s) give that
rule; 10.3125 and 25 Gb/s were run as supplementary arms and sit beside it.

Two earlier attempts at 15.46875 Gb/s stopped before they finished: the first at
lane 4 `sign` with a CLOSED result, the second at lane 5 `sign` with
NOT_ENABLED. Each exposed an engine fault of the activation (a sampler left out
of step with the data after an RX reset, see "ResetRx result"), each was fixed,
and the arm was restarted from its first run with the criteria unchanged. The
stopped runs are kept and are not analysed as an arm. The A/B and the battery
below ran with those fixes.

### Results

All runs reported status OK with W 64. Every run of every lane at every rate
passed OPEN, CONT, MONO and SYM, and CONTROL passed on all four lanes at every
rate. The discriminating counts were error free under both rules (a BER bound
below 5.43e-10 on every run, apart from one measured 1.812e-10 at count 0 of
`rate` on lane 4 at 25 Gb/s, still below the floor).

15.46875 Gb/s (RXOUT_DIV 1, 1/64 UI per count), opening at 1e-9 in counts (UI)
and centre in counts:

| Lane | Rule | OPEN | CONT | MONO | SYM | Opening | Centre |
|---|---|---|---|---|---|---|---|
| 4 | sign | pass | pass | pass | pass | 33 (0.5156) | -3.5 |
| 4 | rate | pass | pass | pass | pass | 33 (0.5156) | -3.5 |
| 4 | sign (2nd) | pass | pass | pass | pass | 33 (0.5156) | -3.5 |
| 5 | sign | pass | pass | pass | pass | 35 (0.5469) | -3.5 |
| 5 | rate | pass | pass | pass | pass | 35 (0.5469) | -3.5 |
| 5 | sign (2nd) | pass | pass | pass | pass | 34 (0.5312) | -3.0 |
| 6 | sign | pass | pass | pass | pass | 36 (0.5625) | -3.0 |
| 6 | rate | pass | pass | pass | pass | 36 (0.5625) | -3.0 |
| 6 | sign (2nd) | pass | pass | pass | pass | 36 (0.5625) | -3.0 |
| 7 | sign | pass | pass | pass | pass | 36 (0.5625) | -2.0 |
| 7 | rate | pass | pass | pass | pass | 36 (0.5625) | -2.0 |
| 7 | sign (2nd) | pass | pass | pass | pass | 36 (0.5625) | -2.0 |

6.25 Gb/s (RXOUT_DIV 2, 1/128 UI per count):

| Lane | Rule | OPEN | CONT | MONO | SYM | Opening | Centre |
|---|---|---|---|---|---|---|---|
| 4 | sign | pass | pass | pass | pass | 101 (0.7891) | -1.5 |
| 4 | rate | pass | pass | pass | pass | 95 (0.7422) | +1.5 |
| 4 | sign (2nd) | pass | pass | pass | pass | 101 (0.7891) | -0.5 |
| 5 | sign | pass | pass | pass | pass | 100 (0.7812) | +0.0 |
| 5 | rate | pass | pass | pass | pass | 96 (0.7500) | +2.0 |
| 5 | sign (2nd) | pass | pass | pass | pass | 101 (0.7891) | +0.5 |
| 6 | sign | pass | pass | pass | pass | 101 (0.7891) | -0.5 |
| 6 | rate | pass | pass | pass | pass | 94 (0.7344) | +3.0 |
| 6 | sign (2nd) | pass | pass | pass | pass | 101 (0.7891) | -0.5 |
| 7 | sign | pass | pass | pass | pass | 99 (0.7734) | +0.5 |
| 7 | rate | pass | pass | pass | pass | 93 (0.7266) | +3.5 |
| 7 | sign (2nd) | pass | pass | pass | pass | 99 (0.7734) | +0.5 |

Supplementary arms, every run passing OPEN, CONT, MONO and SYM, opening in counts
`sign` / `rate` / `sign` (second) and the centre of the first `sign` run. The
25 Gb/s image (RS-FEC, RXOUT_DIV 1) was run twice: first with the QSFP CDR most
likely still disabled by the earlier images, then after the QSFP module was
re-seated:

| Lane | 10.3125 Gb/s (RXOUT_DIV 1) | Centre | 25 Gb/s, CDR most likely disabled | Centre | 25 Gb/s, QSFP re-seated | Centre |
|---|---|---|---|---|---|---|
| 4 | 44 / 44 / 44 | -1.0 | 14 / 14 / 12 | -1.0 | 45 / 44 / 45 | -2.5 |
| 5 | 45 / 45 / 45 | -0.5 | 22 / 22 / 24 | -1.0 | 43 / 43 / 43 | -1.5 |
| 6 | 44 / 44 / 45 | +0.0 | 25 / 24 / 24 | -3.5 | 45 / 45 / 44 | -3.5 |
| 7 | 45 / 46 / 46 | -0.5 | 25 / 25 / 25 | -3.5 | 44 / 44 / 44 | -1.0 |

With the CDR restored the 25 Gb/s openings are about three times wider (43 to 45
counts, 0.67 to 0.70 UI against 12 to 25 counts). The CDR left disabled by the
earlier images is therefore the cause of the narrow first 25 Gb/s eyes. The A/B
outcome is the same in both: both rules pass every criterion and CONTROL passes on
all four lanes.

Verdicts: `undecided` (both rules pass on all four lanes) at 15.46875 Gb/s, at
6.25 Gb/s, and at the supplementary 10.3125 and 25 Gb/s (both 25 Gb/s runs), so
the combined verdict is `undecided`. A read-only record of `ES_CLK_PHASE_SEL`,
`USE_PCS_CLK_PHASE_SEL` and `SAMPLE_CLK_PHASE` (DRP word 0x94) read 0 on lanes 4
to 7 on the 6.25 Gb/s image and, from the earlier register dumps, on the
15.46875 Gb/s image; nothing was written.

Observations not scored by any criterion:

- At 6.25 Gb/s the `rate` runs are 4 to 7 counts narrower than the `sign` runs
  on every lane (lane 4 101, 95, 101; lane 5 100, 96, 101; lane 6 101, 94, 101;
  lane 7 99, 93, 99, in the order `sign`, `rate`, `sign`), with centres 1.5 to
  3.5 counts to the right of the `sign` centres, and the two `sign` runs agree
  with each other. The effect is reproducible and favours `sign`. No such
  difference appears at 10.3125, 15.46875 or 25 Gb/s.
- The UT_SIGN comparison: at 15.46875 Gb/s and in the first 25 Gb/s run UT0
  saturates (65535 errors) while UT1 does not, on every run (compared at counts
  23 to 26). With the CDR restored at 25 Gb/s UT0 and UT1 come back within about
  1.2 to 2.8 times of each other (BER 1.5e-03 to 1.5e-02, lanes 4 and 5
  unsaturated), so that asymmetry went with the disabled CDR; the 15.46875 Gb/s
  arm ran with the CDR disabled by its own image and was not repeated. At 6.25
  Gb/s UT0 and UT1 are close on lanes 4 and 5 and both saturate on lanes 6 and 7
  (compared at counts 56 and 57).

### Chosen rule and its line-rate behaviour

The default of `GTYE4.phaseUnification` stays `sign` (the value shipped with the
family before the A/B), chosen because the A/B could not separate the rules and
the one measurable difference, at 6.25 Gb/s, favours `sign`. It is pinned by a
test. Under `sign` the line rate is not needed for the offset word: a scan with
no `LineRateGbps` measures the rate with one extra run and warns that the value
is less accurate than a set one. Under `rate` a scan with no positive line rate
is refused before anything is written, because the word depends on it. `rate` is
selectable per call through the expert `phaseUnification` keyword.

## GTY bathtub, eye and margin at 6.25 Gb/s (lanes 4 to 7)

C1100 image `XilinxVariumC1100Pgp4_6Gbps`, lanes 4 to 7, DFE, `sign` rule, line
rate 6.25 Gb/s (RXOUT_DIV 2, W 64, 129 positions from -64 to +64 counts). Run
list per lane: three bathtubs on one RX reset (first with policy `Always`, the
other two with `Never`), five bathtubs each after its own RX reset (policy
`Auto`), one Eye, one Margin. Bathtubs use step 1 and floor 1e-9. The gating
checks and their limits were fixed before the run: the three same-reset
openings within 2 counts, each tail position at each decade from 1e-3 to 1e-8
within 1 count, and each side of the open run reaching a BER of at least 1e-3.
A failed battery would stay on record and get exactly one rerun judged alone.

The battery passed on its first run, on all four lanes, with no link drop in any
run, so no rerun was made and no failed battery is on record for GTYE4. The QSFP
CDR state was not read back and was most likely disabled (left by the earlier
images); the battery passed under that condition and was not repeated with the
CDR restored.

| Check | Outcome |
|---|---|
| Activation: reset called, status END, 65535 samples, eye-scan enable read back as 1 | pass on every lane |
| Bits advancing at every point, full range with status OK, walls reaching 1e-3, tails monotone, continuous through counts -2 to +2, no BER 0 and a finite bound at every point (8 bathtubs per lane) | pass on every lane |
| Same-reset opening within 2 counts | pass on every lane |
| Same-reset tail positions within 1 count at every decade | pass on every lane |
| Eye status OK with an open centre | pass on every lane |
| Margin status OK | pass on every lane |

Spreads on one RX reset, in counts:

| Lane | Openings, three runs | Opening spread (limit 2) | Worst decade spread (limit 1.0) |
|---|---|---|---|
| 4 | 100, 100, 100 | 0 | 0.19 |
| 5 | 101, 100, 100 | 1 | 0.29 |
| 6 | 101, 101, 101 | 0 | 0.16 |
| 7 | 99, 100, 99 | 1 | 0.30 |

Spread across RX resets (five resets per lane, reported, not a limit):

| Lane | Opening min / median / max (counts) | Decade spread (counts) |
|---|---|---|
| 4 | 100 / 101 / 101 | 0.43 |
| 5 | 100 / 100 / 101 | 0.30 |
| 6 | 101 / 101 / 102 | 0.58 |
| 7 | 99 / 100 / 100 | 0.41 |

The across-reset spread is 1 to 2 counts here, against 7 to 15 counts on the
GTHE3 lanes over 10 resets (five resets here, so the two are not like for like).

Eye run (one RX reset per lane, 4095 points each, grid 65 x 63):

| Lane | Eye time | Opening at 1e-6 (UI by codes, measured) | Centre offset (UI / codes) | Centre BER |
|---|---|---|---|---|
| 4 | 45.0 s | 0.797 by 96.0 | -0.008 / -4.0 | < 1.8e-07 at 95% |
| 5 | 41.8 s | 0.812 by 100.0 | +0.000 / +2.0 | < 1.8e-07 at 95% |
| 6 | 42.3 s | 0.812 by 96.0 | +0.000 / -4.0 | < 1.8e-07 at 95% |
| 7 | 37.0 s | 0.797 by 100.0 | +0.008 / +2.0 | < 1.8e-07 at 95% |

Margin run (a separate RX reset per lane):

| Lane | Time | Horizontal at 1e-12 (UI) | Vertical at 1e-9 (codes) | Open area (UI x codes) | Centre offset (UI / codes) | LR asym | TB asym | Centre BER |
|---|---|---|---|---|---|---|---|---|
| 4 | 228 s | 0.744 (extrapolated) | 91.0 (measured, insufficient data) | 79.4 | +0.000 / -2.0 | -0.058 | +0.000 | < 5.4e-10 at 95% |
| 5 | 224 s | 0.744 (extrapolated) | 97.0 (measured, insufficient data) | 86.2 | +0.000 / +0.0 | -0.027 | +0.050 | < 5.4e-10 at 95% |
| 6 | 199 s | 0.727 (extrapolated) | 91.0 (measured, insufficient data) | 80.7 | +0.000 / -4.0 | -0.060 | +0.031 | < 5.4e-10 at 95% |
| 7 | 201 s | 0.702 (extrapolated) | 97.0 (measured, insufficient data) | 82.0 | +0.000 / +2.0 | -0.028 | -0.003 | < 5.4e-10 at 95% |

- Horizontal: both tail fits pass every gate on all four lanes (r2 0.980 to
  0.994), so the 1e-12 opening is extrapolated.
- Vertical: the Q-scale fit gate (r2 at least 0.95) fails on GTY as it does on
  GTHE3, on every lane: lane 4 right tail 0.912 (left 0.989 passes); lane 5 0.810
  and 0.619; lane 6 0.069 left and 0.917 right; lane 7 0.833 and 0.881. Each lane
  reports `insufficient_data` and the vertical opening is the measured open run
  at 1e-9, not a 1e-12 value.
- UT_SIGN comparison at the compared count (56 or 57) of the `sign` bathtub:
  lane 4 UT0 36928 errors (BER 4.402e-03) against UT1 45260 (5.395e-03); lane 5
  47473 (5.659e-03) against 44646 (5.322e-03); lanes 6 and 7 saturate on both
  UTs (65535). No systematic side among the unsaturated lanes.
- Centre offsets: the eye centre lies within 0.008 UI and 4 codes of zero, the
  margin centre at 0.000 UI and -4 to +2 codes.

## GTH regression after the GTY change

One bathtub per lane (policy `Auto`) on the KCU1500 (image
`XilinxKcu1500Pgp4_6Gbps`, Git Hash
`dd69c8bd045862a6631c81899e06a321c68cf314`, lanes 4 to 7), after the GTY changes
and the engine fixes above. A lane passes when the status is OK, CONT and MONO
pass, W is 32, RXOUT_DIV is 2, the counts run from -64 to +64 and the opening at
1e-9 lies inside the range of the openings of both GTHE3 batteries above widened
by 2 counts per side. All four lanes pass:

| Lane | Opening at 1e-9 (counts) | Recorded range |
|---|---|---|
| 4 | 105 | 96 to 108 |
| 5 | 93 | 92 to 105 |
| 6 | 96 | 87 to 106 |
| 7 | 96 | 94 to 105 |

## QSFP[0] no-fiber result

Setup: the KCU1500 (image `XilinxKcu1500Pgp4_6Gbps`, GTHE3) and the Varium C1100
(image `XilinxVariumC1100Pgp4_6Gbps`, GTYE4), both reporting Git Hash
`dd69c8bd045862a6631c81899e06a321c68cf314` and a build of 24 October 2026, QSFP[0]
lanes 0 to 3, 6.25 Gb/s, with the QSFP module present and no fiber. The no-fiber
state was inferred from a read-only status read (lanes 0 to 3 not `LinkReady`); it
was not confirmed by hand. On the KCU1500 lanes `PhyRxActive` read True and the
sampler reached a full 65535-sample END while `LinkReady` was False, so a signal
source on those lanes is not excluded.

Method: `EyeScan.py --numLane 8 --lanes 0-3 --lineRate 6.25 --noPng True` with the
default floors and grid, in the order Status, Probe with policy `Auto`, Bathtub
`Auto`, Margin `Auto` and Probe `Never`, no loopback, soft cold or hook removal.
Before and after every run a raw dump read the low 16 bits of every DRP word that
carries a driver variable (GTHE3 up to 0x153, GTYE4 up to 0x28C), the `Ctrl` word,
`PhyRxActive` and `LinkReady`; the bits that differ between two idle dumps of a lane
were excluded. The criteria were fixed before the cards were touched: the status
is `UNLOCKED`, `NOT_ENABLED` or `CLOSED` and nothing else; a `CLOSED` carries a
warning with both causes; the lane finishes inside its time bound; the process
exits 0 or 2, never a hang; every register is restored (the two enable bits may go
from 0 to 1 only, because the engine leaves them set); every lane has a result file.

Time bound: the worst case of the code, not a prediction. One reset costs hold 0.05 s
plus fall wait 0.5 s plus ready timeout 6.0 s plus settle 0.5 s, 7.05 s. One probe
costs 2.0 s plus 1.0 s for the idle wait, 3.0 s. An activation under `Auto` is 12
resets, 12 probes and 10 re-arms of 0.1 s, 121.6 s, and under `Never` one probe,
3.0 s. A scan mode adds the worst-case estimate of the engine at these defaults,
times 1.5, plus one activation. Every bound adds one link-drop recovery (6.5 s, scan
modes only), 1.0 s for the restore and 10 s for register access. The bounds are
132.6 s for Probe `Auto`, 14.0 s for Probe `Never`, 504.32 s (GTHE3) and 317.06 s
(GTYE4) for Bathtub, and 1241.69 s and 692.8 s for Margin.

These bounds leave out the two runs at the ends of the UI (at most
2 x (2.0 + 1.0) = 6 s), which the probe already ran and every scan activation
runs since, so the worst case of the current code is 6 s higher in every mode:
138.6 s for Probe `Auto`, 20.0 s for Probe `Never`, 510.32 s (GTHE3) and 323.06 s
(GTYE4) for Bathtub, and 1247.69 s and 698.8 s for Margin. Every measured lane
stayed inside the smaller bounds fixed before the run.

First run: 8 of the 32 lane and mode results passed and 24 failed. Every one of the
16 KCU1500 results ended `OK`, with Bathtub taking 257.6 to 257.8 s and Margin 539.3
to 611.2 s on lanes that carried no data. On the C1100, 5 results ended `OK` and 3
ended `TIMEOUT` (Bathtub on lanes 0 and 3, Margin on lane 0), and the 8 that ended
`NOT_ENABLED` passed. Every lane was inside its bound and every restore passed; the
failures were the statuses. The fix was a change of the code with regression tests,
followed by exactly one rerun of the full test on both cards with the unchanged
harness, judged alone.

Rerun, all 32 results passed:

| Card (family) | Probe `Auto` | Bathtub `Auto` | Margin `Auto` | Probe `Never` |
|---|---|---|---|---|
| KCU1500 (GTHE3), bound | 132.6 s | 504.32 s | 1241.69 s | 14.0 s |
| KCU1500, lanes 0 to 3 | `CLOSED` 1.06 s | `CLOSED` 255.7 to 256.4 s | `CLOSED` 537.2 to 620.7 s | `CLOSED` 0.01 s |
| Varium C1100 (GTYE4), bound | 132.6 s | 317.06 s | 692.8 s | 14.0 s |
| C1100, lanes 0 to 3 | `NOT_ENABLED` 0.56 to 3.15 s | `NOT_ENABLED` 0.58 to 2.56 s | `NOT_ENABLED` 0.56 to 2.57 s | lane 0 `CLOSED` 0.01 s, lanes 1 to 3 `NOT_ENABLED` 0.02 to 2.01 s |

- Every KCU1500 `CLOSED` carried the two-cause warning (no errors at either end of
  the UI, counts -64 and +64, 65535 samples each).
- On the C1100 the sampler of every lane did not run. In the Probe `Auto` run it
  reached END with no samples on lanes 0, 1 and 3 and `es_control_status` stayed OFF
  on lane 2, so those lanes ended `NOT_ENABLED`. The one C1100 `CLOSED` is lane 0 with policy `Never`.
- Restore: the check passed on every lane in every step; no compared bit differs
  between the dumps before and after apart from the two enable bits (the volatile
  bits found in the idle dumps are excluded).

Re-check of lanes 4 to 7 after the fixes, one Bathtub per lane with policy `Auto` on
QSFP[1] lanes that read `LinkReady` True:

- KCU1500 (GTHE3): all four lanes pass. Openings at 1e-9 are 105, 94, 104 and 101
  counts against the recorded ranges 96 to 108, 92 to 105, 87 to 106 and 94 to 105,
  with W 32, RXOUT_DIV 2, counts -64 to +64, continuity and monotone tails.
- Varium C1100 (GTYE4): the verdict is WIDER, not a pass. Status OK, continuity and
  monotone tails pass on all four lanes (W 64, RXOUT_DIV 2), but the openings are
  104, 104, 104 and 103 counts against the bands 98 to 103, 98 to 103, 99 to 104 and
  97 to 102, which are the battery range widened by 2 counts per side. Lanes 4, 5 and
  7 are 1 count above their band, lane 6 is inside. The QSFP[1] module was re-seated
  after the battery (CDR back at its power-on state) while the battery most likely
  ran with the CDR disabled, so this is read as a change of the physical state. The
  band was not widened afterwards.

Consumer smoke: `PgpMonitor.py` and `PgpTesting.py` of pgp-pcie-apps on both cards,
each plain and with the root wrapped, 8 of 8 runs pass. A plain run ends with exit 0
and no traceback; a wrapped run finds an `EyeScan` child with a registered hook on
all 8 lanes, writes a saved configuration with no `EyeScan` line, and exits through
its own `with` block.

## Decisions

- DFE counts are the sum of the UT_SIGN 0 and 1 accumulations; the comparison is
  reported with every DFE bathtub.
- `ES_ERRDET_EN` is left set together with `ES_EYE_SCAN_EN`; both are left set
  after a scan, all other registers are restored (primed read-modify-write,
  ordered restore, also after an abort).
- The new driver variables (`ResetPolicy`, `RxResetHook`, progress and status)
  are `NoConfig`, so saved YAML does not change.
- Hook defaults of `EyeScan.setRxReset`: ready timeout 6 s (ten times the 0.553 s
  longest measured relock, rounded up to 0.5 s), fall wait 0.5 s, settle 0.5 s,
  hold 0.05 s, and a 2 s activation probe window (END arrived within 8 ms). The
  fall wait is kept because the fall was never observed with a 0.5 s window, so
  a shorter window could only hide it. The ready timeout was 10 s before.
- Every measured point is judged by its one-sided Poisson upper bound at the
  stated confidence, so more errors can never turn a closed point into an open
  one; the zero-error case is -ln(1 - c) / N for c the confidence and N the bit
  count.
- The restore writes every field even when the idle wait after clearing
  `ES_CONTROL` fails, then re-raises the first error. It leaves the sampler
  stopped with the enables set, so the snapshot no longer stores `ES_CONTROL`.
- Repeatability is judged on one RX reset (the contract table above). The spread
  across RX resets is measured over 10 RX resets per lane and reported with the
  result; it is not a pass or fail condition.
- The prescale independence test sums repeated fixed-prescale sweeps in the
  hardware harness (one fixed-prescale sweep per accumulation, prescale 6 and 8
  sweeps interleaved on one RX reset), so that a count reaches 100 summed errors
  without a saturated accumulation.
- Repeat rule: after the first one-reset battery failed, one repeat was fixed
  before the card was touched, judged on its own under unchanged tolerances, with
  the first battery's failure kept on record. The repeat is spent: another repeat
  under these tolerances is not run.
- `GTHE3.hwVerified` is `True`. The claim rests on the one-reset repeatability
  checks and the summed prescale test; the spread across RX resets is reported
  and does not decide it. The first one-reset battery failed the lane 6
  same-reset decade spread (1.21 counts, limit 1.0) and the monotone left tail on
  one lane 6 run, and lane 4 was indeterminate on the summed prescale test (4
  comparable counts, minimum 5). The repeat battery passed every one of those
  checks on all four lanes, so the flag is set on that single passing repeat
  and the failure of the first battery is not erased by it.
  `test_gthe3_hardware_verified_flag_matches_the_hardware_record` pins the value.
- `GTYE4.hwVerified` is `True`. The claim rests on the first 6.25 Gb/s battery on
  Varium C1100 lanes 4 to 7 (every gating check passed on all four lanes, the
  same-reset opening spread at most 1 count against a limit of 2); no failed
  battery exists to keep on record. It is one card and one image, the battery
  ran under the `sign` rule only with the QSFP CDR most likely disabled, and the vertical Q-scale fit gate failed on all
  four lanes, so the vertical margin is a measured opening. The spread across RX
  resets is reported and does not decide it.
  `test_gtye4_hardware_verified_flag_matches_the_hardware_record` pins the value
  and checks that the `HwVerified` variable of a `Gtye4Channel` child reads it.
  The flag per family: GTHE3 `True`, GTYE4 `True`; GTPE2 and GTXE2 have no child.
- GTYE4 phase rule: the default is `sign` and the A/B was undecided at all four
  rates (above), with the one observed difference, `rate` reading 4 to 7 counts
  narrower at 6.25 Gb/s, favouring `sign`. The value is kept after the undecided
  verdict and is pinned by a test.
- The rule decides whether the line rate is needed: a `rate` scan without a
  positive line rate is refused before any write, a `sign` scan measures the
  rate with one extra run and warns.
- `phaseUnification` is an expert keyword of the run methods and the point
  measurement; there is no PyDM variable for it.
- `EtaSeconds` is NaN until the line rate is known (set through `LineRateGbps` or
  measured by a scan), and the lane it prices before the first scan (width and
  RXOUT_DIV) comes from the family descriptor, so a GTYE4 child prices a 64-bit
  lane. This replaces the 5.7 s figure of the line-rate-0 run above.
- A save whose stem already has a file in the same second writes every file under
  the next free serial inserted after the stamp, so two scans started in the same
  second keep both sets of files.
- A sync check that fails warns and continues. A diagnostic runs on a closed or dead
  link, so refusing it would hide the lane; the scan measures every position and
  reports `CLOSED` with a warning naming both causes (sampler out of step, or link
  closed or unlocked), because the scan cannot tell the two apart. A missing hook,
  a ready that never returns and a sampler that does not run stay `NOT_ENABLED`.
- A re-arm clears both enables, waits `REARM_WAIT` and sets them again in a
  `finally`, so an abort or a failing write during the wait still leaves the
  enables set.
- The margin summary labels an axis `closed` when its cross completed and no
  position meets the bathtub floor. The label is in the summary, the npz meta and
  the `EyeScan.py` text; the long-form CSV is unchanged because it carries no
  summary.
- A Start that is refused because a scan is running only fills `Message`: `Status`,
  `ResultFile` and the result of the running scan stay as they are.
- The check at the two ends of the UI runs after every clean activation of the
  probe and of the three scans, whatever the grid. A scan whose edge run counts
  no samples leaves the lane to its points.

## Open risks and next steps

- Two batteries under one contract disagree on lane 6 (same-reset decade spread
  1.21 counts and one non-monotone left tail in the first, 0.29 counts and all
  tails monotone in the repeat) and on lane 4 (4 comparable counts in the first,
  6 in the repeat). One passing repeat after one failing battery is a thin basis
  for the flag; the cause of the first failure (a transient on that lane or the
  limits sitting close to the noise) was not separated.
- Summed prescale test: the comparable counts per lane sit at 5 to 6 against a
  minimum of 5, so the test has little margin. More accumulations per set would
  add summed errors to the counts next to the comparable ones.
- Across-reset spread: in both batteries the lane 6 opening varies by 15 counts
  (0.117 UI) and 7 to 10 of 10 resets deviate on that lane; 9 of 10 resets
  deviate on two or more lanes, and the repeat battery shows the same shifts
  recurring across resets on all four lanes. The classifier reports
  ENGINE_DEFECT_SUSPECTED in both; the cause (receiver re-adaptation or
  something in the scan engine) was not separated. Compare settings on one RX
  reset in the meantime.
- Relock time is only bounded by the fall wait; observe the fall (faster poll or
  the link-down counter) before tightening the hook defaults.
- Lanes with no fiber: measured on QSFP[0] of one KCU1500 and one Varium C1100
  (section "QSFP[0] no-fiber result"). The rerun passed on all 32 results (`CLOSED`
  with the warning on the KCU1500, `NOT_ENABLED` on the C1100, inside the bound
  everywhere, registers restored). Still open: the no-fiber state was inferred and
  not confirmed by hand; the KCU1500 lanes showed `PhyRxActive` True and a full
  65535-sample END, so they are `CLOSED` only through the check at the two ends of
  the UI, and a signal source on them is not excluded; the hardware run predates
  the check in the scans, and the other grids rest on emulated tests; the C1100 lanes ended
  `NOT_ENABLED` because the sampler did not run, which is not the dead-centre path;
  one card per family, four lanes each and 6.25 Gb/s images only; a link that is up
  with a high error rate is not part of this test.
- The lanes 4 to 7 re-check of the C1100 after the fixes read 1 count above its band
  on three lanes (WIDER) after the QSFP module was re-seated; whether the CDR state
  explains it was not separated.
- Vertical extrapolation: the vertical Q-scale fits at step 1 fail the r2 gate on
  one or both tails of every lane 4 to 7 (insufficient data), so the vertical
  margin is a measured opening at 1e-9. Whether a different fit window or gate
  would pass was not tried.
- The vertical opening at 1e-6 differs by up to a factor of 2.6 between RX resets
  of one lane; the cause (receiver adaptation state) was not separated.
- Scan time estimate: lane 7 exceeded the 1.1 factor by 0.01 on the eye run. The
  Stop bound (1 s) was measured on lane 4 only, and the estimate constants only
  at 6.25 Gb/s on GTHE3.
- The GTP and GTX drivers.
- GTY evidence is one Varium C1100 and one image per rate. The battery and the
  Eye and Margin measurements are at 6.25 Gb/s only; 10.3125, 15.46875 and 25
  Gb/s have the phase A/B bathtubs and nothing more.
- QSFP CDR state was never read back on the C1100. It was most likely disabled for
  every run up to the 6.25 Gb/s battery (the 15.46875 and 10.3125 Gb/s images turn
  it off and the later images do not turn it back on). Re-seating the module
  and repeating the 25 Gb/s arm confirmed that a disabled CDR narrows the eye
  about threefold there. The 6.25 Gb/s battery and the 15.46875 and 10.3125 Gb/s
  arms were not repeated with the CDR restored, so how much the CDR changes
  them is not known, and a battery with the CDR restored is not on record.
- The phase rule was not decided by hardware. Both rules passed everywhere, and
  at 6.25 Gb/s `rate` read 4 to 7 counts narrower on every lane without an
  explanation; the phase-select attributes read 0. A card or rate where the two
  rules disagree on the pass criteria would settle it.
- The vertical Q-scale fit gate fails on every GTYE4 lane as well (above), so the
  GTY vertical margin is also a measured opening at 1e-9.
- RXOUT_DIV decodes 1 at 10.3125, 15.46875 and 25 Gb/s and 2 at 6.25 Gb/s, but
  the GTYE4 `defaultDivider` is 2, which is right only at 6.25 Gb/s. It only
  affects the lane the estimate prices before the first scan; the descriptor value
  is unchanged.
- A GTYE4 activation can need several RX resets or re-arms (see "ResetRx result"),
  and each re-arm drops the PGP link once. On the 25 Gb/s RS-FEC image the
  `PhyRxInitCnt` of the first `sign` run rose by 22, 22, 7 and 26 more than the
  engine's resets, re-arms and enable changes predict on lanes 4 to 7 (the
  prediction held exactly at 6.25 Gb/s and at 10.3125 Gb/s). The CDR is not the
  cause: after the re-seat the excess was still 34, 3, 2 and 8, while
  `LinkDownCnt` stayed at about one per engine reset or enable drop in both runs.
  The extra PHY inits are therefore repeated init attempts inside one link-down
  episode while the RS-FEC link re-locks, not extra link drops; the cause is open
  (possibly the link-up timeout of the PGP4 receive protocol against the RS-FEC
  lock time).
