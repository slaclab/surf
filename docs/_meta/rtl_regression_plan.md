# SURF RTL Regression Plan

## Objective
- Build a repo-wide regression system for synthesizable SURF RTL.
- Standardize on a single executable test framework so new work stays consistent.
- Make progress resumable across many context windows without re-discovery.

## Chosen Methodology
- Python-only executable test logic.
- Primary stack: `pytest + cocotb + GHDL + ruckus`.
- Local Python commands should use the repo virtualenv interpreter (`./.venv/bin/python`) unless the virtualenv has already been explicitly activated in that shell.
- VHDL is allowed only for thin wrappers, shims, or required simulation models.
- Existing VHDL testbenches are reference material, not execution constraints.
- New Python regression code should use tutorial-style comments by default.
- Every Python regression should also carry a short module-specific `Test methodology` block immediately under the SLAC header comment.
- The header methodology block should use four wrapped bullets: `Sweep`, `Stimulus`, `Checks`, and `Timing`.
- The methodology bullets must describe the actual curated parameter sweep, the actual driven input sequence, the expected outputs or state changes, and the timing/latency/pulse/backpressure behavior being checked for that specific module.
- Do not use generic placeholder methodology prose; the header should tell a reader what this specific bench is proving.
- Keep methodology comment lines at a normal source width so the block is readable in the editor instead of turning into single-line paragraphs.
- Assume the reader is not already comfortable with cocotb.
- Comment the purpose of each major step in the test flow, including clock startup, reset sequencing, trigger waits, stimulus phases, and result checks.
- Treat the header methodology block and the in-body tutorial comments as separate requirements; one does not replace the other.
- Shared helpers may stay somewhat denser, but module-level tests should still explain how the Python coroutine behavior maps onto DUT behavior.
- When a DUT generic assumes truly common clocks, drive those clocks from one shared cocotb coroutine rather than starting two same-period clocks independently.

## Scope
- Whole repo target.
- Phase 1 focuses on simulator-friendly modules.
- Vendor-heavy modules are deferred in phase 1 unless they become practical under the open-source flow.

## Coverage Model
- `functional_python`
  - Module has a Python-authored cocotb regression.
- `smoke_python`
  - Module has compile/elaborate coverage only.
- `wrapper_required`
  - Module needs a retained or added VHDL wrapper to expose a cocotb-friendly interface.
- `deferred_vendor_heavy`
  - Module is intentionally excluded from phase 1 executable regression.

## Package Coverage Policy
- VHDL packages are not treated as standalone executable regression targets.
- Type/constant packages are covered transitively through the modules that compile and use them.
- Behavioral package functions and procedures should be covered through DUTs that exercise them whenever practical.
- If an important package function or procedure is not well reached transitively, add a minimal VHDL wrapper and test that wrapper from Python.
- Package-helper wrappers should be tracked separately from the main synthesizable-module inventory when they are introduced.

## Generic And Configuration Policy
- Generic-heavy modules are Python-first by default.
- Build curated configuration matrices in Python.
- Do not use naive full Cartesian products for broad generic spaces.
- Compute expected behavior dynamically in Python from the active generics.
- If simulator limitations make direct generic overrides awkward, prefer generated test-local VHDL wrappers over checking in one-off wrapper files for each module.
- Keep generated wrappers thin and declarative: expose cycle-friendly or cocotb-friendly generics, map them onto the real DUT generics, and emit them from shared Python helpers.
- For integration wrappers, test the wrapper-specific behavior rather than replaying the full underlying leaf matrix through the wrapper.
- If only a simulator-stable subset of a wrapper is practical in phase 1, keep that subset intentionally narrow and document the unvalidated branches explicitly in the handoff/progress docs.

## CI And Runtime Policy
- Tier-first split.
- Separate `smoke` and `functional` regression tiers.
- Shard by subsystem only if runtime requires it.
- Keep room for PR-vs-nightly expansion later if runtime and coverage needs justify it.

## Reuse Policy
- Legacy VHDL testbenches are reference material only.
- Rewrite executable test logic in Python when migrating a module into the new regression system.
- Keep VHDL wrappers only when they make Python stimulus materially cleaner.
- Do not preserve old benches purely for historical reasons.
- When a wrapper is needed only to adapt simulator-hostile generics, generate it into the test build area from shared helper code rather than keeping a permanent checked-in HDL shim.
- For SURF AXI/AxiLite record ports, prefer the existing IP-integrator shim layers (`SlaveAxiStreamIpIntegrator`, `MasterAxiStreamIpIntegrator`, `SlaveAxiLiteIpIntegrator`, `MasterAxiLiteIpIntegrator`) instead of hand-writing record-to-flat unpacking in each test wrapper.
- If a DUT has extra nonstandard side signals, compose those on top of the standard AXI shim pair rather than replacing the standard flattening pattern.
- More generally, if a VHDL shim layer is needed to make a module practical to drive from cocotb, place that file in the nearest real subsystem `ip_integrator/` folder beside related adapter layers.
- Do not place cocotb-facing shim/adaptor VHDL under `tests/` or generic `hdl/` buckets when it is serving the same integration role as the existing `*IpIntegrator.vhd` files.

