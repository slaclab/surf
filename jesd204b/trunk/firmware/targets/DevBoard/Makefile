# Define target output
target: prom

# Define target part
export PRJ_PART = XC7K325TFFG900-2

# List of build core directories.
export MODULE_DIRS = $(PROJ_DIR)/../../modules/StdLib  \
                     $(PROJ_DIR)/../../modules/MgtLib/gtx7  \
                     $(PROJ_DIR)/../../modules/Pgp2bCore/core  \
                     $(PROJ_DIR)/../../modules/Pgp2bCore/gtx7  \
                     $(PROJ_DIR)/../../modules/Jesd204bCore  \
                     $(PROJ_DIR)

# Use top level makefile
include ../../modules/StdLib/build/system_vivado_v1.mk


