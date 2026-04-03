# SURF RTL Phase-1 Queue

## Scope
- Scan dirs: `base, axi, dsp, protocols, ethernet, devices, xilinx`
- Queue nodes are path-qualified RTL entity definitions, not bare entity names.
- Queue order is bottom-up: leaves first, higher-level assemblies later.
- Manual phase-1 deferrals and order overrides live in `docs/_meta/rtl_phase1_queue_overrides.json`.

## Summary
- Phase-1 modules: `219`
- Phase-1 dependency edges: `392`
- Bottom-up layers: `10`
- Deferred modules: `632`
- Unresolved duplicate-name phase-1 edges: `0`
- Applied order overrides: `0`

## Phase-1 Filters
- Force-included entities:
  - None
- Force-included paths:
  - None
- Deferred subsystems:
  - `ethernet`: Temporarily deferred during the current rollout so the remaining axi/ queue can be completed first.
  - `protocols`: Temporarily deferred during the current rollout so the remaining axi/ queue can be completed first.
  - `devices`: Subsystem is currently dominated by vendor-heavy modules in phase 1.
  - `xilinx`: Subsystem is currently dominated by vendor-heavy modules in phase 1.
- Deferred entities:
  - `LutFixedDelay`: Depends on SinglePortRamPrimitive under the current open-source flow.
- Deferred exact paths:
  - None
- Deferred path substrings:
  - `axi/simlink/`: Simulation support models are not part of the synthesizable phase-1 queue.
  - `/sim/`: Simulation-only support modules are not part of the synthesizable phase-1 queue.
  - `/dummy/`: Dummy-backed variants are deferred from the phase-1 executable queue.
  - `/altera/`: Vendor-specific implementation branches are deferred in phase 1.
  - `/xilinx/`: Vendor-specific implementation branches are deferred in phase 1.
  - `7Series`: Family-specific implementation branches are deferred in phase 1.
  - `UltraScale`: Family-specific implementation branches are deferred in phase 1.
  - `UltraScale+`: Family-specific implementation branches are deferred in phase 1.
  - `/gth`: GT-family implementation branches are deferred in phase 1.
  - `/gtp`: GT-family implementation branches are deferred in phase 1.
  - `/gty`: GT-family implementation branches are deferred in phase 1.
  - `/gtx`: GT-family implementation branches are deferred in phase 1.

## Manual Order Overrides
- None

## Unresolved Duplicate-Name Phase-1 Edges
- None

