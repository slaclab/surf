//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef SURF_SIMLINK_VCS_ROGUE_TCP_MEMORY_H
#define SURF_SIMLINK_VCS_ROGUE_TCP_MEMORY_H

#include <vhpi_user.h>

#include "RogueTcpMemoryCore.h"

/**
 * Creates and registers a Memory adapter for one elaborated VHDL instance.
 *
 * @param[in] compInst VHPI handle for the elaborated component instance.
 */
void RogueTcpMemoryInit(vhpiHandleT compInst);

/**
 * Processes a Memory port-value change and advances on rising clock edges.
 *
 * @param[in,out] userPtr Adapter-owned portDataT callback context.
 */
void RogueTcpMemoryUpdate(void* userPtr);

#endif
