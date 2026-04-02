# SURF RTL Phase-1 Queue

## Scope
- Scan dirs: `base, axi, protocols, ethernet, devices, xilinx`
- Queue nodes are path-qualified RTL entity definitions, not bare entity names.
- Queue order is bottom-up: leaves first, higher-level assemblies later.
- Manual phase-1 deferrals and order overrides live in `docs/_meta/rtl_phase1_queue_overrides.json`.

## Summary
- Phase-1 modules: `174`
- Phase-1 dependency edges: `294`
- Bottom-up layers: `9`
- Deferred modules: `603`
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
| 14 | 0 | AxiReadPathMux | axi | axi/axi4/rtl/AxiReadPathMux.vhd | 1 |
| 15 | 0 | AxiResize | axi | axi/axi4/rtl/AxiResize.vhd | 1 |
| 16 | 0 | AxiWritePathMux | axi | axi/axi4/rtl/AxiWritePathMux.vhd | 1 |
| 17 | 0 | AxiToAxiLite | axi | axi/bridge/rtl/AxiToAxiLite.vhd | 1 |
| 18 | 0 | AxiStreamDmaV2WriteMux | axi | axi/dma/rtl/v2/AxiStreamDmaV2WriteMux.vhd | 2 |
| 19 | 0 | CRC32Rtl | base | base/crc/rtl/CRC32Rtl.vhd | 0 |
| 20 | 0 | Crc32 | base | base/crc/rtl/Crc32.vhd | 0 |
| 21 | 0 | Crc32Parallel | base | base/crc/rtl/Crc32Parallel.vhd | 0 |
| 22 | 0 | SlvDelay | base | base/delay/rtl/SlvDelay.vhd | 0 |
| 23 | 0 | SlvDelayRam | base | base/delay/rtl/SlvDelayRam.vhd | 0 |
| 24 | 0 | SlvFixedDelay | base | base/delay/rtl/SlvFixedDelay.vhd | 0 |
| 25 | 0 | FifoOutputPipeline | base | base/fifo/rtl/FifoOutputPipeline.vhd | 3 |
| 26 | 0 | FifoRdFsm | base | base/fifo/rtl/inferred/FifoRdFsm.vhd | 2 |
| 27 | 0 | FifoWrFsm | base | base/fifo/rtl/inferred/FifoWrFsm.vhd | 2 |
| 28 | 0 | MasterRamIpIntegrator | base | base/general/ip_integrator/MasterRamIpIntegrator.vhd | 0 |
| 29 | 0 | SlaveRamIpIntegrator | base | base/general/ip_integrator/SlaveRamIpIntegrator.vhd | 0 |
| 30 | 0 | Arbiter | base | base/general/rtl/Arbiter.vhd | 0 |
| 31 | 0 | ClockDivider | base | base/general/rtl/ClockDivider.vhd | 0 |
| 32 | 0 | Gearbox | base | base/general/rtl/Gearbox.vhd | 1 |
| 33 | 0 | Heartbeat | base | base/general/rtl/Heartbeat.vhd | 0 |
| 34 | 0 | Mux | base | base/general/rtl/Mux.vhd | 0 |
| 35 | 0 | OneShot | base | base/general/rtl/OneShot.vhd | 0 |
| 36 | 0 | RegisterVector | base | base/general/rtl/RegisterVector.vhd | 0 |
| 37 | 0 | RstPipeline | base | base/general/rtl/RstPipeline.vhd | 3 |
| 38 | 0 | Scrambler | base | base/general/rtl/Scrambler.vhd | 0 |
| 39 | 0 | LutRam | base | base/ram/inferred/LutRam.vhd | 1 |
| 40 | 0 | SimpleDualPortRam | base | base/ram/inferred/SimpleDualPortRam.vhd | 5 |
| 41 | 0 | TrueDualPortRam | base | base/ram/inferred/TrueDualPortRam.vhd | 3 |
| 42 | 0 | Synchronizer | base | base/sync/rtl/Synchronizer.vhd | 13 |
| 43 | 0 | SynchronizerVector | base | base/sync/rtl/SynchronizerVector.vhd | 7 |
| 44 | 1 | AxiLiteMasterProxy | axi | axi/axi-lite/rtl/AxiLiteMasterProxy.vhd | 1 |
| 45 | 1 | AxiLiteSequencerRam | axi | axi/axi-lite/rtl/AxiLiteSequencerRam.vhd | 1 |
| 46 | 1 | AxiStreamCompact | axi | axi/axi-stream/rtl/AxiStreamCompact.vhd | 1 |
| 47 | 1 | AxiStreamConcat | axi | axi/axi-stream/rtl/AxiStreamConcat.vhd | 1 |
| 48 | 1 | AxiStreamDeMux | axi | axi/axi-stream/rtl/AxiStreamDeMux.vhd | 2 |
| 49 | 1 | AxiStreamFrameRateLimiter | axi | axi/axi-stream/rtl/AxiStreamFrameRateLimiter.vhd | 1 |
| 50 | 1 | AxiStreamMux | axi | axi/axi-stream/rtl/AxiStreamMux.vhd | 2 |
| 51 | 1 | AxiStreamPrbsFlowCtrl | axi | axi/axi-stream/rtl/AxiStreamPrbsFlowCtrl.vhd | 1 |
| 52 | 1 | AxiStreamRepeater | axi | axi/axi-stream/rtl/AxiStreamRepeater.vhd | 1 |
| 53 | 1 | AxiStreamResize | axi | axi/axi-stream/rtl/AxiStreamResize.vhd | 2 |
| 54 | 1 | AxiStreamShift | axi | axi/axi-stream/rtl/AxiStreamShift.vhd | 3 |
| 55 | 1 | AxiStreamTrailerAppend | axi | axi/axi-stream/rtl/AxiStreamTrailerAppend.vhd | 1 |
| 56 | 1 | AxiStreamTrailerRemove | axi | axi/axi-stream/rtl/AxiStreamTrailerRemove.vhd | 1 |
| 57 | 1 | AxiRam | axi | axi/axi4/rtl/AxiRam.vhd | 1 |
| 58 | 1 | AxiLiteToIpBus | axi | axi/bridge/rtl/AxiLiteToIpBus.vhd | 1 |
| 59 | 1 | IpBusToAxiLite | axi | axi/bridge/rtl/IpBusToAxiLite.vhd | 1 |
| 60 | 1 | AxiStreamDmaV2WriteMuxIpIntegrator | axi | axi/dma/ip_integrator/AxiStreamDmaV2WriteMuxIpIntegrator.vhd | 0 |
| 61 | 1 | AxiStreamDmaV2Read | axi | axi/dma/rtl/v2/AxiStreamDmaV2Read.vhd | 3 |
| 62 | 1 | FifoSync | base | base/fifo/rtl/inferred/FifoSync.vhd | 2 |
| 63 | 1 | RstPipelineVector | base | base/general/rtl/RstPipelineVector.vhd | 0 |
| 64 | 1 | WatchDogRst | base | base/general/rtl/WatchDogRst.vhd | 0 |
| 65 | 1 | DualPortRam | base | base/ram/inferred/DualPortRam.vhd | 3 |
| 66 | 1 | RstSync | base | base/sync/rtl/RstSync.vhd | 15 |
| 67 | 1 | SynchronizerEdge | base | base/sync/rtl/SynchronizerEdge.vhd | 1 |
| 68 | 2 | MasterAxiLiteIpIntegrator | axi | axi/axi-lite/ip_integrator/MasterAxiLiteIpIntegrator.vhd | 7 |
| 69 | 2 | SlaveAxiLiteIpIntegrator | axi | axi/axi-lite/ip_integrator/SlaveAxiLiteIpIntegrator.vhd | 15 |
| 70 | 2 | AxiLiteAsync | axi | axi/axi-lite/rtl/AxiLiteAsync.vhd | 6 |
| 71 | 2 | MasterAxiStreamIpIntegrator | axi | axi/axi-stream/ip_integrator/MasterAxiStreamIpIntegrator.vhd | 23 |
| 72 | 2 | SlaveAxiStreamIpIntegrator | axi | axi/axi-stream/ip_integrator/SlaveAxiStreamIpIntegrator.vhd | 22 |
| 73 | 2 | AxiStreamGearbox | axi | axi/axi-stream/rtl/AxiStreamGearbox.vhd | 2 |
| 74 | 2 | AxiStreamTap | axi | axi/axi-stream/rtl/AxiStreamTap.vhd | 1 |
| 75 | 2 | MasterAxiIpIntegrator | axi | axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd | 7 |
| 76 | 2 | SlaveAxiIpIntegrator | axi | axi/axi4/ip_integrator/SlaveAxiIpIntegrator.vhd | 5 |
| 77 | 2 | AxiStreamDmaRead | axi | axi/dma/rtl/v1/AxiStreamDmaRead.vhd | 4 |
| 78 | 2 | AxiStreamDmaV2Write | axi | axi/dma/rtl/v2/AxiStreamDmaV2Write.vhd | 3 |
| 79 | 2 | FifoAsync | base | base/fifo/rtl/inferred/FifoAsync.vhd | 4 |
| 80 | 2 | Debouncer | base | base/general/rtl/Debouncer.vhd | 0 |
| 81 | 2 | PwrUpRst | base | base/general/rtl/PwrUpRst.vhd | 0 |
| 82 | 2 | SynchronizerOneShot | base | base/sync/rtl/SynchronizerOneShot.vhd | 8 |
| 83 | 3 | AxiLiteAsyncIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteAsyncIpIntegrator.vhd | 0 |
| 84 | 3 | AxiLiteMasterIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteMasterIpIntegrator.vhd | 0 |
| 85 | 3 | AxiLiteMasterProxyIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteMasterProxyIpIntegrator.vhd | 0 |
| 86 | 3 | AxiLiteRegsIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteRegsIpIntegrator.vhd | 0 |
| 87 | 3 | AxiLiteRespTimerIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteRespTimerIpIntegrator.vhd | 0 |
| 88 | 3 | AxiLiteSequencerRamIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteSequencerRamIpIntegrator.vhd | 0 |
| 89 | 3 | AxiLiteSlaveIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteSlaveIpIntegrator.vhd | 0 |
| 90 | 3 | AxiLiteWriteFilterIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteWriteFilterIpIntegrator.vhd | 0 |
| 91 | 3 | AxiVersionIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiVersionIpIntegrator.vhd | 0 |
| 92 | 3 | AxiStreamCombinerIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamCombinerIpIntegrator.vhd | 0 |
| 93 | 3 | AxiStreamCompactIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamCompactIpIntegrator.vhd | 0 |
| 94 | 3 | AxiStreamConcatIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamConcatIpIntegrator.vhd | 0 |
| 95 | 3 | AxiStreamDeMuxIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamDeMuxIpIntegrator.vhd | 0 |
| 96 | 3 | AxiStreamFlushIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamFlushIpIntegrator.vhd | 0 |
| 97 | 3 | AxiStreamFrameRateLimiterIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamFrameRateLimiterIpIntegrator.vhd | 0 |
| 98 | 3 | AxiStreamGearboxIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamGearboxIpIntegrator.vhd | 0 |
| 99 | 3 | AxiStreamGearboxPackIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamGearboxPackIpIntegrator.vhd | 0 |
| 100 | 3 | AxiStreamGearboxUnpackIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamGearboxUnpackIpIntegrator.vhd | 0 |
| 101 | 3 | AxiStreamMuxIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamMuxIpIntegrator.vhd | 0 |
| 102 | 3 | AxiStreamPipelineIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamPipelineIpIntegrator.vhd | 0 |
| 103 | 3 | AxiStreamPrbsFlowCtrlIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamPrbsFlowCtrlIpIntegrator.vhd | 0 |
| 104 | 3 | AxiStreamRepeaterIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamRepeaterIpIntegrator.vhd | 0 |
| 105 | 3 | AxiStreamResizeIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamResizeIpIntegrator.vhd | 0 |
| 106 | 3 | AxiStreamShiftIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamShiftIpIntegrator.vhd | 0 |
| 107 | 3 | AxiStreamSplitterIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamSplitterIpIntegrator.vhd | 0 |
| 108 | 3 | AxiStreamTapIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamTapIpIntegrator.vhd | 0 |
| 109 | 3 | AxiStreamTrailerAppendIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamTrailerAppendIpIntegrator.vhd | 0 |
| 110 | 3 | AxiStreamTrailerRemoveIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamTrailerRemoveIpIntegrator.vhd | 0 |
| 111 | 3 | MasterAxiStreamTerminateIpIntegrator | axi | axi/axi-stream/ip_integrator/MasterAxiStreamTerminateIpIntegrator.vhd | 0 |
| 112 | 3 | SlaveAxiStreamTerminateIpIntegrator | axi | axi/axi-stream/ip_integrator/SlaveAxiStreamTerminateIpIntegrator.vhd | 0 |
| 113 | 3 | AxiStreamTimer | axi | axi/axi-stream/rtl/AxiStreamTimer.vhd | 1 |
| 114 | 3 | AxiRamIpIntegrator | axi | axi/axi4/ip_integrator/AxiRamIpIntegrator.vhd | 0 |
| 115 | 3 | AxiReadPathMuxIpIntegrator | axi | axi/axi4/ip_integrator/AxiReadPathMuxIpIntegrator.vhd | 0 |
| 116 | 3 | AxiResizeIpIntegrator | axi | axi/axi4/ip_integrator/AxiResizeIpIntegrator.vhd | 0 |
| 117 | 3 | AxiWritePathMuxIpIntegrator | axi | axi/axi4/ip_integrator/AxiWritePathMuxIpIntegrator.vhd | 0 |
| 118 | 3 | AxiRateGen | axi | axi/axi4/rtl/AxiRateGen.vhd | 1 |
| 119 | 3 | AxiLiteToIpBusIpIntegrator | axi | axi/bridge/ip_integrator/AxiLiteToIpBusIpIntegrator.vhd | 0 |
| 120 | 3 | AxiToAxiLiteIpIntegrator | axi | axi/bridge/ip_integrator/AxiToAxiLiteIpIntegrator.vhd | 0 |
| 121 | 3 | IpBusToAxiLiteIpIntegrator | axi | axi/bridge/ip_integrator/IpBusToAxiLiteIpIntegrator.vhd | 0 |
| 122 | 3 | AxiLiteToDrp | axi | axi/bridge/rtl/AxiLiteToDrp.vhd | 1 |
| 123 | 3 | AxiStreamDmaReadIpIntegrator | axi | axi/dma/ip_integrator/AxiStreamDmaReadIpIntegrator.vhd | 0 |
| 124 | 3 | AxiStreamDmaV2ReadIpIntegrator | axi | axi/dma/ip_integrator/AxiStreamDmaV2ReadIpIntegrator.vhd | 0 |
| 125 | 3 | AxiStreamDmaV2WriteIpIntegrator | axi | axi/dma/ip_integrator/AxiStreamDmaV2WriteIpIntegrator.vhd | 0 |
| 126 | 3 | Fifo | base | base/fifo/rtl/Fifo.vhd | 5 |
| 127 | 3 | AsyncGearbox | base | base/general/rtl/AsyncGearbox.vhd | 0 |
| 128 | 3 | SyncTrigPeriod | base | base/sync/rtl/SyncTrigPeriod.vhd | 0 |
| 129 | 3 | SynchronizerFifo | base | base/sync/rtl/SynchronizerFifo.vhd | 11 |
| 130 | 3 | SynchronizerOneShotVector | base | base/sync/rtl/SynchronizerOneShotVector.vhd | 0 |
| 131 | 4 | AxiDualPortRam | axi | axi/axi-lite/rtl/AxiDualPortRam.vhd | 5 |
| 132 | 4 | AxiLiteRingBuffer | axi | axi/axi-lite/rtl/AxiLiteRingBuffer.vhd | 0 |
| 133 | 4 | AxiStreamTimerIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamTimerIpIntegrator.vhd | 0 |
| 134 | 4 | AxiStreamScatterGather | axi | axi/axi-stream/rtl/AxiStreamScatterGather.vhd | 0 |
| 135 | 4 | AxiRateGenIpIntegrator | axi | axi/axi4/ip_integrator/AxiRateGenIpIntegrator.vhd | 0 |
| 136 | 4 | AxiMemTester | axi | axi/axi4/rtl/AxiMemTester.vhd | 0 |
| 137 | 4 | AxiLiteToDrpIpIntegrator | axi | axi/bridge/ip_integrator/AxiLiteToDrpIpIntegrator.vhd | 0 |
| 138 | 4 | SlvArraytoAxiLite | axi | axi/bridge/rtl/SlvArraytoAxiLite.vhd | 0 |
| 139 | 4 | AxiStreamDmaV2Desc | axi | axi/dma/rtl/v2/AxiStreamDmaV2Desc.vhd | 1 |
| 140 | 4 | AxiStreamDmaV2Fifo | axi | axi/dma/rtl/v2/AxiStreamDmaV2Fifo.vhd | 0 |
| 141 | 4 | SlvDelayFifo | base | base/delay/rtl/SlvDelayFifo.vhd | 0 |
| 142 | 4 | FifoCascade | base | base/fifo/rtl/FifoCascade.vhd | 8 |
| 143 | 4 | SyncClockFreq | base | base/sync/rtl/SyncClockFreq.vhd | 0 |
| 144 | 4 | SyncMinMax | base | base/sync/rtl/SyncMinMax.vhd | 2 |
| 145 | 4 | SynchronizerOneShotCnt | base | base/sync/rtl/SynchronizerOneShotCnt.vhd | 1 |
| 146 | 5 | AxiDualPortRamIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiDualPortRamIpIntegrator.vhd | 0 |
| 147 | 5 | AxiLiteCrossbarIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteCrossbarIpIntegrator.vhd | 0 |
| 148 | 5 | AxiLiteFifoPop | axi | axi/axi-lite/rtl/AxiLiteFifoPop.vhd | 0 |
| 149 | 5 | AxiLiteFifoPush | axi | axi/axi-lite/rtl/AxiLiteFifoPush.vhd | 0 |
| 150 | 5 | AxiLiteFifoPushPop | axi | axi/axi-lite/rtl/AxiLiteFifoPushPop.vhd | 1 |
| 151 | 5 | AxiStreamFifoV2 | axi | axi/axi-stream/rtl/AxiStreamFifoV2.vhd | 7 |
| 152 | 5 | AxiReadPathFifo | axi | axi/axi4/rtl/AxiReadPathFifo.vhd | 2 |
| 153 | 5 | AxiWritePathFifo | axi | axi/axi4/rtl/AxiWritePathFifo.vhd | 2 |
| 154 | 5 | AxiStreamDmaV2 | axi | axi/dma/rtl/v2/AxiStreamDmaV2.vhd | 0 |
| 155 | 5 | FifoMux | base | base/fifo/rtl/FifoMux.vhd | 0 |
| 156 | 5 | SyncTrigRate | base | base/sync/rtl/SyncTrigRate.vhd | 2 |
| 157 | 5 | SynchronizerOneShotCntVector | base | base/sync/rtl/SynchronizerOneShotCntVector.vhd | 1 |
| 158 | 6 | AxiStreamFifoV2IpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamFifoV2IpIntegrator.vhd | 0 |
| 159 | 6 | AxiStreamBatchingFifo | axi | axi/axi-stream/rtl/AxiStreamBatchingFifo.vhd | 0 |
| 160 | 6 | AxiStreamMon | axi | axi/axi-stream/rtl/AxiStreamMon.vhd | 1 |
| 161 | 6 | AxiStreamRingBuffer | axi | axi/axi-stream/rtl/AxiStreamRingBuffer.vhd | 0 |
| 162 | 6 | AxiReadEmulate | axi | axi/axi4/rtl/AxiReadEmulate.vhd | 0 |
| 163 | 6 | AxiRingBuffer | axi | axi/axi4/rtl/AxiRingBuffer.vhd | 0 |
| 164 | 6 | AxiWriteEmulate | axi | axi/axi4/rtl/AxiWriteEmulate.vhd | 0 |
| 165 | 6 | AxiStreamDmaRingRead | axi | axi/dma/rtl/v1/AxiStreamDmaRingRead.vhd | 0 |
| 166 | 6 | AxiStreamDmaWrite | axi | axi/dma/rtl/v1/AxiStreamDmaWrite.vhd | 3 |
| 167 | 6 | SyncStatusVector | base | base/sync/rtl/SyncStatusVector.vhd | 1 |
| 168 | 6 | SyncTrigRateVector | base | base/sync/rtl/SyncTrigRateVector.vhd | 0 |
| 169 | 7 | AxiLiteRamSyncStatusVector | axi | axi/axi-lite/rtl/AxiLiteRamSyncStatusVector.vhd | 0 |
| 170 | 7 | AxiStreamMonAxiL | axi | axi/axi-stream/rtl/AxiStreamMonAxiL.vhd | 1 |
| 171 | 7 | AxiStreamDma | axi | axi/dma/rtl/v1/AxiStreamDma.vhd | 0 |
| 172 | 7 | AxiStreamDmaFifo | axi | axi/dma/rtl/v1/AxiStreamDmaFifo.vhd | 0 |
| 173 | 7 | AxiStreamDmaRingWrite | axi | axi/dma/rtl/v1/AxiStreamDmaRingWrite.vhd | 0 |
| 174 | 8 | AxiMonAxiL | axi | axi/axi4/rtl/AxiMonAxiL.vhd | 0 |
