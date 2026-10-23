#!/bin/zsh
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# zsh compatible version of emacs_beautify_all_vhdl.sh for macOS systems where
# zsh is the default user shell.

setopt null_glob

# Get the directory of the script
SCRIPT_DIR="${0:A:h}"

# Define excluded files using an array
EXCLUDE_FILES=()
EXCLUDE_FILES+=("${(@f)$(find "$SCRIPT_DIR/../base/fifo/rtl/xilinx/FifoXpm.vhd" -type f -name "*.vhd")}")
EXCLUDE_FILES+=("${(@f)$(find "$SCRIPT_DIR/../protocols/i2c/rtl/stdlib.vhd" -type f -name "*.vhd")}")
EXCLUDE_FILES+=("${(@f)$(find "$SCRIPT_DIR/../protocols/i2c/rtl/orig" -type f -name "*.vhd")}")

is_excluded() {
   local candidate="$1"
   local excluded_file
   for excluded_file in "${EXCLUDE_FILES[@]}"; do
      if [[ "$candidate" == "$excluded_file" ]]; then
         return 0
      fi
   done
   return 1
}

# Find all .vhd files and filter
FILES=("${(@f)$(find "$SCRIPT_DIR/../" -type f -name "*.vhd")}")

# Process files not in exclude list
for vhd_file in "${FILES[@]}"; do
   if ! is_excluded "$vhd_file"; then
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
