# Ethernet PTP endpoint

Fixed-source Layer-2 E2E PTP TimeReceiver with one-/two-step Sync reception,
passive physical timestamping and an autonomous PHC/servo. Software configures
and observes it; software is outside the timing loop. Standards/profile and
hardware qualification remain open.

## Guides and sources

| Need | Start here |
| --- | --- |
| Endpoint-to-leaf orientation | [Architecture walkthrough](overview.md) |
| Data flow, numerical behavior, storage and design rationale | [Architecture](architecture.md) |
| Exact handshake, lifecycle, RAM and service bounds | [Interface contracts](interfaces.md) |
| AXI transactions, offsets, defaults and PyRogue ownership | [Register map](register-map.md) |
| Shared PHC subsystem: owner-gated admission, coordination, resets and qualification | [PHC subsystem contract](phc.md) |
| Future waveform/oscillator/epoch integration | [Physical-clock requirements](physical-clock.md) |
| Timing-capable MAC port for a replaceable controller: records, token carrier, `PtpMacPort` and the DMA envelope | [Timing-port contract](timing-port.md); simulation-verified, with a read-only status bank; no hardware result yet |
| Telemetry records: PHC, measurement and servo streams for observation | [Telemetry record format](telemetry.md) |
| Current results and unfinished acceptance | [Workstream](../../docs/plans/ethernet-ptp/README.md) |
| Fixtures, independent oracles and focused test selection | [PTP tests](../../tests/ethernet/PtpCore/README.md) |

