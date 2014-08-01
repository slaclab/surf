
# Detect project name
export PROJECT = $(notdir $(PWD))

# Project Build Directory
export OUT_DIR  = $(abspath $(TOP_DIR)/build/$(PROJECT))

# Synthesis Variables
export VIVADO_DIR       = $(abspath $(PROJ_DIR)/vivado_hls)
export VIVADO_PROJECT   = $(PROJECT)_project
export VIVADO_DEPEND    = $(OUT_DIR)/$(PROJECT)_project.app
export VIVADO_BUILD_DIR = $(TOP_DIR)/modules/StdLib/build
export SOURCE_DEPEND    = $(OUT_DIR)/$(PROJECT)_sources.txt

# Images Directory
export RTL_DIR = $(abspath $(PROJ_DIR)/rtl)

# Source Files
export SRC_LISTS = $(abspath $(foreach ARG,$(MODULE_DIRS),$(ARG)/sources.txt))
export SRC_FILES = $(abspath $(foreach A1,$(MODULE_DIRS),$(foreach A2,$(shell grep -v "\#" $(A1)/sources.txt),$(A1)/$(A2))))

# Simulation Files
export SIM_LISTS = $(abspath $(foreach ARG,$(MODULE_DIRS),$(ARG)/sim.txt))
export SIM_FILES = $(abspath $(foreach A1,$(MODULE_DIRS),$(foreach A2,$(shell grep -v "\#" $(A1)/sim.txt),$(A1)/$(A2))))

define ACTION_HEADER
@echo 
@echo    ================================================================
@echo    $(1)
@echo    "   Project = $(PROJECT)"
@echo    "   Out Dir = $(OUT_DIR)"
@echo -e "   Changed = $(foreach ARG,$?,$(ARG)\n            )"
@echo    ================================================================
@echo 
endef

.PHONY : all
all: target

.PHONY : test
test:
	@echo PROJECT: $(PROJECT)
	@echo PROJ_DIR: $(PROJ_DIR)
	@echo TOP_DIR: $(TOP_DIR)
	@echo OUT_DIR: $(OUT_DIR)
	@echo RTL_DIR: $(RTL_DIR)
	@echo VIVADO_DIR: $(VIVADO_DIR)
	@echo VIVADO_BUILD_DIR: $(VIVADO_BUILD_DIR)
	@echo VIVADO_PROJECT: $(VIVADO_PROJECT)
	@echo SRC_LISTS: $(SRC_LISTS)
	@echo SRC_FILES: 
	@echo -e "$(foreach ARG,$(SRC_FILES),  $(ARG)\n)"
	@echo SIM_LISTS: $(SIM_LISTS)
	@echo SIM_FILES: 
	@echo -e "$(foreach ARG,$(SIM_FILES),  $(ARG)\n)"

###############################################################
#### Build Location ###########################################
###############################################################
.PHONY : dir
dir:

###############################################################
#### Vivado Project ###########################################
###############################################################
$(VIVADO_DEPEND) :
	$(call ACTION_HEADER,"Making output directory")
	@test -d $(TOP_DIR)/build/ || { \
			 echo ""; \
			 echo "Build directory missing!"; \
			 echo "You must create a build directory at the top level."; \
			 echo ""; \
			 echo "This directory can either be a normal directory:"; \
			 echo "   mkdir $(TOP_DIR)/build"; \
			 echo ""; \
			 echo "Or by creating a symbolic link to a directory on another disk:"; \
			 echo "   ln -s /tmp/build $(TOP_DIR)/build"; \
			 echo ""; false; }
	@test -d $(OUT_DIR) || mkdir $(OUT_DIR)

###############################################################
#### Vivado Sources ###########################################
###############################################################
$(SOURCE_DEPEND) : $(SRC_LISTS) $(SIM_LISTS) $(VIVADO_DEPEND)
	$(call ACTION_HEADER,"Vivado HLS Project Creation and Source Setup")
	@cd $(OUT_DIR); vivado_hls -f $(VIVADO_BUILD_DIR)/vivado_hls_sources_v1.tcl

###############################################################
#### Vivado Batch #############################################
###############################################################
.PHONY : dcp
dcp : $(SRC_FILES) $(SIM_FILES) $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado HLS Build")
	@cd $(OUT_DIR); vivado_hls -f $(VIVADO_BUILD_DIR)/vivado_hls_build_v1.tcl
	@cd $(OUT_DIR); vivado -mode batch -source $(VIVADO_BUILD_DIR)/vivado_hls_dcp_v1.tcl

###############################################################
#### Vivado Interactive #######################################
###############################################################
.PHONY : interactive
interactive : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado HLS Interactive")
	@cd $(OUT_DIR); vivado_hls -f $(VIVADO_BUILD_DIR)/vivado_hls_interactive_v1.tcl

###############################################################
#### Vivado Gui ###############################################
###############################################################
.PHONY : gui
gui : $(SOURCE_DEPEND)
	$(call ACTION_HEADER,"Vivado HLS GUI")
	@cd $(OUT_DIR); vivado_hls -p $(PROJECT)_project

###############################################################
#### Makefile Targets #########################################
###############################################################
.PHONY  : depend
depend  : $(VIVADO_DEPEND)

.PHONY  : sources
sources : $(SOURCE_DEPEND)

###############################################################
#### Clean ####################################################
###############################################################
.PHONY : clean
clean:
	rm -rf $(OUT_DIR)
