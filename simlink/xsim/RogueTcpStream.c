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
// Vivado xsim DPI-C backend for the Rogue-TCP AXI-Stream model. The worker
// transport/codec and data-movement FSM live in the compiled shared
// RogueTcpStreamCore.c. This file provides only the DPI-specific plumbing:
// one C-owned state object per SystemVerilog DPI leaf, plus a
// per-edge update function (rogueTcpStreamUpdate) that copies the DPI
// svBit/svBitVecVal parameters into the input snapshot, runs one FSM step, and
// writes the outputs back through the DPI output pointers. Parameterized data,
// user, and keep vectors arrive as little-endian svBitVecVal word arrays and
// are copied into the simulator-neutral beat representation.
//////////////////////////////////////////////////////////////////////////////

#include "RogueTcpStream.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "RogueDpiInstance.h"
#include "svdpi.h"

void RogueTcpStreamLog(const char* message) {
    fputs(message, stdout);
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

void* rogueTcpStreamCreate(void) {
    // The returned registry pointer crosses DPI as an opaque chandle.
    return rogueDpiCreate(&ROGUE_TCP_STREAM_MODEL, sizeof(RogueTcpStreamData), RogueTcpStreamCleanup);
}

void rogueTcpStreamDestroy(void* context) {
    (void)rogueDpiDestroy(context, &ROGUE_TCP_STREAM_MODEL);
}

// Per-edge update function, called from the RogueTcpStreamDpi SV leaf every
// rising_edge(clock) via import "DPI-C". Copies each DPI parameter straight
// into the shared input snapshot, runs one shared FSM step, then
// writes the outputs back through the DPI output pointers.
int rogueTcpStreamUpdate(void* context,
                         int dataBytes,
                         svBit reset,
                         const svBitVecVal* portNum,
                         svBit ssi,
                         svBit obReady,
                         svBit* obValid,
                         svBitVecVal* obData,
                         svBitVecVal* obUser,
                         svBitVecVal* obKeep,
                         svBit* obLast,
                         svBit ibValid,
                         svBit* ibReady,
                         const svBitVecVal* ibData,
                         const svBitVecVal* ibUser,
                         const svBitVecVal* ibKeep,
                         svBit ibLast) {
    RogueTcpStreamData* data = rogueDpiGetData(context, &ROGUE_TCP_STREAM_MODEL);
    unsigned int reqPort     = portNum[0] & 0xFFFF;
    uint32_t dataWords;
    uint32_t keepWords;

    if (data == NULL) return 0;
    if (!RogueTcpStreamSetDataBytes(data, (uint32_t)dataBytes)) return 0;
    if (!reset && !rogueDpiReservePort(context, &ROGUE_TCP_STREAM_MODEL, reqPort)) return 0;

    data->inSnap[s_reset]   = reset ? 1 : 0;
    data->inSnap[s_port]    = reqPort;
    data->inSnap[s_ssi]     = ssi ? 1 : 0;
    data->inSnap[s_obReady] = obReady ? 1 : 0;
    data->inSnap[s_ibValid] = ibValid ? 1 : 0;
    data->inSnap[s_ibLast]  = ibLast ? 1 : 0;
    // DPI vectors are arrays of 32-bit words; data/user are byte-wide per lane,
    // while keep contributes only one bit per lane.
    dataWords = (data->dataBytes + 3U) / 4U;
    keepWords = (data->dataBytes + 31U) / 32U;
    memset(data->ibDataWords, 0, sizeof(data->ibDataWords));
    memset(data->ibUserWords, 0, sizeof(data->ibUserWords));
    memset(data->ibKeepWords, 0, sizeof(data->ibKeepWords));
    memcpy(data->ibDataWords, ibData, dataWords * sizeof(uint32_t));
    memcpy(data->ibUserWords, ibUser, dataWords * sizeof(uint32_t));
    memcpy(data->ibKeepWords, ibKeep, keepWords * sizeof(uint32_t));

    // The shared step polls a worker-owned inbound queue and uses a bounded
    // complete-message rendezvous for outbound frames.
    RogueTcpStreamStep(data);

    // Copy exactly the active vector words; the SystemVerilog widths define
    // how much of the final word is significant.
    *obValid = data->outState[s_obValid] ? 1 : 0;
    memcpy(obData, data->obDataWords, dataWords * sizeof(uint32_t));
    memcpy(obUser, data->obUserWords, dataWords * sizeof(uint32_t));
    memcpy(obKeep, data->obKeepWords, keepWords * sizeof(uint32_t));
    *obLast  = data->outState[s_obLast] ? 1 : 0;
    *ibReady = data->outState[s_ibReady] ? 1 : 0;
    return 1;
}
