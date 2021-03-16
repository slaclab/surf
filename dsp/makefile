GHDL ?= ghdl
GHDLFLAGS=--std=08 -frelaxed --work=surf
CFLAGS=-O3 -Wall
UNISIMDIR=/usr/local/lib/ghdl/

default: test

TBDIR=tb

surf_pkg_files = ../base/general/rtl/StdRtlPkg.vhd
dsp_pkg_files = core/ComplexFixedPkg.vhd
dsp_files = fixed/preAddComplexMult.vhd fixed/cmultAdd.vhd

dsp_tbs = preAddComplexMult_tb cmultAdd_tb


$(dsp_tbs): %: $(surf_pkg_files) $(dsp_pkg_files) $(dsp_files)
	$(GHDL) -c $(GHDLFLAGS) $(surf_pkg_files) $(dsp_pkg_files) $(dsp_files)  $(TBDIR)/$@.vhd -e $@

test: $(dsp_tbs)

_clean:
	rm -f *.o *.cf *_tb $(all)

clean: _clean
