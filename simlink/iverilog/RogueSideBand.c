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
// Icarus VPI backend for the Rogue side-band model. The worker
// transport/codec and opcode/remData FSM live in the compiled shared
// RogueSideBandCore.c; this file only marshals $rogueSideBandUpdate's VPI
// arguments into the input snapshot, runs one FSM step, and writes the
// outputs back through the argument handles. Every port here is 16 bits or
// narrower, so each vector argument is a single 32-bit word.
//////////////////////////////////////////////////////////////////////////////

#include "RogueSideBandCore.h"
#include "RogueVpiInstance.h"

#include <stdio.h>
#include <stdlib.h>

void RogueSideBandLog(const char* message) {
    vpi_printf("%s", message);
}

void RogueSideBandFatal(const char* message) {
    fprintf(stderr, "%s\n", message);
#ifdef ROGUE_SIM_LINK_NATIVE_TEST
    fflush(stderr);
    _Exit(EXIT_FAILURE);
#else
    abort();
#endif
}

// $rogueSideBandCreate() -- vpiSysFunc, no arguments.
static PLI_INT32 rogueSideBandCreateCalltf(PLI_BYTE8* userData) {
    (void)userData;
    rogueVpiReturnInt(rogueVpiCreate(&ROGUE_SIDE_BAND_MODEL, sizeof(RogueSideBandData), RogueSideBandCleanup));
    return 0;
}

// $rogueSideBandUpdate(handle, reset, portNum, txOpCode, txOpCodeEn, txRemData,
//                       rxOpCode, rxOpCodeEn, rxRemData)
// -- vpiSysFunc, 9 arguments, handle first, matching the xsim adapter's
// argument order. Returns 1 on success, 0 after any validation failure.
static PLI_INT32 rogueSideBandUpdateCalltf(PLI_BYTE8* userData) {
    vpiHandle args[9];
    RogueSideBandData* data;
    int32_t handle;
    unsigned int reset;
    unsigned int reqPort;
    uint32_t txOpCode, txOpCodeEn, txRemData;

    (void)userData;

    if (!rogueVpiCollectArgs("$rogueSideBandUpdate", args, 9)) {
        rogueVpiReturnInt(0);
        return 0;
    }

    handle  = (int32_t)rogueVpiGetU32(args[0]);
    reset   = rogueVpiGetU32(args[1]);
    reqPort = rogueVpiGetU32(args[2]);

    if (!rogueVpiGetWords("$rogueSideBandUpdate.txOpCode", args[3], &txOpCode, 1U, 8U) ||
        !rogueVpiGetWords("$rogueSideBandUpdate.txOpCodeEn", args[4], &txOpCodeEn, 1U, 1U) ||
        !rogueVpiGetWords("$rogueSideBandUpdate.txRemData", args[5], &txRemData, 1U, 8U)) {
        rogueVpiReturnInt(0);
        return 0;
    }

    data = rogueVpiGetData(handle, &ROGUE_SIDE_BAND_MODEL);
    if (data == NULL) {
        rogueVpiReturnInt(0);
        return 0;
    }
    // Avoid binding during reset; reserve once the port generic is active.
    if (!reset && !rogueVpiReservePort(handle, &ROGUE_SIDE_BAND_MODEL, (uint16_t)reqPort)) {
        rogueVpiReturnInt(0);
        return 0;
    }

    data->inSnap[s_reset]      = reset ? 1U : 0U;
    data->inSnap[s_port]       = reqPort;
    data->inSnap[s_txOpCode]   = txOpCode;
    data->inSnap[s_txOpCodeEn] = txOpCodeEn ? 1U : 0U;
    data->inSnap[s_txRemData]  = txRemData;

    // The shared step polls a worker-owned inbound queue and uses a bounded
    // complete-message rendezvous for outbound events/state.
    RogueSideBandStep(data);

    if (!rogueVpiPutU32("$rogueSideBandUpdate.rxOpCode", args[6], data->outState[s_rxOpCode], 8U) ||
        !rogueVpiPutU32("$rogueSideBandUpdate.rxOpCodeEn", args[7], data->outState[s_rxOpCodeEn] ? 1U : 0U, 1U) ||
        !rogueVpiPutU32("$rogueSideBandUpdate.rxRemData", args[8], data->outState[s_rxRemData], 8U)) {
        rogueVpiReturnInt(0);
        return 0;
    }

    rogueVpiReturnInt(1);
    return 0;
}

// $rogueSideBandDestroy(handle) -- vpiSysTask, 1 argument.
static PLI_INT32 rogueSideBandDestroyCalltf(PLI_BYTE8* userData) {
    vpiHandle args[1];
    int32_t handle;

    (void)userData;

    if (!rogueVpiCollectArgs("$rogueSideBandDestroy", args, 1)) {
        return 0;
    }
    handle = (int32_t)rogueVpiGetU32(args[0]);
    (void)rogueVpiDestroy(handle, &ROGUE_SIDE_BAND_MODEL);
    return 0;
}

void rogueSideBandVpiRegister(void) {
    rogueVpiRegisterFunction("$rogueSideBandCreate", rogueSideBandCreateCalltf);
    rogueVpiRegisterFunction("$rogueSideBandUpdate", rogueSideBandUpdateCalltf);
    rogueVpiRegisterTask("$rogueSideBandDestroy", rogueSideBandDestroyCalltf);
}
