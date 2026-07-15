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
// GHDL VHPIDIRECT backend for the Rogue side-band model. The ZMQ transport
// (RogueSideBandRestart/Send/Recv) and the opcode/remData FSM
// (RogueSideBandStep) live in axi/simlink/shared/RogueSideBandCore.h, included
// by both this backend and the VHPI backend. This file provides only the
// GHDL-specific plumbing: an integer handle registry, a per-edge update
// procedure (rogueSideBandUpdate) that decodes the VHPIDIRECT parameters into
// the selected instance's input snapshot and runs one FSM step, plus one
// handle-based getter per output port. GHDL has no VHPI (no
// vhpi_register_cb / value-change callbacks), so vhpi_printf and vhpi_assert
// are shimmed to printf/abort in RogueSideBand.h.
//////////////////////////////////////////////////////////////////////////////

#include <zmq.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "RogueSideBand.h"
#include "RogueVhpiDirect.h"
#include "RogueVhpiDirectRegistry.h"
#include "RogueSideBandCore.h"

static const char *ROGUE_SIDE_BAND_NAME = "RogueSideBand";

static void rogueSideBandCleanup(void *opaque) {
    RogueSideBandData *data = opaque;

    if (data->zmqPush != NULL) zmq_close(data->zmqPush);
    if (data->zmqPull != NULL) zmq_close(data->zmqPull);
    if (data->zmqCtx  != NULL) zmq_ctx_term(data->zmqCtx);
}

int32_t rogueSideBandCreate(void) {
    return rogueVhpiDirectCreate(sizeof(RogueSideBandData),
                                 rogueSideBandCleanup,
                                 ROGUE_SIDE_BAND_NAME);
}

void rogueSideBandDestroy(int32_t handle) {
    rogueVhpiDirectDestroy(handle, ROGUE_SIDE_BAND_NAME);
}

// Per-edge update procedure, called from VHDL every rising_edge(clock).
// Decodes each VHPIDIRECT parameter into the input snapshot (the getInt seam),
// then runs one shared FSM step. inSnap[s_clock] is intentionally never
// populated -- the FSM does not read it, since every call is already a rising
// edge and needs no edge detection.
void rogueSideBandUpdate(int32_t handle, unsigned char clkRst, unsigned char *portNum,
                          unsigned char *txOpCode, unsigned char txOpCodeEn,
                          unsigned char *txRemData) {
    RogueSideBandData *data = rogueVhpiDirectGetData(handle, ROGUE_SIDE_BAND_NAME);
    unsigned int reqPort = rogueVhpiDirectDecodeVector(portNum, 16);
    unsigned int reset = rogueVhpiDirectDecodeBit(clkRst);

    if (!reset) rogueVhpiDirectReservePort(handle, reqPort, ROGUE_SIDE_BAND_NAME);

    data->inSnap[s_reset]      = reset;
    data->inSnap[s_port]       = reqPort;
    data->inSnap[s_txOpCode]   = rogueVhpiDirectDecodeVector(txOpCode, 8);
    data->inSnap[s_txOpCodeEn] = rogueVhpiDirectDecodeBit(txOpCodeEn);
    data->inSnap[s_txRemData]  = rogueVhpiDirectDecodeVector(txRemData, 8);

    RogueSideBandStep(data);
}

// Handle-based getters, one per output port, reproducing
// VhpiGenericConvertOut's enum-ordinal encoding.
void rogueSideBandGetRxOpCode(unsigned char *ret, int32_t handle) {
    RogueSideBandData *data = rogueVhpiDirectGetData(handle, ROGUE_SIDE_BAND_NAME);
    rogueVhpiDirectEncodeVector(data->outState[s_rxOpCode], ret, 8);
}

unsigned char rogueSideBandGetRxOpCodeEn(int32_t handle) {
    RogueSideBandData *data = rogueVhpiDirectGetData(handle, ROGUE_SIDE_BAND_NAME);
    return rogueVhpiDirectEncodeBit(data->outState[s_rxOpCodeEn]);
}

void rogueSideBandGetRxRemData(unsigned char *ret, int32_t handle) {
    RogueSideBandData *data = rogueVhpiDirectGetData(handle, ROGUE_SIDE_BAND_NAME);
    rogueVhpiDirectEncodeVector(data->outState[s_rxRemData], ret, 8);
}
