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
// Process-local ownership registry shared by the GHDL, VCS, and xsim
// adapters. It gives pointer-based DPI contexts and integer VHPIDIRECT handles
// the same validation, cleanup, and TCP-port-pair collision rules.
//////////////////////////////////////////////////////////////////////////////

#include "RogueSimLinkInstance.h"

#include <limits.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

struct RogueSimLinkInstance {
    int32_t handle;
    const RogueSimLinkModelDescriptor* model;

    // The base port is claimed lazily, once it is visible at a clock edge.
    uint16_t requestedPort;

    // Model storage and its backend-specific reporting/cleanup hooks.
    void* data;
    RogueSimLinkCleanup cleanup;
    RogueSimLinkReport report;

    // A doubly linked list makes explicit destruction cheap while retaining a
    // simple process-wide scan for validation and port collision detection.
    RogueSimLinkInstance* next;
    RogueSimLinkInstance* previous;
};

// The registry is used only from the simulator thread. Transport worker state
// is separately synchronized inside RogueSimLinkTransport.
static RogueSimLinkInstance* rogueSimLinkInstances = NULL;
static int32_t rogueSimLinkNextHandle              = 1;
static int rogueSimLinkCleanupRegistered           = 0;

const char* rogueSimLinkModelName(const RogueSimLinkModelDescriptor* model) {
    return (model == NULL || model->name == NULL || model->name[0] == '\0') ? "UnknownRogueSimLinkModel" : model->name;
}
static void rogueSimLinkReportMessage(RogueSimLinkReport report, const char* format, ...) {
    char message[512];
    va_list args;

    va_start(args, format);
    vsnprintf(message, sizeof(message), format, args);
    va_end(args);
    if (report != NULL) report(message);
}

static RogueSimLinkInstance* rogueSimLinkValidateInstance(RogueSimLinkInstance* instance,
                                                          const RogueSimLinkModelDescriptor* expectedModel,
                                                          RogueSimLinkReport report) {
    if (instance->model != expectedModel) {
        rogueSimLinkReportMessage((instance->report != NULL) ? instance->report : report,
                                  "%s: SimLink context belongs to %s\n",
                                  rogueSimLinkModelName(expectedModel),
                                  rogueSimLinkModelName(instance->model));
        return NULL;
    }

    return instance;
}

static RogueSimLinkInstance* rogueSimLinkValidate(const void* context,
                                                  const RogueSimLinkModelDescriptor* expectedModel,
                                                  RogueSimLinkReport report) {
    RogueSimLinkInstance* instance;

    if (context == NULL) {
        rogueSimLinkReportMessage(report, "%s: null SimLink instance context\n", rogueSimLinkModelName(expectedModel));
        return NULL;
    }

    // Establish pointer ownership through the live registry before reading
    // any fields. A caller can otherwise make validation dereference an
    // arbitrary or already-freed address while checking model ownership.
    for (instance = rogueSimLinkInstances; instance != NULL; instance = instance->next) {
        if (instance == context) break;
    }
    if (instance == NULL) {
        rogueSimLinkReportMessage(report,
                                  "%s: invalid SimLink instance context\n",
                                  rogueSimLinkModelName(expectedModel));
        return NULL;
    }

    return rogueSimLinkValidateInstance(instance, expectedModel, report);
}

static RogueSimLinkInstance* rogueSimLinkLookup(int32_t handle,
                                                const RogueSimLinkModelDescriptor* expectedModel,
                                                RogueSimLinkReport report) {
    RogueSimLinkInstance* instance;

    // Handles are monotonic and intentionally never reused, so a stale VHDL
    // handle cannot silently select a later instance.
    for (instance = rogueSimLinkInstances; instance != NULL; instance = instance->next) {
        if (instance->handle == handle) return rogueSimLinkValidateInstance(instance, expectedModel, report);
    }

    rogueSimLinkReportMessage(report,
                              "%s: invalid SimLink instance handle %d\n",
                              rogueSimLinkModelName(expectedModel),
                              handle);
    return NULL;
}

static void rogueSimLinkRemove(RogueSimLinkInstance* instance) {
    if (instance->previous == NULL) {
        rogueSimLinkInstances = instance->next;
    } else {
        instance->previous->next = instance->next;
    }

    if (instance->next != NULL) instance->next->previous = instance->previous;
    instance->next     = NULL;
    instance->previous = NULL;
}

static void rogueSimLinkRelease(RogueSimLinkInstance* instance) {
    // Unpublish first: cleanup may stop a worker and invoke logging, but no
    // nested adapter call may recover state that is already being destroyed.
    rogueSimLinkRemove(instance);
    if (instance->cleanup != NULL) instance->cleanup(instance->data);
    free(instance->data);
    free(instance);
}

static void rogueSimLinkDestroyAll(void) {
    while (rogueSimLinkInstances != NULL) rogueSimLinkRelease(rogueSimLinkInstances);
}

