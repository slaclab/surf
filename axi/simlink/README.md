# Simlink

This directory holds three interchangeable Rogue co-simulation backends -- GHDL/VHPIDIRECT (`ghdl/`), Synopsys VCS/VHPI (`vcs/`), and Vivado xsim/DPI (`xsim/`) -- selected automatically by `ruckus.tcl` based on the active simulator. All three backends share the same `shared/` C cores and speak the same ZeroMQ wire protocol to a Rogue-side Python peer, so a testbench built against one backend behaves the same on any of the others.

## Prerequisites

- `libzmq >= 4.1.0` -- check with `pkg-config --modversion libzmq`.
- A Rogue-environment shell for the peer scripts (they `import pyrogue` / `import rogue`).

## Running the Vivado xsim Co-Simulation

1. Run `make gui` from the target directory. Ruckus auto-detects whichever of `RogueTcpStream.vhd`, `RogueTcpMemory.vhd`, or `RogueSideBand.vhd` is present in the sim sources, builds the combined `RogueTcpDpi.so` via `xsc`, and binds it with a single `-sv_lib RogueTcpDpi` -- no manual build step is required.
2. Watch the Tcl/GUI console for the `xsc` build completing and, after `launch_simulation` / `run`, the module's `Listening on ports N & N+1` message -- that print is the ready-for-peer signal.
3. In a separate terminal, start the matching Rogue-side driver script against that module's port.
4. Watch the waveform -- data movement between the DPI adapter and the peer confirms the round trip.

| Module | Demo TB | Ports | Peer script |
|--------|---------|-------|-------------|
| RogueTcpStream | `RogueTcpStreamXsimDemoTb` | 9000 (push on 9001) | `prbsLoopbackDemo.py` |
| RogueTcpMemory | `RogueTcpMemoryXsimDemoTb` | 9100 (push on 9101) | `axiVersionMemoryDemo.py` |
| RogueSideBand | `RogueSideBandXsimDemoTb` | 9200 (push on 9201) | `sideBandDemo.py` |

## Selecting a Module

Vivado elaborates one top per simulation fileset, so switching which module's demo runs is a single manual step: in the target's `ruckus.tcl`, comment/uncomment the desired `set_property top {...XsimDemoTb}` line, then run `make gui` again. This is the only manual step when switching between modules -- the DPI build and `-sv_lib` binding stay identical regardless of which module is selected.

## Troubleshooting

**"libzmq package was not found"**
If the Tcl console prints:
```
libzmq package was not found
Please make sure that you have libzmq installed
or have sourced the necessary rogue setup scripts
```
install libzmq (or source the Rogue setup scripts that put it on `PKG_CONFIG_PATH`) and re-run `make gui`.

**Idle waveform, no data movement**
If the console printed `Listening on ports N & N+1` but the waveform never shows activity, the peer has not connected. Confirm the driver script is running, targeting the same host (loopback `127.0.0.1`) and port pair as the module under test, and that push/pull directions are not swapped.
