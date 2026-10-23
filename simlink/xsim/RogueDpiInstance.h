//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef ROGUE_DPI_INSTANCE_H
#define ROGUE_DPI_INSTANCE_H

#include "RogueSimLinkInstance.h"

/** xsim-facing alias for a model cleanup callback. */
typedef RogueSimLinkCleanup RogueDpiCleanup;

/**
 * Creates one zero-initialized model instance for an SV DPI leaf.
 *
 * @param[in] model Static model descriptor stored in the instance.
 * @param[in] dataSize Number of bytes in the model state.
 * @param[in] cleanup Optional model-specific cleanup callback.
 * @return Opaque chandle-compatible context, or NULL on allocation failure.
 */
void* rogueDpiCreate(const RogueSimLinkModelDescriptor* model, size_t dataSize, RogueDpiCleanup cleanup);

/**
 * Validates a DPI context and returns its model state.
 *
 * @param[in] context Context returned by rogueDpiCreate().
 * @param[in] expectedModel Model descriptor required by the caller.
 * @return Model state, or NULL after reporting a validation failure.
 */
void* rogueDpiGetData(const void* context, const RogueSimLinkModelDescriptor* expectedModel);

/**
 * Claims an immutable adjacent TCP port pair for a DPI context.
 *
 * @param[in] context Context returned by rogueDpiCreate().
 * @param[in] expectedModel Model descriptor required by the caller.
 * @param[in] requestedPort Base port of the adjacent pair.
 * @return 1 on success, otherwise 0 after reporting the reason.
 */
int rogueDpiReservePort(const void* context, const RogueSimLinkModelDescriptor* expectedModel, uint16_t requestedPort);

/**
 * Destroys a validated DPI context.
 *
 * @return 1 on success, otherwise 0 after reporting a validation failure.
 */
int rogueDpiDestroy(const void* context, const RogueSimLinkModelDescriptor* expectedModel);

#endif
