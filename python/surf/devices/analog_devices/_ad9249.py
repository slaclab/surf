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
import rogue.interfaces.memory as rim
import math

class Ad9249ConfigGroup(pr.Device):
    def __init__(self,       
            name        = 'Ad9249ConfigGroup',
            description = 'Configure one side of an AD9249 ADC',
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)                                             
                                             
        # AD9249 bank configuration registers
        self.add(pr.RemoteVariable(
            name        = 'ChipId', 
            offset      = 0x04, 
            bitSize     = 8, 
            bitOffset   = 0, 
            mode        = 'RO',
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'ChipGrade', 
            offset      = 0x08, 
            bitSize     = 3, 
            bitOffset   = 4, 
            mode        = 'RO',
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'ExternalPdwnMode', 
            offset      = 0x20, 
            bitSize     = 1, 
            bitOffset   = 5, 
            enum        = {
                0: 'Full Power Down', 
                1: 'Standby',
            },
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'InternalPdwnMode', 
            offset      = 0x20, 
            bitSize     = 2, 
            bitOffset   = 0, 
            enum        = {
                0: 'Chip Run', 
                1: 'Full Power Down', 
                2: 'Standby', 
                3: 'Digital Reset',
            },
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'DutyCycleStabilizer', 
            offset      = 0x24, 
            bitSize     = 1, 
            bitOffset   = 0, 
            enum        = {
                0: 'Off', 
                1: 'On',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'ClockDivide', 
            offset      = (0xb*4), 
            bitSize     = 3, 
            bitOffset   = 0, 
            enum        = {i : f'Divide by {i+1}' for i in range(8)},
        ))

        self.add(pr.RemoteVariable(
            name        = 'ChopMode', 
            offset      = (0x0c*4), 
            bitSize     = 1, 
            bitOffset   = 2, 
            enum        = {
                0: 'Off', 
                1: 'On',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'DevIndexMask[7:0]', 
            offset      = [0x10, 0x14],
            bitSize     = 4, 
            bitOffset   = 0, 
            mode        = 'RW',
            disp        = '{:#b}',
            base        = pr.UInt,
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'DevIndexMask[DCO:FCO]', 
            offset      = 0x14, 
            bitSize     = 2, 
            bitOffset   = 0x4, 
            mode        = 'RW',
            disp        = '{:#b}',
            base        = pr.UInt,
        ))                

        self.add(pr.RemoteVariable(
            name        = 'UserTestModeCfg', 
            offset      = (0x0D*4), 
            bitSize     = 2, 
            bitOffset   = 6, 
            enum        = {
                0: 'single', 
                1: 'alternate', 
                2: 'single once', 
                3: 'alternate once',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'OutputTestMode', 
            offset      = (0x0D*4), 
            bitSize     = 4, 
            bitOffset   = 0, 
            mode        = 'RW', 
            enum        = {
                0: 'Off', 
                1: 'Midscale Short', 
                2: 'Positive FS', 
                3: 'Negative FS',
                4: 'Alternating checkerboard', 
                5: 'PN23', 
                6: 'PN9', 
                7: '1/0-word toggle',
                8: 'User Input', 
                9: '1/0-bit Toggle', 
                10: '1x sync', 
                11: 'One bit high',
                12: 'mixed bit frequency',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'OffsetAdjust', 
            offset      = (0x10*4), 
            bitSize     = 8, 
            bitOffset   = 0,
        ))

        self.add(pr.RemoteVariable(
            name        = 'OutputInvert', 
            offset      = (0x14*4), 
            bitSize     = 1, 
            bitOffset   = 2, 
            base        = pr.Bool,
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'OutputFormat', 
            offset      = (0x14*4), 
            bitSize     = 1, 
            bitOffset   = 0, 
            enum        = {
                1: 'Twos Compliment', 
                0: 'Offset Binary',
            },
        ))

class Ad9249ChipConfig(pr.Device):
    def __init__(self,       
            name        = 'Ad9249ChipConfig',
            description = 'Configure one side of an AD9249 ADC',
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)   
        self.add(Ad9249ConfigGroup('BankConfig[0]', 0x0000));
        self.add(Ad9249ConfigGroup('BankConfig[1]', 0x0200));        
        
class Ad9249Config(pr.Device):
    def __init__(self,       
            name        = 'Ad9249Config',
            description = 'Configuration of Ad9249 AD',
            chips       = 1,
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)   

        PDWN_ADDR = int(pow(2,11+math.log(chips*2,2)))
        
        # First add all of the power down GPIOs
        if chips == 1:
            self.add(pr.RemoteVariable(
                name        = 'Pdwn',
                description = 'Power down chip ',
                offset      = PDWN_ADDR,
                bitSize     = 1,
                bitOffset   = 0,
                base        = pr.Bool,
                mode        = 'RW',
             ))
            self.add(Ad9249ConfigGroup(name='BankConfig[0]', offset=0x0000));
            self.add(Ad9249ConfigGroup(name='BankConfig[1]', offset=0x0800));
        else:
            for i in range(chips):
                self.add(pr.RemoteVariable(
                    name        = f'Pdwn{i}',
                    description = f'Power down chip {i}',
                    offset      = PDWN_ADDR + (i*4),
                    bitSize     = 1,
                    bitOffset   = 0,
                    base        = pr.Bool,
                    mode        = 'RW',
                ))
                self.add(Ad9249ConfigGroup(name=f'Ad9249Chip[{i}].BankConfig[0]', offset=i*0x1000));
                self.add(Ad9249ConfigGroup(name=f'Ad9249Chip[{i}].BankConfig[1]', offset=i*0x1000+0x0800));

class Ad9249ReadoutGroup(pr.Device):
    def __init__(self,       
            name        = 'Ad9249ReadoutGroup',
            description = 'Configure readout of 1 bank of an AD9249',
            channels    = 8,
            **kwargs):
        assert (channels > 0 and channels <= 8), f'channels ({channels}) must be between 0 and 8'
        super().__init__(name=name, description=description, **kwargs)   
        
        for i in range(channels):
            self.add(pr.RemoteVariable(
                name        = f'ChannelDelay[{i}]',
                description = f'IDELAY value for serial channel {i}',
                offset      = i*4,
                bitSize     = 5,
                bitOffset   = 0,
                base        = pr.UInt,
                mode        = 'RW',
            ))

        self.add(pr.RemoteVariable(
            name        = 'FrameDelay',
            description = 'IDELAY value for FCO',
            offset      = 0x20,
            bitSize     = 5,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LostLockCount',
            description = 'Number of times that frame lock has been lost since reset',
            offset      = 0x30,
            bitSize     = 16,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'Locked',
            description = 'Readout has locked on to the frame boundary',
            offset      = 0x30,
            bitSize     = 1,
            bitOffset   = 16,
            base        = pr.Bool,
            mode        = 'RO',
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'AdcFrame',
            description = 'Last deserialized FCO value for debug',
            offset      = 0x34,
            bitSize     = 16,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))

        for i in range(channels):
            self.add(pr.RemoteVariable(
                name        = f'AdcChannel[{i:d}]',
                description = f'Last deserialized channel {i:d} ADC value for debug',
                offset      = 0x80 + (i*4),
                bitSize     = 32,
                bitOffset   = 0,
                base        = pr.UInt,
                disp        = '{:_x}',
                mode        = 'RO',
            ))

        self.add(pr.RemoteCommand(
            name        = 'LostLockCountReset',
            description = 'Reset LostLockCount',
            function    = pr.BaseCommand.toggle,
            offset      = 0x38,
            bitSize     = 1,
            bitOffset   = 0,
        ))

        self.add(pr.RemoteCommand(
            name='FreezeDebug',
            description='Freeze all of the AdcChannel registers',
            hidden=True,
            offset=0xA0,
            bitSize=1,
            bitOffset=0,
            base=pr.UInt,
            function=pr.RemoteCommand.touch))

    def readBlocks(self, recurse=True, variable=None):
        if variable is not None:
            variable._block.backgroundTransaction(rim.Read)
        else:
            self.FreezeDebug(1)
            for block in self._blocks:
                if block.bulkEn:
                    block.backgroundTransaction(rim.Read)
            self.FreezeDebug(0)

            if recurse:
                for key, value in self.devices.items():
                    value.readBlocks(recurse=True)
