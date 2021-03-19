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
            liteVersion   = True,
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
            self.Page5.BW_UPDATE_PLL()

            # Power Up after the configuration load
            self.Page0.PDN.set(False)

            # Clear the internal error flags
            self.Page0.ClearIntErrFlag()

        ##############################
        # Pages
        ##############################
        self._pages = {
            0:  silabs.Si5345Page0(offset=(0x000<<2),simpleDisplay=simpleDisplay,expand=False), # 0x0000 - 0x03FF
            1:  silabs.Si5345Page1(offset=(0x100<<2),simpleDisplay=simpleDisplay,expand=False,hidden=not(advanceUser),liteVersion=liteVersion),  # 0x0400 - 0x07FF
            2:  silabs.Si5345Page2(offset=(0x200<<2),simpleDisplay=simpleDisplay,expand=False,hidden=not(advanceUser),liteVersion=liteVersion),  # 0x0800 - 0x0BFF
            3:  silabs.Si5345Page3(offset=(0x300<<2),simpleDisplay=simpleDisplay,expand=False,hidden=not(advanceUser),liteVersion=liteVersion),  # 0x0C00 - 0x0FFF
            4:  silabs.Si5345Page4(offset=(0x400<<2),simpleDisplay=simpleDisplay,expand=False,hidden=not(advanceUser),liteVersion=liteVersion),  # 0x1000 - 0x13FF
            5:  silabs.Si5345Page5(offset=(0x500<<2),simpleDisplay=simpleDisplay,expand=False,hidden=not(advanceUser),liteVersion=liteVersion),  # 0x1400 - 0x17FF

            6:  silabs.Si5345PageBase(name='Page6',offset=(0x600<<2),expand=False,hidden=not(advanceUser)),  # 0x1800 - 0x1BFF
            7:  silabs.Si5345PageBase(name='Page7',offset=(0x700<<2),expand=False,hidden=not(advanceUser)),  # 0x1C00 - 0x1FFF
            8:  silabs.Si5345PageBase(name='Page8',offset=(0x800<<2),expand=False,hidden=not(advanceUser)),  # 0x2000 - 0x23FF

            9:  silabs.Si5345Page9(offset=(0x900<<2),simpleDisplay=simpleDisplay,expand=False,hidden=not(advanceUser),liteVersion=liteVersion),  # 0x2400 - 0x27FF
            10: silabs.Si5345PageA(offset=(0xA00<<2),simpleDisplay=simpleDisplay,expand=False,hidden=not(advanceUser),liteVersion=liteVersion),  # 0x2800 - 0x2BFF
            11: silabs.Si5345PageB(offset=(0xB00<<2),simpleDisplay=simpleDisplay,expand=False,hidden=not(advanceUser),liteVersion=liteVersion),  # 0x2C00 - 0x2FFF
        }

        # Add Pages
        for k,v in self._pages.items():
            self.add(v)

        self.add(pr.LinkVariable(
            name         = 'Locked',
            description  = 'Inverse of LOL',
            mode         = 'RO',
            dependencies = [self.Page0.LOL],
            linkedGet    = lambda: (False if self.Page0.LOL.value() else True)
        ))

    def _setValue(self,offset,data):
        if self._useVars:
            # Note: index is byte index (not word index)
            self._pages[offset // 0x400].DataBlock.set(value=data,index=(offset%0x400)>>2)
        else:
            self._rawWrite(offset,data)  # Deprecated
