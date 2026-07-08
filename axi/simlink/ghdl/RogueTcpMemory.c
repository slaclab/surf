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
// GHDL VHPIDIRECT backend for the Rogue-TCP AXI-Lite memory model. The ZMQ
// transport (RogueTcpMemoryRestart/Send/Recv) and the transaction FSM
// (RogueTcpMemoryStep) live in axi/simlink/shared/RogueTcpMemoryCore.h,
// included by both this backend and the VHPI backend. This file provides only
// the GHDL-specific plumbing: a per-edge update procedure (rogueTcpMemoryUpdate)
// that decodes the VHPIDIRECT parameters into the input snapshot and runs one
// FSM step, plus one zero-arg getter per output port. GHDL has no VHPI (no
// vhpi_register_cb / value-change callbacks), so vhpi_printf and vhpi_assert
// are shimmed to printf/abort in RogueTcpMemory.h.
//////////////////////////////////////////////////////////////////////////////

#include <zmq.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

#include "RogueTcpMemory.h"
#include "RogueVhpiDirect.h"
#include "RogueTcpMemoryCore.h"

// Single instance for this simulation; file-scope statics are zero-
// initialized by C, replacing the src Init's malloc+memset.
static RogueTcpMemoryData memoryData;

// Per-edge update procedure, called from VHDL every rising_edge(clock).
// Decodes each VHPIDIRECT parameter into the input snapshot (the getInt seam),
// then runs one shared FSM step. inSnap[s_clock] is intentionally never
// populated -- the FSM does not read it, since every call is already a rising
// edge and needs no edge detection.
void rogueTcpMemoryUpdate(unsigned char clkRst, unsigned char *portNum,
                           unsigned char arready, unsigned char *rdata, unsigned char *rresp,
                           unsigned char rvalid, unsigned char awready, unsigned char wready,
                           unsigned char *bresp, unsigned char bvalid) {
    RogueTcpMemoryData *data = &memoryData;
    unsigned int reqPort = rogueVhpiDirectDecodeVector(portNum, 16);

    // VHPIDIRECT foreign subprograms carry no per-instance context, so this
    // backend hosts a single global memoryData and supports only one
    // RogueTcpMemory per simulation. A second instance would otherwise silently
    // share this state and bind only the first port. Fail fast once a
    // different, already-latched port is observed rather than corrupt state.
    if ( data->port != 0 && reqPort != 0 && reqPort != data->port ) {
        vhpi_printf("RogueTcpMemory: GHDL VHPIDIRECT backend supports only one instance per simulation; observed ports %u and %u\n", data->port, reqPort);
        vhpi_assert("RogueTcpMemory: multiple instances unsupported under GHDL VHPIDIRECT", vhpiFatal);
        return;
    }

    data->inSnap[s_reset]   = rogueVhpiDirectDecodeBit(clkRst);
    data->inSnap[s_port]    = reqPort;
    data->inSnap[s_arready] = rogueVhpiDirectDecodeBit(arready);
    data->inSnap[s_rdata]   = rogueVhpiDirectDecodeVector(rdata, 32);
    data->inSnap[s_rresp]   = rogueVhpiDirectDecodeVector(rresp, 2);
    data->inSnap[s_rvalid]  = rogueVhpiDirectDecodeBit(rvalid);
    data->inSnap[s_awready] = rogueVhpiDirectDecodeBit(awready);
    data->inSnap[s_wready]  = rogueVhpiDirectDecodeBit(wready);
    data->inSnap[s_bresp]   = rogueVhpiDirectDecodeVector(bresp, 2);
    data->inSnap[s_bvalid]  = rogueVhpiDirectDecodeBit(bvalid);

    RogueTcpMemoryStep(data);
}

// Zero-argument getters, one per output port, reproducing
// VhpiGenericConvertOut's enum-ordinal encoding.
void rogueTcpMemoryGetAraddr(unsigned char *ret) {
    rogueVhpiDirectEncodeVector(memoryData.outState[s_araddr], ret, 32);
}

void rogueTcpMemoryGetArprot(unsigned char *ret) {
    rogueVhpiDirectEncodeVector(memoryData.outState[s_arprot], ret, 3);
}

unsigned char rogueTcpMemoryGetArvalid(void) {
    return rogueVhpiDirectEncodeBit(memoryData.outState[s_arvalid]);
}

unsigned char rogueTcpMemoryGetRready(void) {
    return rogueVhpiDirectEncodeBit(memoryData.outState[s_rready]);
}

void rogueTcpMemoryGetAwaddr(unsigned char *ret) {
    rogueVhpiDirectEncodeVector(memoryData.outState[s_awaddr], ret, 32);
}

void rogueTcpMemoryGetAwprot(unsigned char *ret) {
    rogueVhpiDirectEncodeVector(memoryData.outState[s_awprot], ret, 3);
}

unsigned char rogueTcpMemoryGetAwvalid(void) {
    return rogueVhpiDirectEncodeBit(memoryData.outState[s_awvalid]);
}

void rogueTcpMemoryGetWdata(unsigned char *ret) {
    rogueVhpiDirectEncodeVector(memoryData.outState[s_wdata], ret, 32);
}

void rogueTcpMemoryGetWstrb(unsigned char *ret) {
    rogueVhpiDirectEncodeVector(memoryData.outState[s_wstrb], ret, 4);
}

unsigned char rogueTcpMemoryGetWvalid(void) {
    return rogueVhpiDirectEncodeBit(memoryData.outState[s_wvalid]);
}

unsigned char rogueTcpMemoryGetBready(void) {
    return rogueVhpiDirectEncodeBit(memoryData.outState[s_bready]);
}
