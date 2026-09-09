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
// Test-only standalone driver for RogueTcpMemoryCore.c's receive path. Links
// the GHDL adapter and shared core directly (no VHDL/VHPIDIRECT/AXI machinery)
// so fatal request-validation cases run in an isolated process. For accepted
// reads, a memory-error detector can inspect data->data immediately after
// Recv() returns, before AXI-Lite supplies the requested value.
//
// Not part of the shipped .so and not added to simlink/ghdl/Makefile.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "RogueTcpMemory.h"

int main(int argc, char **argv) {
    RogueTcpMemoryData data;
    int got;
    int i;
    uint32_t x;

    if (argc < 2) {
        fprintf(stderr, "usage: %s <port>\n", argv[0]);
        return 2;
    }

    memset(&data, 0, sizeof(data));
    data.port = (uint16_t)atoi(argv[1]);
    RogueTcpMemoryStartTransport(&data);

    got = 0;
    for (i = 0; i < 500 && !got; i++) {
        got = RogueTcpMemoryRecv(&data);
        usleep(10000);
    }

    if (!got) {
        fprintf(stderr, "uninit_read_recv_harness: no request received\n");
        RogueTcpMemoryCleanup(&data);
        return 2;
    }

    // Print the bytes RogueTcpMemoryRecv() placed in data->data. Valgrind
    // verifies that every byte is initialized at this boundary.
    for (x = 0; x < data.size; x++) printf("%02x", data.data[x]);
    printf("\n");

    RogueTcpMemoryCleanup(&data);
    return 0;
}
