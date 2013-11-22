
# Detect project name
export PROJECT = $(notdir $(PWD))

# Top level directory
export PROJ_DIR = $(abspath $(PWD))
export TOP_DIR  = $(abspath $(PROJ_DIR)/../..)

# Project Build Directory
export OUT_DIR = $(abspath $(TOP_DIR)/build/$(PROJECT))

# Location of ise synthesis options files
export ISE_DIR = $(abspath $(PROJ_DIR)/ise)

# Images Directory
export IMAGES_DIR = $(abspath $(PROJ_DIR)/images)

# Get Project Version
export PRJ_VERSION = $(shell grep MAKE_VERSION $(PROJ_DIR)/Version.vhd | sed 's|.*x"\(\S\+\)";.*|\1|')

# Core Directories
export CORE_LISTS = $(abspath $(foreach ARG,$(MODULE_DIRS),$(ARG)/coredirs.txt))
export CORE_DIRS  = $(abspath $(foreach A1,$(MODULE_DIRS),$(foreach A2,$(shell grep -v "\#" $(A1)/coredirs.txt),$(A1)/$(A2))))

# Source Files
export SRC_LISTS   = $(abspath $(foreach ARG,$(MODULE_DIRS),$(ARG)/sources.txt))
export RTL_FILES   = $(abspath $(foreach ARG,$(MODULE_DIRS),$(shell grep -v "\#" $(ARG)/sources.txt | sed 's|\(\S\+\)\(\s\+\)\(\S\+\)\(\s\+\)\(\S\+\).*|$(ARG)/\5|')))
export SOURCE_FILE = $(OUT_DIR)/$(PROJECT).src

# UCF Files
export UCF_FILES   = $(abspath $(foreach ARG,$(shell grep -v "\#" $(PROJ_DIR)/constraints.txt | grep "\.ucf"), $(PROJ_DIR)/$(ARG)))

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
	@echo ISE_DIR: $(ISE_DIR)
	@echo XST_OPTIONS_FILE: $(XST_OPTIONS_FILE)
	@echo MODULE_DIRS: $(MODULE_DIRS)
	@echo CORE_LISTS: $(CORE_LISTS)
	@echo CORE_DIRS: $(CORE_DIRS)
	@echo UCF_FILES: 
	@echo -e "$(foreach ARG,$(UCF_FILES),  $(ARG)\n)"
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

%.ucf : 
	@test -d $*.ucf || echo "$*.ucf does not exist"; false;

#### Synthesis #############################################
XST_OPTIONS_FILE = $(ISE_DIR)/xst_options.txt
RTL_CMDS = $(foreach ARG, $(abspath $(MODULE_DIRS)),grep -v "\#" $(ARG)/sources.txt | sed 's|\(\S\+\)\(\s\+\)\(\S\+\)\(\s\+\)\(\S\+\).*|\1 \3 $(ARG)/\5|' >> $(SOURCE_FILE);)
STAMP_CMD = sed 's|\(constant BUILD_STAMP_C : string := \).*|\1\"Built $(shell date) by $(USER)\";|' $(PROJ_DIR)/Version.vhd > $(PROJ_DIR)/Version.new
%.ngc : $(CORE_LISTS) $(SRC_LISTS) $(RTL_FILES) $(XST_OPTIONS_FILE)
	$(call ACTION_HEADER,"Synthesize")
	@$(STAMP_CMD); mv $(PROJ_DIR)/Version.new $(PROJ_DIR)/Version.vhd
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
	@test -d $(OUT_DIR)         || mkdir $(OUT_DIR)
	@test -d $(OUT_DIR)/tmp     || mkdir $(OUT_DIR)/tmp
	@test -d $(OUT_DIR)/xst/    || mkdir $(OUT_DIR)/xst/
	@test -d $(OUT_DIR)/xst/tmp || mkdir $(OUT_DIR)/xst/tmp
	@rm -f $(SOURCE_FILE)
	@touch $(SOURCE_FILE)
	@$(RTL_CMDS)
	@cd $(OUT_DIR); xst -ifn $(XST_OPTIONS_FILE) -ofn $*.srp

#### Chipscope #############################################
%.ngo: %.ngc 
	@echo ""; \
		 echo "Chipscope core does not exist or is out of date!"; \
		 echo "Please generate the core or unset CHIPSCOPE_INSERTER_EN in the target makefile"; \
		 echo ""; \
		 false;

