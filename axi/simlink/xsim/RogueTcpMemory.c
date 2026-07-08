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
// Vivado xsim DPI-C backend for the Rogue-TCP AXI-Lite memory model. The ZMQ
// transport (RogueTcpMemoryRestart/Send/Recv) and the transaction FSM
// (RogueTcpMemoryStep) live in axi/simlink/shared/RogueTcpMemoryCore.h,
// included by every backend. This file provides only the DPI-specific
// plumbing: a per-edge update function (rogueTcpMemoryUpdate) that copies the
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
#include "RogueTcpMemory.h"
#include "RogueTcpMemoryCore.h"

// Single instance for this simulation; file-scope statics are zero-
// initialized by C, replacing the src Init's malloc+memset.
static RogueTcpMemoryData memoryData;

// Per-edge update function, called from the RogueTcpMemoryDpi SV leaf every
// rising_edge(clock) via import "DPI-C". Copies each DPI parameter straight
// into the input snapshot (the getInt seam), runs one shared FSM step, then
// writes the outputs back through the DPI output pointers.
void rogueTcpMemoryUpdate(unsigned char reset, const svBitVecVal *portNum,
                           svBitVecVal *araddr, svBitVecVal *arprot, unsigned char *arvalid, unsigned char *rready,
                           unsigned char arready, const svBitVecVal *rdata, const svBitVecVal *rresp, unsigned char rvalid,
                           svBitVecVal *awaddr, svBitVecVal *awprot, unsigned char *awvalid,
                           svBitVecVal *wdata, svBitVecVal *wstrb, unsigned char *wvalid, unsigned char *bready,
                           unsigned char awready, unsigned char wready, const svBitVecVal *bresp, unsigned char bvalid) {
    RogueTcpMemoryData *data = &memoryData;
    unsigned int reqPort = portNum[0] & 0xFFFF;

    // DPI-C imports carry no per-instance context, so this backend hosts a
    // single global memoryData and supports only one RogueTcpMemory per
    // simulation. A second instance would otherwise silently share this
    // state and bind only the first port. Fail fast once a different,
    // already-latched port is observed rather than corrupt state.
    if ( data->port != 0 && reqPort != 0 && reqPort != data->port ) {
        vhpi_printf("RogueTcpMemory: Vivado xsim DPI-C backend supports only one instance per simulation; observed ports %u and %u\n", data->port, reqPort);
        vhpi_assert("RogueTcpMemory: multiple instances unsupported under Vivado xsim DPI-C", vhpiFatal);
        return;
    }

    data->inSnap[s_reset]   = reset ? 1 : 0;
    data->inSnap[s_port]    = reqPort;
    data->inSnap[s_arready] = arready ? 1 : 0;
    data->inSnap[s_rdata]   = rdata[0];
    data->inSnap[s_rresp]   = rresp[0];
    data->inSnap[s_rvalid]  = rvalid ? 1 : 0;
    data->inSnap[s_awready] = awready ? 1 : 0;
    data->inSnap[s_wready]  = wready ? 1 : 0;
    data->inSnap[s_bresp]   = bresp[0];
    data->inSnap[s_bvalid]  = bvalid ? 1 : 0;

    // RogueTcpMemoryStep (shared FSM) calls RogueTcpMemoryRecv, which uses
    // ZMQ_DONTWAIT -- never make this a blocking call, or it freezes the
    // whole Vivado xsim process, not just a background thread.
    RogueTcpMemoryStep(data);

    araddr[0]  = data->outState[s_araddr];
    arprot[0]  = data->outState[s_arprot];
    *arvalid   = data->outState[s_arvalid] ? 1 : 0;
    *rready    = data->outState[s_rready]  ? 1 : 0;
    awaddr[0]  = data->outState[s_awaddr];
    awprot[0]  = data->outState[s_awprot];
    *awvalid   = data->outState[s_awvalid] ? 1 : 0;
    wdata[0]   = data->outState[s_wdata];
    wstrb[0]   = data->outState[s_wstrb];
    *wvalid    = data->outState[s_wvalid]  ? 1 : 0;
    *bready    = data->outState[s_bready]  ? 1 : 0;
}
