//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef SURF_SIMLINK_XSIM_ROGUE_TCP_MEMORY_H
#define SURF_SIMLINK_XSIM_ROGUE_TCP_MEMORY_H

#include "RogueTcpMemoryCore.h"
#include "svdpi.h"

/** Creates one AXI-Lite Memory model context for an SV DPI leaf. */
void* rogueTcpMemoryCreate(void);

/** Destroys a Memory model context created by rogueTcpMemoryCreate(). */
void rogueTcpMemoryDestroy(void* context);

/**
 * Samples AXI-Lite response inputs and advances one Memory model edge.
 *
 * @param[in] context Per-leaf DPI context.
 * @param[in] reset Active-high reset.
 * @param[in] portNum Base TCP port; only the low 16 bits are used.
 * @param[out] araddr Read-address output.
 * @param[out] arprot Read-protection output.
 * @param[out] arvalid Read-address valid output.
 * @param[out] rready Read-data ready output.
 * @param[in] arready Read-address ready input.
 * @param[in] rdata Read-data input.
 * @param[in] rresp Read-response input.
 * @param[in] rvalid Read-data valid input.
 * @param[out] awaddr Write-address output.
 * @param[out] awprot Write-protection output.
 * @param[out] awvalid Write-address valid output.
 * @param[out] wdata Write-data output.
 * @param[out] wstrb Write-strobe output.
 * @param[out] wvalid Write-data valid output.
 * @param[out] bready Write-response ready output.
 * @param[in] awready Write-address ready input.
 * @param[in] wready Write-data ready input.
 * @param[in] bresp Write-response input.
 * @param[in] bvalid Write-response valid input.
 * @return 1 on success, or 0 after a context/port validation failure.
 */
int rogueTcpMemoryUpdate(void* context,
                         svBit reset,
                         const svBitVecVal* portNum,
                         svBitVecVal* araddr,
                         svBitVecVal* arprot,
                         svBit* arvalid,
                         svBit* rready,
                         svBit arready,
                         const svBitVecVal* rdata,
                         const svBitVecVal* rresp,
                         svBit rvalid,
                         svBitVecVal* awaddr,
                         svBitVecVal* awprot,
                         svBit* awvalid,
                         svBitVecVal* wdata,
                         svBitVecVal* wstrb,
                         svBit* wvalid,
                         svBit* bready,
                         svBit awready,
                         svBit wready,
                         const svBitVecVal* bresp,
                         svBit bvalid);

#endif
