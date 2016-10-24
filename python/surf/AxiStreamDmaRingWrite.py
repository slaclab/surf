#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device AxiStreamDmaRingWrite
#-----------------------------------------------------------------------------
# File       : AxiStreamDmaRingWrite.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-10-24
# Last update: 2016-10-24
#-----------------------------------------------------------------------------
# Description:
# Device creator for AxiStreamDmaRingWrite
# Auto created from ../surf/axi/yaml/AxiStreamDmaRingWrite.yaml
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the rogue software platform, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue

def create(name, offset, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x1000,
                         description='DMA Ring Buffer Manager')

    dev.add(pyrogue.Variable(name='StartAddr_0',
                             description='',
                             hidden=False, enum=None, offset=0x0, bitSize=64, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='StartAddr_1',
                             description='',
                             hidden=False, enum=None, offset=0x8, bitSize=64, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='StartAddr_2',
                             description='',
                             hidden=False, enum=None, offset=0x10, bitSize=64, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='StartAddr_3',
                             description='',
                             hidden=False, enum=None, offset=0x18, bitSize=64, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='EndAddr_0',
                             description='',
                             hidden=False, enum=None, offset=0x200, bitSize=64, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='EndAddr_1',
                             description='',
                             hidden=False, enum=None, offset=0x208, bitSize=64, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='EndAddr_2',
                             description='',
                             hidden=False, enum=None, offset=0x210, bitSize=64, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='EndAddr_3',
                             description='',
                             hidden=False, enum=None, offset=0x218, bitSize=64, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='WrAddr_0',
                             description='',
                             hidden=False, enum=None, offset=0x400, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='WrAddr_1',
                             description='',
                             hidden=False, enum=None, offset=0x408, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='WrAddr_2',
                             description='',
                             hidden=False, enum=None, offset=0x410, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='WrAddr_3',
                             description='',
                             hidden=False, enum=None, offset=0x418, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='TriggerAddr_0',
                             description='',
                             hidden=False, enum=None, offset=0x600, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='TriggerAddr_1',
                             description='',
                             hidden=False, enum=None, offset=0x608, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='TriggerAddr_2',
                             description='',
                             hidden=False, enum=None, offset=0x610, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='TriggerAddr_3',
                             description='',
                             hidden=False, enum=None, offset=0x618, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Enabled_0',
                             description='',
                             hidden=False, enum=None, offset=0x800, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Enabled_1',
                             description='',
                             hidden=False, enum=None, offset=0x804, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Enabled_2',
                             description='',
                             hidden=False, enum=None, offset=0x808, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Enabled_3',
                             description='',
                             hidden=False, enum=None, offset=0x80c, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Mode_0',
                             description='',
                             hidden=False, enum={0: 'Wrap', 1: 'DoneWhenFull'}, offset=0x800, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Mode_1',
                             description='',
                             hidden=False, enum={0: 'Wrap', 1: 'DoneWhenFull'}, offset=0x804, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Mode_2',
                             description='',
                             hidden=False, enum={0: 'Wrap', 1: 'DoneWhenFull'}, offset=0x808, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Mode_3',
                             description='',
                             hidden=False, enum={0: 'Wrap', 1: 'DoneWhenFull'}, offset=0x80c, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Init_0',
                             description='',
                             hidden=True, enum=None, offset=0x800, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Init_1',
                             description='',
                             hidden=True, enum=None, offset=0x804, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Init_2',
                             description='',
                             hidden=True, enum=None, offset=0x808, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Init_3',
                             description='',
                             hidden=True, enum=None, offset=0x80c, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SoftTrigger_0',
                             description='',
                             hidden=True, enum=None, offset=0x800, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SoftTrigger_1',
                             description='',
                             hidden=True, enum=None, offset=0x804, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SoftTrigger_2',
                             description='',
                             hidden=True, enum=None, offset=0x808, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SoftTrigger_3',
                             description='',
                             hidden=True, enum=None, offset=0x80c, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='MsgDest_0',
                             description='',
                             hidden=True, enum={0: 'Software', 1: 'Auto-Readout'}, offset=0x800, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='MsgDest_1',
                             description='',
                             hidden=True, enum={0: 'Software', 1: 'Auto-Readout'}, offset=0x804, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='MsgDest_2',
                             description='',
                             hidden=True, enum={0: 'Software', 1: 'Auto-Readout'}, offset=0x808, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='MsgDest_3',
                             description='',
                             hidden=True, enum={0: 'Software', 1: 'Auto-Readout'}, offset=0x80c, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='FramesAfterTrigger_0',
                             description='',
                             hidden=False, enum=None, offset=0x200, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='FramesAfterTrigger_1',
                             description='',
                             hidden=False, enum=None, offset=0x204, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='FramesAfterTrigger_2',
                             description='',
                             hidden=False, enum=None, offset=0x208, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='FramesAfterTrigger_3',
                             description='',
                             hidden=False, enum=None, offset=0x20c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Empty_0',
                             description='',
                             hidden=False, enum=None, offset=0xa00, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Empty_1',
                             description='',
                             hidden=False, enum=None, offset=0xa04, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Empty_2',
                             description='',
                             hidden=False, enum=None, offset=0xa08, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Empty_3',
                             description='',
                             hidden=False, enum=None, offset=0xa0c, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Full_0',
                             description='',
                             hidden=False, enum=None, offset=0xa00, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Full_1',
                             description='',
                             hidden=False, enum=None, offset=0xa04, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Full_2',
                             description='',
                             hidden=False, enum=None, offset=0xa08, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Full_3',
                             description='',
                             hidden=False, enum=None, offset=0xa0c, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Done_0',
                             description='',
                             hidden=False, enum=None, offset=0xa00, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Done_1',
                             description='',
                             hidden=False, enum=None, offset=0xa04, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Done_2',
                             description='',
                             hidden=False, enum=None, offset=0xa08, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Done_3',
                             description='',
                             hidden=False, enum=None, offset=0xa0c, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Triggered_0',
                             description='',
                             hidden=False, enum=None, offset=0xa00, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Triggered_1',
                             description='',
                             hidden=False, enum=None, offset=0xa04, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Triggered_2',
                             description='',
                             hidden=False, enum=None, offset=0xa08, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Triggered_3',
                             description='',
                             hidden=False, enum=None, offset=0xa0c, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Error_0',
                             description='',
                             hidden=False, enum=None, offset=0xa00, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Error_1',
                             description='',
                             hidden=False, enum=None, offset=0xa04, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Error_2',
                             description='',
                             hidden=False, enum=None, offset=0xa08, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Error_3',
                             description='',
                             hidden=False, enum=None, offset=0xa0c, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='BurstSize',
                             description='',
                             hidden=False, enum=None, offset=0x280, bitSize=4, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='FramesSinceTrigger_0',
                             description='',
                             hidden=False, enum=None, offset=0x280, bitSize=16, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='FramesSinceTrigger_1',
                             description='',
                             hidden=False, enum=None, offset=0x284, bitSize=16, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='FramesSinceTrigger_2',
                             description='',
                             hidden=False, enum=None, offset=0x288, bitSize=16, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='FramesSinceTrigger_3',
                             description='',
                             hidden=False, enum=None, offset=0x28c, bitSize=16, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Command(name='Initialize',
                            description='Initialize the buffer. Reset the write pointer to StartAddr. Clear the Done field.',
                            hidden=False, base=None,
                            function="""\
                                     dev.Init_0.set(1)
                                     dev.Init_1.set(1)
                                     dev.Init_2.set(1)
                                     dev.Init_3.set(1)
                                     dev.Init_0.set(0)
                                     dev.Init_1.set(0)
                                     dev.Init_2.set(0)
                                     dev.Init_3.set(0)
                                     """

    dev.add(pyrogue.Command(name='C_SoftTrigger',
                            description='Send a trigger to the buffer',
                            hidden=False, base=None,
                            function="""\
                                     dev.SoftTrigger.set(1)
                                     dev.SoftTrigger.set(0)
                                     """

    dev.add(pyrogue.Command(name='SoftTriggerAll',
                            description='Send a trigger to the buffer',
                            hidden=False, base=None,
                            function="""\
                                     dev.SoftTrigger.set(1)
                                     """