#### Translate #############################################
TRANSLATE_OPTIONS_FILE = $(ISE_DIR)/ngdbuild_options.txt
ifdef CHIPSCOPE_INSERTER_EN  # Set in project makefile to use chipscope core inserter
TRANSLATE_INPUT = .ngo 
else
TRANSLATE_INPUT = .ngc 
endif
%.ngd: %$(TRANSLATE_INPUT) $(UCF_FILES) $(TRANSLATE_OPTIONS_FILE)
	$(call ACTION_HEADER,"Translate")
	@cd $(OUT_DIR);	ngdbuild \
	  -sd $(OUT_DIR) \
	  $(foreach ARG,$(CORE_DIRS),-sd $(abspath $(ARG))) \
	  -f $(TRANSLATE_OPTIONS_FILE) \
	  -dd $(OUT_DIR)/bld \
	  $(foreach ARG,$(UCF_FILES),-uc $(abspath $(ARG))) \
	  $*$(TRANSLATE_INPUT) $*.ngd

#### Map ###################################################
MAP_OPTIONS_FILE = $(ISE_DIR)/map_options.txt
%_map.ncd %.pcf: %.ngd $(MAP_OPTIONS_FILE)
	$(call ACTION_HEADER,"Map")
	@cd $(OUT_DIR); map \
	  -w \
	  -f $(MAP_OPTIONS_FILE) \
	  -o $*_map.ncd \
	  $*.ngd $*.pcf

#### PAR ###################################################
PAR_OPTIONS_FILE = $(ISE_DIR)/par_options.txt
%.ncd: %_map.ncd %.pcf $(PAR_OPTIONS_FILE)
	$(call ACTION_HEADER,"Place and Route")
	@cd $(OUT_DIR); par \
	  -w \
	  -f $(PAR_OPTIONS_FILE) \
	  $*_map.ncd \
	  $*.ncd $*.pcf

#### Trace #################################################
TRCE_OPTIONS_FILE =  $(ISE_DIR)/trce_options.txt
%.twr: %.ncd %.pcf $(TRCE_OPTIONS_FILE)
	$(call ACTION_HEADER,"Trace")
	@cd $(OUT_DIR); trce \
	  -f $(TRCE_OPTIONS_FILE) \
	  -o $*.twr \
	  $*.ncd $*.pcf

#### Bit ###################################################
BIT_OPTIONS_FILE = $(ISE_DIR)/bitgen_options.txt
%.bit: %.ncd $(BIT_OPTIONS_FILE)
	$(call ACTION_HEADER,"Bitgen")
	@cd $(OUT_DIR); bitgen \
	  -f $(BIT_OPTIONS_FILE) \
	  $*.ncd

$(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).bit : $(OUT_DIR)/$(PROJECT).bit
	@cp $< $@
	@echo ""
	@echo "Bit file copied to $@"
	@echo "Don't forget to 'svn commit' when the image is stable!"

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

#### Smart Explorer #############################################
SMART_OPTIONS_FILE = $(ISE_DIR)/smart_options.txt
SMART_HOSTS_FILE   = $(ISE_DIR)/smart_hosts.txt
%.smart: %.ngd $(SMART_OPTIONS_FILE) $(SMART_HOSTS_FILE)
	$(call ACTION_HEADER,"Smart Explorer")
	@cd $(OUT_DIR);	smartxplorer \
     -part $(PRJ_PART) \
     -m $(SMART_MAX_RUNS) \
     -wd $(OUT_DIR)/smart/ \
     -sf $(SMART_OPTIONS_FILE) \
     -l  $(SMART_HOSTS_FILE) \
	  $*.ngd;

#### Makefile Targets ######################################
.PHONY : syn
syn    : $(OUT_DIR)/$(PROJECT).ngc 

.PHONY    : translate
translate : $(OUT_DIR)/$(PROJECT).ngd

.PHONY : smart
smart  : $(OUT_DIR)/$(PROJECT).smart

.PHONY : map
map    : $(OUT_DIR)/$(PROJECT)_map.ncd

.PHONY : par
par    : $(OUT_DIR)/$(PROJECT).ncd

.PHONY : trce
trce   : $(OUT_DIR)/$(PROJECT).twr

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

