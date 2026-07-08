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
// VHPI backend for the Rogue-TCP AXI-Lite memory model. The ZMQ transport
// (RogueTcpMemoryRestart/Send/Recv) and the transaction FSM (RogueTcpMemoryStep)
// live in the shared RogueTcpMemoryCore.h, included by both this backend and
// the GHDL VHPIDIRECT backend. This file provides only the VHPI-specific
// plumbing: RogueTcpMemoryInit (port tables + VhpiGeneric registration) and
// RogueTcpMemoryUpdate, the value-change callback that does clock-edge
// detection and bridges portData->intValue to/from the shared FSM's snapshot.
//////////////////////////////////////////////////////////////////////////////

#include <vhpi_user.h>
#include <stdlib.h>
#include <time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/mman.h>
#include <zmq.h>

#include "VhpiGeneric.h"
#include "RogueTcpMemory.h"
#include "RogueTcpMemoryCore.h"

// Init function
void RogueTcpMemoryInit(vhpiHandleT compInst) {
    // Create new port data structure
    portDataT             *portData  = (portDataT *)             malloc(sizeof(portDataT));
    RogueTcpMemoryData *data      = (RogueTcpMemoryData *) malloc(sizeof(RogueTcpMemoryData));

    // Get port count
    portData->portCount = PORT_COUNT;

    // Set port directions
    portData->portDir[s_clock]      = vhpiIn;
    portData->portDir[s_reset]      = vhpiIn;
    portData->portDir[s_port]       = vhpiIn;

    portData->portDir[s_araddr]     = vhpiOut;
    portData->portDir[s_arprot]     = vhpiOut;
    portData->portDir[s_arvalid]    = vhpiOut;
    portData->portDir[s_rready]     = vhpiOut;

    portData->portDir[s_arready]    = vhpiIn;
    portData->portDir[s_rdata]      = vhpiIn;
    portData->portDir[s_rresp]      = vhpiIn;
    portData->portDir[s_rvalid]     = vhpiIn;

    portData->portDir[s_awaddr]     = vhpiOut;
    portData->portDir[s_awprot]     = vhpiOut;
    portData->portDir[s_awvalid]    = vhpiOut;
    portData->portDir[s_wdata]      = vhpiOut;
    portData->portDir[s_wstrb]      = vhpiOut;
    portData->portDir[s_wvalid]     = vhpiOut;
    portData->portDir[s_bready]     = vhpiOut;

    portData->portDir[s_awready]    = vhpiIn;
    portData->portDir[s_wready]     = vhpiIn;
    portData->portDir[s_bresp]      = vhpiIn;
    portData->portDir[s_bvalid]     = vhpiIn;

    // Set port widths
    portData->portWidth[s_clock]    = 1;
    portData->portWidth[s_reset]    = 1;
    portData->portWidth[s_port]     = 16;

    portData->portWidth[s_araddr]   = 32;
    portData->portWidth[s_arprot]   = 3;
    portData->portWidth[s_arvalid]  = 1;
    portData->portWidth[s_rready]   = 1;

    portData->portWidth[s_arready]  = 1;
    portData->portWidth[s_rdata]    = 32;
    portData->portWidth[s_rresp]    = 2;
    portData->portWidth[s_rvalid]   = 1;

    portData->portWidth[s_awaddr]   = 32;
    portData->portWidth[s_awprot]   = 3;
    portData->portWidth[s_awvalid]  = 1;
    portData->portWidth[s_wdata]    = 32;
    portData->portWidth[s_wstrb]    = 4;
    portData->portWidth[s_wvalid]   = 1;
    portData->portWidth[s_bready]   = 1;

    portData->portWidth[s_awready]  = 1;
    portData->portWidth[s_wready]   = 1;
    portData->portWidth[s_bresp]    = 2;
    portData->portWidth[s_bvalid]   = 1;

    // Create data structure to hold state
    portData->stateData = data;

    // State update function
    portData->stateUpdate = *RogueTcpMemoryUpdate;

    // Init
    memset(data, 0, sizeof(RogueTcpMemoryData));

    // Call generic Init
    VhpiGenericInit(compInst, portData);
}


// User function to update state based upon a signal change
void RogueTcpMemoryUpdate(void *userPtr) {
    portDataT          *portData = (portDataT*) userPtr;
    RogueTcpMemoryData *data     = (RogueTcpMemoryData*)(portData->stateData);
    uint32_t            i;

    // Detect clock edge
    if ( data->currClk != portData->intValue[s_clock] ) {
        data->currClk = portData->intValue[s_clock];

        // Rising edge
        if ( data->currClk ) {
            // Snapshot inputs, run the shared FSM step, then publish outputs.
            // Input and output port indices are disjoint, so the two copies
            // never touch the same signal.
            for (i=0; i < PORT_COUNT; i++)
                if ( portData->portDir[i] == vhpiIn ) data->inSnap[i] = portData->intValue[i];

            RogueTcpMemoryStep(data);

            for (i=0; i < PORT_COUNT; i++)
                if ( portData->portDir[i] == vhpiOut ) portData->intValue[i] = data->outState[i];
        }
    }
}
