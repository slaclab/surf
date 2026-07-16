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
// Vivado xsim DPI-C backend for the Rogue-TCP AXI-Stream model. The ZMQ
// transport (RogueTcpStreamRestart/Send/Recv) and the data-movement FSM
// (RogueTcpStreamStep) live in axi/simlink/shared/RogueTcpStreamCore.h,
// included by every backend. This file provides only the DPI-specific
// plumbing: one C-owned state object per SystemVerilog DPI leaf, plus a
// per-edge update function (rogueTcpStreamUpdate) that copies the DPI
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
#include "RogueTcpStream.h"
#include "RogueTcpStreamCore.h"

static void rogueTcpStreamCleanup(void *opaque) {
    RogueTcpStreamData *data = opaque;

    if (data->zmqPush != NULL) zmq_close(data->zmqPush);
    if (data->zmqPull != NULL) zmq_close(data->zmqPull);
    if (data->zmqCtx  != NULL) zmq_ctx_term(data->zmqCtx);
}

void *rogueTcpStreamCreate(void) {
    return rogueDpiCreate(ROGUE_DPI_STREAM_C,
                          sizeof(RogueTcpStreamData),
                          rogueTcpStreamCleanup);
}

void rogueTcpStreamDestroy(void *context) {
    (void)rogueDpiDestroy(context, ROGUE_DPI_STREAM_C);
}

// Per-edge update function, called from the RogueTcpStreamDpi SV leaf every
// rising_edge(clock) via import "DPI-C". Copies each DPI parameter straight
// into the input snapshot (the getInt seam), runs one shared FSM step, then
// writes the outputs back through the DPI output pointers.
int rogueTcpStreamUpdate(void *context, svBit reset, const svBitVecVal *portNum, svBit ssi,
                          svBit obReady, svBit *obValid,
                          svBitVecVal *obDataLow, svBitVecVal *obDataHigh,
                          svBitVecVal *obUserLow, svBitVecVal *obUserHigh,
                          svBitVecVal *obKeep, svBit *obLast,
                          svBit ibValid, svBit *ibReady,
                          const svBitVecVal *ibDataLow, const svBitVecVal *ibDataHigh,
                          const svBitVecVal *ibUserLow, const svBitVecVal *ibUserHigh,
                          const svBitVecVal *ibKeep, svBit ibLast) {
    RogueTcpStreamData *data = rogueDpiGetData(context, ROGUE_DPI_STREAM_C);
    unsigned int reqPort = portNum[0] & 0xFFFF;

    if (data == NULL) return 0;
    if (!reset && !rogueDpiReservePort(context, ROGUE_DPI_STREAM_C, reqPort)) return 0;

    data->inSnap[s_reset]      = reset ? 1 : 0;
    data->inSnap[s_port]       = reqPort;
    data->inSnap[s_ssi]        = ssi ? 1 : 0;
    data->inSnap[s_obReady]    = obReady ? 1 : 0;
    data->inSnap[s_ibValid]    = ibValid ? 1 : 0;
    data->inSnap[s_ibDataLow]  = ibDataLow[0];
    data->inSnap[s_ibDataHigh] = ibDataHigh[0];
    data->inSnap[s_ibUserLow]  = ibUserLow[0];
    data->inSnap[s_ibUserHigh] = ibUserHigh[0];
    data->inSnap[s_ibKeep]     = ibKeep[0];
    data->inSnap[s_ibLast]     = ibLast ? 1 : 0;

    // The shared step retains the established backend transport contract:
    // receive polls with ZMQ_DONTWAIT, while outbound frames are sent
    // synchronously after the peer is connected and draining.
    RogueTcpStreamStep(data);

    *obValid      = data->outState[s_obValid] ? 1 : 0;
    obDataLow[0]  = data->outState[s_obDataLow];
    obDataHigh[0] = data->outState[s_obDataHigh];
    obUserLow[0]  = data->outState[s_obUserLow];
    obUserHigh[0] = data->outState[s_obUserHigh];
    obKeep[0]     = data->outState[s_obKeep];
    *obLast       = data->outState[s_obLast] ? 1 : 0;
    *ibReady      = data->outState[s_ibReady] ? 1 : 0;
    return 1;
}
