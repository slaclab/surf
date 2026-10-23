# GTX7 Support

This directory contains the SURF wrapper, reset state machines, clock monitoring, and phase-alignment
helpers for the AMD/Xilinx 7 Series `GTXE2_CHANNEL` primitive. `Gtx7Core` is the main integration
point, and the directory-level `ruckus.tcl` loads the sources in `rtl/`.

## Fixed-latency RX alignment

`Gtx7RxFixedLatPhaseAligner` aligns a comma in raw parallel RX data while the RX elastic buffer is
bypassed. This configuration requires:

- `RX_ALIGN_MODE_G = "FIXED_LAT"`
- `RX_BUF_EN_G = false`
- `RXSLIDE_MODE_G = "PMA"`

In PMA slide mode, `RXSLIDE` moves the parallel data by one bit per pulse, but the recovered output
clock changes phase only on every other pulse. An even number of slides therefore preserves the
relationship between the aligned comma and `RXOUTCLK`. An odd comma landing needs one of two policies,
selected by `RX_ODD_ALIGN_MODE_G`:

| Mode | Odd landing behavior | Latency and phase contract |
| --- | --- | --- |
| `"RESET"` | Request another RX initialization and accept only a landing requiring an even number of slides. | Intended for applications requiring the recovered-clock phase to match the aligned serial UI. Bring-up can retry without bound. |
| `"BITSLIP"` | Use only an even number of PMA slides, leave a one-bit residue, and repair the word boundary in fabric. | Adds exactly one `rxUsrClk` stage for every landing. Parallel-word latency is deterministic, but the odd and even landing classes may differ in recovered-clock phase by as much as one serial UI. |

`"BITSLIP"` does not request an RX reset after an odd landing. Its caller must drive `rxDataValidIn`
from a decoder so `Gtx7RxRst` can restart alignment if the link later loses validity. Leaving
`rxDataValidIn` at its default of `'1'` disables that recovery path.

## Shared CPLL reset ownership

When TX and RX both select the channel CPLL, `Gtx7Core` gives the TX reset state machine sole ownership
of `CPLLRESET`. This prevents an RX-only retry from resetting the PLL underneath an active TX without
also resetting the TX datapath. The RX reset state machine still asserts `GTRXRESET`, which reinitializes
the RX datapath and CDR, but its separate PLL-reset request is not selected onto the shared CPLL reset.

Consequently, `RX_ODD_ALIGN_MODE_G = "RESET"` retries do not reinitialize the shared CPLL. If odd/even
landing parity is correlated with CPLL or TX state, an RX-only retry can repeatedly return to the same
odd class. Do not fix that by ORing the RX PLL-reset request directly onto `CPLLRESET`: TX would lose
its clock while its reset state machine continued to report stale state. A system requiring both strict
serial-UI phase and shared-CPLL recovery must coordinate both reset state machines and let the TX reset
state machine remain the sole CPLL-reset owner.

A coordinated CPLL restart changes more shared state than `GTRXRESET`, but the GTX documentation does
not guarantee that it changes odd/even comma-landing parity. Any such recovery should therefore remain
bounded and expose a failure condition rather than repeatedly disrupting TX without limit.
