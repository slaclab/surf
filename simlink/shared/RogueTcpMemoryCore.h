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
// Public interface for the compiled Rogue-TCP AXI-Lite memory core. Each
// simulator adapter supplies the logging and fatal-error hooks below, owns a
// RogueTcpMemoryData instance, and calls RogueTcpMemoryStep once per rising
// edge after populating its input snapshot.
//////////////////////////////////////////////////////////////////////////////

#ifndef SURF_SIMLINK_SHARED_ROGUE_TCP_MEMORY_CORE_H
#define SURF_SIMLINK_SHARED_ROGUE_TCP_MEMORY_CORE_H

#include "RogueSimLinkInstance.h"
#include "RogueTcpMemoryModel.h"

/** Memory model type token used for registry ownership checks. */
extern const RogueSimLinkModelDescriptor ROGUE_TCP_MEMORY_MODEL;

/**
 * Writes an informational message through the active simulator adapter.
 * @param[in] message Null-terminated diagnostic text.
 */
void RogueTcpMemoryLog(const char* message);

/**
 * Reports an unrecoverable model error through the active simulator.
 * @param[in] message Null-terminated fatal diagnostic text.
 */
void RogueTcpMemoryFatal(const char* message);

/**
 * Releases the transport owned by a RogueTcpMemoryData object.
 * @param[in,out] opaque Pointer to RogueTcpMemoryData model storage.
 */
void RogueTcpMemoryCleanup(void* opaque);

/**
 * Creates and starts the Memory transport after the base port is captured.
 * @param[in,out] data Memory model state.
 * @return 1 on success, otherwise 0 after a fatal diagnostic.
 */
int RogueTcpMemoryStartTransport(RogueTcpMemoryData* data);

/**
 * Encodes and sends the completion for the current Memory transaction.
 * @param[in,out] data Memory model state containing the completion.
 * @return 1 when sent, otherwise 0 after a fatal diagnostic.
 */
int RogueTcpMemorySend(RogueTcpMemoryData* data);

/**
 * Dequeues, validates, and installs one Memory request when available.
 *
 * @param[in,out] data Memory model state that receives the request.
 * @return Transaction size when accepted, 0 when no request is ready, or -1
 * after a fatal transport/protocol error.
 */
int RogueTcpMemoryRecv(RogueTcpMemoryData* data);

/**
 * Advances the AXI-Lite transaction model by one rising simulation-clock edge.
 *
 * The adapter must populate inSnap before the call and publish outState after
 * it returns.
 *
 * @param[in,out] data Memory model state to advance.
 */
void RogueTcpMemoryStep(RogueTcpMemoryData* data);

#endif
