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
// Shared Rogue-TCP AXI-Lite memory core: the ZMQ transport
// (RogueTcpMemoryRestart/Send/Recv) and the AXI-Lite master transaction FSM
// (RogueTcpMemoryStep). Included by both the VHPI backend
// (axi/simlink/vcs/RogueTcpMemory.c) and the GHDL VHPIDIRECT backend
// (axi/simlink/ghdl/RogueTcpMemory.c) so the two share a single source of
// truth for the wire protocol and the state machine.
//
// Include this exactly once, after the backend's RogueTcpMemory.h, which
// supplies RogueTcpMemoryData, the s_*/T_*/ST_*/MAX_DATA defines, the
// getInt/setInt accessor seam (data->inSnap / data->outState), and the
// vhpi_printf/vhpi_assert bindings. The FSM step runs once per rising clock
// edge; the caller is responsible for edge detection and for moving port
// values in/out of the inSnap/outState snapshot arrays.
//////////////////////////////////////////////////////////////////////////////

#ifndef __ROGUE_TCP_MEMORY_CORE_H__
#define __ROGUE_TCP_MEMORY_CORE_H__

#include <stdint.h>
#include <inttypes.h>
#include <stdio.h>
#include <string.h>
#include <zmq.h>

enum {
    MEM_ID_FRAME_C       = 0,
    MEM_ADDR_FRAME_C     = 1,
    MEM_SIZE_FRAME_C     = 2,
    MEM_TYPE_FRAME_C     = 3,
    MEM_DATA_FRAME_C     = 4,
    MEM_RESULT_FRAME_C   = 5,
    MEM_READ_REQ_FRAMES_C  = 4,
    MEM_WRITE_REQ_FRAMES_C = 5,
    MEM_RESP_FRAMES_C      = 6,
    MEM_U32_BYTES_C        = 4,
    MEM_ADDR_BYTES_C       = 8,
};

static void RogueTcpMemoryCloseMsgs(zmq_msg_t *msg, uint32_t count) {
    uint32_t x;

    for (x=0; x < count; x++) zmq_msg_close(&(msg[x]));
}

// Start/restart zeromq server
void RogueTcpMemoryRestart(RogueTcpMemoryData *data) {
    char buffer[100];

    if ( data->zmqPull  != NULL ) zmq_close(data->zmqPull);
    if ( data->zmqPush  != NULL ) zmq_close(data->zmqPush);
    if ( data->zmqCtx   != NULL ) zmq_term(data->zmqCtx);

    data->zmqCtx   = NULL;
    data->zmqPull  = NULL;
    data->zmqPush  = NULL;

    data->zmqCtx = zmq_ctx_new();
    data->zmqPull  = zmq_socket(data->zmqCtx, ZMQ_PULL);
    data->zmqPush  = zmq_socket(data->zmqCtx, ZMQ_PUSH);

    vhpi_printf("RogueTcpMemory: Listening on ports %i & %i\n", data->port, data->port+1);

    snprintf(buffer, sizeof(buffer), "tcp://127.0.0.1:%i", data->port);
    if ( zmq_bind(data->zmqPull, buffer) ) {
        vhpi_assert("RogueTcpMemory: Failed to bind pull port", vhpiFatal);
        return;
    }

    snprintf(buffer, sizeof(buffer), "tcp://127.0.0.1:%i", data->port+1);
    if ( zmq_bind(data->zmqPush, buffer) ) {
        vhpi_assert("RogueTcpMemory: Failed to bind push port", vhpiFatal);
        return;
    }
}

