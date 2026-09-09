//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef SURF_SIMLINK_VCS_ROGUE_TCP_STREAM_H
#define SURF_SIMLINK_VCS_ROGUE_TCP_STREAM_H

#include <vhpi_user.h>

#include "RogueTcpStreamCore.h"

/**
 * Creates and registers a Stream adapter for one elaborated VHDL instance.
 *
 * The elaborated vector widths are validated and captured before callbacks
 * can advance the shared Stream model.
 *
 * @param[in] compInst VHPI handle for the elaborated component instance.
 */
void RogueTcpStreamInit(vhpiHandleT compInst);

/**
 * Processes a Stream port-value change and advances on rising clock edges.
 *
 * @param[in,out] userPtr Adapter-owned portDataT callback context.
 */
void RogueTcpStreamUpdate(void* userPtr);

#endif
