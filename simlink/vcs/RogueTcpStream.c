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
// VHPI backend for the Rogue-TCP AXI-Stream model. The worker transport/codec
// and data-movement FSM live in the compiled shared RogueTcpStreamCore.c. This
// file provides the VHPI-specific plumbing: RogueTcpStreamInit (port table +
// VhpiGeneric registration) and RogueTcpStreamUpdate, the value-change
// callback that detects clock edges and bridges portData->intValue to/from the
// shared FSM's snapshot.
//////////////////////////////////////////////////////////////////////////////

#include "RogueTcpStream.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "RogueSimLinkInstance.h"
#include "VhpiGeneric.h"

typedef struct {
    // The common model owns protocol state; currClk is VHPI-only edge state.
    RogueTcpStreamData model;
    uint8_t currClk;
} RogueTcpStreamVhpiData;

// Zero widths are inferred at elaboration for the parameterized beat vectors.
static const VhpiPortSpec rogueTcpStreamPorts[ROGUE_TCP_STREAM_PORT_COUNT] = {
    [s_clock]   = {vhpiIn, 1},
    [s_reset]   = {vhpiIn, 1},
    [s_port]    = {vhpiIn, 16},
    [s_ssi]     = {vhpiIn, 1},
    [s_obValid] = {vhpiOut, 1},
    [s_obReady] = {vhpiIn, 1},
    [s_obData]  = {vhpiOut, 0},  // Infer parameterized width
    [s_obUser]  = {vhpiOut, 0},
    [s_obKeep]  = {vhpiOut, 0},
    [s_obLast]  = {vhpiOut, 1},
    [s_ibValid] = {vhpiIn, 1},
    [s_ibReady] = {vhpiOut, 1},
    [s_ibData]  = {vhpiIn, 0},
    [s_ibUser]  = {vhpiIn, 0},
    [s_ibKeep]  = {vhpiIn, 0},
    [s_ibLast]  = {vhpiIn, 1},
};

void RogueTcpStreamLog(const char* message) {
    vhpi_printf("%s", message);
}

void RogueTcpStreamFatal(const char* message) {
    // VCS declares vhpi_assert() as taking a non-const char*, so cast away the
    // qualifier. The message is only read by the simulator.
    vhpi_assert((char*) message, vhpiFatal);
}

// Bind one shared model instance to the elaborated, width-checked port set.
void RogueTcpStreamInit(vhpiHandleT compInst) {
    // VhpiGeneric owns the per-port handles/value buffers; the common instance
    // registry owns the embedded model and its transport.
    portDataT* portData            = VhpiGenericAlloc(sizeof(portDataT), "Stream port metadata");
    RogueSimLinkInstance* instance = rogueSimLinkCreate(&ROGUE_TCP_STREAM_MODEL,
                                                        sizeof(RogueTcpStreamVhpiData),
                                                        RogueTcpStreamCleanup,
                                                        RogueTcpStreamLog);
    RogueTcpStreamVhpiData* adapter;

    if (instance == NULL) {
        free(portData);
        RogueTcpStreamFatal("Failed to create VCS Stream instance");
        return;
    }
    portData->instance    = instance;
    portData->model       = &ROGUE_TCP_STREAM_MODEL;
    portData->report      = RogueTcpStreamLog;
    portData->stateUpdate = *RogueTcpStreamUpdate;
    VhpiGenericInit(compInst, portData, rogueTcpStreamPorts, ROGUE_TCP_STREAM_PORT_COUNT);
    adapter = rogueSimLinkGetData(instance, &ROGUE_TCP_STREAM_MODEL, RogueTcpStreamLog);
    if (adapter == NULL) return;

    // The shared core uses one lane count for both directions and for each
    // lane's data/user/keep representation.
    if ((portData->portWidth[s_obData] % 8) != 0 || portData->portWidth[s_obData] != portData->portWidth[s_ibData] ||
        portData->portWidth[s_obData] != portData->portWidth[s_obUser] ||
        portData->portWidth[s_obData] != portData->portWidth[s_ibUser] ||
        (portData->portWidth[s_obData] / 8) != portData->portWidth[s_obKeep] ||
        portData->portWidth[s_obKeep] != portData->portWidth[s_ibKeep]) {
        RogueTcpStreamFatal("Inconsistent VCS Stream vector widths");
        return;
    }
    if (!RogueTcpStreamSetDataBytes(&(adapter->model), portData->portWidth[s_obKeep])) return;
}

