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
// Shared Rogue side-band codec and opcode/remData state machine.
// Simulator adapters provide only logging/fatal hooks and call the exported
// functions declared in RogueSideBandCore.h.
//
// Note the ZMQ bind order is the mirror of the Rogue-TCP stream/memory cores:
// the side-band model binds PULL on port+1 and PUSH on port.
//////////////////////////////////////////////////////////////////////////////

#include "RogueSideBandCore.h"

#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>

const RogueSimLinkModelDescriptor ROGUE_SIDE_BAND_MODEL = {"RogueSideBand"};

enum {
    // enable/opcode/change/remData: the historical Rogue side-band wire record.
    SIDE_BAND_MESSAGE_BYTES = 4,
};

static void RogueSideBandPrintf(const char* format, ...) {
    char message[512];
    va_list args;

    va_start(args, format);
    vsnprintf(message, sizeof(message), format, args);
    va_end(args);
    // The simulator adapter owns the actual logging API (stdio, VHPI, etc.).
    RogueSideBandLog(message);
}

void RogueSideBandCleanup(void* opaque) {
    RogueSideBandData* data = opaque;

    // The transport is created lazily, so cleanup must also handle a model
    // that never left reset.
    rogueSimLinkTransportDestroy(data->transport);
    data->transport = NULL;
}

static void RogueSideBandTransportFatal(RogueSideBandData* data, const char* fallback) {
    char error[512];

    // Prefer the worker's latched operation/port/errno detail when available.
    error[0] = '\0';
    if (data->transport != NULL) rogueSimLinkTransportCopyError(data->transport, error, sizeof(error));
    RogueSideBandFatal(error[0] == '\0' ? fallback : error);
}

// Start the worker-owned ZeroMQ transport after the port generic is visible.
int RogueSideBandStartTransport(RogueSideBandData* data) {
    char error[512];

    if (!rogueSimLinkTransportResolveTimeout(data->transportTimeoutMs,
                                             &(data->transportTimeoutMs),
                                             error,
                                             sizeof(error))) {
        RogueSideBandFatal(error);
        return 0;
    }
    RogueSideBandPrintf("RogueSideBand: Listening on ports %i & %i\n", data->port, data->port + 1);
    data->transport =
        rogueSimLinkTransportCreate(data->port, ROGUE_SIM_LINK_PUSH_BASE, "RogueSideBand", SIDE_BAND_MESSAGE_BYTES);
    if (data->transport == NULL) {
        RogueSideBandFatal("RogueSideBand: Transport allocation failed");
        return 0;
    }
    if (!rogueSimLinkTransportStart(data->transport, data->transportTimeoutMs)) {
        RogueSideBandTransportFatal(data, "RogueSideBand: Transport startup failed");
        return 0;
    }
    return 1;
}

// Hand one complete message to the transport worker.
int RogueSideBandSend(RogueSideBandData* data) {
    RogueSimLinkMessage message;
    uint8_t ba[SIDE_BAND_MESSAGE_BYTES];

    // Keep the compact wire layout explicit: each value is preceded by a flag
    // that says whether the receiver should apply it.
    ba[0] = data->txOpCodeEn;
    ba[1] = data->txOpCode;
    ba[2] = data->txRemDataChanged;
    ba[3] = data->txRemData;

    rogueSimLinkMessageInit(&message);
    if (!rogueSimLinkMessageAddReference(&message, ba, sizeof(ba))) {
        RogueSideBandFatal("RogueSideBand: Message assembly failed");
        return 0;
    }
    if (!rogueSimLinkTransportSend(data->transport, &message, data->transportTimeoutMs)) {
        rogueSimLinkMessageRelease(&message);
        RogueSideBandTransportFatal(data, "RogueSideBand: Transport send failed");
        return 0;
    }
    rogueSimLinkMessageRelease(&message);
    if (data->txOpCodeEn) {
        RogueSideBandPrintf("RogueSideBand: Sent Opcode: %x on port %i\n", data->txOpCode, data->port);
    }
    if (data->txRemDataChanged) {
        RogueSideBandPrintf("RogueSideBand: Sent remData: %x on port %i\n", data->txRemData, data->port);
    }
    return 1;
}

