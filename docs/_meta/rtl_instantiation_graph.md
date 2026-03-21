# SURF RTL Instantiation Graph

## Scope
- Scan dirs: `base, axi, protocols, ethernet, devices, xilinx`
- Included files: VHDL files outside `tb/`, `build/`, and `.venv/` paths.
- Direct entity instantiations are parsed explicitly.
- Component-style instantiations are included only when the instantiated token matches a known entity name inside an architecture body.
- Packages are not graph nodes.

## Summary
- Entities: `679`
- Edges: `1317`
- Topological layers: `12`
- Duplicate entity names: `51`

## Top Instantiated Entities
| entity | instantiated_by_count | instantiates_count | path |
| --- | --- | --- | --- |
| RstSync | 75 | 1 | base/sync/rtl/RstSync.vhd |
| Synchronizer | 73 | 0 | base/sync/rtl/Synchronizer.vhd |
| SynchronizerVector | 41 | 0 | base/sync/rtl/SynchronizerVector.vhd |
| AxiStreamFifoV2 | 40 | 5 | axi/axi-stream/rtl/AxiStreamFifoV2.vhd |
| AxiStreamPipeline | 37 | 0 | axi/axi-stream/rtl/AxiStreamPipeline.vhd |
| SynchronizerFifo | 37 | 1 | base/sync/rtl/SynchronizerFifo.vhd |
| PwrUpRst | 36 | 1 | base/general/rtl/PwrUpRst.vhd |
| AxiLiteCrossbar | 29 | 0 | axi/axi-lite/rtl/AxiLiteCrossbar.vhd |
| SynchronizerOneShot | 28 | 2 | base/sync/rtl/SynchronizerOneShot.vhd |
| AxiLiteToDrp | 27 | 1 | axi/bridge/rtl/AxiLiteToDrp.vhd |
| AxiLiteAsync | 21 | 1 | axi/axi-lite/rtl/AxiLiteAsync.vhd |
| Fifo | 17 | 4 | base/fifo/rtl/Fifo.vhd |
| SynchronizerEdge | 16 | 1 | base/sync/rtl/SynchronizerEdge.vhd |
| RstPipeline | 15 | 0 | base/general/rtl/RstPipeline.vhd |
| SyncStatusVector | 15 | 2 | base/sync/rtl/SyncStatusVector.vhd |
| EthMacTop | 14 | 5 | ethernet/EthMacCore/rtl/EthMacTop.vhd |
| IoBufWrapper | 14 | 0 | xilinx/dummy/IoBufWrapperDummy.vhd |
| AxiLiteMaster | 13 | 0 | axi/axi-lite/rtl/AxiLiteMaster.vhd |
| AxiStreamMux | 13 | 1 | axi/axi-stream/rtl/AxiStreamMux.vhd |
| AxiStreamDeMux | 12 | 1 | axi/axi-stream/rtl/AxiStreamDeMux.vhd |

## Top Assemblers
| entity | instantiates_count | instantiated_by_count | path |
| --- | --- | --- | --- |
| RssiCore | 13 | 1 | protocols/rssi/v1/rtl/RssiCore.vhd |
| EthMacRxRoCEv2 | 10 | 1 | ethernet/RoCEv2/rtl/EthMacRxRoCEv2.vhd |
| SugoiManagerCore | 10 | 0 | protocols/sugoi/rtl/SugoiManagerCore.vhd |
| Ad9681Readout | 8 | 0 | devices/AnalogDevices/ad9681/7Series/rtl/Ad9681Readout.vhd |
| CoaXPressAxiL | 8 | 1 | protocols/coaxpress/core/rtl/CoaXPressAxiL.vhd |
| EthMacTxRoCEv2 | 8 | 1 | ethernet/RoCEv2/rtl/EthMacTxRoCEv2.vhd |
| Gth7Core | 8 | 2 | xilinx/7Series/gth7/rtl/Gth7Core.vhd |
| RssiCoreWrapper | 8 | 0 | protocols/rssi/v1/rtl/RssiCoreWrapper.vhd |
| Ad9249ReadoutGroup | 7 | 0 | devices/AnalogDevices/ad9249/7Series/rtl/Ad9249ReadoutGroup.vhd |
| Ad9249ReadoutGroup2 | 7 | 0 | devices/AnalogDevices/ad9249/UltraScale/rtl/Ad9249ReadoutGroup2.vhd |
| AxiRingBuffer | 7 | 0 | axi/axi4/rtl/AxiRingBuffer.vhd |
| AxiStreamRingBuffer | 7 | 0 | axi/axi-stream/rtl/AxiStreamRingBuffer.vhd |
| ClinkTop | 7 | 0 | protocols/clink/rtl/ClinkTop.vhd |
| CoaXPressRx | 7 | 1 | protocols/coaxpress/core/rtl/CoaXPressRx.vhd |
| FifoAsync | 7 | 8 | base/fifo/rtl/inferred/FifoAsync.vhd |
| GLinkGtx7Core | 7 | 1 | protocols/glink/gtx7/rtl/GLinkGtx7Core.vhd |
| Gtp7Core | 7 | 4 | xilinx/7Series/gtp7/rtl/Gtp7Core.vhd |
| IpV4Engine | 7 | 1 | ethernet/IpV4Engine/rtl/IpV4Engine.vhd |
| Jesd204bRx | 7 | 1 | protocols/jesd204b/rtl/Jesd204bRx.vhd |
| Jesd204bTx | 7 | 1 | protocols/jesd204b/rtl/Jesd204bTx.vhd |

