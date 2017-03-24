#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device AxiStreamDmaRingWrite
#-----------------------------------------------------------------------------
# File       : AxiStreamDmaRingWrite.py
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for AxiStreamDmaRingWrite
# Auto created from ../surf/axi/yaml/AxiStreamDmaRingWrite.yaml
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the 
# top-level directory of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of 'SLAC Firmware Standard Library', including this file, 
# may be copied, modified, propagated, or distributed except according to 
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr
import functools as ft

class AxiStreamDmaRingWrite(pr.Device):
    def __init__(self, numBuffers, msgDestEnum=None, **kwargs):
        super(self.__class__, self).__init__(description='DMA Ring Buffer Manager', **kwargs)

        assert 2 <= numBuffers <= 64, "numBuffers ({:d}) must be between 2 and 64 (inclusive)".format(numBuffers)

        if msgDestEnum is None:
            msgDestEnum = {0: 'Software', 1: 'Auto-Readout'}

        addVariables = ft.partial(self.addVariables, numBuffers)
        addCommands = ft.partial(self.addCommands, numBuffers)

        addVariables(8, name='StartAddr', offset=0x000, bitSize=64, bitOffset=0, base='hex', mode='RW')

        addVariables(8, name='EndAddr', offset=0x200, bitSize=64, bitOffset=0, base='hex', mode='RW')

        addVariables(8, name='WrAddr', offset=0x400, bitSize=64, bitOffset=0, base='hex', mode='RO')

        addVariables(8, name='TriggerAddr', offset=0x600, bitSize=64, bitOffset=0, base='hex', mode='RO')

        addVariables(4, name='BufEnabled', offset=0x800, bitSize=1, bitOffset=0, base='bool', mode='RW')

        addVariables(4, name='BufMode', offset=0x800, enum={0: 'Wrap', 1: 'DoneWhenFull'}, bitSize=1, bitOffset=1, mode='RW')

        addCommands(4, name='BufInit', offset=0x800, bitSize=1, bitOffset=2, mode='RW', function=pr.Command.toggle)

        addCommands(4, name='SoftTrigger', offset=0x800, bitSize=1, bitOffset=3, function=pr.Command.toggle)

        addVariables(4, name='MsgDest',  offset=0x800, enum=msgDestEnum, bitSize=4, bitOffset=4, mode='RW')

        addVariables(4, name='FramesAfterTrigger', offset=0x800, bitSize=16, bitOffset=16, base='hex', mode='RW')

        addVariables(4, name='Empty', offset=0xa00, bitSize=1, bitOffset=0, base='bool', mode='RO')

        addVariables(4, name='Full', offset=0xa00, bitSize=1, bitOffset=1, base='bool', mode='RO')

        addVariables(4, name='Done', offset=0xa00, bitSize=1, bitOffset=2, base='bool', mode='RO')

        addVariables(4, name='Triggered', offset=0xa00, bitSize=1, bitOffset=3, base='bool', mode='RO')

        addVariables(4, name='Error', offset=0xa00, bitSize=1, bitOffset=4, base='bool', mode='RO')

        addVariables(4, name='BurstSize', offset=0xa00, bitSize=4, bitOffset=8, base='hex', mode='RO')

        addVariables(4, name='FramesSinceTrigger', offset=0xa00, bitSize=16, bitOffset=16, base='hex', mode='RO')

        @self.command()
        def SoftTriggerAll(dev, cmd, arg):
            for t in self.SoftTrigger.values():
                self.t()

    def _softReset(self):
        for c in self.BufInit.values():
            c()
