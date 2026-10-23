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
// Shared Rogue-TCP AXI-Lite memory codec and transaction state machine.
// Simulator adapters provide only logging/fatal hooks and call the exported
// functions declared in RogueTcpMemoryCore.h.
//////////////////////////////////////////////////////////////////////////////

#include "RogueTcpMemoryCore.h"

#include <inttypes.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

const RogueSimLinkModelDescriptor ROGUE_TCP_MEMORY_MODEL = {"RogueTcpMemory"};

enum {
    // Rogue memory requests are multipart messages in this fixed order. A
    // write/post adds MEM_DATA_FRAME; a read/verify/probe stops after type.
    MEM_ID_FRAME         = 0,
    MEM_ADDR_FRAME       = 1,
    MEM_SIZE_FRAME       = 2,
    MEM_TYPE_FRAME       = 3,
    MEM_DATA_FRAME       = 4,
    MEM_READ_REQ_FRAMES  = 4,
    MEM_WRITE_REQ_FRAMES = 5,
    MEM_U32_BYTES        = 4,
    MEM_ADDR_BYTES       = 8,
};

static void RogueTcpMemoryPrintf(const char* format, ...) {
    char message[512];
    va_list args;

    va_start(args, format);
    vsnprintf(message, sizeof(message), format, args);
    va_end(args);
    // The simulator adapter owns the actual logging API (stdio, VHPI, etc.).
    RogueTcpMemoryLog(message);
}

// Preserve the first AXI-Lite error observed during a multiword transaction.
// A later OKAY response must not hide an earlier failed word.
static void RogueTcpMemoryAccumulateResult(RogueTcpMemoryData* data, uint32_t result) {
    if (data->result == 0) data->result = result;
}

void RogueTcpMemoryCleanup(void* opaque) {
    RogueTcpMemoryData* data = opaque;

    // Instance cleanup is also used by the process-exit fallback, so NULL is a
    // normal value when reset never advanced far enough to open the transport.
    rogueSimLinkTransportDestroy(data->transport);
    data->transport = NULL;
}

static void RogueTcpMemoryTransportFatal(RogueTcpMemoryData* data, const char* fallback) {
    char error[512];

    // Prefer the worker's latched operation/port/errno detail. The fallback
    // covers errors reported by the simulator-side rendezvous itself.
    error[0] = '\0';
    if (data->transport != NULL) rogueSimLinkTransportCopyError(data->transport, error, sizeof(error));
    RogueTcpMemoryFatal(error[0] == '\0' ? fallback : error);
}

// Start the worker-owned ZeroMQ transport. This is called lazily after reset,
// when the VHDL port generic has been sampled and reserved.
int RogueTcpMemoryStartTransport(RogueTcpMemoryData* data) {
    char error[512];

    if (!rogueSimLinkTransportResolveTimeout(data->transportTimeoutMs,
                                             &(data->transportTimeoutMs),
                                             error,
                                             sizeof(error))) {
        RogueTcpMemoryFatal(error);
        return 0;
    }
    RogueTcpMemoryPrintf("RogueTcpMemory: Listening on ports %i & %i\n", data->port, data->port + 1);
    data->transport =
        rogueSimLinkTransportCreate(data->port,
                                    ROGUE_SIM_LINK_PULL_BASE,
                                    "RogueTcpMemory",
                                    (size_t)ROGUE_TCP_MEMORY_MAX_DATA + (3U * MEM_U32_BYTES) + MEM_ADDR_BYTES);
    if (data->transport == NULL) {
        RogueTcpMemoryFatal("RogueTcpMemory: Transport allocation failed");
        return 0;
    }
    if (!rogueSimLinkTransportStart(data->transport, data->transportTimeoutMs)) {
        RogueTcpMemoryTransportFatal(data, "RogueTcpMemory: Transport startup failed");
        return 0;
    }
    return 1;
}

