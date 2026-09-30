#!/usr/bin/env bash
# Icarus Verilog SimLink layer. Requires iverilog (>= 12) with iverilog-vpi
# and vvp on PATH.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_runner_common.sh"

have iverilog && have iverilog-vpi && have vvp || layer_skip "iverilog: Icarus Verilog (>= 12) with iverilog-vpi and vvp not on PATH"

clean_sim_build iverilog

echo "== Icarus Verilog layer"
echo "   sim_build: tests/sim_build/simlink/iverilog (cleaned each run)"

layer_run_sim tests/simlink/iverilog
