#!/usr/bin/env bash
# Licensed VCS + cocotb SimLink layer. Opt-in: requires SIMLINK_RUN_VCS=1 and
# `vcs` on PATH (bring VCS in via your interactive alias, e.g. `simX`).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_runner_common.sh"

if [ "${SIMLINK_RUN_VCS:-0}" != "1" ]; then
    layer_skip "vcs — SIMLINK_RUN_VCS != 1 (opt-in gate); set it in env.local.sh after sourcing your VCS alias"
fi
have vcs || layer_skip "vcs — VCS not on PATH; run your VCS alias (e.g. simX) first"

# Clean stale build artifacts. VCS refuses to reuse an AN.DB analyzed by a
# different vlogan version, and switching versions changes the
# -I$VCS_HOME/include path, so rebuild the VHPI objects/.so too.
clean_sim_build vcs
make -C "$ROOT/simlink/vcs" clean >/dev/null 2>&1 || true

echo "== VCS VHPI layer"
echo "   VCS_HOME=${VCS_HOME:-<unset>}  (version year auto-derived; override VCS_VERSION=<year>)"
echo "   tests: 4 Stream / 2 Memory / 2 SideBand instances, tagged traffic + post-traffic reset"
echo "   sim_build: tests/sim_build/simlink/vcs (cleaned each run)"

layer_run_sim tests/simlink/vcs/test_RogueVcsMultiInstance.py
