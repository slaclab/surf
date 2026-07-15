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
// Shared Rogue-TCP AXI-Stream core: the ZMQ transport
// (RogueTcpStreamRestart/Send/Recv) and the AXI-Stream data-movement FSM
// (RogueTcpStreamStep). Included by both the VHPI backend
// (axi/simlink/vcs/RogueTcpStream.c) and the GHDL VHPIDIRECT backend
// (axi/simlink/ghdl/RogueTcpStream.c) so the two share a single source of
// truth for the wire protocol and the state machine.
//
// Include this exactly once, after the backend's RogueTcpStream.h, which
// supplies RogueTcpStreamData, the s_*/MAX_FRAME defines, the getInt/setInt
// accessor seam (data->inSnap / data->outState), and the vhpi_printf/vhpi_assert
// bindings. The FSM step runs once per rising clock edge; the caller is
// responsible for edge detection and for moving port values in/out of the
// inSnap/outState snapshot arrays.
//////////////////////////////////////////////////////////////////////////////

#ifndef __ROGUE_TCP_STREAM_CORE_H__
#define __ROGUE_TCP_STREAM_CORE_H__

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <zmq.h>

// Start/restart zeromq server
void RogueTcpStreamRestart(RogueTcpStreamData *data) {
    char buffer[100];

    if ( data->zmqPush != NULL ) zmq_close(data->zmqPush );
    if ( data->zmqPull != NULL ) zmq_close(data->zmqPull );
    if ( data->zmqCtx  != NULL ) zmq_term(data->zmqCtx);

    data->zmqCtx   = NULL;
    data->zmqPush  = NULL;
    data->zmqPull  = NULL;

    data->zmqCtx = zmq_ctx_new();
    data->zmqPull  = zmq_socket(data->zmqCtx, ZMQ_PULL);
    data->zmqPush  = zmq_socket(data->zmqCtx, ZMQ_PUSH);

    vhpi_printf("RogueTcpStream: Listening on ports %i & %i\n", data->port, data->port+1);

    snprintf(buffer, sizeof(buffer), "tcp://127.0.0.1:%i", data->port);
    if ( zmq_bind(data->zmqPull, buffer) ) {
        vhpi_assert("RogueTcpStream: Failed to bind pull port", vhpiFatal);
        return;
    }

    snprintf(buffer, sizeof(buffer), "tcp://127.0.0.1:%i", data->port+1);
    if ( zmq_bind(data->zmqPush, buffer) ) {
        vhpi_assert("RogueTcpStream: Failed to bind push port", vhpiFatal);
        return;
    }
}

// Send a message
void RogueTcpStreamSend(RogueTcpStreamData *data) {
    zmq_msg_t msg[4];
    uint16_t  flags;
    uint8_t   chan;
    uint8_t   err;
    uint32_t  x;
    int error;

    if ( (zmq_msg_init_size(&(msg[0]), 2) < 0) ||   // Flags
         (zmq_msg_init_size(&(msg[1]), 1) < 0) ||   // Channel
         (zmq_msg_init_size(&(msg[2]), 1) < 0) ) {  // Error
        vhpi_assert("RogueTcpStream: Failed to init message header", vhpiFatal);
        return;
    }

    if (zmq_msg_init_size(&(msg[3]), data->ibSize) < 0) {
        vhpi_assert("RogueTcpStream: Failed to init message", vhpiFatal);
        return;
    }

    if ( data->ssi ) {
        flags  = (data->ibFuser & 0xFF);
        flags |= ((data->ibLuser << 8) & 0xFF00);
        err    = data->ibLuser & 0x1;
    } else {
        flags = 0;
        err   = 0;
    }
    chan = 0;

    memcpy(zmq_msg_data(&(msg[0])), &flags, 2);
    memcpy(zmq_msg_data(&(msg[1])), &chan,  1);
    memcpy(zmq_msg_data(&(msg[2])), &err,   1);

    // Copy data
    memcpy(zmq_msg_data(&(msg[3])), data->ibData, data->ibSize);

    // Send data
    for (x=0; x < 4; x++) {
        if ( zmq_msg_send(&(msg[x]), data->zmqPush, (x == 3)?0:ZMQ_SNDMORE) < 0 ) {
            error = errno;
            vhpi_printf("Failed to send message on port %i - x: %i - err: %i\n", data->port+1, x, error);
            vhpi_printf("Error: %s\n", strerror(error));
            vhpi_assert("RogueTcpStream: Failed to send message", vhpiFatal);
        }
    }
    vhpi_printf("RogueTcpStream: Send data: Size: %i, flags: %x, chan: %x, err: %x, port: %i\n", data->ibSize, flags, chan, err, data->port+1);
    data->ibSize = 0;
}

