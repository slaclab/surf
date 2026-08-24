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
// Threaded ZeroMQ transport shared by all SimLink protocol models. Simulator
// callbacks never call ZeroMQ directly: they exchange owned multipart
// messages with one worker through a bounded inbound ring and a synchronous,
// single-message outbound rendezvous.
//////////////////////////////////////////////////////////////////////////////

#if !defined(__APPLE__) && !defined(_POSIX_C_SOURCE)
    #define _POSIX_C_SOURCE 200809L
#endif

#include "RogueSimLinkTransport.h"

#include <errno.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <zmq.h>

#define ROGUE_SIM_LINK_INBOUND_DEPTH     16
#define ROGUE_SIM_LINK_OUTBOUND_DEPTH    1
#define ROGUE_SIM_LINK_WORKER_POLL_MS    10
#define ROGUE_SIM_LINK_SOCKET_TIMEOUT_MS 100

struct RogueSimLinkTransport {
    // Cross-thread queue state and predicates are protected by the mutex.
    // Socket handles remain worker-only, and configuration is immutable after
    // the worker starts.
    pthread_t thread;
    pthread_mutex_t mutex;
    pthread_cond_t condition;

    // Only the worker touches the ZeroMQ sockets. Message ownership crosses
    // the mutex boundary through these queues.
    RogueSimLinkMessage outbound;
    RogueSimLinkMessage inbound[ROGUE_SIM_LINK_INBOUND_DEPTH];
    char modelName[64];
    char error[512];
    void* context;
    void* pull;
    void* push;

    // inboundHead/inboundCount describe a fixed-size FIFO ring.
    uint32_t inboundHead;
    uint32_t inboundCount;

    // Configuration is finalized before the worker is started.
    size_t maxInboundBytes;
    uint16_t basePort;
    RogueSimLinkSocketOrder order;

    // These flags are predicates for condition-variable waits.
    int threadStarted;
    int ready;
    int stopping;
    int failed;
    int outboundPending;
};

void rogueSimLinkMessageInit(RogueSimLinkMessage* message) {
    if (message == NULL) return;
    memset(message, 0, sizeof(*message));
}

int rogueSimLinkMessageAdd(RogueSimLinkMessage* message, const void* data, size_t size) {
    void* part;

    if (message == NULL || (data == NULL && size != 0) || message->count >= ROGUE_SIM_LINK_MAX_PARTS) return 0;
    // malloc(0) is implementation-defined; retain a non-NULL owned part even
    // for a legitimate empty multipart frame.
    part = malloc(size == 0 ? 1 : size);
    if (part == NULL) return 0;
    if (size != 0) memcpy(part, data, size);
    message->data[message->count] = part;
    message->size[message->count] = size;
    message->owned |= 1U << message->count;
    message->count++;
    return 1;
}

int rogueSimLinkMessageAddReference(RogueSimLinkMessage* message, const void* data, size_t size) {
    if (message == NULL || (data == NULL && size != 0) || message->count >= ROGUE_SIM_LINK_MAX_PARTS) return 0;
    // The owned bitmap remains clear, so release resets this entry without
    // freeing caller storage. Send() copies references before returning.
    message->data[message->count] = (void*)data;
    message->size[message->count] = size;
    message->count++;
    return 1;
}

void rogueSimLinkMessageRelease(RogueSimLinkMessage* message) {
    uint32_t index;

    if (message == NULL) return;
    for (index = 0; index < message->count; index++) {
        if ((message->owned >> index) & 1U) free(message->data[index]);
    }
    rogueSimLinkMessageInit(message);
}

