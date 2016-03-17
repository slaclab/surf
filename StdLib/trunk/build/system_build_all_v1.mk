
export BUILD_SCRIPT_DIR  = $(dir $(BUILD_SCRIPT))
export BUILD_SCRIPT_NAME = $(notdir $(BUILD_SCRIPT))

export SETUP_DIR  = $(dir $(SETUP_ENV))
export SETUP_NAME = $(notdir $(SETUP_ENV))

.PHONY: all build clean

# Default
all: build

# Check variables
test:
	@echo PARALLEL_BUILD:    $(PARALLEL_BUILD)
	@echo BUILD_SCRIPT:      $(BUILD_SCRIPT)
	@echo BUILD_SCRIPT_DIR:  $(BUILD_SCRIPT_DIR)
	@echo BUILD_SCRIPT_NAME: $(BUILD_SCRIPT_NAME)
	@echo SETUP_ENV:         $(SETUP_ENV)
	@echo SETUP_DIR:         $(SETUP_DIR)
	@echo SETUP_NAME:        $(SETUP_NAME)
	@echo TARGET_DIRS:
	@echo -e "$(foreach ARG,$(TARGET_DIRS),\t$(ARG)\n)"

# Clean all firmware builds
clean:
	for i in $(TARGET_DIRS); do \
      cd $$i; make clean; \
   done

# Build targets
build:
	@tclsh $(BUILD_SCRIPT_DIR)/system_build_all_v1.tcl
