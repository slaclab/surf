# AxiLiteAsync Remote Reset Recovery

## Goal And Scope

Stop `AxiLiteAsync` replaying transactions it already rejected. With
`COMMON_CLK_G = false`, an access issued while the master domain was reset was
answered with `AXI_ERROR_RESP_G` on the slave side but queued at the same time,
so it executed once `mAxiClk` and `mAxiClkRst` recovered.

Limited to `axi/axi-lite/rtl/AxiLiteAsync.vhd` and its cocotb regression. No port
or generic changes. GitHub issue #1467. Requested constraints: minimal added
logic, no impact on timing closure.

## Current Status

Complete. Every defect below has a test that fails when only its own fix is
reverted, with one documented exception.

## Defects

All in the `GEN_ASYNC` branch.

1. FIFO write enables were not gated by the remote reset, so a rejected request
   was queued anyway.
2. Request FIFOs were reset only by `s2mRst`, which carries `sAxiClkRst`, so a
   request queued before `mAxiClkRst` also survived. Mirror image: response FIFOs
   were not flushed by a slave-domain reset.
3. `AW` and `W` cross in separate FIFOs, so a write straddling the reset left an
   orphaned address that misdirected the next write's data.
4. `RVALID` and `BVALID` were forced to `'1'`, so a response could appear with no
   matching request.
5. Reset comparisons were written against `'0'`, inverting fail-fast when
   `RST_POLARITY_G = '0'`.

## Design Decisions

**One shared, registered, active-high `fifoRst` for all five FIFOs**, generated
in the `sAxiClk` control domain by a one-bit `RegisterVector`. `sAxiClkRst`
first passes through a local `RstSync`, then asynchronously asserts the
reset-request register; `mAxiClkRst` is synchronized into `sAxiClk` before
entering its synchronous data input. Release is synchronous and held until the
local error responder drains the abandoned transaction. `FifoAsync` then
resynchronizes the single registered request into both FIFO domains. The FIFO
instances use active-high reset internally regardless of the bridge's external
reset polarity, so the register directly drives every reset synchronizer
without an intervening polarity-select LUT. This avoids both combinational
logic and multi-clock fan-in ahead of the synchronizers.

Clock/reset contract: if either AXI clock is unavailable, its corresponding
reset must remain asserted. The clock must be stable before reset release, and
traffic must remain inactive until synchronized release completes. A reset of
the slave/source domain abandons its outstanding transactions, so they require
no response.

**One transaction in flight per channel, matching `AxiLiteCrossbar`** (maintainer
decision). The bridge does not need the bound: measured on unmodified RTL it
accepts 4 outstanding reads and returns all 4 in order. But `AxiLiteCrossbar`
does not release a slave slot until `rvalid and rready`, and `AxiLiteMaster` runs
one at a time, so no SURF topology exceeds one.

Tracking must exist regardless, because `fifoRst` discards in-flight requests
that still owe a response. Matching the crossbar makes that one flag per channel
instead of a counter, which is the whole cost of the fix. The bound is therefore
enforced by the ready outputs and by making every FIFO write conditional on its
source-side handshake, in normal operation as well as during reset:
measured, a flag responder without the bound answers 1 of 4 abandoned reads and
hangs the master. Consequence, a master that pipelines is throttled to one
transaction, which matters because `AxiLiteAsyncIpIntegrator` exposes the slave
port to non-SURF masters.

**Rejected: size tracking to FIFO capacity.** Three 7-bit counters, correct for
any AXI4-Lite master and preserving throughput, but +45 LUTs and +22 flip-flops
on a primitive used in more than 40 modules.

Reset polarity is normalized once into active-high terms.

## Resource And Timing

Vivado 2025.2, out-of-context synthesis and implementation,
`xcku040-ffva1156-2-e`, `sAxiClk` at 2.5 ns and `mAxiClk` at 2.0 ns declared
asynchronous.

| | Baseline | Counters (rejected) | Bounded (shipped) |
| --- | --- | --- | --- |
| CLB LUTs | 312 | 357 | 309 |
| CLB registers | 473 | 495 | 477 |
| WNS `sAxiClk` | +0.485 ns | +0.397 ns | +0.527 ns |
| WNS `mAxiClk` | +0.293 ns | +0.215 ns | +0.184 ns |

