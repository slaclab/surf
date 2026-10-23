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
// Public interface for the compiled Rogue side-band core. Each simulator
// adapter supplies the logging and fatal-error hooks below, owns a
// RogueSideBandData instance, and calls RogueSideBandStep once per rising edge
// after populating its input snapshot.
//////////////////////////////////////////////////////////////////////////////

#ifndef SURF_SIMLINK_SHARED_ROGUE_SIDE_BAND_CORE_H
#define SURF_SIMLINK_SHARED_ROGUE_SIDE_BAND_CORE_H

#include "RogueSideBandModel.h"
#include "RogueSimLinkInstance.h"

/** SideBand model type token used for registry ownership checks. */
extern const RogueSimLinkModelDescriptor ROGUE_SIDE_BAND_MODEL;

/**
 * Writes an informational message through the active simulator adapter.
 * @param[in] message Null-terminated diagnostic text.
 */
void RogueSideBandLog(const char* message);

/**
 * Reports an unrecoverable model error through the active simulator.
 * @param[in] message Null-terminated fatal diagnostic text.
 */
void RogueSideBandFatal(const char* message);

/**
 * Releases the transport owned by a RogueSideBandData object.
 * @param[in,out] opaque Pointer to RogueSideBandData model storage.
 */
void RogueSideBandCleanup(void* opaque);

/**
 * Creates and starts the SideBand transport after the base port is captured.
 * @param[in,out] data SideBand model state.
 * @return 1 on success, otherwise 0 after a fatal diagnostic.
 */
int RogueSideBandStartTransport(RogueSideBandData* data);

/**
 * Encodes and sends pending HDL-originated opcode/remote-data changes.
 * @param[in,out] data SideBand model state containing the pending changes.
 * @return 1 when sent, otherwise 0 after a fatal diagnostic.
 */
int RogueSideBandSend(RogueSideBandData* data);

/**
 * Dequeues and applies one software-originated SideBand message when available.
 *
 * @param[in,out] data SideBand model state that receives the message.
 * @return Four when a message is received, 0 when none is ready, or -1 after a
 * fatal transport/protocol error.
 */
int RogueSideBandRecv(RogueSideBandData* data);

/**
 * Advances the SideBand model by one rising simulation-clock edge.
 *
 * Received opcode-valid is emitted for exactly one call; received remote data
 * is retained until a later message changes it.
 *
 * @param[in,out] data SideBand model state to advance.
 */
void RogueSideBandStep(RogueSideBandData* data);

#endif
