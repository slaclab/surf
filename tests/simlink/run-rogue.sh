#!/usr/bin/env bash
# Real Rogue/PyRogue SimLink contracts. Requires SIMLINK_ROGUE_PYTHON (a
# conda interpreter with rogue and pyrogue). Each backend's contract runs
# only when its own simulator is on PATH: GHDL drives the Memory contract;
# Icarus Verilog (with iverilog-vpi and vvp) and Verilator each drive the
# Memory, Stream and SideBand contract. A missing simulator skips only its
# own backend's contract; the layer skips only when none is present.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_runner_common.sh"

if [ -z "${SIMLINK_ROGUE_PYTHON:-}" ]; then
    layer_skip "rogue: SIMLINK_ROGUE_PYTHON unset; set it in tests/simlink/env.local.sh (see env.example.sh)"
fi

tests=()

if have ghdl; then
    tests+=("tests/simlink/rogue/test_RogueTcpMemoryRogue.py")
else
    echo "note: rogue: ghdl not on PATH, skipping the GHDL Memory contract" >&2
fi

if have iverilog && have iverilog-vpi && have vvp; then
    tests+=("tests/simlink/rogue/test_RogueIverilogRogue.py")
else
    echo "note: rogue: iverilog, iverilog-vpi or vvp not on PATH, skipping the Icarus contract" >&2
fi

if have verilator; then
    tests+=("tests/simlink/rogue/test_RogueVerilatorRogue.py")
else
    echo "note: rogue: verilator not on PATH, skipping the Verilator contract" >&2
fi

if [ "${#tests[@]}" -eq 0 ]; then
    layer_skip "rogue: no Rogue DUT simulator on PATH (ghdl, iverilog with iverilog-vpi and vvp, or verilator)"
fi

layer_run "${tests[@]}"
