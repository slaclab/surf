//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef SURF_SIMLINK_XSIM_ROGUE_TCP_STREAM_H
#define SURF_SIMLINK_XSIM_ROGUE_TCP_STREAM_H

#include "RogueTcpStreamCore.h"
#include "svdpi.h"

/** Creates one AXI Stream model context for a SystemVerilog DPI leaf. */
void* rogueTcpStreamCreate(void);

/** Destroys a Stream model context created by rogueTcpStreamCreate(). */
void rogueTcpStreamDestroy(void* context);

/**
 * Samples Stream inputs and advances one model on a rising clock edge.
 *
 * Packed vectors use DPI's little-endian svBitVecVal word layout.
 *
 * @param[in] context Per-leaf DPI context.
 * @param[in] dataBytes Configured Stream data width in bytes.
 * @param[in] reset Active-high reset.
 * @param[in] portNum Base TCP port; only the low 16 bits are used.
 * @param[in] ssi Enables SSI framing semantics.
 * @param[in] obReady Ready input for software-to-HDL traffic.
 * @param[out] obValid Valid output for software-to-HDL traffic.
 * @param[out] obData Software-to-HDL payload vector.
 * @param[out] obUser Software-to-HDL user vector.
 * @param[out] obKeep Software-to-HDL byte-valid vector.
 * @param[out] obLast Software-to-HDL frame boundary.
 * @param[in] ibValid Valid input for HDL-to-software traffic.
 * @param[out] ibReady Ready output for HDL-to-software traffic.
 * @param[in] ibData HDL-to-software payload vector.
 * @param[in] ibUser HDL-to-software user vector.
 * @param[in] ibKeep HDL-to-software byte-valid vector.
 * @param[in] ibLast HDL-to-software frame boundary.
 * @return 1 on success, or 0 after a width/context/port validation failure.
 */
int rogueTcpStreamUpdate(void* context,
                         int dataBytes,
                         svBit reset,
                         const svBitVecVal* portNum,
                         svBit ssi,
                         svBit obReady,
                         svBit* obValid,
                         svBitVecVal* obData,
                         svBitVecVal* obUser,
                         svBitVecVal* obKeep,
                         svBit* obLast,
                         svBit ibValid,
                         svBit* ibReady,
                         const svBitVecVal* ibData,
                         const svBitVecVal* ibUser,
                         const svBitVecVal* ibKeep,
                         svBit ibLast);

#endif