// Receive data if it is available
int RogueTcpStreamRecv(RogueTcpStreamData *data) {
    int64_t   more;
    size_t    moreSize;
    uint32_t  size;
    zmq_msg_t msg[4];
    uint32_t  msgCnt;
    uint16_t  flags;
    uint8_t   chan;
    uint8_t   err;
    uint32_t  x;

    for (x=0; x < 4; x++) zmq_msg_init(&(msg[x]));
    msgCnt = 0;
    x = 0;

    // Get message
    do {
        // Get the message
        if ( zmq_recvmsg(data->zmqPull, &(msg[x]), ZMQ_DONTWAIT) > 0 ) {
            if ( x != 3 ) x++;
            msgCnt++;

            // Is there more data?
            more = 0;
            moreSize = 8;
            zmq_getsockopt(data->zmqPull, ZMQ_RCVMORE, &more, &moreSize);
        } else {
            more = 0;
        }
    } while ( more );

    // Proper message received
    if ( msgCnt == 4 ) {
        // Check sizes
        if ( (zmq_msg_size(&(msg[0])) != 2) || (zmq_msg_size(&(msg[1])) != 1) || (zmq_msg_size(&(msg[2])) != 1) ) {
            vhpi_assert("RogueTcpStream: Bad message sizes", vhpiFatal);
            for (x=0; x < msgCnt; x++) zmq_msg_close(&(msg[x]));
            return 0;
        }

        // Get fields
        memcpy(&flags, zmq_msg_data(&(msg[0])), 2);
        memcpy(&chan,  zmq_msg_data(&(msg[1])), 1);
        memcpy(&err,   zmq_msg_data(&(msg[2])), 1);

        // Get message info
        size = zmq_msg_size(&(msg[3]));

        // Reject the peer-controlled frame before it overruns the fixed
        // obData[MAX_FRAME] buffer
        if ( size > MAX_FRAME ) {
            vhpi_assert("RogueTcpStream: Receive frame size exceeds MAX_FRAME", vhpiFatal);
            for (x=0; x < 4; x++) zmq_msg_close(&(msg[x]));
            return 0;
        }

        // Set data
        memcpy(data->obData, zmq_msg_data(&(msg[3])), size);
        data->obSize  = size;
        data->obFuser = flags & 0xFF;
        data->obLuser = (flags >> 8) & 0xFF;

        if ( data->ssi ) {
            data->obFuser |= 0x02;
            if ( err ) data->obLuser |= 0x01;
        }

        vhpi_printf("RogueTcpStream: Recv data: Size: %i, flags: %x, chan: %i, err: %i, port: %i\n", data->obSize, flags, chan, err, data->port);

    } else {
        size = 0;
    }

    for (x=0; x < 4; x++) zmq_msg_close(&(msg[x]));

    return(size);
}

