GHDL ?= /usr/local/bin/ghdl
GHDLFLAGS=-P/usr/local/lib/ghdl/xilinx-vivado --std=08 -frelaxed --work=surf
CFLAGS=-O3 -fPIE
UNISIMDIR=/usr/local/lib/ghdl/

default: test

TBDIR=tb

SURF_DIR=../

surf_files = $(shell find $(SURF_DIR) -type f -name '*StdRtlPkg.vhd') \
$(shell find $(SURF_DIR) -type f -name '*ComplexFixedPkg.vhd') \
$(shell find $(SURF_DIR) -type f -name '*Synchronizer.vhd') \
$(shell find $(SURF_DIR) -type f -name '*SynchronizerVector.vhd') \
$(shell find $(SURF_DIR) -type f -name '*RstSync.vhd') \
$(shell find $(SURF_DIR) -type f -name '*SynchronizerEdge.vhd') \
$(shell find $(SURF_DIR) -type f -name '*SynchronizerOneShot.vhd') \
$(shell find $(SURF_DIR) -type f -name '*ClkRst.vhd') \
$(shell find $(SURF_DIR) -type f -name '*SlvDelay.vhd') \
$(shell find $(SURF_DIR) -type f -name '*SlvDelayRam.vhd') \
$(shell find $(SURF_DIR) -type f -name '*Srl16Delay.vhd') \
$(shell find $(SURF_DIR) -type f -name '*SinglePortRamPrimitive.vhd') \
$(shell find $(SURF_DIR) -type f -name '*LutFixedDelay.vhd') \
$(shell find $(SURF_DIR) -type f -name '*SlvFixedDelay.vhd') \
$(shell find $(SURF_DIR) -type f -name '*SimpleDualPortRam.vhd') \
$(shell find $(SURF_DIR) -type f -name '*SfixedDelay.vhd') \
$(shell find $(SURF_DIR) -type f -name '*CfixedDelay.vhd') \
$(shell find $(SURF_DIR) -type f -name '*Csa3.vhd') \
$(shell find $(SURF_DIR) -type f -name '*Add3.vhd') \
$(shell find $(SURF_DIR) -type f -name '*SfixedMultAdd.vhd') \
$(shell find $(SURF_DIR) -type f -name '*SfixedMult.vhd') \
$(shell find $(SURF_DIR) -type f -name '*CfixedMultAdd.vhd') \
$(shell find $(SURF_DIR) -type f -name '*CfixedMult.vhd') \
$(shell find $(SURF_DIR) -type f -name '*CfixedPreAddMult.vhd') \
$(shell find $(SURF_DIR) -type f -name '*IirSimple.vhd') \
$(shell find $(SURF_DIR) -type f -name '*FirAverage.vhd') \
$(shell find $(SURF_DIR) -type f -name '*SinCosLut.vhd') \
$(shell find $(SURF_DIR) -type f -name '*SinCosTaylor.vhd')


dspTbs = CfixedPreAddMultTb \
CfixedMultAddTb \
IirSimpleTb \
FirAverageTb \
SinCosLutTb \


$(dspTbs): %: $(surf_files)
	$(GHDL) -c $(CFLAGS) $(GHDLFLAGS) $(surf_files) $(TBDIR)/$@.vhd -e $@

test: $(dspTbs)

_clean:
	rm -f *.o *.cf *Tb $(all)

clean: _clean
