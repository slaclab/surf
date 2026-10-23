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
// Icarus VPI backend for the Rogue-TCP AXI-Stream model. The worker
// transport/codec and data-movement FSM live in the compiled shared
// RogueTcpStreamCore.c; this file only marshals $rogueTcpStreamUpdate's VPI
// arguments into the input snapshot, runs one FSM step, and writes the
// outputs back through the argument handles. No protocol or framing logic
// belongs here.
//////////////////////////////////////////////////////////////////////////////

#include "RogueTcpStreamCore.h"
#include "RogueVpiInstance.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void RogueTcpStreamLog(const char* message) {
    vpi_printf("%s", message);
}

void RogueTcpStreamFatal(const char* message) {
    fprintf(stderr, "%s\n", message);
#ifdef ROGUE_SIM_LINK_NATIVE_TEST
    // Native negative tests run in bounded subprocesses. Use a normal
    // nonzero exit so macOS does not present an application-crash dialog.
    fflush(stderr);
    _Exit(EXIT_FAILURE);
#else
    abort();
#endif
}

// $rogueTcpStreamCreate() -- vpiSysFunc, no arguments.
static PLI_INT32 rogueTcpStreamCreateCalltf(PLI_BYTE8* userData) {
    (void)userData;
    rogueVpiReturnInt(rogueVpiCreate(&ROGUE_TCP_STREAM_MODEL, sizeof(RogueTcpStreamData), RogueTcpStreamCleanup));
    return 0;
}

