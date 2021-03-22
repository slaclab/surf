GHDL ?= ghdl
GHDLFLAGS=-P/usr/local/lib/ghdl/xilinx-vivado --std=08 -frelaxed --work=surf
CFLAGS=-O3 -Wall
UNISIMDIR=/usr/local/lib/ghdl/

default: test

TBDIR=tb

surf_pkg_files = ../base/general/rtl/StdRtlPkg.vhd
surf_files = ../base/general/tb/ClkRst.vhd ../base/general/xilinx/Srl16Delay.vhd  ../base/ram/xilinx/SinglePortRamPrimitive.vhd ../base/general/rtl/LutFixedDelay.vhd ../base/general/rtl/SlvFixedDelay.vhd
dsp_pkg_files = core/ComplexFixedPkg.vhd
dsp_files = fixed/SfixedDelay.vhd fixed/PreAddComplexMult.vhd fixed/ComplexMultAdd.vhd fixed/Add3.vhd fixed/IirSimple.vhd fixed/FirAverage.vhd

dsp_tbs = PreAddComplexMult_tb ComplexMultAdd_tb IirSimple_tb FirAverage_tb


$(dsp_tbs): %: $(surf_pkg_files) $(surf_files) $(dsp_pkg_files) $(dsp_files)
	$(GHDL) -c $(GHDLFLAGS) $(surf_pkg_files) $(surf_files) $(dsp_pkg_files) $(dsp_files)  $(TBDIR)/$@.vhd -e $@

test: $(dsp_tbs)

_clean:
	rm -f *.o *.cf *_tb $(all)

clean: _clean
