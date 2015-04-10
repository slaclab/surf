
# Define target output
target: dcp

# Set CFLAGs and LDFLAGs
export CFLAGS  = 
export LDFLAGS = 

# Set TOP_DIR to be the base directory for which the build directory resides
export PROJ_DIR = $(abspath $(PWD))
export BASE_DIR = $(abspath $(PWD)/..)
export TOP_DIR  = $(abspath $(PWD)/../../..)

# Use top level makefile
include $(TOP_DIR)/modules/StdLib/build/system_vivado_hls_v1.mk
