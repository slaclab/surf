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
// Shared VCS/VHPI port adapter. Elaboration validates a declarative port table
// and registers one callback on the clock. Each callback converts VHDL
// std_logic ordinals to the adapter's two-state scalar/word representation,
// invokes the model-specific state update, and writes converted outputs back.
// The process-wide list retains every callback, value buffer, and common model
// instance for explicit lifecycle tests and any future safe shutdown callback.
//////////////////////////////////////////////////////////////////////////////

// VHPI std_logic enum ordinals used by the conversion routines below:
// 0   /* uninitialized */
// 1   /* unknown */
// 2   /* forcing 0 */
// 3   /* forcing 1 */
// 4   /* high impedance */
// 5   /* weak unknown */
// 6   /* weak 0 */
// 7   /* weak 1 */
// 8   /* don't care */

#include "VhpiGeneric.h"

#include <stdlib.h>
#include <string.h>
#include <vhpi_user.h>

// Registry head and process-wide callbacks are intentionally centralized so
// multiple Stream, Memory, and SideBand leaves share one teardown domain.
static portDataT* VhpiGenericInstances = NULL;
static vhpiCbDataT VhpiGenericErrorCallbackData;
static vhpiTimeT VhpiGenericErrorCallbackTime;
static vhpiHandleT VhpiGenericErrorCallbackHandle;
// Handle for the end-of-simulation cleanup callback. It is not registered under
// the cocotb VPI-driven flow (see VhpiGenericRegisterGlobalCallbacks), so it
// stays 0 today; VhpiGenericCleanup's release path is guarded on it. A future
// non-cocotb path that registers the callback populates this handle. The
// callback's own cbData/time storage lives with whatever code performs that
// registration, not here, so no dead registration state is carried.
static vhpiHandleT VhpiGenericCleanupCallbackHandle;
static int VhpiGenericCallbacksRegistered = 0;

void* VhpiGenericAlloc(size_t size, const char* objectName) {
    void* value = calloc(1, size);

    if (value == NULL) {
        vhpi_printf("Failed to allocate VCS SimLink %s\n", objectName);
        vhpi_assert("VCS SimLink allocation failed", vhpiFatal);
        abort();
    }
    return value;
}

static vhpiHandleT VhpiGenericRegisterCallback(vhpiCbDataT* cbData) {
    // VCS releases before 2016 used the legacy void-return registration API.
#if (VCS_VERSION >= 2016)
    vhpiHandleT callbackHandle = vhpi_register_cb(cbData, vhpiReturnCb);

    if (callbackHandle == 0) vhpi_assert("VCS SimLink callback registration failed", vhpiFatal);
    return callbackHandle;
#else
    vhpi_register_cb(cbData);
    return 0;
#endif
}

static void VhpiGenericReleaseCallback(vhpiHandleT callbackHandle) {
#if (VCS_VERSION >= 2016)
    if (callbackHandle != 0) {
        vhpi_remove_cb(callbackHandle);
        vhpi_release_handle(callbackHandle);
    }
#else
    (void)callbackHandle;
#endif
}

// Decode simulator enum ordinals into the common two-state representation.
static void VhpiGenericConvertIn(portDataT* portData) {
    int x, y, bit, word;

    // SimLink is deliberately two-state: only forcing '1' maps to one; X, Z,
    // weak values, and every other std_logic ordinal map to zero.
    for (x = 0; x < portData->portCount; x++) {
        if (portData->portDir[x] != vhpiOut) {
            if (portData->portWidth[x] == 1) {
                if (portData->portValue[x]->value.enumval == 3) {
                    portData->intValue[x] = 1;
                } else {
                    portData->intValue[x] = 0;
                }
                portData->wordValue[x][0] = portData->intValue[x];
            } else {
                portData->intValue[x] = 0;
                memset(portData->wordValue[x], 0, sizeof(portData->wordValue[x]));
                // VHPI presents enum vectors in declaration order, whereas the
                // common model numbers bits from LSB zero.
                for (y = 0; y < portData->portWidth[x]; y++) {
                    bit  = (portData->portWidth[x] - 1) - y;
                    word = bit / 32;
                    if (portData->portValue[x]->value.enums[y] == 3) {
                        portData->wordValue[x][word] |= 1U << (bit % 32);
                    }
                }
                portData->intValue[x] = portData->wordValue[x][0];
            }
        }
    }
}

