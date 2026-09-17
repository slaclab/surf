# Ethernet PTP endpoint

This area implements a fixed-source, two-step Layer-2 E2E PTP TimeReceiver.
`EthMacPtpEndpoint` combines the existing MAC with passive timestamp/validation
paths and an autonomous PHC/servo. Software configures and observes it; software
is not in the timing loop. See the [implementation contract](../../docs/plans/ethernet-ptp/autonomous-endpoint.md)
for current validation, register ABI, numerical limits and remaining qualification.

- `rtl/PtpPkg.vhd`: shared time, capture, configuration, command and measurement records.
  It also owns wire encodings/lengths, message-body accessors,
  fixed-point format definitions and distinct nanoseconds/ppb conversion scales.
  These describe fixed interface contracts rather than configurable precision.
  Table/filter depths and implementation policies remain local to their owners.
- `PtpRxTimestampAdapter`, `PtpRxFrontend`, `PtpTxTimestampTap`: physical capture,
  bounded FCS/message validation and actual TX wire completion.
- `PtpPort`, `PtpTxLedger`, `PtpE2e`: fixed-source policy, message association,
  persistent TX reservations, rate estimation, request building and E2E arithmetic.
- `PtpPhc`, `PtpMath`, `PtpServo`: continuously advancing clock, checked serialized
  arithmetic, delay filtering, acquisition, PI control and holdover.
- `PtpPhc`, `PtpPort`, `PtpServo` each contain their own AXI-Lite registers,
  configuration and snapshots. PHC command arbitration is inside `PtpPhc`.
  Servo command payload, valid, cancellation and expiry are registered. The
  PHC's separate acceptance/commit edges allow cancellation registered on an
  acceptance edge to reject the pending command before it takes effect.
  Expiry assertion and release reach the PHC one clock after the servo samples
  the condition; measurement readiness remains combinational backpressure.
  Servo status and RX counters are authoritative registered records, shared
  by their output ports and local state updates.
- Configuration defaults live in `PTP_PORT_CONFIG_INIT_C` and
  `PTP_SERVO_CONFIG_INIT_C`, with units and derivations beside each value.
  `PtpTxLedger.config` accepts the port's active `PtpPortConfigType` directly;
  the former aggregate `PtpConfigType` and `PTP_CONFIG_INIT_C` are removed.
  The servo receives port-owned shared limits through `PtpSharedConfigType`.
- `PtpMeasurementMasterType`/`PtpMeasurementSlaveType` in `PtpPkg`: directional
  measurement transfer. `PtpPortLifecycleType` carries immediate command abort
  and MAC-change restart; `PtpPortStatusType` carries registered diagnostics.
  The port's live record owns counters, Announce metadata and the completed
  exchange directly. Local AXI snapshots freeze pre-edge state separately.
  Summary validity and ledger reporting are clocked observations; protocol
  admission and cancellation retain their current-cycle checks.
- `PtpReg`, `PtpEndpoint`: common commit/snapshot coordination, IRQ and the
  standard SURF crossbar. [development register map](../../docs/plans/ethernet-ptp/register-map.md)
  has four 4 KiB banks in a 16 KiB-aligned window at `AXIL_BASE_ADDR_G`.
  Port and servo capture candidate settings and their validation votes together
  on prepare; later shadow writes cannot change either for that commit.
  Prepare/apply/busy and IRQ are registered from resolved next state, preserving
  the existing commit edges. System reset resets the coordinator and every bank.
- `PtpPrimaryGuard`, `EthMacPtpEndpoint`: exclusive PTP TX ownership and common-clock
  GMII/XGMII composition, using existing SURF stream adapters.
- `PtpPhcRead`: optional, separately instantiated coherent snapshot CDC mailbox.
- `wrappers/`: thin flattened simulation adapters. Executable stimulus and
  independent models live in the [cocotb suite](../../tests/ethernet/PtpCore/README.md).
- [PyRogue map](../../python/surf/ethernet/ptp/_PtpEndpoint.py): development register map with Phc/Port/Servo child devices.

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

Arithmetic results (`PtpMath`, `PtpE2e`) and ledger samples also have registered
valid outputs. Cancellation does not lower valid between clock edges: a transfer
requires valid and ready with the shared cancel/restart low and system reset
inactive. Both producer and consumer give cancellation priority at the edge.
RX overflow, port lifecycle and PHC capture invalidation remain immediate;
snapshot capture is qualified by that same capture invalidation at every bank.

Build manifests load `rtl/` and `wrappers/`. Run `make MODULES="$PWD" import`
before the focused [tests](../../tests/ethernet/PtpCore/README.md). Device timing,
resources, physical CDC, GT integration and hardware latency calibration remain
open. The broader [plan](../../docs/plans/ethernet-ptp/README.md) covers later
application timing and FPGA-family integration. See the parent
[Ethernet index](../README.md) for neighboring cores.

The shared [SURF VHDL conventions](../../docs/vhdl-conventions.md) apply to these
modules. The [PTP supplement](../../docs/plans/ethernet-ptp/rtl-readability.md)
documents the local timing contracts. See
[current validation](../../docs/plans/ethernet-ptp/README.md#current-validation)
for build results and the maintainer VHDL approval gate on regressions.
