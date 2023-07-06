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
import time

class Si5394Lite(pr.Device):
    def __init__(self,
            simpleDisplay = True,
            advanceUser   = False,
            liteVersion   = True,
            **kwargs):

        super().__init__(**kwargs)

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

            # write in the preamble:
            # Write 0x0B24 = 0xC0
            # Write 0x0B25 = 0x00
            # Write 0x0540 = 0x01
            self._setValue(offset=0x0B24<<2,data=0xC0)
            self._setValue(offset=0x0B25<<2,data=0x00)
            self._setValue(offset=0x0540<<2,data=0x01)

            # Wait 300 ms for Grade A/B/C/D/J/K/L/M, Wait 625ms for Grade P/E
            time.sleep(1.0)

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

            # write in the post-amble:
            # Write 0x0514 = 0x01
            # Write 0x001C = 0x01
            # Write 0x0540 = 0x00
            # Write 0x0B24 = 0xC3
            # Write 0x0B25 = 0x02
            self._setValue(offset=0x0514<<2,data=0x01)
            self._setValue(offset=0x001C<<2,data=0x01)
            self._setValue(offset=0x0540<<2,data=0x00)
            self._setValue(offset=0x0B24<<2,data=0xC3)
            self._setValue(offset=0x0B25<<2,data=0x02)

        ##############################
        # Pages
        ##############################
        self._pages = {
            0:  silabs.Si5345Page0(offset=(0x000<<2),simpleDisplay=simpleDisplay,expand=False),
            1:  silabs.Si5345PageBase(name='Page1',offset=(0x100<<2),expand=False,hidden=not (advanceUser)),
            2:  silabs.Si5345PageBase(name='Page2',offset=(0x200<<2),expand=False,hidden=not (advanceUser)),
            3:  silabs.Si5345PageBase(name='Page3',offset=(0x300<<2),expand=False,hidden=not (advanceUser)),
            4:  silabs.Si5345PageBase(name='Page4',offset=(0x400<<2),expand=False,hidden=not (advanceUser)),
            5:  silabs.Si5345PageBase(name='Page5',offset=(0x500<<2),expand=False,hidden=not (advanceUser)),
            6:  silabs.Si5345PageBase(name='Page6',offset=(0x600<<2),expand=False,hidden=not (advanceUser)),
            7:  silabs.Si5345PageBase(name='Page7',offset=(0x700<<2),expand=False,hidden=not (advanceUser)),
            8:  silabs.Si5345PageBase(name='Page8',offset=(0x800<<2),expand=False,hidden=not (advanceUser)),
            9:  silabs.Si5345PageBase(name='Page9',offset=(0x900<<2),expand=False,hidden=not (advanceUser)),
            10: silabs.Si5345PageBase(name='PageA',offset=(0xA00<<2),expand=False,hidden=not (advanceUser)),
            11: silabs.Si5345PageBase(name='PageB',offset=(0xB00<<2),expand=False,hidden=not (advanceUser)),
            12: silabs.Si5345PageBase(name='PageC',offset=(0xC00<<2),expand=False,hidden=not (advanceUser)),
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
        # Note: index is byte index (not word index)
        self._pages[offset // 0x400].DataBlock.set(value=data,index=(offset%0x400)>>2)
