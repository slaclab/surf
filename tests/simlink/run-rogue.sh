#!/usr/bin/env bash
# Real Rogue/PyRogue Memory contract. Requires SIMLINK_ROGUE_PYTHON (a conda
# interpreter with rogue+pyrogue) and `ghdl` on PATH (GHDL drives the DUT).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_runner_common.sh"

if [ -z "${SIMLINK_ROGUE_PYTHON:-}" ]; then
    layer_skip "rogue — SIMLINK_ROGUE_PYTHON unset; set it in tests/simlink/env.local.sh (see env.example.sh)"
fi
have ghdl || layer_skip "rogue — ghdl not on PATH (GHDL drives the Rogue DUT)"

layer_run tests/simlink/rogue/test_RogueTcpMemoryRogue.py
