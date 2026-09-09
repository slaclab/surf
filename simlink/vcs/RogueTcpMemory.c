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
// VHPI backend for the Rogue-TCP AXI-Lite memory model. The worker
// transport/codec and transaction FSM live in the compiled shared
// RogueTcpMemoryCore.c. This file provides the VHPI-specific plumbing:
// RogueTcpMemoryInit (port table + VhpiGeneric registration) and
// RogueTcpMemoryUpdate, the value-change callback that does clock-edge
// detection and bridges portData->intValue to/from the shared FSM's snapshot.
//////////////////////////////////////////////////////////////////////////////

#include "RogueTcpMemory.h"

#include <stdint.h>
#include <stdlib.h>

#include "RogueSimLinkInstance.h"
#include "VhpiGeneric.h"

typedef struct {
    // The common model owns protocol state; currClk is VHPI-only edge state.
    RogueTcpMemoryData model;
    uint8_t currClk;
} RogueTcpMemoryVhpiData;

// Declaration-order contract checked against the elaborated VHDL leaf.
static const VhpiPortSpec rogueTcpMemoryPorts[ROGUE_TCP_MEMORY_PORT_COUNT] = {
    [s_clock]   = {vhpiIn,  1},
    [s_reset]   = {vhpiIn,  1},
    [s_port]    = {vhpiIn, 16},
    [s_araddr]  = {vhpiOut, 32},
    [s_arprot]  = {vhpiOut,  3},
    [s_arvalid] = {vhpiOut,  1},
    [s_rready]  = {vhpiOut,  1},
    [s_arready] = {vhpiIn,   1},
    [s_rdata]   = {vhpiIn,  32},
    [s_rresp]   = {vhpiIn,   2},
    [s_rvalid]  = {vhpiIn,   1},
    [s_awaddr]  = {vhpiOut, 32},
    [s_awprot]  = {vhpiOut,  3},
    [s_awvalid] = {vhpiOut,  1},
    [s_wdata]   = {vhpiOut, 32},
    [s_wstrb]   = {vhpiOut,  4},
    [s_wvalid]  = {vhpiOut,  1},
    [s_bready]  = {vhpiOut,  1},
    [s_awready] = {vhpiIn,   1},
    [s_wready]  = {vhpiIn,   1},
    [s_bresp]   = {vhpiIn,   2},
    [s_bvalid]  = {vhpiIn,   1},
};

void RogueTcpMemoryLog(const char* message) {
    vhpi_printf("%s", message);
}

void RogueTcpMemoryFatal(const char* message) {
    // VCS declares vhpi_assert() as taking a non-const char*, so cast away the
    // qualifier. The message is only read by the simulator.
    vhpi_assert((char*) message, vhpiFatal);
}

// Bind one shared model instance to the elaborated VHPI port set.
void RogueTcpMemoryInit(vhpiHandleT compInst) {
    // VhpiGeneric owns the per-port handles/value buffers; the common instance
    // registry owns the embedded model and its transport.
    portDataT* portData            = VhpiGenericAlloc(sizeof(portDataT), "Memory port metadata");
    RogueSimLinkInstance* instance = rogueSimLinkCreate(&ROGUE_TCP_MEMORY_MODEL,
                                                        sizeof(RogueTcpMemoryVhpiData),
                                                        RogueTcpMemoryCleanup,
                                                        RogueTcpMemoryLog);

    if (instance == NULL) {
        free(portData);
        RogueTcpMemoryFatal("Failed to create VCS Memory instance");
        return;
    }
    portData->instance    = instance;
    portData->model       = &ROGUE_TCP_MEMORY_MODEL;
    portData->report      = RogueTcpMemoryLog;
    portData->stateUpdate = *RogueTcpMemoryUpdate;
    VhpiGenericInit(compInst, portData, rogueTcpMemoryPorts, ROGUE_TCP_MEMORY_PORT_COUNT);
}

// Convert a clock callback into at most one shared-model rising-edge step.
void RogueTcpMemoryUpdate(void* userPtr) {
    portDataT* portData             = (portDataT*)userPtr;
    RogueSimLinkInstance* instance  = portData->instance;
    RogueTcpMemoryVhpiData* adapter = rogueSimLinkGetData(instance, &ROGUE_TCP_MEMORY_MODEL, RogueTcpMemoryLog);
    RogueTcpMemoryData* data;
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
                                                                         &ROGUE_TCP_MEMORY_MODEL,
                                                                         portData->intValue[s_port],
                                                                         RogueTcpMemoryLog)) {
                RogueTcpMemoryFatal("Invalid VCS Memory port reservation");
                return;
            }

            // Snapshot inputs, run the shared FSM step, then publish outputs.
            // Input and output port indices are disjoint, so the two copies
            // never touch the same signal.
            for (i = 0; i < ROGUE_TCP_MEMORY_PORT_COUNT; i++)
                if (portData->portDir[i] == vhpiIn) data->inSnap[i] = portData->intValue[i];

            RogueTcpMemoryStep(data);

            for (i = 0; i < ROGUE_TCP_MEMORY_PORT_COUNT; i++)
                if (portData->portDir[i] == vhpiOut) portData->intValue[i] = data->outState[i];
        }
    }
}
