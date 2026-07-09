# DSP

This tree contains reusable signal-processing support blocks.

## Layout

- `generic/`: portable DSP RTL intended to work across FPGA families.
- `xilinx/`: Xilinx-specific DSP implementations and wrappers.

Prefer generic implementations unless the design needs a family primitive, timing path, or vendor IP wrapper. Keep family-specific assumptions isolated under the vendor-specific subtree and guarded by ruckus logic when necessary.
