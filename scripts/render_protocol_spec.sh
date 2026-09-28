#!/bin/sh
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
set -eu

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "usage: $0 SPEC_MD OUTPUT_HTML [CSS_FILE]" >&2
  exit 1
fi

if ! command -v pandoc >/dev/null 2>&1; then
  echo "pandoc is required to render protocol specs" >&2
  exit 1
fi

SPEC_MD=$1
OUTPUT_HTML=$2
CSS_FILE=${3:-}
RESOURCE_PATH=$(dirname "$SPEC_MD")
HEADER_FILE=

cleanup() {
  if [ -n "${HEADER_FILE:-}" ] && [ -f "$HEADER_FILE" ]; then
    rm -f "$HEADER_FILE"
  fi
}

trap cleanup EXIT

if [ -n "$CSS_FILE" ]; then
  HEADER_FILE=$(mktemp)
  {
    printf '<style>\n'
    cat "$CSS_FILE"
    printf '\n</style>\n'
  } >"$HEADER_FILE"

  pandoc \
    --from gfm+yaml_metadata_block \
    --to html5 \
    --standalone \
    --embed-resources \
    --toc \
    --resource-path="$RESOURCE_PATH" \
    --include-in-header="$HEADER_FILE" \
    --output "$OUTPUT_HTML" \
    "$SPEC_MD"
else
  pandoc \
    --from gfm+yaml_metadata_block \
    --to html5 \
    --standalone \
    --embed-resources \
    --toc \
    --resource-path="$RESOURCE_PATH" \
    --output "$OUTPUT_HTML" \
    "$SPEC_MD"
fi
