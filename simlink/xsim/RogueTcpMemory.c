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
// Vivado xsim DPI-C backend for the Rogue-TCP AXI-Lite memory model. The worker
// transport/codec and transaction FSM live in the compiled shared
// RogueTcpMemoryCore.c. This file provides only the DPI-specific plumbing:
// one C-owned state object per SystemVerilog DPI leaf, plus a
// per-edge update function (rogueTcpMemoryUpdate) that copies the DPI
// svBit/svBitVecVal parameters into the input snapshot, runs one FSM step, and
// writes the outputs back through the DPI output pointers. Unlike the GHDL
// VHPIDIRECT backend, every port here is <=32 bits, so each vector argument is
// a single svBitVecVal word -- no encode/decode loop is needed.
//////////////////////////////////////////////////////////////////////////////

#include "RogueTcpMemory.h"

#include <stdio.h>
#include <stdlib.h>

#include "RogueDpiInstance.h"
#include "svdpi.h"

void RogueTcpMemoryLog(const char* message) {
    fputs(message, stdout);
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

void* rogueTcpMemoryCreate(void) {
    // The returned registry pointer crosses DPI as an opaque chandle.
    return rogueDpiCreate(&ROGUE_TCP_MEMORY_MODEL, sizeof(RogueTcpMemoryData), RogueTcpMemoryCleanup);
}

void rogueTcpMemoryDestroy(void* context) {
    (void)rogueDpiDestroy(context, &ROGUE_TCP_MEMORY_MODEL);
}

// Per-edge update function, called from the RogueTcpMemoryDpi SV leaf every
// rising_edge(clock) via import "DPI-C". Copies each DPI parameter straight
// into the shared input snapshot, runs one shared FSM step, then
// writes the outputs back through the DPI output pointers.
int rogueTcpMemoryUpdate(void* context,
                         svBit reset,
                         const svBitVecVal* portNum,
                         svBitVecVal* araddr,
                         svBitVecVal* arprot,
                         svBit* arvalid,
                         svBit* rready,
                         svBit arready,
                         const svBitVecVal* rdata,
                         const svBitVecVal* rresp,
                         svBit rvalid,
                         svBitVecVal* awaddr,
                         svBitVecVal* awprot,
                         svBit* awvalid,
                         svBitVecVal* wdata,
                         svBitVecVal* wstrb,
                         svBit* wvalid,
                         svBit* bready,
                         svBit awready,
                         svBit wready,
                         const svBitVecVal* bresp,
                         svBit bvalid) {
    RogueTcpMemoryData* data = rogueDpiGetData(context, &ROGUE_TCP_MEMORY_MODEL);
    unsigned int reqPort     = portNum[0] & 0xFFFF;

    if (data == NULL) return 0;
    // Avoid binding during reset; reserve once the port generic is active.
    if (!reset && !rogueDpiReservePort(context, &ROGUE_TCP_MEMORY_MODEL, reqPort)) return 0;

    data->inSnap[s_reset]   = reset ? 1 : 0;
    data->inSnap[s_port]    = reqPort;
    data->inSnap[s_arready] = arready ? 1 : 0;
    data->inSnap[s_rdata]   = rdata[0];
    data->inSnap[s_rresp]   = rresp[0];
    data->inSnap[s_rvalid]  = rvalid ? 1 : 0;
    data->inSnap[s_awready] = awready ? 1 : 0;
    data->inSnap[s_wready]  = wready ? 1 : 0;
    data->inSnap[s_bresp]   = bresp[0];
    data->inSnap[s_bvalid]  = bvalid ? 1 : 0;

    // The shared step polls a worker-owned inbound queue and uses a bounded
    // complete-message rendezvous for responses.
    RogueTcpMemoryStep(data);

    // Publish a coherent set of AXI-Lite master outputs after the FSM step.
    araddr[0] = data->outState[s_araddr];
    arprot[0] = data->outState[s_arprot];
    *arvalid  = data->outState[s_arvalid] ? 1 : 0;
    *rready   = data->outState[s_rready] ? 1 : 0;
    awaddr[0] = data->outState[s_awaddr];
    awprot[0] = data->outState[s_awprot];
    *awvalid  = data->outState[s_awvalid] ? 1 : 0;
    wdata[0]  = data->outState[s_wdata];
    wstrb[0]  = data->outState[s_wstrb];
    *wvalid   = data->outState[s_wvalid] ? 1 : 0;
    *bready   = data->outState[s_bready] ? 1 : 0;
    return 1;
}