## Top Leaf Entities
| entity | instantiated_by_count | path |
| --- | --- | --- |
| Synchronizer | 73 | base/sync/rtl/Synchronizer.vhd |
| SynchronizerVector | 41 | base/sync/rtl/SynchronizerVector.vhd |
| AxiStreamPipeline | 37 | axi/axi-stream/rtl/AxiStreamPipeline.vhd |
| AxiLiteCrossbar | 29 | axi/axi-lite/rtl/AxiLiteCrossbar.vhd |
| RstPipeline | 15 | base/general/rtl/RstPipeline.vhd |
| IoBufWrapper | 14 | xilinx/dummy/IoBufWrapperDummy.vhd |
| AxiLiteMaster | 13 | axi/axi-lite/rtl/AxiLiteMaster.vhd |
| Decoder8b10b | 10 | protocols/line-codes/rtl/Decoder8b10b.vhd |
| SimpleDualPortRam | 9 | base/ram/inferred/SimpleDualPortRam.vhd |
| Crc32Parallel | 7 | base/crc/rtl/Crc32Parallel.vhd |
| SimpleDualPortRamXpm | 7 | base/ram/dummy/SimpleDualPortRamXpmDummy.vhd |
| SpiMaster | 7 | protocols/spi/rtl/SpiMaster.vhd |
| Gearbox | 6 | base/general/rtl/Gearbox.vhd |
| SelectIoRxGearboxAligner | 6 | xilinx/general/rtl/SelectIoRxGearboxAligner.vhd |
| ClkOutBufDiff | 5 | xilinx/dummy/ClkOutBufDiffDummy.vhd |
| FifoOutputPipeline | 5 | base/fifo/rtl/FifoOutputPipeline.vhd |
| Pgp3RxGearboxAligner | 5 | protocols/pgp/pgp3/core/rtl/Pgp3RxGearboxAligner.vhd |
| Scrambler | 5 | base/general/rtl/Scrambler.vhd |
| CRC32Rtl | 4 | base/crc/rtl/CRC32Rtl.vhd |
| Encoder8b10b | 4 | protocols/line-codes/rtl/Encoder8b10b.vhd |

## Base Bottom-Up Candidates
| entity | instantiated_by_count | instantiates_count | path |
| --- | --- | --- | --- |
| Synchronizer | 73 | 0 | base/sync/rtl/Synchronizer.vhd |
| SynchronizerVector | 41 | 0 | base/sync/rtl/SynchronizerVector.vhd |
| RstPipeline | 15 | 0 | base/general/rtl/RstPipeline.vhd |
| SimpleDualPortRam | 9 | 0 | base/ram/inferred/SimpleDualPortRam.vhd |
| Crc32Parallel | 7 | 0 | base/crc/rtl/Crc32Parallel.vhd |
| SimpleDualPortRamXpm | 7 | 0 | base/ram/dummy/SimpleDualPortRamXpmDummy.vhd |
| Gearbox | 6 | 0 | base/general/rtl/Gearbox.vhd |
| FifoOutputPipeline | 5 | 0 | base/fifo/rtl/FifoOutputPipeline.vhd |
| Scrambler | 5 | 0 | base/general/rtl/Scrambler.vhd |
| CRC32Rtl | 4 | 0 | base/crc/rtl/CRC32Rtl.vhd |
| SimpleDualPortRamAlteraMf | 3 | 0 | base/ram/dummy/SimpleDualPortRamAlteraMfDummy.vhd |
| SlvDelay | 3 | 0 | base/delay/rtl/SlvDelay.vhd |
| TrueDualPortRam | 3 | 0 | base/ram/inferred/TrueDualPortRam.vhd |
| Crc32 | 2 | 0 | base/crc/rtl/Crc32.vhd |
| FifoRdFsm | 2 | 0 | base/fifo/rtl/inferred/FifoRdFsm.vhd |
| FifoWrFsm | 2 | 0 | base/fifo/rtl/inferred/FifoWrFsm.vhd |
| LutRam | 2 | 0 | base/ram/inferred/LutRam.vhd |
| TrueDualPortRamAlteraMf | 2 | 0 | base/ram/dummy/TrueDualPortRamXpmAlteraMfDummy.vhd |
| TrueDualPortRamXpm | 2 | 0 | base/ram/dummy/TrueDualPortRamXpmDummy.vhd |
| Arbiter | 1 | 0 | base/general/rtl/Arbiter.vhd |

