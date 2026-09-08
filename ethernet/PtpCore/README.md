# PTP receive slice

This area contains the first synthesizable RX slice of the
[Ethernet PTP plan](../../docs/plans/ethernet-ptp/README.md). It is not yet a
complete PTP endpoint or a qualified timing source.

- `rtl/PtpPkg.vhd`: receive capture/message records, packing, and calibrated
  timestamp arithmetic. The package currently defines only the RX subset.
- `rtl/PtpRxTimestampAdapter.vhd`: passive 1G GMII or 10G XGMII framing,
  selected by `PHY_TYPE_G`; captures time with the first destination-MAC byte.
- `rtl/PtpRxFrontend.vhd`: parallel CRC, bounded structural decode, and a
  configurable queue of complete decoded-message/capture records.
- `wrappers/PtpRxFrontendWrapper.vhd`: flattened simulation access to either
  physical input or the normalized frontend boundary.

All RX logic runs in one continuously running clock domain. Supply canonical
PHC seconds/nanoseconds/Q32 fraction and the active Q32 nanoseconds-per-cycle
increment at the physical sampling edge. GMII requires one byte every clock;
10/100 clock-enable operation is not supported. Calibration is a signed Q16
nanosecond **elaboration-time** `INGRESS_LATENCY_G` in this slice. Runtime
calibration and PHC generation orchestration remain endpoint work. Tick/phase
provenance describes the uncalibrated MAC/PCS message point.

Normalized bytes use SURF AXI Stream/SSI types, eight-byte configuration,
contiguous low-byte `TKEEP`, and no backpressure. FCS bytes are included; an
empty final beat is supported. The capture sidecar belongs to SOF and shares
the adapter's register/reset path. The frontend accepts untagged PTP v2.0/v2.1
Sync, Follow_Up, Delay_Resp, and Announce, with frames bounded to 64–1518 bytes
including FCS. Destination/source/domain, flag, timestamp-field, and profile
policy belong to the future `PtpPort`.

The output transfer condition is `messageValid && messageReady && !rxAbort`.
Flush, generation change, or full-before-edge overflow suppresses transfer;
consumers must give abort priority over committing protocol state. System reset
resets the epoch counter; logical flush advances it. Coordinate reset with all
consumers before restarting admission. The interface is not a CDC mechanism.

The [tests](../../tests/ethernet/PtpCore/README.md) compare every normalized
cycle against the reference model and run the RX RTL beside the real MAC under
CRC/FIFO loss. The [implementation record](../../docs/plans/ethernet-ptp/rx-rtl-proof.md)
tracks verification and remaining timing/resource qualification.

See the parent [Ethernet index](../README.md) for neighboring cores.
