##-----------------------------------------------------------------------------
## File          : sim/Makefile
## Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
## Created       : 04/16/2009
##-----------------------------------------------------------------------------
## Description :
## Makefile for simulation.
##-----------------------------------------------------------------------------
## Copyright (c) 2009 by SLAC. All rights reserved.
## Proprietary and confidential to SLAC.
##-----------------------------------------------------------------------------
## Modification history :
## 04/16/2009: created
##-----------------------------------------------------------------------------

# Set Default Output
SIM_DIR=$(PWD)/build

# Analog netlist
ANA_NET = test_saci_rev2bm.spc

# Shared memory id. Changed this if you need to run multiple instances
# Resulting shared memory file is simlink_username_id
SHM_ID=1
SHM_NAME="saci"

# Set Top Level
DIG_TOP=FrontEndSaciTb
ANA_TOP=FrontEndSaciAnalogTb

# Set 64-bit mode
EN64=-full64

# NS Support files
ANA_INC = $(PWD)/analog/olib_tsmc025.cir \
          $(PWD)/analog/w_si_chip_driver.cir \
          $(PWD)/analog/nanosim_cfg.txt \
          $(PWD)/analog/resis_map.txt

# HDL Source Files
HDL_SRC= $(PWD)/../../StdLib/rtl/StdRtlPkg.vhd \
         $(PWD)/../../StdLib/rtl/SynchronizePkg.vhd \
         $(PWD)/../../StdLib/rtl/RstSync.vhd \
         $(PWD)/../../StdLib/tb/ClkRst.vhd \
         $(PWD)/external/pgp2/rtl/applications/Pgp2RegSlave.vhd \
         $(PWD)/external/pgp2/xil_cores/*.vhd \
	 $(PWD)/external/simlink/SimLinkRx.vhd \
	 $(PWD)/external/simlink/SimLinkTx.vhd \
         $(PWD)/hdl/Pgp2FrontEndSim.vhd \
         $(PWD)/hdl/Version.vhd \
         $(PWD)/../rtl/SaciMasterPkg.vhd \
         $(PWD)/../rtl/SaciMaster.vhd \
         $(PWD)/../rtl/SaciSlave.vhd \
         $(PWD)/hdl/FrontEndPkg.vhd \
         $(PWD)/hdl/FrontEndRegDecoder.vhd \
         $(PWD)/hdl/SaciSlaveRam.vhd \
         $(PWD)/hdl/SaciSlaveWrapper.vhd \
         $(PWD)/hdl/SaciSlaveWrapperAnalog.vhd \
	 $(PWD)/hdl/FrontEndSaciTb.vhd \
	 $(PWD)/hdl/FrontEndSaciAnalogTb.vhd \

# Verilog Source Files
VLOG = $(PWD)/hdl/SaciSlaveAnalog.v 

# Targets
all:    env syn_setup rtl_src vhpi_src sim_dig
analog: dir env syn_setup rtl_src vhpi_src ana_files ana_partition sim_ana

# Directory
dir:
	@mkdir -p $(SIM_DIR)

# RTL Files
rtl_src:
	@cd $(SIM_DIR); vlogan +v2k $(EN64) $(VLOG)
	@cd $(SIM_DIR); vhdlan $(EN64) $(HDL_SRC)

# VHPI Library
vhpi_src:
	@cd $(SIM_DIR); gcc -Wall -c -fPIC -O -DSHM_ID=$(SHM_ID) -DSHM_NAME=\"$(SHM_NAME)\" -I$(VCS_HOME)/include/ $(PWD)/external/simlink/VhpiGeneric.c
	@cd $(SIM_DIR); gcc -Wall -c -fPIC -O -DSHM_ID=$(SHM_ID) -DSHM_NAME=\"$(SHM_NAME)\" -I$(VCS_HOME)/include/ $(PWD)/external/simlink/SimLinkRx.c
	@cd $(SIM_DIR); gcc -Wall -c -fPIC -O -DSHM_ID=$(SHM_ID) -DSHM_NAME=\"$(SHM_NAME)\" -I$(VCS_HOME)/include/ $(PWD)/external/simlink/SimLinkTx.c
	@cd $(SIM_DIR); gcc -Wall -shared -o libSimSw_lib.so VhpiGeneric.o SimLinkRx.o SimLinkTx.o

sim_dig:
	@cd $(SIM_DIR); vcs $(EN64) $(DIG_TOP) -parallel -cpp g++ -cc gcc -lrt -debug -time "ns" -time_res "1ps"

sim_ana:
	@cd $(SIM_DIR); vcs $(EN64) $(ANA_TOP) -parallel -cpp g++ -cc gcc -lrt -debug -time "ns" -time_res "1ps" -nc +ad=$(SIM_DIR)/partition.txt -notice

clean: 
	@rm -rf $(SIM_DIR)/*
	@rm -rf $(SIM_DIR)/.synopsys_vss.setup

# Create Synopsis Setup File
syn_setup:
	@rm -f $(SIM_DIR)/.synopsys_vss.setup
	@echo "UNISIM:$(XIL_SIMLIB)/unisim"                >  $(SIM_DIR)/.synopsys_vss.setup
	@echo "XILINXCORELIB:$(XIL_SIMLIB)/xilinxcorelib"  >> $(SIM_DIR)/.synopsys_vss.setup
	@echo "SIMPRIM:$(XIL_SIMLIB)/simprim"              >> $(SIM_DIR)/.synopsys_vss.setup

# Analog simulation files
ana_files:
	@rm -f $(SIM_DIR)/sim_src
	@cp $(PWD)/analog/$(ANA_NET)  $(SIM_DIR)
	@cp $(ANA_INC)                        $(SIM_DIR)
#	@gzip -df $(SIM_DIR)/*.gz

# Analog partition file
ana_partition:
	@rm -f $(SIM_DIR)/partition.txt
	@echo "partition -cell SaciSlaveAnalog;"                             >  $(SIM_DIR)/partition.txt
	@echo "choose nanosim -A -n $(ANA_NET) -C nanosim_cfg.txt -out wdb;" >> $(SIM_DIR)/partition.txt
	@echo "set bus_format %d;"                                           >> $(SIM_DIR)/partition.txt
	@echo "set rmap resis_map.txt;"                                      >> $(SIM_DIR)/partition.txt

# Create setup env script
env:
	@rm -f $(SIM_DIR)/setup_env.csh
	@echo "limit stacksize 60000"                                 >> $(SIM_DIR)/setup_env.csh
	@echo "setenv LD_LIBRARY_PATH $(SIM_DIR):${LD_LIBRARY_PATH}"  >> $(SIM_DIR)/setup_env.csh