// Hand one complete response to the transport worker.
int RogueTcpMemorySend(RogueTcpMemoryData* data) {
    RogueSimLinkMessage message;
    const void* resultData;
    size_t resultSize;

    // Preserve the original SURF/Rogue uint32 result contract for ordinary
    // transactions. The newer readiness probe is an internal Rogue control
    // operation whose waitReady() implementation explicitly requires "OK".
    if (data->type == ROGUE_TCP_MEMORY_TRANSACTION_PROBE) {
        resultData = "OK";
        resultSize = strlen("OK");
    } else {
        resultData = &(data->result);
        resultSize = MEM_U32_BYTES;
    }

    // Echo the request fields in the response. Read/verify transactions also
    // return the populated data buffer; writes echo their original payload.
    rogueSimLinkMessageInit(&message);
    if (!rogueSimLinkMessageAddReference(&message, &(data->id), MEM_U32_BYTES) ||
        !rogueSimLinkMessageAddReference(&message, &(data->addr), MEM_ADDR_BYTES) ||
        !rogueSimLinkMessageAddReference(&message, &(data->size), MEM_U32_BYTES) ||
        !rogueSimLinkMessageAddReference(&message, &(data->type), MEM_U32_BYTES) ||
        !rogueSimLinkMessageAddReference(&message, data->data, data->size) ||
        !rogueSimLinkMessageAddReference(&message, resultData, resultSize)) {
        RogueTcpMemoryFatal("RogueTcpMemory: Message assembly failed");
        return 0;
    }
    if (!rogueSimLinkTransportSend(data->transport, &message, data->transportTimeoutMs)) {
        rogueSimLinkMessageRelease(&message);
        RogueTcpMemoryTransportFatal(data, "RogueTcpMemory: Transport send failed");
        return 0;
    }
    rogueSimLinkMessageRelease(&message);

    // A completed response releases the FSM to accept the next Rogue request.
    data->state = 0;
    data->curr  = 0;

    RogueTcpMemoryPrintf("RogueTcpMemory: Send Tran: Id %i, Addr 0x%" PRIx64 ", Size %i, Type %i, Resp 0x%x\n",
                         data->id,
                         data->addr,
                         data->size,
                         data->type,
                         data->result);
    return 1;
}

