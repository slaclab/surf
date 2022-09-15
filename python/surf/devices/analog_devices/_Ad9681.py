#-----------------------------------------------------------------------------
# Title      : PyRogue _ad9249 Module
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
# import math

class Ad9681Config(pr.Device):
    def __init__(self,
                 description = 'Configure one side of an AD9249 ADC',
                 **kwargs):

        super().__init__(description=description, **kwargs)

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
            name        = 'DevIndexMask_DataCh',
            offset      = 0x05 *4,
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
            disp        = '{:#b}',
        ))


        self.add(pr.RemoteVariable(
            name        = 'DevIndexMask_FCO',
            offset      = 0x05 *4,
            bitSize     = 1,
            bitOffset   = 4,
            mode        = 'RW',
            disp        = '{:#b}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DevIndexMask_DCO',
            offset      = 0x05 * 4,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
            disp        = '{:#b}',
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

        self.add(pr.RemoteVariable(
            name        = 'OutputDriveTerm',
            offset      = (0x15*4),
            bitSize     = 2,
            bitOffset   = 4,
            enum        = {
                0b00: "None",
                0b01: "200 Ohms",
                0b10: "100 Ohms",
                0b11: "101 Ohms",
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'DcoFcoDrive',
            offset      = (0x15*4),
            bitSize     = 1,
            bitOffset   = 0,
            enum        = {
                0: "1x",
                1: "2x",
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'InputClkPhaseAdj',
            offset      = (0x16*4),
            bitSize     = 3,
            bitOffset   = 4,
            disp = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'OutputClkPhaseAdj',
            offset      = (0x16*4),
            bitSize     = 4,
            bitOffset   = 0,
            disp = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DigitalFsRangeAdj',
            offset      = (0x18*4),
            bitSize     = 3,
            bitOffset   = 0,
            enum = {
                0b000: '1.0 V',
                0b001: '1.14 V',
                0b010: '1.33 V',
                0b011: '1.6 V',
                0b100: '2.0 V',
            },
        ))



        self.add(pr.RemoteVariable(
            name        = 'UserPatt1Lsb',
            offset      = (0x19*4),
            bitSize     = 8,
            bitOffset   = 0,
        ))

        self.add(pr.RemoteVariable(
            name        = 'UserPatt1Msb',
            offset      = (0x1A*4),
            bitSize     = 8,
            bitOffset   = 0,
        ))

        self.add(pr.RemoteVariable(
            name        = 'UserPatt2Lsb',
            offset      = (0x1B*4),
            bitSize     = 8,
            bitOffset   = 0,
        ))

        self.add(pr.RemoteVariable(
            name        = 'UserPatt2Msb',
            offset      = (0x1C*4),
            bitSize     = 8,
            bitOffset   = 0,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LvdsLsbFirst',
            offset      = (0x21*4),
            bitSize     = 1,
            bitOffset   = 7,
            base        = pr.Bool,
        ))

        self.add(pr.RemoteVariable(
            name        = 'OutputMode',
            offset      = (0x21*4),
            bitSize     = 3,
            bitOffset   = 4,
            enum = {
                0b000: 'SDR two-lane, bitwise',
                0b001: 'SDR two-lane, bytewise',
                0b010: 'DDR two-lane, bitwise',
                0b011: 'DDR two-lane, bytewise',
                0b100: 'DDR one-lane, wordwise',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'PllLowEncodeRateMode',
            offset      = (0x21*4),
            bitSize     = 1,
            bitOffset   = 3,
            base        = pr.Bool,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Select2xFrame',
            offset      = (0x21*4),
            bitSize     = 1,
            bitOffset   = 2,
            base        = pr.Bool,
        ))

        self.add(pr.RemoteVariable(
            name        = 'OutputNumBits',
            offset      = (0x21*4),
            bitSize     = 2,
            bitOffset   = 0,
            enum = {
                0b00: '16 bits',
                0b10: '12 bits',
            },
        ))

        self.add(pr.RemoteCommand(
            name='DeviceUpdate',
            offset=0x3FC,
            function=pr.BaseCommand.touchZero,
        ))

    def writeBlocks(self, force=False, recurse=True, variable=None, checkEach=False, index=-1, **kwargs):
        pr.Device.writeBlocks(self, force=force, recurse=True, variable=variable, checkEach=checkEach, index=index)
        self.DeviceUpdate()




class Ad9681ReadoutManual(pr.Device):
    def __init__(self,
                 name        = 'Ad9249Readout',
                 description = 'Configure readout of 1 bank of an AD9249',
                 fpga        = '7series',
                 channels    = 8,
                 **kwargs):

        assert (channels > 0 and channels <= 8), f'channels ({channels}) must be between 0 and 8'
        super().__init__(name=name, description=description, **kwargs)

        if fpga == '7series':
            delayBits = 6
        elif fpga == 'ultrascale':
            delayBits = 10
        else:
            delayBits = 6


        for ch in range(channels):
            for i in range(2):
                self.add(pr.RemoteVariable(
                    name         = f'ChannelDelay[{ch}][{i}]',
                    description  = f'IDELAY value for serial channel {ch}_{i}',
                    offset       = ch*8 + i*4,
                    bitSize      = delayBits,
                    bitOffset    = 0,
                    base         = pr.UInt,
                    mode         = 'RW',
                    verify       = False,
                ))

        for i in range(2):
            self.add(pr.RemoteVariable(
                name        = f'FrameDelay[{i}]',
                description = f'IDELAY value for FCO_{i}',
                offset      = 0x40 + i*4,
                bitSize     = delayBits,
                bitOffset   = 0,
                base        = pr.UInt,
                mode        = 'RW',
                verify       = False,
            ))

        @self.command()
        def AllDelay0(arg):
            self.FrameDelay[0].set(arg)
            for ch in range(8):
                self.ChannelDelay[ch][0].set(arg)

        @self.command()
        def AllDelay1(arg):
            self.FrameDelay[1].set(arg)
            for ch in range(8):
                self.ChannelDelay[ch][1].set(arg)

        for i in range(2):
            self.add(pr.RemoteVariable(
                name        = f'LostLockCount[{i}]',
                description = 'Number of times that frame lock has been lost since reset',
                offset      = 0x50+ 4*i,
                bitSize     = 16,
                bitOffset   = 0,
                base        = pr.UInt,
                mode        = 'RO',
            ))

        for i in range(2):
            self.add(pr.RemoteVariable(
                name        = f'Locked[{i}]',
                description = 'Readout has locked on to the frame boundary',
                offset      = 0x50+ 4*i,
                bitSize     = 1,
                bitOffset   = 16,
                base        = pr.Bool,
                mode        = 'RO',
            ))

        for i in range(2):
            self.add(pr.RemoteVariable(
                name        = f'AdcFrameSync[{i}]',
                description = 'Last deserialized FCO value for debug',
                offset      = 0x58,
                bitSize     = 8,
                bitOffset   = i*8,
                base        = pr.UInt,
                mode        = 'RO',
            ))

        self.add(pr.RemoteVariable(
            name        = 'Invert',
            description = 'Optional ADC data inversion (offset binary only)',
            offset      = 0x60,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.Bool,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Negate',
            description = "Optional ADC data negation (two's complement)",
            offset      = 0x60,
            bitSize     = 1,
            bitOffset   = 1,
            base        = pr.Bool,
            mode        = 'RW',
        ))


        for i in range(channels):
            self.add(pr.RemoteVariable(
                name        = f'AdcChannel[{i:d}]',
                description = f'Last deserialized channel {i:d} ADC value for debug',
                offset      = 0x80 + (i*4),
                bitSize     = 32,
                bitOffset   = 0,
                base        = pr.UInt,
                disp        = '{:09_x}',
                mode        = 'RO',
            ))

        for i in range(channels):
            self.add(pr.LinkVariable(
                name = f'AdcVoltage[{i}]',
                mode = 'RO',
                disp = '{:1.9f}',
                variable = self.AdcChannel[i],
                linkedGet = lambda read, check, r=self.AdcChannel[i]: 2*pr.twosComplement(r.get(read=read, check=check)>>18, 14)/2**14,
                units = 'V'))

        self.add(pr.RemoteCommand(
            name        = 'LostLockCountReset',
            description = 'Reset LostLockCount',
            function    = pr.BaseCommand.toggle,
            offset      = 0x5C,
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

        self.add(pr.RemoteCommand(
            name='Relock',
            hidden=False,
            offset=0x70,
            bitSize=2,
            bitOffset=0,
            base=pr.UInt,
            function=pr.RemoteCommand.createToggle([0, 3, 0])))


    def readBlocks(self, *, recurse=True, variable=None, checkEach=False, index=-1, **kwargs):
        """
        Perform background reads
        """
        checkEach = checkEach or self.forceCheckEach

        if variable is not None:
            freeze = False #isinstance(variable, list) and any(v.name.startswith('AdcChannel') for v in variable)
            if freeze:
                self.FreezeDebug(1)
            pr.startTransaction(variable._block, type=rim.Read, checkEach=checkEach, variable=variable, index=index, **kwargs)
            if freeze:
                self.FreezeDebug(0)

        else:
            self.FreezeDebug(1)
            for block in self._blocks:
                if block.bulkOpEn:
                    pr.startTransaction(block, type=rim.Read, checkEach=checkEach, **kwargs)
            self.FreezeDebug(0)

            if recurse:
                for key,value in self.devices.items():
                    value.readBlocks(recurse=True, checkEach=checkEach, **kwargs)

class Ad9681Readout(pr.Device):
    def __init__(self,
                 name        = 'Ad9249Readout',
                 description = 'Configure readout of 1 bank of an AD9249',
                 fpga        = '7series',
                 channels    = 8,
                 **kwargs):

        assert (channels > 0 and channels <= 8), f'channels ({channels}) must be between 0 and 8'
        super().__init__(name=name, description=description, **kwargs)

        if fpga == '7series':
            delayBits = 6
        elif fpga == 'ultrascale':
            delayBits = 10
        else:
            delayBits = 6

        self.add(pr.RemoteVariable(
            name         = 'EnUsrDelay',
            description  = 'Enable manual delay value',
            offset       = 0x20,
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.Bool,
            mode         = 'RW',
            verify       = True,
        ))

        for i in range(2):
            self.add(pr.RemoteVariable(
                name         = f'Delay[{i}]',
                description  = f'IDELAY value for serial channel {i}',
                offset       = i*4,
                bitSize      = delayBits,
                bitOffset    = 0,
                base         = pr.UInt,
                mode         = 'RW',
                verify       = False,
            ))

        for i in range(2):
            self.add(pr.RemoteVariable(
                name        = f'ErrorDetCount[{i}]',
                description = 'Number of times that frame lock has been lost since reset',
                offset      = 0x30+ 4*i,
                disp = '{:d}',
                bitSize     = 16,
                bitOffset   = 0,
                base        = pr.UInt,
                mode        = 'RO',
            ))


        for i in range(2):
            self.add(pr.RemoteVariable(
                name        = f'LostLockCount[{i}]',
                description = 'Number of times that frame lock has been lost since reset',
                offset      = 0x50+ 4*i,
                bitSize     = 16,
                bitOffset   = 0,
                base        = pr.UInt,
                mode        = 'RO',
            ))

        for i in range(2):
            self.add(pr.RemoteVariable(
                name        = f'Locked[{i}]',
                description = 'Readout has locked on to the frame boundary',
                offset      = 0x50+ 4*i,
                bitSize     = 1,
                bitOffset   = 16,
                base        = pr.Bool,
                mode        = 'RO',
            ))

        for i in range(2):
            self.add(pr.RemoteVariable(
                name        = f'AdcFrameSync[{i}]',
                description = 'Last deserialized FCO value for debug',
                offset      = 0x58,
                bitSize     = 8,
                bitOffset   = i*8,
                base        = pr.UInt,
                mode        = 'RO',
            ))

        self.add(pr.RemoteVariable(
            name        = 'Invert',
            description = 'Optional ADC data inversion (offset binary only)',
            offset      = 0x60,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.Bool,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Negate',
            description = "Optional ADC data negation (two's complement)",
            offset      = 0x60,
            bitSize     = 1,
            bitOffset   = 1,
            base        = pr.Bool,
            mode        = 'RW',
        ))


        for i in range(channels):
            self.add(pr.RemoteVariable(
                name        = f'AdcChannel[{i:d}]',
                description = f'Last deserialized channel {i:d} ADC value for debug',
                offset      = 0x80 + (i*4),
                bitSize     = 32,
                bitOffset   = 0,
                base        = pr.UInt,
                disp        = '{:09_x}',
                mode        = 'RO',
            ))

        for i in range(channels):
            self.add(pr.LinkVariable(
                name = f'AdcVoltage[{i}]',
                mode = 'RO',
                disp = '{:1.9f}',
                variable = self.AdcChannel[i],
                linkedGet = lambda read, check, r=self.AdcChannel[i]: 2*pr.twosComplement(r.get(read=read, check=check)>>18, 14)/2**14,
                units = 'V'))

        self.add(pr.RemoteCommand(
            name        = 'LostLockCountReset',
            description = 'Reset LostLockCount',
            function    = pr.BaseCommand.toggle,
            offset      = 0x5C,
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

        self.add(pr.RemoteCommand(
            name='Relock',
            hidden=False,
            offset=0x70,
            bitSize=2,
            bitOffset=0,
            base=pr.UInt,
            function=pr.RemoteCommand.createToggle([0, 3, 0])))


    def readBlocks(self, *, recurse=True, variable=None, checkEach=False, index=-1, **kwargs):
        """
        Perform background reads
        """
        checkEach = checkEach or self.forceCheckEach

        if variable is not None:
            pr.startTransaction(variable._block, type=rim.Read, checkEach=checkEach, variable=variable, index=index, **kwargs)

        else:
            self.FreezeDebug(1)
            for block in self._blocks:
                if block.bulkOpEn:
                    pr.startTransaction(block, type=rim.Read, checkEach=checkEach, **kwargs)
            self.FreezeDebug(0)

            if recurse:
                for key,value in self.devices.items():
                    value.readBlocks(recurse=True, checkEach=checkEach, **kwargs)
