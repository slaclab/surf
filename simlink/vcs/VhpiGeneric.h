//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef SURF_SIMLINK_VCS_VHPI_GENERIC_H
#define SURF_SIMLINK_VCS_VHPI_GENERIC_H

#include <stddef.h>
#include <vhpi_user.h>

#include "RogueSimLinkInstance.h"

/** Maximum scalar/vector port entries supported by one VHPI adapter. */
#define ROGUE_VHPI_MAX_PORT_COUNT 48
/** Maximum vector width, expressed as little-endian 32-bit words. */
#define ROGUE_VHPI_MAX_VECTOR_WORDS 32

/** Declarative direction and expected-width contract for one VHDL port. */
typedef struct {
    vhpiIntT direction; /**< vhpiIn or vhpiOut. */
    vhpiIntT width;     /**< Expected bits; zero requests elaborated width. */
} VhpiPortSpec;

/**
 * Per-instance VHPI port metadata and shared-model ownership.
 *
 * The callback reads VHDL enum values into intValue/wordValue, invokes
 * stateUpdate(), then encodes output entries back into the simulator.
 */
typedef struct portDataS {
    int portCount; /**< Number of active entries in the parallel arrays. */

    /** Handles for ports in declaration order. */
    vhpiHandleT portHandle[ROGUE_VHPI_MAX_PORT_COUNT];

    /** Simulator value buffers associated with portHandle. */
    vhpiValueT* portValue[ROGUE_VHPI_MAX_PORT_COUNT];

    /** Low 32 bits of each port, and the complete value for narrow ports. */
    unsigned int intValue[ROGUE_VHPI_MAX_PORT_COUNT];

    /**
     * Little-endian words for wide vectors. intValue remains authoritative
     * for ports no wider than 32 bits.
     */
    unsigned int wordValue[ROGUE_VHPI_MAX_PORT_COUNT][ROGUE_VHPI_MAX_VECTOR_WORDS];

    /** Per-port drive enable; currently initialized and retained as enabled. */
    unsigned int outEnable[ROGUE_VHPI_MAX_PORT_COUNT];

    /** Elaborated direction for each port. */
    vhpiIntT portDir[ROGUE_VHPI_MAX_PORT_COUNT];

    /** Elaborated width in bits for each port. */
    vhpiIntT portWidth[ROGUE_VHPI_MAX_PORT_COUNT];

    /** Model-specific callback invoked after input conversion. */
    void (*stateUpdate)(void*);

    RogueSimLinkInstance* instance;           /**< Common instance owned by this entry. */
    const RogueSimLinkModelDescriptor* model; /**< Expected model type token. */
    RogueSimLinkReport report;                /**< Adapter diagnostic callback. */

    vhpiCbDataT callbackData;   /**< Retained value-change callback data. */
    vhpiTimeT callbackTime;     /**< Retained callback time storage. */
    vhpiHandleT callbackHandle; /**< Registered callback handle. */

    struct portDataS* next; /**< Process-wide cleanup-list link. */
} portDataT;

/** Registers process-wide VHPI callbacks during foreign architecture setup. */
void VhpiGenericElab(vhpiHandleT compInst);

/**
 * Validates ports and registers the per-instance clock callback.
 *
 * Ownership of @p portData transfers to the process-wide VHPI registry. Each
 * port specification corresponds by index to a VHDL component port.
 *
 * @param[in] compInst Elaborated component instance.
 * @param[in,out] portData Zero-initialized adapter metadata.
 * @param[in] portSpecs Direction/width table in declaration order.
 * @param[in] portCount Number of entries in portSpecs.
 */
void VhpiGenericInit(vhpiHandleT compInst, portDataT* portData, const VhpiPortSpec* portSpecs, int portCount);

/**
 * Allocates zero-initialized VHPI metadata or reports a fatal error.
 *
 * @param[in] size Allocation size in bytes.
 * @param[in] objectName Diagnostic name for the requested object.
 * @return Owned zero-initialized storage.
 */
void* VhpiGenericAlloc(size_t size, const char* objectName);

/**
 * Releases registered callbacks, handles, model instances, and metadata.
 *
 * This is the body a vhpiCbEndOfSimulation callback would run. It is
 * intentionally not registered under the cocotb VPI-driven flow because that
 * triggers a VCS shutdown-ordering failure. It remains exported for direct
 * lifecycle tests and a future safe non-cocotb path.
 *
 * @param[in] cbData Unused callback argument; may be NULL.
 */
void VhpiGenericCleanup(vhpiCbDataT* cbData);

#endif
