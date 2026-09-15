#!/usr/bin/env bash
# Native + common SimLink layer (C/ctypes + protocol/codec). No simulator
# required; the gcc-only lifecycle case self-skips if gcc is absent.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_runner_common.sh"

layer_run tests/simlink/common tests/simlink/native
