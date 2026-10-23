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
// Icarus VPI backend for the Rogue-TCP AXI-Lite memory model. The worker
// transport/codec and transaction FSM live in the compiled shared
// RogueTcpMemoryCore.c; this file only marshals $rogueTcpMemoryUpdate's VPI
// arguments into the input snapshot, runs one FSM step, and writes the
// outputs back through the argument handles. Every port here is 32 bits or
// narrower, so each vector argument is a single 32-bit word.
//////////////////////////////////////////////////////////////////////////////

#include "RogueTcpMemoryCore.h"
#include "RogueVpiInstance.h"

#include <stdio.h>
#include <stdlib.h>

void RogueTcpMemoryLog(const char* message) {
    vpi_printf("%s", message);
}

void RogueTcpMemoryFatal(const char* message) {
    fprintf(stderr, "%s\n", message);
#ifdef ROGUE_SIM_LINK_NATIVE_TEST
    fflush(stderr);
    _Exit(EXIT_FAILURE);
#else
    abort();
#endif
}

// $rogueTcpMemoryCreate() -- vpiSysFunc, no arguments.
static PLI_INT32 rogueTcpMemoryCreateCalltf(PLI_BYTE8* userData) {
    (void)userData;
    rogueVpiReturnInt(rogueVpiCreate(&ROGUE_TCP_MEMORY_MODEL, sizeof(RogueTcpMemoryData), RogueTcpMemoryCleanup));
    return 0;
}