## Duplicate Entity Names
- `Ad9249Deserializer`
  - `devices/AnalogDevices/ad9249/7Series/rtl/Ad9249Deserializer.vhd`
  - `devices/AnalogDevices/ad9249/UltraScale/rtl/Ad9249Deserializer.vhd`
- `Ad9249ReadoutGroup`
  - `devices/AnalogDevices/ad9249/7Series/rtl/Ad9249ReadoutGroup.vhd`
  - `devices/AnalogDevices/ad9249/UltraScale/rtl/Ad9249ReadoutGroup.vhd`
- `ClinkDataClk`
  - `protocols/clink/7Series/ClinkDataClk.vhd`
  - `protocols/clink/UltraScale/ClinkDataClk.vhd`
- `ClinkDataShift`
  - `protocols/clink/7Series/ClinkDataShift.vhd`
  - `protocols/clink/UltraScale/ClinkDataShift.vhd`
- `ClkOutBufDiff`
  - `xilinx/dummy/ClkOutBufDiffDummy.vhd`
  - `xilinx/general/rtl/ClkOutBufDiff.vhd`
- `ClkOutBufSingle`
  - `xilinx/dummy/ClkOutBufSingleDummy.vhd`
  - `xilinx/general/rtl/ClkOutBufSingle.vhd`
- `ClockManagerUltraScale`
  - `xilinx/UltraScale/clocking/rtl/ClockManagerUltraScale.vhd`
  - `xilinx/UltraScale+/clocking/rtl/ClockManagerUltraScale.vhd`
- `CoaXPressOverFiberGthUsIpWrapper`
  - `protocols/coaxpress/gthUs/rtl/CoaXPressOverFiberGthUsIpWrapper.vhd`
  - `protocols/coaxpress/gthUs+/rtl/CoaXPressOverFiberGthUsIpWrapper.vhd`
- `CoaxpressOverFiberGthUs`
  - `protocols/coaxpress/gthUs/rtl/CoaxpressOverFiberGthUs.vhd`
  - `protocols/coaxpress/gthUs+/rtl/CoaxpressOverFiberGthUs.vhd`
- `CoaxpressOverFiberGthUsQpll`
  - `protocols/coaxpress/gthUs/rtl/CoaxpressOverFiberGthUsQpll.vhd`
  - `protocols/coaxpress/gthUs+/rtl/CoaxpressOverFiberGthUsQpll.vhd`
- `DS2411Core`
  - `devices/Maxim/dummy/DS2411CoreDummy.vhd`
  - `devices/Maxim/rtl/DS2411Core.vhd`
- `DeviceDna`
  - `xilinx/dummy/DeviceDnaDummy.vhd`
  - `xilinx/general/rtl/DeviceDna.vhd`
- `FifoAlteraMf`
  - `base/fifo/rtl/altera/FifoAlteraMf.vhd`
  - `base/fifo/rtl/dummy/FifoAlteraMfDummy.vhd`
- `FifoXpm`
  - `base/fifo/rtl/dummy/FifoXpmDummy.vhd`
  - `base/fifo/rtl/xilinx/FifoXpm.vhd`
- `GigEthGthUltraScale`
  - `ethernet/GigEthCore/gthUltraScale/rtl/GigEthGthUltraScale.vhd`
  - `ethernet/GigEthCore/gthUltraScale+/rtl/GigEthGthUltraScale.vhd`
