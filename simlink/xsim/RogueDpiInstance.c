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
// Thin xsim/DPI ownership adapter over the simulator-neutral instance
// registry. SystemVerilog retains the returned pointer as a chandle; all
// validation, port-pair ownership, cleanup, and process-exit fallback remain
// centralized in RogueSimLinkInstance.c.
//////////////////////////////////////////////////////////////////////////////

#include "RogueDpiInstance.h"

#include <stdio.h>

static void rogueDpiReport(const char* message) {
    fputs(message, stderr);
}

void* rogueDpiCreate(const RogueSimLinkModelDescriptor* model, size_t dataSize, RogueDpiCleanup cleanup) {
    // DPI chandle is pointer-sized, so the registry object itself is the
    // opaque context retained by SystemVerilog.
    return rogueSimLinkCreate(model, dataSize, cleanup, rogueDpiReport);
}

void* rogueDpiGetData(const void* context, const RogueSimLinkModelDescriptor* expectedModel) {
    return rogueSimLinkGetData(context, expectedModel, rogueDpiReport);
}

int rogueDpiReservePort(const void* context, const RogueSimLinkModelDescriptor* expectedModel, uint16_t requestedPort) {
    return rogueSimLinkReservePort(context, expectedModel, requestedPort, rogueDpiReport);
}

int rogueDpiDestroy(const void* context, const RogueSimLinkModelDescriptor* expectedModel) {
    return rogueSimLinkDestroy(context, expectedModel, rogueDpiReport);
}
