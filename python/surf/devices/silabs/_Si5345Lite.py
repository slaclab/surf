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
import surf.devices.silabs as silabs
import csv
import click
import fnmatch
import rogue

class Si5345Lite(pr.Device):
    def __init__(self,
            simpleDisplay = True,
            advanceUser   = False,
            **kwargs):

        self._useVars = rogue.Version.greaterThanEqual('5.4.0')

        if self._useVars:
            size = 0
        else:
            size = (0x1000 << 2)  # 16KB

        super().__init__(size=size, **kwargs)

        self.add(pr.LocalVariable(
            name         = "CsvFilePath",
            description  = "Used if command's argument is empty",
            mode         = "RW",
            value        = "",
        ))

        if self._useVars:

            # Create 4 x 4K Blocks
            for i in range(4):
                self.add(pr.RemoteVariable(
                    name         = f"DataBlock[{i}]",
                    description  = "",
                    offset       = 0,
                    bitSize      = 32,
                    bitOffset    = 0,
                    numValues    = 0x400,
                    valueBits    = 32,
                    valueStride  = 32,
                    updateNotify = False,
                    bulkOpEn     = False,
                    verify       = False,
                    hidden       = True,
                    base         = pr.UInt,
                    mode         = "RW",
                ))

        ##############################
        # Commands
        ##############################
        @self.command(value='',description="Load the .CSV from CBPro.",)
        def LoadCsvFile(arg):
            # Check if non-empty argument
            if (arg != ""):
                path = arg
            else:
                # Use the variable path instead
                path = self.CsvFilePath.get()

            # Check for .csv file
            if fnmatch.fnmatch(path, '*.csv'):
                click.secho( f'{self.path}.LoadCsvFile(): {path}', fg='green')
            else:
                click.secho( f'{self.path}.LoadCsvFile(): {path} is not .csv', fg='red')
                return

            # Power down during the configuration load
            self.Page0.PDN.set(True)

            # Open the .CSV file
            with open(path) as csvfile:
                reader = csv.reader(csvfile, delimiter=',', quoting=csv.QUOTE_NONE)
                # Loop through the rows in the CSV file
                for row in reader:
                    if (row[0]!='Address'):
                        self._setValue(
                            offset = (int(row[0],16)<<2),
                            data   = int(row[1],16),
                        )

            # Update local RemoteVariables and verify conflagration
            self.readBlocks(recurse=True)
            self.checkBlocks(recurse=True)

            # Execute the Page5.BW_UPDATE_PLL command
            self._setValue((0x500<<2)|(0x14 << 2),0x1)
            self._setValue((0x500<<2)|(0x14 << 2),0x0)

            # Power Up after the configuration load
            self.Page0.PDN.set(False)

            # Clear the internal error flags
            self.Page0.ClearIntErrFlag()

        ##############################
        # Devices
        ##############################
        self.add(silabs.Si5345Page0(offset=(0x000<<2),simpleDisplay=simpleDisplay,expand=False))

        self.add(pr.LinkVariable(
            name         = 'Locked',
            description  = 'Inverse of LOL',
            mode         = 'RO',
            dependencies = [self.Page0.LOL],
            linkedGet    = lambda: (False if self.Page0.LOL.value() else True)
        ))

    def _setValue(self,offset,data):
        if self._useVars:
            self.DataBlock[offset//0x400].set(value=data,idx=(offset%0x400))
        else:
            self._rawWrite(offset,data)  # Deprecated