`rtl/` contains the common endpoint, packages, MAC composition and `GigEthPtp`.
`PtpEndpoint` connects `PtpEndpointControl`, `PtpProtocolEngine`, `PtpServo`
(with its private `PtpSecondService`), `PtpVariableDivide`, TX adaptation, the
AXI crossbar and the shared `PtpPhcCore` clock subsystem (`PtpPhcControl`,
`PtpPhc` and a private SECOND converter), with the servo as the core's external
command client; see the [PHC subsystem contract](phc.md). The same core is used
standalone, without protocol or servo. `PtpProtocolEngine` structurally connects `PtpProtocolReg` (configuration
and snapshots), `PtpPortPolicy` (admission and lifecycle), `PtpSyncFlow`
(association and measurement coordination), `PtpDelayReqTx` (scheduling and
frame transmission), and `PtpTxLedger` (wire ownership). The flow delegates table ownership to
`PtpSyncPair` and `PtpSyncHistory`, with row comparisons shared through
`PtpTableScan`. The rate estimator and E2E arithmetic remain flow children. `EthMacPtpEndpoint` adds `EthMacTop`, the
primary-stream guard and passive RX/TX taps. The RX tap composes the timestamp
adapter and RX frontend; TX uses the same adapter with `PtpDelayReqObserver`.
`PtpMacPortEthMac` is the separate timing-port composition: `PtpMacPort`
(`PtpMacPortTx`, `PtpMacPortRx`) over a timing-mode `EthMacTop`, with the PHC
supplied externally (for example by a standalone `PtpPhcCore`), and
`PtpMacPortReg`, its read-only status, occupancy and counter bank; see the
[timing-port contract](timing-port.md#10-phase-1-implementation-map) and
[register map](register-map.md#ptpmacport-fields).
`PtpMacPortEndpoint` is the autonomous endpoint on that MAC:
`PtpMacPortRxAdapter` and `PtpMacPortTxAdapter` give the same `PtpEndpoint`
the records the passive taps produce. `GigEthPtp`'s `MAC_MODE_G` selects
`"TAPPED"` (`EthMacPtpEndpoint`, default) or `"TIMING_PORT"` (PTP-only); see
[timing-port §11](timing-port.md#11-autonomous-rtl-backend-on-the-timing-port).

`wrappers/` contains thin simulation adapters; stimulus lives in the test tree.
The family directories below contain PHY compositions. Reusable PHY-only
adapters live in [GigEthCore](../GigEthCore/README.md). The
[PyRogue endpoint](../../python/surf/ethernet/ptp/_PtpEndpoint.py) exposes
`ProtocolEngine`, `Servo` and `PhcCore` (with its `Phc`) children. `ruckus.tcl` owns the source
inventory for production RTL. Tests load their simulation wrappers explicitly
through `extra_vhdl_sources`.
Production transactions use package-owned records; the
[record interface guide](interfaces.md#record-interfaces-and-source-compatibility)
lists their owners, lifetimes and source-API migration.

## Integration essentials

- Use a continuously running Ethernet/PHC clock: GMII at 125 MHz or XGMII at
  156.25 MHz. Set both `PHY_TYPE_G` and `CLK_FREQ_G`; the composition asserts
  the pair. GMII 10/100 operation is unsupported.
- Assign a unique `localMac`. The primary stream uses `EMAC_AXIS_CONFIG_C`
  with a full first SSI beat. Untagged EtherType `0x88F7` is reserved for the
  endpoint; its private Delay_Req stream is resized to the MAC bypass format.
- Set signed Q16 local-PHC nanosecond ingress/egress calibration and a defensible
  `PACKET_LIFETIME_G`. Zero calibration is uncalibrated; finite key reuse relies
  on the declared network lifetime.
- System reset must reach the entire MAC/resize/endpoint pipeline. Logical
  restart preserves offered TX frames and unresolved wire reservations;
  AXI-only reset preserves active configuration and accepted commands.
- `MAX_FRAME_G` defaults to 1518 and `TLV_EN_G` to true. Reduced capacity and
  TLV rejection restrict accepted traffic; see the
  [capacity contract](architecture.md#frame-capacity-and-tlvs).
- RX records, captures and PHC outputs are local-domain signals, not CDC
  interfaces. `PtpPhcRead` is an optional coherent snapshot mailbox; it does
  not create a continuously advancing remote PHC.

Follow [SURF VHDL conventions](../../docs/vhdl-conventions.md) and the
[PTP interface supplement](interfaces.md) when changing these modules.
Use the normal ruckus import and [focused test procedures](../../tests/ethernet/PtpCore/README.md)
for implementation work. See the parent [Ethernet index](../README.md).

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
| `0x8000` | 32 KiB | `PtpEndpoint`: control, port, servo and the 8 KiB PHC core ([map](register-map.md)) |

Allocate at least a 64 KiB aligned parent window for the default map.
`ETH_OFFSET_G` and `PTP_OFFSET_G` can retain an existing board map. The resolved
Ethernet/PTP addresses must be 4 KiB/32 KiB aligned and disjoint; address addition
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
`U_GigEth*Core` path. The GTH path is
`U_Phy/U_GigEthGthUltraScaleCore`, with KCU105 prefixing it with `U_Ptp/`; the
earlier `GEN_FABRIC_REF`/`GEN_GT_REF` generate labels no longer exist now that
one core serves both reference modes. GTY retains
`U_Phy/U_GigEthGtyUltraScaleCore`.
The legacy checkpoints remain unchanged.

These are source integrations, not hardware-qualified PHYs. Static interface
checks cannot prove checkpoint binding, clock routing, timing closure or
connector-plane latency. Current evidence and required acceptance are retained
in the [PTP plan](../../docs/plans/ethernet-ptp/README.md#phy-composition-implementation).

### Dedicated GTH reference and copper SGMII

[GigEthGthUltraScalePtp](gthUltraScale/rtl/GigEthGthUltraScalePtp.vhd)
passes `USE_GTREFCLK_G` to `GigEthGthUltraScalePhy`. False (default) keeps the
fabric `sysClk125` reference and ignores the optional `gtRefClk` input. True
uses `gtRefClk` for the dedicated 125 MHz reference. Supply related fabric
125/62.5 MHz clocks in either mode.

A single dual-mode checkpoint serves both paths: it leaves `CPLLREFCLKSEL`
untied, so the generic drives a reference-select port on the core instead of
choosing between distinct assets, and no separate PHY or PTP VHDL wrapper is
needed. Selection is still static at elaboration. See the
[checkpoint README](../GigEthCore/gthUltraScale/images/README.md) for the
select mapping. Reference routing and timing remain unqualified in both modes.
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