// $rogueTcpMemoryUpdate(handle, reset, portNum,
//                        araddr, arprot, arvalid, rready, arready, rdata, rresp, rvalid,
//                        awaddr, awprot, awvalid, wdata, wstrb, wvalid, bready, awready,
//                        wready, bresp, bvalid)
// -- vpiSysFunc, 22 arguments, handle first, matching the xsim adapter's
// argument order. Returns 1 on success, 0 after any validation failure.
static PLI_INT32 rogueTcpMemoryUpdateCalltf(PLI_BYTE8* userData) {
    vpiHandle args[22];
    RogueTcpMemoryData* data;
    int32_t handle;
    unsigned int reset;
    unsigned int reqPort;
    uint32_t arready, rdata, rresp, rvalid;
    uint32_t awready, wready, bresp, bvalid;

    (void)userData;

    if (!rogueVpiCollectArgs("$rogueTcpMemoryUpdate", args, 22)) {
        rogueVpiReturnInt(0);
        return 0;
    }

    handle  = (int32_t)rogueVpiGetU32(args[0]);
    reset   = rogueVpiGetU32(args[1]);
    reqPort = rogueVpiGetU32(args[2]);

    // Every response/status input is width-validated through
    // rogueVpiGetWords() (a one-word vector read), matching the write side's
    // rogueVpiPutU32() checks.
    if (!rogueVpiGetWords("$rogueTcpMemoryUpdate.arready", args[7], &arready, 1U, 1U) ||
        !rogueVpiGetWords("$rogueTcpMemoryUpdate.rdata", args[8], &rdata, 1U, 32U) ||
        !rogueVpiGetWords("$rogueTcpMemoryUpdate.rresp", args[9], &rresp, 1U, 2U) ||
        !rogueVpiGetWords("$rogueTcpMemoryUpdate.rvalid", args[10], &rvalid, 1U, 1U) ||
        !rogueVpiGetWords("$rogueTcpMemoryUpdate.awready", args[18], &awready, 1U, 1U) ||
        !rogueVpiGetWords("$rogueTcpMemoryUpdate.wready", args[19], &wready, 1U, 1U) ||
        !rogueVpiGetWords("$rogueTcpMemoryUpdate.bresp", args[20], &bresp, 1U, 2U) ||
        !rogueVpiGetWords("$rogueTcpMemoryUpdate.bvalid", args[21], &bvalid, 1U, 1U)) {
        rogueVpiReturnInt(0);
        return 0;
    }

    data = rogueVpiGetData(handle, &ROGUE_TCP_MEMORY_MODEL);
    if (data == NULL) {
        rogueVpiReturnInt(0);
        return 0;
    }
    // Avoid binding during reset; reserve once the port generic is active.
    if (!reset && !rogueVpiReservePort(handle, &ROGUE_TCP_MEMORY_MODEL, (uint16_t)reqPort)) {
        rogueVpiReturnInt(0);
        return 0;
    }

    data->inSnap[s_reset]   = reset ? 1U : 0U;
    data->inSnap[s_port]    = reqPort;
    data->inSnap[s_arready] = arready ? 1U : 0U;
    data->inSnap[s_rdata]   = rdata;
    data->inSnap[s_rresp]   = rresp;
    data->inSnap[s_rvalid]  = rvalid ? 1U : 0U;
    data->inSnap[s_awready] = awready ? 1U : 0U;
    data->inSnap[s_wready]  = wready ? 1U : 0U;
    data->inSnap[s_bresp]   = bresp;
    data->inSnap[s_bvalid]  = bvalid ? 1U : 0U;

    // The shared step polls a worker-owned inbound queue and uses a bounded
    // complete-message rendezvous for responses.
    RogueTcpMemoryStep(data);

    if (!rogueVpiPutU32("$rogueTcpMemoryUpdate.araddr", args[3], data->outState[s_araddr], 32U) ||
        !rogueVpiPutU32("$rogueTcpMemoryUpdate.arprot", args[4], data->outState[s_arprot], 3U) ||
        !rogueVpiPutU32("$rogueTcpMemoryUpdate.arvalid", args[5], data->outState[s_arvalid] ? 1U : 0U, 1U) ||
        !rogueVpiPutU32("$rogueTcpMemoryUpdate.rready", args[6], data->outState[s_rready] ? 1U : 0U, 1U) ||
        !rogueVpiPutU32("$rogueTcpMemoryUpdate.awaddr", args[11], data->outState[s_awaddr], 32U) ||
        !rogueVpiPutU32("$rogueTcpMemoryUpdate.awprot", args[12], data->outState[s_awprot], 3U) ||
        !rogueVpiPutU32("$rogueTcpMemoryUpdate.awvalid", args[13], data->outState[s_awvalid] ? 1U : 0U, 1U) ||
        !rogueVpiPutU32("$rogueTcpMemoryUpdate.wdata", args[14], data->outState[s_wdata], 32U) ||
        !rogueVpiPutU32("$rogueTcpMemoryUpdate.wstrb", args[15], data->outState[s_wstrb], 4U) ||
        !rogueVpiPutU32("$rogueTcpMemoryUpdate.wvalid", args[16], data->outState[s_wvalid] ? 1U : 0U, 1U) ||
        !rogueVpiPutU32("$rogueTcpMemoryUpdate.bready", args[17], data->outState[s_bready] ? 1U : 0U, 1U)) {
        rogueVpiReturnInt(0);
        return 0;
    }

    rogueVpiReturnInt(1);
    return 0;
}

// $rogueTcpMemoryDestroy(handle) -- vpiSysTask, 1 argument.
static PLI_INT32 rogueTcpMemoryDestroyCalltf(PLI_BYTE8* userData) {
    vpiHandle args[1];
    int32_t handle;

    (void)userData;

    if (!rogueVpiCollectArgs("$rogueTcpMemoryDestroy", args, 1)) {
        return 0;
    }
    handle = (int32_t)rogueVpiGetU32(args[0]);
    (void)rogueVpiDestroy(handle, &ROGUE_TCP_MEMORY_MODEL);
    return 0;
}

void rogueTcpMemoryVpiRegister(void) {
    rogueVpiRegisterFunction("$rogueTcpMemoryCreate", rogueTcpMemoryCreateCalltf);
    rogueVpiRegisterFunction("$rogueTcpMemoryUpdate", rogueTcpMemoryUpdateCalltf);
    rogueVpiRegisterTask("$rogueTcpMemoryDestroy", rogueTcpMemoryDestroyCalltf);
}
