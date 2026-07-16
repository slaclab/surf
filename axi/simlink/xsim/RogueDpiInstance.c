//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "RogueDpiInstance.h"

#define ROGUE_DPI_MAGIC_C 0x52445049U

typedef struct RogueDpiInstance {
    uint32_t magic;
    RogueDpiModel model;
    uint16_t requestedPort;
    void *data;
    RogueDpiCleanup cleanup;
    struct RogueDpiInstance *next;
    struct RogueDpiInstance *previous;
} RogueDpiInstance;

static RogueDpiInstance *rogueDpiInstances = NULL;
static int rogueDpiCleanupRegistered = 0;

static const char *rogueDpiModelName(RogueDpiModel model) {
    switch (model) {
        case ROGUE_DPI_STREAM_C:
            return "RogueTcpStream";
        case ROGUE_DPI_MEMORY_C:
            return "RogueTcpMemory";
        case ROGUE_DPI_SIDEBAND_C:
            return "RogueSideBand";
        default:
            return "UnknownRogueDpiModel";
    }
}

static RogueDpiInstance *rogueDpiValidate(const void *context,
                                           RogueDpiModel expectedModel) {
    RogueDpiInstance *instance = (RogueDpiInstance *)context;

    if (instance == NULL) {
        fprintf(stderr, "%s: null DPI instance context\n",
                rogueDpiModelName(expectedModel));
        return NULL;
    }

    if (instance->magic != ROGUE_DPI_MAGIC_C) {
        fprintf(stderr, "%s: invalid DPI instance context\n",
                rogueDpiModelName(expectedModel));
        return NULL;
    }

    if (instance->model != expectedModel) {
        fprintf(stderr, "%s: DPI context belongs to %s\n",
                rogueDpiModelName(expectedModel),
                rogueDpiModelName(instance->model));
        return NULL;
    }

    return instance;
}

static void rogueDpiRemove(RogueDpiInstance *instance) {
    if (instance->previous == NULL) {
        rogueDpiInstances = instance->next;
    } else {
        instance->previous->next = instance->next;
    }

    if (instance->next != NULL) instance->next->previous = instance->previous;
    instance->next = NULL;
    instance->previous = NULL;
}

static void rogueDpiRelease(RogueDpiInstance *instance) {
    rogueDpiRemove(instance);
    instance->magic = 0;
    if (instance->cleanup != NULL) instance->cleanup(instance->data);
    free(instance->data);
    free(instance);
}

static void rogueDpiDestroyAll(void) {
    while (rogueDpiInstances != NULL) rogueDpiRelease(rogueDpiInstances);
}

void *rogueDpiCreate(RogueDpiModel model,
                     size_t dataSize,
                     RogueDpiCleanup cleanup) {
    RogueDpiInstance *instance;

    instance = calloc(1, sizeof(*instance));
    if (instance == NULL) {
        fprintf(stderr, "%s: failed to allocate DPI instance metadata\n",
                rogueDpiModelName(model));
        return NULL;
    }

    instance->data = calloc(1, dataSize);
    if (instance->data == NULL) {
        fprintf(stderr, "%s: failed to allocate DPI instance state\n",
                rogueDpiModelName(model));
        free(instance);
        return NULL;
    }

    if (!rogueDpiCleanupRegistered) {
        if (atexit(rogueDpiDestroyAll) != 0) {
            fprintf(stderr, "%s: failed to register DPI instance cleanup\n",
                    rogueDpiModelName(model));
            free(instance->data);
            free(instance);
            return NULL;
        }
        rogueDpiCleanupRegistered = 1;
    }

    instance->magic = ROGUE_DPI_MAGIC_C;
    instance->model = model;
    instance->cleanup = cleanup;
    instance->next = rogueDpiInstances;
    if (rogueDpiInstances != NULL) rogueDpiInstances->previous = instance;
    rogueDpiInstances = instance;

    return instance;
}

void *rogueDpiGetData(const void *context, RogueDpiModel expectedModel) {
    RogueDpiInstance *instance = rogueDpiValidate(context, expectedModel);

    return (instance == NULL) ? NULL : instance->data;
}

int rogueDpiReservePort(const void *context,
                        RogueDpiModel expectedModel,
                        uint16_t requestedPort) {
    RogueDpiInstance *instance;
    RogueDpiInstance *other;
    uint32_t requestedEnd;
    uint32_t otherEnd;

    instance = rogueDpiValidate(context, expectedModel);
    if (instance == NULL) return 0;

    if (requestedPort == 0 || requestedPort == UINT16_MAX) {
        fprintf(stderr, "%s: invalid DPI base port %u\n",
                rogueDpiModelName(expectedModel), requestedPort);
        return 0;
    }

    if (instance->requestedPort != 0) {
        if (instance->requestedPort != requestedPort) {
            fprintf(stderr, "%s: DPI base port changed from %u to %u\n",
                    rogueDpiModelName(expectedModel),
                    instance->requestedPort, requestedPort);
            return 0;
        }
        return 1;
    }

    requestedEnd = (uint32_t)requestedPort + 1U;
    for (other = rogueDpiInstances; other != NULL; other = other->next) {
        if (other == instance || other->requestedPort == 0) continue;
        otherEnd = (uint32_t)other->requestedPort + 1U;
        if ((uint32_t)requestedPort <= otherEnd &&
            (uint32_t)other->requestedPort <= requestedEnd) {
            fprintf(stderr,
                    "%s: DPI port pair %u/%u overlaps live %s port pair %u/%u\n",
                    rogueDpiModelName(expectedModel),
                    requestedPort, requestedPort + 1U,
                    rogueDpiModelName(other->model),
                    other->requestedPort, other->requestedPort + 1U);
            return 0;
        }
    }

    instance->requestedPort = requestedPort;
    return 1;
}

int rogueDpiDestroy(const void *context, RogueDpiModel expectedModel) {
    RogueDpiInstance *instance = rogueDpiValidate(context, expectedModel);

    if (instance == NULL) return 0;
    rogueDpiRelease(instance);
    return 1;
}
