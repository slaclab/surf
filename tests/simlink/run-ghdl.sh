#!/usr/bin/env bash
# GHDL + cocotb SimLink layer. Requires `ghdl` on PATH.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_runner_common.sh"

have ghdl || layer_skip "ghdl — GHDL not on PATH; install/source GHDL first"

layer_run tests/simlink/ghdl
