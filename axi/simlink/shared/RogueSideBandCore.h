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
// Shared Rogue side-band core: the ZMQ transport
// (RogueSideBandRestart/Send/Recv) and the opcode/remData FSM
// (RogueSideBandStep). Included by both the VHPI backend
// (axi/simlink/vcs/RogueSideBand.c) and the GHDL VHPIDIRECT backend
// (axi/simlink/ghdl/RogueSideBand.c) so the two share a single source of
// truth for the wire protocol and the state machine.
//
// Include this exactly once, after the backend's RogueSideBand.h, which
// supplies RogueSideBandData, the s_* defines, the getInt/setInt accessor seam
// (data->inSnap / data->outState), and the vhpi_printf/vhpi_assert bindings.
// The FSM step runs once per rising clock edge; the caller is responsible for
// edge detection and for moving port values in/out of the inSnap/outState
// snapshot arrays.
//
// Note the ZMQ bind order is the mirror of the Rogue-TCP stream/memory cores:
// the side-band model binds PULL on port+1 and PUSH on port.
//////////////////////////////////////////////////////////////////////////////

#ifndef __ROGUE_SIDE_BAND_CORE_H__
#define __ROGUE_SIDE_BAND_CORE_H__

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <zmq.h>

// Start/restart zeromq server
void RogueSideBandRestart(RogueSideBandData *data) {
    char buffer[100];

    if ( data->zmqPush != NULL ) zmq_close(data->zmqPush );
    if ( data->zmqPull != NULL ) zmq_close(data->zmqPull );
    if ( data->zmqCtx  != NULL ) zmq_term(data->zmqCtx);

    data->zmqCtx   = NULL;
    data->zmqPush  = NULL;
    data->zmqPull  = NULL;

    data->zmqCtx  = zmq_ctx_new();
    data->zmqPull = zmq_socket(data->zmqCtx, ZMQ_PULL);
    data->zmqPush = zmq_socket(data->zmqCtx, ZMQ_PUSH);

    vhpi_printf("RogueSideBand: Listening on ports %i & %i\n", data->port, data->port+1);

    snprintf(buffer, sizeof(buffer), "tcp://127.0.0.1:%i", data->port+1);
    if ( zmq_bind(data->zmqPull, buffer) ) {
        vhpi_assert("RogueSideBand: Failed to bind sideband port", vhpiFatal);
        return;
    }

    snprintf(buffer, sizeof(buffer), "tcp://127.0.0.1:%i", data->port);
    if ( zmq_bind(data->zmqPush, buffer) ) {
        vhpi_assert("RogueSideBand: Failed to bind push port", vhpiFatal);
        return;
    }
}

// Send a message
void RogueSideBandSend(RogueSideBandData *data) {
    zmq_msg_t msg;
    uint8_t   ba[4];
    char buffer[200];

    if ( (zmq_msg_init_size(&msg, 4) < 0) ) {
        vhpi_assert("RogueSideBand: Failed to init message", vhpiFatal);
        return;
    }

    ba[0] = data->txOpCodeEn;
    ba[1] = data->txOpCode;
    ba[2] = data->txRemDataChanged;
    ba[3] = data->txRemData;

    memcpy(zmq_msg_data(&msg), ba, 4);

    // Send data
    if ( zmq_msg_send(&msg, data->zmqPush, 0) < 0 ) {
        snprintf(buffer, sizeof(buffer), "RogueSideBand: Failed to send opcode: %x, remData: %x, on port %i\n", data->txOpCode, data->txRemData, data->port);
        vhpi_assert(buffer, vhpiFatal);
    }
    if (data->txOpCodeEn) {
        vhpi_printf("RogueSideBand: Sent Opcode: %x on port %i\n", data->txOpCode, data->port);
    }
    if (data->txRemDataChanged) {
        vhpi_printf("RogueSideBand: Sent remData: %x on port %i\n", data->txRemData, data->port);
    }
}

// Receive side data if it is available
int RogueSideBandRecv(RogueSideBandData *data) {
    uint8_t * rd;
    uint32_t  rsize;
    zmq_msg_t rMsg;

    zmq_msg_init(&rMsg);
    if ( zmq_msg_recv(&rMsg, data->zmqPull, ZMQ_DONTWAIT) <= 0 ) {
        zmq_msg_close(&rMsg);
        return(0);
    }

    rd    = zmq_msg_data(&rMsg);
    rsize = zmq_msg_size(&rMsg);

    if ( rsize == 4 ) {
        if ( rd[0] == 0x01 ) {
            data->rxOpCode   = rd[1];
            data->rxOpCodeEn = 1;
            vhpi_printf("RogueSideBand: Got opcode 0x%02x on port %i\n", data->rxOpCode, data->port+1);
        }
        if ( rd[2] == 0x01 ) {
            data->rxRemData = rd[3];
            vhpi_printf("RogueSideBand: Got data 0x%02x on port %i\n", data->rxRemData, data->port+1);
        }
    }
    zmq_msg_close(&rMsg);
    return(rsize);
}

// Side-band FSM, run once per rising clock edge. Reads the input snapshot via
// getInt and drives the output state via setInt.
void RogueSideBandStep(RogueSideBandData *data) {
    uint8_t send = 0;

    // Reset is asserted
    if ( getInt(s_reset) == 1 ) {
        data->rxRemData        = 0x00;
        data->rxOpCode         = 0x00;
        data->rxOpCodeEn       = 0;
        data->txRemData        = 0x00;
        data->txRemDataChanged = 0x00;
        data->txOpCode         = 0x00;
        data->txOpCodeEn       = 0;
        setInt(s_rxOpCodeEn, 0);
        setInt(s_rxOpCode, 0);
        setInt(s_rxRemData, 0);

    // Out of reset
    } else {
        // Port not yet assigned
        if ( data->port == 0 ) {
            data->port = getInt(s_port);
            RogueSideBandRestart(data);
        }

        // TX OpCode
        if (getInt(s_txOpCodeEn)) {
            data->txOpCode   = getInt(s_txOpCode);
            data->txOpCodeEn = getInt(s_txOpCodeEn);
            send = 1;
        }

        // TX RemData
        if (getInt(s_txRemData) != data->txRemData) {
            data->txRemData        = getInt(s_txRemData);
            data->txRemDataChanged = 1;
            send = 1;
        }

        if (send) {
            RogueSideBandSend(data);
        }

        // Rx Data
        RogueSideBandRecv(data);
        setInt(s_rxRemData, data->rxRemData);
        setInt(s_rxOpCode, data->rxOpCode);
        setInt(s_rxOpCodeEn, data->rxOpCodeEn);
        data->rxOpCodeEn = 0;  // Only for one clock
    }
}

#endif