## Rollout Planning Policy
- Use a checked-in RTL instantiation graph to guide bottom-up rollout decisions.
- Prefer testing high-reuse leaf primitives directly before spending effort on higher-level assemblies that mostly repackage them.
- Use the graph to reduce repeated behavioral testing across adjacent hierarchy levels, not as a substitute for engineering judgment about externally visible behavior.
- Keep the graph artifacts for provenance, but use a checked-in flat module build order as the day-to-day source of truth once the order has been reviewed and written down.
- Do not re-analyze `rtl_instantiation_graph.json` before every module. Take the next non-deferred item from the flat build order unless a concrete blocker forces a reorder.

## Flat Build Order
This is the current phase-1 simulator-friendly default queue. It is intentionally flat so future windows can resume by taking the next unfinished, non-deferred item instead of re-deriving priorities from the graph JSON.

Completed foundation through the current `axi/` follow-on:
1. `FifoAsync`
2. `AxiStreamFifoV2`
3. `FifoSync`
4. `Synchronizer`
5. `SynchronizerVector`
6. `RstPipeline`
7. `SimpleDualPortRam`
8. `FifoOutputPipeline`
9. `FifoWrFsm`
10. `Crc32Parallel`
11. `Crc32`
12. `CRC32Rtl`
13. `RstSync`
14. `PwrUpRst`
15. `SynchronizerEdge`
16. `SynchronizerOneShot`
17. `TrueDualPortRam`
18. `LutRam`
19. `FifoRdFsm`
20. `Arbiter`
21. `ClockDivider`
22. `Debouncer`
23. `Gearbox`
24. `Heartbeat`
25. `Mux`
26. `OneShot`
27. `RegisterVector`
28. `RstPipelineVector`
29. `Scrambler`
30. `WatchDogRst`
31. `SlvDelay`
32. `SlvFixedDelay`
33. `SynchronizerFifo`
34. `SynchronizerOneShotCnt`
35. `DspComparator`
36. `Fifo`
37. `FifoCascade`
38. `FifoMux`
39. `AsyncGearbox`
40. `SynchronizerOneShotVector`
41. `SynchronizerOneShotCntVector`
42. `SyncStatusVector`
43. `SyncTrigPeriod`
44. `SyncMinMax`
45. `MasterRamIpIntegrator`
46. `SlaveRamIpIntegrator`
47. `DualPortRam`
48. `SlvDelayRam`
49. `SlvDelayFifo`
50. `SyncClockFreq`
51. `SyncTrigRate`
52. `SyncTrigRateVector`
53. `AxiStreamPipeline`
54. `AxiLiteCrossbar`
55. `AxiStreamMux`
56. `AxiStreamDeMux`
57. `AxiStreamResize`
58. `AxiLiteAsync`
59. `AxiLiteMaster`
60. `AxiLiteToDrp`
61. `AxiDualPortRam`

Current remaining phase-1 queue:
62. `AxiStreamGearbox`
63. `AxiRam`
64. `AxiRingBuffer`
65. `AxiStreamBatchingFifo`
66. `AxiVersion`
67. `AxiStreamMon`
68. `AxiStreamShift`
69. `AxiLiteMasterProxy`
70. `AxiStreamFlush`
71. `AxiStreamCompact`
72. `AxiStreamRepeater`
73. `Decoder8b10b`
74. `Encoder8b10b`
75. `SpiMaster`
76. `I2cRegMaster`
77. `SsiFifo`
78. `AxiStreamPacketizer2`
79. `AxiStreamDepacketizer2`
80. `UartWrapper`
81. `JesdLmfcGen`
82. `JesdRxLane`
83. `JesdTxLane`
84. `AxiI2cRegMasterCore`
85. `Pgp3RxGearboxAligner`
86. `Pgp2bLane`
87. `Pgp2fcLane`
88. `Pgp3Core`
89. `Pgp4Core`
90. `EthCrc32Parallel`
91. `EthMacTop`
92. `GigEthReg`
93. `TenGigEthReg`
94. `XauiReg`
95. `IpV4Engine`
96. `UdpEngine`

Deferred from this flat queue unless conditions change:
1. `LutFixedDelay`
2. vendor-heavy, dummy-backed, or otherwise simulator-hostile variants exposed by the graph

## Phase Breakdown
### Phase 1
- Create the regression inventory and artifact scaffolding.
- Generate and maintain a repo-wide RTL instantiation graph to guide bottom-up prioritization.
- Establish shared Python regression helpers.
- Add smoke coverage for simulator-friendly modules.
- Add functional Python tests for the highest-value pilot modules and reusable blocks.
- Define the migration pattern for wrappers and generic-heavy modules.
- Standardize the generated-wrapper pattern for real- or vector-generic leaves that need cycle-native test knobs under GHDL.

### Phase 2
- Deepen randomized and adversarial coverage.
- Expand curated configuration sweeps for generic-heavy modules.
- Add stronger reusable scoreboards and protocol-specific helpers.
- Revisit deferred vendor-heavy modules after phase 1 baseline stability.

## Acceptance Criteria For Phase 1
- The repo has a checked-in inventory and handoff system.
- New windows can recover project state by reading the handoff artifacts only.
- The Python-only regression direction is documented and stable.
- The first pilot modules are selected and ready for implementation.
- The smoke/functional tier split is established in the plan and progress tracking.

## Open Questions And Deferred Decisions
- Whether PR-vs-nightly split is needed immediately or only after runtime data.
- Exact criteria for moving a vendor-heavy module out of `deferred_vendor_heavy`.
- Which subsystem should be the first large-scale migration after the pilot modules.
- Whether a separate tracked list of high-risk behavioral package helpers is needed once the module inventory stabilizes.
