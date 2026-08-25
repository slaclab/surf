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
// Minimal Synopsys-style VHPI declarations for native compile and lifecycle
// tests. Production VCS builds use the vendor's vhpi_user.h.
//////////////////////////////////////////////////////////////////////////////

#ifndef TESTS_SIMLINK_VCS_VHPI_USER_H
#define TESTS_SIMLINK_VCS_VHPI_USER_H

#include <stddef.h>
#include <stdint.h>

typedef uintptr_t vhpiHandleT;
typedef int32_t vhpiIntT;
typedef uint32_t vhpiEnumT;

typedef struct {
    int32_t high;
    uint32_t low;
} vhpiTimeT;

typedef struct {
    int format;
    size_t bufSize;
    union {
        vhpiEnumT enumval;
        vhpiEnumT *enums;
    } value;
} vhpiValueT;

typedef struct vhpiCbDataS {
    int reason;
    vhpiHandleT obj;
    vhpiValueT *value;
    void (*cbf)(struct vhpiCbDataS *);
    vhpiTimeT *time;
    void *user_data;
} vhpiCbDataT;

typedef struct {
    const char *str;
    const char *message;
} vhpiErrorInfoT;

enum {
    vhpiIn = 1,
    vhpiOut = 2,
    vhpiEnumVal = 3,
    vhpiEnumVecVal = 4,
    vhpiFullNameP = 5,
    vhpiSizeP = 6,
    vhpiModeP = 7,
    vhpiPortDecls = 8,
    vhpiForcePropagate = 9,
    vhpiCbValueChange = 1001,
    vhpiCbEndOfSimulation = 1035,
    vhpiCbPLIError = 1037,
    vhpiReturnCb = 1,
    vhpiFatal = 2,
};

void vhpi_assert(const char *message, int severity);
int vhpi_chk_error(vhpiErrorInfoT *error);
int vhpi_printf(const char *format, ...);
vhpiHandleT vhpi_register_cb(vhpiCbDataT *cbData, int flags);
int vhpi_remove_cb(vhpiHandleT callback);
int vhpi_release_handle(vhpiHandleT handle);
vhpiHandleT vhpi_handle_by_index(int relation,
                                 vhpiHandleT parent,
                                 int index);
char *vhpi_get_str(int property, vhpiHandleT handle);
vhpiIntT vhpi_get(int property, vhpiHandleT handle);
int vhpi_value_size(vhpiHandleT handle, int format);
int vhpi_get_value(vhpiHandleT handle, vhpiValueT *value);
int vhpi_put_value(vhpiHandleT handle, vhpiValueT *value, int mode);
// Match the simulator VHPI ABI, which specifies long for the cycle count.
void vhpi_get_time(vhpiTimeT *time, long *cycles);  // NOLINT(runtime/int)

#endif
