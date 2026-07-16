//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef ROGUE_DPI_INSTANCE_H
#define ROGUE_DPI_INSTANCE_H

#include <stddef.h>
#include <stdint.h>

typedef enum {
    ROGUE_DPI_STREAM_C,
    ROGUE_DPI_MEMORY_C,
    ROGUE_DPI_SIDEBAND_C,
} RogueDpiModel;

typedef void (*RogueDpiCleanup)(void *data);

void *rogueDpiCreate(RogueDpiModel model,
                     size_t dataSize,
                     RogueDpiCleanup cleanup);

void *rogueDpiGetData(const void *context, RogueDpiModel expectedModel);

int rogueDpiReservePort(const void *context,
                        RogueDpiModel expectedModel,
                        uint16_t requestedPort);

int rogueDpiDestroy(const void *context, RogueDpiModel expectedModel);

#endif
