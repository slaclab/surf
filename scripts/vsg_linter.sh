#!/bin/bash
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Print the VSG version number
vsg --version

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define excluded files using an array
EXCLUDE_FILES=()
while IFS= read -r file; do EXCLUDE_FILES+=("$file"); done < <(find "$SCRIPT_DIR/../base/vhdl-libs" -type f -name "*.vhd")
while IFS= read -r file; do EXCLUDE_FILES+=("$file"); done < <(find "$SCRIPT_DIR/../ethernet/EthMacCore/rtl/EthCrc32Pkg.vhd" -type f -name "*.vhd")
while IFS= read -r file; do EXCLUDE_FILES+=("$file"); done < <(find "$SCRIPT_DIR/../protocols/i2c/rtl/stdlib.vhd" -type f -name "*.vhd")
while IFS= read -r file; do EXCLUDE_FILES+=("$file"); done < <(find "$SCRIPT_DIR/../protocols/i2c/rtl/orig" -type f -name "*.vhd")
while IFS= read -r file; do EXCLUDE_FILES+=("$file"); done < <(find "$SCRIPT_DIR/../protocols/i2c/rtl/i2c_master_byte_ctrl.vhd" -type f -name "*.vhd")
while IFS= read -r file; do EXCLUDE_FILES+=("$file"); done < <(find "$SCRIPT_DIR/../protocols/i2c/rtl/i2c_master_bit_ctrl.vhd" -type f -name "*.vhd")
while IFS= read -r file; do EXCLUDE_FILES+=("$file"); done < <(find "$SCRIPT_DIR/../protocols/i2c/rtl/I2cMaster.vhd" -type f -name "*.vhd")
while IFS= read -r file; do EXCLUDE_FILES+=("$file"); done < <(find "$SCRIPT_DIR/../protocols/i2c/rtl/I2cSlave.vhd" -type f -name "*.vhd")
while IFS= read -r file; do EXCLUDE_FILES+=("$file"); done < <(find "$SCRIPT_DIR/../xilinx/xvc-udp/dcp" -type f -name "*.vhd")
while IFS= read -r file; do EXCLUDE_FILES+=("$file"); done < <(find "$SCRIPT_DIR/../protocols/rssi" -type f -name "*.vhd") # Preventing merge conflict with https://github.com/slaclab/surf/pull/1252 for now

# Build a lookup table using associative array
declare -A EXCLUDE_MAP
for file in "${EXCLUDE_FILES[@]}"; do
    EXCLUDE_MAP["$file"]=1
done

# Gather all non-excluded files into a list
INCLUDED_FILES=()
while IFS= read -r vhd_file; do
    if [[ -z "${EXCLUDE_MAP["$vhd_file"]}" ]]; then
        INCLUDED_FILES+=("$vhd_file")
    else
        echo "Skipping:   $vhd_file"
    fi
done < <(find "$SCRIPT_DIR/../" -type f -name "*.vhd")

# Run vsg on all included files at once
if [[ ${#INCLUDED_FILES[@]} -gt 0 ]]; then
    vsg -f "${INCLUDED_FILES[@]}" -c "$SCRIPT_DIR/../vsg-linter.yml"
else
    echo "No files to lint."
fi