// $rogueTcpStreamUpdate(handle, dataBytes, reset, portNum, ssi, obReady,
//                        obValid, obData, obUser, obKeep, obLast,
//                        ibValid, ibReady, ibData, ibUser, ibKeep, ibLast)
// -- vpiSysFunc, 17 arguments, handle first, matching the xsim adapter's
// argument order. Returns 1 on success, 0 after any validation failure.
static PLI_INT32 rogueTcpStreamUpdateCalltf(PLI_BYTE8* userData) {
    vpiHandle args[17];
    RogueTcpStreamData* data;
    int32_t handle;
    uint32_t dataBytes;
    unsigned int reset;
    unsigned int reqPort;
    unsigned int ssi;
    unsigned int obReady;
    unsigned int ibValid;
    unsigned int ibLast;
    uint32_t ibDataWords[ROGUE_TCP_STREAM_MAX_DATA_WORDS];
    uint32_t ibUserWords[ROGUE_TCP_STREAM_MAX_DATA_WORDS];
    uint32_t ibKeepWords[ROGUE_TCP_STREAM_MAX_KEEP_WORDS];

    (void)userData;

    if (!rogueVpiCollectArgs("$rogueTcpStreamUpdate", args, 17)) {
        rogueVpiReturnInt(0);
        return 0;
    }

    handle    = (int32_t)rogueVpiGetU32(args[0]);
    dataBytes = rogueVpiGetU32(args[1]);
    reset     = rogueVpiGetU32(args[2]);
    reqPort   = rogueVpiGetU32(args[3]);
    ssi       = rogueVpiGetU32(args[4]);
    obReady   = rogueVpiGetU32(args[5]);
    ibValid   = rogueVpiGetU32(args[11]);
    ibLast    = rogueVpiGetU32(args[16]);

    data = rogueVpiGetData(handle, &ROGUE_TCP_STREAM_MODEL);
    if (data == NULL) {
        rogueVpiReturnInt(0);
        return 0;
    }
    if (!RogueTcpStreamSetDataBytes(data, dataBytes)) {
        rogueVpiReturnInt(0);
        return 0;
    }
    if (!reset && !rogueVpiReservePort(handle, &ROGUE_TCP_STREAM_MODEL, (uint16_t)reqPort)) {
        rogueVpiReturnInt(0);
        return 0;
    }

    // Data/user vectors are byte-wide per lane; keep contributes one bit per
    // lane. rogueVpiGetWords() zero-fills every word beyond the active
    // prefix, so the unconditional memcpy below matches the xsim adapter's
    // memset-then-memcpy behavior.
    if (!rogueVpiGetWords("$rogueTcpStreamUpdate.ibData", args[13], ibDataWords,
                          ROGUE_TCP_STREAM_MAX_DATA_WORDS, data->dataBytes * 8U) ||
        !rogueVpiGetWords("$rogueTcpStreamUpdate.ibUser", args[14], ibUserWords,
                          ROGUE_TCP_STREAM_MAX_DATA_WORDS, data->dataBytes * 8U) ||
        !rogueVpiGetWords("$rogueTcpStreamUpdate.ibKeep", args[15], ibKeepWords,
                          ROGUE_TCP_STREAM_MAX_KEEP_WORDS, data->dataBytes)) {
        rogueVpiReturnInt(0);
        return 0;
    }

    data->inSnap[s_reset]   = reset   ? 1U : 0U;
    data->inSnap[s_port]    = reqPort;
    data->inSnap[s_ssi]     = ssi     ? 1U : 0U;
    data->inSnap[s_obReady] = obReady ? 1U : 0U;
    data->inSnap[s_ibValid] = ibValid ? 1U : 0U;
    data->inSnap[s_ibLast]  = ibLast  ? 1U : 0U;
    memcpy(data->ibDataWords, ibDataWords, sizeof(data->ibDataWords));
    memcpy(data->ibUserWords, ibUserWords, sizeof(data->ibUserWords));
    memcpy(data->ibKeepWords, ibKeepWords, sizeof(data->ibKeepWords));

    // The shared step polls a worker-owned inbound queue and uses a bounded
    // complete-message rendezvous for outbound frames.
    RogueTcpStreamStep(data);

    if (!rogueVpiPutU32("$rogueTcpStreamUpdate.obValid", args[6],
                        data->outState[s_obValid] ? 1U : 0U, 1U) ||
        !rogueVpiPutWords("$rogueTcpStreamUpdate.obData", args[7],
                          data->obDataWords, data->dataBytes * 8U) ||
        !rogueVpiPutWords("$rogueTcpStreamUpdate.obUser", args[8],
                          data->obUserWords, data->dataBytes * 8U) ||
        !rogueVpiPutWords("$rogueTcpStreamUpdate.obKeep", args[9],
                          data->obKeepWords, data->dataBytes) ||
        !rogueVpiPutU32("$rogueTcpStreamUpdate.obLast", args[10],
                        data->outState[s_obLast] ? 1U : 0U, 1U) ||
        !rogueVpiPutU32("$rogueTcpStreamUpdate.ibReady", args[12],
                        data->outState[s_ibReady] ? 1U : 0U, 1U)) {
        rogueVpiReturnInt(0);
        return 0;
    }

    rogueVpiReturnInt(1);
    return 0;
}

// $rogueTcpStreamDestroy(handle) -- vpiSysTask, 1 argument.
static PLI_INT32 rogueTcpStreamDestroyCalltf(PLI_BYTE8* userData) {
    vpiHandle args[1];
    int32_t handle;

    (void)userData;

    if (!rogueVpiCollectArgs("$rogueTcpStreamDestroy", args, 1)) {
        return 0;
    }
    handle = (int32_t)rogueVpiGetU32(args[0]);
    (void)rogueVpiDestroy(handle, &ROGUE_TCP_STREAM_MODEL);
    return 0;
}

void rogueTcpStreamVpiRegister(void) {
    rogueVpiRegisterFunction("$rogueTcpStreamCreate", rogueTcpStreamCreateCalltf);
    rogueVpiRegisterFunction("$rogueTcpStreamUpdate", rogueTcpStreamUpdateCalltf);
    rogueVpiRegisterTask("$rogueTcpStreamDestroy", rogueTcpStreamDestroyCalltf);
}