## Flat Bottom-Up Order
| order | layer | entity | subsystem | path | instantiated_by_count |
| --- | --- | --- | --- | --- | --- |
| 1 | 0 | AxiLiteCrossbar | axi | axi/axi-lite/rtl/AxiLiteCrossbar.vhd | 3 |
| 2 | 0 | AxiLiteMaster | axi | axi/axi-lite/rtl/AxiLiteMaster.vhd | 6 |
| 3 | 0 | AxiLiteRegs | axi | axi/axi-lite/rtl/AxiLiteRegs.vhd | 2 |
| 4 | 0 | AxiLiteRespTimer | axi | axi/axi-lite/rtl/AxiLiteRespTimer.vhd | 1 |
| 5 | 0 | AxiLiteSlave | axi | axi/axi-lite/rtl/AxiLiteSlave.vhd | 2 |
| 6 | 0 | AxiLiteWriteFilter | axi | axi/axi-lite/rtl/AxiLiteWriteFilter.vhd | 1 |
| 7 | 0 | AxiVersion | axi | axi/axi-lite/rtl/AxiVersion.vhd | 1 |
| 8 | 0 | AxiStreamCombiner | axi | axi/axi-stream/rtl/AxiStreamCombiner.vhd | 1 |
| 9 | 0 | AxiStreamFlush | axi | axi/axi-stream/rtl/AxiStreamFlush.vhd | 1 |
| 10 | 0 | AxiStreamGearboxPack | axi | axi/axi-stream/rtl/AxiStreamGearboxPack.vhd | 1 |
| 11 | 0 | AxiStreamGearboxUnpack | axi | axi/axi-stream/rtl/AxiStreamGearboxUnpack.vhd | 1 |
| 12 | 0 | AxiStreamPipeline | axi | axi/axi-stream/rtl/AxiStreamPipeline.vhd | 18 |
| 13 | 0 | AxiStreamSplitter | axi | axi/axi-stream/rtl/AxiStreamSplitter.vhd | 1 |
| 14 | 0 | AxiStreamPkgWrapper | axi | axi/axi-stream/wrappers/AxiStreamPkgWrapper.vhd | 0 |
| 15 | 0 | AxiReadPathMux | axi | axi/axi4/rtl/AxiReadPathMux.vhd | 1 |
| 16 | 0 | AxiResize | axi | axi/axi4/rtl/AxiResize.vhd | 1 |
| 17 | 0 | AxiWritePathMux | axi | axi/axi4/rtl/AxiWritePathMux.vhd | 1 |
| 18 | 0 | AxiToAxiLite | axi | axi/bridge/rtl/AxiToAxiLite.vhd | 1 |
| 19 | 0 | AxiStreamDmaV2WriteMux | axi | axi/dma/rtl/v2/AxiStreamDmaV2WriteMux.vhd | 2 |
| 20 | 0 | CRC32Rtl | base | base/crc/rtl/CRC32Rtl.vhd | 0 |
| 21 | 0 | Crc32 | base | base/crc/rtl/Crc32.vhd | 1 |
| 22 | 0 | Crc32Parallel | base | base/crc/rtl/Crc32Parallel.vhd | 0 |
| 23 | 0 | SlvDelay | base | base/delay/rtl/SlvDelay.vhd | 0 |
| 24 | 0 | SlvDelayRam | base | base/delay/rtl/SlvDelayRam.vhd | 0 |
| 25 | 0 | SlvFixedDelay | base | base/delay/rtl/SlvFixedDelay.vhd | 0 |
| 26 | 0 | FifoOutputPipeline | base | base/fifo/rtl/FifoOutputPipeline.vhd | 7 |
| 27 | 0 | FifoRdFsm | base | base/fifo/rtl/inferred/FifoRdFsm.vhd | 2 |
| 28 | 0 | FifoWrFsm | base | base/fifo/rtl/inferred/FifoWrFsm.vhd | 2 |
| 29 | 0 | MasterRamIpIntegrator | base | base/general/ip_integrator/MasterRamIpIntegrator.vhd | 0 |
| 30 | 0 | SlaveRamIpIntegrator | base | base/general/ip_integrator/SlaveRamIpIntegrator.vhd | 0 |
| 31 | 0 | Arbiter | base | base/general/rtl/Arbiter.vhd | 0 |
| 32 | 0 | ClockDivider | base | base/general/rtl/ClockDivider.vhd | 0 |
| 33 | 0 | Gearbox | base | base/general/rtl/Gearbox.vhd | 1 |
| 34 | 0 | Heartbeat | base | base/general/rtl/Heartbeat.vhd | 1 |
| 35 | 0 | Mux | base | base/general/rtl/Mux.vhd | 0 |
| 36 | 0 | OneShot | base | base/general/rtl/OneShot.vhd | 0 |
| 37 | 0 | RegisterVector | base | base/general/rtl/RegisterVector.vhd | 0 |
| 38 | 0 | RstPipeline | base | base/general/rtl/RstPipeline.vhd | 3 |
| 39 | 0 | Scrambler | base | base/general/rtl/Scrambler.vhd | 0 |
| 40 | 0 | LutRam | base | base/ram/inferred/LutRam.vhd | 1 |
| 41 | 0 | SimpleDualPortRam | base | base/ram/inferred/SimpleDualPortRam.vhd | 6 |
| 42 | 0 | TrueDualPortRam | base | base/ram/inferred/TrueDualPortRam.vhd | 3 |
| 43 | 0 | Synchronizer | base | base/sync/rtl/Synchronizer.vhd | 13 |
| 44 | 0 | SynchronizerVector | base | base/sync/rtl/SynchronizerVector.vhd | 7 |
| 45 | 0 | FirFilterTap | dsp | dsp/generic/fixed/FirFilterTap.vhd | 2 |
| 46 | 1 | AxiLiteMasterProxy | axi | axi/axi-lite/rtl/AxiLiteMasterProxy.vhd | 1 |
| 47 | 1 | AxiLiteSequencerRam | axi | axi/axi-lite/rtl/AxiLiteSequencerRam.vhd | 1 |
| 48 | 1 | AxiStreamCompact | axi | axi/axi-stream/rtl/AxiStreamCompact.vhd | 1 |
| 49 | 1 | AxiStreamConcat | axi | axi/axi-stream/rtl/AxiStreamConcat.vhd | 1 |
| 50 | 1 | AxiStreamDeMux | axi | axi/axi-stream/rtl/AxiStreamDeMux.vhd | 2 |
| 51 | 1 | AxiStreamFrameRateLimiter | axi | axi/axi-stream/rtl/AxiStreamFrameRateLimiter.vhd | 1 |
| 52 | 1 | AxiStreamMux | axi | axi/axi-stream/rtl/AxiStreamMux.vhd | 2 |
| 53 | 1 | AxiStreamRepeater | axi | axi/axi-stream/rtl/AxiStreamRepeater.vhd | 1 |
| 54 | 1 | AxiStreamResize | axi | axi/axi-stream/rtl/AxiStreamResize.vhd | 2 |
| 55 | 1 | AxiStreamShift | axi | axi/axi-stream/rtl/AxiStreamShift.vhd | 3 |
| 56 | 1 | AxiStreamTrailerAppend | axi | axi/axi-stream/rtl/AxiStreamTrailerAppend.vhd | 1 |
| 57 | 1 | AxiStreamTrailerRemove | axi | axi/axi-stream/rtl/AxiStreamTrailerRemove.vhd | 1 |
| 58 | 1 | AxiRam | axi | axi/axi4/rtl/AxiRam.vhd | 1 |
| 59 | 1 | AxiLiteToIpBus | axi | axi/bridge/rtl/AxiLiteToIpBus.vhd | 1 |
| 60 | 1 | IpBusToAxiLite | axi | axi/bridge/rtl/IpBusToAxiLite.vhd | 1 |
| 61 | 1 | AxiStreamDmaV2WriteMuxIpIntegrator | axi | axi/dma/ip_integrator/AxiStreamDmaV2WriteMuxIpIntegrator.vhd | 0 |
| 62 | 1 | Crc32PolyWrapper | base | base/crc/wrappers/Crc32PolyWrapper.vhd | 0 |
| 63 | 1 | FifoSync | base | base/fifo/rtl/inferred/FifoSync.vhd | 2 |
| 64 | 1 | RstPipelineVector | base | base/general/rtl/RstPipelineVector.vhd | 0 |
| 65 | 1 | WatchDogRst | base | base/general/rtl/WatchDogRst.vhd | 0 |
| 66 | 1 | HeartbeatWrapper | base | base/general/wrappers/HeartbeatWrapper.vhd | 0 |
| 67 | 1 | DualPortRam | base | base/ram/inferred/DualPortRam.vhd | 4 |
| 68 | 1 | RstSync | base | base/sync/rtl/RstSync.vhd | 15 |
| 69 | 1 | SynchronizerEdge | base | base/sync/rtl/SynchronizerEdge.vhd | 1 |
| 70 | 1 | BoxcarIntegrator | dsp | dsp/generic/fixed/BoxcarIntegrator.vhd | 1 |
| 71 | 1 | DspAddSub | dsp | dsp/generic/fixed/DspAddSub.vhd | 1 |
| 72 | 1 | DspComparator | dsp | dsp/generic/fixed/DspComparator.vhd | 4 |
| 73 | 1 | DspPreSubMult | dsp | dsp/generic/fixed/DspPreSubMult.vhd | 0 |
| 74 | 1 | DspSquareDiffMult | dsp | dsp/generic/fixed/DspSquareDiffMult.vhd | 0 |
| 75 | 2 | MasterAxiLiteIpIntegrator | axi | axi/axi-lite/ip_integrator/MasterAxiLiteIpIntegrator.vhd | 9 |
| 76 | 2 | SlaveAxiLiteIpIntegrator | axi | axi/axi-lite/ip_integrator/SlaveAxiLiteIpIntegrator.vhd | 32 |
| 77 | 2 | AxiLiteAsync | axi | axi/axi-lite/rtl/AxiLiteAsync.vhd | 7 |
| 78 | 2 | MasterAxiStreamIpIntegrator | axi | axi/axi-stream/ip_integrator/MasterAxiStreamIpIntegrator.vhd | 30 |
| 79 | 2 | SlaveAxiStreamIpIntegrator | axi | axi/axi-stream/ip_integrator/SlaveAxiStreamIpIntegrator.vhd | 30 |
| 80 | 2 | AxiStreamGearbox | axi | axi/axi-stream/rtl/AxiStreamGearbox.vhd | 2 |
| 81 | 2 | AxiStreamPrbsFlowCtrl | axi | axi/axi-stream/rtl/AxiStreamPrbsFlowCtrl.vhd | 1 |
| 82 | 2 | AxiStreamTap | axi | axi/axi-stream/rtl/AxiStreamTap.vhd | 1 |
| 83 | 2 | MasterAxiIpIntegrator | axi | axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd | 16 |
| 84 | 2 | SlaveAxiIpIntegrator | axi | axi/axi4/ip_integrator/SlaveAxiIpIntegrator.vhd | 9 |
| 85 | 2 | AxiStreamDmaRead | axi | axi/dma/rtl/v1/AxiStreamDmaRead.vhd | 4 |
| 86 | 2 | AxiStreamDmaV2Read | axi | axi/dma/rtl/v2/AxiStreamDmaV2Read.vhd | 3 |
| 87 | 2 | AxiStreamDmaV2Write | axi | axi/dma/rtl/v2/AxiStreamDmaV2Write.vhd | 3 |
| 88 | 2 | FifoAsync | base | base/fifo/rtl/inferred/FifoAsync.vhd | 4 |
| 89 | 2 | Debouncer | base | base/general/rtl/Debouncer.vhd | 1 |
| 90 | 2 | PwrUpRst | base | base/general/rtl/PwrUpRst.vhd | 0 |
| 91 | 2 | SynchronizerOneShot | base | base/sync/rtl/SynchronizerOneShot.vhd | 8 |
| 92 | 2 | BoxcarFilter | dsp | dsp/generic/fixed/BoxcarFilter.vhd | 0 |
| 93 | 3 | AxiLiteAsyncIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteAsyncIpIntegrator.vhd | 0 |
| 94 | 3 | AxiLiteMasterIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteMasterIpIntegrator.vhd | 0 |
| 95 | 3 | AxiLiteMasterProxyIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteMasterProxyIpIntegrator.vhd | 0 |
| 96 | 3 | AxiLiteRegsIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteRegsIpIntegrator.vhd | 0 |
| 97 | 3 | AxiLiteRespTimerIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteRespTimerIpIntegrator.vhd | 0 |
| 98 | 3 | AxiLiteSequencerRamIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteSequencerRamIpIntegrator.vhd | 0 |
| 99 | 3 | AxiLiteSlaveIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteSlaveIpIntegrator.vhd | 0 |
| 100 | 3 | AxiLiteWriteFilterIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteWriteFilterIpIntegrator.vhd | 0 |
| 101 | 3 | AxiVersionIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiVersionIpIntegrator.vhd | 0 |
| 102 | 3 | AxiStreamCombinerIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamCombinerIpIntegrator.vhd | 0 |
| 103 | 3 | AxiStreamCompactIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamCompactIpIntegrator.vhd | 0 |
| 104 | 3 | AxiStreamConcatIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamConcatIpIntegrator.vhd | 0 |
| 105 | 3 | AxiStreamDeMuxIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamDeMuxIpIntegrator.vhd | 0 |
| 106 | 3 | AxiStreamFlushIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamFlushIpIntegrator.vhd | 0 |
| 107 | 3 | AxiStreamFrameRateLimiterIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamFrameRateLimiterIpIntegrator.vhd | 0 |
| 108 | 3 | AxiStreamGearboxIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamGearboxIpIntegrator.vhd | 0 |
| 109 | 3 | AxiStreamGearboxPackIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamGearboxPackIpIntegrator.vhd | 0 |
| 110 | 3 | AxiStreamGearboxUnpackIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamGearboxUnpackIpIntegrator.vhd | 0 |
| 111 | 3 | AxiStreamMuxIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamMuxIpIntegrator.vhd | 0 |
| 112 | 3 | AxiStreamPipelineIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamPipelineIpIntegrator.vhd | 0 |
| 113 | 3 | AxiStreamPrbsFlowCtrlIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamPrbsFlowCtrlIpIntegrator.vhd | 0 |
| 114 | 3 | AxiStreamRepeaterIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamRepeaterIpIntegrator.vhd | 0 |
| 115 | 3 | AxiStreamResizeIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamResizeIpIntegrator.vhd | 0 |
| 116 | 3 | AxiStreamShiftIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamShiftIpIntegrator.vhd | 0 |
| 117 | 3 | AxiStreamSplitterIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamSplitterIpIntegrator.vhd | 0 |
| 118 | 3 | AxiStreamTapIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamTapIpIntegrator.vhd | 0 |
| 119 | 3 | AxiStreamTrailerAppendIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamTrailerAppendIpIntegrator.vhd | 0 |
| 120 | 3 | AxiStreamTrailerRemoveIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamTrailerRemoveIpIntegrator.vhd | 0 |
| 121 | 3 | MasterAxiStreamTerminateIpIntegrator | axi | axi/axi-stream/ip_integrator/MasterAxiStreamTerminateIpIntegrator.vhd | 0 |
| 122 | 3 | SlaveAxiStreamTerminateIpIntegrator | axi | axi/axi-stream/ip_integrator/SlaveAxiStreamTerminateIpIntegrator.vhd | 0 |
| 123 | 3 | AxiStreamTimer | axi | axi/axi-stream/rtl/AxiStreamTimer.vhd | 1 |
| 124 | 3 | AxiRamIpIntegrator | axi | axi/axi4/ip_integrator/AxiRamIpIntegrator.vhd | 0 |
| 125 | 3 | AxiReadPathMuxIpIntegrator | axi | axi/axi4/ip_integrator/AxiReadPathMuxIpIntegrator.vhd | 0 |
| 126 | 3 | AxiResizeIpIntegrator | axi | axi/axi4/ip_integrator/AxiResizeIpIntegrator.vhd | 0 |
| 127 | 3 | AxiWritePathMuxIpIntegrator | axi | axi/axi4/ip_integrator/AxiWritePathMuxIpIntegrator.vhd | 0 |
| 128 | 3 | AxiRateGen | axi | axi/axi4/rtl/AxiRateGen.vhd | 1 |
| 129 | 3 | AxiLiteToIpBusIpIntegrator | axi | axi/bridge/ip_integrator/AxiLiteToIpBusIpIntegrator.vhd | 0 |
| 130 | 3 | AxiToAxiLiteIpIntegrator | axi | axi/bridge/ip_integrator/AxiToAxiLiteIpIntegrator.vhd | 0 |
| 131 | 3 | IpBusToAxiLiteIpIntegrator | axi | axi/bridge/ip_integrator/IpBusToAxiLiteIpIntegrator.vhd | 0 |
| 132 | 3 | AxiLiteToDrp | axi | axi/bridge/rtl/AxiLiteToDrp.vhd | 1 |
| 133 | 3 | AxiStreamDmaReadIpIntegrator | axi | axi/dma/ip_integrator/AxiStreamDmaReadIpIntegrator.vhd | 0 |
| 134 | 3 | AxiStreamDmaV2ReadIpIntegrator | axi | axi/dma/ip_integrator/AxiStreamDmaV2ReadIpIntegrator.vhd | 0 |
| 135 | 3 | AxiStreamDmaV2WriteIpIntegrator | axi | axi/dma/ip_integrator/AxiStreamDmaV2WriteIpIntegrator.vhd | 0 |
| 136 | 3 | Fifo | base | base/fifo/rtl/Fifo.vhd | 6 |
| 137 | 3 | AsyncGearbox | base | base/general/rtl/AsyncGearbox.vhd | 0 |
| 138 | 3 | DebouncerWrapper | base | base/general/wrappers/DebouncerWrapper.vhd | 0 |
| 139 | 3 | SyncTrigPeriod | base | base/sync/rtl/SyncTrigPeriod.vhd | 0 |
| 140 | 3 | SynchronizerFifo | base | base/sync/rtl/SynchronizerFifo.vhd | 11 |
| 141 | 3 | SynchronizerOneShotVector | base | base/sync/rtl/SynchronizerOneShotVector.vhd | 0 |
| 142 | 3 | FirFilterSingleChannel | dsp | dsp/generic/fixed/FirFilterSingleChannel.vhd | 0 |
| 143 | 4 | AxiDualPortRam | axi | axi/axi-lite/rtl/AxiDualPortRam.vhd | 6 |
| 144 | 4 | AxiLiteRingBuffer | axi | axi/axi-lite/rtl/AxiLiteRingBuffer.vhd | 1 |
| 145 | 4 | AxiStreamTimerIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamTimerIpIntegrator.vhd | 0 |
| 146 | 4 | AxiStreamScatterGather | axi | axi/axi-stream/rtl/AxiStreamScatterGather.vhd | 1 |
| 147 | 4 | AxiRateGenIpIntegrator | axi | axi/axi4/ip_integrator/AxiRateGenIpIntegrator.vhd | 0 |
| 148 | 4 | AxiMemTester | axi | axi/axi4/rtl/AxiMemTester.vhd | 1 |
| 149 | 4 | AxiLiteToDrpIpIntegrator | axi | axi/bridge/ip_integrator/AxiLiteToDrpIpIntegrator.vhd | 0 |
| 150 | 4 | SlvArraytoAxiLite | axi | axi/bridge/rtl/SlvArraytoAxiLite.vhd | 1 |
| 151 | 4 | AxiStreamDmaV2Desc | axi | axi/dma/rtl/v2/AxiStreamDmaV2Desc.vhd | 2 |
| 152 | 4 | AxiStreamDmaV2Fifo | axi | axi/dma/rtl/v2/AxiStreamDmaV2Fifo.vhd | 1 |
| 153 | 4 | SlvDelayFifo | base | base/delay/rtl/SlvDelayFifo.vhd | 0 |
| 154 | 4 | FifoCascade | base | base/fifo/rtl/FifoCascade.vhd | 8 |
| 155 | 4 | FwftCntWrapper | base | base/fifo/wrappers/FwftCntWrapper.vhd | 0 |
| 156 | 4 | SyncClockFreq | base | base/sync/rtl/SyncClockFreq.vhd | 1 |
| 157 | 4 | SyncMinMax | base | base/sync/rtl/SyncMinMax.vhd | 2 |
| 158 | 4 | SynchronizerOneShotCnt | base | base/sync/rtl/SynchronizerOneShotCnt.vhd | 1 |
| 159 | 5 | AxiDualPortRamIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiDualPortRamIpIntegrator.vhd | 0 |
| 160 | 5 | AxiLiteCrossbarIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteCrossbarIpIntegrator.vhd | 0 |
| 161 | 5 | AxiLiteRingBufferIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteRingBufferIpIntegrator.vhd | 0 |
| 162 | 5 | AxiLiteFifoPop | axi | axi/axi-lite/rtl/AxiLiteFifoPop.vhd | 1 |
| 163 | 5 | AxiLiteFifoPush | axi | axi/axi-lite/rtl/AxiLiteFifoPush.vhd | 1 |
| 164 | 5 | AxiLiteFifoPushPop | axi | axi/axi-lite/rtl/AxiLiteFifoPushPop.vhd | 2 |
| 165 | 5 | AxiStreamScatterGatherIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamScatterGatherIpIntegrator.vhd | 0 |
| 166 | 5 | AxiStreamFifoV2 | axi | axi/axi-stream/rtl/AxiStreamFifoV2.vhd | 7 |
| 167 | 5 | AxiMemTesterIpIntegrator | axi | axi/axi4/ip_integrator/AxiMemTesterIpIntegrator.vhd | 0 |
| 168 | 5 | AxiReadPathFifo | axi | axi/axi4/rtl/AxiReadPathFifo.vhd | 3 |
| 169 | 5 | AxiWritePathFifo | axi | axi/axi4/rtl/AxiWritePathFifo.vhd | 3 |
| 170 | 5 | SlvArraytoAxiLiteIpIntegrator | axi | axi/bridge/ip_integrator/SlvArraytoAxiLiteIpIntegrator.vhd | 0 |
| 171 | 5 | AxiStreamDmaV2DescIpIntegrator | axi | axi/dma/ip_integrator/AxiStreamDmaV2DescIpIntegrator.vhd | 0 |
| 172 | 5 | AxiStreamDmaV2FifoIpIntegrator | axi | axi/dma/ip_integrator/AxiStreamDmaV2FifoIpIntegrator.vhd | 0 |
| 173 | 5 | AxiStreamDmaV2 | axi | axi/dma/rtl/v2/AxiStreamDmaV2.vhd | 1 |
| 174 | 5 | FifoMux | base | base/fifo/rtl/FifoMux.vhd | 0 |
| 175 | 5 | SyncTrigRate | base | base/sync/rtl/SyncTrigRate.vhd | 3 |
| 176 | 5 | SynchronizerOneShotCntVector | base | base/sync/rtl/SynchronizerOneShotCntVector.vhd | 2 |
| 177 | 5 | SyncClockFreqWrapper | base | base/sync/wrappers/SyncClockFreqWrapper.vhd | 0 |
| 178 | 5 | FirFilterMultiChannel | dsp | dsp/generic/fixed/FirFilterMultiChannel.vhd | 0 |
| 179 | 6 | AxiLiteFifoPopIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteFifoPopIpIntegrator.vhd | 0 |
| 180 | 6 | AxiLiteFifoPushIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteFifoPushIpIntegrator.vhd | 0 |
| 181 | 6 | AxiLiteFifoPushPopIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteFifoPushPopIpIntegrator.vhd | 0 |
| 182 | 6 | AxiStreamFifoV2IpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamFifoV2IpIntegrator.vhd | 0 |
| 183 | 6 | AxiStreamBatchingFifo | axi | axi/axi-stream/rtl/AxiStreamBatchingFifo.vhd | 1 |
| 184 | 6 | AxiStreamMon | axi | axi/axi-stream/rtl/AxiStreamMon.vhd | 2 |
| 185 | 6 | AxiStreamRingBuffer | axi | axi/axi-stream/rtl/AxiStreamRingBuffer.vhd | 1 |
| 186 | 6 | AxiReadPathFifoIpIntegrator | axi | axi/axi4/ip_integrator/AxiReadPathFifoIpIntegrator.vhd | 0 |
| 187 | 6 | AxiWritePathFifoIpIntegrator | axi | axi/axi4/ip_integrator/AxiWritePathFifoIpIntegrator.vhd | 0 |
| 188 | 6 | AxiReadEmulate | axi | axi/axi4/rtl/AxiReadEmulate.vhd | 1 |
| 189 | 6 | AxiRingBuffer | axi | axi/axi4/rtl/AxiRingBuffer.vhd | 1 |
| 190 | 6 | AxiWriteEmulate | axi | axi/axi4/rtl/AxiWriteEmulate.vhd | 1 |
| 191 | 6 | AxiStreamDmaV2IpIntegrator | axi | axi/dma/ip_integrator/AxiStreamDmaV2IpIntegrator.vhd | 0 |
| 192 | 6 | AxiStreamDmaRingRead | axi | axi/dma/rtl/v1/AxiStreamDmaRingRead.vhd | 1 |
| 193 | 6 | AxiStreamDmaWrite | axi | axi/dma/rtl/v1/AxiStreamDmaWrite.vhd | 4 |
| 194 | 6 | SyncStatusVector | base | base/sync/rtl/SyncStatusVector.vhd | 2 |
| 195 | 6 | SyncTrigRateVector | base | base/sync/rtl/SyncTrigRateVector.vhd | 1 |
| 196 | 6 | SyncTrigRateWrapper | base | base/sync/wrappers/SyncTrigRateWrapper.vhd | 0 |
| 197 | 6 | SynchronizerOneShotCntVectorFlatWrapper | base | base/sync/wrappers/SynchronizerOneShotCntVectorFlatWrapper.vhd | 0 |
| 198 | 7 | AxiLiteRamSyncStatusVector | axi | axi/axi-lite/rtl/AxiLiteRamSyncStatusVector.vhd | 1 |
| 199 | 7 | AxiStreamBatchingFifoIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamBatchingFifoIpIntegrator.vhd | 0 |
| 200 | 7 | AxiStreamMonIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamMonIpIntegrator.vhd | 0 |
| 201 | 7 | AxiStreamRingBufferIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamRingBufferIpIntegrator.vhd | 0 |
| 202 | 7 | AxiStreamMonAxiL | axi | axi/axi-stream/rtl/AxiStreamMonAxiL.vhd | 2 |
| 203 | 7 | AxiReadEmulateIpIntegrator | axi | axi/axi4/ip_integrator/AxiReadEmulateIpIntegrator.vhd | 0 |
| 204 | 7 | AxiRingBufferIpIntegrator | axi | axi/axi4/ip_integrator/AxiRingBufferIpIntegrator.vhd | 0 |
| 205 | 7 | AxiWriteEmulateIpIntegrator | axi | axi/axi4/ip_integrator/AxiWriteEmulateIpIntegrator.vhd | 0 |
| 206 | 7 | AxiStreamDmaRingReadIpIntegrator | axi | axi/dma/ip_integrator/AxiStreamDmaRingReadIpIntegrator.vhd | 0 |
| 207 | 7 | AxiStreamDmaWriteIpIntegrator | axi | axi/dma/ip_integrator/AxiStreamDmaWriteIpIntegrator.vhd | 0 |
| 208 | 7 | AxiStreamDma | axi | axi/dma/rtl/v1/AxiStreamDma.vhd | 1 |
| 209 | 7 | AxiStreamDmaFifo | axi | axi/dma/rtl/v1/AxiStreamDmaFifo.vhd | 1 |
| 210 | 7 | AxiStreamDmaRingWrite | axi | axi/dma/rtl/v1/AxiStreamDmaRingWrite.vhd | 1 |
| 211 | 7 | SyncStatusVectorFlatWrapper | base | base/sync/wrappers/SyncStatusVectorFlatWrapper.vhd | 0 |
| 212 | 7 | SyncTrigRateVectorFlatWrapper | base | base/sync/wrappers/SyncTrigRateVectorFlatWrapper.vhd | 0 |
| 213 | 8 | AxiLiteRamSyncStatusVectorIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteRamSyncStatusVectorIpIntegrator.vhd | 0 |
| 214 | 8 | AxiStreamMonAxiLIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamMonAxiLIpIntegrator.vhd | 0 |
| 215 | 8 | AxiMonAxiL | axi | axi/axi4/rtl/AxiMonAxiL.vhd | 1 |
| 216 | 8 | AxiStreamDmaFifoIpIntegrator | axi | axi/dma/ip_integrator/AxiStreamDmaFifoIpIntegrator.vhd | 0 |
| 217 | 8 | AxiStreamDmaIpIntegrator | axi | axi/dma/ip_integrator/AxiStreamDmaIpIntegrator.vhd | 0 |
| 218 | 8 | AxiStreamDmaRingWriteIpIntegrator | axi | axi/dma/ip_integrator/AxiStreamDmaRingWriteIpIntegrator.vhd | 0 |
| 219 | 9 | AxiMonAxiLIpIntegrator | axi | axi/axi4/ip_integrator/AxiMonAxiLIpIntegrator.vhd | 0 |
