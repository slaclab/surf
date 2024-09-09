#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite Version Module
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Lite Version Module
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Comment added by rherbst for demonstration purposes.
import datetime
import parse
import click
import pyrogue as pr

# Another comment added by rherbst for demonstration
# Yet Another comment added by rherbst for demonstration

class AxiVersion(pr.Device):

    # Last comment added by rherbst for demonstration.
    def __init__(self, numUserConstants = 0, **kwargs):
        super().__init__(**kwargs)

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
            disp         = '{:#08x}',
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
            pollInterval = 1,
        ))

        def parseUpTime(var,read):
            seconds=var.dependencies[0].get(read=read)
            if seconds == 0xFFFFFFFF:
                click.secho(f'Invalid {var.path} detected', fg='red')
                return 'Invalid'
            else:
                return str(datetime.timedelta(seconds=seconds))

        self.add(pr.LinkVariable(
            name         = 'UpTime',
            description  = 'Time since power up or last firmware reload',
            mode         = 'RO',
            disp         = '{}',
            variable     = self.UpTimeCnt,
            linkedGet    = parseUpTime,
            units        = 'HH:MM:SS',
        ))

        self.add(pr.RemoteVariable(
            name         = 'FpgaReloadHalt',
            description  = 'Used to halt automatic reloads via AxiVersion',
            groups       = ['NoConfig'],
            offset       = 0x100,
            bitSize      = 1,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = 'RW',
            hidden       = True,
            groups       = 'NoConfig'
        ))

        self.add(pr.RemoteCommand(
            name         = 'FpgaReload',
            description  = 'Optional Reload the FPGA from the attached PROM',
            offset       = 0x104,
            bitSize      = 1,
            bitOffset    = 0x00,
            base         = pr.UInt,
            function     = lambda cmd: cmd.post(1),
            hidden       = True,
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
            groups       = 'NoConfig',
        ))

        @self.command(hidden=True)
        def FpgaReloadAtAddress(arg):
            self.FpgaReloadAddress.set(arg)
            self.FpgaReload()

        self.add(pr.RemoteVariable(
            name         = 'UserReset',
            description  = 'Optional User Reset',
            groups       = ['NoConfig'],
            hidden       = True,
            offset       = 0x10C,
            bitSize      = 1,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = 'RW',
            groups       = 'NoConfig',
        ))

        @self.command(description  = 'Toggle UserReset')
        def UserRst():
            self.UserReset.set(1)
            self.UserReset.set(0)

        self.add(pr.RemoteVariable(
            name         = 'FdSerial',
            description  = 'Board ID value read from DS2411 chip',
            offset       = 0x300,
            bitSize      = 64,
            bitOffset    = 0x00,
            base         = pr.UInt,
            mode         = 'RO',
            hidden       = True,
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
            linkedGet    = lambda read: f'{(self.GitHash.value() >> 132):07x}' if self.GitHash.get(read=read) != 0 else 'dirty (uncommitted code)',
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

        def parseBuildStamp(var,read):
            buildStamp = var.dependencies[0].get(read=read)
            if buildStamp is None:
                return ''
            else:
                # Strip away the whitespace padding
                buildStamp = buildStamp.strip()

                # Parse the string
                p = parse.parse("{ImageName}: {BuildEnv}, {BuildServer}, Built {BuildDate} by {Builder}", buildStamp)

                # Check if failed
                if p is None:
                    return ''
                else:
                    return p[var.name]

        self.add(pr.LinkVariable(
            name = 'ImageName',
            mode = 'RO',
            linkedGet = parseBuildStamp,
            variable = self.BuildStamp))

        self.add(pr.LinkVariable(
            name = 'BuildEnv',
            mode = 'RO',
            linkedGet = parseBuildStamp,
            variable = self.BuildStamp))

        self.add(pr.LinkVariable(
            name = 'BuildServer',
            mode = 'RO',
            linkedGet = parseBuildStamp,
            variable = self.BuildStamp))

        self.add(pr.LinkVariable(
            name = 'BuildDate',
            mode = 'RO',
            linkedGet = parseBuildStamp,
            variable = self.BuildStamp))

        self.add(pr.LinkVariable(
            name = 'Builder',
            mode = 'RO',
            linkedGet = parseBuildStamp,
            variable = self.BuildStamp))


    def hardReset(self):
        print(f'{self.path} hard reset called')

    def initialize(self):
        print(f'{self.path} initialize called')

    def countReset(self):
        print(f'{self.path} count reset called')

    def printStatus(self):
        try:
            gitHash = self.GitHash.get()
            print("Path         = {}".format(self.path))
            print("FwVersion    = {}".format(hex(self.FpgaVersion.get())))
            print("UpTime       = {}".format(self.UpTime.get()))
            if (gitHash != 0):
                print("GitHash      = {}".format(hex(self.GitHash.get())))
            else:
                print("GitHash      = dirty (uncommitted code)")
            print("XilinxDnaId  = {}".format(hex(self.DeviceDna.get())))
            print("FwTarget     = {}".format(self.ImageName.get()))      # Read buildstamp here
            print("BuildEnv     = {}".format(self.BuildEnv.value()))
            print("BuildServer  = {}".format(self.BuildServer.value()))
            print("BuildDate    = {}".format(self.BuildDate.value()))
            print("Builder      = {}".format(self.Builder.value()))
        except Exception:
            print("Failed to get %s status" % self)