// Send a message
void RogueTcpMemorySend(RogueTcpMemoryData *data) {
    uint32_t  x;
    size_t    frameSize[MEM_RESP_FRAMES_C];
    zmq_msg_t msg[MEM_RESP_FRAMES_C];

    frameSize[MEM_ID_FRAME_C]     = MEM_U32_BYTES_C;
    frameSize[MEM_ADDR_FRAME_C]   = MEM_ADDR_BYTES_C;
    frameSize[MEM_SIZE_FRAME_C]   = MEM_U32_BYTES_C;
    frameSize[MEM_TYPE_FRAME_C]   = MEM_U32_BYTES_C;
    frameSize[MEM_DATA_FRAME_C]   = data->size;
    frameSize[MEM_RESULT_FRAME_C] = MEM_U32_BYTES_C;

    for (x=0; x < MEM_RESP_FRAMES_C; x++) {
        if (zmq_msg_init_size(&(msg[x]), frameSize[x]) < 0) {
            RogueTcpMemoryCloseMsgs(msg, x);
            vhpi_assert("RogueTcpMemory: Failed to init message", vhpiFatal);
            return;
        }
    }

    memcpy(zmq_msg_data(&(msg[MEM_ID_FRAME_C])), &(data->id),
           MEM_U32_BYTES_C);
    memcpy(zmq_msg_data(&(msg[MEM_ADDR_FRAME_C])), &(data->addr),
           MEM_ADDR_BYTES_C);
    memcpy(zmq_msg_data(&(msg[MEM_SIZE_FRAME_C])), &(data->size),
           MEM_U32_BYTES_C);
    memcpy(zmq_msg_data(&(msg[MEM_TYPE_FRAME_C])), &(data->type),
           MEM_U32_BYTES_C);
    memcpy(zmq_msg_data(&(msg[MEM_RESULT_FRAME_C])), &(data->result),
           MEM_U32_BYTES_C);

    // Copy data
    memcpy(zmq_msg_data(&(msg[MEM_DATA_FRAME_C])), data->data, data->size);

    // Send data
    for (x=0; x < MEM_RESP_FRAMES_C; x++) {
        if ( zmq_sendmsg(data->zmqPush, &(msg[x]),
                         (x == MEM_RESULT_FRAME_C)?0:ZMQ_SNDMORE) < 0 )
            vhpi_assert("RogueTcpMemory: Failed to send message", vhpiFatal);
    }
    RogueTcpMemoryCloseMsgs(msg, MEM_RESP_FRAMES_C);

    data->state = 0;
    data->curr  = 0;

    vhpi_printf("RogueTcpMemory: Send Tran: Id %i, Addr 0x%" PRIx64 ", Size %i, Type %i, Resp 0x%x\n", data->id, data->addr, data->size, data->type, data->result);
}

