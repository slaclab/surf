# SURF RTL Regression Handoff

## Objective
- Build a repo-wide regression system for synthesizable SURF RTL.
- Keep all executable test logic in Python.
- Use `pytest + cocotb + GHDL + ruckus`.
- Keep VHDL only for wrappers, shims, and required simulation models.

## Chosen Constraints
- Python-only test logic
- VHDL wrappers allowed
- Whole-repo target
- Vendor-heavy modules deferred in phase 1
- Comment new Python regression code at a tutorial level, assuming the reader may be new to cocotb
- Give each Python regression the normal SURF/SLAC file header and two distinct comment layers: a module-specific `Test methodology` block under that header and tutorial-style comments in the executable code body
- Give each checked-in cocotb-facing `*IpIntegrator.vhd` wrapper the normal SURF file banner plus section comments for shim setup, DUT instantiation, and any flattening/status wiring
- Treat VHDL packages as transitively covered unless a behavioral function/procedure needs a dedicated wrapper

## Quick Resume Snapshot
- Current frontier: the axi-first pass is complete through the previously remaining final 11 `axi/` modules. `ethernet` and `protocols` are still temporarily deferred in `docs/_meta/rtl_phase1_queue_overrides.json`, but that deferral is now the next thing to unwind rather than an active implementation aid.
- Current axi frontier: complete for the intended simulator-friendly pass in this branch snapshot; do not resume from the older stale `AxiResize` note.
- Current validated-open issues:
  - `tests/axi/axi4/test_AxiResize.py` intentionally keeps the known `32-bit -> 64-bit` upsize failure visible until the separate RTL-fix branch lands.
  - `tests/axi/dma/test_AxiStreamDmaV2Read.py` is still an expected open failure because the DUT aborts under GHDL with `std_logic_arith` `CONV_INTEGER`.
- Current queue discipline:
  - The next session should remove the temporary `ethernet` and `protocols` subsystem deferrals from `docs/_meta/rtl_phase1_queue_overrides.json`.
  - After removing those deferrals, regenerate `docs/_meta/rtl_phase1_queue.{md,json}` and resume from the regenerated cross-subsystem frontier.
  - Do not hand-maintain queue order in the plan or handoff docs.
- Current wrapper discipline:
  - Prefer the existing subsystem `ip_integrator/` shim layers over bespoke record flattening.
  - Keep first-pass wrapper benches intentionally narrow and document any omitted branches explicitly.
  - Use `start_lockstep_clocks()` when a DUT depends on truly shared clock edges.
  - When a wrapper is checked in, write it like the surrounding repo HDL: include the SLAC/SURF banner and enough section comments that a new session can identify the shim, DUT, and flattening regions quickly.
- Current cocotb-file discipline:
  - New test files should start with the standard SURF/SLAC header block.
  - The `Test methodology` block belongs directly under that header.
  - In-body tutorial comments are still required; the methodology block does not replace them.

## Session Learnings To Preserve
- Start with the smallest stable wrapper that exposes the DUT cleanly to cocotb. Reuse the existing subsystem `ip_integrator/` shims before inventing bespoke flattening or a generated wrapper.
- Prefer checked-in subsystem wrappers for durable integration patterns and generated wrappers only when the real problem is simulator-hostile generic binding.
- If a Python cocotb file is permanent enough to check in, do not leave it with a custom or abbreviated header. Use the standard repo header immediately, then add the methodology block and tutorial comments in the same first pass.
- If a wrapper is permanent enough to check in, do not leave it as a bare anonymous adapter. Add the standard SURF banner and short section comments immediately, not as a cleanup pass later.
- For AXI and AXI-Lite benches, the practical first-pass shape is usually:
  - cocotb protocol master on the control/request side,
  - cocotb RAM or simple protocol model on the generated/response side,
  - lightweight monitors on accepted handshakes when timing or burst shape matters.
