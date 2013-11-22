
# Detect project name
export PROJECT = $(notdir $(PWD))

# Top level directory
export PROJ_DIR = $(abspath $(PWD))
export TOP_DIR  = $(abspath $(PROJ_DIR)/../..)

# Project Build Directory
export OUT_DIR = $(abspath $(TOP_DIR)/build/$(PROJECT))

# Location of synthesis options files
export VIVADO_DIR   = $(abspath $(PROJ_DIR)/vivado)
export ISE_DIR      = $(abspath $(PROJ_DIR)/ise)
export VIVADO_FILES = $(abspath $(PROJ_DIR)/vivado/pre_synthesis.tcl \
                                $(PROJ_DIR)/vivado/post_synthesis.tcl \
                                $(PROJ_DIR)/vivado/post_route.tcl )

# Images Directory
export IMAGES_DIR = $(abspath $(PROJ_DIR)/images)

# Get Project Version
export PRJ_VERSION = $(shell grep MAKE_VERSION $(PROJ_DIR)/Version.vhd | sed 's|.*x"\(\S\+\)";.*|\1|')

# Core Directories
export CORE_LISTS = $(abspath $(foreach ARG,$(MODULE_DIRS),$(ARG)/cores.txt))
export CORE_FILES = $(abspath $(foreach A1,$(MODULE_DIRS),$(foreach A2,$(shell grep -v "\#" $(A1)/cores.txt),$(A1)/$(A2))))

# Source Files
export SRC_LISTS   = $(abspath $(foreach ARG,$(MODULE_DIRS),$(ARG)/sources.txt))
export RTL_FILES   = $(abspath $(foreach ARG,$(MODULE_DIRS),$(shell grep -v "\#" $(ARG)/sources.txt | sed 's|\(\S\+\)\(\s\+\)\(\S\+\)\(\s\+\)\(\S\+\).*|$(ARG)/\5|')))
export SOURCE_FILE = $(OUT_DIR)/$(PROJECT)_source.tcl

# XDC Files
export XDC_FILES   = $(abspath $(foreach ARG,$(shell grep -v "\#" $(PROJ_DIR)/constraints.txt | grep "\.xdc"), $(PROJ_DIR)/$(ARG)))

define ACTION_HEADER
@echo 
@echo    "============================================================================="
@echo    $(1)
@echo    "   Project = $(PROJECT)"
@echo    "   Out Dir = $(OUT_DIR)"
@echo    "   Version = $(PRJ_VERSION)"
@echo -e "   Changed = $(foreach ARG,$?,$(ARG)\n            )"
@echo    "============================================================================="
@echo 	
endef

.PHONY : all
all: target

.PHONY : test
test:
	@echo PROJECT: $(PROJECT)
	@echo PROJ_DIR: $(PROJ_DIR)
	@echo PRJ_VERSION: $(PRJ_VERSION)
	@echo PRJ_PART: $(PRJ_PART)
	@echo TOP_DIR: $(TOP_DIR)
	@echo OUT_DIR: $(OUT_DIR)
	@echo VIVADO_DIR: $(VIVADO_DIR)
	@echo VIVADO_FILES:
	@echo -e "$(foreach ARG,$(VIVADO_FILES), $(ARG)\n)"
	@echo MODULE_DIRS: $(MODULE_DIRS)
	@echo CORE_LISTS: $(CORE_LISTS)
	@echo CORE_FILES:
	@echo -e "$(foreach ARG,$(CORE_FILES), $(ARG)\n)"
	@echo XDC_FILES: 
	@echo -e "$(foreach ARG,$(XDC_FILES),  $(ARG)\n)"
	@echo SRC_LISTS: $(SRC_LISTS)
	@echo RTL_FILES: 
	@echo -e "$(foreach ARG,$(RTL_FILES),  $(ARG)\n)"

#### Build Location ########################################
.PHONY : dir
dir:

#### Check Source Files ###################################

%.txt : 
	@test -d $*.txt || echo "$*.txt does not exist"; false;

%.vhd : 
	@test -d $*.vhd || echo "$*.vhd does not exist"; false;

%.v : 
	@test -d $*.v || echo "$*.v does not exist"; false;

%.xdc : 
	@test -d $*.xdc || echo "$*.xdc does not exist"; false;

#### Source Generation Commands #############################################
VER_CMDS  = $(foreach ARG, $(abspath $(MODULE_DIRS)), \
   grep "^verilog" $(ARG)/sources.txt | sed 's|^verilog\(\s\+\)\(\S\+\)\(\s\+\)\(\S\+\).*|read_verilog -library \2 $(ARG)/\4|' >> $(SOURCE_FILE);)
