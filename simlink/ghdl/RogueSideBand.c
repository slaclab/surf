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
// GHDL VHPIDIRECT backend for the Rogue side-band model. The worker
// transport/codec and opcode/remData FSM live in the compiled shared
// RogueSideBandCore.c. This file provides only the GHDL-specific plumbing:
// an integer handle registry, a per-edge update
// procedure (rogueSideBandUpdate) that decodes the VHPIDIRECT parameters into
// the selected instance's input snapshot and runs one FSM step, plus one
// handle-based getter per output port, plus logging and fatal-error hooks.
//////////////////////////////////////////////////////////////////////////////

#include "RogueSideBand.h"

#include <stdio.h>
#include <stdlib.h>

#include "RogueVhpiDirect.h"
#include "RogueVhpiDirectRegistry.h"

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

int32_t rogueSideBandCreate(void) {
    // VHDL retains only the integer handle; the common registry owns the
    // zero-initialized model and its transport cleanup hook.
    return rogueVhpiDirectCreate(sizeof(RogueSideBandData), RogueSideBandCleanup, &ROGUE_SIDE_BAND_MODEL);
}

void rogueSideBandDestroy(int32_t handle) {
    rogueVhpiDirectDestroy(handle, &ROGUE_SIDE_BAND_MODEL);
}

// Per-edge update procedure, called from VHDL every rising_edge(clock).
// Decodes each VHPIDIRECT parameter into the shared input snapshot, then runs
// one shared FSM step. inSnap[s_clock] is intentionally never
// populated -- the FSM does not read it, since every call is already a rising
// edge and needs no edge detection.
void rogueSideBandUpdate(int32_t handle,
                         unsigned char clkRst,
                         unsigned char* portNum,
                         unsigned char* txOpCode,
                         unsigned char txOpCodeEn,
                         unsigned char* txRemData) {
    RogueSideBandData* data = rogueVhpiDirectGetData(handle, &ROGUE_SIDE_BAND_MODEL);
    unsigned int reqPort    = rogueVhpiDirectDecodeVector(portNum, 16);
    unsigned int reset      = rogueVhpiDirectDecodeBit(clkRst);

    // Port zero is the pre-elaboration/reset sentinel. Claim the two TCP ports
    // only once the model is active and the generic is meaningful.
    if (!reset) rogueVhpiDirectReservePort(handle, reqPort, &ROGUE_SIDE_BAND_MODEL);

    data->inSnap[s_reset]      = reset;
    data->inSnap[s_port]       = reqPort;
    data->inSnap[s_txOpCode]   = rogueVhpiDirectDecodeVector(txOpCode, 8);
    data->inSnap[s_txOpCodeEn] = rogueVhpiDirectDecodeBit(txOpCodeEn);
    data->inSnap[s_txRemData]  = rogueVhpiDirectDecodeVector(txRemData, 8);

    // The getter functions below expose the resulting output snapshot back to
    // VHDL after this procedure returns.
    RogueSideBandStep(data);
}

// Handle-based getters, one per output port, reproducing
// VhpiGenericConvertOut's enum-ordinal encoding.
void rogueSideBandGetRxOpCode(unsigned char* ret, int32_t handle) {
    RogueSideBandData* data = rogueVhpiDirectGetData(handle, &ROGUE_SIDE_BAND_MODEL);
    rogueVhpiDirectEncodeVector(data->outState[s_rxOpCode], ret, 8);
}

unsigned char rogueSideBandGetRxOpCodeEn(int32_t handle) {
    RogueSideBandData* data = rogueVhpiDirectGetData(handle, &ROGUE_SIDE_BAND_MODEL);
    return rogueVhpiDirectEncodeBit(data->outState[s_rxOpCodeEn]);
}

void rogueSideBandGetRxRemData(unsigned char* ret, int32_t handle) {
    RogueSideBandData* data = rogueVhpiDirectGetData(handle, &ROGUE_SIDE_BAND_MODEL);
    rogueVhpiDirectEncodeVector(data->outState[s_rxRemData], ret, 8);
}
