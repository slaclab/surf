# Gigabit Ethernet PHY and MAC integration

This subtree supplies 1 GbE MAC/PHY integrations. Shared Ethernet management
lives in `core/`; transceiver adapters live in family directories. PTP compositions live alongside the protocol code in `PtpCore`.
See the [Ethernet index](../README.md) and [PTP endpoint guide](../PtpCore/README.md).

## GMII boundary

The following PHY-only adapters expose the same ports:

| Adapter | Device family | Existing checkpoint |
| --- | --- | --- |
| [GigEthGthUltraScalePhy](gthUltraScale/rtl/GigEthGthUltraScalePhy.vhd) | UltraScale GTH, including KCU105 | `GigEthGthUltraScaleCore.dcp` |
| [GigEthGtyUltraScalePlusPhy](gtyUltraScale+/rtl/GigEthGtyUltraScalePlusPhy.vhd) | UltraScale+ GTY, including the RFMC 1G RTM path | `GigEthGtyUltraScaleCore.dcp` |

Each adapter owns the vendor component declaration and checkpoint wiring. It
accepts GMII TX and returns GMII RX, plus native five-bit PCS configuration and
16-bit PCS status. It exposes signal detect and TX/RX polarity. It contains no
MAC, PHC, registers, clock generator or AXI-Lite crossing. Auto-negotiation
advertisement, reference selection and unused vendor outputs retain the legacy
wiring. Vendor components bind to DCPs in Vivado, not to VHDL implementations.

`GigEthGthUltraScale` and `GigEthGtyUltraScale` now use these adapters beneath
their existing MAC and management logic. Their public interfaces, register maps
and reset logic are unchanged. Existing multi-lane wrappers continue to use
those lane entities. New UltraScale+ entities explicitly include `Plus` in their
names; new implementations must not rely on duplicate names selected by ruckus.

The adapter is deliberately thin: it removes duplicate component declarations
and checkpoint connections from the ordinary Ethernet and PTP compositions.
There is no added pipeline or packet-processing stage. Its cost is one extra
hierarchy level. This boundary lets either MAC composition use the same PHY
without an external-MAC mode or unused MAC ports in the legacy entity.

## Clock/reset contract and hierarchy

Supply related 125 MHz and 62.5 MHz fabric clocks and an appropriately stretched
PCS reset. These adapters preserve the existing `gtrefclk => sysClk125` and
`rxuserclk2 => sysClk62` wiring. Reference routing, clock continuity and reset
release still need device/board qualification; extracting the wiring does not
qualify a new clock path. They do not expose recovered clocks.

The extraction adds `U_Phy/` to the legacy checkpoint instance hierarchy.
Review external XDC/Tcl queries and DCP constraints naming the former
`U_GigEth*Core` path. No checkpoint is modified or regenerated here.

The [PTP compositions and their clock/reset/register contracts](../PtpCore/README.md#1g-phy-compositions)
live under `PtpCore`. See the [PTP plan](../../docs/plans/ethernet-ptp/README.md#phy-composition-implementation)
for current static evidence and outstanding behavioral/device acceptance.
