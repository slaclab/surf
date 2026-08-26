# Batcher Regressions

These tests follow the repository-wide [regression style guide](../../README.md)
and [protocol guidance](../README.md). Shared AXI Stream beats, source/sink
drivers, byte compaction, and V2 superframe reference helpers live in
`batcher_test_utils.py`.

The suite is layered deliberately:

- `test_AxiStreamBatcher.py` proves the leaf V2 byte-stream contract, subframe
  metadata, termination controls, and output stability under backpressure.
- `test_AxiStreamBatcherAxil.py` proves reset values, register readback, CDC
  behavior, and the stream-side effects of threshold, gap, soft-reset, and
  blowoff controls. It reuses the leaf oracle instead of repeating the full
  packet matrix.
- `test_AxiStreamBatcherEventBuilder.py` focuses on indexed/routed source
  selection, TDEST remapping, transition frames, alignment checks, timeout and
  bypass/drop policy, counters, and multi-input progress.

Keep future additions at the narrowest layer that owns the behavior. Packet
grammar belongs in the leaf test; register behavior belongs in the AXI-Lite
test; arbitration, routing, and cross-source policy belong in the event-builder
test. Extend `batcher_test_utils.py` for reusable mechanics, but leave the
policy being asserted visible in the individual test.

Run the suite with:

```bash
make MODULES="$PWD" import
./.venv/bin/python -m pytest -n auto --dist=worksteal -q tests/protocols/batcher
```
