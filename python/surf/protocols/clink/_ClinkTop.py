#-----------------------------------------------------------------------------
# Title      : PyRogue CameraLink module
#-----------------------------------------------------------------------------
# Description:
# PyRogue CameraLink module
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
import surf.protocols.clink

class ClinkTop(pr.Device):
    def __init__(
            self,
            serial      = [None,None],
            camType     = [None,None],
            **kwargs):
        super().__init__(**kwargs)

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(
            name         = "ChanCount",
            description  = "Supported channels",
            offset       =  0x00,
            bitSize      =  4,
            bitOffset    =  0x00,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(
            name         = "RstPll",
            description  = "Camera link channel PLL reset",
            offset       =  0x04,
            bitSize      =  1,
            bitOffset    =  0,
            mode         = "RW",
            hidden       = True,
        ))

        @self.command(description="toggles Camera link channel PLL reset",)
        def ResetPll():
            self.RstPll.set(0x1)
            self.RstPll.set(0x0)

        self.add(pr.RemoteCommand(
            name         = "ResetFsm",
            description  = "Camera link channel FSM reset",
            offset       =  0x04,
            bitSize      =  1,
            bitOffset    =  1,
            function     = pr.BaseCommand.toggle,
        ))

        self.add(pr.RemoteCommand(
            name         = "CntRst",
            description  = "",
            offset       = 0x04,
            bitSize      = 1,
            bitOffset    = 2,
            function     = pr.BaseCommand.toggle,
        ))

        self.add(pr.RemoteVariable(
            name         = "LinkLockedA",
            description  = "Camera link channel locked status",
            offset       =  0x10,
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.Bool,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(
            name         = "LinkLockedB",
            description  = "Camera link channel locked status",
            offset       =  0x10,
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.Bool,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(
            name         = "LinkLockedC",
            description  = "Camera link channel locked status",
            offset       =  0x10,
            bitSize      =  1,
            bitOffset    =  2,
            base         = pr.Bool,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(
            name         = "LinkLockedCntA",
            description  = "Camera link channel locked status counter",
            offset       =  0x10,
            bitSize      =  8,
            bitOffset    =  8,
            disp         = '{}',
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "LinkLockedCntB",
            description  = "Camera link channel locked status counter",
            offset       =  0x10,
            bitSize      =  8,
            bitOffset    =  16,
            disp         = '{}',
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "LinkLockedCntC",
            description  = "Camera link channel locked status counter",
            offset       =  0x10,
            bitSize      =  8,
            bitOffset    =  24,
            disp         = '{}',
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "ShiftCountA",
            description  = "Shift count for channel",
            offset       =  0x14,
            bitSize      =  3,
            bitOffset    =  0,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "ShiftCountB",
            description  = "Shift count for channel",
            offset       =  0x14,
            bitSize      =  3,
            bitOffset    =  8,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "ShiftCountC",
            description  = "Shift count for channel",
            offset       =  0x14,
            bitSize      =  3,
            bitOffset    =  16,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "DelayA",
            description  = "Precision delay for channel A",
            offset       =  0x18,
            bitSize      =  5,
            bitOffset    =  0,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "DelayB",
            description  = "Precision delay for channel B",
            offset       =  0x18,
            bitSize      =  5,
            bitOffset    =  8,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "DelayC",
            description  = "Precision delay for channel C",
            offset       =  0x18,
            bitSize      =  5,
            bitOffset    =  16,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.addRemoteVariables(
            name         = "ClkInFreq",
            description  = "Clock Input Freq",
            offset       = 0x01C,
            bitSize      = 32,
            bitOffset    = 0,
            units        = 'Hz',
            disp         = '{:d}',
            mode         = "RO",
            pollInterval = 1,
            number       = 3,
            stride       = 4,
        )

        self.addRemoteVariables(
            name         = "ClinkClkFreq",
            description  = "CameraLink Clock Freq",
            offset       = 0x028,
            bitSize      = 32,
            bitOffset    = 0,
            units        = 'Hz',
            disp         = '{:d}',
            mode         = "RO",
            pollInterval = 1,
            number       = 3,
            stride       = 4,
        )

        for i in range(2):
            if camType[i] is not None:
                self.add(surf.protocols.clink.ClinkChannel(
                    name    = f'Ch[{i}]',
                    offset  = 0x100+(i*0x100),
                    serial  = serial[i],
                    camType = camType[i],
                    # expand  = False,
                ))
        for i in range(3):
            self.add(surf.protocols.clink.ClockManager(
                name    = f'Pll[{i}]',
                offset  = 0x1000+(i*0x1000),
                type    = 'MMCME2',
                expand  = False,
            ))

        for i in range(3):
            self.add(pr.LocalVariable(
                name         = f'PllConfig[{i}]',
                description  = 'Sets the PLL to a known set of configurations',
                mode         = 'RW',
                value        = '',
            ))

    def hardReset(self):
        super().hardReset()
        self.ResetPll()
        self.CntRst()

    def initialize(self):
        super().initialize()
        # Hold the PLL in reset before configuration
        self.RstPll.set(0x1)

        # Loop through the PLL modules
        for i in range(3):

            # Check for 85 MHz configuration
            if (self.PllConfig[i].get() == '85MHz'):
                self.Pll[i].Config85MHz()

            # Check for 80 MHz configuration
            if (self.PllConfig[i].get() == '80MHz'):
                # Same config as 85 MHz
                self.Pll[i].Config85MHz()

            # Check for 40 MHz configuration
            if (self.PllConfig[i].get() == '40MHz'):
                self.Pll[i].Config40MHz()

            # Check for 25 MHz configuration
            if (self.PllConfig[i].get() == '25MHz'):
                self.Pll[i].Config25MHz()


        # Release the reset after configuration
        self.RstPll.set(0x0)

        # Reset all the counters
        self.CntRst()

    def countReset(self):
        super().countReset()
        self.CntRst()