- Do not rely on final memory contents alone when the contract includes timing-visible behavior. Record accepted handshakes if the bench is supposed to prove spacing, burst length, sideband propagation, partial-last-beat strobes, or arbitration order.
- For `COMMON_CLK_G` style wrappers, use one shared clock coroutine via `start_lockstep_clocks()` when the RTL expects true shared edges rather than merely equal nominal periods.
- For first-pass wrapper benches, prove the externally visible stable path first and defer shakier simulator-sensitive branches explicitly in the docs instead of stretching one bench to cover everything.

## Current Status
Planning is complete enough to start implementation. The agreed direction is a Python-only executable regression framework with tiered `smoke` and `functional` coverage. Existing VHDL TBs are reference material only and should be rewritten in Python when migrated, unless a thin wrapper is still useful for cocotb access.

The repo now has the initial handoff artifacts, a checked-in inventory scaffold at `docs/_meta/rtl_regression_inventory.yaml`, and local bootstrap helpers in `scripts/setup_regression_env.sh` plus `.vscode/tasks.json`. The first pilot modules were `FifoAsync`, `AxiStreamFifoV2`, and `AxiLiteAsync`, and the work has since moved into a graph-guided bottom-up rollout across `base/`.

The local machine now has `ghdl`, a working `.venv`, the Python regression packages, a repo-local `ruckus` link to `~/ruckus`, and a successful `make MODULES="$PWD" import` run. Local environment bootstrap is no longer the blocker. The first shared-helper-based pilot regression now exists in `tests/base/fifo/test_FifoAsync.py` and passes locally.

New regressions are now being organized by subsystem under `tests/`, with shared helpers in `tests/common/`. The `FifoAsync` pilot lives in `tests/base/fifo/test_FifoAsync.py`, and `AxiStreamFifoV2` now lives in `tests/axi/axi_stream/test_AxiStreamFifoV2IpIntegrator.py`. New work should follow that package layout instead of adding more flat files under `tests/`.

`FifoAsync` now has a validated expanded 12-case matrix, `FifoSync` has a validated expanded 11-case matrix, `Synchronizer` and `SynchronizerVector` now each have validated 6-case matrices under `tests/base/sync/`, `RstPipeline` has a validated 4-case matrix under `tests/base/general/`, `SimpleDualPortRam` has a validated 5-case matrix under `tests/base/ram/`, `FifoOutputPipeline` has a validated 5-case matrix under `tests/base/fifo/`, and `FifoWrFsm` has a validated 4-case matrix under `tests/base/fifo/`.

The next graph-guided 10-module follow-on is also now in place: `Crc32Parallel`, `Crc32`, `CRC32Rtl`, `RstSync`, `PwrUpRst`, `SynchronizerEdge`, `SynchronizerOneShot`, `TrueDualPortRam`, `LutRam`, and `FifoRdFsm`. The combined validation command for that batch is `./.venv/bin/python -m pytest -v tests/base/crc/test_Crc32Parallel.py tests/base/crc/test_Crc32.py tests/base/crc/test_CRC32Rtl.py tests/base/sync/test_RstSync.py tests/base/general/test_PwrUpRst.py tests/base/sync/test_SynchronizerEdge.py tests/base/sync/test_SynchronizerOneShot.py tests/base/ram/test_TrueDualPortRam.py tests/base/ram/test_LutRam.py tests/base/fifo/test_FifoRdFsm.py`, and it currently passes with `38 passed`.

The next 15-module `base/` general/delay/sync batch is now also implemented and validated: `Arbiter`, `ClockDivider`, `Debouncer`, `Gearbox`, `Heartbeat`, `Mux`, `OneShot`, `RegisterVector`, `RstPipelineVector`, `Scrambler`, `WatchDogRst`, `SlvDelay`, `SlvFixedDelay`, `SynchronizerFifo`, and `SynchronizerOneShotCnt`. The combined validation command for that batch is `./.venv/bin/python -m pytest -n 0 -q tests/base/general/test_Arbiter.py tests/base/general/test_ClockDivider.py tests/base/general/test_Debouncer.py tests/base/general/test_Gearbox.py tests/base/general/test_Heartbeat.py tests/base/general/test_Mux.py tests/base/general/test_OneShot.py tests/base/general/test_RegisterVector.py tests/base/general/test_RstPipelineVector.py tests/base/general/test_Scrambler.py tests/base/general/test_WatchDogRst.py tests/base/delay/test_SlvDelay.py tests/base/delay/test_SlvFixedDelay.py tests/base/sync/test_SynchronizerFifo.py tests/base/sync/test_SynchronizerOneShotCnt.py`, and it currently passes with `41 passed`.

