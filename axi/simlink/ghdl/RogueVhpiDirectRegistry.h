//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef ROGUE_VHPI_DIRECT_REGISTRY_H
#define ROGUE_VHPI_DIRECT_REGISTRY_H

#include <limits.h>
#include <stdint.h>
#include <stdlib.h>

typedef void (*RogueVhpiDirectCleanup)(void *data);

typedef struct RogueVhpiDirectInstance {
    int32_t handle;
    uint16_t requestedPort;
    void *data;
    RogueVhpiDirectCleanup cleanup;
    struct RogueVhpiDirectInstance *next;
} RogueVhpiDirectInstance;

// Each GHDL model is built as a separate shared object, so these file-local
// registry variables form one independent handle namespace per model type.
static RogueVhpiDirectInstance *rogueVhpiDirectInstances = NULL;
static int32_t rogueVhpiDirectNextHandle = 1;
static int rogueVhpiDirectCleanupRegistered = 0;

static void rogueVhpiDirectCleanupAll(void) {
    RogueVhpiDirectInstance *instance;
    RogueVhpiDirectInstance *next;

    instance = rogueVhpiDirectInstances;
    while (instance != NULL) {
        next = instance->next;
        if (instance->cleanup != NULL) instance->cleanup(instance->data);
        free(instance->data);
        free(instance);
        instance = next;
    }
    rogueVhpiDirectInstances = NULL;
}

static RogueVhpiDirectInstance *rogueVhpiDirectLookup(int32_t handle,
                                                       const char *modelName) {
    RogueVhpiDirectInstance *instance;

    for (instance = rogueVhpiDirectInstances; instance != NULL; instance = instance->next) {
        if (instance->handle == handle) return instance;
    }

    vhpi_printf("%s: invalid VHPIDIRECT instance handle %d\n", modelName, handle);
    vhpi_assert("Invalid VHPIDIRECT instance handle", vhpiFatal);
    return NULL;
}

static int32_t rogueVhpiDirectCreate(size_t dataSize,
                                     RogueVhpiDirectCleanup cleanup,
                                     const char *modelName) {
    RogueVhpiDirectInstance *instance;

    if (rogueVhpiDirectNextHandle == INT32_MAX) {
        vhpi_printf("%s: exhausted VHPIDIRECT instance handles\n", modelName);
        vhpi_assert("Exhausted VHPIDIRECT instance handles", vhpiFatal);
        return 0;
    }

    instance = calloc(1, sizeof(*instance));
    if (instance == NULL) {
        vhpi_printf("%s: failed to allocate instance registry entry\n", modelName);
        vhpi_assert("Failed to allocate VHPIDIRECT registry entry", vhpiFatal);
        return 0;
    }

    instance->data = calloc(1, dataSize);
    if (instance->data == NULL) {
        free(instance);
        vhpi_printf("%s: failed to allocate instance state\n", modelName);
        vhpi_assert("Failed to allocate VHPIDIRECT instance state", vhpiFatal);
        return 0;
    }

    instance->handle = rogueVhpiDirectNextHandle++;
    instance->cleanup = cleanup;
    instance->next = rogueVhpiDirectInstances;
    rogueVhpiDirectInstances = instance;

    if (!rogueVhpiDirectCleanupRegistered) {
        if (atexit(rogueVhpiDirectCleanupAll) != 0) {
            vhpi_printf("%s: failed to register instance cleanup\n", modelName);
            vhpi_assert("Failed to register VHPIDIRECT instance cleanup", vhpiFatal);
            return 0;
        }
        rogueVhpiDirectCleanupRegistered = 1;
    }

    return instance->handle;
}

static void *rogueVhpiDirectGetData(int32_t handle, const char *modelName) {
    return rogueVhpiDirectLookup(handle, modelName)->data;
}

static void rogueVhpiDirectDestroy(int32_t handle, const char *modelName) {
    RogueVhpiDirectInstance *instance;
    RogueVhpiDirectInstance *previous;

    previous = NULL;
    for (instance = rogueVhpiDirectInstances; instance != NULL; instance = instance->next) {
        if (instance->handle == handle) break;
        previous = instance;
    }

    if (instance == NULL) {
        (void)rogueVhpiDirectLookup(handle, modelName);
        return;
    }

    if (previous == NULL) {
        rogueVhpiDirectInstances = instance->next;
    } else {
        previous->next = instance->next;
    }

    if (instance->cleanup != NULL) instance->cleanup(instance->data);
    free(instance->data);
    free(instance);
}

static void rogueVhpiDirectReservePort(int32_t handle,
                                       uint16_t requestedPort,
                                       const char *modelName) {
    RogueVhpiDirectInstance *instance;
    RogueVhpiDirectInstance *other;

    instance = rogueVhpiDirectLookup(handle, modelName);

    if (requestedPort == 0) {
        vhpi_printf("%s: port must be non-zero\n", modelName);
        vhpi_assert("VHPIDIRECT instance port must be non-zero", vhpiFatal);
        return;
    }

    if (instance->requestedPort == 0) {
        for (other = rogueVhpiDirectInstances; other != NULL; other = other->next) {
            if (other != instance && other->requestedPort == requestedPort) {
                vhpi_printf("%s: duplicate VHPIDIRECT port %u for handles %d and %d\n",
                            modelName, requestedPort, other->handle, handle);
                vhpi_assert("Duplicate VHPIDIRECT instance port", vhpiFatal);
                return;
            }
        }
        instance->requestedPort = requestedPort;
    } else if (instance->requestedPort != requestedPort) {
        vhpi_printf("%s: port changed for VHPIDIRECT handle %d from %u to %u\n",
                    modelName, handle, instance->requestedPort, requestedPort);
        vhpi_assert("VHPIDIRECT instance port changed", vhpiFatal);
    }
}

#endif
