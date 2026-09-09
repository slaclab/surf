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
// GHDL VHPIDIRECT backend for the Rogue-TCP AXI-Stream model. The worker
// transport/codec and data-movement FSM live in the compiled shared
// RogueTcpStreamCore.c. This file provides only the GHDL-specific plumbing:
// an integer handle registry, a per-edge update
// procedure (rogueTcpStreamUpdate) that decodes the VHPIDIRECT parameters into
// the selected instance's input snapshot and runs one FSM step, plus one
// handle-based getter per output port, plus logging and fatal-error hooks.
//////////////////////////////////////////////////////////////////////////////

#include "RogueTcpStream.h"

#include <stdio.h>
#include <stdlib.h>

#include "RogueVhpiDirect.h"
#include "RogueVhpiDirectRegistry.h"

void RogueTcpStreamLog(const char* message) {
    fputs(message, stdout);
}

void RogueTcpStreamFatal(const char* message) {
    fprintf(stderr, "%s\n", message);
#ifdef ROGUE_SIM_LINK_NATIVE_TEST
    fflush(stderr);
    _Exit(EXIT_FAILURE);
#else
    abort();
#endif
}

int32_t rogueTcpStreamCreate(void) {
    // VHDL retains only the integer handle; the common registry owns the
    // zero-initialized model and its transport cleanup hook.
    return rogueVhpiDirectCreate(sizeof(RogueTcpStreamData), RogueTcpStreamCleanup, &ROGUE_TCP_STREAM_MODEL);
}

void rogueTcpStreamDestroy(int32_t handle) {
    rogueVhpiDirectDestroy(handle, &ROGUE_TCP_STREAM_MODEL);
}

// Per-edge update procedure, called from VHDL every rising_edge(clock).
// Decodes each VHPIDIRECT parameter into the shared input snapshot, then runs
// one shared FSM step. inSnap[s_clock] is intentionally never
// populated -- the FSM does not read it, since every call is already a rising
// edge and needs no edge detection.
void rogueTcpStreamUpdate(int32_t handle,
                          int32_t dataBytes,
                          unsigned char clkRst,
                          unsigned char* portNum,
                          unsigned char ssi,
                          unsigned char obReady,
                          unsigned char ibValid,
                          unsigned char* ibData,
                          unsigned char* ibUser,
                          unsigned char* ibKeep,
                          unsigned char ibLast) {
    RogueTcpStreamData* data = rogueVhpiDirectGetData(handle, &ROGUE_TCP_STREAM_MODEL);
    unsigned int reqPort     = rogueVhpiDirectDecodeVector(portNum, 16);
    unsigned int reset       = rogueVhpiDirectDecodeBit(clkRst);

    // DATA_BYTES is passed explicitly because VHPIDIRECT cannot discover the
    // unconstrained vector width from these raw C arguments.
    if (!RogueTcpStreamSetDataBytes(data, (uint32_t)dataBytes)) return;
    if (!reset) rogueVhpiDirectReservePort(handle, reqPort, &ROGUE_TCP_STREAM_MODEL);

    data->inSnap[s_reset]   = reset;
    data->inSnap[s_port]    = reqPort;
    data->inSnap[s_ssi]     = rogueVhpiDirectDecodeBit(ssi);
    data->inSnap[s_obReady] = rogueVhpiDirectDecodeBit(obReady);
    data->inSnap[s_ibValid] = rogueVhpiDirectDecodeBit(ibValid);
    data->inSnap[s_ibLast]  = rogueVhpiDirectDecodeBit(ibLast);
    // Decode std_logic enum ordinals into the shared little-endian word view.
    rogueVhpiDirectDecodeWords(ibData, data->ibDataWords, data->dataBytes * 8U);
    rogueVhpiDirectDecodeWords(ibUser, data->ibUserWords, data->dataBytes * 8U);
    rogueVhpiDirectDecodeWords(ibKeep, data->ibKeepWords, data->dataBytes);

    // The getter functions below encode the resulting outbound beat.
    RogueTcpStreamStep(data);
}

// Handle-based getters, one per output port, reproducing
// VhpiGenericConvertOut's enum-ordinal encoding.
unsigned char rogueTcpStreamGetObValid(int32_t handle) {
    RogueTcpStreamData* data = rogueVhpiDirectGetData(handle, &ROGUE_TCP_STREAM_MODEL);
    return rogueVhpiDirectEncodeBit(data->outState[s_obValid]);
}

unsigned char rogueTcpStreamGetObLast(int32_t handle) {
    RogueTcpStreamData* data = rogueVhpiDirectGetData(handle, &ROGUE_TCP_STREAM_MODEL);
    return rogueVhpiDirectEncodeBit(data->outState[s_obLast]);
}

unsigned char rogueTcpStreamGetIbReady(int32_t handle) {
    RogueTcpStreamData* data = rogueVhpiDirectGetData(handle, &ROGUE_TCP_STREAM_MODEL);
    return rogueVhpiDirectEncodeBit(data->outState[s_ibReady]);
}

void rogueTcpStreamGetObData(unsigned char* ret, int32_t handle) {
    RogueTcpStreamData* data = rogueVhpiDirectGetData(handle, &ROGUE_TCP_STREAM_MODEL);
    rogueVhpiDirectEncodeWords(data->obDataWords, ret, data->dataBytes * 8U);
}

void rogueTcpStreamGetObUser(unsigned char* ret, int32_t handle) {
    RogueTcpStreamData* data = rogueVhpiDirectGetData(handle, &ROGUE_TCP_STREAM_MODEL);
    rogueVhpiDirectEncodeWords(data->obUserWords, ret, data->dataBytes * 8U);
}

void rogueTcpStreamGetObKeep(unsigned char* ret, int32_t handle) {
    RogueTcpStreamData* data = rogueVhpiDirectGetData(handle, &ROGUE_TCP_STREAM_MODEL);
    rogueVhpiDirectEncodeWords(data->obKeepWords, ret, data->dataBytes);
}
