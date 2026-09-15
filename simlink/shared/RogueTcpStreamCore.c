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
// Shared Rogue-TCP AXI-Stream codec and data-movement state machine.
// Simulator adapters provide only logging/fatal hooks and call the exported
// functions declared in RogueTcpStreamCore.h.
//////////////////////////////////////////////////////////////////////////////

#include "RogueTcpStreamCore.h"

#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

const RogueSimLinkModelDescriptor ROGUE_TCP_STREAM_MODEL = {"RogueTcpStream"};

static void RogueTcpStreamPrintf(const char* format, ...) {
    char message[512];
    va_list args;

    va_start(args, format);
    vsnprintf(message, sizeof(message), format, args);
    va_end(args);
    // The simulator adapter owns the actual logging API (stdio, VHPI, etc.).
    RogueTcpStreamLog(message);
}

void RogueTcpStreamCleanup(void* opaque) {
    RogueTcpStreamData* data = opaque;

    // The transport is created lazily, so cleanup must also handle a model
    // that never left reset.
    rogueSimLinkTransportDestroy(data->transport);
    data->transport = NULL;
}

static void RogueTcpStreamTransportFatal(RogueTcpStreamData* data, const char* fallback) {
    char error[512];

    // Prefer the worker's latched operation/port/errno detail when available.
    error[0] = '\0';
    if (data->transport != NULL) rogueSimLinkTransportCopyError(data->transport, error, sizeof(error));
    RogueTcpStreamFatal(error[0] == '\0' ? fallback : error);
}

int RogueTcpStreamSetDataBytes(RogueTcpStreamData* data, uint32_t dataBytes) {
    // The beat width is established by an elaborated vector. Once stored it is
    // part of the instance ABI and must remain constant for every callback.
    if (dataBytes == 0 || dataBytes > ROGUE_TCP_STREAM_MAX_DATA_BYTES) {
        RogueTcpStreamFatal("RogueTcpStream: DATA_BYTES must be between 1 and 128");
        return 0;
    }
    if (data->dataBytes != 0 && data->dataBytes != dataBytes) {
        RogueTcpStreamFatal("RogueTcpStream: DATA_BYTES changed after initialization");
        return 0;
    }
    data->dataBytes = dataBytes;
    return 1;
}

static uint32_t RogueTcpStreamGetBit(const uint32_t* words, uint32_t bit) {
    // Simulator adapters normalize vectors into little-endian 32-bit words.
    return (words[bit / 32U] >> (bit % 32U)) & 0x1U;
}

static uint8_t RogueTcpStreamGetByte(const uint32_t* words, uint32_t byte) {
    return (uint8_t)((words[byte / 4U] >> ((byte % 4U) * 8U)) & 0xFFU);
}

static void RogueTcpStreamSetBit(uint32_t* words, uint32_t bit) {
    words[bit / 32U] |= 1U << (bit % 32U);
}

static void RogueTcpStreamSetByte(uint32_t* words, uint32_t byte, uint8_t value) {
    words[byte / 4U] |= ((uint32_t)value) << ((byte % 4U) * 8U);
}

// Start the worker-owned ZeroMQ transport. This is deferred until reset is
// released and the port/SSI generics have been sampled.
int RogueTcpStreamStartTransport(RogueTcpStreamData* data) {
    char error[512];

    if (!rogueSimLinkTransportResolveTimeout(data->transportTimeoutMs,
                                             &(data->transportTimeoutMs),
                                             error,
                                             sizeof(error))) {
        RogueTcpStreamFatal(error);
        return 0;
    }
    RogueTcpStreamPrintf("RogueTcpStream: Listening on ports %i & %i\n", data->port, data->port + 1);
    data->transport =
        rogueSimLinkTransportCreate(data->port,
                                    ROGUE_SIM_LINK_PULL_BASE,
                                    "RogueTcpStream",
                                    (size_t)ROGUE_TCP_STREAM_MAX_FRAME + sizeof(uint16_t) + (2U * sizeof(uint8_t)));
    if (data->transport == NULL) {
        RogueTcpStreamFatal("RogueTcpStream: Transport allocation failed");
        return 0;
    }
    if (!rogueSimLinkTransportStart(data->transport, data->transportTimeoutMs)) {
        RogueTcpStreamTransportFatal(data, "RogueTcpStream: Transport startup failed");
        return 0;
    }
    return 1;
}

