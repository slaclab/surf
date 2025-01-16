ifndef VARIANT
target %:
	$(MAKE) -j Impl@$(@) Stub@$(@)

Impl@%:
	$(MAKE) VARIANT=$(firstword $(subst @, ,$(@))) $(lastword $(subst @, ,$(@)))

Stub@%:
	$(MAKE) VARIANT=$(firstword $(subst @, ,$(@))) $(lastword $(subst @, ,$(@)))
else

VALID_VARIANTS=Impl Stub
ifeq ($(filter $(VALID_VARIANTS),$(VARIANT)),)
  $(error "Invalid variant '$(VARIANT)' -- valid variants are: $(VALID_VARIANTS)")
endif

# Bypass the XVC_DEBUG during surf/ruckus.tcl loading
export BYPASS_XVC_DEBUG = 1

# Define Firmware Version Number
export PRJ_VERSION = 0x00000001

# Define target output
target: dcp

# Define target part
export PRJ_PART = XC7Z045FFG900-2

export PROJECT = UdpDebugBridge$(VARIANT)

# Override the defaults
export TOP_DIR = $(abspath $(PROJ_DIR)/../../../../../../)

# Use top level makefile
include ../../../../../ruckus/system_vivado.mk

IMAGES_DIR=$(PROJ_DIR)/$(VARIANT)/images
endif
