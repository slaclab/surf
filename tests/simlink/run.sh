#!/usr/bin/env bash
# Orchestrate SimLink test layers. No args runs every layer in order; layers
# whose tools/gates are unavailable are skipped, not failed. Pass layer names
# to run a subset, e.g. `run.sh ghdl vcs`.
#
# Each layer runs in its own process so a sourced env / LD_LIBRARY_PATH from
# one layer cannot leak into the next.
set -uo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
DIR="$ROOT/tests/simlink"

ALL_LAYERS=(native ghdl rogue xsim vcs)

usage() {
    echo "usage: $(basename "$0") [layer ...]   (layers: ${ALL_LAYERS[*]})" >&2
}

# Validate requested layers, default to all.
layers=("$@")
if [ "${#layers[@]}" -eq 0 ]; then
    layers=("${ALL_LAYERS[@]}")
else
    for l in "${layers[@]}"; do
        case " ${ALL_LAYERS[*]} " in
            *" $l "*) ;;
            *) echo "error: unknown layer '$l'" >&2; usage; exit 2 ;;
        esac
    done
fi

declare -A RESULT
declare -A REASON
overall_rc=0
trap 'rm -f "${tmp:-}" "${errtmp:-}"' EXIT

for l in "${layers[@]}"; do
    echo "=============================================================="
    echo "== SimLink layer: $l"
    echo "=============================================================="
    # Capture stdout to a temp file so we can read the sentinel, while still
    # streaming it to the user via tee.  Also capture stderr to errtmp so we
    # can extract the skip reason for the summary; the process substitution
    # here is intentional (NOT a no-op) — it tees stderr to file and terminal.
    tmp="$(mktemp)"
    if [ -z "$tmp" ]; then echo "error: mktemp failed" >&2; exit 3; fi
    errtmp="$(mktemp)"
    if [ -z "$errtmp" ]; then echo "error: mktemp failed" >&2; exit 3; fi
    rc=0
    "$DIR/run-$l.sh" 2> >(tee "$errtmp" >&2) | tee "$tmp" || rc=$?
    # Wait for the async stderr tee to finish writing before we grep errtmp.
    wait
    sentinel="$(grep -E '^SIMLINK_LAYER_RESULT=' "$tmp" | tail -1 | cut -d= -f2)"
    skip_reason="$(grep -E '^SKIP: ' "$errtmp" | tail -1 | sed 's/^SKIP: //')"
    rm -f "$tmp" "$errtmp"

    if [ "$sentinel" = "skipped" ]; then
        RESULT[$l]="SKIPPED"
        REASON[$l]="$skip_reason"
    elif [ "$rc" -eq 0 ]; then
        RESULT[$l]="PASSED"
    else
        RESULT[$l]="FAILED"
        overall_rc=1
    fi
done

echo
echo "==================== SimLink summary ========================="
for l in "${layers[@]}"; do
    printf "  %-8s %s%s\n" "$l" "${RESULT[$l]}" "${REASON[$l]:+  (${REASON[$l]})}"
done
echo "=============================================================="
exit "$overall_rc"
