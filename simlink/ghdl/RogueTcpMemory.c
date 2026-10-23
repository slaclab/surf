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
// GHDL VHPIDIRECT backend for the Rogue-TCP AXI-Lite memory model. The worker
// transport/codec and transaction FSM live in the compiled shared
// RogueTcpMemoryCore.c. This file provides only the GHDL-specific plumbing:
// an integer handle registry, a per-edge update
// procedure (rogueTcpMemoryUpdate) that decodes the VHPIDIRECT parameters into
// the selected instance's input snapshot and runs one FSM step, plus one
// handle-based getter per output port, plus logging and fatal-error hooks.
//////////////////////////////////////////////////////////////////////////////

#include "RogueTcpMemory.h"

#include <stdio.h>
#include <stdlib.h>

#include "RogueVhpiDirect.h"
#include "RogueVhpiDirectRegistry.h"

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

int32_t rogueTcpMemoryCreate(void) {
    // VHDL retains only the integer handle; the common registry owns the
    // zero-initialized model and its transport cleanup hook.
    return rogueVhpiDirectCreate(sizeof(RogueTcpMemoryData), RogueTcpMemoryCleanup, &ROGUE_TCP_MEMORY_MODEL);
}

void rogueTcpMemoryDestroy(int32_t handle) {
    rogueVhpiDirectDestroy(handle, &ROGUE_TCP_MEMORY_MODEL);
}

// Per-edge update procedure, called from VHDL every rising_edge(clock).
// Decodes each VHPIDIRECT parameter into the shared input snapshot, then runs
// one shared FSM step. inSnap[s_clock] is intentionally never
// populated -- the FSM does not read it, since every call is already a rising
// edge and needs no edge detection.
void rogueTcpMemoryUpdate(int32_t handle,
                          unsigned char clkRst,
                          unsigned char* portNum,
                          unsigned char arready,
                          unsigned char* rdata,
                          unsigned char* rresp,
                          unsigned char rvalid,
                          unsigned char awready,
                          unsigned char wready,
                          unsigned char* bresp,
                          unsigned char bvalid) {
    RogueTcpMemoryData* data = rogueVhpiDirectGetData(handle, &ROGUE_TCP_MEMORY_MODEL);
    unsigned int reqPort     = rogueVhpiDirectDecodeVector(portNum, 16);
    unsigned int reset       = rogueVhpiDirectDecodeBit(clkRst);

    // Defer the paired-port claim until reset is released and the elaborated
    // generic is available to the model.
    if (!reset) rogueVhpiDirectReservePort(handle, reqPort, &ROGUE_TCP_MEMORY_MODEL);

    data->inSnap[s_reset]   = reset;
    data->inSnap[s_port]    = reqPort;
    data->inSnap[s_arready] = rogueVhpiDirectDecodeBit(arready);
    data->inSnap[s_rdata]   = rogueVhpiDirectDecodeVector(rdata, 32);
    data->inSnap[s_rresp]   = rogueVhpiDirectDecodeVector(rresp, 2);
    data->inSnap[s_rvalid]  = rogueVhpiDirectDecodeBit(rvalid);
    data->inSnap[s_awready] = rogueVhpiDirectDecodeBit(awready);
    data->inSnap[s_wready]  = rogueVhpiDirectDecodeBit(wready);
    data->inSnap[s_bresp]   = rogueVhpiDirectDecodeVector(bresp, 2);
    data->inSnap[s_bvalid]  = rogueVhpiDirectDecodeBit(bvalid);

    // The getter functions below expose the resulting AXI-Lite master outputs.
    RogueTcpMemoryStep(data);
}

// Handle-based getters, one per output port, reproducing
// VhpiGenericConvertOut's enum-ordinal encoding.
void rogueTcpMemoryGetAraddr(unsigned char* ret, int32_t handle) {
    RogueTcpMemoryData* data = rogueVhpiDirectGetData(handle, &ROGUE_TCP_MEMORY_MODEL);
    rogueVhpiDirectEncodeVector(data->outState[s_araddr], ret, 32);
}

void rogueTcpMemoryGetArprot(unsigned char* ret, int32_t handle) {
    RogueTcpMemoryData* data = rogueVhpiDirectGetData(handle, &ROGUE_TCP_MEMORY_MODEL);
    rogueVhpiDirectEncodeVector(data->outState[s_arprot], ret, 3);
}

unsigned char rogueTcpMemoryGetArvalid(int32_t handle) {
    RogueTcpMemoryData* data = rogueVhpiDirectGetData(handle, &ROGUE_TCP_MEMORY_MODEL);
    return rogueVhpiDirectEncodeBit(data->outState[s_arvalid]);
}

unsigned char rogueTcpMemoryGetRready(int32_t handle) {
    RogueTcpMemoryData* data = rogueVhpiDirectGetData(handle, &ROGUE_TCP_MEMORY_MODEL);
    return rogueVhpiDirectEncodeBit(data->outState[s_rready]);
}

void rogueTcpMemoryGetAwaddr(unsigned char* ret, int32_t handle) {
    RogueTcpMemoryData* data = rogueVhpiDirectGetData(handle, &ROGUE_TCP_MEMORY_MODEL);
    rogueVhpiDirectEncodeVector(data->outState[s_awaddr], ret, 32);
}

void rogueTcpMemoryGetAwprot(unsigned char* ret, int32_t handle) {
    RogueTcpMemoryData* data = rogueVhpiDirectGetData(handle, &ROGUE_TCP_MEMORY_MODEL);
    rogueVhpiDirectEncodeVector(data->outState[s_awprot], ret, 3);
}

unsigned char rogueTcpMemoryGetAwvalid(int32_t handle) {
    RogueTcpMemoryData* data = rogueVhpiDirectGetData(handle, &ROGUE_TCP_MEMORY_MODEL);
    return rogueVhpiDirectEncodeBit(data->outState[s_awvalid]);
}

void rogueTcpMemoryGetWdata(unsigned char* ret, int32_t handle) {
    RogueTcpMemoryData* data = rogueVhpiDirectGetData(handle, &ROGUE_TCP_MEMORY_MODEL);
    rogueVhpiDirectEncodeVector(data->outState[s_wdata], ret, 32);
}

void rogueTcpMemoryGetWstrb(unsigned char* ret, int32_t handle) {
    RogueTcpMemoryData* data = rogueVhpiDirectGetData(handle, &ROGUE_TCP_MEMORY_MODEL);
    rogueVhpiDirectEncodeVector(data->outState[s_wstrb], ret, 4);
}

unsigned char rogueTcpMemoryGetWvalid(int32_t handle) {
    RogueTcpMemoryData* data = rogueVhpiDirectGetData(handle, &ROGUE_TCP_MEMORY_MODEL);
    return rogueVhpiDirectEncodeBit(data->outState[s_wvalid]);
}

unsigned char rogueTcpMemoryGetBready(int32_t handle) {
    RogueTcpMemoryData* data = rogueVhpiDirectGetData(handle, &ROGUE_TCP_MEMORY_MODEL);
    return rogueVhpiDirectEncodeBit(data->outState[s_bready]);
}
