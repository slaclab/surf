# Shared helpers for SimLink layer runner scripts. Source this; do not execute.
#
# Provides:
#   $ROOT              - repo root (also cd'd into)
#   ${PYTEST[@]}       - pytest driver command array
#   layer_run PATHS...     - run pytest over PATHS, emit sentinel 'ran', exit rc
#   layer_run_sim PATHS... - like layer_run but verbose/serial by default (sim layers)
#   layer_skip REASON      - print SKIP to stderr, emit sentinel 'skipped', exit 0
#   clean_sim_build CAT    - rm -rf tests/sim_build/simlink/CAT (announce)
#   have CMD               - true if CMD is on PATH

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$ROOT"

# User-specific config (rogue interpreter, overrides). Optional, git-ignored.
if [ -f "$ROOT/tests/simlink/env.local.sh" ]; then
    # shellcheck disable=SC1091
    source "$ROOT/tests/simlink/env.local.sh"
fi

PYTEST=("$ROOT/.venv/bin/python" -m pytest)

# Default pytest args; override wholesale via PYTEST_ARGS.
DEFAULT_PYTEST_ARGS="-q -n auto --dist=worksteal"
# Simulator layers (vcs/xsim) run a few heavy cases; default to serial + verbose
# + no capture so the compile/elaboration/sim log streams to the terminal.
DEFAULT_SIM_PYTEST_ARGS="-v -s -n 0"

have() { command -v "$1" >/dev/null 2>&1; }

layer_skip() {
    echo "SKIP: $1" >&2
    echo "SIMLINK_LAYER_RESULT=skipped"
    exit 0
}

layer_run() {
    # shellcheck disable=SC2206
    local args=(${PYTEST_ARGS:-$DEFAULT_PYTEST_ARGS})
    local rc=0
    "${PYTEST[@]}" "${args[@]}" "$@" || rc=$?
    echo "SIMLINK_LAYER_RESULT=ran"
    exit "$rc"
}

# rm -rf a sim_build category dir (best-effort) and announce it. Used by the
# simulator layers, which must not reuse artifacts analyzed by a different tool
# version (VCS refuses to mix vlogan versions in one AN.DB).
clean_sim_build() {
    local category="$1"
    local dir="$ROOT/tests/sim_build/simlink/$category"
    if [ -d "$dir" ]; then
        echo "  cleaning $dir"
        rm -rf "$dir"
    fi
}

# Like layer_run, but defaults to the verbose/serial sim args when PYTEST_ARGS
# is unset. Same sentinel + exit-code contract.
layer_run_sim() {
    # shellcheck disable=SC2206
    local args=(${PYTEST_ARGS:-$DEFAULT_SIM_PYTEST_ARGS})
    local rc=0
    "${PYTEST[@]}" "${args[@]}" "$@" || rc=$?
    echo "SIMLINK_LAYER_RESULT=ran"
    exit "$rc"
}
