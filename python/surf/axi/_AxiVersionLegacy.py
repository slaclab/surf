#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite Version Module
#-----------------------------------------------------------------------------
# File       : AxiVersionLegacy.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Lite Version Module
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the rogue software platform, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Comment added by rherbst for demonstration purposes.

import pyrogue as pr

import datetime

# Another comment added by rherbst for demonstration
# Yet Another comment added by rherbst for demonstration

class AxiVersionLegacy(pr.Device):

    # Last comment added by rherbst for demonstration.
    def __init__(
            self,       
            name        = 'AxiVersion',
            description = 'AXI-Lite Version Module',
            numUserConstants = 0,
            **kwargs):
        
        super().__init__(
            name        = name,
            description = description,
            **kwargs)

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(
            name         = 'FpgaVersion',
            description  = 'FPGA Firmware Version Number',
            offset       =  0x00,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         =  pr.UInt,
            mode         = 'RO',
            disp         = '{:#08x}',
        ))

        self.add(pr.RemoteVariable(   
            name         = 'ScratchPad',
            description  = 'Register to test reads and writes',
            offset       = 0x04,
            bitSize      = 32,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = 'RW',
            disp         = '{:#08x}',            
        ))

        self.add(pr.RemoteVariable(   
            name         = 'UpTimeCnt',
            description  = 'Number of seconds since last reset',
            hidden       = True,
            offset       = 0x02C,
            bitSize      = 32,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = 'RO',
            disp         = '{:d}',
            units        = 'seconds',
            pollInterval = 1,
        ))

        @self.linkedGet(dependencies=[self.UpTimeCnt])
        def UpTime():
            return str(datetime.timedelta(seconds=self.UpTimeCnt.value()))
        

        self.add(pr.RemoteVariable(   
            name         = 'FpgaReloadHalt',
            description  = 'Used to halt automatic reloads via AxiVersion',
            offset       = 0x28,
            bitSize      = 1,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = 'RW',
            hidden       = True,
        ))

        self.add(pr.RemoteCommand(   
            name         = 'FpgaReload',
            description  = 'Optional Reload the FPGA from the attached PROM',
            offset       = 0x1C,
            bitSize      = 1,
            bitOffset    = 0x00,
            base         = pr.UInt,
            function     = pr.RemoteCommand.postedTouchOne
        ))

        self.add(pr.RemoteVariable(   
            name         = 'FpgaReloadAddress',
            description  = 'Reload start address',
            offset       = 0x020,
            bitSize      = 32,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(   
            name         = 'UserReset',
            description  = 'Optional User Reset',
            offset       = 0x018,
            bitSize      = 1,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(   
            name         = 'FdSerial',
            description  = 'Board ID value read from DS2411 chip',
            offset       =  0x10,
            bitSize      =  64,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = 'RO',
            disp         = '{:#08x}',
        ))

        
        self.addRemoteVariables(   
            name         = 'UserConstants',
            description  = 'Optional user input values',
            offset       = 0x400,
            bitSize      = 32,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = 'RO',
            number       =  numUserConstants,
            stride       =  4,
            hidden       = True,
        )


        self.add(pr.RemoteVariable(   
            name         = 'DeviceId',
            description  = 'Device Identification  (configued by generic)',
            offset       = 0x030,
            bitSize      = 32,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = 'RO',
        ))

#         self.add(pr.RemoteVariable(   
#             name         = 'GitHash',
#             description  = 'GIT SHA-1 Hash',
#             offset       =  0x600,
#             bitSize      =  160,
#             bitOffset    =  0x00,
#             base         = pr.UInt,
#             mode         = 'RO',
#         ))

        self.add(pr.RemoteVariable(   
            name         = 'DeviceDna',
            description  = 'Xilinx Device DNA value burned into FPGA',
            offset       = 0x8,
            bitSize      = 64,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(   
            name         = 'BuildStamp',
            description  = 'Firmware Build String',
            offset       = 0x800,
            bitSize      = 8*256,
            bitOffset    = 0x00,
            base         = pr.String,
            mode         = 'RO',
        ))

