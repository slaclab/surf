# SimLink SystemVerilog Wrappers

This directory holds the flat SystemVerilog wrappers that a pure-Verilog
design instantiates: `RogueTcpStreamWrap`, `RogueTcpMemoryWrap`, and
`RogueSideBandWrap`. `simlink/ruckus.tcl` loads this directory instead of
`../sim/` (the VHDL record wrappers) when `RUCKUS_SIM_BACKEND` is `iverilog`
or `verilator`, since neither tool parses VHDL. Each wrapper instantiates the
backend leaf of the same name from `../iverilog/` or `../verilator/`
depending on the selected backend.

## Parameters

| Parameter | Default | Range | Wrappers |
| --- | ---: | --- | --- |
| `PORT_NUM_G` | 9000 | 1024..49151 | all three |
| `SSI_EN_G` | 1 | 0 or 1 | `RogueTcpStreamWrap` |
| `TDATA_BYTES_G` | 8 | 1..128 | `RogueTcpStreamWrap` |

Compose multiple channels by instantiating one wrapper per channel at
`PORT_NUM_G + 2*chan`; the wrappers do not multiplex channels themselves.

## RogueTcpStreamWrap

Stream direction naming follows the SURF SimLink convention: `sAxis*` is the
slave port, HDL-to-software; `mAxis*` is the master port, software-to-HDL.

| Port | Direction | Width |
| --- | --- | --- |
| `axisClk` | input | 1 |
| `axisRst` | input | 1 |
| `sAxisTValid` | input | 1 |
| `sAxisTData` | input | `TDATA_BYTES_G*8` |
| `sAxisTKeep` | input | `TDATA_BYTES_G` |
| `sAxisTUser` | input | `TDATA_BYTES_G*8` |
| `sAxisTLast` | input | 1 |
| `sAxisTReady` | output | 1 |
| `mAxisTValid` | output | 1 |
| `mAxisTData` | output | `TDATA_BYTES_G*8` |
| `mAxisTKeep` | output | `TDATA_BYTES_G` |
| `mAxisTUser` | output | `TDATA_BYTES_G*8` |
| `mAxisTLast` | output | 1 |
| `mAxisTReady` | input | 1 |

`TUSER` carries the raw SimLink convention documented in
[protocol-reference.md](../docs/protocol-reference.md): 8 bits per byte lane,
with SSI start-of-frame carried in bit 1 of lane 0 on the first beat of a
frame, and end-of-frame error (EOFE) carried in bit 0 of the last kept lane.

Intentional differences from the VHDL `RogueTcpStreamWrap`: no
`RogueTcpStreamPacer` bandwidth pacing, no `TDEST` mux or mask, no AXI Stream
resizing, no `TID`/`TSTRB`, and no `TPD_G` delay generic.

## RogueTcpMemoryWrap

A raw 1:1 port map onto the AXI-Lite master leaf, with no crossbar or
slave-side logic of its own.

| Port | Direction | Width |
| --- | --- | --- |
| `axilClk` | input | 1 |
| `axilRst` | input | 1 |
| `axilArAddr` | output | 32 |
| `axilArProt` | output | 3 |
| `axilArValid` | output | 1 |
| `axilArReady` | input | 1 |
| `axilRData` | input | 32 |
| `axilRResp` | input | 2 |
| `axilRValid` | input | 1 |
| `axilRReady` | output | 1 |
| `axilAwAddr` | output | 32 |
| `axilAwProt` | output | 3 |
| `axilAwValid` | output | 1 |
| `axilAwReady` | input | 1 |
| `axilWData` | output | 32 |
| `axilWStrb` | output | 4 |
| `axilWValid` | output | 1 |
| `axilWReady` | input | 1 |
| `axilBResp` | input | 2 |
| `axilBValid` | input | 1 |
| `axilBReady` | output | 1 |

## RogueSideBandWrap

A raw 1:1 port map onto the side-band leaf, keeping the existing VHDL port
names.

| Port | Direction | Width |
| --- | --- | --- |
| `sysClk` | input | 1 |
| `sysRst` | input | 1 |
| `txOpCode` | input | 8 |
| `txOpCodeEn` | input | 1 |
| `txRemData` | input | 8 |
| `rxOpCode` | output | 8 |
| `rxOpCodeEn` | output | 1 |
| `rxRemData` | output | 8 |

## Instantiation example

```verilog
RogueTcpStreamWrap #(
   .PORT_NUM_G    (9000),
   .SSI_EN_G      (1),
   .TDATA_BYTES_G (8)
) u_stream (
   .axisClk      (clk),
   .axisRst      (rst),

   .sAxisTValid  (sAxisTValid),
   .sAxisTData   (sAxisTData),
   .sAxisTKeep   (sAxisTKeep),
   .sAxisTUser   (sAxisTUser),
   .sAxisTLast   (sAxisTLast),
   .sAxisTReady  (sAxisTReady),

   .mAxisTValid  (mAxisTValid),
   .mAxisTData   (mAxisTData),
   .mAxisTKeep   (mAxisTKeep),
   .mAxisTUser   (mAxisTUser),
   .mAxisTLast   (mAxisTLast),
   .mAxisTReady  (mAxisTReady)
);
```
