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
import math

class Ad9249ConfigGroup(pr.Device):
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
            name        = 'DevIndexMask_DataCh[0]',
            offset      = 0x10,
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
            disp        = '{:#b}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DevIndexMask_DataCh[1]',
            offset      = 0x14,
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
            disp        = '{:#b}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DevIndexMask_FCO',
            offset      = 0x14,
            bitSize     = 1,
            bitOffset   = 4,
            mode        = 'RW',
            disp        = '{:#b}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DevIndexMask_DCO',
            offset      = 0x14,
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

class Ad9249ChipConfig(pr.Device):
    def __init__(self,
            name        = 'Ad9249ChipConfig',
            description = 'Configure one side of an AD9249 ADC',
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)
        self.add(Ad9249ConfigGroup('BankConfig[0]', 0x0000))
        self.add(Ad9249ConfigGroup('BankConfig[1]', 0x0200))

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
            self.add(Ad9249ConfigGroup(name='BankConfig[0]', offset=0x0000))
            self.add(Ad9249ConfigGroup(name='BankConfig[1]', offset=0x0800))
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
                self.add(Ad9249ConfigGroup(name=f'Ad9249ChipBankConfig0[{i}]', offset=i*0x1000))
                self.add(Ad9249ConfigGroup(name=f'Ad9249ChipBankConfig1[{i}]', offset=i*0x1000+0x0800))

class Ad9249ReadoutGroup(pr.Device):
    def __init__(self,
            name        = 'Ad9249ReadoutGroup',
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

        for i in range(channels):
            self.add(pr.RemoteVariable(
                name         = f'ChannelDelay[{i}]',
                description  = f'IDELAY value for serial channel {i}',
                offset       = i*4,
                bitSize      = delayBits,
                bitOffset    = 0,
                base         = pr.UInt,
                mode         = 'RW',
                verify       = False,
            ))

        self.add(pr.RemoteVariable(
            name        = 'FrameDelay',
            description = 'IDELAY value for FCO',
            offset      = 0x20,
            bitSize     = delayBits,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
            verify       = False,
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

        self.add(pr.RemoteVariable(
            name        = 'Invert',
            description = 'Optional ADC data inversion (offset binary only)',
            offset      = 0x40,
            bitSize     = 1,
            bitOffset   = 0,
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

    @staticmethod
    def setDelay(var, value, write):
        iValue = value + 512
        var.dependencies[0].set(iValue, write)
        var.dependencies[0].set(value, write)

    @staticmethod
    def getDelay(var, read):
        return var.dependencies[0].get(read=read)

    def readBlocks(self, *, recurse=True, variable=None, checkEach=False, index=-1, **kwargs):
        """
        Perform background reads
        """
        checkEach = checkEach or self.forceCheckEach

        if variable is not None:
            freeze = isinstance(variable, list) and any(v.name.startswith('AdcChannel') for v in variable)
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


class Ad9249ReadoutGroup2(pr.Device):
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
            delayBits = 9
        else:
            delayBits = 6


        self.add(pr.RemoteVariable(
            name         = f'Delay',
            description  = f'IDELAY value',
            offset       = 0x00,
            bitSize      = delayBits,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = 'RW',
            verify       = False,
            groups       = 'NoConfig',
        ))
        
        self.add(pr.RemoteCommand(
            name='Relock',
            hidden=False,
            offset=0x20,
            bitSize=1,
            bitOffset=0,
            base=pr.UInt,
            function=pr.RemoteCommand.toggle))
        
        self.add(pr.RemoteVariable(
            name        = f'ErrorDetCount',
            description = 'Number of times that frame lock has been lost since reset',
            offset      = 0x30,
            disp = '{:d}',
            bitSize     = 16,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
            ))

        self.add(pr.RemoteVariable(
            name        = f'LostLockCount',
            description = 'Number of times that frame lock has been lost since reset',
            offset      = 0x50,
            bitSize     = 16,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = f'Locked',
            description = 'Readout has locked on to the frame boundary',
            offset      = 0x50,
            bitSize     = 1,
            bitOffset   = 16,
            base        = pr.Bool,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = f'AdcFrameSync',
            description = 'Last deserialized FCO value for debug',
            offset      = 0x58,
            bitSize     = 14,
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


class AdcTester(pr.Device):
    def __init__(self, **kwargs):
        """Create AdcTester"""
        super().__init__(description='ADC Pattern Tester Regsisters', **kwargs)

        # Creation. memBase is either the register bus server (srp, rce mapped memory, etc) or the device which
        # contains this object. In most cases the parent and memBase are the same but they can be
        # different in more complex bus structures. They will also be different for the top most node.
        # The setMemBase call can be used to update the memBase for this Device. All sub-devices and local
        # blocks will be updated.

        #############################################
        # Create block / variable combinations
        #############################################


        #Setup registers & variables
        self.add(pr.RemoteVariable(
            name       = 'TestChannel',
            description= 'Test Channel Select',
            offset     = 0x00000000,
            bitSize    = 32,
            bitOffset  = 0,
            base       = pr.UInt,
            mode       = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name       = 'TestDataMask',
            description= 'Test Data Mask',
            offset     = 0x00000004,
            bitSize    = 32,
            bitOffset  = 0,
            base       = pr.UInt,
            mode       = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name       = 'TestPattern',
            description= 'Test Pattern',
            offset     = 0x00000008,
            bitSize    = 32,
            bitOffset  = 0,
            base       = pr.UInt,
            mode       = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name       = 'TestSamples',
            description= 'Test Samples Number',
            offset     = 0x0000000C,
            bitSize    = 32,
            bitOffset  = 0,
            base       = pr.UInt,
            mode       = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name       = 'TestTimeout',
            description= 'Test Timeout',
            offset     = 0x00000010,
            bitSize    = 32,
            bitOffset  = 0,
            base       = pr.UInt,
            mode       = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name       = 'TestRequest',
            description= 'Test Request',
            offset     = 0x00000014,
            bitSize    = 1,
            bitOffset  = 0,
            base       = pr.Bool,
            mode       = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name       = 'TestPassed',
            description= 'Test Passed Flag',
            offset     = 0x00000018,
            bitSize    = 1,
            bitOffset  = 0,
            base       = pr.Bool,
            mode       = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name       = 'TestFailed',
            description= 'Test Failed Flag',
            offset     = 0x0000001C,
            bitSize    = 1,
            bitOffset  = 0,
            base       = pr.Bool,
            mode       = 'RO',
        ))

    #####################################
    # Create commands
    #####################################

    # A command has an associated function. The function can be a series of
    # python commands in a string. Function calls are executed in the command scope
    # the passed arg is available as 'arg'. Use 'dev' to get to device scope.
    # A command can also be a call to a local function with local scope.
    # The command object and the arg are passed

    @staticmethod
    def frequencyConverter(self):
        def func(dev, var):
            return '{:.3f} kHz'.format(1/(self.clkPeriod * self._count(var.dependencies)) * 1e-3)
        return func
