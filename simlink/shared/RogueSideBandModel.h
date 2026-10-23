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
// Simulator-neutral Rogue SideBand signal indices and instance state.
// Simulator adapters must keep callback/handle state separately.
//////////////////////////////////////////////////////////////////////////////

#ifndef SURF_SIMLINK_SHARED_ROGUE_SIDE_BAND_MODEL_H
#define SURF_SIMLINK_SHARED_ROGUE_SIDE_BAND_MODEL_H

#include <stdint.h>

#include "RogueSimLinkTransport.h"

/** Flattened leaf-port indices shared by all simulator adapters. */
#define s_clock 0
#define s_reset 1
#define s_port  2

#define s_txOpCode   3
#define s_txOpCodeEn 4
#define s_txRemData  5

#define s_rxOpCode   6
#define s_rxOpCodeEn 7
#define s_rxRemData  8

#define ROGUE_SIDE_BAND_PORT_COUNT 9

/** Simulator-neutral state for one SideBand endpoint. */
typedef struct {
    /** Immutable base port captured on the first post-reset step. */
    uint16_t port;

    /** Software-to-HDL state: opcode is a pulse; remote data is retained. */
    uint8_t rxRemData;
    uint8_t rxOpCode;
    uint8_t rxOpCodeEn;

    /** HDL-to-software state plus the qualifiers for the next wire message. */
    uint8_t txRemData;
    uint8_t txRemDataChanged;
    uint8_t txOpCode;
    uint8_t txOpCodeEn;

    /** Scalar simulator input snapshot and output publication slots. */
    unsigned int inSnap[ROGUE_SIDE_BAND_PORT_COUNT];
    unsigned int outState[ROGUE_SIDE_BAND_PORT_COUNT];

    /** Worker-owned host transport and its resolved wall-clock deadline. */
    RogueSimLinkTransport* transport;
    uint32_t transportTimeoutMs;
} RogueSideBandData;

#endif
