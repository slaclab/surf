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
#include "RogueTcpMemoryCore.h"

// Single instance for this simulation; file-scope statics are zero-
// initialized by C, replacing the src Init's malloc+memset.
static RogueTcpMemoryData memoryData;

// Decode a std_logic scalar enum-ordinal byte ('1' == 3) into 0/1.
static unsigned int decodeBit(unsigned char val) {
    return (val == 3) ? 1 : 0;
}

// Decode a std_logic_vector enum-ordinal byte array, MSB-first (array index
// 0 is the vector's MSB, byte value 3 means bit set), into an unsigned int.
static unsigned int decodeVector(const unsigned char *val, unsigned int width) {
    unsigned int result;
    unsigned int y;
    unsigned int bit;

    result = 0;
    for (y = 0; y < width; y++) {
        bit = (width - 1) - y;
        if (val[y] == 3) result += (1U << bit);
    }
    return result;
}

// Encode 0/1 into a std_logic scalar enum-ordinal byte ('0' == 2, '1' == 3).
static unsigned char encodeBit(unsigned int val) {
    return (val == 0) ? 2 : 3;
}

// Encode an unsigned int into a std_logic_vector enum-ordinal byte array,
// MSB-first (array index 0 is the vector's MSB).
static void encodeVector(unsigned int val, unsigned char *ret, unsigned int width) {
    unsigned int y;
    unsigned int bit;

    for (y = 0; y < width; y++) {
        bit = (width - 1) - y;
        ret[y] = ((val >> bit) & 0x1) ? 3 : 2;
    }
}

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
    unsigned int reqPort = decodeVector(portNum, 16);

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

    data->inSnap[s_reset]   = decodeBit(clkRst);
    data->inSnap[s_port]    = reqPort;
    data->inSnap[s_arready] = decodeBit(arready);
    data->inSnap[s_rdata]   = decodeVector(rdata, 32);
    data->inSnap[s_rresp]   = decodeVector(rresp, 2);
    data->inSnap[s_rvalid]  = decodeBit(rvalid);
    data->inSnap[s_awready] = decodeBit(awready);
    data->inSnap[s_wready]  = decodeBit(wready);
    data->inSnap[s_bresp]   = decodeVector(bresp, 2);
    data->inSnap[s_bvalid]  = decodeBit(bvalid);

    RogueTcpMemoryStep(data);
}

// Zero-argument getters, one per output port, reproducing
// VhpiGenericConvertOut's enum-ordinal encoding.
void rogueTcpMemoryGetAraddr(unsigned char *ret) {
    encodeVector(memoryData.outState[s_araddr], ret, 32);
}

void rogueTcpMemoryGetArprot(unsigned char *ret) {
    encodeVector(memoryData.outState[s_arprot], ret, 3);
}

unsigned char rogueTcpMemoryGetArvalid(void) {
    return encodeBit(memoryData.outState[s_arvalid]);
}

unsigned char rogueTcpMemoryGetRready(void) {
    return encodeBit(memoryData.outState[s_rready]);
}

void rogueTcpMemoryGetAwaddr(unsigned char *ret) {
    encodeVector(memoryData.outState[s_awaddr], ret, 32);
}

void rogueTcpMemoryGetAwprot(unsigned char *ret) {
    encodeVector(memoryData.outState[s_awprot], ret, 3);
}

unsigned char rogueTcpMemoryGetAwvalid(void) {
    return encodeBit(memoryData.outState[s_awvalid]);
}

void rogueTcpMemoryGetWdata(unsigned char *ret) {
    encodeVector(memoryData.outState[s_wdata], ret, 32);
}

void rogueTcpMemoryGetWstrb(unsigned char *ret) {
    encodeVector(memoryData.outState[s_wstrb], ret, 4);
}

unsigned char rogueTcpMemoryGetWvalid(void) {
    return encodeBit(memoryData.outState[s_wvalid]);
}

unsigned char rogueTcpMemoryGetBready(void) {
    return encodeBit(memoryData.outState[s_bready]);
}
