# Ethernet PTP endpoint

This area implements a fixed-source, two-step Layer-2 E2E PTP TimeReceiver.
`EthMacPtpEndpoint` combines the existing MAC with passive timestamp/validation
paths and an autonomous PHC/servo. Software configures and observes it; software
is not in the timing loop. See the [implementation contract](../../docs/plans/ethernet-ptp/autonomous-endpoint.md)
for current validation, register ABI, numerical limits and remaining qualification.

- `rtl/PtpPkg.vhd`: shared time, capture, configuration, command and measurement records.
- `PtpRxTimestampAdapter`, `PtpRxFrontend`, `PtpTxTimestampTap`: physical capture,
  bounded FCS/message validation and actual TX wire completion.
- `PtpPort`, `PtpTxLedger`, `PtpE2e`: fixed-source policy, message association,
  persistent TX reservations, rate estimation, request building and E2E arithmetic.
- `PtpPhc`, `PtpMath`, `PtpServo`: continuously advancing clock, checked serialized
  arithmetic, delay filtering, acquisition, PI control and holdover.
- `PtpPhc`, `PtpPort`, `PtpServo` each contain their own AXI-Lite registers,
  configuration and snapshots. PHC command arbitration is inside `PtpPhc`.
- `PtpMeasurementMasterType`/`PtpMeasurementSlaveType` and `PtpPortStatusType`
  in `PtpPkg`: directional measurement transfer and grouped port diagnostics.
- `PtpReg`, `PtpEndpoint`: common commit/snapshot coordination, IRQ and the
  standard SURF crossbar. [ABI v2](../../docs/plans/ethernet-ptp/register-map.md)
  has four 1 KiB banks at the aligned `AXIL_BASE_ADDR_G`.
- `PtpPrimaryGuard`, `EthMacPtpEndpoint`: exclusive PTP TX ownership and common-clock
  GMII/XGMII composition, using existing SURF stream adapters.
- `PtpPhcRead`: optional, separately instantiated coherent snapshot CDC mailbox.
- `wrappers/`: thin flattened simulation adapters. Executable stimulus and
  independent models live in the [cocotb suite](../../tests/ethernet/PtpCore/README.md).
- [PyRogue map](../../python/surf/ethernet/ptp/_PtpEndpoint.py): register ABI v2 with Phc/Port/Servo child devices.

Use one continuously running clock: full-rate GMII at 125 MHz or XGMII at
156.25 MHz. GMII 10/100 operation is unsupported. The primary MAC stream uses
`EMAC_AXIS_CONFIG_C` and a full first beat with SSI SOF. Untagged EtherType
`0x88F7` is reserved for the endpoint; other primary traffic passes through.
Latency calibration is signed Q16 local-PHC nanoseconds in elaboration-time
`INGRESS_LATENCY_G`/`EGRESS_LATENCY_G` generics, readable in software.

System reset must reset the entire MAC/endpoint TX pipeline. A port restart
preserves PHC time and unknown physical TX reservations; an AXI-only reset also
preserves accepted commands. Configure a defensible `PACKET_LIFETIME_G` before
integration: sequence reuse relies on that finite network-lifetime bound.
RX records transfer only when valid, ready and no abort; consumers give abort
priority. These records are not themselves a CDC interface.

Build manifests load `rtl/` and `wrappers/`. Run `make MODULES="$PWD" import`
before the focused [tests](../../tests/ethernet/PtpCore/README.md). Device timing,
resources, physical CDC, GT integration and hardware latency calibration remain
open. The broader [plan](../../docs/plans/ethernet-ptp/README.md) covers later
application timing and FPGA-family integration. See the parent
[Ethernet index](../README.md) for neighboring cores.

The [RTL readability review](../../docs/plans/ethernet-ptp/rtl-readability.md)
tracks the current flow/interface cleanup. Regressions remain stopped pending
maintainer approval of the VHDL; build-only smoke checks are permitted.
