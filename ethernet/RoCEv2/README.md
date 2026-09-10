# All-VHDL Implementation of RoCEv2 Engine
This folder is an all-VHDL RoCEv2 stack. Its origin traces to Bluespec SystemVerilog (BSV) source
code from a different repository: [blue-rdma](https://github.com/datenlord/blue-rdma), by way of a
modified fork, [FilMarini/blue-rdma](https://github.com/FilMarini/blue-rdma).

## Description
`blue-lib` holds hand-written surf primitives that a maintainer may edit directly. Any edit must
keep the whole stack passing `make MODULES="$PWD" analysis` and the cocotb regression under
`tests/ethernet/RoCEv2/`, whose `test_RoCEv2AxiStreamRdma.py` simulates the assembled top level and
so exercises every primitive the engine instantiates. See `blue-lib/README.md` for the
primitive-by-primitive conversion status.

`blue-rdma` holds machine-generated VHDL for the RoCEv2 RDMA engine. These files must never be
hand-edited; they are regenerated in the fork rather than edited in place. See
`blue-rdma/README.md` for the conversion record, the fork's commit, and what is and is not
proven about them.

The iCRC calculation is a hand-written VHDL engine under `rtl/` that generates its lookup tables at elaboration rather than reading checked-in table files.

blue-rdma's own origin modifies the upstream BSV sources as follows:

* **Receiving Path Removed**: The RoCEv2 engine's receiving path as well as support for RDMA-Read operations has been entirely removed.

* **Resource Optimization**: By removing the receiving path, the core now consumes fewer hardware resources, allowing it to fit on smaller FPGAs.

* **Fixed settings**: the generated verilog has support for 1 PD, 1 QP, 2 CQ and 2 MR, in order to be as light as possible. To change these settings, the core needs to be re-generated from its original or modified repo

## License information
The BSV-generated files follow the licensing terms from the original repositories. A copy of the original license can be found in the folders.

Please ensure compliance with both licenses when using or modifying these files.
