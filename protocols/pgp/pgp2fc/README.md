# PGP2 Fast Control (PGP2FC) Implementation

Similar implementation as PGP2B, while giving priority to fast control words and fixed latency.

Applications need to create the MGT wrapper with no elastic buffers and PMA RX Slide enabled. See LDMX fast control application example.

Xilinx does NOT allow this configuration directly from the transceiver wizard, but it can be overriden by configurating it with PCS slide and then using the following constraint:

```
set_property RXSLIDE_MODE PMA [get_cells {<Path to target GTYE4_CHANNEL_PRIM_INST>}]
```

**This variant only supports a single-lane mode and special care must be taken when using virtual channels and fast control excessively.**

## Design considerations

Because fast control has priority over virtual channel data, it is possible that the virtual channels will become starved if too many fast control words are sent frequently or with no break between them.

Using the fast control scheme in LDMX as an example:

- Experimental operational clock is 37.2MHz and the link will operate at 3.72GHz with 186MHz on the user side.
- In this scheme, we send a single fast control word every 37.2MHz clock tick with 16-bits width to indicate an edge transition, even if there are no fast control flags to send.
- Because of the experimental clock of 37.2MHz, we can send up to 5 data words in the link (186/37.2=5), and because PGP2FC fast control words have an overhead of 1 word for header and CRC, it means that out of the 5 data words per experimental clock, 2 will be used for fast control.
- Leaving 3/5 available for virtual channel operation. This is be fine for light operation.

In the example above, if the width of the fast control word got changed from 16-bits to 64-bits, it would mean the link would be saturated and the virtual channels would be starved. In this situation virtual channels should not be used.