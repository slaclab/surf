# GTHE4 and GTYE3 PyRogue drivers from the user guides

## Goal and scope

Add the two UltraScale GT families that `python/surf/xilinx` did not cover:
the UltraScale+ GTH (`Gthe4Channel`, `Gthe4Common`) and the UltraScale GTY
(`Gtye3Channel`, `Gtye3Common`), with the same `EyeScan` child as
`Gthe3Channel` and `Gtye4Channel`. The 7-series GTX and GTP drivers are out of
scope. No GTHE4 or GTYE3 hardware was available, so the register maps come from
the vendor user guides and the eye-scan descriptors are `hwVerified=False`.
Usage is in [python/surf/xilinx/README.md](../../../python/surf/xilinx/README.md),
section "GT drivers from the user guides"; this note keeps the record of how
the drivers were produced and what remains unverified.

## Current status

- The four drivers exist and are exported from `surf.xilinx`. Every field of
  every driver equals its row of UG576 v1.7.1 Tables C-1 and C-2 (GTHE4) or
  UG578 v1.4 Tables B-1 and B-2 (GTYE3): 511 and 79 variables for GTHE4, 490 and
  70 for GTYE3, compared by DRP address, bit range and access mode after
  generation.
- `GTHE4` and `GTYE3` descriptors are in `surf.xilinx.eyescan._EyeScanFamilies`
  and the emulated eye-scan suite runs every per-family test on them.
- Not run on hardware.

## Method

1. The two PDFs were converted with `pdftotext -layout` and the DRP tables were
   parsed by address, bit range, access and attribute name, with the attribute
   encodings of the multi-line rows collected per row. The parser was checked
   against the existing drivers first: every field of `Gtye4Channel`,
   `Gtye4Common` and `Gthe3Common` matched its UG578 Table C-2, C-1 or UG576
   Table B-1 row (one known exception: `Gtye4Channel.TX_FIFO_BYP_EN` sits on
   bit 3 of word 0x0A where UG578 v1.4 moved it to bit 0, a revision change
   outside this task).
2. A generator wrote the drivers in the `Gtye4Channel` style (`addVar` with
   `offset = address << 2`, one variable per row, `RO` for read-only rows,
   `RX_PRBS_ERR_CNT` as a two-word list variable, an `EyeScan` child on the
   channel drivers). Enums: the curated `Gtye4Channel` enum where the same
   attribute exists there, the table encodings otherwise; the per-family
   divider, PROGDIV, CPLL divider and SATA VCO tables come from the family's own
   table. Descriptions: the first sentence of the attribute description of the
   user guide where one exists, the `Gtye4Common` text for the QPLL registers,
   hand-written text for the eye-scan registers, and "Reserved. Use the
   recommended value from the Wizard" for reserved attributes.
3. The generated fields were compared with the parsed tables, the golden lists
   `tests/xilinx/eyescan/gthe4_variables.json` and `gtye3_variables.json` were
   captured from the drivers with `eyeScan=False`, and the tests were added.
   The generator and the parsed tables are scratch tooling and are not part of
   the repository.

## Decisions

- GTHE4 eye-scan mask arrays are five words (40-bit bus). UG576 Table C-2 lists
  ten words at the GTYE4 addresses, but Table 4-20 note 1 keeps words 5 to 9 for
  GTY transceivers and the GTH datapath is at most 40 bits (Table 4-46). Words 5
  to 9 stay in the driver as plain registers and the tests check a scan never
  writes them.
- GTHE4 width pairs and dividers reuse the GTHE3 tables; `RXOUT_DIV` and
  `TXOUT_DIV` enums stop at 16 (UG576 Table 4-20).
- GTYE3 reuses the GTYE4 arrays, width pairs and dividers (UG578 Table 4-20 and
  Table 4-49 are the same for both GTY generations).
- Phase-unification rule `sign` for both new descriptors. UG578 Table 4-20
  describes the UltraScale GTY as the `rate` rule (bit 11 set above 10 Gb/s);
  the verified GTHE3 and GTYE4 descriptors use `sign` and the C1100 A/B did not
  separate the rules, so `sign` is kept and `rate` stays a per-call option.
- `Gtye3Channel` declares `TX_FIFO_BYP_EN` and `TX_PI_DIV2_MODE_B` with
  `overlapEn`: UG578 v1.4 Table B-2 lists both on bit 0 of word 0xFB.
- `defaultWidth` 32 and `defaultDivider` 2 for GTHE4 (the SURF UltraScale+ GTH
  IP cores use a 32-bit internal width), 64 and 2 for GTYE3 like GTYE4. These
  only price the scan time estimate before the first scan.
- `hwVerified=False` for both, pinned by tests, until a battery is on record.

## Files

- `python/surf/xilinx/_Gthe4Channel.py`, `_Gthe4Common.py`, `_Gtye3Channel.py`,
  `_Gtye3Common.py`, `__init__.py`
- `python/surf/xilinx/eyescan/_EyeScanFamilies.py`
- `tests/xilinx/eyescan/gt_new_eye_model.py`, `gthe4_variables.json`,
  `gtye3_variables.json`, `test_Gthe4AndGtye3Registers.py`, and the family
  parametrisation of `test_EyeScanFamilies.py`, `test_EyeScanPhase.py`,
  `test_EyeScanSync.py`, `test_EyeScanNoLink.py`, `test_EyeScanDevice.py`
- `python/surf/xilinx/README.md`, `tests/xilinx/eyescan/README.md`

## Validation

- `flake8 --count python/ scripts/ tests/`: 0.
- `PYTHONPATH=python python -m pytest -q --noconftest tests/xilinx/eyescan` in
  a Rogue v6.16.0 environment: 1177 passed, 2 failed. The two failures are the
  `test_EyeScanOutput.py` subprocess tests, which need `pytest` importable from
  a clean interpreter; they fail the same way on the tree before this change and
  pass in CI.

## Open risks and next steps

- No hardware evidence for either family. The first card should run the
  eye-scan battery of [docs/plans/eyescan/README.md](../eyescan/README.md)
  (activation, bathtub, eye, margin) before `hwVerified` is set; the GTYE3 phase
  rule A/B (`sign` against `rate` above 10 Gb/s) is the first thing to settle on
  an UltraScale GTY card.
- The GTHE4 five-word mask decision rests on a footnote of UG576; if a GTHE4 lane
  activates but counts no errors anywhere, the ten-word layout is the first
  alternative to try.
- `Gthe3Common` and `Gtye4Common` do not construct (`__FBDIV_ENUM` is referenced
  before it is defined at module level, a name-mangling error from an earlier
  change). The new Common drivers do not share that code. Fixing the two
  existing drivers is a separate change.
- `Gtye4Channel.TX_FIFO_BYP_EN` (bit 3 of word 0x0A) disagrees with UG578 v1.4
  Table C-2 (bit 0); not changed here.
