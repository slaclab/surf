#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite Version Module
#-----------------------------------------------------------------------------
# File       : AxiVersion.py
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
import datetime
import parse
import pyrogue as pr

# Another comment added by rherbst for demonstration
# Yet Another comment added by rherbst for demonstration

class AxiVersion(pr.Device):

    # Last comment added by rherbst for demonstration.
    def __init__(
            self,       
            name             = 'AxiVersion',
            description      = 'AXI-Lite Version Module',
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
            offset       = 0x00,
            bitSize      = 32,
            bitOffset    = 0x00,
            base         = pr.UInt,
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
            disp         = '{:#08x}'            
        ))

        self.add(pr.RemoteVariable(   
            name         = 'UpTimeCnt',
            description  = 'Number of seconds since last reset',
            hidden       = True,
            offset       = 0x08,
            bitSize      = 32,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = 'RO',
            disp         = '{:d}',
            units        = 'seconds',
            pollInterval = 1
        ))

        self.add(pr.LinkVariable(
            name = 'UpTime',
            mode = 'RO',
            dependencies = [self.UpTimeCnt],
            linkedGet = lambda: str(datetime.timedelta(seconds=self.UpTimeCnt.value()))
        ))

        self.add(pr.RemoteVariable(   
            name         = 'FpgaReloadHalt',
            description  = 'Used to halt automatic reloads via AxiVersion',
            offset       = 0x100,
            bitSize      = 1,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = 'RW',
            hidden       = True,
        ))

        self.add(pr.RemoteCommand(   
            name         = 'FpgaReload',
            description  = 'Optional Reload the FPGA from the attached PROM',
            offset       = 0x104,
            bitSize      = 1,
            bitOffset    = 0x00,
            base         = pr.UInt,
            function     = lambda cmd: cmd.post(1),
            hidden       = False,
        ))

        self.add(pr.RemoteVariable(   
            name         = 'FpgaReloadAddress',
            description  = 'Reload start address',
            offset       = 0x108,
            bitSize      = 32,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = 'RW',
            hidden       = True,
        ))

        @self.command(hidden=True)
        def FpgaReloadAtAddress(arg):
            self.FpgaReloadAddress.set(arg)
            self.FpgaReload()

        self.add(pr.RemoteVariable(   
            name         = 'UserReset',
            description  = 'Optional User Reset',
            offset       = 0x10C,
            bitSize      = 1,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(   
            name         = 'FdSerial',
            description  = 'Board ID value read from DS2411 chip',
            offset       = 0x300,
            bitSize      = 64,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = 'RO',
        ))

        self.addRemoteVariables(   
            name         = 'UserConstants',
            description  = 'Optional user input values',
            offset       = 0x400,
            bitSize      = 32,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = 'RO',
            number       = numUserConstants,
            stride       = 4,
            hidden       = True,
        )


        self.add(pr.RemoteVariable(   
            name         = 'DeviceId',
            description  = 'Device Identification  (configued by generic)',
            offset       = 0x500,
            bitSize      = 32,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(   
            name         = 'GitHash',
            description  = 'GIT SHA-1 Hash',
            offset       = 0x600,
            bitSize      = 160,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'GitHashShort',
            mode         = 'RO',
            dependencies = [self.GitHash],
            disp         = '{:07x}',
            linkedGet    = lambda: self.GitHash.value() >> 132
        ))

        self.add(pr.RemoteVariable(   
            name         = 'DeviceDna',
            description  = 'Xilinx Device DNA value burned into FPGA',
            offset       = 0x700,
            bitSize      = 128,
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
            hidden       = True,
        ))

        
        def parseBuildStamp(var, value, disp):
            p = parse.parse("{ImageName}: {BuildEnv}, {BuildServer}, Built {BuildDate} by {Builder}", value.strip())
            if p is not None:
                for k,v in p.named.items():
                    self.node(k).set(v)
        
        self.add(pr.LocalVariable(
            name = 'ImageName',
            mode = 'RO',
            value = ''))
 
        self.add(pr.LocalVariable(
            name = 'BuildEnv',
            mode = 'RO',
            value = ''))

        self.add(pr.LocalVariable(
            name = 'BuildServer',
            mode = 'RO',
            value = ''))
       
        self.add(pr.LocalVariable(
            name = 'BuildDate',
            mode = 'RO',
            value = ''))
       
        self.add(pr.LocalVariable(
            name = 'Builder',
            mode = 'RO',
            value = ''))

        self.BuildStamp.addListener(parseBuildStamp)        
       

    def hardReset(self):
        print('AxiVersion hard reset called')

    def softReset(self):
        print('AxiVersion soft reset called')

    def countReset(self):
        print('AxiVersion count reset called')
        
    def printStatus(self):
        self.UpTimeCnt.get()
        self.BuildStamp.get()
        gitHash = self.GitHash.get()
        print("FwVersion    = {}".format(hex(self.FpgaVersion.get())))
        print("UpTime       = {}".format(self.UpTime.get()))
        if (gitHash != 0):
            print("GitHash      = {}".format(hex(self.GitHash.get())))
        else:
            print("GitHash      = dirty (uncommitted code)")
        print("XilinxDnaId  = {}".format(hex(self.DeviceDna.get())))
        print("FwTarget     = {}".format(self.ImageName.get()))
        print("BuildEnv     = {}".format(self.BuildEnv.get()))
        print("BuildServer  = {}".format(self.BuildServer.get()))
        print("BuildDate    = {}".format(self.BuildDate.get()))
        print("Builder      = {}".format(self.Builder.get()))
