//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef __ROGUE_TCP_MEMORY_H__
#define __ROGUE_TCP_MEMORY_H__

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

// Signals
#define s_clock        0
#define s_reset        1
#define s_port         2

#define s_araddr       3
#define s_arprot       4
#define s_arvalid      5
#define s_rready       6

#define s_arready      7
#define s_rdata        8
#define s_rresp        9
#define s_rvalid       10

#define s_awaddr       11
#define s_awprot       12
#define s_awvalid      13
#define s_wdata        14
#define s_wstrb        15
#define s_wvalid       16
#define s_bready       17

#define s_awready      18
#define s_wready       19
#define s_bresp        20
#define s_bvalid       21

#define PORT_COUNT     22

#define T_READ   0x1
#define T_WRITE  0x2
#define T_POST   0x3
#define T_VERIFY 0x4

#define ST_IDLE  0x0
#define ST_START 0x1
#define ST_WRESP 0x4
#define ST_RADDR 0x5
#define ST_RDATA 0x6
#define ST_PAUSE 0x7

#define MAX_DATA 2000000

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
    uint16_t   port;
    uint8_t    state;
    uint32_t   id;
    uint64_t   addr;
    uint8_t    data[MAX_DATA];
    uint32_t   size;
    uint32_t   curr;
    uint32_t   type;
    uint32_t   result;

    unsigned int inSnap[PORT_COUNT];
    unsigned int outState[PORT_COUNT];

    void *     zmqCtx;
    void *     zmqPull;
    void *     zmqPush;
} RogueTcpMemoryData;

// Start/restart zeromq server
void RogueTcpMemoryRestart(RogueTcpMemoryData *data);

// Send a message
void RogueTcpMemorySend(RogueTcpMemoryData *data);

// Receive data if it is available
int RogueTcpMemoryRecv(RogueTcpMemoryData *data);

#endif
