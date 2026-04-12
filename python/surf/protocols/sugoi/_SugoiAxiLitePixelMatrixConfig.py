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
import fnmatch
import click
import numpy as np

class SugoiAxiLitePixelMatrixConfig(pr.Device):
    def __init__(self,
            colWidth   = 6,
            rowWidth   = 6,
            dataWidth  = 9,
            timerWidth = 16,
            numCol     = 48,
            numRow     = 48,
            **kwargs):
        super().__init__(**kwargs)
        self.numCol = numCol
        self.numRow = numRow
        self.numPixMax = (2**colWidth)*(2**rowWidth)

        self.add(pr.RemoteVariable(
            name        = 'Version',
            description = 'Firmware version of the pixel matrix configuration interface',
            offset      = 0x0,
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'COL_GRAY_CODE_G',
            description = 'Generic: column address uses Gray code encoding when True',
            offset      = 0x0,
            bitSize     = 1,
            bitOffset   = 4,
            mode        = 'RO',
            base        = pr.Bool,
        ))

        self.add(pr.RemoteVariable(
            name        = 'ROW_GRAY_CODE_G',
            description = 'Generic: row address uses Gray code encoding when True',
            offset      = 0x0,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RO',
            base        = pr.Bool,
        ))

        self.add(pr.RemoteVariable(
            name        = 'COL_WIDTH_G',
            description = 'Generic: bit width of the column address bus',
            offset      = 0x0,
            bitSize     = 4,
            bitOffset   = 8,
            mode        = 'RO',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ROW_WIDTH_G',
            description = 'Generic: bit width of the row address bus',
            offset      = 0x0,
            bitSize     = 4,
            bitOffset   = 12,
            mode        = 'RO',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DATA_WIDTH_G',
            description = 'Generic: bit width of each pixel data word',
            offset      = 0x0,
            bitSize     = 4,
            bitOffset   = 16,
            mode        = 'RO',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TIMER_WIDTH_G',
            description = 'Generic: bit width of the inter-pixel timer counter',
            offset      = 0x0,
            bitSize     = 8,
            bitOffset   = 24,
            mode        = 'RO',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TimerSize',
            description = 'Inter-pixel programming timer period (in clock cycles)',
            offset      = 0xC,
            bitSize     = timerWidth,
            bitOffset   = 0,
            mode        = 'RW',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'AllCol',
            description = 'Enable broadcast write to all columns simultaneously',
            offset      = 0xC,
            bitSize     = 1,
            bitOffset   = 16,
            mode        = 'RW',
            base        = pr.Bool,
        ))

        self.add(pr.RemoteVariable(
            name        = 'AllRow',
            description = 'Enable broadcast write to all rows simultaneously',
            offset      = 0xC,
            bitSize     = 1,
            bitOffset   = 17,
            mode        = 'RW',
            base        = pr.Bool,
        ))

        self.add(pr.RemoteVariable(
            name        = 'GlobalRstL',
            description = 'Global reset for the pixel matrix (active LOW)',
            offset      = 0xC,
            bitSize     = 1,
            bitOffset   = 18,
            mode        = 'RW',
            base        = pr.Bool,
        ))

        for i in range(self.numRow):
            self.add(pr.RemoteVariable(
                name         = f'_PixData[{i}]',
                description  = f'Raw pixel data array for row {i} (one 32-bit word per column)',
                offset       = (self.numPixMax<<2) +(i*(2**colWidth)<<2),
                bitSize      = 32 * self.numCol,
                bitOffset    = 0,
                numValues    = self.numCol,
                valueBits    = 32,
                valueStride  = 32,
                updateNotify = True,
                bulkOpEn     = False, # FALSE for large variables
                overlapEn    = False,
                verify       = False, # Set to True to add verification step but slow down the readout
                hidden       = True,
                base         = pr.UInt,
                mode         = "RW",
                groups       = ['NoStream','NoState','NoConfig'], # Not saving config/state to YAML
            ))

        self.add(pr.RemoteVariable(
            name        = 'AllMatrixValue',
            description = 'Write this value to all pixels when AllCol and AllRow are set',
            offset      = (self.numPixMax<<2) + ((self.numPixMax-1)<<2) ,
            bitSize     = 32,
            bitOffset   = 0,
            hidden      = True,
            mode        = 'WO',
        ))

        @self.command(value='',description="Programming bits for each pixel of the matrix",)
        def SetAllColAllRow(arg):
            self.AllCol.set(0x1)
            self.AllRow.set(0x1)
            self.AllMatrixValue.set(int(arg))

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
                if matrixCfg.shape == (self.numRow, self.numCol):
                    for i in range (self.numRow):
                        self._PixData[i].set(np.array(matrixCfg[i],np.uint32))
                else:
                    click.secho( f'.CSV file must be {self.numCol} X {self.numRow} (cols X rows) pixels')
            else:
                click.secho( "Warning: ASIC enable is set to False!")

        @self.command(value='',description="",)
        def ReadAllMatrix(arg):
            for i in range (self.numRow):
                click.secho(f' Row: {i}')
                click.secho(f' Read: {self._PixData[i].get()}')


    def LoadRowValue(self, row, val, verbose=False):

        """Configure an entire row with provided values"""

        if row < 0 or row >= self.numRow:
            click.secho(f'[ERROR]: {self.path}.LoadRowValue(): Row {row} out of range [0, {self.numRow-1}]', fg='red')
            return

        if not self.enable.get():
            click.secho("[WARNING]: ASIC enable is set to False!", fg='yellow')
            return

        try:
            valNpArray = np.array(val, np.uint32)
        except (TypeError, ValueError):
            click.secho(f'[ERROR]: {self.path}.LoadRowValue(): Value must be a list/array', fg='red')
            return

        # Check if val is a list/array of correct length
        if len(valNpArray) != self.numCol:
            click.secho(f'[ERROR]: {self.path}.LoadRowValue(): Value array length {len(valNpArray)} does not match number of columns ({self.numCol})', fg='red')
            return

        # val should be an array of length numCol
        self._PixData[row].set(valNpArray)

        if verbose:
            click.secho(f'[INFO]: {self.path}.LoadRowValue(): Set row {row} with {valNpArray}', fg='green')

    def LoadPixelValue(self, col, row, val, verbose=False):

        """Configure a single pixel at specified column and row"""

        # Validate column and row bounds
        if col < 0 or col >= self.numCol:
            click.secho(f'[ERROR]: {self.path}.LoadPixelValue(): Column {col} out of range [0, {self.numCol-1}]', fg='red')
            return

        if row < 0 or row >= self.numRow:
            click.secho(f'[ERROR]: {self.path}.LoadPixelValue(): Row {row} out of range [0, {self.numRow-1}]', fg='red')
            return

        if not self.enable.get():
            click.secho("[WARNING]: ASIC enable is set to False!", fg='yellow')
            return

        # Read current row data, modify the specific column, write back
        current_row = self._PixData[row].get()
        current_row[col] = np.uint32(val)
        self._PixData[row].set(current_row)

        if verbose:
            click.secho(f'[INFO]: {self.path}.LoadPixelValue(): Set pixel ({col},{row}) with {val}', fg='green')
