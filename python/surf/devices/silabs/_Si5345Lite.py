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

class Si5345Lite(pr.Device):
    def __init__(self,
            simpleDisplay = True,
            advanceUser   = False,
            **kwargs):
        super().__init__(size=(0x1000<<2), **kwargs)

        self.add(pr.LocalVariable(
            name         = "CsvFilePath",
            description  = "Used if command's argument is empty",
            mode         = "RW",
            value        = "",
        ))




        self.add(pr.RemoteVariable(
            name         = "AlwaysWriteBit",
            description  = "",
            offset       = masterPage + (4*0x059),
            bitSize      = 32,
            bitOffset    = 0,
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
                        self._rawWrite(
                            offset = (int(row[0],16)<<2),
                            data   = int(row[1],16),
                        )

            # Update local RemoteVariables and verify conflagration
            self.readBlocks(recurse=True)
            self.checkBlocks(recurse=True)

            # Execute the Page5.BW_UPDATE_PLL command
            self._rawWrite((0x500<<2)|(0x14 << 2),0x1)
            self._rawWrite((0x500<<2)|(0x14 << 2),0x0)

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
