//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef ROGUE_SIM_LINK_TRANSPORT_H
#define ROGUE_SIM_LINK_TRANSPORT_H

#include <stddef.h>
#include <stdint.h>

#define ROGUE_SIM_LINK_MAX_PARTS          6
#define ROGUE_SIM_LINK_DEFAULT_TIMEOUT_MS 30000
#define ROGUE_SIM_LINK_TIMEOUT_ENV        "SURF_SIMLINK_TRANSPORT_TIMEOUT_MS"

/** Selects which member of the adjacent port pair hosts each socket. */
typedef enum {
    ROGUE_SIM_LINK_PULL_BASE, /**< PULL on N and PUSH on N+1. */
    ROGUE_SIM_LINK_PUSH_BASE, /**< PUSH on N and PULL on N+1. */
} RogueSimLinkSocketOrder;

/**
 * One complete ZeroMQ multipart message crossing the worker boundary.
 *
 * A bit in owned marks a part allocated by rogueSimLinkMessageAdd(). Referenced
 * parts are not freed by rogueSimLinkMessageRelease(). Always initialize a
 * message before building it and release it after its final use.
 */
typedef struct {
    size_t size[ROGUE_SIM_LINK_MAX_PARTS]; /**< Byte count for each part. */
    void* data[ROGUE_SIM_LINK_MAX_PARTS];  /**< Part payload pointers. */
    uint32_t count;                        /**< Number of populated parts. */
    uint32_t owned;                        /**< Ownership bitmap by part index. */
} RogueSimLinkMessage;

/** Opaque worker, socket, queue, and synchronization state. */
typedef struct RogueSimLinkTransport RogueSimLinkTransport;

/** Initializes an empty message. */
void rogueSimLinkMessageInit(RogueSimLinkMessage* message);

/**
 * Appends an owned copy of one message part.
 *
 * @return 1 on success, or 0 for invalid input, a full message, or allocation
 * failure. The caller retains ownership of data.
 */
int rogueSimLinkMessageAdd(RogueSimLinkMessage* message, const void* data, size_t size);

/**
 * Appends a non-owning reference to one message part.
 *
 * The referenced storage must remain valid until the synchronous
 * rogueSimLinkTransportSend() call returns.
 *
 * @return 1 on success, otherwise 0.
 */
int rogueSimLinkMessageAddReference(RogueSimLinkMessage* message, const void* data, size_t size);

/** Frees owned parts and resets the message to its empty state. */
void rogueSimLinkMessageRelease(RogueSimLinkMessage* message);

/**
 * Resolves the transport deadline from an instance value or the environment.
 *
 * A nonzero instance value takes precedence. Otherwise the function parses
 * ROGUE_SIM_LINK_TIMEOUT_ENV, falling back to the default when it is unset.
 *
 * @return 1 with timeoutMs populated, or 0 with a diagnostic in error.
 */
int rogueSimLinkTransportResolveTimeout(uint32_t instanceTimeoutMs, uint32_t* timeoutMs, char* error, size_t errorSize);

/**
 * Allocates transport state without creating a worker or binding sockets.
 *
 * @param[in] basePort First port in the adjacent pair.
 * @param[in] order Mapping of PUSH/PULL sockets onto the pair.
 * @param[in] modelName Name used in diagnostics.
 * @param[in] maxInboundBytes Maximum cumulative bytes in one inbound message.
 * @return Unstarted transport, or NULL for invalid input/allocation failure.
 */
RogueSimLinkTransport* rogueSimLinkTransportCreate(uint16_t basePort,
                                                   RogueSimLinkSocketOrder order,
                                                   const char* modelName,
                                                   size_t maxInboundBytes);

/** Starts the worker and waits until both sockets are bound or startup fails. */
int rogueSimLinkTransportStart(RogueSimLinkTransport* transport, uint32_t timeoutMs);

/**
 * Copies and synchronously hands one complete outbound message to the worker.
 *
 * At most one outbound message may be pending. The call returns only after the
 * worker sends the message or the deadline/failure path completes.
 *
 * @return 1 when sent, otherwise 0.
 */
int rogueSimLinkTransportSend(RogueSimLinkTransport* transport, const RogueSimLinkMessage* message, uint32_t timeoutMs);

/**
 * Removes one complete inbound message from the bounded worker FIFO.
 *
 * Ownership transfers to message when a message is returned; the caller must
 * eventually call rogueSimLinkMessageRelease().
 *
 * @return 1 when a message is returned, 0 when no message is ready, or -1 when
 * the worker has failed.
 */
int rogueSimLinkTransportReceive(RogueSimLinkTransport* transport, RogueSimLinkMessage* message);

/** Copies the sticky first worker error into buffer and returns its fail flag. */
int rogueSimLinkTransportCopyError(RogueSimLinkTransport* transport, char* buffer, size_t size);

/** Stops and joins the worker, closes its sockets, and frees queued messages. */
void rogueSimLinkTransportDestroy(RogueSimLinkTransport* transport);

#endif