// Hand one complete message to the transport worker.
int RogueTcpStreamSend(RogueTcpStreamData* data) {
    RogueSimLinkMessage message;
    uint16_t flags;
    uint8_t chan;
    uint8_t err;

    // Rogue's four-part stream wire format is flags, channel, error, payload.
    // SSI maps first/last TUSER bytes and EOFE into those metadata fields.
    if (data->ssi) {
        flags = (data->ibFuser & 0xFF);
        flags |= ((data->ibLuser << 8) & 0xFF00);
        err = data->ibLuser & 0x1;
    } else {
        flags = 0;
        err   = 0;
    }
    chan = 0;

    // References remain valid while the synchronous rendezvous makes its one
    // worker-owned copy, avoiding an extra ROGUE_TCP_STREAM_MAX_FRAME-sized temporary copy.
    rogueSimLinkMessageInit(&message);
    if (!rogueSimLinkMessageAddReference(&message, &flags, sizeof(flags)) ||
        !rogueSimLinkMessageAddReference(&message, &chan, sizeof(chan)) ||
        !rogueSimLinkMessageAddReference(&message, &err, sizeof(err)) ||
        !rogueSimLinkMessageAddReference(&message, data->ibData, data->ibSize)) {
        RogueTcpStreamFatal("RogueTcpStream: Message assembly failed");
        return 0;
    }
    if (!rogueSimLinkTransportSend(data->transport, &message, data->transportTimeoutMs)) {
        rogueSimLinkMessageRelease(&message);
        RogueTcpStreamTransportFatal(data, "RogueTcpStream: Transport send failed");
        return 0;
    }
    rogueSimLinkMessageRelease(&message);
    RogueTcpStreamPrintf(
        "RogueTcpStream: Send data: Size: %i, flags: %x, chan: %x, "
        "err: %x, port: %i\n",
        data->ibSize,
        flags,
        chan,
        err,
        data->port + 1);
    data->ibSize = 0;
    return 1;
}

// Receive and decode one complete Rogue stream frame, if available.
int RogueTcpStreamRecv(RogueTcpStreamData* data) {
    RogueSimLinkMessage message;
    int received;
    uint32_t size;
    uint16_t flags;
    uint8_t chan;
    uint8_t err;

    received = rogueSimLinkTransportReceive(data->transport, &message);
    if (received < 0) {
        RogueTcpStreamTransportFatal(data, "RogueTcpStream: Transport receive failed");
        return -1;
    }
    if (received == 0) return 0;
    if (message.count != 4 || message.size[0] != sizeof(flags) || message.size[1] != sizeof(chan) ||
        message.size[2] != sizeof(err)) {
        rogueSimLinkMessageRelease(&message);
        RogueTcpStreamFatal("RogueTcpStream: Bad message sizes");
        return -1;
    }

    if (message.size[3] > ROGUE_TCP_STREAM_MAX_FRAME) {
        rogueSimLinkMessageRelease(&message);
        RogueTcpStreamFatal("RogueTcpStream: Receive frame size exceeds ROGUE_TCP_STREAM_MAX_FRAME");
        return -1;
    }
    size = (uint32_t)message.size[3];
    memcpy(&flags, message.data[0], sizeof(flags));
    memcpy(&chan, message.data[1], sizeof(chan));
    memcpy(&err, message.data[2], sizeof(err));
    memcpy(data->obData, message.data[3], size);
    rogueSimLinkMessageRelease(&message);

    // Hold the complete frame in model storage; Step() slices it into AXI
    // beats according to the elaborated data width and downstream READY.
    data->obSize  = size;
    data->obFuser = flags & 0xFF;
    data->obLuser = (flags >> 8) & 0xFF;

    // SSI SOF is asserted on the first byte, while Rogue's separate error flag
    // is folded back into the last-byte EOFE bit.
    if (data->ssi) {
        data->obFuser |= 0x02;
        if (err) data->obLuser |= 0x01;
    }

    RogueTcpStreamPrintf(
        "RogueTcpStream: Recv data: Size: %i, flags: %x, chan: %i, "
        "err: %i, port: %i\n",
        data->obSize,
        flags,
        chan,
        err,
        data->port);
    return size;
}

