//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "RogueSimLinkInstance.h"
#include "VhpiGeneric.h"

enum {
    TEST_PORT_COUNT       = 3,
    TEST_COMPONENT_HANDLE = 100,
    TEST_PORT_HANDLE_BASE = 200,
};

static const VhpiPortSpec testPorts[TEST_PORT_COUNT] = {
    {vhpiIn, 1},
    {vhpiIn, 8},
    {vhpiOut, 8},
};

static const vhpiIntT testPortWidths[TEST_PORT_COUNT]     = {1, 8, 8};
static const vhpiIntT testPortDirections[TEST_PORT_COUNT] = {vhpiIn, vhpiIn, vhpiOut};
static const RogueSimLinkModelDescriptor testModel        = {"TestModel"};
static vhpiCbDataT* callbacks[1100];
static int modelCleanupCount;
static int callbackRemoveCount;
static int handleReleaseCount;

static void report(const char* message) {
    (void)message;
}

static void modelCleanup(void* data) {
    (void)data;
    modelCleanupCount++;
}

static void stateUpdate(void* data) {
    (void)data;
}

void vhpi_assert(const char* message, int severity) {
    fprintf(stderr, "VHPI assertion %d: %s\n", severity, message);
    abort();
}

int vhpi_chk_error(vhpiErrorInfoT* error) {
    (void)error;
    return 0;
}

int vhpi_printf(const char* format, ...) {
    va_list arguments;
    int result;

    va_start(arguments, format);
    result = vfprintf(stderr, format, arguments);
    va_end(arguments);
    return result;
}

vhpiHandleT vhpi_register_cb(vhpiCbDataT* cbData, int flags) {
    assert(flags == vhpiReturnCb);
    assert(cbData->reason >= 0 && cbData->reason < 1100);
    callbacks[cbData->reason] = cbData;
    return (vhpiHandleT)cbData->reason;
}

int vhpi_remove_cb(vhpiHandleT callback) {
    assert(callback != 0);
    callbackRemoveCount++;
    return 0;
}

int vhpi_release_handle(vhpiHandleT handle) {
    assert(handle != 0);
    handleReleaseCount++;
    return 0;
}

vhpiHandleT vhpi_handle_by_index(int relation, vhpiHandleT parent, int index) {
    assert(relation == vhpiPortDecls);
    assert(parent == TEST_COMPONENT_HANDLE);
    assert(index >= 0 && index < TEST_PORT_COUNT);
    return TEST_PORT_HANDLE_BASE + (vhpiHandleT)index;
}

char* vhpi_get_str(int property, vhpiHandleT handle) {
    assert(property == vhpiFullNameP);
    if (handle == TEST_COMPONENT_HANDLE) return "test_component";
    return "test_port";
}

vhpiIntT vhpi_get(int property, vhpiHandleT handle) {
    int index = (int)(handle - TEST_PORT_HANDLE_BASE);

    assert(index >= 0 && index < TEST_PORT_COUNT);
    if (property == vhpiSizeP) return testPortWidths[index];
    assert(property == vhpiModeP);
    return testPortDirections[index];
}

int vhpi_value_size(vhpiHandleT handle, int format) {
    assert(format == vhpiEnumVecVal);
    return vhpi_get(vhpiSizeP, handle);
}

int vhpi_get_value(vhpiHandleT handle, vhpiValueT* value) {
    (void)handle;
    (void)value;
    return 0;
}

int vhpi_put_value(vhpiHandleT handle, vhpiValueT* value, int mode) {
    (void)handle;
    (void)value;
    assert(mode == vhpiForcePropagate);
    return 0;
}

void vhpi_get_time(vhpiTimeT* time, long* cycles) {  // NOLINT(runtime/int)
    memset(time, 0, sizeof(*time));
    if (cycles != NULL) *cycles = 0;
}

int main(void) {
    RogueSimLinkInstance* instance = rogueSimLinkCreate(&testModel, 1, modelCleanup, report);
    portDataT* portData            = VhpiGenericAlloc(sizeof(*portData), "test port metadata");

    assert(instance != NULL);
    portData->instance    = instance;
    portData->model       = &testModel;
    portData->report      = report;
    portData->stateUpdate = stateUpdate;

    VhpiGenericInit(TEST_COMPONENT_HANDLE, portData, testPorts, TEST_PORT_COUNT);
    assert(callbacks[vhpiCbPLIError] != NULL);
    // The end-of-simulation callback is deliberately NOT registered under the
    // cocotb VPI-driven flow (it triggers a VCS $finish shutdown-ordering
    // segfault). Confirm that, then drive teardown by calling the exported
    // VhpiGenericCleanup directly instead of through the (absent) callback slot.
    assert(callbacks[vhpiCbEndOfSimulation] == NULL);
    assert(callbacks[vhpiCbValueChange] == &portData->callbackData);

    VhpiGenericCleanup(NULL);

    assert(modelCleanupCount == 1);
    // Value-change and PLI-error callbacks are removed (2). Handles released:
    // the value-change callback handle, TEST_PORT_COUNT port handles, and the
    // error callback handle == TEST_PORT_COUNT + 2. The cleanup callback handle
    // is 0 (never registered), so its release is skipped -- one fewer than when
    // the end-of-sim callback was registered.
    assert(callbackRemoveCount == 2);
    assert(handleReleaseCount == TEST_PORT_COUNT + 2);
    assert(rogueSimLinkGetData(instance, &testModel, report) == NULL);
    return 0;
}