int rogueSimLinkTransportResolveTimeout(uint32_t instanceTimeoutMs,
                                        uint32_t* timeoutMs,
                                        char* error,
                                        size_t errorSize) {
    const char* value;
    const char* digit;
    uint64_t parsed = 0;

    if (timeoutMs == NULL) return 0;
    // A per-instance setting has highest priority. Zero means "not set", then
    // the environment override and compiled default are considered in order.
    if (instanceTimeoutMs != 0) {
        *timeoutMs = instanceTimeoutMs;
        return 1;
    }

    value = getenv(ROGUE_SIM_LINK_TIMEOUT_ENV);
    if (value == NULL) {
        *timeoutMs = ROGUE_SIM_LINK_DEFAULT_TIMEOUT_MS;
        return 1;
    }

    for (digit = value; *digit != '\0'; digit++) {
        uint32_t next;

        if (*digit < '0' || *digit > '9') break;
        next = (uint32_t)(*digit - '0');
        if (parsed > (UINT32_MAX - next) / 10U) break;
        parsed = parsed * 10U + next;
    }
    if (*value == '\0' || *digit != '\0' || parsed == 0) {
        if (error != NULL && errorSize != 0)
            snprintf(error,
                     errorSize,
                     "%s must be a decimal integer from 1 through %u milliseconds",
                     ROGUE_SIM_LINK_TIMEOUT_ENV,
                     UINT32_MAX);
        return 0;
    }

    *timeoutMs = (uint32_t)parsed;
    return 1;
}

static int rogueSimLinkMessageCopy(RogueSimLinkMessage* destination, const RogueSimLinkMessage* source) {
    uint32_t index;

    // The deep copy decouples simulator-owned buffers from the worker thread.
    rogueSimLinkMessageInit(destination);
    for (index = 0; index < source->count; index++) {
        if (!rogueSimLinkMessageAdd(destination, source->data[index], source->size[index])) {
            rogueSimLinkMessageRelease(destination);
            return 0;
        }
    }
    return 1;
}

static void rogueSimLinkTransportSetErrorLocked(RogueSimLinkTransport* transport, const char* format, ...) {
    va_list arguments;

    // Preserve the first failure, which is normally the most useful root
    // cause, and wake every startup/send/shutdown waiter.
    if (transport->failed) return;
    va_start(arguments, format);
    vsnprintf(transport->error, sizeof(transport->error), format, arguments);
    va_end(arguments);
    transport->failed   = 1;
    transport->stopping = 1;
    pthread_cond_broadcast(&(transport->condition));
}

static void rogueSimLinkTransportSetZmqError(RogueSimLinkTransport* transport, const char* operation, uint16_t port) {
    int error = zmq_errno();

    pthread_mutex_lock(&(transport->mutex));
    rogueSimLinkTransportSetErrorLocked(transport,
                                        "%s: %s failed on port %u: %s",
                                        transport->modelName,
                                        operation,
                                        port,
                                        zmq_strerror(error));
    pthread_mutex_unlock(&(transport->mutex));
}

static uint16_t rogueSimLinkTransportPushPort(const RogueSimLinkTransport* transport) {
    return (transport->order == ROGUE_SIM_LINK_PUSH_BASE) ? transport->basePort : transport->basePort + 1U;
}

static uint16_t rogueSimLinkTransportPullPort(const RogueSimLinkTransport* transport) {
    return (transport->order == ROGUE_SIM_LINK_PULL_BASE) ? transport->basePort : transport->basePort + 1U;
}

static void rogueSimLinkTransportDeadline(struct timespec* deadline, uint32_t timeoutMs) {
    // Wall-clock corrections must not shorten or extend transport deadlines.
    clock_gettime(CLOCK_MONOTONIC, deadline);
    deadline->tv_sec += timeoutMs / 1000U;
    deadline->tv_nsec +=                       // NOLINT(runtime/int)
        (long)(timeoutMs % 1000U) * 1000000L;  // NOLINT(runtime/int)
    if (deadline->tv_nsec >= 1000000000L) {
        deadline->tv_sec++;
        deadline->tv_nsec -= 1000000000L;
    }
}

static int rogueSimLinkTransportConditionInit(RogueSimLinkTransport* transport) {
#if defined(__APPLE__)
    // macOS does not provide pthread_condattr_setclock(). Timed waits use its
    // relative extension below, with a monotonic absolute deadline retained
    // by the caller so spurious wakeups cannot restart the timeout.
    return pthread_cond_init(&(transport->condition), NULL) == 0;
#else
    pthread_condattr_t attributes;
    int result;

    if (pthread_condattr_init(&attributes) != 0) return 0;
    result = pthread_condattr_setclock(&attributes, CLOCK_MONOTONIC);
    if (result == 0) result = pthread_cond_init(&(transport->condition), &attributes);
    pthread_condattr_destroy(&attributes);
    return result == 0;
#endif
}

