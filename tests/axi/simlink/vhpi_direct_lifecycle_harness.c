//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
//
// Test methodology:
// - Link directly against all three GHDL VHPIDIRECT model libraries.
// - For each model, create and bind an instance, destroy it, then create and
//   bind a replacement on the same endpoint pair before destroying it too.
// - Run this executable under Valgrind so only native model/library ownership,
//   rather than the Python interpreter, contributes to the leak report.
//////////////////////////////////////////////////////////////////////////////

#include <stdint.h>
#include <stdio.h>

#define STD_LOGIC_0_C 2
#define STD_LOGIC_1_C 3

int32_t rogueTcpStreamCreate(void);
void rogueTcpStreamDestroy(int32_t handle);
void rogueTcpStreamUpdate(int32_t handle, unsigned char clkRst,
                          unsigned char *portNum, unsigned char ssi,
                          unsigned char obReady, unsigned char ibValid,
                          unsigned char *ibDataLow, unsigned char *ibDataHigh,
                          unsigned char *ibUserLow, unsigned char *ibUserHigh,
                          unsigned char *ibKeep, unsigned char ibLast);

int32_t rogueTcpMemoryCreate(void);
void rogueTcpMemoryDestroy(int32_t handle);
void rogueTcpMemoryUpdate(int32_t handle, unsigned char clkRst,
                          unsigned char *portNum, unsigned char arready,
                          unsigned char *rdata, unsigned char *rresp,
                          unsigned char rvalid, unsigned char awready,
                          unsigned char wready, unsigned char *bresp,
                          unsigned char bvalid);

int32_t rogueSideBandCreate(void);
void rogueSideBandDestroy(int32_t handle);
void rogueSideBandUpdate(int32_t handle, unsigned char clkRst,
                         unsigned char *portNum, unsigned char *txOpCode,
                         unsigned char txOpCodeEn,
                         unsigned char *txRemData);

static void encodeVector(uint32_t value, unsigned char *result,
                         uint32_t width) {
    uint32_t index;
    uint32_t bit;

    for (index = 0; index < width; index++) {
        bit = (width - 1) - index;
        result[index] = ((value >> bit) & 1U) ?
                        STD_LOGIC_1_C : STD_LOGIC_0_C;
    }
}

static int exerciseStream(uint16_t port) {
    unsigned char portNum[16];
    unsigned char zero32[32];
    unsigned char zero8[8];
    int32_t first;
    int32_t second;

    encodeVector(port, portNum, 16);
    encodeVector(0, zero32, 32);
    encodeVector(0, zero8, 8);

    first = rogueTcpStreamCreate();
    if (first <= 0) return 1;
    rogueTcpStreamUpdate(first, STD_LOGIC_0_C, portNum, STD_LOGIC_0_C,
                         STD_LOGIC_0_C, STD_LOGIC_0_C, zero32, zero32,
                         zero32, zero32, zero8, STD_LOGIC_0_C);
    rogueTcpStreamDestroy(first);

    second = rogueTcpStreamCreate();
    if (second <= 0 || second == first) return 1;
    rogueTcpStreamUpdate(second, STD_LOGIC_0_C, portNum, STD_LOGIC_0_C,
                         STD_LOGIC_0_C, STD_LOGIC_0_C, zero32, zero32,
                         zero32, zero32, zero8, STD_LOGIC_0_C);
    rogueTcpStreamDestroy(second);
    return 0;
}

static int exerciseMemory(uint16_t port) {
    unsigned char portNum[16];
    unsigned char zero32[32];
    unsigned char zero2[2];
    int32_t first;
    int32_t second;

    encodeVector(port, portNum, 16);
    encodeVector(0, zero32, 32);
    encodeVector(0, zero2, 2);

    first = rogueTcpMemoryCreate();
    if (first <= 0) return 1;
    rogueTcpMemoryUpdate(first, STD_LOGIC_0_C, portNum, STD_LOGIC_0_C,
                         zero32, zero2, STD_LOGIC_0_C, STD_LOGIC_0_C,
                         STD_LOGIC_0_C, zero2, STD_LOGIC_0_C);
    rogueTcpMemoryDestroy(first);

    second = rogueTcpMemoryCreate();
    if (second <= 0 || second == first) return 1;
    rogueTcpMemoryUpdate(second, STD_LOGIC_0_C, portNum, STD_LOGIC_0_C,
                         zero32, zero2, STD_LOGIC_0_C, STD_LOGIC_0_C,
                         STD_LOGIC_0_C, zero2, STD_LOGIC_0_C);
    rogueTcpMemoryDestroy(second);
    return 0;
}

static int exerciseSideBand(uint16_t port) {
    unsigned char portNum[16];
    unsigned char zero8[8];
    int32_t first;
    int32_t second;

    encodeVector(port, portNum, 16);
    encodeVector(0, zero8, 8);

    first = rogueSideBandCreate();
    if (first <= 0) return 1;
    rogueSideBandUpdate(first, STD_LOGIC_0_C, portNum, zero8,
                        STD_LOGIC_0_C, zero8);
    rogueSideBandDestroy(first);

    second = rogueSideBandCreate();
    if (second <= 0 || second == first) return 1;
    rogueSideBandUpdate(second, STD_LOGIC_0_C, portNum, zero8,
                        STD_LOGIC_0_C, zero8);
    rogueSideBandDestroy(second);
    return 0;
}

int main(void) {
    if (exerciseStream(9670) != 0) {
        fprintf(stderr, "Stream lifecycle exercise failed\n");
        return 1;
    }
    if (exerciseMemory(9672) != 0) {
        fprintf(stderr, "Memory lifecycle exercise failed\n");
        return 1;
    }
    if (exerciseSideBand(9674) != 0) {
        fprintf(stderr, "SideBand lifecycle exercise failed\n");
        return 1;
    }
    return 0;
}