// Receive data if it is available
int RogueTcpMemoryRecv(RogueTcpMemoryData *data) {
    uint64_t  more;
    size_t    moreSize;
    uint32_t  x;
    uint32_t  msgCnt;
    uint32_t  size;
    zmq_msg_t msg[MEM_WRITE_REQ_FRAMES_C];

    for (x=0; x < MEM_WRITE_REQ_FRAMES_C; x++) zmq_msg_init(&(msg[x]));
    msgCnt = 0;
    x = 0;

    // Get message
    do {
        // Get the message
        if (zmq_recvmsg(data->zmqPull, &(msg[x]), ZMQ_DONTWAIT) > 0) {
            if ( x != MEM_DATA_FRAME_C ) x++;
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
    if (msgCnt == MEM_READ_REQ_FRAMES_C || msgCnt == MEM_WRITE_REQ_FRAMES_C) {
        // Check sizes
        if ( (zmq_msg_size(&(msg[MEM_ID_FRAME_C])) != MEM_U32_BYTES_C) ||
             (zmq_msg_size(&(msg[MEM_ADDR_FRAME_C])) != MEM_ADDR_BYTES_C) ||
             (zmq_msg_size(&(msg[MEM_SIZE_FRAME_C])) != MEM_U32_BYTES_C) ||
             (zmq_msg_size(&(msg[MEM_TYPE_FRAME_C])) != MEM_U32_BYTES_C) ) {
            vhpi_assert("RogueTcpMemory: Bad message size", vhpiFatal);
            RogueTcpMemoryCloseMsgs(msg, MEM_WRITE_REQ_FRAMES_C);
            return 0;
        }

        // Get fields
        memcpy(&(data->id), zmq_msg_data(&(msg[MEM_ID_FRAME_C])),
               MEM_U32_BYTES_C);
        memcpy(&(data->addr), zmq_msg_data(&(msg[MEM_ADDR_FRAME_C])),
               MEM_ADDR_BYTES_C);
        memcpy(&(data->size), zmq_msg_data(&(msg[MEM_SIZE_FRAME_C])),
               MEM_U32_BYTES_C);
        memcpy(&(data->type), zmq_msg_data(&(msg[MEM_TYPE_FRAME_C])),
               MEM_U32_BYTES_C);

        // Validate the peer-declared size before it is trusted below. It must
        // fit the fixed data[MAX_DATA] buffer, and it must be a whole number of
        // 32-bit words: the AXI-Lite FSM advances curr four bytes per beat and
        // finishes only when curr == size, so a non-word-sized request would
        // overrun data[] (curr steps past size) and never terminate.
        if ( (data->size > MAX_DATA) || ((data->size % MEM_U32_BYTES_C) != 0) ) {
            vhpi_assert("RogueTcpMemory: Transaction size invalid (exceeds MAX_DATA or not 32-bit word aligned)", vhpiFatal);
            RogueTcpMemoryCloseMsgs(msg, MEM_WRITE_REQ_FRAMES_C);
            return 0;
        }

        // Write data is expected
        if ( (data->type == T_WRITE) || (data->type == T_POST) ) {
            if ( (msgCnt != MEM_WRITE_REQ_FRAMES_C) ||
                 (zmq_msg_size(&(msg[MEM_DATA_FRAME_C])) != data->size) ) {
                vhpi_assert("RogueTcpMemory: Transaction write data error", vhpiFatal);
                RogueTcpMemoryCloseMsgs(msg, MEM_WRITE_REQ_FRAMES_C);
                return 0;
            }
        }

        // Data pointer
        if ( (data->type == T_WRITE) || (data->type == T_POST) ) {
            memcpy(data->data, zmq_msg_data(&(msg[MEM_DATA_FRAME_C])), data->size);
        }
        data->state  = ST_START;
        data->curr   = 0;
        data->result = 0;

        vhpi_printf("RogueTcpMemory: Got Tran: Id %i, Addr 0x%" PRIx64 ", Size %i, Type %i\n", data->id, data->addr, data->size, data->type);

        size = data->size;
        RogueTcpMemoryCloseMsgs(msg, MEM_WRITE_REQ_FRAMES_C);
        return(size);
    }

    RogueTcpMemoryCloseMsgs(msg, MEM_WRITE_REQ_FRAMES_C);
    return (0);
}

// AXI-Lite master transaction FSM, run once per rising clock edge. Reads the
// input snapshot via getInt and drives the output state via setInt.
void RogueTcpMemoryStep(RogueTcpMemoryData *data) {
    uint32_t data32;

    // Reset is asserted
    if ( getInt(s_reset) == 1 ) {
        data->state = ST_IDLE;
        setInt(s_arvalid, 0);
        setInt(s_rready, 1);
        setInt(s_awvalid, 0);
        setInt(s_bready, 1);

    // Data movement
    } else {
        // Port not yet assigned
        if ( data->port == 0 ) {
            data->port = getInt(s_port);
            RogueTcpMemoryRestart(data);
        }

        switch (data->state) {
            // Idle get new data
            case ST_IDLE:
                RogueTcpMemoryRecv(data);
                break;

            // Start, present transaction
            case ST_START:

                // Write
                if ( data->type == T_WRITE || data->type == T_POST ) {
                    setInt(s_awaddr, (data->addr+data->curr));
                    setInt(s_awprot, 0);
                    setInt(s_awvalid, 1);
                    setInt(s_bready, 1);

                    data32  = data->data[data->curr++]         & 0x000000FF;
                    data32 |= (data->data[data->curr++] <<  8) & 0x0000FF00;
                    data32 |= (data->data[data->curr++] << 16) & 0x00FF0000;
                    data32 |= (data->data[data->curr++] << 24) & 0xFF000000;

                    setInt(s_wdata, data32);
                    setInt(s_wstrb, 0xF);
                    setInt(s_wvalid, 1);
                    data->state = ST_WRESP;

                // Read
                } else {
                    setInt(s_araddr, (data->addr+data->curr));
                    setInt(s_arprot, 0);
                    setInt(s_arvalid, 1);
                    setInt(s_rready, 1);
                    data->state = ST_RADDR;
                }
                break;

            // Write response
            case ST_WRESP:

                if ( getInt(s_awready) ) setInt(s_awvalid, 0);
                if ( getInt(s_wready)  ) setInt(s_wvalid, 0);

                if ( getInt(s_bvalid) ) {
                    // setInt(s_bready,0);
                    data->result = getInt(s_bresp);

                    if (data->curr == data->size) {
                        RogueTcpMemorySend(data);  // state goes to idle
                    } else {
                        data->state = ST_PAUSE;
                    }
                }
                break;

            // Read address
            case ST_RADDR:
                if ( getInt(s_arready) ) {
                    setInt(s_arvalid, 0);
                    setInt(s_rready, 1);
                    data->state = ST_RDATA;
                }
                break;

            // Read data
            case ST_RDATA:
                if ( getInt(s_rvalid) ) {
                    data32 = getInt(s_rdata);
                    data->result = getInt(s_rresp);

                    data->data[data->curr++] = data32 & 0xFF;
                    data->data[data->curr++] = (data32 >>  8) & 0xFF;
                    data->data[data->curr++] = (data32 >> 16) & 0xFF;
                    data->data[data->curr++] = (data32 >> 24) & 0xFF;

                    // setInt(s_rready,0);

                    if (data->curr == data->size) {
                        RogueTcpMemorySend(data);  // state goes to idle
                    } else {
                        data->state = ST_PAUSE;
                    }
                }
                break;

            // Wait for RVALID and BVALID to fall
            case ST_PAUSE:
                if ( getInt(s_rvalid) == 0 && getInt(s_bvalid) == 0 ) {
                    data->state = ST_START;
                    break;
                }
        }
    }
}

#endif