static int rogueSimLinkTransportTimedWait(RogueSimLinkTransport* transport, const struct timespec* deadline) {
#if defined(__APPLE__)
    struct timespec now;
    struct timespec remaining;

    if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) return ETIMEDOUT;
    if (now.tv_sec > deadline->tv_sec || (now.tv_sec == deadline->tv_sec && now.tv_nsec >= deadline->tv_nsec))
        return ETIMEDOUT;

    remaining.tv_sec  = deadline->tv_sec - now.tv_sec;
    remaining.tv_nsec = deadline->tv_nsec - now.tv_nsec;
    if (remaining.tv_nsec < 0) {
        remaining.tv_sec--;
        remaining.tv_nsec += 1000000000L;
    }
    return pthread_cond_timedwait_relative_np(&(transport->condition), &(transport->mutex), &remaining);
#else
    return pthread_cond_timedwait(&(transport->condition), &(transport->mutex), deadline);
#endif
}

static int rogueSimLinkTransportSetOption(RogueSimLinkTransport* transport,
                                          void* socket,
                                          int option,
                                          int value,
                                          const char* operation,
                                          uint16_t port) {
    if (zmq_setsockopt(socket, option, &value, sizeof(value)) == 0) return 1;
    rogueSimLinkTransportSetZmqError(transport, operation, port);
    return 0;
}

static int rogueSimLinkTransportBind(RogueSimLinkTransport* transport,
                                     void* socket,
                                     const char* operation,
                                     uint16_t port) {
    char endpoint[64];

    snprintf(endpoint, sizeof(endpoint), "tcp://127.0.0.1:%u", port);
    if (zmq_bind(socket, endpoint) == 0) return 1;
    rogueSimLinkTransportSetZmqError(transport, operation, port);
    return 0;
}

static void rogueSimLinkTransportClose(RogueSimLinkTransport* transport) {
    if (transport->push != NULL) zmq_close(transport->push);
    if (transport->pull != NULL) zmq_close(transport->pull);
    if (transport->context != NULL) zmq_ctx_term(transport->context);
    transport->push    = NULL;
    transport->pull    = NULL;
    transport->context = NULL;
}

static int rogueSimLinkTransportSetup(RogueSimLinkTransport* transport) {
    int linger        = 0;
    uint16_t pullPort = (transport->order == ROGUE_SIM_LINK_PULL_BASE) ? transport->basePort : transport->basePort + 1U;
    uint16_t pushPort = (transport->order == ROGUE_SIM_LINK_PUSH_BASE) ? transport->basePort : transport->basePort + 1U;

    // Both sockets bind on loopback; Rogue clients connect to the paired
    // endpoints. `order` accounts for the historical side-band reversal.
    transport->context = zmq_ctx_new();
    if (transport->context == NULL) {
        rogueSimLinkTransportSetZmqError(transport, "context create", transport->basePort);
        return 0;
    }
    transport->pull = zmq_socket(transport->context, ZMQ_PULL);
    if (transport->pull == NULL) {
        rogueSimLinkTransportSetZmqError(transport, "PULL socket create", pullPort);
        return 0;
    }
    transport->push = zmq_socket(transport->context, ZMQ_PUSH);
    if (transport->push == NULL) {
        rogueSimLinkTransportSetZmqError(transport, "PUSH socket create", pushPort);
        return 0;
    }

    // No linger keeps simulator teardown bounded. The high-water marks mirror
    // the in-process queues, IMMEDIATE prevents disconnected sends from being
    // queued indefinitely, and SNDTIMEO gives the worker a chance to observe
    // the stopping flag between retries.
    if (!rogueSimLinkTransportSetOption(transport,
                                        transport->pull,
                                        ZMQ_LINGER,
                                        linger,
                                        "PULL linger setup",
                                        pullPort) ||
        !rogueSimLinkTransportSetOption(transport,
                                        transport->push,
                                        ZMQ_LINGER,
                                        linger,
                                        "PUSH linger setup",
                                        pushPort) ||
        !rogueSimLinkTransportSetOption(transport,
                                        transport->pull,
                                        ZMQ_RCVHWM,
                                        ROGUE_SIM_LINK_INBOUND_DEPTH,
                                        "PULL high-water setup",
                                        pullPort) ||
        !rogueSimLinkTransportSetOption(transport,
                                        transport->push,
                                        ZMQ_SNDHWM,
                                        ROGUE_SIM_LINK_OUTBOUND_DEPTH,
                                        "PUSH high-water setup",
                                        pushPort) ||
        !rogueSimLinkTransportSetOption(transport,
                                        transport->push,
                                        ZMQ_IMMEDIATE,
                                        1,
                                        "PUSH immediate setup",
                                        pushPort) ||
        !rogueSimLinkTransportSetOption(transport,
                                        transport->push,
                                        ZMQ_SNDTIMEO,
                                        ROGUE_SIM_LINK_SOCKET_TIMEOUT_MS,
                                        "PUSH timeout setup",
                                        pushPort) ||
        !rogueSimLinkTransportBind(transport, transport->pull, "PULL bind", pullPort) ||
        !rogueSimLinkTransportBind(transport, transport->push, "PUSH bind", pushPort))
        return 0;
    return 1;
}

