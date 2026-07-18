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

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

// Signals
#define s_clock        0
#define s_reset        1
#define s_port         2

#define s_txOpCode     3
#define s_txOpCodeEn   4
#define s_txRemData    5

#define s_rxOpCode     6
#define s_rxOpCodeEn   7
#define s_rxRemData    8

#define PORT_COUNT     9

// GHDL has no VHPI (no vhpi_register_cb / value-change callbacks), so the
// VHPI print/assert calls in the transplanted FSM body are shimmed straight
// to printf/abort. The severity argument is accepted but never referenced,
// so no VHPI severity token (e.g. vhpiFatal) needs defining.
#define vhpi_printf(...) printf(__VA_ARGS__)
#define vhpi_assert(msg, sev) \
    do { \
        fprintf(stderr, "%s\n", (msg)); \
        abort(); \
    } while (0)

// Macros for get/set ints, redefined for the per-edge update-procedure model:
// getInt reads the input snapshot populated at update-procedure entry;
// setInt writes the output state read back by the handle-based getters.
#define getInt(idx)      (data->inSnap[idx])
#define setInt(idx, val) (data->outState[idx] = (val))

// Structure to track state
typedef struct {
    uint16_t  port;

    uint8_t   rxRemData;
    uint8_t   rxOpCode;
    uint8_t   rxOpCodeEn;

    uint8_t   txRemData;
    uint8_t   txRemDataChanged;
    uint8_t   txOpCode;
    uint8_t   txOpCodeEn;

    unsigned int inSnap[PORT_COUNT];
    unsigned int outState[PORT_COUNT];

    void *    zmqCtx;
    void *    zmqPull;
    void *    zmqPush;
} RogueSideBandData;

// GHDL VHPIDIRECT instance lifecycle
int32_t rogueSideBandCreate(void);
void rogueSideBandDestroy(int32_t handle);

// Start/restart zeromq server
void RogueSideBandRestart(RogueSideBandData *data);

// Send a message
void RogueSideBandSend(RogueSideBandData *data);

// Receive data if it is available
int RogueSideBandRecv(RogueSideBandData *data);

#endif
