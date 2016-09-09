
# Define target output
target: dcp

# Define target part
export PRJ_PART = XCKU040-FFVA1156-2-E

export PROJECT = GigEthGthUltraScaleCoreDcp
export TOP_DIR = $(abspath $(PWD))
export MODULES = $(abspath ../../../../../..)

# List of build core directories.
export MODULE_DIRS = $(MODULES)/modules/surf/base  \
                     $(MODULES)/modules/surf/axi  \
                     $(MODULES)/modules/surf/xilinx/general  \
                     $(MODULES)/modules/surf/xilinx/7Series/general  \
                     $(MODULES)/modules/surf/protocols/ssi \
                     $(MODULES)/modules/surf/protocols/srp \
                     $(PROJ_DIR)

# Use top level makefile
include $(MODULES)/ruckus/system_vivado_v1.mk