- `GigEthGthUltraScaleWrapper`
  - `ethernet/GigEthCore/gthUltraScale/rtl/GigEthGthUltraScaleWrapper.vhd`
  - `ethernet/GigEthCore/gthUltraScale+/rtl/GigEthGthUltraScaleWrapper.vhd`
- `GthUltraScaleQuadPll`
  - `xilinx/UltraScale/gthUs/rtl/GthUltraScaleQuadPll.vhd`
  - `xilinx/UltraScale+/gthUs+/rtl/GthUltraScaleQuadPll.vhd`
- `Idelaye3Wrapper`
  - `xilinx/7Series/dummy/Idelaye3WrapperDummy.vhd`
  - `xilinx/UltraScale/general/rtl/Idelaye3Wrapper.vhd`
- `InputBufferReg`
  - `xilinx/7Series/general/rtl/InputBufferReg.vhd`
  - `xilinx/UltraScale/general/rtl/InputBufferReg.vhd`
- `IoBufWrapper`
  - `xilinx/dummy/IoBufWrapperDummy.vhd`
  - `xilinx/general/rtl/IoBufWrapper.vhd`
- `Iprog`
  - `xilinx/dummy/IprogDummy.vhd`
  - `xilinx/general/rtl/Iprog.vhd`
- `MicroblazeBasicCoreWrapper`
  - `xilinx/general/microblaze/bypass/MicroblazeBasicCoreWrapper.vhd`
  - `xilinx/general/microblaze/generate/MicroblazeBasicCoreWrapper.vhd`
- `Odelaye3Wrapper`
  - `xilinx/7Series/dummy/Odelaye3WrapperDummy.vhd`
  - `xilinx/UltraScale/general/rtl/Odelaye3Wrapper.vhd`
- `OutputBufferReg`
  - `xilinx/7Series/general/rtl/OutputBufferReg.vhd`
  - `xilinx/UltraScale/general/rtl/OutputBufferReg.vhd`
  - `xilinx/dummy/OutputBufferRegDummy.vhd`
- `Pgp2bGthUltra`
  - `protocols/pgp/pgp2b/gthUltraScale/rtl/Pgp2bGthUltra.vhd`
  - `protocols/pgp/pgp2b/gthUltraScale+/rtl/Pgp2bGthUltra.vhd`
- `Pgp3GthUs`
  - `protocols/pgp/pgp3/gthUs/rtl/Pgp3GthUs.vhd`
  - `protocols/pgp/pgp3/gthUs+/rtl/Pgp3GthUs.vhd`
- `Pgp3GthUsIpWrapper`
  - `protocols/pgp/pgp3/gthUs/rtl/Pgp3GthUsIpWrapper.vhd`
  - `protocols/pgp/pgp3/gthUs+/rtl/Pgp3GthUsIpWrapper.vhd`
- `Pgp3GthUsQpll`
  - `protocols/pgp/pgp3/gthUs/rtl/Pgp3GthUsQpll.vhd`
  - `protocols/pgp/pgp3/gthUs+/rtl/Pgp3GthUsQpll.vhd`
- `Pgp3GthUsWrapper`
  - `protocols/pgp/pgp3/gthUs/rtl/Pgp3GthUsWrapper.vhd`
  - `protocols/pgp/pgp3/gthUs+/rtl/Pgp3GthUsWrapper.vhd`
- `Pgp4GthUs`
  - `protocols/pgp/pgp4/gthUs/rtl/Pgp4GthUs.vhd`
  - `protocols/pgp/pgp4/gthUs+/rtl/Pgp4GthUs.vhd`
- `Pgp4GthUsWrapper`
  - `protocols/pgp/pgp4/gthUs/rtl/Pgp4GthUsWrapper.vhd`
  - `protocols/pgp/pgp4/gthUs+/rtl/Pgp4GthUsWrapper.vhd`
- `PgpGthCoreWrapper`
  - `protocols/pgp/pgp2b/gthUltraScale/rtl/PgpGthCoreWrapper.vhd`
  - `protocols/pgp/pgp2b/gthUltraScale+/rtl/PgpGthCoreWrapper.vhd`
- `RogueSideBand`
  - `axi/simlink/ghdl/RogueSideBand.vhd`
  - `axi/simlink/sim/RogueSideBand.vhd`
- `RogueTcpMemory`
  - `axi/simlink/ghdl/RogueTcpMemory.vhd`
  - `axi/simlink/sim/RogueTcpMemory.vhd`
- `RogueTcpStream`
  - `axi/simlink/ghdl/RogueTcpStream.vhd`
  - `axi/simlink/sim/RogueTcpStream.vhd`
