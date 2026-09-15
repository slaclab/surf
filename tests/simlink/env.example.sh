# SimLink test runner configuration — TEMPLATE.
#
# Copy to env.local.sh (git-ignored) and edit for your machine:
#   cp tests/simlink/env.example.sh tests/simlink/env.local.sh
#
# The layer runner scripts source env.local.sh automatically if present.
# All values are optional; unset gates simply cause the relevant layer to skip.

# --- Real Rogue layer -------------------------------------------------------
# Absolute path to a Python interpreter that can import rogue and pyrogue
# (typically a conda env). Used only to spawn the Rogue client child process;
# pytest itself still runs under .venv. Layer skips if unset.
# export SIMLINK_ROGUE_PYTHON=/path/to/conda/envs/<env>/bin/python

# --- VCS layer (licensed) ---------------------------------------------------
# Opt-in gate: the VCS layer runs only when this is 1 AND `vcs` is on PATH.
# Bring VCS onto PATH first (e.g. your interactive `simX` alias); the version
# year is auto-derived from VCS_HOME, so nothing else is required.
# export SIMLINK_RUN_VCS=1
# Optional: override the auto-derived version year (4-digit) only if VCS_HOME
# does not encode it. Normally leave this unset.
# export VCS_VERSION=2025
# Optional license override, applied to VCS test subprocesses only.
# export SIMLINK_VCS_LICENSE_FILE=27000@cadlic-ext.stanford.edu

# --- Common overrides -------------------------------------------------------
# Override pytest args wholesale (default: "-q -n auto --dist=worksteal").
# Use serial for readable simulator logs:
# export PYTEST_ARGS="-q -n 0"
# Raise the multi-instance peer-completion budget, in seconds, on a loaded host
# (default 60):
# export SIMLINK_MULTI_MAX_TRAFFIC_SECONDS=120
# Raise the persistent relaunch peer's wait budget, in seconds, when a
# simulator takes longer to analyze and elaborate than the peer will wait for
# it to bind (default 60; the VCS relaunch test sets its own value):
# export SIMLINK_PEER_WAIT_SECONDS=720