// AXI-Stream data-movement FSM, run once per rising clock edge. Reads the
// input snapshot and drives the output state directly on the shared model.
void RogueTcpStreamStep(RogueTcpStreamData* data) {
    uint32_t x;

    if (data->dataBytes == 0 && !RogueTcpStreamSetDataBytes(data, ROGUE_TCP_STREAM_DEFAULT_DATA_BYTES)) return;

    // Reset is asserted
    if (data->inSnap[s_reset] == 1) {
        data->obCount             = 0;
        data->obSize              = 0;
        data->ibSize              = 0;
        data->obValid             = 0;
        data->outState[s_obValid] = 0;
        data->outState[s_ibReady] = 1;
        memset(data->obDataWords, 0, sizeof(data->obDataWords));
        memset(data->obUserWords, 0, sizeof(data->obUserWords));
        memset(data->obKeepWords, 0, sizeof(data->obKeepWords));
        data->outState[s_obLast] = 0;

    } else {
        // Bind lazily so a reset-only instance never occupies TCP ports.
        if (data->port == 0) {
            data->port = data->inSnap[s_port];
            data->ssi  = data->inSnap[s_ssi];
            if (!RogueTcpStreamStartTransport(data)) return;
        }

        // Accumulate one accepted inbound beat. ibReady is held high by this
        // model, so ibValid alone denotes the handshake at this clock edge.
        if (data->inSnap[s_ibValid]) {
            // TUSER byte lane zero on the first beat carries SSI first-user.
            if (data->ibSize == 0) data->ibFuser = RogueTcpStreamGetByte(data->ibUserWords, 0);

            // Compact kept lanes into the contiguous Rogue payload. The last
            // kept lane encountered supplies the eventual last-user byte.
            for (x = 0; x < data->dataBytes; x++) {
                if (RogueTcpStreamGetBit(data->ibKeepWords, x)) {
                    // Guard the fixed ibData[ROGUE_TCP_STREAM_MAX_FRAME] buffer against a frame
                    // that keeps streaming past capacity before asserting
                    // tLast. Unkept lanes neither consume nor touch storage.
                    if (data->ibSize >= ROGUE_TCP_STREAM_MAX_FRAME) {
                        RogueTcpStreamFatal(
                            "RogueTcpStream: Inbound frame size exceeds "
                            "ROGUE_TCP_STREAM_MAX_FRAME");
                        return;
                    }
                    data->ibData[data->ibSize] = RogueTcpStreamGetByte(data->ibDataWords, x);
                    data->ibLuser              = RogueTcpStreamGetByte(data->ibUserWords, x);
                    data->ibSize++;
                }
            }

            // TLAST closes the complete frame and performs the synchronous
            // handoff to the transport worker.
            if (data->inSnap[s_ibLast] && !RogueTcpStreamSend(data)) return;
        }

        // Once every byte of the current frame has been packed into beats, the
        // next complete frame may be prefetched; any held beat is independent
        // in obDataWords/obUserWords/obKeepWords.
        if (data->obSize == 0 && RogueTcpStreamRecv(data) < 0) return;

        // Once READY accepts the currently held beat, the next beat may be
        // assembled below in the same model step.
        if (data->inSnap[s_obReady]) {
            data->obValid            = 0;
            data->outState[s_obLast] = 0;
        }

        // Build the next outbound beat only when no unaccepted VALID is being
        // held. This preserves data, keep, user, and last under backpressure.
        if (data->obValid == 0 && data->obSize > 0) {
            memset(data->obDataWords, 0, sizeof(data->obDataWords));
            memset(data->obUserWords, 0, sizeof(data->obUserWords));
            memset(data->obKeepWords, 0, sizeof(data->obKeepWords));

            // SSI first-user is attached only to byte lane zero of beat zero.
            if (data->obCount == 0) RogueTcpStreamSetByte(data->obUserWords, 0, data->obFuser);

            // Fill lanes from low to high and mark every populated lane kept.
            for (x = 0; x < data->dataBytes && data->obCount < data->obSize; x++) {
                RogueTcpStreamSetByte(data->obDataWords, x, data->obData[data->obCount]);
                if ((data->obCount + 1) == data->obSize) RogueTcpStreamSetByte(data->obUserWords, x, data->obLuser);

                data->obCount++;
                RogueTcpStreamSetBit(data->obKeepWords, x);
            }
            data->obValid = 1;

            // obSize is cleared when the final beat is prepared, while
            // obValid keeps that beat resident until READY accepts it.
            if (data->obCount >= data->obSize) {
                data->outState[s_obLast] = 1;
                data->obSize             = 0;
                data->obCount            = 0;
            }
        }

        // Publish the registered-valid shadow after any READY/new-beat work.
        data->outState[s_obValid] = data->obValid;
    }
}
