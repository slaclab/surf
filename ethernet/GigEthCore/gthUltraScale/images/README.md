Refer to https://github.com/slaclab/surf-dcp-targets/tree/master/firmware/dcp/GigEthGthUltraScale/ for original source code

`GigEthGthUltraScaleCore.dcp` is a **dual-mode** checkpoint: it does not tie
`CPLLREFCLKSEL` internally, so the GT reference source is chosen by the
instantiating design through two added ports rather than by picking a
checkpoint. The original 33 ports are unchanged.

| `gt0_usegtgrefclk_in` | `CPLLREFCLKSEL` | reference taken from |
| --- | --- | --- |
| `'1'` | `"111"` | `gt0_gtgrefclk_in` — fabric clock (`GTGREFCLK`) |
| `'0'` | `"001"` | `gtrefclk` — dedicated reference |

Only the fabric input needs its own port; the dedicated reference arrives on the
existing `gtrefclk` port. `"001"` is the IP default for a dedicated reference
and leaves the actual `MGTREFCLK` route to placement, so no separate GTREFCLK1
port is required. Both clock inputs are always connected and the select decides
which drives the CPLL, so neither is left floating in either mode.

`GigEthGthUltraScalePhy` drives both from its `USE_GTREFCLK_G` generic: `false`
takes the fabric 125 MHz clock, `true` the dedicated GT buffer output on its
`gtRefClk` port.

A synthesized checkpoint does not carry VHDL port defaults, so a design binding
this `.dcp` must drive both ports explicitly even when it only wants the
original fabric behaviour.
