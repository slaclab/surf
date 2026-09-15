These VHDL primitives are hand-written surf code that a maintainer may edit directly. Any edit
must keep the whole stack passing `make MODULES="$PWD" analysis` and the cocotb regression under
`tests/ethernet/RoCEv2/`, whose `test_RoCEv2AxiStreamRdma.py` simulates the assembled top level
and so exercises every primitive the engine instantiates. Each was translated from a
Bluespec-generated Verilog primitive originally taken from the
[B-Lang-org/bsc](https://github.com/B-Lang-org/bsc) repo.

The license file from the original repo applies to the files in this folder

## VHDL Conversion Status

| Primitive   | VHDL |
|-------------|------|
| FIFO2       | Yes  |
| FIFO20      | Yes  |
| SizedFIFO   | Yes  |
| BRAM2       | Yes  |
| RegN        | Yes  |
| RegUN       | Yes  |
| ConfigRegN  | Yes  |
| CRegN5      | Yes  |
| CRegUN5     | Yes  |
| Counter     | Yes  |
| RWire       | Yes  |
| RWire0      | Yes  |
| BypassWire  | Yes  |
