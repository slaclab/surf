#-----------------------------------------------------------------------------
# Title      : Legacy AD9249 readout interfaces
#-----------------------------------------------------------------------------
# Description:
# PyRogue register maps retained for the legacy Ad9249ReadoutGroup RTL.
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr
import rogue.interfaces.memory as rim


__all__ = [
    'Ad9249ReadoutGroup',
    'AdcTester',
]


class Ad9249ReadoutGroup(pr.Device):
    def __init__(self,
            name        = 'Ad9249ReadoutGroup',
            description = 'Configure readout of 1 bank of an AD9249',
            fpga        = '7series',
            channels    = 8,
            **kwargs):
        assert (channels > 0 and channels <= 8), f'channels ({channels}) must be between 1 and 8'
        super().__init__(name=name, description=description, **kwargs)

        if fpga == '7series':
            delayBits = 6
        elif fpga == 'ultrascale':
            delayBits = 10
        else:
            delayBits = 6

        for i in range(channels):
            self.add(pr.RemoteVariable(
                name        = f'ChannelDelay[{i}]',
                description = f'IDELAY value for serial channel {i}',
                offset      = i*4,
                bitSize     = delayBits,
                bitOffset   = 0,
                base        = pr.UInt,
                mode        = 'RW',
                verify      = False,
            ))

        self.add(pr.RemoteVariable(
            name        = 'FrameDelay',
            description = 'IDELAY value for FCO',
            offset      = 0x20,
            bitSize     = delayBits,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
            verify      = False,
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


class AdcTester(pr.Device):
    def __init__(self, description='ADC Pattern Tester Registers', **kwargs):
        """Create AdcTester"""
        super().__init__(description=description, **kwargs)

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
            name        = 'TestChannel',
            description = 'Test Channel Select',
            offset      = 0x00000000,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TestDataMask',
            description = 'Test Data Mask',
            offset      = 0x00000004,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TestPattern',
            description = 'Test Pattern',
            offset      = 0x00000008,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TestSamples',
            description = 'Test Samples Number',
            offset      = 0x0000000C,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TestTimeout',
            description = 'Test Timeout',
            offset      = 0x00000010,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TestRequest',
            description = 'Test Request',
            offset      = 0x00000014,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.Bool,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TestPassed',
            description = 'Test Passed Flag',
            offset      = 0x00000018,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.Bool,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TestFailed',
            description = 'Test Failed Flag',
            offset      = 0x0000001C,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.Bool,
            mode        = 'RO',
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
