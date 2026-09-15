//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef ROGUE_VHPI_DIRECT_REGISTRY_H
#define ROGUE_VHPI_DIRECT_REGISTRY_H

#include <stdint.h>

#include "RogueSimLinkInstance.h"

/** Model cleanup callback used by the handle-based VHPIDIRECT registry. */
typedef RogueSimLinkCleanup RogueVhpiDirectCleanup;

/** Routes common instance diagnostics through the active GHDL adapter. */
static void rogueVhpiDirectReport(const char* message) {
    vhpi_printf("%s", message);
}

/**
 * Allocates a common instance and returns its VHDL-compatible integer handle.
 *
 * @param[in] dataSize Number of bytes in the zero-initialized model state.
 * @param[in] cleanup Model-specific cleanup callback.
 * @param[in] model Model discriminator used for later validation.
 * @return Positive instance handle; fatal reporting occurs on failure.
 */
static int32_t rogueVhpiDirectCreate(size_t dataSize,
                                     RogueVhpiDirectCleanup cleanup,
                                     const RogueSimLinkModelDescriptor* model) {
    RogueSimLinkInstance* instance = rogueSimLinkCreate(model, dataSize, cleanup, rogueVhpiDirectReport);

    if (instance == NULL) {
        vhpi_assert("Failed to create VHPIDIRECT SimLink instance", vhpiFatal);
        return 0;
    }
    return rogueSimLinkGetHandle(instance);
}

/**
 * Resolves and validates model storage from a VHPIDIRECT integer handle.
 *
 * @param[in] handle Process-wide instance handle.
 * @param[in] model Expected model discriminator.
 * @return Model storage owned by the common instance registry.
 */
static void* rogueVhpiDirectGetData(int32_t handle, const RogueSimLinkModelDescriptor* model) {
    void* data = rogueSimLinkGetDataByHandle(handle, model, rogueVhpiDirectReport);

    if (data == NULL) vhpi_assert("Invalid VHPIDIRECT SimLink instance", vhpiFatal);
    return data;
}

/** Destroys a validated handle and all model-owned resources. */
static void rogueVhpiDirectDestroy(int32_t handle, const RogueSimLinkModelDescriptor* model) {
    if (!rogueSimLinkDestroyByHandle(handle, model, rogueVhpiDirectReport))
        vhpi_assert("Failed to destroy VHPIDIRECT SimLink instance", vhpiFatal);
}

/**
 * Claims the immutable adjacent TCP port pair for one handle.
 *
 * @param[in] handle Process-wide instance handle.
 * @param[in] requestedPort Base port of the pair.
 * @param[in] model Expected model discriminator.
 */
static void rogueVhpiDirectReservePort(int32_t handle,
                                       uint16_t requestedPort,
                                       const RogueSimLinkModelDescriptor* model) {
    if (!rogueSimLinkReservePortByHandle(handle, model, requestedPort, rogueVhpiDirectReport))
        vhpi_assert("Invalid VHPIDIRECT SimLink port reservation", vhpiFatal);
}

#endif
