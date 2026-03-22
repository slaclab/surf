# SURF RTL Phase-1 Queue

## Scope
- Scan dirs: `base, axi, protocols, ethernet, devices, xilinx`
- Queue nodes are path-qualified RTL entity definitions, not bare entity names.
- Queue order is bottom-up: leaves first, higher-level assemblies later.
- Manual phase-1 deferrals and order overrides live in `docs/_meta/rtl_phase1_queue_overrides.json`.

## Summary
- Phase-1 modules: `411`
- Phase-1 dependency edges: `704`
- Bottom-up layers: `11`
- Deferred modules: `331`
- Unresolved duplicate-name phase-1 edges: `0`
- Applied order overrides: `0`

## Phase-1 Filters
- Force-included entities:
  - None
- Force-included paths:
  - None
- Deferred subsystems:
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
| 1 | 0 | AxiLiteCrossbar | axi | axi/axi-lite/rtl/AxiLiteCrossbar.vhd | 5 |
| 2 | 0 | AxiLiteMaster | axi | axi/axi-lite/rtl/AxiLiteMaster.vhd | 11 |
| 3 | 0 | AxiLiteRegs | axi | axi/axi-lite/rtl/AxiLiteRegs.vhd | 1 |
| 4 | 0 | AxiLiteRespTimer | axi | axi/axi-lite/rtl/AxiLiteRespTimer.vhd | 0 |
| 5 | 0 | AxiLiteSlave | axi | axi/axi-lite/rtl/AxiLiteSlave.vhd | 1 |
| 6 | 0 | AxiLiteWriteFilter | axi | axi/axi-lite/rtl/AxiLiteWriteFilter.vhd | 0 |
| 7 | 0 | AxiVersion | axi | axi/axi-lite/rtl/AxiVersion.vhd | 1 |
| 8 | 0 | AxiStreamCombiner | axi | axi/axi-stream/rtl/AxiStreamCombiner.vhd | 0 |
| 9 | 0 | AxiStreamFlush | axi | axi/axi-stream/rtl/AxiStreamFlush.vhd | 3 |
| 10 | 0 | AxiStreamGearboxPack | axi | axi/axi-stream/rtl/AxiStreamGearboxPack.vhd | 0 |
| 11 | 0 | AxiStreamGearboxUnpack | axi | axi/axi-stream/rtl/AxiStreamGearboxUnpack.vhd | 0 |
| 12 | 0 | AxiStreamPipeline | axi | axi/axi-stream/rtl/AxiStreamPipeline.vhd | 38 |
| 13 | 0 | AxiStreamSplitter | axi | axi/axi-stream/rtl/AxiStreamSplitter.vhd | 0 |
| 14 | 0 | AxiReadPathMux | axi | axi/axi4/rtl/AxiReadPathMux.vhd | 0 |
| 15 | 0 | AxiResize | axi | axi/axi4/rtl/AxiResize.vhd | 0 |
| 16 | 0 | AxiWritePathMux | axi | axi/axi4/rtl/AxiWritePathMux.vhd | 0 |
| 17 | 0 | AxiToAxiLite | axi | axi/bridge/rtl/AxiToAxiLite.vhd | 1 |
| 18 | 0 | AxiStreamDmaV2WriteMux | axi | axi/dma/rtl/v2/AxiStreamDmaV2WriteMux.vhd | 1 |
| 19 | 0 | CRC32Rtl | base | base/crc/rtl/CRC32Rtl.vhd | 4 |
| 20 | 0 | Crc32 | base | base/crc/rtl/Crc32.vhd | 2 |
| 21 | 0 | Crc32Parallel | base | base/crc/rtl/Crc32Parallel.vhd | 7 |
| 22 | 0 | SlvDelay | base | base/delay/rtl/SlvDelay.vhd | 3 |
| 23 | 0 | SlvDelayRam | base | base/delay/rtl/SlvDelayRam.vhd | 0 |
| 24 | 0 | SlvFixedDelay | base | base/delay/rtl/SlvFixedDelay.vhd | 0 |
| 25 | 0 | FifoOutputPipeline | base | base/fifo/rtl/FifoOutputPipeline.vhd | 3 |
| 26 | 0 | FifoRdFsm | base | base/fifo/rtl/inferred/FifoRdFsm.vhd | 2 |
| 27 | 0 | FifoWrFsm | base | base/fifo/rtl/inferred/FifoWrFsm.vhd | 2 |
| 28 | 0 | MasterRamIpIntegrator | base | base/general/ip_integrator/MasterRamIpIntegrator.vhd | 0 |
| 29 | 0 | SlaveRamIpIntegrator | base | base/general/ip_integrator/SlaveRamIpIntegrator.vhd | 0 |
| 30 | 0 | Arbiter | base | base/general/rtl/Arbiter.vhd | 1 |
| 31 | 0 | ClockDivider | base | base/general/rtl/ClockDivider.vhd | 0 |
| 32 | 0 | Gearbox | base | base/general/rtl/Gearbox.vhd | 5 |
| 33 | 0 | Heartbeat | base | base/general/rtl/Heartbeat.vhd | 0 |
| 34 | 0 | Mux | base | base/general/rtl/Mux.vhd | 0 |
| 35 | 0 | OneShot | base | base/general/rtl/OneShot.vhd | 0 |
| 36 | 0 | RegisterVector | base | base/general/rtl/RegisterVector.vhd | 0 |
| 37 | 0 | RstPipeline | base | base/general/rtl/RstPipeline.vhd | 12 |
| 38 | 0 | Scrambler | base | base/general/rtl/Scrambler.vhd | 5 |
| 39 | 0 | LutRam | base | base/ram/inferred/LutRam.vhd | 2 |
| 40 | 0 | SimpleDualPortRam | base | base/ram/inferred/SimpleDualPortRam.vhd | 6 |
| 41 | 0 | TrueDualPortRam | base | base/ram/inferred/TrueDualPortRam.vhd | 3 |
| 42 | 0 | Synchronizer | base | base/sync/rtl/Synchronizer.vhd | 39 |
| 43 | 0 | SynchronizerVector | base | base/sync/rtl/SynchronizerVector.vhd | 27 |
| 44 | 0 | EthCrc32Parallel | ethernet | ethernet/EthMacCore/rtl/EthCrc32Parallel.vhd | 0 |
| 45 | 0 | EthMacFlowCtrl | ethernet | ethernet/EthMacCore/rtl/EthMacFlowCtrl.vhd | 1 |
| 46 | 0 | EthMacRxBypass | ethernet | ethernet/EthMacCore/rtl/EthMacRxBypass.vhd | 1 |
| 47 | 0 | EthMacRxCsum | ethernet | ethernet/EthMacCore/rtl/EthMacRxCsum.vhd | 1 |
| 48 | 0 | EthMacRxFilter | ethernet | ethernet/EthMacCore/rtl/EthMacRxFilter.vhd | 1 |
| 49 | 0 | EthMacRxImportXlgmii | ethernet | ethernet/EthMacCore/rtl/EthMacRxImportXlgmii.vhd | 1 |
| 50 | 0 | EthMacRxPause | ethernet | ethernet/EthMacCore/rtl/EthMacRxPause.vhd | 1 |
| 51 | 0 | EthMacTxBypass | ethernet | ethernet/EthMacCore/rtl/EthMacTxBypass.vhd | 1 |
| 52 | 0 | EthMacTxExportXlgmii | ethernet | ethernet/EthMacCore/rtl/EthMacTxExportXlgmii.vhd | 1 |
| 53 | 0 | EthMacTxPause | ethernet | ethernet/EthMacCore/rtl/EthMacTxPause.vhd | 1 |
| 54 | 0 | ArpEngine | ethernet | ethernet/IpV4Engine/rtl/ArpEngine.vhd | 1 |
| 55 | 0 | IcmpEngine | ethernet | ethernet/IpV4Engine/rtl/IcmpEngine.vhd | 1 |
| 56 | 0 | IgmpV2Engine | ethernet | ethernet/IpV4Engine/rtl/IgmpV2Engine.vhd | 1 |
| 57 | 0 | IpV4EngineDeMux | ethernet | ethernet/IpV4Engine/rtl/IpV4EngineDeMux.vhd | 1 |
| 58 | 0 | RawEthFramerRx | ethernet | ethernet/RawEthFramer/rtl/RawEthFramerRx.vhd | 1 |
| 59 | 0 | EthMacPrepareForICrc | ethernet | ethernet/RoCEv2/rtl/EthMacPrepareForICrc.vhd | 2 |
| 60 | 0 | EthMacRxCheckICrc | ethernet | ethernet/RoCEv2/rtl/EthMacRxCheckICrc.vhd | 1 |
| 61 | 0 | RoceConfigurator | ethernet | ethernet/RoCEv2/rtl/RoceConfigurator.vhd | 1 |
| 62 | 0 | UdpEngineArp | ethernet | ethernet/UdpEngine/rtl/UdpEngineArp.vhd | 1 |
| 63 | 0 | ClinkReg | protocols | protocols/clink/rtl/ClinkReg.vhd | 1 |
| 64 | 0 | ClinkUartThrottle | protocols | protocols/clink/rtl/ClinkUartThrottle.vhd | 1 |
| 65 | 0 | CoaXPressEventAckMsg | protocols | protocols/coaxpress/core/rtl/CoaXPressEventAckMsg.vhd | 1 |
| 66 | 0 | CoaXPressOverFiberBridgeRx | protocols | protocols/coaxpress/core/rtl/CoaXPressOverFiberBridgeRx.vhd | 1 |
| 67 | 0 | CoaXPressOverFiberBridgeTx | protocols | protocols/coaxpress/core/rtl/CoaXPressOverFiberBridgeTx.vhd | 1 |
| 68 | 0 | CoaXPressRxLane | protocols | protocols/coaxpress/core/rtl/CoaXPressRxLane.vhd | 1 |
| 69 | 0 | CoaXPressRxWordPacker | protocols | protocols/coaxpress/core/rtl/CoaXPressRxWordPacker.vhd | 1 |
| 70 | 0 | CoaXPressTxLsFsm | protocols | protocols/coaxpress/core/rtl/CoaXPressTxLsFsm.vhd | 1 |
| 71 | 0 | GLinkEncoder | protocols | protocols/glink/core/rtl/GLinkEncoder.vhd | 1 |
| 72 | 0 | HammingEccDecoder | protocols | protocols/hamming-ecc/rtl/HammingEccDecoder.vhd | 0 |
| 73 | 0 | HammingEccEncoder | protocols | protocols/hamming-ecc/rtl/HammingEccEncoder.vhd | 0 |
| 74 | 0 | I2cRegMasterAxiBridge | protocols | protocols/i2c/rtl/I2cRegMasterAxiBridge.vhd | 1 |
| 75 | 0 | I2cRegMasterMux | protocols | protocols/i2c/rtl/I2cRegMasterMux.vhd | 0 |
| 76 | 0 | I2cSlave | protocols | protocols/i2c/rtl/I2cSlave.vhd | 1 |
| 77 | 0 | i2c_master_bit_ctrl | protocols | protocols/i2c/rtl/i2c_master_bit_ctrl.vhd | 1 |
| 78 | 0 | i2c2ahbx | protocols | protocols/i2c/rtl/orig/i2c2ahbx.vhd | 2 |
| 79 | 0 | i2cslv | protocols | protocols/i2c/rtl/orig/i2cslv.vhd | 0 |
| 80 | 0 | JesdAlignChGen | protocols | protocols/jesd204b/rtl/JesdAlignChGen.vhd | 1 |
| 81 | 0 | JesdAlignFrRepCh | protocols | protocols/jesd204b/rtl/JesdAlignFrRepCh.vhd | 1 |
| 82 | 0 | JesdIlasGen | protocols | protocols/jesd204b/rtl/JesdIlasGen.vhd | 1 |
| 83 | 0 | JesdLmfcGen | protocols | protocols/jesd204b/rtl/JesdLmfcGen.vhd | 2 |
| 84 | 0 | JesdSyncFsmRx | protocols | protocols/jesd204b/rtl/JesdSyncFsmRx.vhd | 1 |
| 85 | 0 | JesdSyncFsmTx | protocols | protocols/jesd204b/rtl/JesdSyncFsmTx.vhd | 1 |
| 86 | 0 | JesdSyncFsmTxTest | protocols | protocols/jesd204b/rtl/JesdSyncFsmTxTest.vhd | 1 |
| 87 | 0 | JesdTestSigGen | protocols | protocols/jesd204b/rtl/JesdTestSigGen.vhd | 1 |
| 88 | 0 | JesdTestStreamTx | protocols | protocols/jesd204b/rtl/JesdTestStreamTx.vhd | 1 |
| 89 | 0 | Decoder10b12b | protocols | protocols/line-codes/rtl/Decoder10b12b.vhd | 1 |
| 90 | 0 | Decoder12b14b | protocols | protocols/line-codes/rtl/Decoder12b14b.vhd | 1 |
| 91 | 0 | Decoder8b10b | protocols | protocols/line-codes/rtl/Decoder8b10b.vhd | 4 |
| 92 | 0 | Encoder10b12b | protocols | protocols/line-codes/rtl/Encoder10b12b.vhd | 1 |
| 93 | 0 | Encoder12b14b | protocols | protocols/line-codes/rtl/Encoder12b14b.vhd | 1 |
| 94 | 0 | Encoder8b10b | protocols | protocols/line-codes/rtl/Encoder8b10b.vhd | 4 |
| 95 | 0 | MdioCore | protocols | protocols/mdio/rtl/MdioCore.vhd | 1 |
| 96 | 0 | AxiStreamBytePacker | protocols | protocols/packetizer/rtl/AxiStreamBytePacker.vhd | 1 |
| 97 | 0 | Pgp2bRxCell | protocols | protocols/pgp/pgp2b/core/rtl/Pgp2bRxCell.vhd | 1 |
| 98 | 0 | Pgp2bRxPhy | protocols | protocols/pgp/pgp2b/core/rtl/Pgp2bRxPhy.vhd | 1 |
| 99 | 0 | Pgp2bTxCell | protocols | protocols/pgp/pgp2b/core/rtl/Pgp2bTxCell.vhd | 1 |
| 100 | 0 | Pgp2bTxPhy | protocols | protocols/pgp/pgp2b/core/rtl/Pgp2bTxPhy.vhd | 1 |
| 101 | 0 | Pgp2bTxSched | protocols | protocols/pgp/pgp2b/core/rtl/Pgp2bTxSched.vhd | 1 |
| 102 | 0 | CRC7Rtl | protocols | protocols/pgp/pgp2fc/core/rtl/CRC7Rtl.vhd | 2 |
| 103 | 0 | Pgp2fcRxCell | protocols | protocols/pgp/pgp2fc/core/rtl/Pgp2fcRxCell.vhd | 1 |
| 104 | 0 | Pgp2fcTxCell | protocols | protocols/pgp/pgp2fc/core/rtl/Pgp2fcTxCell.vhd | 1 |
| 105 | 0 | Pgp2fcTxSched | protocols | protocols/pgp/pgp2fc/core/rtl/Pgp2fcTxSched.vhd | 1 |
| 106 | 0 | Pgp3RxGearboxAligner | protocols | protocols/pgp/pgp3/core/rtl/Pgp3RxGearboxAligner.vhd | 2 |
| 107 | 0 | Pgp3TxProtocol | protocols | protocols/pgp/pgp3/core/rtl/Pgp3TxProtocol.vhd | 1 |
| 108 | 0 | Pgp4TxProtocol | protocols | protocols/pgp/pgp4/core/rtl/Pgp4TxProtocol.vhd | 1 |
| 109 | 0 | RssiChksum | protocols | protocols/rssi/v1/rtl/RssiChksum.vhd | 1 |
| 110 | 0 | RssiConnFsm | protocols | protocols/rssi/v1/rtl/RssiConnFsm.vhd | 1 |
| 111 | 0 | RssiHeaderReg | protocols | protocols/rssi/v1/rtl/RssiHeaderReg.vhd | 1 |
| 112 | 0 | RssiMonitor | protocols | protocols/rssi/v1/rtl/RssiMonitor.vhd | 1 |
| 113 | 0 | RssiRxFsm | protocols | protocols/rssi/v1/rtl/RssiRxFsm.vhd | 1 |
| 114 | 0 | RssiTxFsm | protocols | protocols/rssi/v1/rtl/RssiTxFsm.vhd | 1 |
| 115 | 0 | SaciMaster | protocols | protocols/saci/saci1/rtl/SaciMaster.vhd | 0 |
| 116 | 0 | SaciMasterSync | protocols | protocols/saci/saci1/rtl/SaciMasterSync.vhd | 0 |
| 117 | 0 | SaciMultiPixel | protocols | protocols/saci/saci1/rtl/SaciMultiPixel.vhd | 0 |
| 118 | 0 | SaciPrepRdout | protocols | protocols/saci/saci1/rtl/SaciPrepRdout.vhd | 0 |
| 119 | 0 | SaciSlave | protocols | protocols/saci/saci1/rtl/SaciSlave.vhd | 1 |
| 120 | 0 | SaciSlaveOld | protocols | protocols/saci/saci1/rtl/SaciSlaveOld.vhd | 0 |
| 121 | 0 | Saci2Subordinate | protocols | protocols/saci/saci2/rtl/Saci2Subordinate.vhd | 1 |
| 122 | 0 | SaltTxResize | protocols | protocols/salt/rtl/SaltTxResize.vhd | 1 |
| 123 | 0 | SpiMaster | protocols | protocols/spi/rtl/SpiMaster.vhd | 1 |
| 124 | 0 | SsiCmdMasterPulser | protocols | protocols/ssi/rtl/SsiCmdMasterPulser.vhd | 0 |
| 125 | 0 | SsiDbgTap | protocols | protocols/ssi/rtl/SsiDbgTap.vhd | 0 |
| 126 | 0 | SsiIbFrameFilter | protocols | protocols/ssi/rtl/SsiIbFrameFilter.vhd | 1 |
| 127 | 0 | SspDeframer | protocols | protocols/ssp/rtl/SspDeframer.vhd | 3 |
| 128 | 0 | SspFramer | protocols | protocols/ssp/rtl/SspFramer.vhd | 3 |
| 129 | 0 | SugoiAxiLitePixelMatrixConfig | protocols | protocols/sugoi/rtl/SugoiAxiLitePixelMatrixConfig.vhd | 0 |
| 130 | 0 | SugoiManagerFsm | protocols | protocols/sugoi/rtl/SugoiManagerFsm.vhd | 1 |
| 131 | 0 | SugoiManagerRx | protocols | protocols/sugoi/rtl/SugoiManagerRx.vhd | 1 |
| 132 | 0 | SugoiSubordinateFsm | protocols | protocols/sugoi/rtl/SugoiSubordinateFsm.vhd | 1 |
| 133 | 0 | UartBrg | protocols | protocols/uart/rtl/UartBrg.vhd | 1 |
| 134 | 0 | UartTx | protocols | protocols/uart/rtl/UartTx.vhd | 2 |
| 135 | 1 | AxiLiteMasterProxy | axi | axi/axi-lite/rtl/AxiLiteMasterProxy.vhd | 3 |
| 136 | 1 | AxiLiteSequencerRam | axi | axi/axi-lite/rtl/AxiLiteSequencerRam.vhd | 0 |
| 137 | 1 | AxiStreamCompact | axi | axi/axi-stream/rtl/AxiStreamCompact.vhd | 2 |
| 138 | 1 | AxiStreamConcat | axi | axi/axi-stream/rtl/AxiStreamConcat.vhd | 0 |
| 139 | 1 | AxiStreamDeMux | axi | axi/axi-stream/rtl/AxiStreamDeMux.vhd | 13 |
| 140 | 1 | AxiStreamFrameRateLimiter | axi | axi/axi-stream/rtl/AxiStreamFrameRateLimiter.vhd | 0 |
| 141 | 1 | AxiStreamMux | axi | axi/axi-stream/rtl/AxiStreamMux.vhd | 14 |
| 142 | 1 | AxiStreamPrbsFlowCtrl | axi | axi/axi-stream/rtl/AxiStreamPrbsFlowCtrl.vhd | 0 |
| 143 | 1 | AxiStreamRepeater | axi | axi/axi-stream/rtl/AxiStreamRepeater.vhd | 2 |
| 144 | 1 | AxiStreamResize | axi | axi/axi-stream/rtl/AxiStreamResize.vhd | 7 |
| 145 | 1 | AxiStreamShift | axi | axi/axi-stream/rtl/AxiStreamShift.vhd | 4 |
| 146 | 1 | AxiStreamTrailerAppend | axi | axi/axi-stream/rtl/AxiStreamTrailerAppend.vhd | 1 |
| 147 | 1 | AxiStreamTrailerRemove | axi | axi/axi-stream/rtl/AxiStreamTrailerRemove.vhd | 1 |
| 148 | 1 | AxiRam | axi | axi/axi4/rtl/AxiRam.vhd | 0 |
| 149 | 1 | AxiLiteToIpBus | axi | axi/bridge/rtl/AxiLiteToIpBus.vhd | 0 |
| 150 | 1 | IpBusToAxiLite | axi | axi/bridge/rtl/IpBusToAxiLite.vhd | 0 |
| 151 | 1 | AxiStreamDmaV2Read | axi | axi/dma/rtl/v2/AxiStreamDmaV2Read.vhd | 2 |
| 152 | 1 | FifoSync | base | base/fifo/rtl/inferred/FifoSync.vhd | 3 |
| 153 | 1 | RstPipelineVector | base | base/general/rtl/RstPipelineVector.vhd | 2 |
| 154 | 1 | WatchDogRst | base | base/general/rtl/WatchDogRst.vhd | 1 |
| 155 | 1 | DualPortRam | base | base/ram/inferred/DualPortRam.vhd | 6 |
| 156 | 1 | RstSync | base | base/sync/rtl/RstSync.vhd | 21 |
| 157 | 1 | SynchronizerEdge | base | base/sync/rtl/SynchronizerEdge.vhd | 4 |
| 158 | 1 | RawEthFramerTx | ethernet | ethernet/RawEthFramer/rtl/RawEthFramerTx.vhd | 1 |
| 159 | 1 | RoceResizeAndSwap | ethernet | ethernet/RoCEv2/rtl/RoceResizeAndSwap.vhd | 1 |
| 160 | 1 | TenGigEthRst | ethernet | ethernet/TenGigEthCore/core/rtl/TenGigEthRst.vhd | 0 |
| 161 | 1 | UdpEngineTx | ethernet | ethernet/UdpEngine/rtl/UdpEngineTx.vhd | 1 |
| 162 | 1 | CoaXPressRxHsFsm | protocols | protocols/coaxpress/core/rtl/CoaXPressRxHsFsm.vhd | 1 |
| 163 | 1 | CoaXPressRxLaneMux | protocols | protocols/coaxpress/core/rtl/CoaXPressRxLaneMux.vhd | 1 |
| 164 | 1 | EventFrameSequencerDemux | protocols | protocols/event-frame-sequencer/rtl/EventFrameSequencerDemux.vhd | 0 |
| 165 | 1 | EventFrameSequencerMux | protocols | protocols/event-frame-sequencer/rtl/EventFrameSequencerMux.vhd | 0 |
| 166 | 1 | GLinkDecoder | protocols | protocols/glink/core/rtl/GLinkDecoder.vhd | 1 |
| 167 | 1 | I2cRegSlave | protocols | protocols/i2c/rtl/I2cRegSlave.vhd | 0 |
| 168 | 1 | i2c_master_byte_ctrl | protocols | protocols/i2c/rtl/i2c_master_byte_ctrl.vhd | 2 |
| 169 | 1 | i2c2ahb | protocols | protocols/i2c/rtl/orig/i2c2ahb.vhd | 0 |
| 170 | 1 | i2c2ahb_apb | protocols | protocols/i2c/rtl/orig/i2c2ahb_apb.vhd | 0 |
| 171 | 1 | JesdTxLane | protocols | protocols/jesd204b/rtl/JesdTxLane.vhd | 1 |
| 172 | 1 | JesdTxTest | protocols | protocols/jesd204b/rtl/JesdTxTest.vhd | 1 |
| 173 | 1 | MdioSeqCore | protocols | protocols/mdio/rtl/MdioSeqCore.vhd | 1 |
| 174 | 1 | AxiStreamDepacketizer | protocols | protocols/packetizer/rtl/AxiStreamDepacketizer.vhd | 1 |
| 175 | 1 | AxiStreamPacketizer | protocols | protocols/packetizer/rtl/AxiStreamPacketizer.vhd | 1 |
| 176 | 1 | Pgp2bRx | protocols | protocols/pgp/pgp2b/core/rtl/Pgp2bRx.vhd | 1 |
| 177 | 1 | Pgp2bTx | protocols | protocols/pgp/pgp2b/core/rtl/Pgp2bTx.vhd | 1 |
| 178 | 1 | Pgp2fcRxPhy | protocols | protocols/pgp/pgp2fc/core/rtl/Pgp2fcRxPhy.vhd | 1 |
| 179 | 1 | Pgp2fcTxPhy | protocols | protocols/pgp/pgp2fc/core/rtl/Pgp2fcTxPhy.vhd | 1 |
| 180 | 1 | Pgp4TxLiteProtocol | protocols | protocols/pgp/pgp4/core/rtl/Pgp4TxLiteProtocol.vhd | 1 |
| 181 | 1 | RssiParamSync | protocols | protocols/rssi/v1/rtl/RssiParamSync.vhd | 1 |
| 182 | 1 | SaciAxiLiteMaster | protocols | protocols/saci/saci1/rtl/SaciAxiLiteMaster.vhd | 0 |
| 183 | 1 | SaciMaster2 | protocols | protocols/saci/saci1/rtl/SaciMaster2.vhd | 1 |
| 184 | 1 | Saci2Coordinator | protocols | protocols/saci/saci2/rtl/Saci2Coordinator.vhd | 1 |
| 185 | 1 | Saci2ToAxiLite | protocols | protocols/saci/saci2/rtl/Saci2ToAxiLite.vhd | 0 |
| 186 | 1 | SpiSlave | protocols | protocols/spi/rtl/SpiSlave.vhd | 0 |
| 187 | 1 | SsiObFrameFilter | protocols | protocols/ssi/rtl/SsiObFrameFilter.vhd | 1 |
| 188 | 1 | SspDecoder10b12b | protocols | protocols/ssp/rtl/SspDecoder10b12b.vhd | 1 |
| 189 | 1 | SspDecoder12b14b | protocols | protocols/ssp/rtl/SspDecoder12b14b.vhd | 1 |
| 190 | 1 | SspDecoder8b10b | protocols | protocols/ssp/rtl/SspDecoder8b10b.vhd | 1 |
| 191 | 1 | SspEncoder10b12b | protocols | protocols/ssp/rtl/SspEncoder10b12b.vhd | 0 |
| 192 | 1 | SspEncoder12b14b | protocols | protocols/ssp/rtl/SspEncoder12b14b.vhd | 0 |
| 193 | 1 | SspEncoder8b10b | protocols | protocols/ssp/rtl/SspEncoder8b10b.vhd | 0 |
| 194 | 1 | SugoiSubordinateCore | protocols | protocols/sugoi/rtl/SugoiSubordinateCore.vhd | 0 |
| 195 | 1 | UartAxiLiteMasterFsm | protocols | protocols/uart/rtl/UartAxiLiteMasterFsm.vhd | 1 |
| 196 | 2 | MasterAxiLiteIpIntegrator | axi | axi/axi-lite/ip_integrator/MasterAxiLiteIpIntegrator.vhd | 2 |
| 197 | 2 | SlaveAxiLiteIpIntegrator | axi | axi/axi-lite/ip_integrator/SlaveAxiLiteIpIntegrator.vhd | 4 |
| 198 | 2 | AxiLiteAsync | axi | axi/axi-lite/rtl/AxiLiteAsync.vhd | 11 |
| 199 | 2 | MasterAxiStreamIpIntegrator | axi | axi/axi-stream/ip_integrator/MasterAxiStreamIpIntegrator.vhd | 9 |
| 200 | 2 | SlaveAxiStreamIpIntegrator | axi | axi/axi-stream/ip_integrator/SlaveAxiStreamIpIntegrator.vhd | 9 |
| 201 | 2 | AxiStreamGearbox | axi | axi/axi-stream/rtl/AxiStreamGearbox.vhd | 5 |
| 202 | 2 | AxiStreamTap | axi | axi/axi-stream/rtl/AxiStreamTap.vhd | 0 |
| 203 | 2 | MasterAxiIpIntegrator | axi | axi/axi4/ip_integrator/MasterAxiIpIntegrator.vhd | 0 |
| 204 | 2 | SlaveAxiIpIntegrator | axi | axi/axi4/ip_integrator/SlaveAxiIpIntegrator.vhd | 0 |
| 205 | 2 | AxiStreamDmaRead | axi | axi/dma/rtl/v1/AxiStreamDmaRead.vhd | 4 |
| 206 | 2 | AxiStreamDmaV2Write | axi | axi/dma/rtl/v2/AxiStreamDmaV2Write.vhd | 2 |
| 207 | 2 | FifoAsync | base | base/fifo/rtl/inferred/FifoAsync.vhd | 6 |
| 208 | 2 | Debouncer | base | base/general/rtl/Debouncer.vhd | 0 |
| 209 | 2 | PwrUpRst | base | base/general/rtl/PwrUpRst.vhd | 0 |
| 210 | 2 | SynchronizerOneShot | base | base/sync/rtl/SynchronizerOneShot.vhd | 19 |
| 211 | 2 | EthMacRxShift | ethernet | ethernet/EthMacCore/rtl/EthMacRxShift.vhd | 0 |
| 212 | 2 | EthMacTxExportGmii | ethernet | ethernet/EthMacCore/rtl/EthMacTxExportGmii.vhd | 1 |
| 213 | 2 | EthMacTxShift | ethernet | ethernet/EthMacCore/rtl/EthMacTxShift.vhd | 0 |
| 214 | 2 | IpV4EngineRx | ethernet | ethernet/IpV4Engine/rtl/IpV4EngineRx.vhd | 1 |
| 215 | 2 | IpV4EngineTx | ethernet | ethernet/IpV4Engine/rtl/IpV4EngineTx.vhd | 1 |
| 216 | 2 | RawEthFramer | ethernet | ethernet/RawEthFramer/rtl/RawEthFramer.vhd | 1 |
| 217 | 2 | UdpEngineRx | ethernet | ethernet/UdpEngine/rtl/UdpEngineRx.vhd | 1 |
| 218 | 2 | GLinkTxToRx | protocols | protocols/glink/core/rtl/GLinkTxToRx.vhd | 0 |
| 219 | 2 | HtspRx | protocols | protocols/htsp/core/rtl/HtspRx.vhd | 1 |
| 220 | 2 | HtspTx | protocols | protocols/htsp/core/rtl/HtspTx.vhd | 1 |
| 221 | 2 | I2cMaster | protocols | protocols/i2c/rtl/I2cMaster.vhd | 1 |
| 222 | 2 | i2cmst | protocols | protocols/i2c/rtl/orig/i2cmst.vhd | 1 |
| 223 | 2 | JesdRxLane | protocols | protocols/jesd204b/rtl/JesdRxLane.vhd | 1 |
| 224 | 2 | MdioLinkIrqHandler | protocols | protocols/mdio/rtl/MdioLinkIrqHandler.vhd | 0 |
| 225 | 2 | AxiStreamDepacketizer2 | protocols | protocols/packetizer/rtl/AxiStreamDepacketizer2.vhd | 3 |
| 226 | 2 | AxiStreamPacketizer2 | protocols | protocols/packetizer/rtl/AxiStreamPacketizer2.vhd | 3 |
| 227 | 2 | Pgp2bLane | protocols | protocols/pgp/pgp2b/core/rtl/Pgp2bLane.vhd | 0 |
| 228 | 2 | Pgp2fcAlignmentChecker | protocols | protocols/pgp/pgp2fc/core/rtl/Pgp2fcAlignmentChecker.vhd | 0 |
| 229 | 2 | Pgp2fcAlignmentController | protocols | protocols/pgp/pgp2fc/core/rtl/Pgp2fcAlignmentController.vhd | 0 |
| 230 | 2 | Pgp2fcRx | protocols | protocols/pgp/pgp2fc/core/rtl/Pgp2fcRx.vhd | 1 |
| 231 | 2 | Pgp2fcTx | protocols | protocols/pgp/pgp2fc/core/rtl/Pgp2fcTx.vhd | 1 |
| 232 | 2 | Pgp3RxProtocol | protocols | protocols/pgp/pgp3/core/rtl/Pgp3RxProtocol.vhd | 1 |
| 233 | 2 | AxiLiteSaciMaster | protocols | protocols/saci/saci1/rtl/AxiLiteSaciMaster.vhd | 0 |
| 234 | 2 | AxiLiteToSaci2 | protocols | protocols/saci/saci2/rtl/AxiLiteToSaci2.vhd | 0 |
| 235 | 2 | SaltDelayCtrl | protocols | protocols/salt/rtl/SaltDelayCtrl.vhd | 0 |
| 236 | 2 | AxiSpiMaster | protocols | protocols/spi/rtl/AxiSpiMaster.vhd | 0 |
| 237 | 2 | SspLowSpeedDecoderLane | protocols | protocols/ssp/rtl/SspLowSpeedDecoderLane.vhd | 3 |
| 238 | 2 | UartRx | protocols | protocols/uart/rtl/UartRx.vhd | 2 |
| 239 | 3 | AxiLiteAsyncIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteAsyncIpIntegrator.vhd | 0 |
| 240 | 3 | AxiLiteMasterIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiLiteMasterIpIntegrator.vhd | 0 |
| 241 | 3 | AxiVersionIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiVersionIpIntegrator.vhd | 0 |
| 242 | 3 | AxiStreamDeMuxIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamDeMuxIpIntegrator.vhd | 0 |
| 243 | 3 | AxiStreamMuxIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamMuxIpIntegrator.vhd | 0 |
| 244 | 3 | AxiStreamPipelineIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamPipelineIpIntegrator.vhd | 0 |
| 245 | 3 | AxiStreamResizeIpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamResizeIpIntegrator.vhd | 0 |
| 246 | 3 | MasterAxiStreamTerminateIpIntegrator | axi | axi/axi-stream/ip_integrator/MasterAxiStreamTerminateIpIntegrator.vhd | 0 |
| 247 | 3 | SlaveAxiStreamTerminateIpIntegrator | axi | axi/axi-stream/ip_integrator/SlaveAxiStreamTerminateIpIntegrator.vhd | 0 |
| 248 | 3 | AxiStreamTimer | axi | axi/axi-stream/rtl/AxiStreamTimer.vhd | 0 |
| 249 | 3 | AxiRateGen | axi | axi/axi4/rtl/AxiRateGen.vhd | 0 |
| 250 | 3 | AxiLiteToDrp | axi | axi/bridge/rtl/AxiLiteToDrp.vhd | 1 |
| 251 | 3 | Fifo | base | base/fifo/rtl/Fifo.vhd | 17 |
| 252 | 3 | AsyncGearbox | base | base/general/rtl/AsyncGearbox.vhd | 3 |
| 253 | 3 | SyncTrigPeriod | base | base/sync/rtl/SyncTrigPeriod.vhd | 0 |
| 254 | 3 | SynchronizerFifo | base | base/sync/rtl/SynchronizerFifo.vhd | 24 |
| 255 | 3 | SynchronizerOneShotVector | base | base/sync/rtl/SynchronizerOneShotVector.vhd | 1 |
| 256 | 3 | IpV4Engine | ethernet | ethernet/IpV4Engine/rtl/IpV4Engine.vhd | 1 |
| 257 | 3 | EthMacCrcAxiStreamWrapperRecv | ethernet | ethernet/RoCEv2/rtl/EthMacCrcAxiStreamWrapperRecv.vhd | 1 |
| 258 | 3 | EthMacCrcAxiStreamWrapperSend | ethernet | ethernet/RoCEv2/rtl/EthMacCrcAxiStreamWrapperSend.vhd | 1 |
| 259 | 3 | RoceEngineWrapper | ethernet | ethernet/RoCEv2/rtl/RoceEngineWrapper.vhd | 0 |
| 260 | 3 | AxiStreamBatcher | protocols | protocols/batcher/rtl/AxiStreamBatcher.vhd | 2 |
| 261 | 3 | I2cRegMaster | protocols | protocols/i2c/rtl/I2cRegMaster.vhd | 4 |
| 262 | 3 | i2cmst_gen | protocols | protocols/i2c/rtl/orig/i2cmst_gen.vhd | 0 |
| 263 | 3 | Pgp2fcLane | protocols | protocols/pgp/pgp2fc/core/rtl/Pgp2fcLane.vhd | 0 |
| 264 | 3 | Pgp3Tx | protocols | protocols/pgp/pgp3/core/rtl/Pgp3Tx.vhd | 1 |
| 265 | 3 | Pgp4Tx | protocols | protocols/pgp/pgp4/core/rtl/Pgp4Tx.vhd | 1 |
| 266 | 3 | Pgp4TxLite | protocols | protocols/pgp/pgp4/core/rtl/Pgp4TxLite.vhd | 2 |
| 267 | 3 | SugoiManagerCore | protocols | protocols/sugoi/rtl/SugoiManagerCore.vhd | 0 |
| 268 | 4 | AxiDualPortRam | axi | axi/axi-lite/rtl/AxiDualPortRam.vhd | 6 |
| 269 | 4 | AxiLiteRingBuffer | axi | axi/axi-lite/rtl/AxiLiteRingBuffer.vhd | 0 |
| 270 | 4 | AxiStreamScatterGather | axi | axi/axi-stream/rtl/AxiStreamScatterGather.vhd | 0 |
| 271 | 4 | AxiMemTester | axi | axi/axi4/rtl/AxiMemTester.vhd | 0 |
| 272 | 4 | AxiLiteToDrpIpIntegrator | axi | axi/bridge/ip_integrator/AxiLiteToDrpIpIntegrator.vhd | 0 |
| 273 | 4 | SlvArraytoAxiLite | axi | axi/bridge/rtl/SlvArraytoAxiLite.vhd | 0 |
| 274 | 4 | AxiStreamDmaV2Desc | axi | axi/dma/rtl/v2/AxiStreamDmaV2Desc.vhd | 1 |
| 275 | 4 | AxiStreamDmaV2Fifo | axi | axi/dma/rtl/v2/AxiStreamDmaV2Fifo.vhd | 0 |
| 276 | 4 | SlvDelayFifo | base | base/delay/rtl/SlvDelayFifo.vhd | 0 |
| 277 | 4 | FifoCascade | base | base/fifo/rtl/FifoCascade.vhd | 8 |
| 278 | 4 | SyncClockFreq | base | base/sync/rtl/SyncClockFreq.vhd | 6 |
| 279 | 4 | SyncMinMax | base | base/sync/rtl/SyncMinMax.vhd | 3 |
| 280 | 4 | SynchronizerOneShotCnt | base | base/sync/rtl/SynchronizerOneShotCnt.vhd | 1 |
| 281 | 4 | EthMacRxImportXgmii | ethernet | ethernet/EthMacCore/rtl/EthMacRxImportXgmii.vhd | 1 |
| 282 | 4 | ArpIpTable | ethernet | ethernet/UdpEngine/rtl/ArpIpTable.vhd | 1 |
| 283 | 4 | AxiStreamBatcherAxil | protocols | protocols/batcher/rtl/AxiStreamBatcherAxil.vhd | 0 |
| 284 | 4 | AxiStreamBatcherEventBuilder | protocols | protocols/batcher/rtl/AxiStreamBatcherEventBuilder.vhd | 0 |
| 285 | 4 | ClinkData | protocols | protocols/clink/rtl/ClinkData.vhd | 1 |
| 286 | 4 | CoaXPressOverFiberBridge | protocols | protocols/coaxpress/core/rtl/CoaXPressOverFiberBridge.vhd | 0 |
| 287 | 4 | AxiI2cEepromCore | protocols | protocols/i2c/axi/AxiI2cEepromCore.vhd | 1 |
| 288 | 4 | AxiI2cRegMasterCore | protocols | protocols/i2c/axi/AxiI2cRegMasterCore.vhd | 1 |
| 289 | 4 | AxiLiteCrossbarI2cMux | protocols | protocols/i2c/axi/AxiLiteCrossbarI2cMux.vhd | 0 |
| 290 | 4 | Jesd16bTo32b | protocols | protocols/jesd204b/rtl/Jesd16bTo32b.vhd | 0 |
| 291 | 4 | Jesd32bTo16b | protocols | protocols/jesd204b/rtl/Jesd32bTo16b.vhd | 0 |
| 292 | 4 | Jesd32bTo64b | protocols | protocols/jesd204b/rtl/Jesd32bTo64b.vhd | 0 |
| 293 | 4 | Jesd64bTo32b | protocols | protocols/jesd204b/rtl/Jesd64bTo32b.vhd | 0 |
| 294 | 4 | JesdSysrefMon | protocols | protocols/jesd204b/rtl/JesdSysrefMon.vhd | 2 |
| 295 | 4 | iq16bTo32b | protocols | protocols/jesd204b/rtl/iq16bTo32b.vhd | 0 |
| 296 | 4 | iq32bTo16b | protocols | protocols/jesd204b/rtl/iq32bTo16b.vhd | 0 |
| 297 | 4 | Pgp3RxEb | protocols | protocols/pgp/pgp3/core/rtl/Pgp3RxEb.vhd | 1 |
| 298 | 4 | Pgp4RxEb | protocols | protocols/pgp/pgp4/core/rtl/Pgp4RxEb.vhd | 1 |
| 299 | 4 | Pgp4TxLiteWrapper | protocols | protocols/pgp/pgp4/core/rtl/Pgp4TxLiteWrapper.vhd | 0 |
| 300 | 4 | AxiLitePMbusMasterCore | protocols | protocols/pmbus/rtl/AxiLitePMbusMasterCore.vhd | 1 |
| 301 | 4 | RssiAxiLiteRegItf | protocols | protocols/rssi/v1/rtl/RssiAxiLiteRegItf.vhd | 1 |
| 302 | 4 | SaltRxLvds | protocols | protocols/salt/rtl/SaltRxLvds.vhd | 1 |
| 303 | 4 | SaltTxLvds | protocols | protocols/salt/rtl/SaltTxLvds.vhd | 1 |
| 304 | 4 | UartWrapper | protocols | protocols/uart/rtl/UartWrapper.vhd | 1 |
| 305 | 5 | AxiDualPortRamIpIntegrator | axi | axi/axi-lite/ip_integrator/AxiDualPortRamIpIntegrator.vhd | 0 |
| 306 | 5 | AxiLiteFifoPop | axi | axi/axi-lite/rtl/AxiLiteFifoPop.vhd | 0 |
| 307 | 5 | AxiLiteFifoPush | axi | axi/axi-lite/rtl/AxiLiteFifoPush.vhd | 0 |
| 308 | 5 | AxiLiteFifoPushPop | axi | axi/axi-lite/rtl/AxiLiteFifoPushPop.vhd | 1 |
| 309 | 5 | AxiStreamFifoV2 | axi | axi/axi-stream/rtl/AxiStreamFifoV2.vhd | 37 |
| 310 | 5 | AxiReadPathFifo | axi | axi/axi4/rtl/AxiReadPathFifo.vhd | 2 |
| 311 | 5 | AxiWritePathFifo | axi | axi/axi4/rtl/AxiWritePathFifo.vhd | 2 |
| 312 | 5 | AxiStreamDmaV2 | axi | axi/dma/rtl/v2/AxiStreamDmaV2.vhd | 0 |
| 313 | 5 | FifoMux | base | base/fifo/rtl/FifoMux.vhd | 0 |
| 314 | 5 | SyncTrigRate | base | base/sync/rtl/SyncTrigRate.vhd | 3 |
| 315 | 5 | SynchronizerOneShotCntVector | base | base/sync/rtl/SynchronizerOneShotCntVector.vhd | 1 |
| 316 | 5 | RawEthFramerWrapper | ethernet | ethernet/RawEthFramer/rtl/RawEthFramerWrapper.vhd | 0 |
| 317 | 5 | AxiI2cEeprom | protocols | protocols/i2c/axi/AxiI2cEeprom.vhd | 0 |
| 318 | 5 | AxiI2cRegMaster | protocols | protocols/i2c/axi/AxiI2cRegMaster.vhd | 0 |
| 319 | 5 | Pgp3Rx | protocols | protocols/pgp/pgp3/core/rtl/Pgp3Rx.vhd | 1 |
| 320 | 5 | AxiLitePMbusMaster | protocols | protocols/pmbus/rtl/AxiLitePMbusMaster.vhd | 0 |
| 321 | 5 | UartAxiLiteMaster | protocols | protocols/uart/rtl/UartAxiLiteMaster.vhd | 0 |
| 322 | 6 | AxiStreamFifoV2IpIntegrator | axi | axi/axi-stream/ip_integrator/AxiStreamFifoV2IpIntegrator.vhd | 0 |
| 323 | 6 | AxiStreamBatchingFifo | axi | axi/axi-stream/rtl/AxiStreamBatchingFifo.vhd | 0 |
| 324 | 6 | AxiStreamMon | axi | axi/axi-stream/rtl/AxiStreamMon.vhd | 4 |
| 325 | 6 | AxiStreamRingBuffer | axi | axi/axi-stream/rtl/AxiStreamRingBuffer.vhd | 0 |
| 326 | 6 | AxiReadEmulate | axi | axi/axi4/rtl/AxiReadEmulate.vhd | 0 |
| 327 | 6 | AxiRingBuffer | axi | axi/axi4/rtl/AxiRingBuffer.vhd | 0 |
| 328 | 6 | AxiWriteEmulate | axi | axi/axi4/rtl/AxiWriteEmulate.vhd | 0 |
| 329 | 6 | AxiStreamDmaRingRead | axi | axi/dma/rtl/v1/AxiStreamDmaRingRead.vhd | 0 |
| 330 | 6 | AxiStreamDmaWrite | axi | axi/dma/rtl/v1/AxiStreamDmaWrite.vhd | 4 |
| 331 | 6 | SyncStatusVector | base | base/sync/rtl/SyncStatusVector.vhd | 15 |
| 332 | 6 | SyncTrigRateVector | base | base/sync/rtl/SyncTrigRateVector.vhd | 0 |
| 333 | 6 | EthMacRxImportGmii | ethernet | ethernet/EthMacCore/rtl/EthMacRxImportGmii.vhd | 1 |
| 334 | 6 | EthMacTxCsum | ethernet | ethernet/EthMacCore/rtl/EthMacTxCsum.vhd | 1 |
| 335 | 6 | EthMacTxExportXgmii | ethernet | ethernet/EthMacCore/rtl/EthMacTxExportXgmii.vhd | 1 |
| 336 | 6 | EthMacTxFifo | ethernet | ethernet/EthMacCore/rtl/EthMacTxFifo.vhd | 1 |
| 337 | 6 | EthMacRxRoCEv2 | ethernet | ethernet/RoCEv2/rtl/EthMacRxRoCEv2.vhd | 1 |
| 338 | 6 | EthMacTxRoCEv2 | ethernet | ethernet/RoCEv2/rtl/EthMacTxRoCEv2.vhd | 1 |
| 339 | 6 | UdpEngineDhcp | ethernet | ethernet/UdpEngine/rtl/UdpEngineDhcp.vhd | 1 |
| 340 | 6 | ClinkFraming | protocols | protocols/clink/rtl/ClinkFraming.vhd | 1 |
| 341 | 6 | ClinkUart | protocols | protocols/clink/rtl/ClinkUart.vhd | 1 |
| 342 | 6 | CoaXPressTx | protocols | protocols/coaxpress/core/rtl/CoaXPressTx.vhd | 1 |
| 343 | 6 | HtspRxFifo | protocols | protocols/htsp/core/rtl/HtspRxFifo.vhd | 0 |
| 344 | 6 | Pgp4RxProtocol | protocols | protocols/pgp/pgp4/core/rtl/Pgp4RxProtocol.vhd | 1 |
| 345 | 6 | PgpRxVcFifo | protocols | protocols/pgp/shared/PgpRxVcFifo.vhd | 0 |
| 346 | 6 | PgpTxVcFifo | protocols | protocols/pgp/shared/PgpTxVcFifo.vhd | 0 |
| 347 | 6 | SaltTx | protocols | protocols/salt/rtl/SaltTx.vhd | 1 |
| 348 | 6 | AxiLiteSrpV0 | protocols | protocols/srp/rtl/AxiLiteSrpV0.vhd | 0 |
| 349 | 6 | SsiAxiLiteMaster | protocols | protocols/ssi/rtl/SsiAxiLiteMaster.vhd | 0 |
| 350 | 6 | SsiCmdMaster | protocols | protocols/ssi/rtl/SsiCmdMaster.vhd | 0 |
| 351 | 6 | SsiFifo | protocols | protocols/ssi/rtl/SsiFifo.vhd | 4 |
| 352 | 6 | SsiFrameLimiter | protocols | protocols/ssi/rtl/SsiFrameLimiter.vhd | 1 |
| 353 | 6 | SsiIncrementingTx | protocols | protocols/ssi/rtl/SsiIncrementingTx.vhd | 0 |
| 354 | 6 | SsiInsertSof | protocols | protocols/ssi/rtl/SsiInsertSof.vhd | 2 |
| 355 | 6 | SsiPrbsTx | protocols | protocols/ssi/rtl/SsiPrbsTx.vhd | 1 |
| 356 | 7 | AxiLiteRamSyncStatusVector | axi | axi/axi-lite/rtl/AxiLiteRamSyncStatusVector.vhd | 0 |
| 357 | 7 | AxiStreamMonAxiL | axi | axi/axi-stream/rtl/AxiStreamMonAxiL.vhd | 1 |
| 358 | 7 | AxiStreamDma | axi | axi/dma/rtl/v1/AxiStreamDma.vhd | 0 |
| 359 | 7 | AxiStreamDmaFifo | axi | axi/dma/rtl/v1/AxiStreamDmaFifo.vhd | 0 |
| 360 | 7 | AxiStreamDmaRingWrite | axi | axi/dma/rtl/v1/AxiStreamDmaRingWrite.vhd | 0 |
| 361 | 7 | EthMacRxFifo | ethernet | ethernet/EthMacCore/rtl/EthMacRxFifo.vhd | 1 |
| 362 | 7 | EthMacRxImport | ethernet | ethernet/EthMacCore/rtl/EthMacRxImport.vhd | 1 |
| 363 | 7 | EthMacTxExport | ethernet | ethernet/EthMacCore/rtl/EthMacTxExport.vhd | 1 |
| 364 | 7 | GigEthReg | ethernet | ethernet/GigEthCore/core/rtl/GigEthReg.vhd | 0 |
| 365 | 7 | TenGigEthReg | ethernet | ethernet/TenGigEthCore/core/rtl/TenGigEthReg.vhd | 0 |
| 366 | 7 | UdpEngine | ethernet | ethernet/UdpEngine/rtl/UdpEngine.vhd | 1 |
| 367 | 7 | XauiReg | ethernet | ethernet/XauiCore/core/rtl/XauiReg.vhd | 0 |
| 368 | 7 | ClinkCtrl | protocols | protocols/clink/rtl/ClinkCtrl.vhd | 1 |
| 369 | 7 | CoaXPressAxiL | protocols | protocols/coaxpress/core/rtl/CoaXPressAxiL.vhd | 1 |
| 370 | 7 | CoaXPressRx | protocols | protocols/coaxpress/core/rtl/CoaXPressRx.vhd | 1 |
| 371 | 7 | HtspAxiL | protocols | protocols/htsp/core/rtl/HtspAxiL.vhd | 1 |
| 372 | 7 | HtspTxFifo | protocols | protocols/htsp/core/rtl/HtspTxFifo.vhd | 0 |
| 373 | 7 | JesdRxReg | protocols | protocols/jesd204b/rtl/JesdRxReg.vhd | 1 |
| 374 | 7 | JesdTxReg | protocols | protocols/jesd204b/rtl/JesdTxReg.vhd | 1 |
| 375 | 7 | Pgp2bAxi | protocols | protocols/pgp/pgp2b/core/rtl/Pgp2bAxi.vhd | 0 |
| 376 | 7 | Pgp2fcAxi | protocols | protocols/pgp/pgp2fc/core/rtl/Pgp2fcAxi.vhd | 0 |
| 377 | 7 | Pgp3AxiL | protocols | protocols/pgp/pgp3/core/rtl/Pgp3AxiL.vhd | 1 |
| 378 | 7 | Pgp4AxiL | protocols | protocols/pgp/pgp4/core/rtl/Pgp4AxiL.vhd | 2 |
| 379 | 7 | Pgp4Rx | protocols | protocols/pgp/pgp4/core/rtl/Pgp4Rx.vhd | 2 |
| 380 | 7 | Pgp4RxLiteLowSpeedReg | protocols | protocols/pgp/pgp4/core/rtl/Pgp4RxLiteLowSpeedReg.vhd | 1 |
| 381 | 7 | RssiCore | protocols | protocols/rssi/v1/rtl/RssiCore.vhd | 1 |
| 382 | 7 | SaltRx | protocols | protocols/salt/rtl/SaltRx.vhd | 1 |
| 383 | 7 | SrpV0AxiLite | protocols | protocols/srp/rtl/SrpV0AxiLite.vhd | 0 |
| 384 | 7 | SrpV3AxiLite | protocols | protocols/srp/rtl/SrpV3AxiLite.vhd | 1 |
| 385 | 7 | SrpV3Core | protocols | protocols/srp/rtl/SrpV3Core.vhd | 1 |
| 386 | 7 | SsiPrbsRateGen | protocols | protocols/ssi/rtl/SsiPrbsRateGen.vhd | 0 |
| 387 | 7 | SsiPrbsRx | protocols | protocols/ssi/rtl/SsiPrbsRx.vhd | 0 |
| 388 | 7 | SspLowSpeedDecoderReg | protocols | protocols/ssp/rtl/SspLowSpeedDecoderReg.vhd | 3 |
| 389 | 8 | AxiMonAxiL | axi | axi/axi4/rtl/AxiMonAxiL.vhd | 0 |
| 390 | 8 | EthMacRx | ethernet | ethernet/EthMacCore/rtl/EthMacRx.vhd | 1 |
| 391 | 8 | EthMacTx | ethernet | ethernet/EthMacCore/rtl/EthMacTx.vhd | 1 |
| 392 | 8 | UdpEngineWrapper | ethernet | ethernet/UdpEngine/rtl/UdpEngineWrapper.vhd | 0 |
| 393 | 8 | ClinkTop | protocols | protocols/clink/rtl/ClinkTop.vhd | 0 |
| 394 | 8 | CoaXPressConfig | protocols | protocols/coaxpress/core/rtl/CoaXPressConfig.vhd | 1 |
| 395 | 8 | HtspCore | protocols | protocols/htsp/core/rtl/HtspCore.vhd | 0 |
| 396 | 8 | Jesd204bRx | protocols | protocols/jesd204b/rtl/Jesd204bRx.vhd | 0 |
| 397 | 8 | Jesd204bTx | protocols | protocols/jesd204b/rtl/Jesd204bTx.vhd | 0 |
| 398 | 8 | Pgp3Core | protocols | protocols/pgp/pgp3/core/rtl/Pgp3Core.vhd | 0 |
| 399 | 8 | Pgp4Core | protocols | protocols/pgp/pgp4/core/rtl/Pgp4Core.vhd | 0 |
| 400 | 8 | Pgp4CoreLite | protocols | protocols/pgp/pgp4/core/rtl/Pgp4CoreLite.vhd | 1 |
| 401 | 8 | RssiCoreWrapper | protocols | protocols/rssi/v1/rtl/RssiCoreWrapper.vhd | 0 |
| 402 | 8 | SaltCore | protocols | protocols/salt/rtl/SaltCore.vhd | 0 |
| 403 | 8 | SrpV3Axi | protocols | protocols/srp/rtl/SrpV3Axi.vhd | 1 |
| 404 | 8 | SspLowSpeedDecoder10b12bWrapper | protocols | protocols/ssp/rtl/SspLowSpeedDecoder10b12bWrapper.vhd | 0 |
| 405 | 8 | SspLowSpeedDecoder12b14bWrapper | protocols | protocols/ssp/rtl/SspLowSpeedDecoder12b14bWrapper.vhd | 0 |
| 406 | 8 | SspLowSpeedDecoder8b10bWrapper | protocols | protocols/ssp/rtl/SspLowSpeedDecoder8b10bWrapper.vhd | 0 |
| 407 | 9 | EthMacTop | ethernet | ethernet/EthMacCore/rtl/EthMacTop.vhd | 0 |
| 408 | 9 | CoaXPressCore | protocols | protocols/coaxpress/core/rtl/CoaXPressCore.vhd | 0 |
| 409 | 9 | Pgp4RxLiteLowSpeedLane | protocols | protocols/pgp/pgp4/core/rtl/Pgp4RxLiteLowSpeedLane.vhd | 1 |
| 410 | 9 | SrpV3AxiLiteFull | protocols | protocols/srp/rtl/SrpV3AxiLiteFull.vhd | 0 |
| 411 | 10 | Pgp4LiteRxLowSpeed | protocols | protocols/pgp/pgp4/core/rtl/Pgp4RxLiteLowSpeed.vhd | 0 |
