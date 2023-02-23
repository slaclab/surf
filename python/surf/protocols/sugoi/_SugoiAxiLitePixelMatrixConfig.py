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
import time
import fnmatch
import click
import numpy as np

class SugoiAxiLitePixelMatrixConfig(pr.Device):
    def __init__(self,
            colWidth   = 7,
            rowWidth   = 8,
            dataWidth  = 9,
            timerWidth = 16,
            **kwargs):
        super().__init__(**kwargs)
        self.numCol = 2**colWidth,
        self.numRow = 2**rowWidth,
        self.numPix = self.numCol*self.numRow,

        self.add(pr.RemoteVariable(
            name      = 'Version',
            offset    = 0x0,
            bitSize   = 4,
            bitOffset = 0,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      = 'COL_GRAY_CODE_G',
            offset    = 0x0,
            bitSize   = 1,
            bitOffset = 4,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      = 'ROW_GRAY_CODE_G',
            offset    = 0x0,
            bitSize   = 1,
            bitOffset = 5,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      = 'COL_WIDTH_G',
            offset    = 0x0,
            bitSize   = 4,
            bitOffset = 8,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      = 'ROW_WIDTH_G',
            offset    = 0x0,
            bitSize   = 4,
            bitOffset = 12,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      = 'DATA_WIDTH_G',
            offset    = 0x0,
            bitSize   = 4,
            bitOffset = 16,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      = 'TIMER_WIDTH_G',
            offset    = 0x0,
            bitSize   = 8,
            bitOffset = 24,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      = 'TimerSize',
            offset    = 0xC,
            bitSize   = timerWidth,
            bitOffset = 0,
            mode      = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name      = 'AllCol',
            offset    = 0xC,
            bitSize   = 1,
            bitOffset = 16,
            mode      = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name      = 'AllRow',
            offset    = 0xC,
            bitSize   = 1,
            bitOffset = 17,
            mode      = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name      = 'GlobalRstL',
            offset    = 0xC,
            bitSize   = 1,
            bitOffset = 18,
            mode      = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'PixData',
            offset       = (self.numPix<<2),
            bitSize      = 32 * self.numPix,
            bitOffset    = 0,
            numValues    = self.numPix,
            valueBits    = 32,
            valueStride  = 32,
            updateNotify = True,
            bulkOpEn     = False, # FALSE for large variables
            overlapEn    = False,
            verify       = False, # Set to True to add verification step but slow down the readout
            hidden       = True,
            base         = pr.UInt,
            mode         = "RW",
        ))

        @self.command()
        def SetupWrite():
            self.GlobalRstL.set(0x1)
            self.TimerSize.set(0x2)

        @self.command()
        def SetAllColAllRow():
            self.AllCol.set(0x1)
            self.AllRow.set(0x1)

        @self.command()
        def ResetAllColAllRow():
            self.AllCol.set(0x0)
            self.AllRow.set(0x0)

        self.add(pr.LocalVariable(
            name         = 'CsvFilePath',
            description  = 'Used if command argument is empty',
            mode         = 'RW',
            value        = '',
        ))

        @self.command(value='',description="Load the .CSV",)
        def LoadCsvPixelBitmap(arg):
            # Check if non-empty argument
            if (arg != ""):
                path = arg
            else:
                # Use the variable path instead
                path = self.CsvFilePath.get()

            # Check for .csv file
            if fnmatch.fnmatch(path, '*.csv'):
                click.secho( f'{self.path}.LoadCsvPixelBitmap(): {path}', fg='green')
            else:
                click.secho( f'{self.path}.LoadCsvPixelBitmap(): {path} is not .csv', fg='red')
                return

            if (self.enable.get()):
                matrixCfg = np.genfromtxt(path, dtype=np.int32, delimiter=',')
                if matrixCfg.shape == (self.numCol, self.numRow):
                    self.PixData.set(matrixCfg)
                else:
                    click.secho( f'.CSV file must be {numCol} X {numRow} pixels')
            else:
                click.secho( "Warning: ASIC enable is set to False!")
