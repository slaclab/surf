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
// Test-only standalone driver for both partial-beat directions in
// RogueTcpStreamStep(). The inbound case reaches exactly
// ROGUE_TCP_STREAM_MAX_FRAME with two kept lanes followed by six empty lanes.
// The outbound case starts on the final byte and requires every invalid output
// lane to remain zero rather than reading past the end of obData.

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "RogueTcpStream.h"

void RogueTcpStreamLog(const char *message) {
    fputs(message, stdout);
}

void RogueTcpStreamFatal(const char *message) {
    fprintf(stderr, "%s\n", message);
    fflush(stderr);
    _Exit(EXIT_FAILURE);
}

int main(void) {
    RogueTcpStreamData *data;

    data = (RogueTcpStreamData *)calloc(1, sizeof(RogueTcpStreamData));
    if (data == NULL) {
        fprintf(stderr, "stream_max_frame_harness: allocation failed\n");
        return 2;
    }

    // Skip ZMQ startup/polling so this harness exercises only inbound lane
    // compaction. Holding an output frame valid prevents the receive path from
    // polling the intentionally-null ZMQ socket.
    data->port    = 1;
    data->obSize  = 1;
    data->obValid = 1;
    data->ibSize  = ROGUE_TCP_STREAM_MAX_FRAME-2;

    data->inSnap[s_ibValid] = 1;
    data->ibDataWords[0]    = 0x44332211;
    data->ibUserWords[0]    = 0x0000BBAA;
    data->ibKeepWords[0]    = 0x03;

    RogueTcpStreamStep(data);

    if (data->ibSize != ROGUE_TCP_STREAM_MAX_FRAME) {
        fprintf(stderr, "stream_max_frame_harness: wrong size %u\n", data->ibSize);
        free(data);
        return 1;
    }
    if ( (data->ibData[ROGUE_TCP_STREAM_MAX_FRAME-2] != 0x11) ||
         (data->ibData[ROGUE_TCP_STREAM_MAX_FRAME-1] != 0x22) ||
         (data->ibLuser != 0xBB) ) {
        fprintf(stderr, "stream_max_frame_harness: lane compaction mismatch\n");
        free(data);
        return 1;
    }

    data->inSnap[s_ibValid] = 0;
    data->obData[ROGUE_TCP_STREAM_MAX_FRAME-1] = 0x5A;
    data->obSize  = ROGUE_TCP_STREAM_MAX_FRAME;
    data->obCount = ROGUE_TCP_STREAM_MAX_FRAME-1;
    data->obValid = 0;

    RogueTcpStreamStep(data);

    if ( (data->obDataWords[0] != 0x5A) ||
         (data->obDataWords[1] != 0) ||
         (data->obKeepWords[0] != 0x01) ||
         (data->outState[s_obLast] != 1) ||
         (data->outState[s_obValid] != 1) ) {
        fprintf(stderr, "stream_max_frame_harness: output tail mismatch\n");
        free(data);
        return 1;
    }

    free(data);
    return 0;
}
