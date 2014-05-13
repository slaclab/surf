TOP=tb

# Set Default Output
SIM_DIR=$(PWD)/out

all: syn_setup rtl_src sim_gen

EN64=-full64 -xlrm

# RTL Files
rtl_src:
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/general/tb/glbl.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/general/rtl/StdRtlPkg.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/sync/rtl/Synchronizer.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/sync/rtl/RstSync.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/sync/rtl/SynchronizerEdge.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/sync/rtl/SynchronizerVector.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/ram/rtl/SimpleDualPortRam.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/fifo/rtl/FifoOutputPipeline.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/fifo/rtl/FifoAsyncBuiltIn.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/fifo/rtl/FifoSyncBuiltIn.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/fifo/rtl/FifoAsync.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/fifo/rtl/FifoSync.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/fifo/rtl/Fifo.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/fifo/rtl/FifoCascade.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/fifo/rtl/FifoMux.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/sync/rtl/SynchronizerFifo.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/sync/rtl/SynchronizerOneShot.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/sync/rtl/SynchronizerOneShotCnt.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/sync/rtl/SynchronizerOneShotCntVector.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/sync/rtl/SynchronizerFifo.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/sync/rtl/SynchronizerFifo.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/sync/rtl/SyncStatusVector.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/general/rtl/ArbiterPkg.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/general/rtl/Arbiter.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/general/rtl/PrbsPkg.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/general/rtl/CRC32Rtl.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/axi/rtl/AxiLitePkg.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/xilinx7/rtl/DeviceDna.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/axi/rtl/AxiLiteCrossbar.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/axi/rtl/AxiLiteAsync.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/axi/rtl/AxiStreamPkg.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/axi/rtl/AxiStreamDeMux.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/axi/rtl/AxiStreamPipeline.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/axi/rtl/AxiStreamFifo.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/axi/rtl/SsiPkg.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/axi/rtl/SsiPrbsTx.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../../../StdLib/axi/rtl/SsiPrbsRx.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/..//rtl/Pgp2bPkg.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/..//rtl/Pgp2bRxPhy.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/..//rtl/Pgp2bRxCell.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/..//rtl/Pgp2bRx.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/..//rtl/Pgp2bTxPhy.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/..//rtl/Pgp2bTxCell.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/..//rtl/Pgp2bTxSched.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/..//rtl/Pgp2bTx.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/..//rtl/Pgp2bLane.vhd
	cd $(SIM_DIR); vhdlan $(EN64) $(PWD)/../tb/tb.vhd

sim_gen:
	cd $(SIM_DIR); vcs $(EN64) $(TOP) -cpp g++ -cc gcc -debug -lrt -timescale=1ns/1ps -sim_res=1ps

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
