#TOP=stream_tb
#TOP=dma_tb
#TOP=vcs_tb
TOP=fifo_tb
#TOP=fifo_128_tb
#TOP=mytb

# Set Default Output
SIM_DIR=$(PWD)/out

all: env syn_setup rtl_src vhpi_src sim_gen

EN64=-full64 -xlrm

# Shared memory id. Changed this if you need to run multiple instances
# Resulting shared memory file is simlink_username_id

# RTL Files
rtl_src:
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../general/tb/glbl.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../general/rtl/StdRtlPkg.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../sync/rtl/Synchronizer.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../sync/rtl/SynchronizerEdge.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../sync/rtl/SynchronizerVector.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../sync/rtl/RstSync.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../sync/rtl/SynchronizerOneShot.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../ram/rtl/SimpleDualPortRam.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../fifo/rtl/FifoOutputPipeline.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../fifo/rtl/FifoAsyncBuiltIn.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../fifo/rtl/FifoSyncBuiltIn.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../fifo/rtl/FifoAsync.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../fifo/rtl/FifoSync.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../fifo/rtl/Fifo.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../fifo/rtl/FifoCascade.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../fifo/rtl/FifoMux.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../sync/rtl/SynchronizerFifo.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../general/rtl/ArbiterPkg.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../general/rtl/Arbiter.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../general/rtl/PrbsPkg.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiPkg.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiWritePathFifo.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiWritePathMux.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiReadPathFifo.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiReadPathMux.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiLitePkg.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiToAxiLite.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiLiteCrossbar.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiLiteEmpty.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiLiteFifoPush.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiLiteFifoPushPop.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiLiteFifoPop.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiStreamPkg.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/SsiPkg.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiStreamPipeline.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiStreamFifo.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiStreamShift.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiDmaPkg.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiStreamDmaWrite.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiStreamDmaRead.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiStreamDma.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiStreamMux.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/AxiStreamDeMux.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/SsiAxiLiteMaster.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/SsiCmdMasterPkg.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../axi/rtl/SsiCmdMaster.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../simlink/rtl/AxiStreamSimIb.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../simlink/rtl/AxiStreamSimOb.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../simlink/rtl/AxiStreamSim.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../simlink/rtl/AxiSimMaster.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../simlink/rtl/AxiSimMasterWrap.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../simlink/rtl/AxiSimSlave.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../simlink/rtl/AxiSimSlaveWrap.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../pgp2b_core/core/rtl/Pgp2bPkg.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../pgp2b_core/core/simlink/rtl//PgpSimModel.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../i2c_core/rtl/stdlib.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../i2c_core/rtl/I2cPkg.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../i2c_core/rtl/I2cSlave.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../i2c_core/rtl/I2cRegSlave.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../i2c_core/rtl/i2c_master_bit_ctrl.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../i2c_core/rtl/i2c_master_byte_ctrl.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../i2c_core/rtl/I2cMaster.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../i2c_core/rtl/I2cRegMaster.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../i2c_core/rtl/I2cRegMasterMux.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../i2c_core/rtl/I2cRegMasterAxiBridge.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../tb/dma_tb.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../tb/vcs_tb.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../tb/fifo_tb.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../tb/stream_tb.vhd

# VHPI Library
vhpi_src:
	@cd $(SIM_DIR); gcc -Wall -c -fPIC -O -I$(VCS_HOME)/include/ -I$(PWD)/../../general/simlink/src $(PWD)/../../general/simlink/src/VhpiGeneric.c
	@cd $(SIM_DIR); gcc -Wall -c -fPIC -O -I$(VCS_HOME)/include/ -I$(PWD)/../../general/simlink/src $(PWD)/../simlink/src/AxiStreamSimOb.c 
	@cd $(SIM_DIR); gcc -Wall -c -fPIC -O -I$(VCS_HOME)/include/ -I$(PWD)/../../general/simlink/src $(PWD)/../simlink/src/AxiStreamSimIb.c
	@cd $(SIM_DIR); gcc -Wall -c -fPIC -O -I$(VCS_HOME)/include/ -I$(PWD)/../../general/simlink/src $(PWD)/../simlink/src/AxiSimMaster.c
	@cd $(SIM_DIR); gcc -Wall -c -fPIC -O -I$(VCS_HOME)/include/ -I$(PWD)/../../general/simlink/src $(PWD)/../simlink/src/AxiSimSlave.c
	@cd $(SIM_DIR); gcc -Wall -shared -o libAxiSim.so VhpiGeneric.o AxiStreamSimOb.o AxiStreamSimIb.o AxiSimMaster.o AxiSimSlave.o

sim_gen:
	cd $(SIM_DIR); vcs $(EN64) $(TOP) -cpp g++ -cc gcc -debug -lrt -timescale=1ps/1ps -sim_res=1ps

clean: 
	rm -rf $(SIM_DIR)/*
	rm -rf $(SIM_DIR)/.synopsys_vss.setup

# Create Synopsis Setup File
syn_setup:
	rm -f $(SIM_DIR)/.synopsys_vss.setup
	echo "UNISIM:$(XIL_SIMLIB)/unisim"                >  $(SIM_DIR)/.synopsys_vss.setup
	echo "UNIMACRO:$(XIL_SIMLIB)/unimacro"            >> $(SIM_DIR)/.synopsys_vss.setup
	echo "XILINXCORELIB:$(XIL_SIMLIB)/xilinxcorelib"  >> $(SIM_DIR)/.synopsys_vss.setup
	echo "SIMPRIM:$(XIL_SIMLIB)/simprim"              >> $(SIM_DIR)/.synopsys_vss.setup

# Create setup env script
env:
	@rm -f $(SIM_DIR)/setup_env.csh
	@echo "limit stacksize 60000"                                 >> $(SIM_DIR)/setup_env.csh
	@echo "setenv LD_LIBRARY_PATH $(SIM_DIR):${LD_LIBRARY_PATH}"  >> $(SIM_DIR)/setup_env.csh