// Convert a clock callback into at most one shared-model rising-edge step.
void RogueTcpStreamUpdate(void* userPtr) {
    portDataT* portData             = (portDataT*)userPtr;
    RogueSimLinkInstance* instance  = portData->instance;
    RogueTcpStreamVhpiData* adapter = rogueSimLinkGetData(instance, &ROGUE_TCP_STREAM_MODEL, RogueTcpStreamLog);
    RogueTcpStreamData* data;
    uint32_t i;
    uint32_t dataWords;
    uint32_t keepWords;

    // A failed lookup reports through the log hook and returns NULL; do not
    // dereference it (data would resolve to NULL since model is the first
    // member). Match the xsim adapter, which guards the same case.
    if (adapter == NULL) return;
    data = &(adapter->model);

    // Detect clock edge
    if (adapter->currClk != portData->intValue[s_clock]) {
        adapter->currClk = portData->intValue[s_clock];

        // Rising edge
        if (adapter->currClk) {
            // Reserve only after reset so an inactive leaf does not bind TCP
            // sockets or collide with another live model.
            if (!portData->intValue[s_reset] && !rogueSimLinkReservePort(instance,
                                                                         &ROGUE_TCP_STREAM_MODEL,
                                                                         portData->intValue[s_port],
                                                                         RogueTcpStreamLog)) {
                RogueTcpStreamFatal("Invalid VCS Stream port reservation");
                return;
            }

            // Snapshot inputs, run the shared FSM step, then publish outputs.
            // Input and output port indices are disjoint, so the two copies
            // never touch the same signal.
            for (i = 0; i < ROGUE_TCP_STREAM_PORT_COUNT; i++)
                if (portData->portDir[i] == vhpiIn) data->inSnap[i] = portData->intValue[i];

            // Scalar/narrow values live in intValue; parameterized vectors are
            // copied through wordValue using only their active 32-bit words.
            dataWords = (data->dataBytes + 3U) / 4U;
            keepWords = (data->dataBytes + 31U) / 32U;
            memset(data->ibDataWords, 0, sizeof(data->ibDataWords));
            memset(data->ibUserWords, 0, sizeof(data->ibUserWords));
            memset(data->ibKeepWords, 0, sizeof(data->ibKeepWords));
            memcpy(data->ibDataWords, portData->wordValue[s_ibData], dataWords * sizeof(uint32_t));
            memcpy(data->ibUserWords, portData->wordValue[s_ibUser], dataWords * sizeof(uint32_t));
            memcpy(data->ibKeepWords, portData->wordValue[s_ibKeep], keepWords * sizeof(uint32_t));

            RogueTcpStreamStep(data);

            for (i = 0; i < ROGUE_TCP_STREAM_PORT_COUNT; i++)
                if (portData->portDir[i] == vhpiOut) portData->intValue[i] = data->outState[i];

            memcpy(portData->wordValue[s_obData], data->obDataWords, dataWords * sizeof(uint32_t));
            memcpy(portData->wordValue[s_obUser], data->obUserWords, dataWords * sizeof(uint32_t));
            memcpy(portData->wordValue[s_obKeep], data->obKeepWords, keepWords * sizeof(uint32_t));
            // VhpiGeneric retains intValue as the output source for vectors
            // up to 32 bits. Mirror word zero so narrow data/user ports and
            // keep masks through 32 lanes use the same shared beat state.
            portData->intValue[s_obData] = data->obDataWords[0];
            portData->intValue[s_obUser] = data->obUserWords[0];
            portData->intValue[s_obKeep] = data->obKeepWords[0];
        }
    }
}
