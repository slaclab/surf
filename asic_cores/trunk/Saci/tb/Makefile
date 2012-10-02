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
SIM_DIR=/u1/bareese/kpix/sim/newsimrun

# Analog netlist
ANA_NET = kpix_b_trunc2.cir

# Shared memory id. Changed this if you need to run multiple instances
# Resulting shared memory file is simlink_username_id
SHM_ID=1

# Set Top Level
DIG_TOP=SmallTb
ANA_TOP=AnalogTb

# Set 64-bit mode
EN64=-full64

# NS Support files
ANA_INC = $(PWD)/analog/olib_tsmc025.cir \
          $(PWD)/analog/w_si_chip_driver.cir \
          $(PWD)/analog/nanosim_cfg.txt \
          $(PWD)/analog/resis_map.txt

# HDL Source Files
HDL_SRC= $(PWD)/../firmware/modules/StdLib/rtl/StdRtlPkg.vhd \
         $(PWD)/../firmware/modules/StdLib/rtl/SynchronizePkg.vhd \
         $(PWD)/../firmware/modules/StdLib/rtl/RstSync.vhd \
	 $(PWD)/../firmware/projects/KpixSmall/rtl/Version.vhd \
         $(PWD)/../firmware/modules/KpixDaq/rtl/KpixPkg.vhd \
	 $(PWD)/../firmware/modules/KpixCore/rtl/reg_rw_32.vhd \
	 $(PWD)/../firmware/modules/KpixCore/rtl/command_control.vhd \
	 $(PWD)/../firmware/modules/KpixCore/rtl/analog_control.vhd \
	 $(PWD)/../firmware/modules/KpixCore/rtl/readout_control.vhd \
	 $(PWD)/../firmware/modules/KpixCore/rtl/memory_array_control.vhd \
	 $(PWD)/../firmware/modules/eth_client/xil_cores/*.vhd \
	 $(PWD)/../firmware/modules/eth_client/rtl/1g/EthRegSlave.vhd \
	 $(PWD)/../firmware/modules/eth_client/rtl/1g/EthCmdSlave.vhd \
	 $(PWD)/../firmware/modules/KpixDaq/xil_cores/*.vhd \
         $(PWD)/../firmware/modules/KpixDaq/rtl/UsBuff64.vhd \
         $(PWD)/hdl/EthFrontEndSim.vhd \
         $(PWD)/../firmware/modules/KpixDaq/rtl/KpixRegRxPkg.vhd \
         $(PWD)/../firmware/modules/KpixDaq/rtl/KpixRegRx.vhd \
         $(PWD)/../firmware/modules/KpixDaq/rtl/KpixDataRxPkg.vhd \
         $(PWD)/../firmware/modules/KpixDaq/rtl/KpixDataRx.vhd \
         $(PWD)/../firmware/modules/KpixDaq/rtl/KpixLocalPkg.vhd \
         $(PWD)/../firmware/modules/KpixDaq/rtl/KpixLocal.vhd \
         $(PWD)/../firmware/modules/KpixDaq/rtl/KpixClockGenPkg.vhd \
         $(PWD)/../firmware/modules/KpixDaq/rtl/KpixClockGen.vhd \
         $(PWD)/../firmware/modules/KpixDaq/rtl/FrontEndPkg.vhd \
         $(PWD)/../firmware/modules/KpixDaq/rtl/TriggerPkg.vhd \
         $(PWD)/../firmware/modules/KpixDaq/rtl/Trigger.vhd \
         $(PWD)/../firmware/modules/KpixDaq/rtl/FrontEndRegDecoder.vhd \
         $(PWD)/../firmware/modules/KpixDaq/rtl/EventBuilderFifoPkg.vhd \
         $(PWD)/../firmware/modules/KpixDaq/rtl/EventBuilder.vhd \
         $(PWD)/../firmware/modules/KpixDaq/rtl/KpixRegCntlPkg.vhd \
         $(PWD)/../firmware/modules/KpixDaq/rtl/KpixRegCntl.vhd \
         $(PWD)/../firmware/modules/KpixDaq/rtl/KpixDaqCore.vhd \
	 $(PWD)/../firmware/projects/KpixSmall/xil_cores/*.vhd \
	 $(PWD)/../firmware/projects/KpixSmall/rtl/KpixSmall.vhd \
	 $(PWD)/hdl/AnalogReg.vhd \
	 $(PWD)/hdl/DataRead.vhd \
	 $(PWD)/hdl/AsicSim.vhd \
	 $(PWD)/hdl/SmallTb.vhd

# Verilog Source Files
VLOG = $(PWD)/hdl/AsicSimAnalog.v 

# Targets
all:    dir syn_setup rtl_src sysc_src sim_dig
analog: dir syn_setup rtl_src sysc_src ana_files ana_partition sim_ana

# Directory
dir:
	@mkdir -p $(SIM_DIR)

# RTL Files
rtl_src:
	@cd $(SIM_DIR); vhdlan $(EN64) $(HDL_SRC)
	@cd $(SIM_DIR); vlogan +v2k $(EN64) $(VLOG)

# System C Files
sysc_src:
	@cd $(SIM_DIR); syscan $(EN64) -cpp g++ -cflags "-DSHM_ID=$(SHM_ID)" -port $(PWD)/sysc/SimLinkRx.map $(PWD)/sysc/SimLinkRx.cpp:SimLinkRx
	@cd $(SIM_DIR); syscan $(EN64) -cpp g++ -cflags "-DSHM_ID=$(SHM_ID)" -port $(PWD)/sysc/SimLinkTx.map $(PWD)/sysc/SimLinkTx.cpp:SimLinkTx

sim_dig:
	@cd $(SIM_DIR); vcs $(EN64) -sysc $(DIG_TOP) -cpp g++ -cc gcc -lrt -debug_all -timescale=1ns/1ps 

sim_ana:
	@cd $(SIM_DIR); vcs $(EN64) -sysc $(ANA_TOP) -cpp g++ -cc gcc -lrt -debug -timescale=1ns/1ps -nc +ad=$(SIM_DIR)/partition.txt

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
	@cp $(PWD)/../netlists/$(ANA_NET).gz  $(SIM_DIR)
	@cp $(ANA_INC)                        $(SIM_DIR)
	@gzip -df $(SIM_DIR)/*.gz

# Analog partition file
ana_partition:
	@rm -f $(SIM_DIR)/partition.txt
	@echo "partition -cell AsicSimAnalog;"                               >  $(SIM_DIR)/partition.txt
	@echo "choose nanosim -A -n $(ANA_NET) -C nanosim_cfg.txt -out wdb;" >> $(SIM_DIR)/partition.txt
	@echo "set bus_format %d;"                                           >> $(SIM_DIR)/partition.txt
	@echo "set rmap resis_map.txt;"                                      >> $(SIM_DIR)/partition.txt

