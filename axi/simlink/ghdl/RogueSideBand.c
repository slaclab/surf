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
// GHDL-specific plumbing: a per-edge update procedure (rogueSideBandUpdate)
// that decodes the VHPIDIRECT parameters into the input snapshot and runs one
// FSM step, plus one zero-arg getter per output port. GHDL has no VHPI (no
// vhpi_register_cb / value-change callbacks), so vhpi_printf and vhpi_assert
// are shimmed to printf/abort in RogueSideBand.h.
//////////////////////////////////////////////////////////////////////////////

#include <zmq.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "RogueSideBand.h"
#include "RogueSideBandCore.h"

// Single instance for this simulation; file-scope statics are zero-
// initialized by C, replacing the src Init's malloc+memset.
static RogueSideBandData sideBandData;

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
void rogueSideBandUpdate(unsigned char clkRst, unsigned char *portNum,
                          unsigned char *txOpCode, unsigned char txOpCodeEn,
                          unsigned char *txRemData) {
    RogueSideBandData *data = &sideBandData;
    unsigned int reqPort = decodeVector(portNum, 16);

    // VHPIDIRECT foreign subprograms carry no per-instance context, so this
    // backend hosts a single global sideBandData and supports only one
    // RogueSideBand per simulation. A second instance would otherwise silently
    // share this state and bind only the first port. Fail fast once a
    // different, already-latched port is observed rather than corrupt state.
    if ( data->port != 0 && reqPort != 0 && reqPort != data->port ) {
        vhpi_printf("RogueSideBand: GHDL VHPIDIRECT backend supports only one instance per simulation; observed ports %u and %u\n", data->port, reqPort);
        vhpi_assert("RogueSideBand: multiple instances unsupported under GHDL VHPIDIRECT", vhpiFatal);
        return;
    }

    data->inSnap[s_reset]      = decodeBit(clkRst);
    data->inSnap[s_port]       = reqPort;
    data->inSnap[s_txOpCode]   = decodeVector(txOpCode, 8);
    data->inSnap[s_txOpCodeEn] = decodeBit(txOpCodeEn);
    data->inSnap[s_txRemData]  = decodeVector(txRemData, 8);

    RogueSideBandStep(data);
}

// Zero-argument getters, one per output port, reproducing
// VhpiGenericConvertOut's enum-ordinal encoding.
void rogueSideBandGetRxOpCode(unsigned char *ret) {
    encodeVector(sideBandData.outState[s_rxOpCode], ret, 8);
}

unsigned char rogueSideBandGetRxOpCodeEn(void) {
    return encodeBit(sideBandData.outState[s_rxOpCodeEn]);
}

void rogueSideBandGetRxRemData(unsigned char *ret) {
    encodeVector(sideBandData.outState[s_rxRemData], ret, 8);
}