- `SaltRxDeser`
  - `protocols/salt/rtl/7Series/SaltRxDeser.vhd`
  - `protocols/salt/rtl/UltraScale/SaltRxDeser.vhd`
- `SaltTxSer`
  - `protocols/salt/rtl/7Series/SaltTxSer.vhd`
  - `protocols/salt/rtl/UltraScale/SaltTxSer.vhd`
- `SimpleDualPortRamXpm`
  - `base/ram/dummy/SimpleDualPortRamXpmDummy.vhd`
  - `base/ram/xilinx/SimpleDualPortRamXpm.vhd`
- `SinglePortRamPrimitive`
  - `base/ram/dummy/SinglePortRamPrimitiveDummy.vhd`
  - `base/ram/xilinx/SinglePortRamPrimitive.vhd`
- `Srl16Delay`
  - `xilinx/dummy/Srl16DelayDummy.vhd`
  - `xilinx/general/rtl/Srl16Delay.vhd`
- `SugoiManagerRx7Series`
  - `protocols/sugoi/rtl/7Series/SugoiManagerRx7Series.vhd`
  - `protocols/sugoi/rtl/dummy/SugoiManagerRx7SeriesDummy.vhd`
- `SugoiManagerRxUltrascale`
  - `protocols/sugoi/rtl/UltraScale/SugoiManagerRxUltrascale.vhd`
  - `protocols/sugoi/rtl/dummy/SugoiManagerRxUltrascaleDummy.vhd`
- `TenGigEthGthUltraScale`
  - `ethernet/TenGigEthCore/gthUltraScale/rtl/TenGigEthGthUltraScale.vhd`
  - `ethernet/TenGigEthCore/gthUltraScale+/rtl/TenGigEthGthUltraScale.vhd`
- `TenGigEthGthUltraScaleClk`
  - `ethernet/TenGigEthCore/gthUltraScale/rtl/TenGigEthGthUltraScaleClk.vhd`
  - `ethernet/TenGigEthCore/gthUltraScale+/rtl/TenGigEthGthUltraScaleClk.vhd`
- `TenGigEthGthUltraScaleRst`
  - `ethernet/TenGigEthCore/gthUltraScale/rtl/TenGigEthGthUltraScaleRst.vhd`
  - `ethernet/TenGigEthCore/gthUltraScale+/rtl/TenGigEthGthUltraScaleRst.vhd`
- `TenGigEthGthUltraScaleWrapper`
  - `ethernet/TenGigEthCore/gthUltraScale/rtl/TenGigEthGthUltraScaleWrapper.vhd`
  - `ethernet/TenGigEthCore/gthUltraScale+/rtl/TenGigEthGthUltraScaleWrapper.vhd`
- `TrueDualPortRamXpm`
  - `base/ram/dummy/TrueDualPortRamXpmDummy.vhd`
  - `base/ram/xilinx/TrueDualPortRamXpm.vhd`
- `UdpDebugBridge`
  - `xilinx/xvc-udp/dcp/7Series/Impl/images/UdpDebugBridge_stub.vhd`
  - `xilinx/xvc-udp/dcp/7Series/Stub/images/UdpDebugBridge_stub.vhd`
  - `xilinx/xvc-udp/dcp/UltraScale/Impl/images/UdpDebugBridge_stub.vhd`
  - `xilinx/xvc-udp/dcp/UltraScale/Stub/images/UdpDebugBridge_stub.vhd`
  - `xilinx/xvc-udp/dcp/core/UdpDebugBridgeImplWrapper.vhd`
  - `xilinx/xvc-udp/dcp/core/UdpDebugBridgeStubWrapper.vhd`
- `UdpDebugBridgeWrapper`
  - `xilinx/xvc-udp/dcp/core/UdpDebugBridgeWrapper.vhd`
  - `xilinx/xvc-udp/rtl/UdpDebugBridgeWrapper.vhd`
- `XauiGthUltraScale`
  - `ethernet/XauiCore/gthUltraScale/rtl/XauiGthUltraScale.vhd`
  - `ethernet/XauiCore/gthUltraScale+/rtl/XauiGthUltraScale.vhd`
- `XauiGthUltraScaleWrapper`
  - `ethernet/XauiCore/gthUltraScale/rtl/XauiGthUltraScaleWrapper.vhd`
  - `ethernet/XauiCore/gthUltraScale+/rtl/XauiGthUltraScaleWrapper.vhd`
