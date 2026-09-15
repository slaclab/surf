//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef SURF_SIMLINK_GHDL_ROGUE_TCP_STREAM_H
#define SURF_SIMLINK_GHDL_ROGUE_TCP_STREAM_H

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "RogueTcpStreamCore.h"

/**
 * Compatibility reporting seam used by RogueVhpiDirectRegistry.h.
 *
 * The shared Stream core uses the explicit RogueTcpStreamLog() and
 * RogueTcpStreamFatal() hooks instead.
 */
#define vhpi_printf(...) printf(__VA_ARGS__)
#define vhpi_assert(msg, sev)           \
    do {                                \
        fprintf(stderr, "%s\n", (msg)); \
        abort();                        \
    } while (0)

/**
 * Creates one GHDL Stream model instance.
 *
 * @return Positive process-wide handle, or 0 after a fatal allocation error.
 */
int32_t rogueTcpStreamCreate(void);

/** Destroys the Stream instance identified by @p handle. */
void rogueTcpStreamDestroy(int32_t handle);

/**
 * Samples Stream inputs and advances one instance on a rising clock edge.
 *
 * @param[in] handle Instance handle.
 * @param[in] dataBytes Configured AXI Stream data width in bytes.
 * @param[in] clkRst Reset value encoded as a std_logic ordinal.
 * @param[in] portNum Base TCP port encoded as a 16-bit vector.
 * @param[in] ssi Enables SSI framing semantics.
 * @param[in] obReady Ready input for software-to-HDL traffic.
 * @param[in] ibValid Valid input for HDL-to-software traffic.
 * @param[in] ibData HDL-to-software payload vector.
 * @param[in] ibUser HDL-to-software user vector.
 * @param[in] ibKeep HDL-to-software byte-valid vector.
 * @param[in] ibLast HDL-to-software frame boundary.
 */
void rogueTcpStreamUpdate(int32_t handle,
                          int32_t dataBytes,
                          unsigned char clkRst,
                          unsigned char* portNum,
                          unsigned char ssi,
                          unsigned char obReady,
                          unsigned char ibValid,
                          unsigned char* ibData,
                          unsigned char* ibUser,
                          unsigned char* ibKeep,
                          unsigned char ibLast);

/** @name AXI Stream output accessors
 * Vector getters write MSB-first std_logic ordinal arrays; scalar getters
 * return one std_logic ordinal.
 * @{ */
unsigned char rogueTcpStreamGetObValid(int32_t handle);
unsigned char rogueTcpStreamGetObLast(int32_t handle);
unsigned char rogueTcpStreamGetIbReady(int32_t handle);
void rogueTcpStreamGetObData(unsigned char* ret, int32_t handle);
void rogueTcpStreamGetObUser(unsigned char* ret, int32_t handle);
void rogueTcpStreamGetObKeep(unsigned char* ret, int32_t handle);
/** @} */

#endif
