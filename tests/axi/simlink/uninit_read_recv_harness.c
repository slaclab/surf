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
// Test-only standalone driver for RogueTcpMemory.c's RogueTcpMemoryRecv().
// Links the unmodified GHDL-fork C model directly (no VHDL/VHPIDIRECT/AXI
// machinery) so a memory-error detector can observe data->data immediately
// after Recv() returns -- the narrow window before any AXI-Lite read would
// overwrite a 4-frame read request's uninitialized data buffer.
//
// Not part of the shipped .so and not added to axi/simlink/ghdl/Makefile.

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
    RogueTcpMemoryRestart(&data);

    got = 0;
    for (i = 0; i < 500 && !got; i++) {
        got = RogueTcpMemoryRecv(&data);
        usleep(10000);
    }

    if (!got) {
        fprintf(stderr, "uninit_read_recv_harness: no request received\n");
        return 2;
    }

    // Print the bytes RogueTcpMemoryRecv() just placed in data->data. This
    // read/print is the observation window that makes the memcpy source's
    // uninitialized value visible to a memory-error detector.
    for (x = 0; x < data.size; x++) printf("%02x", data.data[x]);
    printf("\n");

    return 0;
}
