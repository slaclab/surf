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
// VHPI backend for the Rogue-TCP AXI-Stream model. The ZMQ transport
// (RogueTcpStreamRestart/Send/Recv) and the data-movement FSM
// (RogueTcpStreamStep) live in the shared RogueTcpStreamCore.h, included by
// both this backend and the GHDL VHPIDIRECT backend. This file provides only
// the VHPI-specific plumbing: RogueTcpStreamInit (port tables + VhpiGeneric
// registration) and RogueTcpStreamUpdate, the value-change callback that does
// clock-edge detection and bridges portData->intValue to/from the shared
// FSM's snapshot.
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
#include <errno.h>

#include "VhpiGeneric.h"
#include "RogueTcpStream.h"
#include "RogueTcpStreamCore.h"

// Init function
void RogueTcpStreamInit(vhpiHandleT compInst) {
    // Create new port data structure
    portDataT             *portData  = (portDataT *)             malloc(sizeof(portDataT));
    RogueTcpStreamData *data      = (RogueTcpStreamData *) malloc(sizeof(RogueTcpStreamData));

    // Get port count
    portData->portCount = PORT_COUNT;

    // Set port directions
    portData->portDir[s_clock]      = vhpiIn;
    portData->portDir[s_reset]      = vhpiIn;
    portData->portDir[s_port]       = vhpiIn;
    portData->portDir[s_ssi]        = vhpiIn;

    portData->portDir[s_obValid]    = vhpiOut;
    portData->portDir[s_obReady]    = vhpiIn;
    portData->portDir[s_obDataLow]  = vhpiOut;
    portData->portDir[s_obDataHigh] = vhpiOut;
    portData->portDir[s_obUserLow]  = vhpiOut;
    portData->portDir[s_obUserHigh] = vhpiOut;
    portData->portDir[s_obKeep]     = vhpiOut;
    portData->portDir[s_obLast]     = vhpiOut;

    portData->portDir[s_ibValid]    = vhpiIn;
    portData->portDir[s_ibReady]    = vhpiOut;
    portData->portDir[s_ibDataLow]  = vhpiIn;
    portData->portDir[s_ibDataHigh] = vhpiIn;
    portData->portDir[s_ibUserLow]  = vhpiIn;
    portData->portDir[s_ibUserHigh] = vhpiIn;
    portData->portDir[s_ibKeep]     = vhpiIn;
    portData->portDir[s_ibLast]     = vhpiIn;

    // Set port widths
    portData->portWidth[s_clock]      = 1;
    portData->portWidth[s_reset]      = 1;
    portData->portWidth[s_port]       = 16;
    portData->portWidth[s_ssi]        = 1;

    portData->portWidth[s_obValid]    = 1;
    portData->portWidth[s_obReady]    = 1;
    portData->portWidth[s_obDataLow]  = 32;
    portData->portWidth[s_obDataHigh] = 32;
    portData->portWidth[s_obUserLow]  = 32;
    portData->portWidth[s_obUserHigh] = 32;
    portData->portWidth[s_obKeep]     = 8;
    portData->portWidth[s_obLast]     = 1;

    portData->portWidth[s_ibValid]    = 1;
    portData->portWidth[s_ibReady]    = 1;
    portData->portWidth[s_ibDataLow]  = 32;
    portData->portWidth[s_ibDataHigh] = 32;
    portData->portWidth[s_ibUserLow]  = 32;
    portData->portWidth[s_ibUserHigh] = 32;
    portData->portWidth[s_ibKeep]     = 8;
    portData->portWidth[s_ibLast]     = 1;

    // Create data structure to hold state
    portData->stateData = data;

    // State update function
    portData->stateUpdate = *RogueTcpStreamUpdate;

    // Init
    memset(data, 0, sizeof(RogueTcpStreamData));
    time(&(data->ltime));

    // Call generic Init
    VhpiGenericInit(compInst, portData);
}

// User function to update state based upon a signal change
void RogueTcpStreamUpdate(void *userPtr) {
    portDataT          *portData = (portDataT*) userPtr;
    RogueTcpStreamData *data     = (RogueTcpStreamData*)(portData->stateData);
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

            RogueTcpStreamStep(data);

            for (i=0; i < PORT_COUNT; i++)
                if ( portData->portDir[i] == vhpiOut ) portData->intValue[i] = data->outState[i];
        }
    }
}
