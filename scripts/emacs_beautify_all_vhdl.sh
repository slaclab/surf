#!/bin/bash
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define excluded files using an array
EXCLUDE_FILES=()
while IFS= read -r file; do EXCLUDE_FILES+=("$file"); done < <(find "$SCRIPT_DIR/../base/fifo/rtl/xilinx/FifoXpm.vhd" -type f -name "*.vhd")
while IFS= read -r file; do EXCLUDE_FILES+=("$file"); done < <(find "$SCRIPT_DIR/../protocols/i2c/rtl/stdlib.vhd" -type f -name "*.vhd")
while IFS= read -r file; do EXCLUDE_FILES+=("$file"); done < <(find "$SCRIPT_DIR/../protocols/i2c/rtl/orig" -type f -name "*.vhd")

# Manually add a specific file to the exclude list
EXCLUDE_FILES+=("$SCRIPT_DIR/../protocols/packetizer/rtl/AxiStreamDepacketizer2.vhd")

# Build a lookup table using associative array
declare -A EXCLUDE_MAP
for file in "${EXCLUDE_FILES[@]}"; do
    EXCLUDE_MAP["$file"]=1
done

# Find all .vhd files and filter
FILES=$(find "$SCRIPT_DIR/../" -type f -name "*.vhd")

# Process files not in exclude list
echo "$FILES" | while read -r vhd_file; do
  if [[ -z "${EXCLUDE_MAP["$vhd_file"]}" ]]; then
    echo "Processing: $vhd_file"
    emacs --batch "$vhd_file" \
        -l "$SCRIPT_DIR/../.emacs" \
        -f vhdl-beautify-buffer \
        -f vhdl-update-sensitivity-list-buffer \
        -f save-buffer
  else
    echo "Skipping:   $vhd_file"
  fi
done

