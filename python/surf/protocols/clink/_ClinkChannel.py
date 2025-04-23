#-----------------------------------------------------------------------------
# Title      : PyRogue CameraLink Channel
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

class ClinkChannel(pr.Device):
    def __init__(
            self,
            serial      = None,
            camType     = None,
            localSerial = False, # True if pyrogue is serial source, False if serial source from external software
            **kwargs):

        super().__init__(**kwargs)

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(
            name         = "LinkMode",
            offset       =  0x00,
            bitSize      =  3,
            bitOffset    =  0,
            mode         = "RW",
            enum         = { 0 : 'Disable' , 1 : 'Base', 2 : 'Medium', 3 : 'Full', 4 : 'Deca'},
            description = """
                Link mode control for camera link lanes:
                Disable: Nothing connected
                Base: Port Supported [A,B,C], # of chips = 1, # of connectors = 1
                Medium: Port Supported [A,B,C,D,E,F], # of chips = 2, # of connectors = 2
                Full: Port Supported [A,B,C,D,E,F,G,H], # of chips = 3, # of connectors = 3
                Deca: Refer to section /"2.2.3 Camera Link 80 bit/" CameraLink spec V2.0, page 16
                """,
        ))

        self.add(pr.RemoteVariable(
            name         = "DataMode",
            description  = "Data mode",
            offset       =  0x04,
            bitSize      =  4,
            bitOffset    =  0,
            mode         = "RW",
            enum         = { 0 : 'None',  1 : '8Bit',  2 : '10Bit', 3 : '12Bit', 4 : '14Bit',
                             5 : '16Bit', 6 : '24Bit', 7 : '30Bit', 8 : '36Bit'},
        ))

        self.add(pr.RemoteVariable(
            name         = "FrameMode",
            offset       =  0x08,
            bitSize      =  2,
            bitOffset    =  0,
            mode         = "RW",
            enum         = { 0 : 'None', 1 : 'Line', 2 : 'Frame'},
            description = """
                None: Disables output
                Line: 1D camera
                Frame: 2D pixel array
                """,
        ))

        self.add(pr.RemoteVariable(
            name         = "TapCount",
            description  = "# of video output taps on the Camera Link Interface (# of individual data value channels)",
            offset       =  0x0C,
            bitSize      =  4,
            bitOffset    =  0,
            minimum      = 0,
            maximum      = 10,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "DataEn",
            description  = "Data enable.  When 0x0 causes reset on ClinkData\'s FSM module",
            offset       =  0x10,
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.Bool,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "Blowoff",
            description  = "Blows off the outbound AXIS stream (for debugging)",
            offset       =  0x10,
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.Bool,
            mode         = "RW",
        ))

        self.add(pr.RemoteCommand(
            name         = "CntRst",
            description  = "",
            offset       = 0x10,
            bitSize      = 1,
            bitOffset    = 2,
            function     = pr.BaseCommand.toggle,
        ))

        self.add(pr.RemoteVariable(
            name         = "SerThrottle",
            description  = "Throttles the UART Serial TX byte rate. Used when the camera cannot accept new bytes until the previous command processed",
            offset       =  0x10,
            bitSize      =  16,
            bitOffset    =  16,
            disp         = '{}',
            mode         = "RW",
            units        = "microsec",
        ))

        self.add(pr.RemoteVariable(
            name         = "BaudRate",
            description  = "Baud rate",
            offset       =  0x14,
            bitSize      =  24,
            bitOffset    =  0,
            disp         = '{}',
            mode         = "RW",
            units        = "bps",
            value        = 9600,
        ))

        self.add(pr.RemoteVariable(
            name         = "SwControlValue",
            description  = "Software camera control bit values",
            offset       =  0x18,
            bitSize      =  4,
            bitOffset    =  0,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "SwControlEn",
            description  = "Software camera control bit enable mask for lane A",
            offset       =  0x1C,
            bitSize      =  4,
            bitOffset    =  0,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "Running",
            description  = "Camera link lane running status",
            offset       =  0x20,
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.Bool,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "FrameCount",
            description  = "Frame counter",
            offset       =  0x24,
            bitSize      =  32,
            bitOffset    =  0,
            disp         = '{}',
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "DropCount",
            description  = "Drop counter",
            offset       =  0x28,
            bitSize      =  32,
            bitOffset    =  0,
            disp         = '{}',
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "FrameSize",
            description  = "Camera Image size",
            offset       =  0x2C,
            bitSize      =  32,
            bitOffset    =  0,
            disp         = '{}',
            mode         = "RO",
            units        = "bytes",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "HSkip",
            description  = "# of cycle to skip from the start of CLINK LineValid (LV)",
            offset       =  0x30,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "HActive",
            description  = "# of active cycle after HSkip while CLINK LineValid (LV) is active",
            offset       =  0x34,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "VSkip",
            description  = "# of lines to skip from the start of CLINK FrameValid (FV)",
            offset       =  0x38,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "VActive",
            description  = "# of active lines after VSkip while CLINK FrameValid (FV) is active",
            offset       =  0x3C,
            bitSize      =  16,
            mode         = "RW",
        ))

        ##############################################################################

        self._rx = None
        self._tx = None

        # Check if serial interface defined
        if serial is not None:

            # Check for BaslerAce camera
            if (camType=='BaslerAce'):

                # Override defaults
                self.BaudRate._default = 9600

                # Add the device
                self.add(surf.protocols.clink.UartBaslerAce(
                    name   = 'UartBaslerAce',
                    serial = serial,
                    expand = False,
                ))

            # Check for JAI CM-140MCL-UV camera
            elif (camType=='JaiCm140'):

                # Override defaults
                self.BaudRate._default = 9600
                self.SerThrottle._default = 30000

                # Add the device
                self.add(surf.protocols.clink.UartJaiCm140(
                    name        = 'UartJaiCm140',
                    serial      = serial,
                    expand      = False,
                ))


            # Check for Imperx C1921 camera
            elif (camType=='ImperxC1921'):

                # Override defaults
                self.BaudRate._default = 115200
                self.SerThrottle._default = 10000

                # Add the device
                self.add(surf.protocols.clink.UartImperxC1921(
                    name        = 'UartImperxC1921',
                    serial      = serial,
                    expand      = False,
                ))


            # Check for OPA1000 camera
            elif (camType=='Opal1000'):

                # Override defaults
                self.BaudRate._default = 57600

                # Add the device
                self.add(surf.protocols.clink.UartOpal1000(
                    name   = 'UartOpal1000',
                    serial = serial,
                    expand = False,
                ))

            # Check for Piranha4 camera
            elif (camType=='Piranha4'):

                # Override defaults
                self.BaudRate._default = 9600

                # Add the device
                self.add(surf.protocols.clink.UartPiranha4(
                    name        = 'UartPiranha4',
                    serial      = serial,
                    expand      = False,
                ))

            # Check for Uniq UP-900CL-12B camera
            elif (camType=='Up900cl12b'):

                # Override defaults
                self.BaudRate._default = 9600
                self.SerThrottle._default = 30000

                # Add the device
                self.add(surf.protocols.clink.UartUp900cl12b(
                    name        = 'UartUp900cl12b',
                    serial      = serial,
                    expand      = False,
                ))

            # Else generic interface to serial stream
            elif camType is None:

                # Add the device
                self.add(surf.protocols.clink.UartGeneric(
                    name        = 'UartGeneric',
                    serial      = serial,
                    expand      = False,
                ))

            elif localSerial:
                raise ValueError( f'Invalid camType ({camType})' )
        ##############################################################################

    def hardReset(self):
        self.CntRst()

    def initialize(self):
        self.CntRst()

    def countReset(self):
        self.CntRst()
