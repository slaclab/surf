//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef SURF_SIMLINK_XSIM_ROGUE_SIDE_BAND_H
#define SURF_SIMLINK_XSIM_ROGUE_SIDE_BAND_H

#include "RogueSideBandCore.h"
#include "svdpi.h"

/** Creates one SideBand model context for a SystemVerilog DPI leaf. */
void* rogueSideBandCreate(void);

/** Destroys a SideBand model context created by rogueSideBandCreate(). */
void rogueSideBandDestroy(void* context);

/**
 * Advances one SideBand model on a rising simulation-clock edge.
 *
 * @param[in] context Per-leaf DPI context.
 * @param[in] reset Active-high reset.
 * @param[in] portNum Base TCP port; only the low 16 bits are used.
 * @param[in] txOpCode HDL-originated opcode.
 * @param[in] txOpCodeEn Opcode-valid qualifier.
 * @param[in] txRemData HDL-originated remote-data value.
 * @param[out] rxOpCode Software-originated opcode.
 * @param[out] rxOpCodeEn Received-opcode qualifier.
 * @param[out] rxRemData Software-originated remote-data value.
 * @return 1 on success, or 0 after a context/port validation failure.
 */
int rogueSideBandUpdate(void* context,
                        svBit reset,
                        const svBitVecVal* portNum,
                        const svBitVecVal* txOpCode,
                        svBit txOpCodeEn,
                        const svBitVecVal* txRemData,
                        svBitVecVal* rxOpCode,
                        svBit* rxOpCodeEn,
                        svBitVecVal* rxRemData);

#endif