VHDL_CMDS = $(foreach ARG, $(abspath $(MODULE_DIRS)), \
	grep "^vhdl" $(ARG)/sources.txt | sed 's|^vhdl\(\s\+\)\(\S\+\)\(\s\+\)\(\S\+\).*|read_vhdl -library \2 $(ARG)/\4|' >> $(SOURCE_FILE);)
CORE_CMDS = $(foreach ARG, $(CORE_FILES),echo add_files $(ARG) >> $(SOURCE_FILE);)
STAMP_CMD = sed 's|\(constant BUILD_STAMP_C : string := \).*|\1\"Built $(shell date) by $(USER)\";|' $(PROJ_DIR)/Version.vhd > $(PROJ_DIR)/Version.new

# Common vivado commands
define VIVADO_PREPARE
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
@rm -f $(SOURCE_FILE)
@touch $(SOURCE_FILE)
@$(VER_CMDS)
@$(VHDL_CMDS)
@$(CORE_CMDS)
endef

#### Vivado Batch #############################################
%.bit : $(CORE_LISTS) $(SRC_LISTS) $(RTL_FILES) $(XDC_FILES) $(CORE_FILES) $(VIVADO_FILES)
	$(call ACTION_HEADER,"Vivado Build")
	@$(STAMP_CMD); mv $(PROJ_DIR)/Version.new $(PROJ_DIR)/Version.vhd
	$(call VIVADO_PREPARE)
	@cd $(OUT_DIR); vivado -mode batch -source $(TOP_DIR)/modules/StdLib/build/build_vivado_v1.tcl

$(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).bit : $(OUT_DIR)/$(PROJECT).bit
	@cp $< $@
	@echo ""
	@echo "Bit file copied to $@"
	@echo "Don't forget to 'svn commit' when the image is stable!"

#### Vivado Interactive #############################################
.PHONY : interactive
interactive : $(CORE_LISTS) $(SRC_LISTS) $(RTL_FILES) $(XDC_FILES) $(CORE_FILES) $(VIVADO_FILES)
	$(call ACTION_HEADER,"Vivado Interactive")
	$(call VIVADO_PREPARE)
	@cd $(OUT_DIR); vivado -mode tcl

#### Vivado GUI #############################################
.PHONY : gui
gui : $(CORE_LISTS) $(SRC_LISTS) $(RTL_FILES) $(XDC_FILES) $(CORE_FILES) $(VIVADO_FILES)
	$(call ACTION_HEADER,"Vivado GUI")
	@$(STAMP_CMD); mv $(PROJ_DIR)/Version.new $(PROJ_DIR)/Version.vhd
	$(call VIVADO_PREPARE)
	@cd $(OUT_DIR); vivado -mode batch -source $(TOP_DIR)/modules/StdLib/build/build_vivado_gui_v1.tcl

#### PROM ##################################################
PROM_OPTIONS_FILE = $(ISE_DIR)/promgen_options.txt
%.mcs: %.bit $(PROM_OPTIONS_FILE)
	$(call ACTION_HEADER,"PROM Generate")
	@cd $(OUT_DIR); promgen \
	  -f $(PROM_OPTIONS_FILE) \
	  -u 0 $*.bit 

$(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).mcs : $(OUT_DIR)/$(PROJECT).mcs
	@cp $< $@
	@echo ""
	@echo "Prom file copied to $@"
	@echo "Don't forget to 'svn commit' when the image is stable!"

#### BitBin ##################################################
%.bitbin: %.bit 
	$(call ACTION_HEADER,"Binary Bit file Generate")
	@cd $(OUT_DIR); promgen -intstyle silent -p bin -data_width 32 -b -w -u 0x0 $*.bit; mv $*.bin $*.bitbin

$(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).bitbin : $(OUT_DIR)/$(PROJECT).bitbin
	@cp $< $@
	@echo ""
	@echo "Binary bit file generated at $@"
	@echo "Don't forget to 'svn commit' when the image is stable!"

#### Makefile Targets ######################################
.PHONY : bit
bit    : $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).bit 

.PHONY : prom
prom   : bit $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).mcs

.PHONY  : bitbin
bitbin  : bit $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).bitbin

#### Clean #################################################
.PHONY : clean
clean:
	rm -rf $(OUT_DIR) 

