
# Define target output
target: dcp

# Define target part
export PRJ_PART = XC7K325TFFG900-2

export PROJECT = Salt7SeriesCore
export TOP_DIR = $(abspath $(PWD))
export MODULES = $(abspath ../../../../..)

# List of build core directories.
export MODULE_DIRS = $(MODULES)/surf/base  \
		     $(PROJ_DIR)

# Use top level makefile
include $(MODULES)/ruckus/system_vivado_v1.mk
