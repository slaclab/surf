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
// Public interface for the compiled Rogue-TCP AXI-Stream core. Each simulator
// adapter supplies the logging and fatal-error hooks below, owns a
// RogueTcpStreamData instance, and calls RogueTcpStreamStep once per rising
// edge after populating its input snapshot.
//////////////////////////////////////////////////////////////////////////////

#ifndef SURF_SIMLINK_SHARED_ROGUE_TCP_STREAM_CORE_H
#define SURF_SIMLINK_SHARED_ROGUE_TCP_STREAM_CORE_H

#include "RogueSimLinkInstance.h"
#include "RogueTcpStreamModel.h"

/** Stream model type token used for registry ownership checks. */
extern const RogueSimLinkModelDescriptor ROGUE_TCP_STREAM_MODEL;

/**
 * Writes an informational message through the active simulator adapter.
 * @param[in] message Null-terminated diagnostic text.
 */
void RogueTcpStreamLog(const char* message);

/**
 * Reports an unrecoverable model error through the active simulator.
 * @param[in] message Null-terminated fatal diagnostic text.
 */
void RogueTcpStreamFatal(const char* message);

/**
 * Releases the transport owned by a RogueTcpStreamData object.
 * @param[in,out] opaque Pointer to RogueTcpStreamData model storage.
 */
void RogueTcpStreamCleanup(void* opaque);

/**
 * Creates and starts the Stream transport after the base port is captured.
 * @param[in,out] data Stream model state.
 * @return 1 on success, otherwise 0 after a fatal diagnostic.
 */
int RogueTcpStreamStartTransport(RogueTcpStreamData* data);

/**
 * Encodes and sends the complete HDL-to-software frame accumulated in data.
 * @param[in,out] data Stream model state containing the accumulated frame.
 * @return 1 when sent, otherwise 0 after a fatal diagnostic.
 */
int RogueTcpStreamSend(RogueTcpStreamData* data);

/**
 * Dequeues and decodes one software-to-HDL frame when available.
 *
 * @param[in,out] data Stream model state that receives the decoded frame.
 * @return Payload size when received, 0 when the queue is empty, or -1 after a
 * fatal transport/protocol error.
 */
int RogueTcpStreamRecv(RogueTcpStreamData* data);

/**
 * Selects the simulator-facing AXI Stream beat width.
 *
 * @param[in,out] data Stream model state to configure.
 * @param[in] dataBytes Active payload bytes per simulation beat.
 * @return 1 for widths from 1 through ROGUE_TCP_STREAM_MAX_DATA_BYTES,
 * otherwise 0 after a fatal diagnostic.
 */
int RogueTcpStreamSetDataBytes(RogueTcpStreamData* data, uint32_t dataBytes);

/**
 * Advances the Stream model by one rising simulation-clock edge.
 *
 * The adapter must populate inSnap and the inbound beat-word arrays before the
 * call, then publish outState and the outbound beat-word arrays afterward.
 *
 * @param[in,out] data Stream model state to advance.
 */
void RogueTcpStreamStep(RogueTcpStreamData* data);

#endif