static int rogueSimLinkTransportSendWorker(RogueSimLinkTransport* transport, const RogueSimLinkMessage* message) {
    uint32_t index;

    // Preserve Rogue's multipart framing; only the final part clears SNDMORE.
    for (index = 0; index < message->count; index++) {
        int flags = (index + 1U == message->count) ? 0 : ZMQ_SNDMORE;
        int result;

        // EAGAIN is expected while no peer is connected. Retry in bounded
        // socket-timeout increments so destroy can interrupt the loop.
        do {
            result = zmq_send(transport->push, message->data[index], message->size[index], flags);
            if (result < 0 && zmq_errno() == EAGAIN) {
                pthread_mutex_lock(&(transport->mutex));
                if (transport->stopping) {
                    pthread_mutex_unlock(&(transport->mutex));
                    return 0;
                }
                pthread_mutex_unlock(&(transport->mutex));
            }
        } while (result < 0 && zmq_errno() == EAGAIN);

        if (result < 0) {
            rogueSimLinkTransportSetZmqError(transport, "PUSH send", rogueSimLinkTransportPushPort(transport));
            return 0;
        }
    }
    return 1;
}

static int rogueSimLinkTransportReceiveWorker(RogueSimLinkTransport* transport, RogueSimLinkMessage* message) {
    int more         = 0;
    size_t moreSize  = sizeof(more);
    size_t totalSize = 0;

    rogueSimLinkMessageInit(message);
    do {
        zmq_msg_t part;
        int result;

        if (message->count >= ROGUE_SIM_LINK_MAX_PARTS) {
            pthread_mutex_lock(&(transport->mutex));
            rogueSimLinkTransportSetErrorLocked(transport,
                                                "%s: inbound message exceeds %u parts on port %u",
                                                transport->modelName,
                                                ROGUE_SIM_LINK_MAX_PARTS,
                                                rogueSimLinkTransportPullPort(transport));
            pthread_mutex_unlock(&(transport->mutex));
            rogueSimLinkMessageRelease(message);
            return -1;
        }
        if (zmq_msg_init(&part) != 0) {
            rogueSimLinkTransportSetZmqError(transport, "PULL message init", rogueSimLinkTransportPullPort(transport));
            rogueSimLinkMessageRelease(message);
            return -1;
        }
        // Probe the first part without blocking. Once a multipart message has
        // begun, receive its remaining parts as one indivisible queue entry.
        result = zmq_msg_recv(&part, transport->pull, message->count == 0 ? ZMQ_DONTWAIT : 0);
        if (result < 0) {
            int error = zmq_errno();
            zmq_msg_close(&part);
            if (message->count == 0 && error == EAGAIN) return 0;
            rogueSimLinkTransportSetZmqError(transport, "PULL receive", rogueSimLinkTransportPullPort(transport));
            rogueSimLinkMessageRelease(message);
            return -1;
        }
        {
            size_t partSize = zmq_msg_size(&part);

            if (partSize > transport->maxInboundBytes - totalSize) {
                zmq_msg_close(&part);
                pthread_mutex_lock(&(transport->mutex));
                rogueSimLinkTransportSetErrorLocked(transport,
                                                    "%s: inbound message exceeds %zu bytes on port %u",
                                                    transport->modelName,
                                                    transport->maxInboundBytes,
                                                    rogueSimLinkTransportPullPort(transport));
                pthread_mutex_unlock(&(transport->mutex));
                rogueSimLinkMessageRelease(message);
                return -1;
            }
            if (!rogueSimLinkMessageAdd(message, zmq_msg_data(&part), partSize)) {
                zmq_msg_close(&part);
                pthread_mutex_lock(&(transport->mutex));
                rogueSimLinkTransportSetErrorLocked(transport,
                                                    "%s: inbound message allocation failed on port %u",
                                                    transport->modelName,
                                                    rogueSimLinkTransportPullPort(transport));
                pthread_mutex_unlock(&(transport->mutex));
                rogueSimLinkMessageRelease(message);
                return -1;
            }
            totalSize += partSize;
        }
        zmq_msg_close(&part);
        more = 0;
        if (zmq_getsockopt(transport->pull, ZMQ_RCVMORE, &more, &moreSize) != 0) {
            rogueSimLinkTransportSetZmqError(transport,
                                             "PULL multipart query",
                                             rogueSimLinkTransportPullPort(transport));
            rogueSimLinkMessageRelease(message);
            return -1;
        }
    } while (more);
    return 1;
}

