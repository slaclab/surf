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
// Simulator-neutral Rogue TCP Memory signal indices, protocol/FSM constants,
// and instance state. Simulator adapters must keep callback/handle state
// separately.
//////////////////////////////////////////////////////////////////////////////

#ifndef SURF_SIMLINK_SHARED_ROGUE_TCP_MEMORY_MODEL_H
#define SURF_SIMLINK_SHARED_ROGUE_TCP_MEMORY_MODEL_H

#include <stdint.h>

#include "RogueSimLinkTransport.h"

/**
 * Flattened leaf-port indices shared by all simulator adapters. AXI-Lite
 * outputs driven by the model and response inputs sampled from the DUT occupy
 * the same indexed snapshot/state arrays.
 */
#define s_clock 0
#define s_reset 1
#define s_port  2

#define s_araddr  3
#define s_arprot  4
#define s_arvalid 5
#define s_rready  6

#define s_arready 7
#define s_rdata   8
#define s_rresp   9
#define s_rvalid  10

#define s_awaddr  11
#define s_awprot  12
#define s_awvalid 13
#define s_wdata   14
#define s_wstrb   15
#define s_wvalid  16
#define s_bready  17

#define s_awready 18
#define s_wready  19
#define s_bresp   20
#define s_bvalid  21

#define ROGUE_TCP_MEMORY_PORT_COUNT 22

#define ROGUE_TCP_MEMORY_TRANSACTION_READ   0x1
#define ROGUE_TCP_MEMORY_TRANSACTION_WRITE  0x2
#define ROGUE_TCP_MEMORY_TRANSACTION_POST   0x3
#define ROGUE_TCP_MEMORY_TRANSACTION_VERIFY 0x4
#define ROGUE_TCP_MEMORY_TRANSACTION_PROBE  0xFFFFFFFE

#define ROGUE_TCP_MEMORY_STATE_IDLE  0x0
#define ROGUE_TCP_MEMORY_STATE_START 0x1
#define ROGUE_TCP_MEMORY_STATE_WRESP 0x4
#define ROGUE_TCP_MEMORY_STATE_RADDR 0x5
#define ROGUE_TCP_MEMORY_STATE_RDATA 0x6
#define ROGUE_TCP_MEMORY_STATE_PAUSE 0x7

#define ROGUE_TCP_MEMORY_MAX_DATA 2000000

/** Simulator-neutral state for one Rogue Memory transaction endpoint. */
typedef struct {
    /** Endpoint identity and the active wire transaction. */
    uint16_t port;
    uint8_t state;
    uint32_t id;
    uint64_t addr;
    uint8_t data[ROGUE_TCP_MEMORY_MAX_DATA];
    uint32_t size;
    uint32_t curr;
    uint32_t type;
    uint32_t result;

    /** Scalar simulator input snapshot and output publication slots. */
    unsigned int inSnap[ROGUE_TCP_MEMORY_PORT_COUNT];
    unsigned int outState[ROGUE_TCP_MEMORY_PORT_COUNT];

    /** Worker-owned host transport and its resolved wall-clock deadline. */
    RogueSimLinkTransport* transport;
    uint32_t transportTimeoutMs;
} RogueTcpMemoryData;

#endif
