//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef SURF_SIMLINK_GHDL_ROGUE_SIDE_BAND_H
#define SURF_SIMLINK_GHDL_ROGUE_SIDE_BAND_H

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "RogueSideBandCore.h"

/**
 * Compatibility reporting seam used by RogueVhpiDirectRegistry.h.
 *
 * The shared SideBand core uses the explicit RogueSideBandLog() and
 * RogueSideBandFatal() hooks instead.
 */
#define vhpi_printf(...) printf(__VA_ARGS__)
#define vhpi_assert(msg, sev)           \
    do {                                \
        fprintf(stderr, "%s\n", (msg)); \
        abort();                        \
    } while (0)

/**
 * Creates one GHDL SideBand model instance.
 *
 * @return Positive process-wide handle, or 0 after a fatal allocation error.
 */
int32_t rogueSideBandCreate(void);

/**
 * Destroys one GHDL SideBand model instance.
 *
 * @param[in] handle Handle returned by rogueSideBandCreate().
 */
void rogueSideBandDestroy(int32_t handle);

/**
 * Advances one SideBand instance on a rising simulation-clock edge.
 *
 * VHPIDIRECT represents each std_logic value as an enum-ordinal byte and each
 * vector as an MSB-first byte array.
 *
 * @param[in] handle Instance handle.
 * @param[in] clkRst Reset value encoded as a std_logic ordinal.
 * @param[in] portNum Base TCP port encoded as a 16-bit std_logic_vector.
 * @param[in] txOpCode HDL-originated opcode.
 * @param[in] txOpCodeEn Opcode-valid qualifier.
 * @param[in] txRemData HDL-originated remote-data value.
 */
void rogueSideBandUpdate(int32_t handle,
                         unsigned char clkRst,
                         unsigned char* portNum,
                         unsigned char* txOpCode,
                         unsigned char txOpCodeEn,
                         unsigned char* txRemData);

/** Writes the current received opcode into an eight-bit VHPIDIRECT vector. */
void rogueSideBandGetRxOpCode(unsigned char* ret, int32_t handle);

/** Returns the received-opcode qualifier as a std_logic ordinal. */
unsigned char rogueSideBandGetRxOpCodeEn(int32_t handle);

/** Writes the current received remote data into an eight-bit vector. */
void rogueSideBandGetRxRemData(unsigned char* ret, int32_t handle);

#endif