// Receive and validate one complete Rogue memory request, if available.
int RogueTcpMemoryRecv(RogueTcpMemoryData* data) {
    RogueSimLinkMessage message;
    int received;
    uint32_t size;

    received = rogueSimLinkTransportReceive(data->transport, &message);
    if (received < 0) {
        RogueTcpMemoryTransportFatal(data, "RogueTcpMemory: Transport receive failed");
        return -1;
    }
    if (received == 0) return 0;

    if (message.count != MEM_READ_REQ_FRAMES && message.count != MEM_WRITE_REQ_FRAMES) {
        rogueSimLinkMessageRelease(&message);
        RogueTcpMemoryFatal("RogueTcpMemory: Bad message frame count");
        return -1;
    }

    if ((message.size[MEM_ID_FRAME] != MEM_U32_BYTES) || (message.size[MEM_ADDR_FRAME] != MEM_ADDR_BYTES) ||
        (message.size[MEM_SIZE_FRAME] != MEM_U32_BYTES) || (message.size[MEM_TYPE_FRAME] != MEM_U32_BYTES)) {
        rogueSimLinkMessageRelease(&message);
        RogueTcpMemoryFatal("RogueTcpMemory: Bad message size");
        return -1;
    }

    // Use memcpy rather than pointer casts: ZeroMQ parts carry byte-aligned
    // wire data and need not meet the host alignment of uint32_t/uint64_t.
    memcpy(&(data->id), message.data[MEM_ID_FRAME], MEM_U32_BYTES);
    memcpy(&(data->addr), message.data[MEM_ADDR_FRAME], MEM_ADDR_BYTES);
    memcpy(&(data->size), message.data[MEM_SIZE_FRAME], MEM_U32_BYTES);
    memcpy(&(data->type), message.data[MEM_TYPE_FRAME], MEM_U32_BYTES);

    // Validate the complete transaction shape before accepting any optional
    // data frame. In particular, a fifth frame on a read must not be silently
    // ignored, and an unknown type must not fall through to the read FSM.
    switch (data->type) {
        case ROGUE_TCP_MEMORY_TRANSACTION_READ:
        case ROGUE_TCP_MEMORY_TRANSACTION_VERIFY:
            if (message.count != MEM_READ_REQ_FRAMES) {
                rogueSimLinkMessageRelease(&message);
                RogueTcpMemoryFatal(
                    "RogueTcpMemory: Read/verify transaction has unexpected "
                    "data");
                return -1;
            }
            break;
        case ROGUE_TCP_MEMORY_TRANSACTION_WRITE:
        case ROGUE_TCP_MEMORY_TRANSACTION_POST:
            if (message.count != MEM_WRITE_REQ_FRAMES) {
                rogueSimLinkMessageRelease(&message);
                RogueTcpMemoryFatal("RogueTcpMemory: Write/post transaction data is missing");
                return -1;
            }
            break;
        case ROGUE_TCP_MEMORY_TRANSACTION_PROBE:
            // Rogue's TcpClient::waitReady() sends this internal control
            // request to verify the complete request/response path. Handle it
            // locally; it must never reach the AXI-Lite transaction FSM.
            if ((message.count != MEM_READ_REQ_FRAMES) || (data->size != 0)) {
                rogueSimLinkMessageRelease(&message);
                RogueTcpMemoryFatal("RogueTcpMemory: Malformed readiness probe");
                return -1;
            }

            data->state  = ROGUE_TCP_MEMORY_STATE_IDLE;
            data->curr   = 0;
            data->result = 0;
            rogueSimLinkMessageRelease(&message);
            return RogueTcpMemorySend(data) ? 0 : -1;
        default:
            rogueSimLinkMessageRelease(&message);
            RogueTcpMemoryFatal("RogueTcpMemory: Unsupported transaction type");
            return -1;
    }

    // The AXI-Lite FSM advances curr four bytes per beat and finishes only
    // when curr == size. Reject any size that would overrun data[] or prevent
    // the state machine from terminating.
    if ((data->size == 0) || (data->size > ROGUE_TCP_MEMORY_MAX_DATA) || ((data->size % MEM_U32_BYTES) != 0)) {
        rogueSimLinkMessageRelease(&message);
        RogueTcpMemoryFatal(
            "RogueTcpMemory: Transaction size invalid (zero, exceeds "
            "ROGUE_TCP_MEMORY_MAX_DATA, or not 32-bit word aligned)");
        return -1;
    }

    if ((data->type == ROGUE_TCP_MEMORY_TRANSACTION_WRITE) || (data->type == ROGUE_TCP_MEMORY_TRANSACTION_POST)) {
        if (message.size[MEM_DATA_FRAME] != data->size) {
            rogueSimLinkMessageRelease(&message);
            RogueTcpMemoryFatal("RogueTcpMemory: Write/post transaction data size mismatch");
            return -1;
        }
        memcpy(data->data, message.data[MEM_DATA_FRAME], data->size);
    }

    // Commit the decoded request only after all framing and bounds checks pass.
    data->state  = ROGUE_TCP_MEMORY_STATE_START;
    data->curr   = 0;
    data->result = 0;

    RogueTcpMemoryPrintf("RogueTcpMemory: Got Tran: Id %i, Addr 0x%" PRIx64 ", Size %i, Type %i\n",
                         data->id,
                         data->addr,
                         data->size,
                         data->type);

    size = data->size;
    rogueSimLinkMessageRelease(&message);
    return size;
}

