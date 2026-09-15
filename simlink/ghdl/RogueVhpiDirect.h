//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef SURF_SIMLINK_GHDL_ROGUE_VHPI_DIRECT_H
#define SURF_SIMLINK_GHDL_ROGUE_VHPI_DIRECT_H

#include <stdint.h>

#define GHDL_STD_LOGIC_0 2
#define GHDL_STD_LOGIC_1 3

/**
 * Decodes a std_logic enum-ordinal byte into a two-state integer.
 *
 * Values other than the ordinal for forcing-one decode as zero. SimLink uses
 * this intentionally narrow interpretation because its foreign boundary is
 * two-state.
 *
 * @param[in] val GHDL std_logic enum ordinal.
 * @return 1 for forcing-one, otherwise 0.
 */
static inline unsigned int rogueVhpiDirectDecodeBit(unsigned char val) {
    return (val == GHDL_STD_LOGIC_1) ? 1 : 0;
}

/**
 * Decodes an MSB-first std_logic_vector into an unsigned integer.
 *
 * @param[in] val Enum-ordinal byte array; index zero is the vector MSB.
 * @param[in] width Vector width, which must fit in unsigned int.
 * @return Decoded two-state value.
 */
static inline unsigned int rogueVhpiDirectDecodeVector(const unsigned char* val, unsigned int width) {
    unsigned int result;
    unsigned int y;
    unsigned int bit;

    result = 0;
    for (y = 0; y < width; y++) {
        bit = (width - 1) - y;
        if (val[y] == GHDL_STD_LOGIC_1) result += (1U << bit);
    }
    return result;
}

/**
 * Encodes a two-state integer as a std_logic enum ordinal.
 *
 * @param[in] val Value to encode; zero becomes forcing-zero and every nonzero
 * value becomes forcing-one.
 * @return GHDL std_logic enum ordinal.
 */
static inline unsigned char rogueVhpiDirectEncodeBit(unsigned int val) {
    return (val == 0) ? GHDL_STD_LOGIC_0 : GHDL_STD_LOGIC_1;
}

/**
 * Encodes an unsigned integer into an MSB-first std_logic_vector.
 *
 * @param[in] val Two-state value to encode.
 * @param[out] ret Enum-ordinal output array; index zero receives the MSB.
 * @param[in] width Output vector width, which must fit in unsigned int.
 */
static inline void rogueVhpiDirectEncodeVector(unsigned int val, unsigned char* ret, unsigned int width) {
    unsigned int y;
    unsigned int bit;

    for (y = 0; y < width; y++) {
        bit    = (width - 1) - y;
        ret[y] = ((val >> bit) & 0x1) ? GHDL_STD_LOGIC_1 : GHDL_STD_LOGIC_0;
    }
}

/**
 * Decodes an arbitrary-width VHPIDIRECT vector into little-endian words.
 *
 * The ABI remains an MSB-first std_logic ordinal array while the output layout
 * matches SystemVerilog DPI and the shared Stream beat representation.
 *
 * @param[in] val Enum-ordinal input array; index zero is the vector MSB.
 * @param[out] words Output array of ceil(width/32) little-endian words.
 * @param[in] width Input vector width in bits.
 */
static inline void rogueVhpiDirectDecodeWords(const unsigned char* val, uint32_t* words, unsigned int width) {
    unsigned int y;
    unsigned int bit;
    unsigned int wordCount = (width + 31U) / 32U;

    for (y = 0; y < wordCount; y++) words[y] = 0;
    for (y = 0; y < width; y++) {
        bit = (width - 1U) - y;
        if (val[y] == GHDL_STD_LOGIC_1) words[bit / 32U] |= 1U << (bit % 32U);
    }
}

/**
 * Encodes little-endian words into an arbitrary-width VHPIDIRECT vector.
 *
 * @param[in] words Input array of ceil(width/32) little-endian words.
 * @param[out] ret Enum-ordinal output array; index zero receives the MSB.
 * @param[in] width Output vector width in bits.
 */
static inline void rogueVhpiDirectEncodeWords(const uint32_t* words, unsigned char* ret, unsigned int width) {
    unsigned int y;
    unsigned int bit;

    for (y = 0; y < width; y++) {
        bit    = (width - 1U) - y;
        ret[y] = ((words[bit / 32U] >> (bit % 32U)) & 0x1U) ? GHDL_STD_LOGIC_1 : GHDL_STD_LOGIC_0;
    }
}

#endif
