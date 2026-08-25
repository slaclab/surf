//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Firmware Standard Library', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#include <stdint.h>
#include <string.h>

#include "RogueDpiInstance.h"
#include "RogueTcpStreamCore.h"

int simLinkNativeStreamSend(void* context, uint32_t size) {
    RogueTcpStreamData* data = rogueDpiGetData(context, &ROGUE_TCP_STREAM_MODEL);

    if (data == NULL || size > ROGUE_TCP_STREAM_MAX_FRAME) return 0;
    memset(data->ibData, 0xA5, size);
    data->ibSize = size;
    return RogueTcpStreamSend(data);
}
