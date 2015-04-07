
# Define target output
target: dcp

# Define target part
export PRJ_PART = XC7VX690TFFG1761-3

# List of build core directories.
export MODULE_DIRS = $(PROJ_DIR)/../../modules/StdLib  \
                     $(PROJ_DIR)

# Use top level makefile
include ../../modules/StdLib/build/system_vivado_v1.mk