// Encode common two-state values back into simulator enum ordinals.
static void VhpiGenericConvertOut(portDataT* portData) {
    int x, y, bit, word;
    unsigned int value;
    // Reverse the input mapping: common-model bits become forcing '0'/'1'
    // ordinals in the simulator's declaration order.
    for (x = 0; x < portData->portCount; x++) {
        if (portData->portDir[x] != vhpiIn) {
            if (portData->portWidth[x] == 1) {
                if (portData->outEnable[x] == 1) {
                    if (portData->intValue[x] == 0) {
                        portData->portValue[x]->value.enumval = 2;
                    } else {
                        portData->portValue[x]->value.enumval = 3;
                    }
                } else {
                    // Reserved tri-state path; unreachable while outEnable==1.
                    portData->portValue[x]->value.enumval = 4;  // Tri-state
                }
            } else {
                if (portData->outEnable[x] == 1) {
                    for (y = 0; y < portData->portWidth[x]; y++) {
                        bit   = (portData->portWidth[x] - 1) - y;
                        word  = bit / 32;
                        value = (portData->portWidth[x] <= 32) ? portData->intValue[x] : portData->wordValue[x][word];
                        if (((value >> (bit % 32)) & 0x1U) != 0) {
                            portData->portValue[x]->value.enums[y] = 3;
                        } else {
                            portData->portValue[x]->value.enums[y] = 2;
                        }
                    }
                } else {
                    // Reserved tri-state path; unreachable while outEnable==1.
                    for (y = 0; y < portData->portWidth[x]; y++) {
                        portData->portValue[x]->value.enums[y] = 4;  // Tri-state
                    }
                }
            }
        }
    }
}

// Complete one callback transaction: sample, update, and publish.
static void VhpiGenericCallBack(vhpiCbDataT* cbData) {
    int x;
    int ret;

    // Get user data
    portDataT* portData = (portDataT*)cbData->user_data;

    // Get current state of all ports
    for (x = 0; x < portData->portCount; x++) {
        // Get the initial input values.
        if (portData->portDir[x] != vhpiOut)
            if ((ret = vhpi_get_value(portData->portHandle[x], portData->portValue[x])))
                vhpi_printf("vhpi_get_value status error %i for port %i\n", ret, x);
    }

    // Convert input values.
    VhpiGenericConvertIn(portData);

    // Advance the model-specific state.
    portData->stateUpdate(portData);

    // Convert output values.
    VhpiGenericConvertOut(portData);

    // Set output values
    for (x = 0; x < portData->portCount; x++) {
        if (portData->portDir[x] != vhpiIn)
            if ((ret = vhpi_put_value(portData->portHandle[x], portData->portValue[x], vhpiForcePropagate)))
                vhpi_printf("vhpi_put_value status error %i for port %i\n", ret, x);
    }
}

// Drain all pending VHPI diagnostics through the simulator log.
static void VhpiGenericErrors(vhpiCbDataT* cb) {
    vhpiErrorInfoT g_error;

    (void)cb;
    while (vhpi_chk_error(&g_error)) vhpi_printf("\tError: %s: %s\n", g_error.str, g_error.message);
}

