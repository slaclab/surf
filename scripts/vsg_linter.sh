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

# Determine number of CPU cores available
if command -v nproc &> /dev/null; then
    NUM_JOBS=$(nproc)
elif [[ "$OSTYPE" == "darwin"* ]]; then
    NUM_JOBS=$(sysctl -n hw.ncpu)
else
    NUM_JOBS=4  # Fallback default
fi

echo "Running VSG in parallel with $NUM_JOBS jobs..."

# Create a temporary directory to hold file lists
TMP_DIR=$(mktemp -d)

# Split included files into chunks
split_size=$(( (${#INCLUDED_FILES[@]} + NUM_JOBS - 1) / NUM_JOBS ))
split_file_list=()
for ((i=0; i<${#INCLUDED_FILES[@]}; i+=split_size)); do
    chunk=("${INCLUDED_FILES[@]:i:split_size}")
    filelist="$TMP_DIR/files_$i.txt"
    printf "%s\n" "${chunk[@]}" > "$filelist"
    split_file_list+=("$filelist")
done

# Disable job control messages to suppress "[N] Done" output
set +m

# Run vsg in parallel, printing only blocks with violations
pids=()
for filelist in "${split_file_list[@]}"; do
    (
        mapfile -t files < "$filelist"
        vsg -f "${files[@]}" -c "$SCRIPT_DIR/../vsg-linter.yml" -of syntastic 2>&1 | tee /dev/stderr
        exit_code=${PIPESTATUS[0]}
        exit $exit_code
    ) &
    pids+=($!)
done

# Wait for all jobs to finish and collect exit statuses
error=0
for pid in "${pids[@]}"; do
    wait "$pid" || error=1
done

# Clean up
rm -rf "$TMP_DIR"

# Final error status based on children
if [[ $error -ne 0 ]]; then
    echo "ERROR: Linting failed (see messages above)"
    return 1 2>/dev/null || exit 1
else
    echo "No issues found"
    return 0 2>/dev/null || exit 0
fi
