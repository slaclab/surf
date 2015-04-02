# Template setup_env.csh script. You should make a copy of this and 
# rename it to setup_env.csh after checkout

# Base directory
setenv BASE ${PWD}

# QT Base Directory
setenv QTDIR   /afs/slac/g/reseng/qt/qt_4.7.4_x64
setenv QWTDIR  /afs/slac/g/reseng/qt/qwt_6.0_x64

# Root base directory
setenv ROOTSYS /afs/slac/g/reseng/root/root_5.20_x64

# Epics base
setenv EPICS_BASE /u1/epics/base-3.14.12.2/

# EVIO base
setenv EVIO_BASE /afs/slac.stanford.edu/u/ey/rherbst/projects/heavyp/evio
setenv BMS_HOME  /afs/slac.stanford.edu/u/ey/rherbst/projects/heavyp/BMS

# Setup path
if ($?PATH) then
   setenv PATH ${EPICS_BASE}/bin/linux-x86_64:${BASE}/bin:${ROOTSYS}/bin:${QTDIR}/bin:${PATH}
else
   setenv PATH ${EPICS_BASE}/bin/linux-x86_64:${BASE}/bin:${ROOTSYS}/bin:${QTDIR}/bin
endif

# Setup library path
if ($?LD_LIBRARY_PATH) then
   setenv LD_LIBRARY_PATH ${EVIO_BASE}/Linux-x86_64/lib:${EPICS_BASE}/lib/linux-x86_64:${ROOTSYS}/lib:${QTDIR}/lib:${QWTDIR}/lib:${LD_LIBRARY_PATH}
else
   setenv LD_LIBRARY_PATH ${EVIO_BASE}/Linux-x86_64/lib:${EPICS_BASE}/lib/linux-x86_64:${ROOTSYS}/lib:${QTDIR}/lib:${QWTDIR}/lib:
endif