RogueSimLinkInstance* rogueSimLinkCreate(const RogueSimLinkModelDescriptor* model,
                                         size_t dataSize,
                                         RogueSimLinkCleanup cleanup,
                                         RogueSimLinkReport report) {
    RogueSimLinkInstance* instance;

    if (model == NULL || model->name == NULL || model->name[0] == '\0') {
        rogueSimLinkReportMessage(report, "RogueSimLink: invalid model descriptor\n");
        return NULL;
    }

    if (rogueSimLinkNextHandle == INT32_MAX) {
        rogueSimLinkReportMessage(report, "%s: exhausted SimLink instance handles\n", rogueSimLinkModelName(model));
        return NULL;
    }

    instance = calloc(1, sizeof(*instance));
    if (instance == NULL) {
        rogueSimLinkReportMessage(report,
                                  "%s: failed to allocate SimLink instance metadata\n",
                                  rogueSimLinkModelName(model));
        return NULL;
    }

    instance->data = calloc(1, dataSize);
    if (instance->data == NULL) {
        rogueSimLinkReportMessage(report,
                                  "%s: failed to allocate SimLink instance state\n",
                                  rogueSimLinkModelName(model));
        free(instance);
        return NULL;
    }

    // Simulator shutdown paths differ, so atexit is the common final safety
    // net. Explicit destroy still removes instances before process exit.
    if (!rogueSimLinkCleanupRegistered) {
        if (atexit(rogueSimLinkDestroyAll) != 0) {
            rogueSimLinkReportMessage(report,
                                      "%s: failed to register SimLink instance cleanup\n",
                                      rogueSimLinkModelName(model));
            free(instance->data);
            free(instance);
            return NULL;
        }
        rogueSimLinkCleanupRegistered = 1;
    }

    // Publish only after allocation and exit-cleanup registration succeed.
    instance->handle  = rogueSimLinkNextHandle++;
    instance->model   = model;
    instance->cleanup = cleanup;
    instance->report  = report;
    instance->next    = rogueSimLinkInstances;
    if (rogueSimLinkInstances != NULL) rogueSimLinkInstances->previous = instance;
    rogueSimLinkInstances = instance;

    return instance;
}

void* rogueSimLinkGetData(const void* context,
                          const RogueSimLinkModelDescriptor* expectedModel,
                          RogueSimLinkReport report) {
    RogueSimLinkInstance* instance = rogueSimLinkValidate(context, expectedModel, report);

    return (instance == NULL) ? NULL : instance->data;
}

int rogueSimLinkReservePort(const void* context,
                            const RogueSimLinkModelDescriptor* expectedModel,
                            uint16_t requestedPort,
                            RogueSimLinkReport report) {
    RogueSimLinkInstance* instance;
    RogueSimLinkInstance* other;
    uint32_t requestedEnd;
    uint32_t otherEnd;

    instance = rogueSimLinkValidate(context, expectedModel, report);
    if (instance == NULL) return 0;
    report = (instance->report != NULL) ? instance->report : report;

    if (requestedPort == 0 || requestedPort == UINT16_MAX) {
        rogueSimLinkReportMessage(report,
                                  "%s: invalid SimLink base port %u\n",
                                  rogueSimLinkModelName(expectedModel),
                                  requestedPort);
        return 0;
    }

    // A model may present the same generic every cycle, but changing it after
    // the first reservation would orphan the already-bound transport.
    if (instance->requestedPort != 0) {
        if (instance->requestedPort != requestedPort) {
            rogueSimLinkReportMessage(report,
                                      "%s: SimLink base port changed from %u to %u\n",
                                      rogueSimLinkModelName(expectedModel),
                                      instance->requestedPort,
                                      requestedPort);
            return 0;
        }
        return 1;
    }

    // Each model owns adjacent PUSH/PULL ports. Widen before adding one so the
    // interval comparison cannot wrap at UINT16_MAX.
    requestedEnd = (uint32_t)requestedPort + 1U;
    for (other = rogueSimLinkInstances; other != NULL; other = other->next) {
        if (other == instance || other->requestedPort == 0) continue;
        otherEnd = (uint32_t)other->requestedPort + 1U;
        if ((uint32_t)requestedPort <= otherEnd && (uint32_t)other->requestedPort <= requestedEnd) {
            rogueSimLinkReportMessage(report,
                                      "%s: SimLink port pair %u/%u overlaps live %s port pair "
                                      "%u/%u\n",
                                      rogueSimLinkModelName(expectedModel),
                                      requestedPort,
                                      requestedPort + 1U,
                                      rogueSimLinkModelName(other->model),
                                      other->requestedPort,
                                      other->requestedPort + 1U);
            return 0;
        }
    }

    instance->requestedPort = requestedPort;
    return 1;
}

int rogueSimLinkDestroy(const void* context,
                        const RogueSimLinkModelDescriptor* expectedModel,
                        RogueSimLinkReport report) {
    RogueSimLinkInstance* instance = rogueSimLinkValidate(context, expectedModel, report);

    if (instance == NULL) return 0;
    rogueSimLinkRelease(instance);
    return 1;
}

int32_t rogueSimLinkGetHandle(const RogueSimLinkInstance* instance) {
    return (instance == NULL) ? 0 : instance->handle;
}

void* rogueSimLinkGetDataByHandle(int32_t handle,
                                  const RogueSimLinkModelDescriptor* expectedModel,
                                  RogueSimLinkReport report) {
    RogueSimLinkInstance* instance = rogueSimLinkLookup(handle, expectedModel, report);

    return (instance == NULL) ? NULL : instance->data;
}

int rogueSimLinkReservePortByHandle(int32_t handle,
                                    const RogueSimLinkModelDescriptor* expectedModel,
                                    uint16_t requestedPort,
                                    RogueSimLinkReport report) {
    RogueSimLinkInstance* instance = rogueSimLinkLookup(handle, expectedModel, report);

    if (instance == NULL) return 0;
    return rogueSimLinkReservePort(instance, expectedModel, requestedPort, report);
}

int rogueSimLinkDestroyByHandle(int32_t handle,
                                const RogueSimLinkModelDescriptor* expectedModel,
                                RogueSimLinkReport report) {
    RogueSimLinkInstance* instance = rogueSimLinkLookup(handle, expectedModel, report);

    if (instance == NULL) return 0;
    return rogueSimLinkDestroy(instance, expectedModel, report);
}
