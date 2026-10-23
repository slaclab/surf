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
// Vivado xsim DPI-C backend for the Rogue side-band model. The worker
// transport/codec and opcode/remData FSM live in the compiled shared
// RogueSideBandCore.c. This file provides only the DPI-specific plumbing:
// one C-owned state object per SystemVerilog DPI leaf, plus a
// per-edge update function (rogueSideBandUpdate) that copies the DPI
// svBit/svBitVecVal parameters into the input snapshot, runs one FSM step, and
// writes the outputs back through the DPI output pointers. Unlike the GHDL
// VHPIDIRECT backend, every port here is <=32 bits, so each vector argument is
// a single svBitVecVal word -- no encode/decode loop is needed.
//////////////////////////////////////////////////////////////////////////////

#include "RogueSideBand.h"

#include <stdio.h>
#include <stdlib.h>

#include "RogueDpiInstance.h"
#include "svdpi.h"

void RogueSideBandLog(const char* message) {
    fputs(message, stdout);
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

void* rogueSideBandCreate(void) {
    // The returned registry pointer crosses DPI as an opaque chandle.
    return rogueDpiCreate(&ROGUE_SIDE_BAND_MODEL, sizeof(RogueSideBandData), RogueSideBandCleanup);
}

void rogueSideBandDestroy(void* context) {
    (void)rogueDpiDestroy(context, &ROGUE_SIDE_BAND_MODEL);
}

// Per-edge update function, called from the RogueSideBandDpi SV leaf every
// rising_edge(clock) via import "DPI-C". Copies each DPI parameter straight
// into the shared input snapshot, runs one shared FSM step, then
// writes the outputs back through the DPI output pointers.
int rogueSideBandUpdate(void* context,
                        svBit reset,
                        const svBitVecVal* portNum,
                        const svBitVecVal* txOpCode,
                        svBit txOpCodeEn,
                        const svBitVecVal* txRemData,
                        svBitVecVal* rxOpCode,
                        svBit* rxOpCodeEn,
                        svBitVecVal* rxRemData) {
    RogueSideBandData* data = rogueDpiGetData(context, &ROGUE_SIDE_BAND_MODEL);
    unsigned int reqPort    = portNum[0] & 0xFFFF;

    if (data == NULL) return 0;
    // Avoid binding during reset; reserve once the port generic is active.
    if (!reset && !rogueDpiReservePort(context, &ROGUE_SIDE_BAND_MODEL, reqPort)) return 0;

    data->inSnap[s_reset]      = reset ? 1 : 0;
    data->inSnap[s_port]       = reqPort;
    data->inSnap[s_txOpCode]   = txOpCode[0];
    data->inSnap[s_txOpCodeEn] = txOpCodeEn ? 1 : 0;
    data->inSnap[s_txRemData]  = txRemData[0];

    // The shared step polls a worker-owned inbound queue and uses a bounded
    // complete-message rendezvous for outbound events/state.
    RogueSideBandStep(data);

    // DPI output arguments are updated after the complete shared-model step.
    rxOpCode[0]  = data->outState[s_rxOpCode];
    *rxOpCodeEn  = data->outState[s_rxOpCodeEn] ? 1 : 0;
    rxRemData[0] = data->outState[s_rxRemData];
    return 1;
}
