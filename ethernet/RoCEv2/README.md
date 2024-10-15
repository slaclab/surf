@FilMarini: Please write up some text about how these modules were auto-generated from BlueRdma

# Hardware Implementation of RoCEv2 Engine
This folder contains files generated from Bluespec SystemVerilog (BSV) source code located in different repositories: [blue-rdma](https://github.com/datenlord/blue-rdma), [blue-crc](https://github.com/datenlord/blue-crc)

## Description
The verilog files in the `blue-rdma` and `blue-crc` folders represent a hardware implementation of the RoCEv2 engine and a iCRC calculation engine, respectively.
These files have been generated from a modified version of the BSV sources. The forked repo with the modifed version can be found [here](https://github.com/FilMarini/blue-rdma)

The modifications consists in:

* **Receiving Path Removed**: The RoCEv2 engine's receiving path as well as support for RDMA-Read operations has been entirely removed.

* **Resource Optimization**: By removing the receiving path, the core now consumes fewer hardware resources, allowing it to fit on smaller FPGAs.

## License information
The BSV-generated files follow the licensing terms from the original repositories. A copy of the original license can be found in the folders.

Please ensure compliance with both licenses when using or modifying these files.