// AXI-Lite master transaction FSM, run once per rising clock edge. Reads the
// input snapshot and drives the output state directly on the shared model.
void RogueTcpMemoryStep(RogueTcpMemoryData* data) {
    uint32_t data32;
    const uint8_t* wbytes;

    // Reset is asserted
    if (data->inSnap[s_reset] == 1) {
        data->state               = ROGUE_TCP_MEMORY_STATE_IDLE;
        data->outState[s_arvalid] = 0;
        data->outState[s_rready]  = 1;
        data->outState[s_awvalid] = 0;
        data->outState[s_bready]  = 1;

    } else {
        // The port generic is stable after elaboration but is sampled here so
        // reset-only simulations do not bind sockets unnecessarily.
        if (data->port == 0) {
            data->port = data->inSnap[s_port];
            if (!RogueTcpMemoryStartTransport(data)) return;
        }

        switch (data->state) {
            // IDLE polls the worker-owned inbound queue without blocking the
            // simulator thread.
            case ROGUE_TCP_MEMORY_STATE_IDLE:
                if (RogueTcpMemoryRecv(data) < 0) return;
                break;

            // Present one 32-bit word. Multiword requests revisit START after
            // the response signals have returned low.
            case ROGUE_TCP_MEMORY_STATE_START:

                // Write
                if (data->type == ROGUE_TCP_MEMORY_TRANSACTION_WRITE ||
                    data->type == ROGUE_TCP_MEMORY_TRANSACTION_POST) {
                    data->outState[s_awaddr]  = data->addr + data->curr;
                    data->outState[s_awprot]  = 0;
                    data->outState[s_awvalid] = 1;
                    data->outState[s_bready]  = 1;

                    // The Rogue payload is little-endian bytes; assemble an
                    // aligned AXI-Lite WDATA word explicitly.
                    wbytes = &data->data[data->curr];
                    data32 = (uint32_t)wbytes[0] | ((uint32_t)wbytes[1] << 8) | ((uint32_t)wbytes[2] << 16) |
                             ((uint32_t)wbytes[3] << 24);
                    data->curr += 4;

                    data->outState[s_wdata]  = data32;
                    data->outState[s_wstrb]  = 0xF;
                    data->outState[s_wvalid] = 1;
                    data->state              = ROGUE_TCP_MEMORY_STATE_WRESP;

                } else {
                    // Read
                    data->outState[s_araddr]  = data->addr + data->curr;
                    data->outState[s_arprot]  = 0;
                    data->outState[s_arvalid] = 1;
                    data->outState[s_rready]  = 1;
                    data->state               = ROGUE_TCP_MEMORY_STATE_RADDR;
                }
                break;

            // AXI-Lite address and data channels handshake independently. Keep
            // each VALID asserted until its matching READY is observed.
            case ROGUE_TCP_MEMORY_STATE_WRESP:

                if (data->inSnap[s_awready]) data->outState[s_awvalid] = 0;
                if (data->inSnap[s_wready]) data->outState[s_wvalid] = 0;

                if (data->inSnap[s_bvalid]) {
                    RogueTcpMemoryAccumulateResult(data, data->inSnap[s_bresp]);

                    if (data->curr == data->size) {
                        if (!RogueTcpMemorySend(data)) return;
                    } else {
                        data->state = ROGUE_TCP_MEMORY_STATE_PAUSE;
                    }
                }
                break;

            // Read address
            case ROGUE_TCP_MEMORY_STATE_RADDR:
                if (data->inSnap[s_arready]) {
                    data->outState[s_arvalid] = 0;
                    data->outState[s_rready]  = 1;
                    data->state               = ROGUE_TCP_MEMORY_STATE_RDATA;
                }
                break;

            // Consume one RDATA beat and serialize it back into Rogue's
            // little-endian byte buffer.
            case ROGUE_TCP_MEMORY_STATE_RDATA:
                if (data->inSnap[s_rvalid]) {
                    data32 = data->inSnap[s_rdata];
                    RogueTcpMemoryAccumulateResult(data, data->inSnap[s_rresp]);

                    data->data[data->curr++] = data32 & 0xFF;
                    data->data[data->curr++] = (data32 >> 8) & 0xFF;
                    data->data[data->curr++] = (data32 >> 16) & 0xFF;
                    data->data[data->curr++] = (data32 >> 24) & 0xFF;

                    if (data->curr == data->size) {
                        if (!RogueTcpMemorySend(data)) return;
                    } else {
                        data->state = ROGUE_TCP_MEMORY_STATE_PAUSE;
                    }
                }
                break;

            // The model accepts one word per assertion. Waiting for both
            // response VALIDs to fall prevents a held response from being
            // mistaken for the next word's response.
            case ROGUE_TCP_MEMORY_STATE_PAUSE:
                if (data->inSnap[s_rvalid] == 0 && data->inSnap[s_bvalid] == 0) {
                    data->state = ROGUE_TCP_MEMORY_STATE_START;
                    break;
                }
        }
    }
}
