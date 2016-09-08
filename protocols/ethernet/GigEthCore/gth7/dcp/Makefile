
# Define target output
target: dcp

# Define target part
export PRJ_PART = XC7VX690TFFG1761-3

export PROJECT = GigEthGth7CoreDcp
export TOP_DIR = $(abspath $(PWD))
export MODULES = $(abspath ../../../../../..)

# List of build core directories.
export MODULE_DIRS = $(MODULES)/surf/base  \
                     $(MODULES)/surf/axi  \
                     $(MODULES)/surf/xilinx/general  \
                     $(MODULES)/surf/xilinx/7Series/general  \
                     $(MODULES)/surf/protocols/ssi \
                     $(MODULES)/surf/protocols/srp \
                     $(PROJ_DIR)

# Use top level makefile
include $(MODULES)/ruckus/system_vivado_v1.mk
