#!/usr/bin/env bash
# Verilator SimLink layer. Requires verilator (>= 5.020) on PATH.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_runner_common.sh"

have verilator || layer_skip "verilator: Verilator (>= 5.020) not on PATH"

clean_sim_build verilator

echo "== Verilator layer"
echo "   sim_build: tests/sim_build/simlink/verilator (cleaned each run)"

layer_run_sim tests/simlink/verilator
