//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef __SSI_PRINTF__
#define __SSI_PRINTF__

#include "printf.h"
#include <stdarg.h>
#include <stdint.h>

struct ssi_printf_type {
   uint8_t  tmpCnt;
   uint32_t tmp;
   uint32_t buffBase;
   uint16_t buffSize;
   uint16_t buffPtr;
   uint16_t buffTot;
};

void ssi_putc ( void* p, const char c);
void ssi_printf_init(uint32_t buffBase, uint16_t buffSize);

#define ssi_printf(...) tfp_printf (__VA_ARGS__)

#endif
