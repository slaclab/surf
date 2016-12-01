#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device AxiStreamDmaRingWrite
#-----------------------------------------------------------------------------
# File       : AxiStreamDmaRingWrite.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-12-01
# Last update: 2016-12-01
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

def create(name='axiStreamDmaRingWrite', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x1000,
                         description='DMA Ring Buffer Manager')

    dev.add(pyrogue.Variable(name='startAddr_0',
                             description='',
                             hidden=False, enum=None, offset=0x0, bitSize=64, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='startAddr_1',
                             description='',
                             hidden=False, enum=None, offset=0x8, bitSize=64, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='startAddr_2',
                             description='',
                             hidden=False, enum=None, offset=0x10, bitSize=64, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='startAddr_3',
                             description='',
                             hidden=False, enum=None, offset=0x18, bitSize=64, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='endAddr_0',
                             description='',
                             hidden=False, enum=None, offset=0x200, bitSize=64, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='endAddr_1',
                             description='',
                             hidden=False, enum=None, offset=0x208, bitSize=64, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='endAddr_2',
                             description='',
                             hidden=False, enum=None, offset=0x210, bitSize=64, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='endAddr_3',
                             description='',
                             hidden=False, enum=None, offset=0x218, bitSize=64, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='wrAddr_0',
                             description='',
                             hidden=False, enum=None, offset=0x400, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='wrAddr_1',
                             description='',
                             hidden=False, enum=None, offset=0x408, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='wrAddr_2',
                             description='',
                             hidden=False, enum=None, offset=0x410, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='wrAddr_3',
                             description='',
                             hidden=False, enum=None, offset=0x418, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='triggerAddr_0',
                             description='',
                             hidden=False, enum=None, offset=0x600, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='triggerAddr_1',
                             description='',
                             hidden=False, enum=None, offset=0x608, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='triggerAddr_2',
                             description='',
                             hidden=False, enum=None, offset=0x610, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='triggerAddr_3',
                             description='',
                             hidden=False, enum=None, offset=0x618, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='enabled_0',
                             description='',
                             hidden=False, enum=None, offset=0x800, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='enabled_1',
                             description='',
                             hidden=False, enum=None, offset=0x804, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='enabled_2',
                             description='',
                             hidden=False, enum=None, offset=0x808, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='enabled_3',
                             description='',
                             hidden=False, enum=None, offset=0x80c, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='mode_0',
                             description='',
                             hidden=False, enum={0: 'Wrap', 1: 'DoneWhenFull'}, offset=0x800, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='mode_1',
                             description='',
                             hidden=False, enum={0: 'Wrap', 1: 'DoneWhenFull'}, offset=0x804, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='mode_2',
                             description='',
                             hidden=False, enum={0: 'Wrap', 1: 'DoneWhenFull'}, offset=0x808, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='mode_3',
                             description='',
                             hidden=False, enum={0: 'Wrap', 1: 'DoneWhenFull'}, offset=0x80c, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='init_0',
                             description='',
                             hidden=True, enum=None, offset=0x800, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='init_1',
                             description='',
                             hidden=True, enum=None, offset=0x804, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='init_2',
                             description='',
                             hidden=True, enum=None, offset=0x808, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='init_3',
                             description='',
                             hidden=True, enum=None, offset=0x80c, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='softTrigger_0',
                             description='',
                             hidden=True, enum=None, offset=0x800, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='softTrigger_1',
                             description='',
                             hidden=True, enum=None, offset=0x804, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='softTrigger_2',
                             description='',
                             hidden=True, enum=None, offset=0x808, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='softTrigger_3',
                             description='',
                             hidden=True, enum=None, offset=0x80c, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='msgDest_0',
                             description='',
                             hidden=True, enum={0: 'Software', 1: 'Auto-Readout'}, offset=0x800, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='msgDest_1',
                             description='',
                             hidden=True, enum={0: 'Software', 1: 'Auto-Readout'}, offset=0x804, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='msgDest_2',
                             description='',
                             hidden=True, enum={0: 'Software', 1: 'Auto-Readout'}, offset=0x808, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='msgDest_3',
                             description='',
                             hidden=True, enum={0: 'Software', 1: 'Auto-Readout'}, offset=0x80c, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='framesAfterTrigger_0',
                             description='',
                             hidden=False, enum=None, offset=0x800, bitSize=16, bitOffset=16, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='framesAfterTrigger_1',
                             description='',
                             hidden=False, enum=None, offset=0x804, bitSize=16, bitOffset=16, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='framesAfterTrigger_2',
                             description='',
                             hidden=False, enum=None, offset=0x808, bitSize=16, bitOffset=16, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='framesAfterTrigger_3',
                             description='',
                             hidden=False, enum=None, offset=0x80c, bitSize=16, bitOffset=16, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='empty_0',
                             description='',
                             hidden=False, enum=None, offset=0xa00, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='empty_1',
                             description='',
                             hidden=False, enum=None, offset=0xa04, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='empty_2',
                             description='',
                             hidden=False, enum=None, offset=0xa08, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='empty_3',
                             description='',
                             hidden=False, enum=None, offset=0xa0c, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='full_0',
                             description='',
                             hidden=False, enum=None, offset=0xa00, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='full_1',
                             description='',
                             hidden=False, enum=None, offset=0xa04, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='full_2',
                             description='',
                             hidden=False, enum=None, offset=0xa08, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='full_3',
                             description='',
                             hidden=False, enum=None, offset=0xa0c, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='done_0',
                             description='',
                             hidden=False, enum=None, offset=0xa00, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='done_1',
                             description='',
                             hidden=False, enum=None, offset=0xa04, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='done_2',
                             description='',
                             hidden=False, enum=None, offset=0xa08, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='done_3',
                             description='',
                             hidden=False, enum=None, offset=0xa0c, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='triggered_0',
                             description='',
                             hidden=False, enum=None, offset=0xa00, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='triggered_1',
                             description='',
                             hidden=False, enum=None, offset=0xa04, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='triggered_2',
                             description='',
                             hidden=False, enum=None, offset=0xa08, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='triggered_3',
                             description='',
                             hidden=False, enum=None, offset=0xa0c, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='error_0',
                             description='',
                             hidden=False, enum=None, offset=0xa00, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='error_1',
                             description='',
                             hidden=False, enum=None, offset=0xa04, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='error_2',
                             description='',
                             hidden=False, enum=None, offset=0xa08, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='error_3',
                             description='',
                             hidden=False, enum=None, offset=0xa0c, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='burstSize',
                             description='',
                             hidden=False, enum=None, offset=0xa00, bitSize=4, bitOffset=8, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='framesSinceTrigger_0',
                             description='',
                             hidden=False, enum=None, offset=0xa00, bitSize=16, bitOffset=16, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='framesSinceTrigger_1',
                             description='',
                             hidden=False, enum=None, offset=0xa04, bitSize=16, bitOffset=16, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='framesSinceTrigger_2',
                             description='',
                             hidden=False, enum=None, offset=0xa08, bitSize=16, bitOffset=16, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='framesSinceTrigger_3',
                             description='',
                             hidden=False, enum=None, offset=0xa0c, bitSize=16, bitOffset=16, base='uint', mode='RO'))

    dev.add(pyrogue.Command(name='initialize',
                            description='Initialize the buffer. Reset the write pointer to StartAddr. Clear the Done field.',
                            hidden=False, base='None',
                            function="""\
                                     dev.init_0.set(1)
                                     dev.init_1.set(1)
                                     dev.init_2.set(1)
                                     dev.init_3.set(1)
                                     dev.init_0.set(0)
                                     dev.init_1.set(0)
                                     dev.init_2.set(0)
                                     dev.init_3.set(0)
                                     """))

    dev.add(pyrogue.Command(name='c_SoftTrigger',
                            description='Send a trigger to the buffer',
                            hidden=False, base='None',
                            function="""\
                                     dev.softTrigger.set(1)
                                     dev.softTrigger.set(0)
                                     """))

    dev.add(pyrogue.Command(name='softTriggerAll',
                            description='Send a trigger to the buffer',
                            hidden=False, base='None',
                            function="""\
                                     dev.softTrigger.set(1)
                                     """))

    return dev