void VhpiGenericCleanup(vhpiCbDataT* cbData) {
    portDataT* portData;
    int x;

    (void)cbData;
    while (VhpiGenericInstances != NULL) {
        portData             = VhpiGenericInstances;
        VhpiGenericInstances = portData->next;

        // Stop callbacks and release simulator handles before destroying the
        // common instance that backs stateUpdate().
        VhpiGenericReleaseCallback(portData->callbackHandle);
        for (x = 0; x < portData->portCount; x++) {
            if (portData->portHandle[x] != 0) vhpi_release_handle(portData->portHandle[x]);
            if (portData->portValue[x] != NULL) {
                if (portData->portWidth[x] != 1) free(portData->portValue[x]->value.enums);
                free(portData->portValue[x]);
            }
        }

        if (portData->instance != NULL) rogueSimLinkDestroy(portData->instance, portData->model, portData->report);
        free(portData);
    }

    VhpiGenericReleaseCallback(VhpiGenericErrorCallbackHandle);
    VhpiGenericErrorCallbackHandle = 0;
#if (VCS_VERSION >= 2016)
    if (VhpiGenericCleanupCallbackHandle != 0) vhpi_release_handle(VhpiGenericCleanupCallbackHandle);
#endif
    VhpiGenericCleanupCallbackHandle = 0;
}

static void VhpiGenericRegisterGlobalCallbacks(void) {
    if (VhpiGenericCallbacksRegistered) return;

    memset(&VhpiGenericErrorCallbackData, 0, sizeof(VhpiGenericErrorCallbackData));
    memset(&VhpiGenericErrorCallbackTime, 0, sizeof(VhpiGenericErrorCallbackTime));
    VhpiGenericErrorCallbackData.cbf    = VhpiGenericErrors;
    VhpiGenericErrorCallbackData.time   = &VhpiGenericErrorCallbackTime;
    VhpiGenericErrorCallbackData.reason = vhpiCbPLIError;
    VhpiGenericErrorCallbackHandle      = VhpiGenericRegisterCallback(&VhpiGenericErrorCallbackData);

    // Deliberately do NOT register a vhpiCbEndOfSimulation callback. Under the
    // cocotb VPI-driven flow (the SystemVerilog VPI bridge that lets cocotb
    // drive the VHPI leaves), VCS segfaults inside vpi_control [vpiFinish] when
    // a VHPI end-of-simulation callback is also registered -- a VHPI/VPI
    // shutdown-ordering conflict in the simulator, reproducible even with an
    // empty callback body. Active teardown of VHPI handles and port memory is
    // unnecessary at $finish: the process exits immediately afterward and the
    // OS reclaims that memory. The transport worker thread and its ZeroMQ
    // sockets -- the only teardown with real side effects -- are still shut
    // down deterministically by the instance layer's atexit(rogueSimLinkDestroyAll)
    // hook. VhpiGenericCleanup is retained for a future non-cocotb path that can
    // register it safely.
    (void)VhpiGenericCleanup;

    VhpiGenericCallbacksRegistered = 1;
}

// Register process-wide error handling during foreign architecture setup.
void VhpiGenericElab(vhpiHandleT compInst) {
    (void)compInst;
    VhpiGenericRegisterGlobalCallbacks();
}

