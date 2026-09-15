//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef ROGUE_SIM_LINK_INSTANCE_H
#define ROGUE_SIM_LINK_INSTANCE_H

#include <stddef.h>
#include <stdint.h>

/** Caller-owned type token and diagnostic name for a SimLink model family. */
typedef struct {
    const char* name; /**< Static, nonempty model name. */
} RogueSimLinkModelDescriptor;

/** Releases model-specific resources before the zeroed model state is freed. */
typedef void (*RogueSimLinkCleanup)(void* data);

/** Reports a recoverable validation or allocation error through an adapter. */
typedef void (*RogueSimLinkReport)(const char* message);

/** Opaque registry entry shared by the GHDL, VCS, and xsim adapters. */
typedef struct RogueSimLinkInstance RogueSimLinkInstance;

/**
 * Returns the diagnostic name associated with a model identifier.
 *
 * @param[in] model Model descriptor to inspect.
 * @return Static string; callers must not free or modify it.
 */
const char* rogueSimLinkModelName(const RogueSimLinkModelDescriptor* model);

/**
 * Allocates and registers one model instance.
 *
 * Model storage is zero-initialized. The returned context remains owned by the
 * registry until rogueSimLinkDestroy() or process-exit cleanup releases it.
 *
 * @param[in] model Static model descriptor stored in the instance.
 * @param[in] dataSize Number of bytes to allocate for model state.
 * @param[in] cleanup Optional model cleanup callback.
 * @param[in] report Optional adapter diagnostic callback.
 * @return Opaque instance context, or NULL after reporting an allocation error.
 */
RogueSimLinkInstance* rogueSimLinkCreate(const RogueSimLinkModelDescriptor* model,
                                         size_t dataSize,
                                         RogueSimLinkCleanup cleanup,
                                         RogueSimLinkReport report);

/**
 * Validates a context and returns its model storage.
 *
 * Validation establishes that the pointer belongs to the live registry before
 * dereferencing it, so fabricated and stale contexts fail safely.
 *
 * @param[in] context Opaque context returned by rogueSimLinkCreate().
 * @param[in] expectedModel Model descriptor required by the caller.
 * @param[in] report Fallback diagnostic callback.
 * @return Model storage, or NULL if validation fails.
 */
void* rogueSimLinkGetData(const void* context,
                          const RogueSimLinkModelDescriptor* expectedModel,
                          RogueSimLinkReport report);

/**
 * Claims an immutable adjacent TCP port pair for an instance.
 *
 * A request for base port N reserves both N and N+1 process-wide. Repeating the
 * same request is idempotent; changing the port or overlapping any live pair
 * fails. The claim is released only when the instance is destroyed.
 *
 * @param[in] context Opaque instance context.
 * @param[in] expectedModel Model descriptor required by the caller.
 * @param[in] requestedPort Base port of the pair to reserve.
 * @param[in] report Fallback diagnostic callback.
 * @return 1 on success, otherwise 0 after reporting the reason.
 */
int rogueSimLinkReservePort(const void* context,
                            const RogueSimLinkModelDescriptor* expectedModel,
                            uint16_t requestedPort,
                            RogueSimLinkReport report);

/**
 * Destroys a validated context and releases its model state and port pair.
 *
 * @return 1 on success, or 0 if the context or model type is invalid.
 */
int rogueSimLinkDestroy(const void* context,
                        const RogueSimLinkModelDescriptor* expectedModel,
                        RogueSimLinkReport report);

/** Returns the positive integer handle assigned to an instance, or 0 for NULL. */
int32_t rogueSimLinkGetHandle(const RogueSimLinkInstance* instance);

/**
 * Handle-based equivalent of rogueSimLinkGetData(), used by GHDL VHPIDIRECT.
 *
 * @return Model storage, or NULL if the handle or model type is invalid.
 */
void* rogueSimLinkGetDataByHandle(int32_t handle,
                                  const RogueSimLinkModelDescriptor* expectedModel,
                                  RogueSimLinkReport report);

/** Handle-based equivalent of rogueSimLinkReservePort(). */
int rogueSimLinkReservePortByHandle(int32_t handle,
                                    const RogueSimLinkModelDescriptor* expectedModel,
                                    uint16_t requestedPort,
                                    RogueSimLinkReport report);

/** Handle-based equivalent of rogueSimLinkDestroy(). */
int rogueSimLinkDestroyByHandle(int32_t handle,
                                const RogueSimLinkModelDescriptor* expectedModel,
                                RogueSimLinkReport report);

#endif
