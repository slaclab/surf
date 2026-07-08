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
// plumbing: a per-edge update function (rogueSideBandUpdate) that copies the
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
#include "RogueSideBand.h"
#include "RogueSideBandCore.h"

// Single instance for this simulation; file-scope statics are zero-
// initialized by C, replacing the src Init's malloc+memset.
static RogueSideBandData sideBandData;

// Per-edge update function, called from the RogueSideBandDpi SV leaf every
// rising_edge(clock) via import "DPI-C". Copies each DPI parameter straight
// into the input snapshot (the getInt seam), runs one shared FSM step, then
// writes the outputs back through the DPI output pointers.
void rogueSideBandUpdate(unsigned char reset, const svBitVecVal *portNum,
                          const svBitVecVal *txOpCode, unsigned char txOpCodeEn, const svBitVecVal *txRemData,
                          svBitVecVal *rxOpCode, unsigned char *rxOpCodeEn, svBitVecVal *rxRemData) {
    RogueSideBandData *data = &sideBandData;
    unsigned int reqPort = portNum[0] & 0xFFFF;

    // DPI-C imports carry no per-instance context, so this backend hosts a
    // single global sideBandData and supports only one RogueSideBand per
    // simulation. A second instance would otherwise silently share this
    // state and bind only the first port. Fail fast once a different,
    // already-latched port is observed rather than corrupt state.
    if ( data->port != 0 && reqPort != 0 && reqPort != data->port ) {
        vhpi_printf("RogueSideBand: Vivado xsim DPI-C backend supports only one instance per simulation; observed ports %u and %u\n", data->port, reqPort);
        vhpi_assert("RogueSideBand: multiple instances unsupported under Vivado xsim DPI-C", vhpiFatal);
        return;
    }

    data->inSnap[s_reset]      = reset ? 1 : 0;
    data->inSnap[s_port]       = reqPort;
    data->inSnap[s_txOpCode]   = txOpCode[0];
    data->inSnap[s_txOpCodeEn] = txOpCodeEn ? 1 : 0;
    data->inSnap[s_txRemData]  = txRemData[0];

    // RogueSideBandStep (shared FSM) calls RogueSideBandRecv, which uses
    // ZMQ_DONTWAIT -- never make this a blocking call, or it freezes the
    // whole Vivado xsim process, not just a background thread.
    RogueSideBandStep(data);

    rxOpCode[0]  = data->outState[s_rxOpCode];
    *rxOpCodeEn  = data->outState[s_rxOpCodeEn] ? 1 : 0;
    rxRemData[0] = data->outState[s_rxRemData];
}
