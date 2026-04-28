#!/bin/sh
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

cleanup() {
  if [ -n "${HEADER_FILE:-}" ] && [ -f "$HEADER_FILE" ]; then
    rm -f "$HEADER_FILE"
  fi
  if [ -n "${TEMP_HTML:-}" ] && [ -f "$TEMP_HTML" ]; then
    rm -f "$TEMP_HTML"
  fi
}

trap cleanup EXIT

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
  TEMP_HTML=$(mktemp).html
  render_html "$TEMP_HTML"
  "$CHROME_BIN" \
    --headless \
    --disable-gpu \
    --no-pdf-header-footer \
    --print-to-pdf="$OUTPUT_PDF" \
    "file://$TEMP_HTML"
  exit 0
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