The next 10-module wrapper/integration batch is now also implemented and validated: `DspComparator`, `Fifo`, `FifoCascade`, `FifoMux`, `AsyncGearbox`, `SynchronizerOneShotVector`, `SynchronizerOneShotCntVector`, `SyncStatusVector`, `SyncTrigPeriod`, and `SyncMinMax`. The combined validation command for that batch is `./.venv/bin/python -m pytest -n 0 -q tests/dsp/generic/test_DspComparator.py tests/base/fifo/test_Fifo.py tests/base/fifo/test_FifoCascade.py tests/base/fifo/test_FifoMux.py tests/base/general/test_AsyncGearbox.py tests/base/sync/test_SynchronizerOneShotVector.py tests/base/sync/test_SynchronizerOneShotCntVector.py tests/base/sync/test_SyncStatusVector.py tests/base/sync/test_SyncTrigPeriod.py tests/base/sync/test_SyncMinMax.py`, and it currently passes with `18 passed`.

The remaining practical non-vendor, non-dummy `base/` modules are now also implemented and validated: `MasterRamIpIntegrator`, `SlaveRamIpIntegrator`, `DualPortRam`, `SlvDelayRam`, `SlvDelayFifo`, `SyncClockFreq`, `SyncTrigRate`, and `SyncTrigRateVector`. The combined validation command for that batch is `./.venv/bin/python -m pytest -n 0 -q tests/base/general/test_MasterRamIpIntegrator.py tests/base/general/test_SlaveRamIpIntegrator.py tests/base/ram/test_DualPortRam.py tests/base/delay/test_SlvDelayRam.py tests/base/delay/test_SlvDelayFifo.py tests/base/sync/test_SyncClockFreq.py tests/base/sync/test_SyncTrigRate.py tests/base/sync/test_SyncTrigRateVector.py`, and it currently passes with `15 passed`.

`Crc32` now covers multiple common 32-bit polynomials instead of only the default IEEE CRC-32 polynomial. That test uses a thin wrapper at `tests/base/crc/hdl/Crc32PolyWrapper.vhd` because the local GHDL flow rejects direct command-line overrides of the `CRC_POLY_G : slv(31 downto 0)` generic. Pytest still defaults to `-n auto --dist=worksteal` through `pytest.ini` so parameterized regressions fan out across worker processes by default.

The project now also has a shared generated-wrapper path in `tests/common/regression_utils.py` for cases where the DUT is fine but the local simulator does not handle a generic interface cleanly. `Heartbeat` and `Debouncer` were migrated away from checked-in one-off wrapper files to generated test-local wrappers, and future real-generic shim cases should follow that pattern by default.

`tests/common/regression_utils.py` now also includes `start_lockstep_clocks()` for DUTs whose generics assume truly common clocks in both ports. Use that helper instead of launching two same-period clocks independently when the RTL assumes shared edge identity.

The wrapper coverage policy is now more explicit in practice: test the wrapper-specific behavior, not the full leaf matrix again. `Fifo` validated both inferred sync/async selection branches, `FifoCascade` validated public stage-vector mapping plus a curated output smoke, and `FifoMux` is currently validated only on the stable split-to-narrow path. The pack-to-wide `FifoMux` path should be treated as still open rather than silently assumed covered.

That same wrapper-policy lesson now applies to the late `base/sync` wrappers as well. `SyncClockFreq` is stable with a generated wrapper, but its common-clock measurement quantizes one count above the abstract target under the current GHDL flow, so the regression checks a bounded expected range rather than an exact integer. `SyncTrigRate` is intentionally covered as a wrapper/integration bench only: it proves aligned update publication, denser-window rate growth, reset-path liveness, and strobe pulse behavior, while exact min/max pipeline semantics remain the responsibility of the dedicated `SyncMinMax` leaf test.

