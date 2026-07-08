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
// plumbing: a per-edge update function (rogueTcpStreamUpdate) that copies the
// DPI svBit/svBitVecVal parameters into the input snapshot, runs one FSM
// step, and writes the outputs back through the DPI output pointers. Unlike
// the GHDL VHPIDIRECT backend, every port here is <=32 bits, so each vector
// argument is a single svBitVecVal word -- no encode/decode loop is needed.
//////////////////////////////////////////////////////////////////////////////

#include <zmq.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

#include "svdpi.h"
#include "RogueTcpStream.h"
#include "RogueTcpStreamCore.h"

// Single instance for this simulation; file-scope statics are zero-
// initialized by C, replacing the src Init's malloc+memset.
static RogueTcpStreamData streamData;

// Per-edge update function, called from the RogueTcpStreamDpi SV leaf every
// rising_edge(clock) via import "DPI-C". Copies each DPI parameter straight
// into the input snapshot (the getInt seam), runs one shared FSM step, then
// writes the outputs back through the DPI output pointers.
void rogueTcpStreamUpdate(unsigned char reset, const svBitVecVal *portNum, unsigned char ssi,
                           unsigned char obReady, unsigned char *obValid,
                           svBitVecVal *obDataLow, svBitVecVal *obDataHigh,
                           svBitVecVal *obUserLow, svBitVecVal *obUserHigh,
                           svBitVecVal *obKeep, unsigned char *obLast,
                           unsigned char ibValid, unsigned char *ibReady,
                           const svBitVecVal *ibDataLow, const svBitVecVal *ibDataHigh,
                           const svBitVecVal *ibUserLow, const svBitVecVal *ibUserHigh,
                           const svBitVecVal *ibKeep, unsigned char ibLast) {
    RogueTcpStreamData *data = &streamData;
    unsigned int reqPort = portNum[0] & 0xFFFF;

    // DPI-C imports carry no per-instance context, so this backend hosts a
    // single global streamData and supports only one RogueTcpStream per
    // simulation. A second instance (e.g. RogueTcpStreamWrap with
    // CHAN_COUNT_G>1, one distinct port per channel) would otherwise
    // silently share this state and bind only the first port. Fail fast once
    // a different, already-latched port is observed rather than corrupt
    // state.
    if ( data->port != 0 && reqPort != 0 && reqPort != data->port ) {
        vhpi_printf("RogueTcpStream: Vivado xsim DPI-C backend supports only one instance per simulation; observed ports %u and %u\n", data->port, reqPort);
        vhpi_assert("RogueTcpStream: multiple instances unsupported under Vivado xsim DPI-C", vhpiFatal);
        return;
    }

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

    // RogueTcpStreamStep (shared FSM) calls RogueTcpStreamRecv, which uses
    // ZMQ_DONTWAIT -- never make this a blocking call, or it freezes the
    // whole Vivado xsim process, not just a background thread.
    RogueTcpStreamStep(data);

    *obValid      = data->outState[s_obValid] ? 1 : 0;
    obDataLow[0]  = data->outState[s_obDataLow];
    obDataHigh[0] = data->outState[s_obDataHigh];
    obUserLow[0]  = data->outState[s_obUserLow];
    obUserHigh[0] = data->outState[s_obUserHigh];
    obKeep[0]     = data->outState[s_obKeep];
    *obLast       = data->outState[s_obLast] ? 1 : 0;
    *ibReady      = data->outState[s_ibReady] ? 1 : 0;
}
