//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef __ROGUE_VHPI_DIRECT_H__
#define __ROGUE_VHPI_DIRECT_H__

#define GHDL_STD_LOGIC_0_C 2
#define GHDL_STD_LOGIC_1_C 3

// Decode a std_logic scalar enum-ordinal byte into 0/1.
static inline unsigned int rogueVhpiDirectDecodeBit(unsigned char val) {
    return (val == GHDL_STD_LOGIC_1_C) ? 1 : 0;
}

// Decode a std_logic_vector enum-ordinal byte array, MSB-first (array index
// 0 is the vector's MSB), into an unsigned int.
static inline unsigned int rogueVhpiDirectDecodeVector(const unsigned char *val,
                                                       unsigned int width) {
    unsigned int result;
    unsigned int y;
    unsigned int bit;

    result = 0;
    for (y = 0; y < width; y++) {
        bit = (width - 1) - y;
        if (val[y] == GHDL_STD_LOGIC_1_C) result += (1U << bit);
    }
    return result;
}

// Encode 0/1 into a std_logic scalar enum-ordinal byte.
static inline unsigned char rogueVhpiDirectEncodeBit(unsigned int val) {
    return (val == 0) ? GHDL_STD_LOGIC_0_C : GHDL_STD_LOGIC_1_C;
}

// Encode an unsigned int into a std_logic_vector enum-ordinal byte array,
// MSB-first (array index 0 is the vector's MSB).
static inline void rogueVhpiDirectEncodeVector(unsigned int val,
                                               unsigned char *ret,
                                               unsigned int width) {
    unsigned int y;
    unsigned int bit;

    for (y = 0; y < width; y++) {
        bit = (width - 1) - y;
        ret[y] = ((val >> bit) & 0x1) ?
                 GHDL_STD_LOGIC_1_C : GHDL_STD_LOGIC_0_C;
    }
}

#endif