static void* rogueSimLinkTransportWorker(void* opaque) {
    RogueSimLinkTransport* transport = opaque;

    if (!rogueSimLinkTransportSetup(transport)) {
        rogueSimLinkTransportClose(transport);
        return NULL;
    }

    // Start() waits for this point so a successful return means both sockets
    // have been configured and bound.
    pthread_mutex_lock(&(transport->mutex));
    transport->ready = 1;
    pthread_cond_broadcast(&(transport->condition));
    pthread_mutex_unlock(&(transport->mutex));

    while (1) {
        int haveOutbound;
        int canReceive;

        pthread_mutex_lock(&(transport->mutex));
        if (transport->stopping) {
            pthread_mutex_unlock(&(transport->mutex));
            break;
        }
        haveOutbound = transport->outboundPending;
        canReceive   = transport->inboundCount < ROGUE_SIM_LINK_INBOUND_DEPTH;
        pthread_mutex_unlock(&(transport->mutex));

        // Give synchronous outbound traffic priority. This bounds the time a
        // simulator callback spends waiting even during heavy inbound traffic.
        if (haveOutbound) {
            int sent = rogueSimLinkTransportSendWorker(transport, &(transport->outbound));

            pthread_mutex_lock(&(transport->mutex));
            if (sent) {
                rogueSimLinkMessageRelease(&(transport->outbound));
                transport->outboundPending = 0;
                pthread_cond_broadcast(&(transport->condition));
            }
            pthread_mutex_unlock(&(transport->mutex));
            continue;
        }

        // Apply backpressure at the local ring rather than receiving and then
        // dropping a complete Rogue message.
        if (!canReceive) {
            struct timespec deadline;

            rogueSimLinkTransportDeadline(&deadline, ROGUE_SIM_LINK_WORKER_POLL_MS);
            pthread_mutex_lock(&(transport->mutex));
            if (!transport->stopping && transport->inboundCount >= ROGUE_SIM_LINK_INBOUND_DEPTH)
                rogueSimLinkTransportTimedWait(transport, &deadline);
            pthread_mutex_unlock(&(transport->mutex));
            continue;
        }

        if (canReceive) {
            RogueSimLinkMessage message;
            int received = rogueSimLinkTransportReceiveWorker(transport, &message);

            if (received > 0) {
                uint32_t tail;

                pthread_mutex_lock(&(transport->mutex));
                // Ownership of every allocated message part moves into the
                // ring by structure assignment.
                tail = (transport->inboundHead + transport->inboundCount) % ROGUE_SIM_LINK_INBOUND_DEPTH;
                transport->inbound[tail] = message;
                transport->inboundCount++;
                pthread_mutex_unlock(&(transport->mutex));
                continue;
            }
            if (received < 0) break;
        }

        // Nothing was ready. Poll briefly to avoid a busy loop while retaining
        // a bounded response time for outbound work and shutdown.
        {
            zmq_pollitem_t item = {transport->pull, 0, ZMQ_POLLIN, 0};
            zmq_poll(&item, 1, ROGUE_SIM_LINK_WORKER_POLL_MS);
        }
    }

    rogueSimLinkTransportClose(transport);
    return NULL;
}