At this point the practical phase-1 `base/` rollout is effectively complete. The only uncovered non-dummy `base/` module is `LutFixedDelay`, and it remains deferred because it still depends on the vendor-backed `SinglePortRamPrimitive` path. The other remaining `base/` gaps are vendor-heavy or dummy-backed variants.

The first post-`base/` `axi/` follow-on is now in place as well. `AxiStreamPipeline` is validated under `tests/axi/axi_stream/test_AxiStreamPipeline.py` using a thin flat-port adapter at `axi/axi-stream/ip_integrator/AxiStreamPipelineIpIntegrator.vhd`, and `AxiLiteCrossbar` is validated under `tests/axi/axi_lite/test_AxiLiteCrossbar.py` using the existing `axi/axi-lite/tb/AxiLiteCrossbarTb.vhd` harness as a cocotb-facing shell. The combined validation command is `./.venv/bin/python -m pytest -n 0 -q tests/axi/axi_stream/test_AxiStreamPipeline.py tests/axi/axi_lite/test_AxiLiteCrossbar.py`, and it currently passes with `4 passed`.

For `AxiStreamPipeline`, treat the zero-stage case as a true combinational pass-through and the staged cases as wrapper-visible buffered paths. The stable expectation under the current wrapper is sink-handshake latency of `PIPE_STAGES_G + 2` clocks plus bounded reset flush behavior, not a naive one-to-one mapping from the user generic name. For `AxiLiteCrossbar`, the useful regression surface is region routing, decode-miss `DECERR` handling, and concurrent traffic through the existing cascaded harness topology rather than a broad generic sweep.

`AxiStreamMux` is now validated under `tests/axi/axi_stream/test_AxiStreamMux.py` using a thin two-input adapter at `axi/axi-stream/ip_integrator/AxiStreamMuxIpIntegrator.vhd`. The module-local validation command is `./.venv/bin/python -m pytest -n 0 -q tests/axi/axi_stream/test_AxiStreamMux.py`, and it currently passes with `3 passed`. A small follow-on sanity run across `tests/axi/axi_stream/test_AxiStreamPipeline.py`, `tests/axi/axi_stream/test_AxiStreamMux.py`, and `tests/axi/axi_lite/test_AxiLiteCrossbar.py` also passes with `7 passed`. Keep the validated subset intentionally narrow: indexed arbitration with explicit priority plus `disableSel`, routed `TDEST`/`TID` remap under backpressure, and staged asynchronous active-low reset recovery in passthrough mode. Interleave and explicit rearbitrate branches remain open for later work. Also note the mux-specific nuance from this bench: `disableSel` is applied before the separate priority-mask generation, so a disabled higher-priority source can still suppress lower-priority requesters.

`AxiStreamDeMux` is now validated under `tests/axi/axi_stream/test_AxiStreamDeMux.py` using a thin one-input/two-output adapter at `axi/axi-stream/ip_integrator/AxiStreamDeMuxIpIntegrator.vhd`. The module-local validation command is `./.venv/bin/python -m pytest -n 0 -q tests/axi/axi_stream/test_AxiStreamDeMux.py`, and it currently passes with `3 passed`. A small follow-on sanity run across `tests/axi/axi_stream/test_AxiStreamPipeline.py`, `tests/axi/axi_stream/test_AxiStreamMux.py`, `tests/axi/axi_stream/test_AxiStreamDeMux.py`, and `tests/axi/axi_lite/test_AxiLiteCrossbar.py` passes with `10 passed`. Keep the validated subset intentionally narrow: indexed decode to both outputs, exact-match routed decode under output backpressure, and dynamic-route table behavior including unmatched-destination drop plus staged asynchronous active-low reset flush. Wildcard-route patterns and larger fanout counts remain open for later work.

