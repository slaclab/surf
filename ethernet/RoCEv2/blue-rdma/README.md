This directory holds machine-generated VHDL for the blue-rdma RDMA engine, transpiled by
`tools/bsc2vhdl` from Bluespec Compiler (BSC) 2023.01-generated Verilog in the
`ruck314/blue-rdma` fork (branch `feat/deeper-sq-rnr-infinite`, commit
`53a7b0e0ac19cecc36c951616bec0056609a8ebc`). Each `.vhd` must never be hand-edited; each was
regenerated in place from its unmodified Verilog source and reviewed with `git diff --quiet`
reporting no change afterward. The Verilog originals themselves no longer ship in this
repository: the fork above is the only place the corpus exists, and any future regeneration
proof depends on it staying reachable.

`tools/bsc2vhdl` also emits a `<module>.namemap.json` beside each `.vhd`, mapping every
original BSC identifier to the VHDL identifier the transpiler produced for it. Those maps are
not shipped here because nothing in this repository reads them; regenerate them from the fork
when a waveform of the generated VHDL needs to be traced back to its BSV rule names.

## The hierarchy runs the opposite way from line count

`mkAxisTransportLayer` (3,944 lines) instantiates `mkTransportLayer` (15,995 lines), which
instantiates `mkQP` (33,443 lines), which instantiates only already-converted blue-lib
primitives. **`mkQP` is the leaf of the instantiation chain, not its summit.** Line count
describes translation difficulty, which is real and drove the bottom-up conversion order, but
elaboration dependency runs the other way: `mkQP` had to be converted first because everything
above it needs it bound before it can elaborate at all.

## Conversion record

| Verilog file | Lines | Verilog module name | VHDL entity | Instantiated children |
|---|---:|---|---|---|
| `mkQP.v` | 33,443 | `mkQP` | `mkQP` | `FIFO2` x65, `SizedFIFO` x2, `Counter` x2, `BRAM2` x1 |
| `mkTransportLayer.v` | 15,995 | `mkTransportLayer` | `mkTransportLayer` | `mkQP` x1, `FIFO2` x45, `FIFO20` x1, `Counter` x1 |
| `mkAxisTransportLayer.v` | 3,944 | `mkAxiSTransportLayer` (capital S) | `mkAxisTransportLayer` | `mkTransportLayer` x1, `FIFO2` x8 |

**The capital-S discrepancy is real and deliberate, not a typo in this table.**
`mkAxisTransportLayer.v` declares a Verilog module named `mkAxiSTransportLayer` (capital
`S`), but the emitted VHDL entity and every file this conversion produces for it use the
file's own stem, `mkAxisTransportLayer` (lowercase `s`), exactly as `tools/bsc2vhdl`'s own
output-naming rule requires: the output name follows the *input file's* stem, never the
module name declared inside it.

## What this record claims

This section is a historical record of what was established at conversion time, against
Bluespec-generated Verilog sources that no longer ship in this repository. It is not a set of
checks that run today; see "What is checked now" below for those.

- Each `.vhd` above was byte-regenerable from the fork's unmodified `.v` source by
  `tools/bsc2vhdl`, verified by a scratch regeneration into the shipping location with
  `git diff --quiet` reporting no change afterward, before the Verilog source itself was
  deleted from this repository.
- Each `.vhd` was compared cycle by cycle against its Verilog original through an
  Icarus-record/GHDL-replay harness, with zero mismatches, under a measured and causally
  attributed live-side masking budget on every output port. Every masked window was traced to a
  named `FIFO2` instance's own reset-free pre-first-write window, never declared without a cause.
  That harness, and the recorded vectors it replayed, were retired once the Verilog originals
  they compared against were deleted: with no Verilog left in the tree the harness could no
  longer re-record, and a replay-only half proves nothing the checks below do not.
- The full three-level generated hierarchy (`mkAxisTransportLayer` -> `mkTransportLayer` ->
  `mkQP`, bound to the five hand-written blue-lib children) elaborated under GHDL, exit 0.

## What is checked now

- `make MODULES="$PWD" analysis` analyzes every file in this directory, in dependency order, on
  every CI run.
- `tests/ethernet/RoCEv2/test_RoCEv2AxiStreamRdma.py` simulates the assembled
  `RoCEv2AxiStreamRdma` top level, whose instantiation closure is this whole directory plus the
  blue-lib children. Its directed-write case walks a queue pair from RESET to RTS, posts a
  payload, and checks every field of the emitted frame against a reference built independently
  of this RTL. Elaborating and simulating that closure is a strictly stronger gate than the
  standalone `ghdl -m` check the conversion-time record describes.
- The design has been run on hardware; see the repository's own release notes for the
  sign-off record.

## What this record does not claim

- Nothing about utilization or timing on any particular device. Those are properties of the
  build that instantiates this engine, not of these files.
- The dual-definition exposure that once applied here, library `surf` holding both a Verilog
  module and a VHDL entity of the same name, no longer applies at all: the Verilog originals are
  deleted from this repository, and this directory's own `ruckus.tcl` now loads it by a single
  `loadSource -lib surf -dir` line, the same form used everywhere else in this build
  description.
- The RNR-triggered retry for `mkQP` (the same pending request re-presented after a
  receiver-not-ready NAK) was never proven and remains a known gap.
- Recovery from a reset asserted mid-stream was proven only into the `RESET` state, not all the
  way back to RTS: every one of `mkQP`'s non-`RESET` control-plane rules crashes on a stray
  create-type request, so no scripted stimulus could safely wait for a mid-stream pulse.
