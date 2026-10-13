Refer to https://github.com/slaclab/surf-dcp-targets/tree/master/firmware/dcp/GigEthGthUltraScale/ for original source code

`GigEthGthUltraScaleCore.dcp` is a **multi-mode** checkpoint: it does not tie
`CPLLREFCLKSEL` internally, so the GT reference source is chosen by the
instantiating design through four added ports rather than by picking a
checkpoint. The original 33 ports are unchanged.

| `gt0_usegtgrefclk_in` | `gt0_userefclk1_in` | `CPLLREFCLKSEL` | reference taken from |
| --- | --- | --- | --- |
| `'1'` | ignored | `"111"` | `gt0_gtgrefclk_in` — fabric clock (`GTGREFCLK`) |
| `'0'` | `'0'` | `"001"` | `gtrefclk` — dedicated reference on `GTREFCLK0` |
| `'0'` | `'1'` | `"010"` | `gt0_gtrefclk1_in` — dedicated reference on `GTREFCLK1` |

A dedicated reference must name the channel input it arrives on. `GTREFCLK0`
and `GTREFCLK1` are fed by the quad's `MGTREFCLK0` and `MGTREFCLK1` pin pairs
respectively, and no routing resource connects them: selecting the wrong index
leaves the reference unroutable, which `route_design` reports as
`[Route 35-7] Design has 1 unroutable pin` with an unroute type of
`GTHE3_COMMON.MGTREFCLK<n>->GTHE3_CHANNEL.MGTREFCLK<m>`. Placement cannot
resolve this. The select encoding never yields the invalid `"000"`.

The dedicated clock must drive only the selected input; one net cannot reach
both `MGTREFCLK` inputs of a quad. `GigEthGthUltraScalePhy` drives all four
ports from its `USE_GTREFCLK_G` and `GTREFCLK_INDEX_G` generics: `false` takes
the fabric 125 MHz clock, `true` the dedicated GT buffer output on its
`gtRefClk` port, with the index selecting `GTREFCLK0` or `GTREFCLK1` and tying
off the other.

**An unselected dedicated input must be tied to a constant, not to a fabric
clock.** `GTREFCLK0` and `GTREFCLK1` are reachable only from the quad's
`MGTREFCLK` pins, so a fabric clock on either is unroutable even when
`CPLLREFCLKSEL` does not select it: the net still exists and the router must
route it. A constant tie-off is not a floating input. Only `GTGREFCLK`, driven
from `gt0_gtgrefclk_in`, accepts a fabric clock; that port is connected
unconditionally and carries the fabric path in `"111"` mode.

Driving `gtrefclk` with the fabric clock when it was not selected caused a
`route_design` failure in the `PtpKcu105` target on October 13, 2026, reported
as `[Route 35-7] Design has 1 unroutable pin` with unroute type
`BUFG_GT.CLK_OUT->GTHE3_CHANNEL.MGTREFCLK0`. Note this differs from the
wrong-index signature above: the driver is a `BUFG_GT`, not a `GTHE3_COMMON`.
Synthesis, including out-of-context synthesis of this wrapper, cannot detect
either condition; only a full implementation run can.

A synthesized checkpoint does not carry VHDL port defaults, so a design binding
this `.dcp` must drive all four ports explicitly even when it only wants the
original fabric behaviour.