Shipped version is 3 LUTs smaller than the unfixed baseline for 4 flip-flops. All
variants meet timing and no handshake output gained a logic level. The `mAxiClk`
worst path reports 0 logic levels, so its roughly 100 ps movement is routing
noise at this scale.

## Files And Tests

- `axi/axi-lite/rtl/AxiLiteAsync.vhd`
- `tests/axi/axi_lite/test_AxiLiteAsync.py`

`AxiLiteAsyncIpIntegrator.vhd` needed no change; it already exposes both clocks
and resets and passes real response codes through.

Sweep: 5 cases (common-clock, plus asynchronous active-high, active-low,
`RST_ASYNC_G = true`, `PIPE_STAGES_G = 2`), 9 cocotb tests each.

| Defect or behaviour | Test |
| --- | --- |
| 2 | `remote_reset_inflight_flush_test` |
| 3 | `remote_reset_orphan_pairing_test` |
| 4 | `reset_behavior_test`, `remote_reset_write_order_test` |
| 5 | `async_active_low` case |
| Rejected request replayed | `remote_reset_ghost_test` |
| Mirror image of 2 | `source_reset_stale_response_test` |
| Reset of the new registered state | `source_reset_clears_outstanding_test` |
| One-transaction bound | `single_outstanding_bound_test` |

`source_reset_clears_outstanding_test` is what gives the reset cases teeth.
Adding a `RST_ASYNC_G = true` case alone compiled the asynchronous reset branch
without checking it, and disabling that branch still passed. With this test,
breaking only the sequential asynchronous reset fails just that case and breaking
only the combinational synchronous reset fails just the others.

**Exception:** defect 1 is not independently covered. Removing the write-enable
gating passes the whole regression, because `fifoRst` holds the FIFOs in reset
for the entire local-answer window so the write pointer cannot advance. Kept
anyway: one LUT input, it states the invariant explicitly instead of depending on
`FifoAsync` ignoring `wr_en` while reset, and it stays correct if `fifoRst` is
ever narrowed.

`single_outstanding_bound_test` also holds a second `AR`, `AW`, and `W` while
the corresponding ready output is low and verifies that none of those
unaccepted beats crosses to the downstream slave.

## Validation Run

- Reproduced first: unmodified RTL replayed the rejected write and read
  downstream after recovery.
- `pytest tests/axi/axi_lite/test_AxiLiteAsync.py`, 5 cases.
- `pytest -n auto tests/`, 1017 passed and 29 skipped. Run in full because
  `AxiLiteAsync` is instantiated in `axi`, `dsp` and every GigE and 10GigE core.
- `make MODULES="$PWD" analysis` clean library wide.
- `vsg -c vsg-linter.yml` clean; `flake8 --count python/ scripts/ tests/` 0.
- Vivado numbers above: all SURF sources into library `surf` and ruckus into
  `ruckus`, testbenches excluded, `synth_design -mode out_of_context` then
  `opt_design`, `place_design`, `phys_opt_design`, `route_design`.

Do not run `pytest -n auto` while Vivado implementation is running. The
`tests/simlink` tests are timing sensitive and fail from CPU starvation.

## Open Risks And Next Steps

- The bound is now enforced, so a previously pipelining external master is
  throttled. Correctness unaffected, throughput not.
- Synthesis numbers are out-of-context on one part; absolute slack will differ
  inside a real design.
- The resource and timing table predates the registered reset-request review
  revision and must be remeasured before using the exact numbers in release
  notes.
- Rerun Vivado `report_cdc -details -all_checks_per_endpoint` on the revised
  reset topology and confirm that the former FIFO-reset CDC-10/CDC-12 paths are
  gone. Vivado is not available in the current validation environment.
- `NUM_ADDR_BITS_G` exercised only at 12 in simulation and 32 in synthesis.
- With one transaction in flight the 16-deep FIFOs are oversized and their 96
  distributed-RAM LUTs now dominate the module. Shrinking `FIFO_ADDR_WIDTH_C` is
  the obvious next saving, left out as an optimisation rather than part of the fix.
