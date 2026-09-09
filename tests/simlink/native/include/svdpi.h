//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
//
// Minimal native-test subset of Vivado's svdpi.h. Production xsim builds use
// the simulator-provided header; this file only lets host-gcc lifecycle tests
// compile the DPI adapters on systems without Vivado.
//////////////////////////////////////////////////////////////////////////////

#ifndef SURF_TEST_SVDPI_H
#define SURF_TEST_SVDPI_H

#include <stdint.h>

typedef unsigned char svBit;
typedef uint32_t svBitVecVal;

#endif