// Receive and apply one complete side-band update, if available.
int RogueSideBandRecv(RogueSideBandData* data) {
    RogueSimLinkMessage message;
    uint8_t* rd;
    int received = rogueSimLinkTransportReceive(data->transport, &message);

    if (received < 0) {
        RogueSideBandTransportFatal(data, "RogueSideBand: Transport receive failed");
        return -1;
    }
    if (received == 0) return 0;
    if (message.count != 1 || message.size[0] != SIDE_BAND_MESSAGE_BYTES) {
        rogueSimLinkMessageRelease(&message);
        RogueSideBandFatal("RogueSideBand: Bad message size");
        return -1;
    }
    // Disabled fields retain their prior values. Opcode enable is later
    // converted into a one-clock pulse; remData is level state.
    rd = message.data[0];
    {
        if (rd[0] == 0x01) {
            data->rxOpCode   = rd[1];
            data->rxOpCodeEn = 1;
            RogueSideBandPrintf("RogueSideBand: Got opcode 0x%02x on port %i\n", data->rxOpCode, data->port + 1);
        }
        if (rd[2] == 0x01) {
            data->rxRemData = rd[3];
            RogueSideBandPrintf("RogueSideBand: Got data 0x%02x on port %i\n", data->rxRemData, data->port + 1);
        }
    }
    rogueSimLinkMessageRelease(&message);
    return SIDE_BAND_MESSAGE_BYTES;
}

// Side-band FSM, run once per rising clock edge. Reads the input snapshot and
// drives the output state directly on the shared model.
void RogueSideBandStep(RogueSideBandData* data) {
    uint8_t send = 0;

    // Reset is asserted
    if (data->inSnap[s_reset] == 1) {
        data->rxRemData              = 0x00;
        data->rxOpCode               = 0x00;
        data->rxOpCodeEn             = 0;
        data->txRemData              = 0x00;
        data->txRemDataChanged       = 0x00;
        data->txOpCode               = 0x00;
        data->txOpCodeEn             = 0;
        data->outState[s_rxOpCodeEn] = 0;
        data->outState[s_rxOpCode]   = 0;
        data->outState[s_rxRemData]  = 0;

    } else {
        // Bind lazily so a reset-only instance never occupies TCP ports.
        if (data->port == 0) {
            data->port = data->inSnap[s_port];
            if (!RogueSideBandStartTransport(data)) return;
        }

        // Opcode is event-like and is transmitted whenever its enable pulses.
        if (data->inSnap[s_txOpCodeEn]) {
            data->txOpCode   = data->inSnap[s_txOpCode];
            data->txOpCodeEn = data->inSnap[s_txOpCodeEn];
            send             = 1;
        }

        // remData is level-like, so transmit only changes.
        if (data->inSnap[s_txRemData] != data->txRemData) {
            data->txRemData        = data->inSnap[s_txRemData];
            data->txRemDataChanged = 1;
            send                   = 1;
        }

        // Coalesce an opcode and remData change from the same clock edge into
        // one four-byte transport message.
        if (send) {
            if (!RogueSideBandSend(data)) return;
            data->txOpCodeEn       = 0;
            data->txRemDataChanged = 0;
        }

        // Publish the most recent levels. rxOpCodeEn is deliberately cleared
        // after one model step so the HDL observes a single-cycle pulse.
        if (RogueSideBandRecv(data) < 0) return;
        data->outState[s_rxRemData]  = data->rxRemData;
        data->outState[s_rxOpCode]   = data->rxOpCode;
        data->outState[s_rxOpCodeEn] = data->rxOpCodeEn;
        data->rxOpCodeEn             = 0;  // Only for one clock
    }
}
