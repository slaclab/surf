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
// Vivado xsim DPI-C backend for the Rogue side-band model. The ZMQ transport
// (RogueSideBandRestart/Send/Recv) and the opcode/remData FSM
// (RogueSideBandStep) live in axi/simlink/shared/RogueSideBandCore.h,
// included by every backend. This file provides only the DPI-specific
// plumbing: one C-owned state object per SystemVerilog DPI leaf, plus a
// per-edge update function (rogueSideBandUpdate) that copies the DPI
// svBit/svBitVecVal parameters into the input snapshot, runs one FSM step, and
// writes the outputs back through the DPI output pointers. Unlike the GHDL
// VHPIDIRECT backend, every port here is <=32 bits, so each vector argument is
// a single svBitVecVal word -- no encode/decode loop is needed.
//////////////////////////////////////////////////////////////////////////////

#include <zmq.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

#include "svdpi.h"
#include "RogueDpiInstance.h"
#include "RogueSideBand.h"
#include "RogueSideBandCore.h"

static void rogueSideBandCleanup(void *opaque) {
    RogueSideBandData *data = opaque;

    if (data->zmqPush != NULL) zmq_close(data->zmqPush);
    if (data->zmqPull != NULL) zmq_close(data->zmqPull);
    if (data->zmqCtx  != NULL) zmq_ctx_term(data->zmqCtx);
}

void *rogueSideBandCreate(void) {
    return rogueDpiCreate(ROGUE_DPI_SIDEBAND_C,
                          sizeof(RogueSideBandData),
                          rogueSideBandCleanup);
}

void rogueSideBandDestroy(void *context) {
    (void)rogueDpiDestroy(context, ROGUE_DPI_SIDEBAND_C);
}

// Per-edge update function, called from the RogueSideBandDpi SV leaf every
// rising_edge(clock) via import "DPI-C". Copies each DPI parameter straight
// into the input snapshot (the getInt seam), runs one shared FSM step, then
// writes the outputs back through the DPI output pointers.
int rogueSideBandUpdate(void *context, svBit reset, const svBitVecVal *portNum,
                         const svBitVecVal *txOpCode, svBit txOpCodeEn, const svBitVecVal *txRemData,
                         svBitVecVal *rxOpCode, svBit *rxOpCodeEn, svBitVecVal *rxRemData) {
    RogueSideBandData *data = rogueDpiGetData(context, ROGUE_DPI_SIDEBAND_C);
    unsigned int reqPort = portNum[0] & 0xFFFF;

    if (data == NULL) return 0;
    if (!reset && !rogueDpiReservePort(context, ROGUE_DPI_SIDEBAND_C, reqPort)) return 0;

    data->inSnap[s_reset]      = reset ? 1 : 0;
    data->inSnap[s_port]       = reqPort;
    data->inSnap[s_txOpCode]   = txOpCode[0];
    data->inSnap[s_txOpCodeEn] = txOpCodeEn ? 1 : 0;
    data->inSnap[s_txRemData]  = txRemData[0];

    // The shared step retains the established backend transport contract:
    // receive polls with ZMQ_DONTWAIT, while events are sent synchronously
    // after the peer is connected and draining.
    RogueSideBandStep(data);

    rxOpCode[0]  = data->outState[s_rxOpCode];
    *rxOpCodeEn  = data->outState[s_rxOpCodeEn] ? 1 : 0;
    rxRemData[0] = data->outState[s_rxRemData];
    return 1;
}
