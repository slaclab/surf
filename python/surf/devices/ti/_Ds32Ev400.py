#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class Ds32Ev400(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name         = 'SmBusEnable',
            description  = '0: Disabled, 1: Enabled',
            offset       = (0x07 << 2),
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'SD',
            description  = 'Signal Detect',
            offset       = (0x00 << 2),
            bitSize      = 4,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'ID',
            description  = 'ID Revision',
            offset       = (0x00 << 2),
            bitSize      = 4,
            bitOffset    = 4,
            mode         = 'RO',
        ))

        regOffset    = [0x1,0x1,0x2,0x2]
        regBitOffset = [  3,  7,  3,  7]
        for i in range(4):
            self.add(pr.RemoteVariable(
                name         = f'ExternalEn[{i}]',
                description  = 'Enable status',
                offset       = (regOffset[i] << 2),
                bitSize      = 1,
                bitOffset    = regBitOffset[i],
                mode         = 'RO',
            ))

        regOffset    = [0x1,0x1,0x2,0x2]
        regBitOffset = [  0,  4,  0,  4]
        for i in range(4):
            self.add(pr.RemoteVariable(
                name         = f'ExternalBoost[{i}]',
                description  = 'Boost status',
                offset       = (regOffset[i] << 2),
                bitSize      = 3,
                bitOffset    = regBitOffset[i],
                mode         = 'RO',
            ))

        regOffset    = [0x3,0x3,0x4,0x4]
        regBitOffset = [  3,  7,  3,  7]
        for i in range(4):
            self.add(pr.RemoteVariable(
                name         = f'OeL[{i}]',
                description  = 'Enable status',
                offset       = (regOffset[i] << 2),
                bitSize      = 1,
                bitOffset    = regBitOffset[i],
                mode         = 'RW',
            ))

        regOffset    = [0x3,0x3,0x4,0x4]
        regBitOffset = [  0,  4,  0,  4]
        for i in range(4):
            self.add(pr.RemoteVariable(
                name         = f'BoostControl[{i}]',
                description  = 'BST_N setting controlled by SMBus',
                offset       = (regOffset[i] << 2),
                bitSize      = 3,
                bitOffset    = regBitOffset[i],
                mode         = 'RW',
            ))

        for i in range(4):

            self.add(pr.RemoteVariable(
                name         = f'SdOnThreshold[{i}]',
                description  = 'Signal Detect ON threshold',
                offset       = (0x05 << 2),
                bitSize      = 2,
                bitOffset    = 2*i,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = f'SdOffThreshold[{i}]',
                description  = 'Signal Detect OFF threshold',
                offset       = (0x06 << 2),
                bitSize      = 2,
                bitOffset    = 2*i,
                mode         = 'RW',
            ))

        self.add(pr.RemoteVariable(
            name         = 'OutputLevel',
            description  = 'Sets the output diff. swing',
            offset       = (0x08 << 2),
            bitSize      = 2,
            bitOffset    = 2,
            mode         = 'RW',
        ))