The next five flat-queue modules are now also in place and validated. `AxiStreamResize` uses `axi/axi-stream/ip_integrator/AxiStreamResizeIpIntegrator.vhd` plus `tests/axi/axi_stream/test_AxiStreamResize.py`; `AxiLiteAsync` uses `axi/axi-lite/ip_integrator/AxiLiteAsyncIpIntegrator.vhd` plus `tests/axi/axi_lite/test_AxiLiteAsync.py`; `AxiLiteMaster` uses `axi/axi-lite/ip_integrator/AxiLiteMasterIpIntegrator.vhd` plus `tests/axi/axi_lite/test_AxiLiteMaster.py`; `AxiLiteToDrp` uses `axi/bridge/ip_integrator/AxiLiteToDrpIpIntegrator.vhd` plus `tests/axi/bridge/test_AxiLiteToDrp.py`; and `AxiDualPortRam` is validated through the existing `axi/axi-lite/ip_integrator/AxiDualPortRamIpIntegrator.vhd` wrapper plus `tests/axi/axi_lite/test_AxiDualPortRam.py`. The five-module validation command is `./.venv/bin/python -m pytest -n 0 -q tests/axi/axi_stream/test_AxiStreamResize.py tests/axi/axi_lite/test_AxiLiteAsync.py tests/axi/axi_lite/test_AxiLiteMaster.py tests/axi/bridge/test_AxiLiteToDrp.py tests/axi/axi_lite/test_AxiDualPortRam.py`, and it currently passes with `10 passed`. A broader AXI follow-on sanity run across pipeline, mux, demux, resize, crossbar, async, master, DRP bridge, and dual-port RAM also passes with `20 passed`.

The next 10 generated-queue AXI modules are now also in place and validated. `AxiLiteRegs`, `AxiLiteRespTimer`, `AxiLiteSlave`, `AxiLiteWriteFilter`, and `AxiVersion` are covered under `tests/axi/axi_lite/` with thin subsystem-local wrappers in `axi/axi-lite/ip_integrator/`. `AxiStreamCombiner`, `AxiStreamFlush`, `AxiStreamGearboxPack`, `AxiStreamGearboxUnpack`, and `AxiStreamSplitter` are covered under `tests/axi/axi_stream/` with thin subsystem-local wrappers in `axi/axi-stream/ip_integrator/`. The combined validation command is `./.venv/bin/python -m pytest -n 0 -q tests/axi/axi_lite/test_AxiLiteRegs.py tests/axi/axi_lite/test_AxiLiteRespTimer.py tests/axi/axi_lite/test_AxiLiteSlave.py tests/axi/axi_lite/test_AxiLiteWriteFilter.py tests/axi/axi_lite/test_AxiVersion.py tests/axi/axi_stream/test_AxiStreamCombiner.py tests/axi/axi_stream/test_AxiStreamFlush.py tests/axi/axi_stream/test_AxiStreamGearboxPack.py tests/axi/axi_stream/test_AxiStreamGearboxUnpack.py tests/axi/axi_stream/test_AxiStreamSplitter.py`, and it currently passes with `14 passed`.

Keep the validated subset intentionally narrow for the two most timing-sensitive wrappers. `AxiStreamResize` covers equal-width pass-through plus curated upsize/downsize cases with sideband alignment and staged reset flush. `AxiLiteMaster` covers request/ack sequencing, staggered AXI ready/valid handshakes, propagated `SLVERR` responses, and reset return to idle. `AxiDualPortRam` covers AXI round-trips, system-port visibility, byte-masked system writes, and AXI write-disable error responses through the existing wrapper. `AxiLiteAsync` is currently validated only on the stable `COMMON_CLK_G=true` wrapper path; the asynchronous reset-crossing branches remain open for later work. `AxiLiteToDrp` is currently validated only on the stable common-clock non-arbitrated path with timeout recovery; the async arbitration branch remains open for later work.

`AxiRateGen` is now also validated under `tests/axi/axi4/test_AxiRateGen.py` using `axi/axi4/ip_integrator/AxiRateGenIpIntegrator.vhd`. The module-local validation command is `./.venv/bin/python -m pytest -n 0 -q tests/axi/axi4/test_AxiRateGen.py`, and it currently passes with `1 passed`. Keep the validated subset intentionally narrow here too: the stable `COMMON_CLK_G=true` path covers AXI-Lite register programming, timer-spaced generated AXI writes, and generated-read completion through a cocotb AXI RAM model, while the asynchronous AXI-Lite crossing branches remain open for later work.

