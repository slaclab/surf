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

# Set Top Level
#TOP=Pgp2Mgt16Tb
#TOP=Pgp2Mgt32Tb
#TOP=Pgp2Mgt64Tb
#TOP=Pgp2Gtp32Tb
#TOP=Pgp2Gtp16Tb
#TOP=Pgp2Gtx16Tb
#TOP=Pgp2RceTb
TOP=Pgp2RegTb

# Set Default Output
SIM_DIR=/u1/pgp2/sim

all: dir syn_setup pack_src smart_src core_src rtl_src tb_src sim_gen
#all: dir syn_setup pack_src smart_src core_src rtl_src tb_src sysc_src sim_gen

#EN64=-full64
EN64=

# Directory
dir:
	mkdir -p $(SIM_DIR)

# Packages
pack_src:
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../rtl/*/*Package.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/tb/*Package.vhd

# RTL Files
rtl_src:
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../rtl/*/*.vhd

# Smart Models
smart_src:
	cd $(SIM_DIR); vhdlan $(EN64) $(XILINX)/smartmodel/$(PLATFORM)/wrappers/vcsmxvhdl/*.vhd

# RTL Files
core_src:
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../xil_cores/*.vhd

# TB Files
tb_src:
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/tb/*.vhd

# System C Files
sysc_src:
	cd $(SIM_DIR); syscan $(EN64) -cpp g++ $(PWD)/sysc/Pgp2VcCmd.cpp
	cd $(SIM_DIR); syscan $(EN64) -cpp g++ $(PWD)/sysc/Pgp2VcFrame.cpp
	cd $(SIM_DIR); syscan $(EN64) -cpp g++ $(PWD)/sysc/Pgp2VcReg.cpp
	cd $(SIM_DIR); syscan $(EN64) -cpp g++ $(PWD)/sysc/Pgp2VcRxModel.cpp
	cd $(SIM_DIR); syscan $(EN64) -cpp g++ $(PWD)/sysc/Pgp2VcTxModel.cpp
	cd $(SIM_DIR); syscan $(EN64) -cpp g++ $(PWD)/sysc/Pgp2PicModel.cpp
	cd $(SIM_DIR); syscan $(EN64) -cpp g++ $(PWD)/sysc/PicFrame.cpp
	cd $(SIM_DIR); syscan $(EN64) -cpp g++ -port $(PWD)/sysc/Pgp2VcTest.map  $(PWD)/sysc/Pgp2VcTest.cpp:Pgp2VcTest
	cd $(SIM_DIR); syscan $(EN64) -cpp g++ -port $(PWD)/sysc/Pgp2LclsRce.map $(PWD)/sysc/Pgp2LclsRce.cpp:Pgp2LclsRce
	cd $(SIM_DIR); syscan $(EN64) -cpp g++ -port $(PWD)/sysc/RceLoop.map     $(PWD)/sysc/RceLoop.cpp:RceLoop

sim_gen:
	cd $(SIM_DIR); vcs $(EN64) $(TOP) -cpp g++ -cc gcc -debug -timescale=1ns/1ps 
	#cd $(SIM_DIR); vcs $(EN64) -sysc $(TOP) -cpp g++ -cc gcc -debug -timescale=1ns/1ps 

clean: 
	rm -rf $(SIM_DIR)/*
	rm -rf $(SIM_DIR)/.synopsys_vss.setup

# Create Synopsis Setup File
syn_setup:
	rm -f $(SIM_DIR)/.synopsys_vss.setup
	echo "UNISIM:$(XIL_SIMLIB)/unisim"                >  $(SIM_DIR)/.synopsys_vss.setup
	echo "XILINXCORELIB:$(XIL_SIMLIB)/xilinxcorelib"  >> $(SIM_DIR)/.synopsys_vss.setup
	echo "SIMPRIM:$(XIL_SIMLIB)/simprim"              >> $(SIM_DIR)/.synopsys_vss.setup
