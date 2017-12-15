export GIT_BYPASS = 1

# Define target output
target: dcp

# Define target part
export PRJ_PART = XCKU11P-FFVA1156-3-E

export PRJ_VERSION = 0x00000001
export PROJECT = GigEthGthUltraScaleCoreDcp
export TOP_DIR = $(abspath $(PWD))
export MODULES = $(abspath ../../../../..)

# List of build core directories.
export MODULE_DIRS = $(PROJ_DIR)

# Use top level makefile
include $(MODULES)/ruckus/system_vivado.mk