The remaining final 11 `axi/` modules from the axi-first pass are now also implemented and validated. The new checked-in benches are:
- `tests/axi/axi4/test_AxiReadEmulate.py`
- `tests/axi/axi4/test_AxiWriteEmulate.py`
- `tests/axi/axi4/test_AxiRingBuffer.py`
- `tests/axi/axi4/test_AxiMonAxiL.py`
- `tests/axi/axi_lite/test_AxiLiteRamSyncStatusVector.py`
- `tests/axi/axi_stream/test_AxiStreamMonAxiL.py`
- `tests/axi/dma/test_AxiStreamDmaWrite.py`
- `tests/axi/dma/test_AxiStreamDma.py`
- `tests/axi/dma/test_AxiStreamDmaFifo.py`
- `tests/axi/dma/test_AxiStreamDmaRingRead.py`
- `tests/axi/dma/test_AxiStreamDmaRingWrite.py`

The supporting wrappers added for that batch are:
- `axi/axi4/ip_integrator/AxiReadEmulateIpIntegrator.vhd`
- `axi/axi4/ip_integrator/AxiWriteEmulateIpIntegrator.vhd`
- `axi/axi4/ip_integrator/AxiRingBufferIpIntegrator.vhd`
- `axi/axi4/ip_integrator/AxiMonAxiLIpIntegrator.vhd`
- `axi/axi-lite/ip_integrator/AxiLiteRamSyncStatusVectorIpIntegrator.vhd`
- `axi/axi-stream/ip_integrator/AxiStreamMonAxiLIpIntegrator.vhd`
- `axi/dma/ip_integrator/AxiStreamDmaWriteIpIntegrator.vhd`
- `axi/dma/ip_integrator/AxiStreamDmaFifoIpIntegrator.vhd`
- `axi/dma/ip_integrator/AxiStreamDmaIpIntegrator.vhd`
- `axi/dma/ip_integrator/AxiStreamDmaRingReadIpIntegrator.vhd`
- `axi/dma/ip_integrator/AxiStreamDmaRingWriteIpIntegrator.vhd`

The combined validation command for that batch is `./.venv/bin/python -m pytest -n 0 -q tests/axi/axi4/test_AxiReadEmulate.py tests/axi/axi4/test_AxiWriteEmulate.py tests/axi/axi4/test_AxiRingBuffer.py tests/axi/axi4/test_AxiMonAxiL.py tests/axi/axi_lite/test_AxiLiteRamSyncStatusVector.py tests/axi/axi_stream/test_AxiStreamMonAxiL.py tests/axi/dma/test_AxiStreamDmaWrite.py tests/axi/dma/test_AxiStreamDma.py tests/axi/dma/test_AxiStreamDmaFifo.py tests/axi/dma/test_AxiStreamDmaRingRead.py tests/axi/dma/test_AxiStreamDmaRingWrite.py`, and it passes locally with `11 passed`.

One small RTL fix landed during that validation pass because the new `AxiStreamDmaRingWrite` test exposed a real simulation-width hazard: `axi/dma/rtl/v1/AxiStreamDmaRingWrite.vhd` now slices `dmaAck.size` back to `RAM_DATA_WIDTH_C` before incrementing `nextAddr`. Keep that change; it is what allows the checked-in narrow wrapper to simulate cleanly under GHDL.

A first-pass RTL instantiation graph is now checked in at `docs/_meta/rtl_instantiation_graph.md` and `docs/_meta/rtl_instantiation_graph.json`, and the same generator now also emits a path-qualified bottom-up phase-1 queue at `docs/_meta/rtl_phase1_queue.md` and `docs/_meta/rtl_phase1_queue.json`. Keep the graph for provenance, but treat the generated queue as the default source of truth for what to implement next. Manual phase-1 deferrals and order exceptions belong in `docs/_meta/rtl_phase1_queue_overrides.json`, not as hand-edited ordering in the plan doc.

## Immediate Next Task
Remove the temporary `ethernet` and `protocols` subsystem deferrals from `docs/_meta/rtl_phase1_queue_overrides.json`, regenerate `docs/_meta/rtl_phase1_queue.{md,json}`, and then resume from the regenerated cross-subsystem frontier. Do not resume from the older stale `AxiResize` checkpoint.

