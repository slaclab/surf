#!/usr/bin/env bash
# Vivado xsim mixed-language SimLink layer. Requires `xelab` on PATH (bring
# Vivado in via your interactive alias, e.g. `x2024.2`).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_runner_common.sh"

have xelab || layer_skip "xsim — xelab not on PATH; run your Vivado alias (e.g. x2024.2) first"

# Clean stale build artifacts so a prior Vivado version's xelab snapshot is not
# reused.
clean_sim_build xsim

echo "== Vivado xsim layer"
echo "   tests: mixed-language DPI ABI, instance isolation, duplicate-pair rejection, active traffic"
echo "   sim_build: tests/sim_build/simlink/xsim (cleaned each run)"

layer_run_sim tests/simlink/xsim
