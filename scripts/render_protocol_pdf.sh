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
  echo "usage: $0 SPEC_MD OUTPUT_PDF [CSS_FILE]" >&2
  exit 1
fi

if ! command -v pandoc >/dev/null 2>&1; then
  echo "pandoc is required to render protocol specs" >&2
  exit 1
fi

SPEC_MD=$1
OUTPUT_PDF=$2
CSS_FILE=${3:-}
RESOURCE_PATH=$(dirname "$SPEC_MD")
HEADER_FILE=
TEMP_HTML=
TEMP_DIR=
BROWSER_PID=

stop_browser() {
  if [ -n "$BROWSER_PID" ]; then
    kill "$BROWSER_PID" 2>/dev/null || true
    STOP_ATTEMPTS=0
    while kill -0 "$BROWSER_PID" 2>/dev/null && [ "$STOP_ATTEMPTS" -lt 5 ]; do
      sleep 1
      STOP_ATTEMPTS=$((STOP_ATTEMPTS + 1))
    done
    if kill -0 "$BROWSER_PID" 2>/dev/null; then
      kill -KILL "$BROWSER_PID" 2>/dev/null || true
    fi
    wait "$BROWSER_PID" 2>/dev/null || true
    BROWSER_PID=
  fi
}

cleanup() {
  stop_browser
  if [ -n "${HEADER_FILE:-}" ] && [ -f "$HEADER_FILE" ]; then
    rm -f "$HEADER_FILE"
  fi
  if [ -n "${TEMP_HTML:-}" ] && [ -f "$TEMP_HTML" ]; then
    rm -f "$TEMP_HTML"
  fi
  if [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

PDF_ENGINE=${PDF_ENGINE:-}
CHROME_BIN=${CHROME_BIN:-}

find_chrome() {
  for candidate in \
    "$CHROME_BIN" \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
    google-chrome \
    chromium \
    chromium-browser \
    microsoft-edge; do
    if [ -n "$candidate" ] && command -v "$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

if [ -z "$PDF_ENGINE" ]; then
  if CHROME_BIN=$(find_chrome); then
    PDF_ENGINE=chrome
  else
    for candidate in weasyprint wkhtmltopdf pagedjs-cli; do
      if command -v "$candidate" >/dev/null 2>&1; then
        PDF_ENGINE=$candidate
        break
      fi
    done
  fi
elif [ "$PDF_ENGINE" = "chrome" ] || [ "$PDF_ENGINE" = "chromium" ]; then
  if ! CHROME_BIN=$(find_chrome); then
    echo "PDF_ENGINE=$PDF_ENGINE was requested, but no Chrome-compatible browser was found" >&2
    exit 1
  fi
elif ! command -v "$PDF_ENGINE" >/dev/null 2>&1; then
  echo "PDF_ENGINE=$PDF_ENGINE was requested, but it is not in PATH" >&2
  exit 1
fi

render_html() {
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
      --output "$1" \
      "$SPEC_MD"
  else
    pandoc \
      --from gfm+yaml_metadata_block \
      --to html5 \
      --standalone \
      --embed-resources \
      --toc \
      --resource-path="$RESOURCE_PATH" \
      --output "$1" \
      "$SPEC_MD"
  fi
}

if [ "$PDF_ENGINE" = "chrome" ] || [ "$PDF_ENGINE" = "chromium" ]; then
  TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/protocol-spec.XXXXXX")
  TEMP_HTML=$TEMP_DIR/spec.html
  TEMP_PDF=$TEMP_DIR/spec.pdf
  render_html "$TEMP_HTML"
  "$CHROME_BIN" \
    --headless \
    --disable-gpu \
    --no-first-run \
    --no-default-browser-check \
    --disable-background-networking \
    --disable-extensions \
    --user-data-dir="$TEMP_DIR/chrome-profile" \
    --no-pdf-header-footer \
    --print-to-pdf="$TEMP_PDF" \
    "file://$TEMP_HTML" &
  BROWSER_PID=$!

  # Some browser builds remain alive after printing. Wait for a complete PDF,
  # then stop only the isolated browser started by this invocation. Render to a
  # temporary file so a failed invocation cannot replace a previous good PDF.
  RENDER_ATTEMPTS=0
  while [ "$RENDER_ATTEMPTS" -lt 60 ]; do
    if [ -s "$TEMP_PDF" ] && tail -c 32 "$TEMP_PDF" | LC_ALL=C grep -q '^%%EOF'; then
      stop_browser
      mv "$TEMP_PDF" "$OUTPUT_PDF"
      exit 0
    fi
    if ! kill -0 "$BROWSER_PID" 2>/dev/null; then
      wait "$BROWSER_PID" 2>/dev/null || true
      BROWSER_PID=
      echo "Browser exited without producing a complete PDF" >&2
      exit 1
    fi
    sleep 1
    RENDER_ATTEMPTS=$((RENDER_ATTEMPTS + 1))
  done
  echo "Browser did not produce a complete PDF within 60 seconds" >&2
  exit 1
fi

if [ -z "$PDF_ENGINE" ]; then
  echo "No supported PDF engine found." >&2
  echo "Install Google Chrome, Chromium, weasyprint, wkhtmltopdf, or pagedjs-cli." >&2
  echo "Or set PDF_ENGINE or CHROME_BIN to a supported renderer." >&2
  exit 1
fi

if ! command -v "$PDF_ENGINE" >/dev/null 2>&1; then
  echo "PDF_ENGINE=$PDF_ENGINE was requested, but it is not in PATH" >&2
  exit 1
fi

if [ -z "${XDG_CACHE_HOME:-}" ]; then
  XDG_CACHE_HOME=${TMPDIR:-/tmp}/protocol-spec-cache
  export XDG_CACHE_HOME
fi
mkdir -p "$XDG_CACHE_HOME/fontconfig"

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
    --pdf-engine="$PDF_ENGINE" \
    --output "$OUTPUT_PDF" \
    "$SPEC_MD"
else
  pandoc \
    --from gfm+yaml_metadata_block \
    --to html5 \
    --standalone \
    --embed-resources \
    --toc \
    --resource-path="$RESOURCE_PATH" \
    --pdf-engine="$PDF_ENGINE" \
    --output "$OUTPUT_PDF" \
    "$SPEC_MD"
fi
