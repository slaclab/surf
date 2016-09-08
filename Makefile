
# Define target output
target: dcp

# Define target part
export PRJ_PART = XC7VX690TFFG1761-3

# List of build core directories.
export MODULE_DIRS = $(PROJ_DIR)/../../modules/surf/base  \
                     $(PROJ_DIR)/../../modules/surf/axi  \
                     $(PROJ_DIR)/../../modules/surf/xilinx/general  \
                     $(PROJ_DIR)/../../modules/surf/xilinx/7Series/general  \
                     $(PROJ_DIR)/../../modules/surf/protocols/ssi \
                     $(PROJ_DIR)/../../modules/surf/protocols/srp \
                     $(PROJ_DIR)

# Use top level makefile
include ../../modules/ruckus/system_vivado_v1.mk