// AXI-Stream data-movement FSM, run once per rising clock edge. Reads the
// input snapshot via getInt and drives the output state via setInt.
void RogueTcpStreamStep(RogueTcpStreamData *data) {
    uint32_t x;
    uint32_t keep;
    uint32_t dLow;
    uint32_t dHigh;
    uint32_t uLow;
    uint32_t uHigh;

    // Reset is asserted
    if ( getInt(s_reset) == 1 ) {
        data->obCount = 0;
        data->obSize  = 0;
        data->ibSize  = 0;
        data->obValid = 0;
        setInt(s_obValid, 0);
        setInt(s_ibReady, 1);
        setInt(s_obDataLow, 0);
        setInt(s_obDataHigh, 0);
        setInt(s_obUserLow, 0);
        setInt(s_obUserHigh, 0);
        setInt(s_obKeep, 0);
        setInt(s_obLast, 0);

    // Data movement
    } else {
        // Port not yet assigned
        if ( data->port == 0 ) {
            data->port = getInt(s_port);
            data->ssi  = getInt(s_ssi);
            RogueTcpStreamRestart(data);
        }

        // Inbound
        if (getInt(s_ibValid)) {
            keep  = getInt(s_ibKeep);
            dLow  = getInt(s_ibDataLow);
            dHigh = getInt(s_ibDataHigh);
            uLow  = getInt(s_ibUserLow);
            uHigh = getInt(s_ibUserHigh);

            // First
            if ( data->ibSize == 0 ) data->ibFuser = uLow & 0xFF;

            // Get data
            for (x=0; x< 8; x++) {
                if ( (keep >> x) & 1 ) {
                    // Guard the fixed ibData[MAX_FRAME] buffer against a frame
                    // that keeps streaming past capacity before asserting
                    // tLast. Unkept lanes neither consume nor touch storage.
                    if ( data->ibSize >= MAX_FRAME ) {
                        vhpi_assert("RogueTcpStream: Inbound frame size exceeds MAX_FRAME", vhpiFatal);
                        return;
                    }
                    if ( x < 4 ) {
                        data->ibData[data->ibSize] = (dLow >> (x*8)) & 0xFF;
                        data->ibLuser = (uLow >> (x*8)) & 0xFF;
                    } else {
                        data->ibData[data->ibSize] = (dHigh >> ((x-4)*8)) & 0xFF;
                        data->ibLuser = (uHigh >> ((x-4)*8)) & 0xFF;
                    }
                    data->ibSize++;
                }
            }

            // Last
            if ( getInt(s_ibLast) ) RogueTcpStreamSend(data);
        }

        // Not in frame
        if ( data->obSize == 0 ) RogueTcpStreamRecv(data);

        // Data accepted
        if ( getInt(s_obReady) ) {
            data->obValid = 0;
            setInt(s_obLast, 0);
        }

        // Valid not asserted and data is ready
        if ( data->obValid == 0 && data->obSize > 0 ) {
            // First user
            if ( data->obCount == 0 ) {
                setInt(s_obUserLow, data->obFuser);
            } else {
                setInt(s_obUserLow, 0);
            }
            setInt(s_obUserHigh, 0);

            // Get data
            dHigh = 0;
            dLow  = 0;
            keep  = 0;

            // Set data
            for (x=0; x< 8; x++) {
                if ( x < 4 ) {
                    dLow |= (data->obData[data->obCount] << (x*8));
                    if ( (data->obCount+1) == data->obSize ) {
                        if (data->obCount < 4) {
                            setInt(s_obUserLow, (data->obLuser << (x*8))|(data->obFuser));
                        } else {
                            setInt(s_obUserLow, (data->obLuser << (x*8)));
                        }
                    }
                } else {
                    dHigh |= (data->obData[data->obCount] << ((x-4)*8));
                    if ( (data->obCount+1) == data->obSize )
                        setInt(s_obUserHigh, (data->obLuser << ((x-4)*8)));
                }

                data->obCount++;
                if ( data->obCount <= data->obSize ) keep |= (1 << x);
            }
            setInt(s_obDataLow, dLow);
            setInt(s_obDataHigh, dHigh);
            setInt(s_obKeep, keep);
            data->obValid = 1;

            // Done
            if ( data->obCount >= data->obSize ) {
                setInt(s_obLast, 1);
                data->obSize  = 0;
                data->obCount = 0;
            }
        }

        // Output valid
        setInt(s_obValid, data->obValid);
    }
}

#endif
