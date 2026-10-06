# Ethernet PTP endpoint

This area implements a fixed-source Layer-2 E2E PTP TimeReceiver with one-step
and two-step Sync reception.
`EthMacPtpEndpoint` combines the existing MAC with passive timestamp/validation
paths and an autonomous PHC/servo. Software configures and observes it; software
is not in the timing loop. See the [implementation contract](../../docs/plans/ethernet-ptp/autonomous-endpoint.md)
for current validation, register ABI, numerical limits and remaining qualification.

Sync flags select the receive mode per message: exactly `0x0000` uses the Sync
origin timestamp and correction; exactly `0x0200` waits for Follow_Up and uses
its timestamp plus both signed corrections. Both use the same capture, rate
estimator, history and E2E path. No software mode switch or register change is
required. Mixed-mode collisions follow the conservative
[association policy](../../docs/plans/ethernet-ptp/autonomous-endpoint.md#port-policy-and-numerical-envelope).
One-step reception is implemented but awaits behavioral verification under the
[one-step handoff](../../docs/plans/ethernet-ptp/one-step.md). One-step transmit
insertion remains outside scope.

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
  measurement transfer. `PtpPortLifecycleType` carries registered command abort
  and MAC-change restart; `PtpPortStatusType` carries registered diagnostics.
  The port's live record owns counters, Announce metadata and the completed
  exchange directly. Local AXI snapshots freeze pre-edge state separately.
  Summary validity, ledger reporting, measurement and lifecycle outputs are
  registered. Local admission checks reject work before publication; consumers
  act on a published cancellation on the following edge.
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
- `GigEthPtp`: common 1G Ethernet management, MAC/PTP composition and one
  AXI-Lite crossing before register fanout. The single-lane
  [UltraScale GTH](gthUltraScale/rtl/GigEthGthUltraScalePtp.vhd) and
  [UltraScale+ GTY](gtyUltraScale+/rtl/GigEthGtyUltraScalePlusPtp.vhd)
  compositions live here beside the common PTP code; their reusable PHY-only
  adapters live in [GigEthCore](../GigEthCore/README.md).
- `wrappers/`: thin flattened simulation adapters. Executable stimulus and
  independent models live in the [cocotb suite](../../tests/ethernet/PtpCore/README.md).
- [PyRogue map](../../python/surf/ethernet/ptp/_PtpEndpoint.py): development register map with Phc/Port/Servo child devices.

Use one continuously running clock: full-rate GMII at 125 MHz or XGMII at
156.25 MHz. `EthMacPtpEndpoint` asserts that `CLK_FREQ_G` matches the selected
`PHY_TYPE_G`; set both generics when selecting GMII. GMII 10/100 operation is
unsupported. `PtpTxLedger` supports depths 1 through 255 so its eight-bit
occupancy and unresolved counts remain representable. The primary MAC stream uses
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
RX head selection, overflow, port lifecycle and measurement outputs are
registered. A cause detected at edge N is consumed at N+1; already committed
work is not retroactively revoked. The endpoint registers restart/flush assembly
as another hop. PHC SET/PHASE admission announces capture inhibition before the
following commit edge, including conservative inhibition of rejected commands.

Port-to-ledger requests and complete E2E operands are registered. TX begins only
after a reservation handshake and then survives logical restart. E2E owns its
frozen exchange through result consumption. Ledger response acceptance returns
one cycle after submission; the port retains the associated response metadata.
Snapshots issue a registered capture/sequence broadcast; every bank samples
pre-edge state and the coordinator completes on the next edge. Issued snapshots
are not withdrawn by later invalidation. The CDC mailbox registers FIFO strobes
and read-valid, retaining asynchronous session reset for stopped clocks.

Reverse ready remains combinational where current arbitration/cancellation can
remove capacity and no extra input slot is reserved. See the
[boundary survey](../../docs/plans/ethernet-ptp/output-register-survey.md) for
specific exceptions and the [timing contracts](../../docs/plans/ethernet-ptp/rtl-readability.md)
for detection, publication and consumption edges. These changes deliberately
revise interface latencies; the software register layout is unchanged.

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

## 1G PHY compositions

[GigEthGthUltraScalePtp](gthUltraScale/rtl/GigEthGthUltraScalePtp.vhd) and
[GigEthGtyUltraScalePlusPtp](gtyUltraScale+/rtl/GigEthGtyUltraScalePlusPtp.vhd)
compose their PHY adapter with the same
[GigEthPtp](rtl/GigEthPtp.vhd). Both have identical public contracts.
`GigEthPtp` owns `GigEthReg`, `EthMacPtpEndpoint`, PCS reset stretching, and one
`AxiLiteAsync` followed by the local register crossbar. It is also usable with
another compatible full-rate GMII PHY. MAC/PCS register ownership stays here
because `GigEthReg` describes both; it does not belong in a PHY-only adapter.

```text
AXI-Lite -> AxiLiteAsync -> crossbar -> GigEthReg / EthMacPtpEndpoint
                                               |
application AXI Stream <-> EthMacPtpEndpoint <-> GMII <-> family PHY <-> serial
```

Application streams use `EMAC_AXIS_CONFIG_C` in the 125 MHz domain. Add stream
CDC outside this interface if the application has another clock; the management
bridge does not cross stream data. The existing endpoint reserves untagged
EtherType `0x88F7` for PTP. PHC time/status, PPS, IRQ, port state, servo state and
primary-drop count are exposed in the 125 MHz domain. `localMac` feeds the
Ethernet register block, whose MAC configuration also feeds the PTP endpoint.

Default register locations relative to `AXIL_BASE_ADDR_G`:

| Offset | Size | Device |
| --- | --- | --- |
| `0x0000` | 4 KiB | `GigEthReg` |
| `0x4000` | 16 KiB | `PtpEndpoint`: control, PHC, port, servo at 4 KiB strides |

Allocate at least a 32 KiB aligned parent window for the default map.
`ETH_OFFSET_G` and `PTP_OFFSET_G` can retain an existing board map. The resolved
Ethernet/PTP addresses must be 4 KiB/16 KiB aligned and disjoint; address addition
must not wrap. Elaboration assertions check those conditions. The parent must
allocate an aperture enclosing both banks. Holes return DECERR. The KCU105
integration uses relative `0x10000`/`0x20000` in its existing 256 KiB aperture,
preserving absolute Ethernet `0x50000` and endpoint `0x60000` addresses.

### Clocks, resets and qualification

- Supply continuously running, related `sysClk125` (125 MHz) and `sysClk62`
  (62.5 MHz) clocks meeting the existing checkpoint contract. GMII and PHC share
  `sysClk125`; this is full-rate 1 GbE, not 10/100 or SGMII rate adaptation.
- These checkpoints retain the legacy `gtrefclk => sysClk125` connection and
  `rxuserclk2 => sysClk62` wiring. They do not expose a newly qualified dedicated
  GT reference path or recovered clock. In particular, the KCU105 investigation
  found a fabric GT-reference path in its GTH checkpoint; clock routing still
  needs Vivado/device review before accepting precision results. Do not assume
  the GTY checkpoint has identical internal routing without inspecting it.
- `sysRst125` resets the complete MAC/PTP pipeline and PHC. It must follow the
  clock-source startup/discontinuity contract. A clock that stops or changes
  phase cannot silently retain a claim of valid time.
- `extRst`, Ethernet soft reset and watchdog reset only restart the PCS and PTP
  port association, preserving the running MAC/PHC and unresolved TX lifecycle.
  The common composition stretches PCS reset for 1000 `sysClk125` cycles using
  `PwrUpRst`. Link-ready loss reaches the endpoint independently through PCS
  status bit 1. The PHY-only interface expects its enclosing design to supply
  the appropriate stretched reset.
- `axilRst` resets the management bridge, not the PHC. Default `COMMON_CLK_G=false`
  permits an independent management domain; set it true only when the clocks
  and resets meet `AxiLiteAsync`'s common-clock contract.
- `PACKET_LIFETIME_G` defaults to 125,000,000 unsteered ticks (one second).
  Validate that bound against actual network/TX retention. Latency calibration
  is signed Q16 PHC nanoseconds; zero defaults are explicitly uncalibrated.

The extraction adds `U_Phy/` to the legacy checkpoint instance hierarchy.
Review external XDC/Tcl queries and DCP constraints that name the former
`U_GigEth*Core` path. PTP paths use `U_Phy/U_GigEth*Core`; KCU105 prefixes that
with `U_Ptp/`. No checkpoint is modified or regenerated here.

These are source integrations, not hardware-qualified PHYs. Static interface
checks cannot prove checkpoint binding, clock routing, timing closure or
connector-plane latency. Current evidence and required acceptance are retained
in the [PTP plan](../../docs/plans/ethernet-ptp/README.md#phy-composition-implementation).
