//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef __ROGUE_TCP_STREAM_H__
#define __ROGUE_TCP_STREAM_H__

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "svdpi.h"

// Signals
#define s_clock        0
#define s_reset        1
#define s_port         2
#define s_ssi          3

#define s_obValid      4
#define s_obReady      5
#define s_obDataLow    6
#define s_obDataHigh   7
#define s_obUserLow    8
#define s_obUserHigh   9
#define s_obKeep       10
#define s_obLast       11

#define s_ibValid      12
#define s_ibReady      13
#define s_ibDataLow    14
#define s_ibDataHigh   15
#define s_ibUserLow    16
#define s_ibUserHigh   17
#define s_ibKeep       18
#define s_ibLast       19

#define PORT_COUNT     20

#define MAX_FRAME 20000000

// Vivado xsim's DPI-C boundary has no VHPI (no vhpi_register_cb / value-change
// callbacks), so the VHPI print/assert calls in the transplanted FSM body are
// shimmed straight to printf/abort. The severity argument is accepted but
// never referenced, so no VHPI severity token (e.g. vhpiFatal) needs defining.
// This shim is backend-agnostic and is shared verbatim with the GHDL backend.
#define vhpi_printf(...) printf(__VA_ARGS__)
#define vhpi_assert(msg, sev) \
    do { \
        fprintf(stderr, "%s\n", (msg)); \
        abort(); \
    } while (0)

// Macros for get/set ints, redefined for the per-edge update-procedure model:
// getInt reads the input snapshot populated at update-procedure entry;
// setInt writes the output state read back through the DPI output pointers.
#define getInt(idx)      (data->inSnap[idx])
#define setInt(idx, val) (data->outState[idx] = (val))

// Structure to track state
typedef struct {
    uint8_t   obFuser;
    uint8_t   obLuser;
    uint32_t  obSize;
    uint32_t  obCount;
    uint8_t   obData[MAX_FRAME];
    uint32_t  obValid;

    uint8_t   ibFuser;
    uint8_t   ibLuser;
    uint32_t  ibSize;
    uint8_t   ibData[MAX_FRAME];

    uint16_t  port;
    uint8_t   ssi;

    unsigned int inSnap[PORT_COUNT];
    unsigned int outState[PORT_COUNT];

    void *    zmqCtx;
    void *    zmqPush;
    void *    zmqPull;
} RogueTcpStreamData;

// Vivado xsim DPI-C instance lifecycle and per-edge update
void *rogueTcpStreamCreate(void);
void rogueTcpStreamDestroy(void *context);
int rogueTcpStreamUpdate(void *context, svBit reset, const svBitVecVal *portNum, svBit ssi,
                         svBit obReady, svBit *obValid,
                         svBitVecVal *obDataLow, svBitVecVal *obDataHigh,
                         svBitVecVal *obUserLow, svBitVecVal *obUserHigh,
                         svBitVecVal *obKeep, svBit *obLast,
                         svBit ibValid, svBit *ibReady,
                         const svBitVecVal *ibDataLow, const svBitVecVal *ibDataHigh,
                         const svBitVecVal *ibUserLow, const svBitVecVal *ibUserHigh,
                         const svBitVecVal *ibKeep, svBit ibLast);

// Start/restart zeromq server
void RogueTcpStreamRestart(RogueTcpStreamData *data);

// Send a message
void RogueTcpStreamSend(RogueTcpStreamData *data);

// Receive data if it is available
int RogueTcpStreamRecv(RogueTcpStreamData *data);

#endif
