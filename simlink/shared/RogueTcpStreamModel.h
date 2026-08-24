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
// Simulator-neutral Rogue TCP Stream signal indices, constants, and instance
// state. Simulator adapters must keep callback/handle state separately.
//////////////////////////////////////////////////////////////////////////////

#ifndef SURF_SIMLINK_SHARED_ROGUE_TCP_STREAM_MODEL_H
#define SURF_SIMLINK_SHARED_ROGUE_TCP_STREAM_MODEL_H

#include <stdint.h>

#include "RogueSimLinkTransport.h"

/**
 * Indices shared by the adapter's flattened port table and the model's scalar
 * snapshots. "ib" is input to SimLink (HDL-to-software); "ob" is output from
 * SimLink (software-to-HDL). Wide data/user/keep values use the word arrays in
 * RogueTcpStreamData rather than these scalar slots.
 */
#define s_clock 0
#define s_reset 1
#define s_port  2
#define s_ssi   3

#define s_obValid 4
#define s_obReady 5
#define s_obData  6
#define s_obUser  7
#define s_obKeep  8
#define s_obLast  9

#define s_ibValid 10
#define s_ibReady 11
#define s_ibData  12
#define s_ibUser  13
#define s_ibKeep  14
#define s_ibLast  15

#define ROGUE_TCP_STREAM_PORT_COUNT 16

#define ROGUE_TCP_STREAM_MAX_FRAME          20000000
#define ROGUE_TCP_STREAM_DEFAULT_DATA_BYTES 8U
#define ROGUE_TCP_STREAM_MAX_DATA_BYTES     128U
#define ROGUE_TCP_STREAM_MAX_DATA_WORDS     32U
#define ROGUE_TCP_STREAM_MAX_KEEP_WORDS     4U

/** Simulator-neutral state for one Stream endpoint. */
typedef struct {
    /** Software-to-HDL frame currently being emitted on the ob interface. */
    uint8_t obFuser;
    uint8_t obLuser;
    uint32_t obSize;
    uint32_t obCount;
    uint8_t obData[ROGUE_TCP_STREAM_MAX_FRAME];
    uint32_t obValid;

    /** HDL-to-software frame accumulated from accepted ib beats. */
    uint8_t ibFuser;
    uint8_t ibLuser;
    uint32_t ibSize;
    uint8_t ibData[ROGUE_TCP_STREAM_MAX_FRAME];

    /**
     * One simulator-facing AXI Stream beat. Words are little-endian by lane:
     * word 0 contains byte lanes 0 through 3. The active prefix is selected by
     * dataBytes; fixed arrays keep the shared core ABI independent of the
     * simulator-specific foreign-function representation.
     */
    uint32_t obDataWords[ROGUE_TCP_STREAM_MAX_DATA_WORDS];
    uint32_t obUserWords[ROGUE_TCP_STREAM_MAX_DATA_WORDS];
    uint32_t obKeepWords[ROGUE_TCP_STREAM_MAX_KEEP_WORDS];
    uint32_t ibDataWords[ROGUE_TCP_STREAM_MAX_DATA_WORDS];
    uint32_t ibUserWords[ROGUE_TCP_STREAM_MAX_DATA_WORDS];
    uint32_t ibKeepWords[ROGUE_TCP_STREAM_MAX_KEEP_WORDS];
    uint32_t dataBytes;

    /** Immutable endpoint configuration captured on the first post-reset step. */
    uint16_t port;
    uint8_t ssi;

    /** Scalar simulator input snapshot and output publication slots. */
    unsigned int inSnap[ROGUE_TCP_STREAM_PORT_COUNT];
    unsigned int outState[ROGUE_TCP_STREAM_PORT_COUNT];

    /** Worker-owned host transport and its resolved wall-clock deadline. */
    RogueSimLinkTransport* transport;
    uint32_t transportTimeoutMs;
} RogueTcpStreamData;

#endif
