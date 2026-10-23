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
// VHPI backend for the Rogue side-band model. The worker transport/codec and
// opcode/remData FSM live in the compiled shared RogueSideBandCore.c. This
// file provides the VHPI-specific plumbing: RogueSideBandInit (port table +
// VhpiGeneric registration) and RogueSideBandUpdate, the value-change callback
// that detects clock edges and bridges portData->intValue to/from the shared
// FSM's snapshot.
//////////////////////////////////////////////////////////////////////////////

#include "RogueSideBand.h"

#include <stdint.h>
#include <stdlib.h>

#include "RogueSimLinkInstance.h"
#include "VhpiGeneric.h"

typedef struct {
    // Keep the shared model first so ownership and cleanup stay model-centric;
    // currClk belongs only to the VHPI edge-detection adapter.
    RogueSideBandData model;
    uint8_t currClk;
} RogueSideBandVhpiData;

// Declaration-order contract checked against the elaborated VHDL leaf.
static const VhpiPortSpec rogueSideBandPorts[ROGUE_SIDE_BAND_PORT_COUNT] = {
    [s_clock]      = {vhpiIn, 1},
    [s_reset]      = {vhpiIn, 1},
    [s_port]       = {vhpiIn, 16},
    [s_txOpCode]   = {vhpiIn, 8},
    [s_txOpCodeEn] = {vhpiIn, 1},
    [s_txRemData]  = {vhpiIn, 8},
    [s_rxOpCode]   = {vhpiOut, 8},
    [s_rxOpCodeEn] = {vhpiOut, 1},
    [s_rxRemData]  = {vhpiOut, 8},
};

void RogueSideBandLog(const char* message) {
    vhpi_printf("%s", message);
}

void RogueSideBandFatal(const char* message) {
    // VCS declares vhpi_assert() as taking a non-const char*, so cast away the
    // qualifier. The message is only read by the simulator.
    vhpi_assert((char*) message, vhpiFatal);
}

// Bind one shared model instance to the elaborated VHPI port set.
void RogueSideBandInit(vhpiHandleT compInst) {
    // VhpiGeneric owns the per-port handles/value buffers; the common instance
    // registry owns the embedded model and its transport.
    portDataT* portData            = VhpiGenericAlloc(sizeof(portDataT), "SideBand port metadata");
    RogueSimLinkInstance* instance = rogueSimLinkCreate(&ROGUE_SIDE_BAND_MODEL,
                                                        sizeof(RogueSideBandVhpiData),
                                                        RogueSideBandCleanup,
                                                        RogueSideBandLog);

    if (instance == NULL) {
        free(portData);
        RogueSideBandFatal("Failed to create VCS SideBand instance");
        return;
    }
    portData->instance    = instance;
    portData->model       = &ROGUE_SIDE_BAND_MODEL;
    portData->report      = RogueSideBandLog;
    portData->stateUpdate = *RogueSideBandUpdate;
    VhpiGenericInit(compInst, portData, rogueSideBandPorts, ROGUE_SIDE_BAND_PORT_COUNT);
}

// Convert a clock callback into at most one shared-model rising-edge step.
void RogueSideBandUpdate(void* userPtr) {
    portDataT* portData            = (portDataT*)userPtr;
    RogueSimLinkInstance* instance = portData->instance;
    RogueSideBandVhpiData* adapter = rogueSimLinkGetData(instance, &ROGUE_SIDE_BAND_MODEL, RogueSideBandLog);
    RogueSideBandData* data;
    uint32_t i;

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
                                                                         &ROGUE_SIDE_BAND_MODEL,
                                                                         portData->intValue[s_port],
                                                                         RogueSideBandLog)) {
                RogueSideBandFatal("Invalid VCS SideBand port reservation");
                return;
            }

            // Snapshot inputs, run the shared FSM step, then publish outputs.
            // Input and output port indices are disjoint, so the two copies
            // never touch the same signal.
            for (i = 0; i < ROGUE_SIDE_BAND_PORT_COUNT; i++)
                if (portData->portDir[i] == vhpiIn) data->inSnap[i] = portData->intValue[i];

            RogueSideBandStep(data);

            for (i = 0; i < ROGUE_SIDE_BAND_PORT_COUNT; i++)
                if (portData->portDir[i] == vhpiOut) portData->intValue[i] = data->outState[i];
        }
    }
}
