# Define target output
target: prom

# Define target part
export PRJ_PART = XC7A100TFGG676-3

# List of build core directories.
export MODULE_DIRS = $(PROJ_DIR)/../../modules/StdLib  \
                     $(PROJ_DIR)/../../modules/MgtLib/gtp7  \
                     $(PROJ_DIR)/../../modules/pgp2b_core/core  \
                     $(PROJ_DIR)/../../modules/pgp2b_core/gtp7  \
                     $(PROJ_DIR)/../../modules/Jesd204bCore  \
                     $(PROJ_DIR)/../../modules/DeviceLib/AxiMicronP30Core  \
                     $(PROJ_DIR)

# Max number of smart explorer runs
export SMART_MAX_RUNS = 20

# Use top level makefile
include ../../modules/StdLib/build/system_vivado_v1.mk




# Project Name
#export PROJECT = $(notdir $(PWD))

# List of build core directories. Relative to current directory.
#export CORE_DIRS = $(abspath xil_cores ../../modules/pgp2_core/xil_cores)

#include ../../xilinx_common.mk