## Read Order
1. `docs/_meta/rtl_regression_handoff.md`
2. `docs/_meta/rtl_regression_progress.md`
3. `docs/_meta/rtl_regression_plan.md`
4. `docs/_meta/rtl_phase1_queue.md`

Before writing code in a fresh session:
1. Re-read the Python comment rules and the checked-in wrapper comment/header rules above.
2. If adding a permanent `*IpIntegrator.vhd`, include the standard SURF banner and section comments in the first edit, not as an afterthought.
3. If adding a Python regression, include the standard SURF/SLAC header, the `Test methodology` header block, and in-body tutorial comments in the first draft.

## Important Repo Facts
- New Python regressions should be organized under subsystem packages in `tests/`
- Shared Python regression helper lives in `tests/common/regression_utils.py`
- `tests/common/regression_utils.py` now supports both test-local extra VHDL source lists and generated test-local wrapper emission for wrapper-based cases
- `tests/common/regression_utils.py` also now provides `start_lockstep_clocks()` for `COMMON_CLK_G` style benches that require truly shared edges
- Default comment style for new cocotb tests has two parts: a wrapped four-bullet `Test methodology` header (`Sweep`, `Stimulus`, `Checks`, `Timing`) plus tutorial-style in-body comments that explain what each coroutine step is doing and why
- New cocotb tests should also use the standard SURF/SLAC file header, not a shortened local variant
- The methodology header should be module-specific and describe the real curated sweep, driven sequence, expected outputs/state changes, and timing checks; avoid generic boilerplate
- Keep methodology comment lines to a normal readable width in the source file
- Checked-in cocotb-facing `*IpIntegrator.vhd` files should also follow repo style: standard SLAC/SURF banner at the top and short section comments marking shim setup, DUT hookup, and flattening/status export logic
- For AXI Stream and AXI-Lite record ports, prefer the existing IP-integrator shim entities to flatten record interfaces for cocotb instead of hand-writing record packing in each wrapper
- If an AXI wrapper needs DUT-specific extra signals, keep the standard shim pair for the bus itself and only wire the extra signals manually
- More generally, if any module needs a VHDL shim layer to fit cleanly into the cocotb flow, that shim belongs in the nearest real subsystem `ip_integrator/` tree rather than under `tests/`
- Do not use generic `hdl/` buckets for cocotb-facing adapter layers; reserve those locations for genuinely different kinds of HDL support
- Many VHDL wrappers live under `*/tb/`
- The initial regression inventory lives in `docs/_meta/rtl_regression_inventory.yaml`
- The RTL instantiation graph lives in `docs/_meta/rtl_instantiation_graph.{md,json}`
- The generated path-qualified phase-1 module queue lives in `docs/_meta/rtl_phase1_queue.{md,json}`; use that queue plus the progress doc as the next-module source of truth instead of re-analyzing the graph JSON every time
- Manual phase-1 queue deferrals and order overrides live in `docs/_meta/rtl_phase1_queue_overrides.json`
- Use `./.venv/bin/python ...` for repo-local Python commands unless the virtualenv has already been activated in the current shell; do not assume a `python` shim exists on `PATH`
- If GHDL rejects a direct command-line override for a non-scalar or real generic, prefer a generated thin test-only wrapper over simulator-specific literal workarounds or another checked-in one-off HDL shim
- If a wrapper branch is unstable under the current open-source flow, keep the validated subset narrow and record the omitted branch explicitly in the docs instead of over-claiming wrapper coverage
- `LutFixedDelay` remains intentionally deferred because it depends on `SinglePortRamPrimitive`; do not accidentally treat the now-small remaining `base/` set as phase-1 work that still needs to be forced through
- Regenerate the graph and the phase-1 queue with `./.venv/bin/python scripts/build_rtl_instantiation_graph.py`
- Local bootstrap entrypoint: `scripts/setup_regression_env.sh`
- Local `ruckus` is linked from `~/ruckus`

## Resume Rule
If resuming implementation, update `docs/_meta/rtl_regression_progress.md` first.
