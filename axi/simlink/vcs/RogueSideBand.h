//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef __ROGUE_SIDE_BAND_H__
#define __ROGUE_SIDE_BAND_H__

#include <vhpi_user.h>
#include <stdint.h>
#include <time.h>

// Signals
#define s_clock        0
#define s_reset        1
#define s_port         2

#define s_txOpCode       3
#define s_txOpCodeEn     4
#define s_txRemData      5

#define s_rxOpCode       6
#define s_rxOpCodeEn     7
#define s_rxRemData      8

#define PORT_COUNT     9

// Structure to track state
typedef struct {
    uint32_t  currClk;
    uint16_t  port;

    uint8_t   rxRemData;
    uint8_t   rxOpCode;
    uint8_t   rxOpCodeEn;

    uint8_t   txRemData;
    uint8_t   txRemDataChanged;
    uint8_t   txOpCode;
    uint8_t   txOpCodeEn;

    // Input snapshot / output state driven by the shared FSM core through the
    // getInt/setInt seam below; RogueSideBandUpdate bridges these to/from
    // portData->intValue around each step.
    unsigned int inSnap[PORT_COUNT];
    unsigned int outState[PORT_COUNT];

    void *    zmqCtx;
    void *    zmqPull;
    void *    zmqPush;
} RogueSideBandData;

// The shared FSM core (RogueSideBandCore.h) drives the state machine through
// getInt/setInt. Override VhpiGeneric.h's portData-based definitions so the
// shared body compiles against RogueSideBandData's local snapshot arrays.
#undef getInt
#undef setInt
#define getInt(idx)      (data->inSnap[idx])
#define setInt(idx, val) (data->outState[idx] = (val))

// Init function
void RogueSideBandInit(vhpiHandleT compInst);

// Callback function for updating
void RogueSideBandUpdate(void *userPtr);

// Start/restart zeromq server
void RogueSideBandRestart(RogueSideBandData *data);

// Send a message
void RogueSideBandSend(RogueSideBandData *data);

// Receive data if it is available
int RogueSideBandRecv(RogueSideBandData *data);

#endif
