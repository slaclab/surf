//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef SURF_SIMLINK_GHDL_ROGUE_TCP_MEMORY_H
#define SURF_SIMLINK_GHDL_ROGUE_TCP_MEMORY_H

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "RogueTcpMemoryCore.h"

/**
 * Compatibility reporting seam used by RogueVhpiDirectRegistry.h.
 *
 * The shared Memory core uses the explicit RogueTcpMemoryLog() and
 * RogueTcpMemoryFatal() hooks instead.
 */
#define vhpi_printf(...) printf(__VA_ARGS__)
#define vhpi_assert(msg, sev)           \
    do {                                \
        fprintf(stderr, "%s\n", (msg)); \
        abort();                        \
    } while (0)

/**
 * Creates one GHDL Memory model instance.
 *
 * @return Positive process-wide handle, or 0 after a fatal allocation error.
 */
int32_t rogueTcpMemoryCreate(void);

/** Destroys the Memory instance identified by @p handle. */
void rogueTcpMemoryDestroy(int32_t handle);

/**
 * Samples AXI-Lite response inputs and advances one Memory instance.
 *
 * Scalar and vector arguments use GHDL's std_logic enum-ordinal
 * representation. Output channels are read through the getter functions
 * below after this call returns.
 *
 * @param[in] handle Instance handle.
 * @param[in] clkRst Reset value.
 * @param[in] portNum Base TCP port.
 * @param[in] arready AXI-Lite read-address ready.
 * @param[in] rdata AXI-Lite read data.
 * @param[in] rresp AXI-Lite read response.
 * @param[in] rvalid AXI-Lite read-data valid.
 * @param[in] awready AXI-Lite write-address ready.
 * @param[in] wready AXI-Lite write-data ready.
 * @param[in] bresp AXI-Lite write response.
 * @param[in] bvalid AXI-Lite write-response valid.
 */
void rogueTcpMemoryUpdate(int32_t handle,
                          unsigned char clkRst,
                          unsigned char* portNum,
                          unsigned char arready,
                          unsigned char* rdata,
                          unsigned char* rresp,
                          unsigned char rvalid,
                          unsigned char awready,
                          unsigned char wready,
                          unsigned char* bresp,
                          unsigned char bvalid);

/** @name AXI-Lite output accessors
 * Each vector getter writes an MSB-first std_logic ordinal array; each scalar
 * getter returns one std_logic ordinal.
 * @{ */
void rogueTcpMemoryGetAraddr(unsigned char* ret, int32_t handle);
void rogueTcpMemoryGetArprot(unsigned char* ret, int32_t handle);
unsigned char rogueTcpMemoryGetArvalid(int32_t handle);
unsigned char rogueTcpMemoryGetRready(int32_t handle);
void rogueTcpMemoryGetAwaddr(unsigned char* ret, int32_t handle);
void rogueTcpMemoryGetAwprot(unsigned char* ret, int32_t handle);
unsigned char rogueTcpMemoryGetAwvalid(int32_t handle);
void rogueTcpMemoryGetWdata(unsigned char* ret, int32_t handle);
void rogueTcpMemoryGetWstrb(unsigned char* ret, int32_t handle);
unsigned char rogueTcpMemoryGetWvalid(int32_t handle);
unsigned char rogueTcpMemoryGetBready(int32_t handle);
/** @} */

#endif
