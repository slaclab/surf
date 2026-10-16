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
// Thin Icarus VPI ownership adapter over the simulator-neutral instance
// registry, plus the argument-marshalling and systf registration helpers
// shared by every Rogue* VPI adapter. All validation, port-pair ownership,
// cleanup, and process-exit fallback remain centralized in
// RogueSimLinkInstance.c; this file only bridges the handle-based VPI ABI to
// that registry's pointer-based API.
//////////////////////////////////////////////////////////////////////////////

#include "RogueVpiInstance.h"

#include <string.h>

// The largest vector this module marshals is a 128-byte Stream data/user
// lane (1024 bits = 32 words), matching ROGUE_TCP_STREAM_MAX_DATA_WORDS.
#define ROGUE_VPI_MAX_WORDS 32U

static void rogueVpiReport(const char* message) {
    vpi_printf("%s", message);
}

int32_t rogueVpiCreate(const RogueSimLinkModelDescriptor* model, size_t dataSize, RogueVpiCleanup cleanup) {
    RogueSimLinkInstance* instance = rogueSimLinkCreate(model, dataSize, cleanup, rogueVpiReport);
    return rogueSimLinkGetHandle(instance);
}

void* rogueVpiGetData(int32_t handle, const RogueSimLinkModelDescriptor* expectedModel) {
    return rogueSimLinkGetDataByHandle(handle, expectedModel, rogueVpiReport);
}

int rogueVpiReservePort(int32_t handle, const RogueSimLinkModelDescriptor* expectedModel, uint16_t requestedPort) {
    return rogueSimLinkReservePortByHandle(handle, expectedModel, requestedPort, rogueVpiReport);
}

int rogueVpiDestroy(int32_t handle, const RogueSimLinkModelDescriptor* expectedModel) {
    return rogueSimLinkDestroyByHandle(handle, expectedModel, rogueVpiReport);
}

int rogueVpiCollectArgs(const char* name, vpiHandle* args, int expected) {
    vpiHandle systf = vpi_handle(vpiSysTfCall, NULL);
    vpiHandle iter   = vpi_iterate(vpiArgument, systf);
    vpiHandle arg;
    int count = 0;

    while (iter != NULL) {
        arg = vpi_scan(iter);
        if (arg == NULL) {
            // vpi_scan() frees the iterator itself once exhausted.
            iter = NULL;
            break;
        }
        if (count < expected) {
            args[count] = arg;
        }
        count++;
        if (count > expected) {
            // More arguments than expected: stop early and free the
            // iterator ourselves, since vpi_scan() never returned NULL.
            vpi_free_object(iter);
            iter = NULL;
            break;
        }
    }

    if (count != expected) {
        vpi_printf("%s: expected %d argument(s), got %d\n", name, expected, count);
        return 0;
    }
    return 1;
}

unsigned int rogueVpiGetU32(vpiHandle arg) {
    s_vpi_value value;

    value.format = vpiVectorVal;
    vpi_get_value(arg, &value);
    return (unsigned int)(value.value.vector[0].aval & ~value.value.vector[0].bval);
}

int rogueVpiGetWords(const char* name, vpiHandle arg, uint32_t* words, uint32_t maxWords, uint32_t expectedBits) {
    s_vpi_value value;
    uint32_t wordCount = (expectedBits + 31U) / 32U;
    uint32_t i;
    int actualBits = vpi_get(vpiSize, arg);

    if (actualBits < 0 || (uint32_t)actualBits != expectedBits) {
        vpi_printf("%s: expected %u-bit argument, got %d bits\n", name, expectedBits, actualBits);
        return 0;
    }
    if (wordCount > maxWords) {
        vpi_printf("%s: %u-bit argument exceeds %u-word buffer\n", name, expectedBits, maxWords);
        return 0;
    }

    value.format = vpiVectorVal;
    vpi_get_value(arg, &value);
    for (i = 0; i < wordCount; i++) {
        words[i] = (uint32_t)(value.value.vector[i].aval & ~value.value.vector[i].bval);
    }
    for (; i < maxWords; i++) {
        words[i] = 0U;
    }
    return 1;
}

int rogueVpiPutU32(const char* name, vpiHandle arg, uint32_t value, uint32_t expectedBits) {
    s_vpi_value result;
    s_vpi_vecval vector;
    int actualBits = vpi_get(vpiSize, arg);
    uint32_t mask = (expectedBits >= 32U) ? 0xFFFFFFFFU : ((1U << expectedBits) - 1U);

    if (actualBits < 0 || (uint32_t)actualBits != expectedBits) {
        vpi_printf("%s: expected %u-bit argument, got %d bits\n", name, expectedBits, actualBits);
        return 0;
    }

    vector.aval = (PLI_INT32)(value & mask);
    vector.bval = 0;
    result.format = vpiVectorVal;
    result.value.vector = &vector;
    vpi_put_value(arg, &result, NULL, vpiNoDelay);
    return 1;
}

int rogueVpiPutWords(const char* name, vpiHandle arg, const uint32_t* words, uint32_t expectedBits) {
    s_vpi_value result;
    s_vpi_vecval vector[ROGUE_VPI_MAX_WORDS];
    uint32_t wordCount = (expectedBits + 31U) / 32U;
    uint32_t remainderBits = expectedBits % 32U;
    uint32_t mask = (remainderBits == 0U) ? 0xFFFFFFFFU : ((1U << remainderBits) - 1U);
    uint32_t i;
    int actualBits = vpi_get(vpiSize, arg);

    if (actualBits < 0 || (uint32_t)actualBits != expectedBits) {
        vpi_printf("%s: expected %u-bit argument, got %d bits\n", name, expectedBits, actualBits);
        return 0;
    }
    if (wordCount > ROGUE_VPI_MAX_WORDS) {
        vpi_printf("%s: %u-bit argument exceeds %u-word buffer\n", name, expectedBits, ROGUE_VPI_MAX_WORDS);
        return 0;
    }

    for (i = 0; i < wordCount; i++) {
        vector[i].aval = (PLI_INT32)words[i];
        vector[i].bval = 0;
    }
    vector[wordCount - 1U].aval &= (PLI_INT32)mask;

    result.format = vpiVectorVal;
    result.value.vector = vector;
    vpi_put_value(arg, &result, NULL, vpiNoDelay);
    return 1;
}

void rogueVpiReturnInt(int32_t value) {
    vpiHandle systf = vpi_handle(vpiSysTfCall, NULL);
    s_vpi_value result;

    result.format = vpiIntVal;
    result.value.integer = value;
    vpi_put_value(systf, &result, NULL, vpiNoDelay);
}

static PLI_INT32 rogueVpiSizetf(PLI_BYTE8* userData) {
    (void)userData;
    return 32;
}

void rogueVpiRegisterFunction(PLI_BYTE8* name, RogueVpiCalltf calltf) {
    s_vpi_systf_data tf;

    memset(&tf, 0, sizeof(tf));
    tf.type        = vpiSysFunc;
    tf.sysfunctype = vpiIntFunc;
    tf.tfname      = name;
    tf.calltf      = calltf;
    tf.sizetf      = rogueVpiSizetf;
    vpi_register_systf(&tf);
}

void rogueVpiRegisterTask(PLI_BYTE8* name, RogueVpiCalltf calltf) {
    s_vpi_systf_data tf;

    memset(&tf, 0, sizeof(tf));
    tf.type   = vpiSysTask;
    tf.tfname = name;
    tf.calltf = calltf;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {
    rogueTcpStreamVpiRegister,
    rogueTcpMemoryVpiRegister,
    rogueSideBandVpiRegister,
    NULL
};
