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
// VHPI backend for the Rogue side-band model. The ZMQ transport
// (RogueSideBandRestart/Send/Recv) and the opcode/remData FSM
// (RogueSideBandStep) live in the shared RogueSideBandCore.h, included by
// both this backend and the GHDL VHPIDIRECT backend. This file provides only
// the VHPI-specific plumbing: RogueSideBandInit (port tables + VhpiGeneric
// registration) and RogueSideBandUpdate, the value-change callback that does
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

#include "VhpiGeneric.h"
#include "RogueSideBand.h"
#include "RogueSideBandCore.h"

// Init function
void RogueSideBandInit(vhpiHandleT compInst) {
    // Create new port data structure
    portDataT         *portData  = (portDataT *)         malloc(sizeof(portDataT));
    RogueSideBandData *data      = (RogueSideBandData *) malloc(sizeof(RogueSideBandData));

    // Get port count
    portData->portCount = PORT_COUNT;

    // Set port directions
    portData->portDir[s_clock]      = vhpiIn;
    portData->portDir[s_reset]      = vhpiIn;
    portData->portDir[s_port]       = vhpiIn;

    portData->portDir[s_txOpCode]     = vhpiIn;
    portData->portDir[s_txOpCodeEn]   = vhpiIn;
    portData->portDir[s_txRemData]    = vhpiIn;

    portData->portDir[s_rxOpCode]     = vhpiOut;
    portData->portDir[s_rxOpCodeEn]   = vhpiOut;
    portData->portDir[s_rxRemData]    = vhpiOut;

    // Set port widths
    portData->portWidth[s_clock]      = 1;
    portData->portWidth[s_reset]      = 1;
    portData->portWidth[s_port]       = 16;

    portData->portWidth[s_txOpCode]     = 8;
    portData->portWidth[s_txOpCodeEn]   = 1;
    portData->portWidth[s_txRemData]    = 8;

    portData->portWidth[s_rxOpCode]     = 8;
    portData->portWidth[s_rxOpCodeEn]   = 1;
    portData->portWidth[s_rxRemData]    = 8;

    // Create data structure to hold state
    portData->stateData = data;

    // State update function
    portData->stateUpdate = *RogueSideBandUpdate;

    // Init
    memset(data, 0, sizeof(RogueSideBandData));

    // Call generic Init
    VhpiGenericInit(compInst, portData);
}

// User function to update state based upon a signal change
void RogueSideBandUpdate(void *userPtr) {
    portDataT         *portData = (portDataT*) userPtr;
    RogueSideBandData *data     = (RogueSideBandData*)(portData->stateData);
    uint32_t           i;

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

            RogueSideBandStep(data);

            for (i=0; i < PORT_COUNT; i++)
                if ( portData->portDir[i] == vhpiOut ) portData->intValue[i] = data->outState[i];
        }
    }
}