RogueSimLinkTransport* rogueSimLinkTransportCreate(uint16_t basePort,
                                                   RogueSimLinkSocketOrder order,
                                                   const char* modelName,
                                                   size_t maxInboundBytes) {
    RogueSimLinkTransport* transport = calloc(1, sizeof(*transport));

    if (transport == NULL) return NULL;
    if (basePort == 0 || basePort == UINT16_MAX || maxInboundBytes == 0 ||
        (order != ROGUE_SIM_LINK_PULL_BASE && order != ROGUE_SIM_LINK_PUSH_BASE)) {
        free(transport);
        return NULL;
    }
    transport->basePort        = basePort;
    transport->order           = order;
    transport->maxInboundBytes = maxInboundBytes;
    snprintf(transport->modelName, sizeof(transport->modelName), "%s", modelName == NULL ? "RogueSimLink" : modelName);
    rogueSimLinkMessageInit(&(transport->outbound));
    if (pthread_mutex_init(&(transport->mutex), NULL) != 0) {
        free(transport);
        return NULL;
    }
    if (!rogueSimLinkTransportConditionInit(transport)) {
        pthread_mutex_destroy(&(transport->mutex));
        free(transport);
        return NULL;
    }
    return transport;
}

int rogueSimLinkTransportStart(RogueSimLinkTransport* transport, uint32_t timeoutMs) {
    struct timespec deadline;

    if (transport == NULL || transport->threadStarted) return 0;
    if (pthread_create(&(transport->thread), NULL, rogueSimLinkTransportWorker, transport) != 0) {
        pthread_mutex_lock(&(transport->mutex));
        rogueSimLinkTransportSetErrorLocked(transport,
                                            "%s: worker thread creation failed on port %u",
                                            transport->modelName,
                                            transport->basePort);
        pthread_mutex_unlock(&(transport->mutex));
        return 0;
    }
    transport->threadStarted = 1;
    rogueSimLinkTransportDeadline(&deadline, timeoutMs);

    // Wait on predicates, not a single notification: condition variables may
    // wake spuriously and setup failures use the same broadcast path.
    pthread_mutex_lock(&(transport->mutex));
    while (!transport->ready && !transport->failed) {
        if (rogueSimLinkTransportTimedWait(transport, &deadline) == ETIMEDOUT) {
            /* ETIMEDOUT can race a genuine wakeup: the worker may have set
             * ready/failed and broadcast at the same scheduling boundary the
             * deadline expired. Only report a timeout if the predicate is still
             * unsatisfied; otherwise fall through and honor the real result. */
            if (!transport->ready && !transport->failed)
                rogueSimLinkTransportSetErrorLocked(transport,
                                                    "%s: worker startup timeout on ports %u/%u",
                                                    transport->modelName,
                                                    transport->basePort,
                                                    transport->basePort + 1U);
            break;
        }
    }
    {
        int result = transport->ready && !transport->failed;
        pthread_mutex_unlock(&(transport->mutex));
        return result;
    }
}

