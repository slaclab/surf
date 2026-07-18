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
// Test-only standalone driver for the AXI-to-ZMQ lane compaction in
// RogueTcpStreamStep(). Seeds ibSize just below MAX_FRAME, then presents two
// kept lanes followed by six unkept lanes. The valid payload reaches exactly
// MAX_FRAME; the trailing empty lanes must not touch the buffer or trip the
// overflow guard.

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "RogueTcpStream.h"
#include "RogueTcpStreamCore.h"

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
    data->ibSize  = MAX_FRAME-2;

    data->inSnap[s_ibValid]   = 1;
    data->inSnap[s_ibDataLow] = 0x44332211;
    data->inSnap[s_ibUserLow] = 0x0000BBAA;
    data->inSnap[s_ibKeep]    = 0x03;

    RogueTcpStreamStep(data);

    if (data->ibSize != MAX_FRAME) {
        fprintf(stderr, "stream_max_frame_harness: wrong size %u\n", data->ibSize);
        free(data);
        return 1;
    }
    if ( (data->ibData[MAX_FRAME-2] != 0x11) ||
         (data->ibData[MAX_FRAME-1] != 0x22) ||
         (data->ibLuser != 0xBB) ) {
        fprintf(stderr, "stream_max_frame_harness: lane compaction mismatch\n");
        free(data);
        return 1;
    }

    free(data);
    return 0;
}
