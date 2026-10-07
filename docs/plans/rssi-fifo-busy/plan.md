# RSSI application FIFO BUSY threshold fix

## Scope and branch

Branch `fix/rssi-fifo-busy` in `/Users/bareese/surf`, based on
`origin/pre-release` at `fc4d923a0` on 2026-09-29. Apply only the FIFO pause/BUSY
threshold fix, its integration coverage and documentation. PR #1489 remains
separate and is not a prerequisite; the broader monitor review stays in
`/private/tmp/surf-rssi-busy-review`. On 2026-09-30 the user authorized committing
these changes and publishing a draft PR against `pre-release`.

## Defect and change

RX stops application delivery on `s_mAppAxisCtrl.pause`, but local BUSY used
FIFO count bit `SEGMENT_ADDR_SIZE_G`. With address width 5, pause is reached
at 16 words while that bit requires 32 words. RX can stop filling before
BUSY is ever advertised. Drive BUSY from the same pause signal and remove the
unused count wire. Preserve FIFO depth/threshold, interfaces and monitor logic.
Update the LocalBusy register description for the new source and existing
sticky status semantics; do not change the register map.

## Coverage and independence

`test_RssiCoreBusy.py` carries the previously validated independent wire-peer
scenario into a standalone default-enabled regression. Test pause thresholds
8 and 16 words, repeated wire BUSY, stalled application stability, exact
payload/SSI drain, NULL-probed release, resumed DATA and quiet ACK output.
Use NULL timeout 8192 clocks, longer than the entire scenario, to avoid relying
on #1489's pending ACK/BUSY receive-liveness correction. The unused RTL client
stays closed. No broad monitor diagnostics or RX fixes are included.

## Validation status

Completed on 2026-09-29 with GHDL 6.0.0 and cocotb 2.1.0:

- Source import: passed (`make MODULES=/Users/bareese import`).
- Focused BUSY integration: **2 passed**, pause8 and pause16, 118.42 seconds.
- Remaining default RSSI suite: **6 passed, 17 skipped**, 36.56 seconds;
  existing known-issue gates remain unchanged. Combined default coverage is
  8 passed and 17 skipped across the two commands below.
- Identical pause16 test with only RssiCore restored from the branch base:
  **failed as expected** at 4672 ns waiting for the next RSSI reply during
  FIFO filling, before periodic BUSY/release assertions (34.60 seconds).
- VSG: 689 rules, zero violations for RssiCore. Python lint, the new-test audit
  (zero findings), full test-compliance baseline, register-description syntax,
  Markdown file links and whitespace checks passed.

Commands:

```sh
./.venv/bin/python -m pytest -n 0 -q tests/protocols/rssi/test_RssiCoreBusy.py
./.venv/bin/python -m pytest -n 0 -q tests/protocols/rssi \
  --ignore=tests/protocols/rssi/test_RssiCoreBusy.py
```

The comparison source is `/private/tmp/surf-rssi-fifo-busy-negative`; its
production RSSI RTL differs only in RssiCore and uses exactly the same new
test. Run `test_RssiCoreBusy.py::test_RssiCoreBusy[pause16]` there to reproduce.
Temporary logs: `/private/tmp/rssi-fifo-busy-{focused,existing,negative,vsg}.log`.
No logs or generated build outputs are included in the branch changes.

No deployed Rogue/UDP/FPGA or synthesis/timing validation is claimed. The fix
advertises pressure earlier and can therefore change flow-control timing.
Release coverage uses an explicit peer NULL probe; autonomous recovery from
all lost-release/peer-role combinations is outside this change.

## Handoff

The new branch is checked out in `/Users/bareese/surf`. The
[RTL fix](../../../protocols/rssi/v1/rtl/RssiCore.vhd),
[standalone test](../../../tests/protocols/rssi/test_RssiCoreBusy.py), protocol/
test READMEs and LocalBusy register description are ready for review. The
broader review worktree is preserved. Implementation and validation are complete;
this focused change is being submitted as a draft PR for maintainer review.
