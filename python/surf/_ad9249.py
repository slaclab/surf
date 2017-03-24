#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue _ad9249 Module
#-----------------------------------------------------------------------------
# File       : _ad9249.py
# Created    : 2017-01-17
# Last update: 2017-01-17
#-----------------------------------------------------------------------------
# Description:
# PyRogue _ad9249 Module
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
import math

class Ad9249ConfigGroup(pr.Device):
    def __init__(self, **kwargs):
        super(self.__class__, self).__init__(description="Configure one side of an AD9249 ADC",
                                             **kwargs)

        # AD9249 bank configuration registers
        self.add(pr.Variable(name="ChipId", offset=0x04, bitSize=8, bitOffset=0, mode="RO"))
        self.add(pr.Variable(name="ChipGrade", offset=0x08, bitSize=3, bitOffset=4, mode="RO"))

        
        self.add(pr.Variable(name="ExternalPdwnMode", offset=0x20, bitSize=1, bitOffset=5, base='enum',
                             enum = {0:"Full Power Down", 1: "Standby"}))
        self.add(pr.Variable(name="InternalPdwnMode", offset=0x20, bitSize=2, bitOffset=0, base='enum',
                             enum = {0:"Chip Run", 1: "Full Power Down", 2: "Standby", 3: "Digital Reset"}))
        self.add(pr.Variable(name="DutyCycleStabilizer", offset=0x24, bitSize=1, bitOffset=0, base='enum',
                             enum = {0:"Off", 1: "On"}))

        self.add(pr.Variable(name='ClockDivide', offset=(0xb*4), bitSize=3, bitOffset=0, base='enum',
                             enum={i : "Divide by {:d}".format(i+1) for i in range(8)}))

        self.add(pr.Variable(name='ChopMode', offset=(0x0c*4), bitSize=1, bitOffset=2, base='enum',
                             enum={0: 'off', 1: 'on'}))

        self.add(pr.Variable(name="DevIndexMask[7:4]", offset=0x10, bitSize=4, bitOffset=0, mode='RW', base='bin'))
        self.add(pr.Variable(name="DevIndexMask[3:0]", offset=0x14, bitSize=4, bitOffset=0, mode='RW', base='bin'))
        self.add(pr.Variable(name="DevIndexMask[DCO:FCO]", offset=0x14, bitSize=2, bitOffset=0x4, mode='RW', base='bin'))                
                

        self.add(pr.Variable(name='UserTestModeCfg', offset=(0x0D*4), bitSize=2, bitOffset=6, base='enum',
                             enum={0: 'single', 1: 'alternate', 2: 'single once', 3: 'alternate once'}))
        

        self.add(pr.Variable(name="OutputTestMode", offset=(0x0D*4), bitSize=4, bitOffset=0, mode='RW', base='enum',
                             enum={0: "Off", 1: "Midscale Short", 2: "Positive FS", 3: "Negative FS",
                                    4: "Alternating checkerboard", 5: "PN23", 6: "PN9", 7: "1/0-word toggle",
                                    8: "User Input", 9: "1/0-bit Toggle", 10: "1x sync", 11: "One bit high",
                                    12: "mixed bit frequency"}))

        self.add(pr.Variable(name='OffsetAdjust', offset=(0x10*4), bitSize=8, bitOffset=0))

        self.add(pr.Variable(name='OutputInvert', offset=(0x14*4), bitSize=1, bitOffset=2, base='bool'))
        self.add(pr.Variable(name='OutputFormat', offset=(0x14*4), bitSize=1, bitOffset=0, base='enum',
                             enum={1: 'Twos Compliment', 0: 'Offset Binary'}))

                     

class Ad9249ChipConfig(pr.Device):
    def __init__(self, **kwargs):
        super(self.__class__, self).__init__(description="Configure one side of an AD9249 ADC",
                                             **kwargs)

        self.add(Ad9249ConfigGroup("BankConfig[0]", 0x0000));
        self.add(Ad9249ConfigGroup("BankConfig[1]", 0x0200));        

        
class Ad9249Config(pr.Device):

    def __init__(self, chips=1, **kwargs):
        super(self.__class__, self).__init__(description="Configuration of Ad9249 ADC",
                                             **kwargs)

        PDWN_ADDR = int(pow(2,11+math.log(chips*2,2)))
        
        # First add all of the powerdown GPIOs
        if chips == 1:
            self.add(pr.Variable(name = "Pdwn",
                                 description = "Power down chip ",
                                 offset = PDWN_ADDR,
                                 bitSize = 1,
                                 bitOffset = 0,
                                 base = 'bool',
                                 mode = "RW"))
            self.add(Ad9249ConfigGroup(name="BankConfig[0]", offset=0x0000));
            self.add(Ad9249ConfigGroup(name="BankConfig[1]", offset=0x0800));
        else:
            for i in range(chips):
                self.add(pr.Variable(name = "Pdwn" + chip,
                                     description = "Power down chip " + chip,
                                     offset = PDWN_ADDR + (i*4),
                                     bitSize = 1,
                                     bitOffset = 0,
                                     base = 'bool',
                                     mode = "RW"))
                self.add(Ad9249ChipConfig(name="Ad9249Chip[{:d}]".format(chip), offset=(i*(0x800))))
  

class Ad9249ReadoutGroup(pr.Device):
    def __init__(self, channels=8, **kwargs):

        assert (channels > 0 and channels <= 8), "channels (%r) must be between 0 and 8" % (channels)
        
        super(self.__class__, self).__init__(description="Configure readout of 1 bank of an AD9249",
                                             **kwargs)
        
        for i in range(channels):
            self.add(pr.Variable(name="ChannelDelay["+str(i)+"]",
                                 description = "IDELAY value for serial channel " + str(i),
                                 offset = i*4,
                                 bitSize = 5,
                                 bitOffset = 0,
                                 base = 'hex',
                                 mode = 'RW'))

        self.add(pr.Variable(name="FrameDelay",
                                 description = "IDELAY value for FCO",
                                 offset = 0x20,
                                 bitSize = 5,
                                 bitOffset = 0,
                                 base = 'hex',
                                 mode = 'RW'))

        self.add(pr.Variable(name="LostLockCount",
                             description = "Number of times that frame lock has been lost since reset",
                             offset = 0x30,
                             bitSize = 16,
                             bitOffset = 0,
                             base = 'int',
                             mode = "RO"))
        
        self.add(pr.Variable(name="Locked",
                             description = "Readout has locked on to the frame boundary",
                             offset = 0x30,
                             bitSize = 1,
                             bitOffset = 16,
                             base = 'bool',
                             mode = "RO"))
        
        self.add(pr.Variable(name="AdcFrame",
                             description = "Last deserialized FCO value for debug",
                             offset = 0x34,
                             bitSize = 16,
                             bitOffset = 0,
                             base = 'hex',
                             mode = "RO"))

        for i in range(channels):
            self.add(pr.Variable(name="AdcChannel[{:d}]".format(i),
                                 description = 'Last deserialized channel {:d} ADC value for debug'.format(i),
                                 offset = 0x80 + (i*4),
                                 bitSize = 32,
                                 bitOffset = 0,
                                 base = 'hex',
                                 mode = "RO"))
            
        self.add(pr.Command(name="LostLockCountReset",
                            description = "Reset LostLockCount",
                            function = pr.Command.toggle,
                            offset = 0x38,
                            bitSize = 1,
                            bitOffset = 0))

        

        
                             
        
        
