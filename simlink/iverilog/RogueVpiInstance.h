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
// Icarus VPI ownership bridge over the simulator-neutral instance registry,
// modeled on RogueDpiInstance.h but keyed by a positive integer handle rather
// than a raw pointer, so no pointer ever crosses the Verilog/C boundary. Also
// declares the VPI argument-marshalling helpers shared by every Rogue* VPI
// adapter and the systf registration helpers used by their startup routines.
//////////////////////////////////////////////////////////////////////////////

#ifndef ROGUE_VPI_INSTANCE_H
#define ROGUE_VPI_INSTANCE_H

#include <stddef.h>
#include <stdint.h>

#include "RogueSimLinkInstance.h"
#include "vpi_user.h"

/** VPI-facing alias for a model cleanup callback. */
typedef RogueSimLinkCleanup RogueVpiCleanup;

/** VPI systf callback signature, matching s_vpi_systf_data.calltf. */
typedef PLI_INT32 (*RogueVpiCalltf)(PLI_BYTE8* userData);

/**
 * Creates one zero-initialized model instance for a VPI leaf.
 *
 * @param[in] model Static model descriptor stored in the instance.
 * @param[in] dataSize Number of bytes in the model state.
 * @param[in] cleanup Optional model-specific cleanup callback.
 * @return Positive handle, or 0 on allocation failure.
 */
int32_t rogueVpiCreate(const RogueSimLinkModelDescriptor* model, size_t dataSize, RogueVpiCleanup cleanup);

/**
 * Validates a handle and returns its model state.
 *
 * @param[in] handle Handle returned by rogueVpiCreate().
 * @param[in] expectedModel Model descriptor required by the caller.
 * @return Model state, or NULL after reporting a validation failure.
 */
void* rogueVpiGetData(int32_t handle, const RogueSimLinkModelDescriptor* expectedModel);

/**
 * Claims an immutable adjacent TCP port pair for a handle.
 *
 * @param[in] handle Handle returned by rogueVpiCreate().
 * @param[in] expectedModel Model descriptor required by the caller.
 * @param[in] requestedPort Base port of the adjacent pair.
 * @return 1 on success, otherwise 0 after reporting the reason.
 */
int rogueVpiReservePort(int32_t handle, const RogueSimLinkModelDescriptor* expectedModel, uint16_t requestedPort);

/**
 * Destroys a validated handle.
 *
 * @return 1 on success, otherwise 0 after reporting a validation failure.
 */
int rogueVpiDestroy(int32_t handle, const RogueSimLinkModelDescriptor* expectedModel);

/**
 * Collects the argument handles of the currently executing systf call.
 *
 * Iterates vpiArgument of vpi_handle(vpiSysTfCall, NULL), draining and
 * freeing the iterator itself, and reports through vpi_printf when the
 * actual argument count does not match expected.
 *
 * @param[in] name Calling systf name, for diagnostics.
 * @param[out] args Buffer that receives up to expected argument handles.
 * @param[in] expected Required argument count.
 * @return 1 on success, otherwise 0.
 */
int rogueVpiCollectArgs(const char* name, vpiHandle* args, int expected);

/** Reads a scalar or sub-32-bit argument, with X/Z narrowed to 0. */
unsigned int rogueVpiGetU32(vpiHandle arg);

/**
 * Reads a wide vector argument into a little-endian 32-bit word array,
 * validating its width and zero-filling any unused trailing words.
 *
 * @param[in] name Calling systf name, for diagnostics.
 * @param[in] arg Argument handle to read.
 * @param[out] words Destination word array.
 * @param[in] maxWords Capacity of words, in 32-bit words.
 * @param[in] expectedBits Required argument width, in bits.
 * @return 1 on success, otherwise 0 after reporting a width mismatch.
 */
int rogueVpiGetWords(const char* name, vpiHandle arg, uint32_t* words, uint32_t maxWords, uint32_t expectedBits);

/**
 * Writes a scalar or sub-32-bit output argument, validating its width first.
 *
 * @param[in] name Calling systf name, for diagnostics.
 * @param[in] arg Argument handle to write.
 * @param[in] value Value to write, masked to expectedBits.
 * @param[in] expectedBits Required argument width, in bits.
 * @return 1 on success, otherwise 0 after reporting a width mismatch.
 */
int rogueVpiPutU32(const char* name, vpiHandle arg, uint32_t value, uint32_t expectedBits);

/**
 * Writes a wide vector output argument from a little-endian 32-bit word
 * array, validating its width first and masking the final word to its
 * significant bits.
 *
 * @param[in] name Calling systf name, for diagnostics.
 * @param[in] arg Argument handle to write.
 * @param[in] words Source word array.
 * @param[in] expectedBits Required argument width, in bits.
 * @return 1 on success, otherwise 0 after reporting a width mismatch.
 */
int rogueVpiPutWords(const char* name, vpiHandle arg, const uint32_t* words, uint32_t expectedBits);

/** Writes the return value of the currently executing systf function call. */
void rogueVpiReturnInt(int32_t value);

/** Registers a vpiSysFunc/vpiIntFunc system function. */
void rogueVpiRegisterFunction(PLI_BYTE8* name, RogueVpiCalltf calltf);

/** Registers a vpiSysTask system task. */
void rogueVpiRegisterTask(PLI_BYTE8* name, RogueVpiCalltf calltf);

/** Registers the $rogueTcpStream* system tasks/functions. */
void rogueTcpStreamVpiRegister(void);

/** Registers the $rogueTcpMemory* system tasks/functions. */
void rogueTcpMemoryVpiRegister(void);

/** Registers the $rogueSideBand* system tasks/functions. */
void rogueSideBandVpiRegister(void);

#endif