// Validate one elaborated port set and register its clock callback.
void VhpiGenericInit(vhpiHandleT compInst, portDataT* portData, const VhpiPortSpec* portSpecs, int portCount) {
    int width;
    int x, y;

    if (portData == NULL || portSpecs == NULL || portCount <= 0 || portCount > ROGUE_VHPI_MAX_PORT_COUNT) {
        vhpi_assert("Invalid VCS SimLink port specification", vhpiFatal);
        return;
    }
    VhpiGenericRegisterGlobalCallbacks();
    portData->portCount = portCount;
    for (x = 0; x < portData->portCount; x++) {
        // A width of 0 is legitimate (parameterized ports infer their width
        // from the elaborated design below). Do not test direction against 0:
        // the VHPI standard defines vhpiIn as the first mode, so vhpiIn == 0
        // and the clock/reset inputs would falsely trip an "unset" sentinel.
        // Accept only the modes these adapters actually use.
        if ((portSpecs[x].direction != vhpiIn && portSpecs[x].direction != vhpiOut) || portSpecs[x].width < 0) {
            vhpi_assert("Incomplete VCS SimLink port specification", vhpiFatal);
            return;
        }
        portData->portDir[x]   = portSpecs[x].direction;
        portData->portWidth[x] = portSpecs[x].width;
    }
    // Publish the complete metadata object to the cleanup list before any
    // later initialization step can invoke a fatal simulator path.
    portData->next       = VhpiGenericInstances;
    VhpiGenericInstances = portData;

    // Blank out port handles and create value structures
    for (x = 0; x < portData->portCount; x++) {
        portData->portHandle[x] = 0;
        portData->portValue[x]  = VhpiGenericAlloc(sizeof(vhpiValueT), "port value");
        portData->intValue[x]   = 0;
        memset(portData->wordValue[x], 0, sizeof(portData->wordValue[x]));
        // outEnable is initialized to 1 for every port and never cleared
        // today, so the enumval=4 tri-state branches in VhpiGenericConvertOut
        // are currently unreachable. They are kept deliberately: VhpiGeneric is
        // a general VHPI helper and per-port tri-state drive is a valid future
        // capability -- wire outEnable through the port spec to activate it.
        portData->outEnable[x] = 1;

        memset(portData->portValue[x], 0, sizeof(vhpiValueT));
    }

    // Get each port and verify width and direction, get initial value
    for (x = 0; x < portData->portCount; x++) {
        // VHPI indexes ports in the foreign entity's declaration order; the
        // model-specific VhpiPortSpec table uses that same enum ordering.
        portData->portHandle[x] = vhpi_handle_by_index(vhpiPortDecls, compInst, x);

        // A zero expected width requests inference from the elaborated port.
        // Parameterized Stream vectors use this path; existing fixed-width
        // adapters retain their explicit width checks.
        if (portData->portWidth[x] == 0) portData->portWidth[x] = vhpi_get(vhpiSizeP, portData->portHandle[x]);
        if (portData->portWidth[x] > (ROGUE_VHPI_MAX_VECTOR_WORDS * 32)) {
            vhpi_printf("Error: Port '%s' exceeds VhpiGeneric vector limit\n",
                        vhpi_get_str(vhpiFullNameP, portData->portHandle[x]));
            vhpi_assert("VCS SimLink vector width unsupported", vhpiFatal);
        }

        // Setup value types
        if (portData->portWidth[x] == 1) {
            portData->portValue[x]->format        = vhpiEnumVal;
            portData->portValue[x]->value.enumval = 2;
        } else {
            portData->portValue[x]->format      = vhpiEnumVecVal;
            width                               = vhpi_value_size(portData->portHandle[x], vhpiEnumVecVal);
            portData->portValue[x]->value.enums = VhpiGenericAlloc(width * sizeof(vhpiEnumT), "port vector value");
            portData->portValue[x]->bufSize     = width;
            for (y = 0; y < portData->portWidth[x]; y++) portData->portValue[x]->value.enums[y] = 2;
        }

        // Check direction
        if (vhpi_get(vhpiModeP, portData->portHandle[x]) != portData->portDir[x])
            vhpi_printf("Error: Port '%s' direction mismatch\n", vhpi_get_str(vhpiFullNameP, portData->portHandle[x]));

        // Check width
        if (vhpi_get(vhpiSizeP, portData->portHandle[x]) != portData->portWidth[x])
            vhpi_printf("Error: Port '%s' size mismatch\n", vhpi_get_str(vhpiFullNameP, portData->portHandle[x]));

        // Get the initial input values.
        if (portData->portDir[x] != vhpiOut) vhpi_get_value(portData->portHandle[x], portData->portValue[x]);

        // Set the initial output values.
        if (portData->portDir[x] != vhpiIn)
            vhpi_put_value(portData->portHandle[x], portData->portValue[x], vhpiForcePropagate);
    }

    // The clock is port zero for every SimLink leaf.
    memset(&portData->callbackData, 0, sizeof(portData->callbackData));
    memset(&portData->callbackTime, 0, sizeof(portData->callbackTime));
    portData->callbackData.reason    = vhpiCbValueChange;
    portData->callbackData.obj       = portData->portHandle[0];
    portData->callbackData.value     = portData->portValue[0];
    portData->callbackData.cbf       = VhpiGenericCallBack;
    portData->callbackData.time      = &portData->callbackTime;
    portData->callbackData.user_data = (void*)portData;
    portData->callbackHandle         = VhpiGenericRegisterCallback(&portData->callbackData);
}