int rogueSimLinkTransportSend(RogueSimLinkTransport* transport,
                              const RogueSimLinkMessage* message,
                              uint32_t timeoutMs) {
    struct timespec deadline;
    int result;

    if (transport == NULL || message == NULL || message->count == 0 || message->count > ROGUE_SIM_LINK_MAX_PARTS)
        return 0;
    rogueSimLinkTransportDeadline(&deadline, timeoutMs);
    pthread_mutex_lock(&(transport->mutex));
    if (!transport->ready || transport->failed || transport->outboundPending) {
        pthread_mutex_unlock(&(transport->mutex));
        return 0;
    }
    // Copy while holding the mutex, then let the worker own the copy. The
    // caller's referenced parts may therefore be stack-backed.
    if (!rogueSimLinkMessageCopy(&(transport->outbound), message)) {
        rogueSimLinkTransportSetErrorLocked(transport,
                                            "%s: outbound allocation failed on port %u",
                                            transport->modelName,
                                            rogueSimLinkTransportPushPort(transport));
        pthread_mutex_unlock(&(transport->mutex));
        return 0;
    }
    transport->outboundPending = 1;
    pthread_cond_broadcast(&(transport->condition));

    // This rendezvous preserves the old callback semantics: success means the
    // complete multipart message has reached ZeroMQ, not merely a local queue.
    while (transport->outboundPending && !transport->failed) {
        if (rogueSimLinkTransportTimedWait(transport, &deadline) == ETIMEDOUT) {
            /* ETIMEDOUT can race a genuine wakeup: the worker may have
             * completed the send (cleared outboundPending) and broadcast at
             * the same scheduling boundary the deadline expired. Only report a
             * timeout if the send is still pending; otherwise fall through and
             * report the send as successful. */
            if (transport->outboundPending && !transport->failed)
                rogueSimLinkTransportSetErrorLocked(transport,
                                                    "%s: transport timeout on port %u during outbound send",
                                                    transport->modelName,
                                                    rogueSimLinkTransportPushPort(transport));
            break;
        }
    }
    result = !transport->failed && !transport->outboundPending;
    pthread_mutex_unlock(&(transport->mutex));
    return result;
}

int rogueSimLinkTransportReceive(RogueSimLinkTransport* transport, RogueSimLinkMessage* message) {
    if (transport == NULL || message == NULL) return -1;
    rogueSimLinkMessageInit(message);
    pthread_mutex_lock(&(transport->mutex));
    if (transport->failed) {
        pthread_mutex_unlock(&(transport->mutex));
        return -1;
    }
    if (transport->inboundCount == 0) {
        pthread_mutex_unlock(&(transport->mutex));
        return 0;
    }
    // Transfer ownership out of the ring; clearing the slot prevents destroy
    // from releasing the same parts a second time.
    *message = transport->inbound[transport->inboundHead];
    rogueSimLinkMessageInit(&(transport->inbound[transport->inboundHead]));
    transport->inboundHead = (transport->inboundHead + 1U) % ROGUE_SIM_LINK_INBOUND_DEPTH;
    transport->inboundCount--;
    pthread_cond_broadcast(&(transport->condition));
    pthread_mutex_unlock(&(transport->mutex));
    return 1;
}

int rogueSimLinkTransportCopyError(RogueSimLinkTransport* transport, char* buffer, size_t size) {
    int failed;

    if (transport == NULL || buffer == NULL || size == 0) return 0;
    pthread_mutex_lock(&(transport->mutex));
    failed = transport->failed;
    snprintf(buffer, size, "%s", transport->error);
    pthread_mutex_unlock(&(transport->mutex));
    return failed;
}

void rogueSimLinkTransportDestroy(RogueSimLinkTransport* transport) {
    uint32_t index;

    if (transport == NULL) return;
    pthread_mutex_lock(&(transport->mutex));
    transport->stopping = 1;
    pthread_cond_broadcast(&(transport->condition));
    pthread_mutex_unlock(&(transport->mutex));
    // Join before releasing messages or synchronization objects because the
    // worker may still own the outbound slot or a partially received message.
    if (transport->threadStarted) pthread_join(transport->thread, NULL);

    rogueSimLinkMessageRelease(&(transport->outbound));
    for (index = 0; index < ROGUE_SIM_LINK_INBOUND_DEPTH; index++)
        rogueSimLinkMessageRelease(&(transport->inbound[index]));
    pthread_cond_destroy(&(transport->condition));
    pthread_mutex_destroy(&(transport->mutex));
    free(transport);
}
