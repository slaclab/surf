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
- [PtpRxTimestampTap](rtl/PtpRxTimestampTap.vhd): RX physical capture and bounded
  FCS/message validation, composing `PtpRxTimestampAdapter` and `PtpRxFrontend`
  without additional state or latency. The adapter/frontend register boundary
  keeps frame bytes and their start capture aligned. The leaf blocks remain
  independently testable. `PtpTxTimestampTap` composes the same leaves in
  TX-observation mode for actual TX wire completion.
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

`PtpEndpoint.TX_AXIS_CONFIG_G` selects the private Delay_Req output format.
Its default `PTP_RX_AXIS_CONFIG_C` preserves the eight-byte stream and direct
ready/valid connection from `PtpPort`. Other formats use an internal
`AxiStreamResize`; `EthMacPtpEndpoint` selects the MAC's 16-byte
`EMAC_AXIS_CONFIG_C`. The resize uses system reset only, preserving queued
data across port and register resets. Supported conversions follow
`AxiStreamResize`'s stream-configuration constraints; downstream framing must
interpret the selected configuration's SSI SOF/EOFE bits.

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
[timing guide](../../docs/plans/ethernet-ptp/rtl-readability.md#output-ownership-and-exceptions)
for specific exceptions and detection, publication and consumption edges. These changes deliberately
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
[GigEthPtp](rtl/GigEthPtp.vhd). Both share the same MAC/PTP contract; GTH
also offers the optional dedicated reference described below.
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
- By default these checkpoints retain the legacy `gtrefclk => sysClk125` connection and
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
  `PwrUpRst` with asynchronous assertion so reset also reaches the PHY while
  `sysClk125` is stopped; release is synchronized and stretched after the clock
  resumes. Assert system reset before stopping or retuning a clock source.
  Link-ready loss reaches the endpoint independently through PCS
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
`U_GigEth*Core` path. GTH paths now include
`U_Phy/GEN_FABRIC_REF/U_GigEthGthUltraScaleCore` or
`U_Phy/GEN_GT_REF/U_GigEthGthUltraScaleRefCore`; KCU105 prefixes the latter
with `U_Ptp/`. GTY retains `U_Phy/U_GigEthGtyUltraScaleCore`.
The legacy checkpoints remain unchanged.

These are source integrations, not hardware-qualified PHYs. Static interface
checks cannot prove checkpoint binding, clock routing, timing closure or
connector-plane latency. Current evidence and required acceptance are retained
in the [PTP plan](../../docs/plans/ethernet-ptp/README.md#phy-composition-implementation).

### Dedicated GTH reference and copper SGMII

[GigEthGthUltraScalePtp](gthUltraScale/rtl/GigEthGthUltraScalePtp.vhd)
passes `USE_GTREFCLK_G` to `GigEthGthUltraScalePhy`. False (default) keeps
`sysClk125` as the reference and ignores the optional `gtRefClk` input. True
uses `gtRefClk` for the dedicated 125 MHz reference and selects the separately
named `GigEthGthUltraScaleRefCore` checkpoint. Supply related fabric
125/62.5 MHz clocks in either mode. Selection is static at elaboration; the
fixed GT routing inside each DCP requires distinct checkpoint assets, but no
separate PHY or PTP VHDL wrapper. The dedicated-reference asset is not yet
supplied: the selected component cannot bind with only the existing legacy DCP.
Develop compatible IP in `surf-dcp-targets`, as identified by the
[checkpoint README](../GigEthCore/gthUltraScale/images/README.md), then qualify
its reference routing and integrate the asset through the normal ruckus manifest.
No checkpoint conversion or environment-variable loading workflow is required.

[Sgmii88E1111LvdsUltraScalePtp](lvdsUltraScale/rtl/Sgmii88E1111LvdsUltraScalePtp.vhd)
combines the shared LVDS PHY adapter with a separate `GigEthPtp` and Marvell
MDIO controller. It advertises only gigabit full duplex and gates readiness
on MDIO initialization, copper link/speed, PCS validity and GMII clock enable.
10/100 support remains in the ordinary Ethernet composition only. Its PHC,
application streams and outputs use the PCS-derived `phyClk` (125 MHz from
625 MHz external PHY clock); use `phyRst` for consumers in that domain.

The independent `stableClk`/`stableRst` domain owns external PHY reset, MDIO and
finite PCS-reset pulses. It must keep running while the PHY clock is absent.
This avoids a reset feedback loop: the vendor PCS reset also controls its
clock/reset outputs. **Copper PCS reset resets the copper PHC/MAC and register
configuration**; software must reconfigure and reacquire time. That differs
from the externally clocked GTH/GTY compositions, which retain PHC time during
PCS reset. Cable-loss clock continuity and reset recovery require hardware
qualification. Do not claim holdover across a stopped clock.

Both new compositions use the same endpoint register layout and single internal
AXI-Lite CDC before fanout. Instantiating them together creates independent PHCs
and servos; there is no shared timing loop. Their distinct MACs provide distinct
default PTP identities, unless overridden by software. Outputs are local to
each clock domain; comparison capture/stream CDC belongs in board/application
integration. Readiness bit 1 in copper's Ethernet core status is qualified as
above, while bit 0 retains raw PCS link validity.
