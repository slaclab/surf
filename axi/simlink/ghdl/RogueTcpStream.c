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
// GHDL VHPIDIRECT backend for the Rogue-TCP AXI-Stream model. The ZMQ
// transport (RogueTcpStreamRestart/Send/Recv) and the data-movement FSM
// (RogueTcpStreamStep) live in axi/simlink/shared/RogueTcpStreamCore.h,
// included by both this backend and the VHPI backend. This file provides only
// the GHDL-specific plumbing: an integer handle registry, a per-edge update
// procedure (rogueTcpStreamUpdate) that decodes the VHPIDIRECT parameters into
// the selected instance's input snapshot and runs one FSM step, plus one
// handle-based getter per output port. GHDL has no VHPI (no
// vhpi_register_cb / value-change callbacks), so vhpi_printf and vhpi_assert
// are shimmed to printf/abort in RogueTcpStream.h.
//////////////////////////////////////////////////////////////////////////////

#include <zmq.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

#include "RogueTcpStream.h"
#include "RogueVhpiDirect.h"
#include "RogueVhpiDirectRegistry.h"
#include "RogueTcpStreamCore.h"

static const char *ROGUE_TCP_STREAM_NAME = "RogueTcpStream";

static void rogueTcpStreamCleanup(void *opaque) {
    RogueTcpStreamData *data = opaque;

    if (data->zmqPush != NULL) zmq_close(data->zmqPush);
    if (data->zmqPull != NULL) zmq_close(data->zmqPull);
    if (data->zmqCtx  != NULL) zmq_ctx_term(data->zmqCtx);
}

int32_t rogueTcpStreamCreate(void) {
    return rogueVhpiDirectCreate(sizeof(RogueTcpStreamData),
                                 rogueTcpStreamCleanup,
                                 ROGUE_TCP_STREAM_NAME);
}

void rogueTcpStreamDestroy(int32_t handle) {
    rogueVhpiDirectDestroy(handle, ROGUE_TCP_STREAM_NAME);
}

// Per-edge update procedure, called from VHDL every rising_edge(clock).
// Decodes each VHPIDIRECT parameter into the input snapshot (the getInt seam),
// then runs one shared FSM step. inSnap[s_clock] is intentionally never
// populated -- the FSM does not read it, since every call is already a rising
// edge and needs no edge detection.
void rogueTcpStreamUpdate(int32_t handle, unsigned char clkRst, unsigned char *portNum, unsigned char ssi,
                           unsigned char obReady, unsigned char ibValid,
                           unsigned char *ibDataLow, unsigned char *ibDataHigh,
                           unsigned char *ibUserLow, unsigned char *ibUserHigh,
                           unsigned char *ibKeep, unsigned char ibLast) {
    RogueTcpStreamData *data = rogueVhpiDirectGetData(handle, ROGUE_TCP_STREAM_NAME);
    unsigned int reqPort = rogueVhpiDirectDecodeVector(portNum, 16);
    unsigned int reset = rogueVhpiDirectDecodeBit(clkRst);

    if (!reset) rogueVhpiDirectReservePort(handle, reqPort, ROGUE_TCP_STREAM_NAME);

    data->inSnap[s_reset]      = reset;
    data->inSnap[s_port]       = reqPort;
    data->inSnap[s_ssi]        = rogueVhpiDirectDecodeBit(ssi);
    data->inSnap[s_obReady]    = rogueVhpiDirectDecodeBit(obReady);
    data->inSnap[s_ibValid]    = rogueVhpiDirectDecodeBit(ibValid);
    data->inSnap[s_ibDataLow]  = rogueVhpiDirectDecodeVector(ibDataLow, 32);
    data->inSnap[s_ibDataHigh] = rogueVhpiDirectDecodeVector(ibDataHigh, 32);
    data->inSnap[s_ibUserLow]  = rogueVhpiDirectDecodeVector(ibUserLow, 32);
    data->inSnap[s_ibUserHigh] = rogueVhpiDirectDecodeVector(ibUserHigh, 32);
    data->inSnap[s_ibKeep]     = rogueVhpiDirectDecodeVector(ibKeep, 8);
    data->inSnap[s_ibLast]     = rogueVhpiDirectDecodeBit(ibLast);

    RogueTcpStreamStep(data);
}

// Handle-based getters, one per output port, reproducing
// VhpiGenericConvertOut's enum-ordinal encoding.
unsigned char rogueTcpStreamGetObValid(int32_t handle) {
    RogueTcpStreamData *data = rogueVhpiDirectGetData(handle, ROGUE_TCP_STREAM_NAME);
    return rogueVhpiDirectEncodeBit(data->outState[s_obValid]);
}

unsigned char rogueTcpStreamGetObLast(int32_t handle) {
    RogueTcpStreamData *data = rogueVhpiDirectGetData(handle, ROGUE_TCP_STREAM_NAME);
    return rogueVhpiDirectEncodeBit(data->outState[s_obLast]);
}

unsigned char rogueTcpStreamGetIbReady(int32_t handle) {
    RogueTcpStreamData *data = rogueVhpiDirectGetData(handle, ROGUE_TCP_STREAM_NAME);
    return rogueVhpiDirectEncodeBit(data->outState[s_ibReady]);
}

void rogueTcpStreamGetObDataLow(unsigned char *ret, int32_t handle) {
    RogueTcpStreamData *data = rogueVhpiDirectGetData(handle, ROGUE_TCP_STREAM_NAME);
    rogueVhpiDirectEncodeVector(data->outState[s_obDataLow], ret, 32);
}

void rogueTcpStreamGetObDataHigh(unsigned char *ret, int32_t handle) {
    RogueTcpStreamData *data = rogueVhpiDirectGetData(handle, ROGUE_TCP_STREAM_NAME);
    rogueVhpiDirectEncodeVector(data->outState[s_obDataHigh], ret, 32);
}

void rogueTcpStreamGetObUserLow(unsigned char *ret, int32_t handle) {
    RogueTcpStreamData *data = rogueVhpiDirectGetData(handle, ROGUE_TCP_STREAM_NAME);
    rogueVhpiDirectEncodeVector(data->outState[s_obUserLow], ret, 32);
}

void rogueTcpStreamGetObUserHigh(unsigned char *ret, int32_t handle) {
    RogueTcpStreamData *data = rogueVhpiDirectGetData(handle, ROGUE_TCP_STREAM_NAME);
    rogueVhpiDirectEncodeVector(data->outState[s_obUserHigh], ret, 32);
}

void rogueTcpStreamGetObKeep(unsigned char *ret, int32_t handle) {
    RogueTcpStreamData *data = rogueVhpiDirectGetData(handle, ROGUE_TCP_STREAM_NAME);
    rogueVhpiDirectEncodeVector(data->outState[s_obKeep], ret, 8);
}
