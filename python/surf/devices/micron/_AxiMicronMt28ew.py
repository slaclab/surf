#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite Micron MT28EW PROM
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Lite Micron MT28EW (or Cypress S29G) PROM
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue   as pr
import surf.misc
import click
import time
import datetime
import math

class AxiMicronMt28ew(pr.Device):
    def __init__(self,
                 description = "AXI-Lite Micron MT28EW (or Cypress S29G) PROM",
                 tryCount    = 5,
                 hidden      = True,
                 **kwargs):

        super().__init__(
            description = description,
            hidden      = hidden,
            **kwargs)

        self._mcs = surf.misc.McsReader()
        self._progDone = False
        self._tryCount = tryCount

        ##############################
        # Setup variables
        ##############################
        self.add(pr.RemoteVariable(
            name         = 'DataWrBus',
            offset       = 0x0,
            base         = pr.UInt,
            bitSize      = 32,
            bitOffset    = 0,
            retryCount   = tryCount,
            updateNotify = False,
            bulkOpEn     = False,
            hidden       = True,
            verify       = False,
        ))

        self.add(pr.RemoteVariable(
            name         = 'AddrBus',
            offset       = 0x4,
            base         = pr.UInt,
            bitSize      = 32,
            bitOffset    = 0,
            retryCount   = tryCount,
            updateNotify = False,
            bulkOpEn     = False,
            hidden       = True,
            verify       = False,
        ))

        self.add(pr.RemoteVariable(
            name         = 'DataRdBus',
            offset       = 0x8,
            base         = pr.UInt,
            bitSize      = 32,
            bitOffset    = 0,
            retryCount   = tryCount,
            updateNotify = False,
            bulkOpEn     = False,
            hidden       = True,
            verify       = False,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TranSize',
            offset       = 0x80,
            base         = pr.UInt,
            bitSize      = 32,
            bitOffset    = 0,
            retryCount   = tryCount,
            updateNotify = False,
            bulkOpEn     = False,
            hidden       = True,
            verify       = False,
        ))

        self.add(pr.RemoteVariable(
            name         = 'BurstTran',
            offset       = 0x84,
            base         = pr.UInt,
            bitSize      = 32,
            bitOffset    = 0,
            retryCount   = tryCount,
            updateNotify = False,
            bulkOpEn     = False,
            hidden       = True,
            verify       = False,
        ))

        self.add(pr.RemoteVariable(
            name         = 'BurstData',
            offset       = 0x400,
            base         = pr.UInt,
            bitSize      = 32*256,
            bitOffset    = 0,
            numValues    = 256,
            valueBits    = 32,
            valueStride  = 32,
            retryCount   = tryCount,
            updateNotify = False,
            bulkOpEn     = False,
            hidden       = True,
            verify       = False,
            groups       = ['NoStream','NoState','NoConfig'], # Not saving config/state to YAML
        ))

        self.add(pr.LocalCommand(
            name        = 'LoadMcsFile',
            function    = self._LoadMcsFile,
            description = 'Load the .MCS into PROM',
            value       = '',
        ))

    def _LoadMcsFile(self,arg):
        click.secho(('%s.LoadMcsFile: %s' % (self.path,arg) ), fg='green')
        self._progDone = False

        # Start time measurement for profiling
        start = time.time()

        # Open the MCS file
        self._mcs.open(arg)

        # Erase the PROM
        self.eraseProm()

        # Write to the PROM
        self.bufferedWriteProm()

        # Verify the PROM
        self.bufferedVerifyProm()

        # End time measurement for profiling
        end = time.time()
        elapsed = end - start
        click.secho('LoadMcsFile() took %s to program the PROM' % datetime.timedelta(seconds=int(elapsed)), fg='green')

        # Add a power cycle reminder
        self._progDone = True
        click.secho(
            "\n\n\
            ***************************************************\n\
            ***************************************************\n\
            The MCS data has been written into the PROM.       \n\
            To reprogram the FPGA with the new PROM data,      \n\
            a IPROG CMD or power cycle is be required.\n\
            ***************************************************\n\
            ***************************************************\n\n"
            , bg='green',
        )

    # Reset Command
    def _resetCmd(self):
        self._writeToFlash(0x555,0xAA)
        self._writeToFlash(0x2AA,0x55)
        self._writeToFlash(0x555,0xF0)

    def eraseProm(self):
        # Reset the PROM
        self._resetCmd()
        # Set the starting address index
        address    = self._mcs.startAddr >> 1
        # Uniform block size of 64-kword/block
        ERASE_SIZE = 0x10000
        # Setup the status bar
        with click.progressbar(
            iterable = range(math.ceil(self._mcs.size/ERASE_SIZE)),
            label    = click.style('Erasing PROM:  ', fg='green'),
        ) as bar:
            for i in bar:
                # Execute the erase command
                self._eraseCmd(address)
                # Increment by one block
                address += ERASE_SIZE
        # Check the corner case
        if ( address< (self._mcs.endAddr>>1) ):
            self._eraseCmd(address)

    # Erase Command
    def _eraseCmd(self, address):
        self._writeToFlash(0x555,0xAA)
        self._writeToFlash(0x2AA,0x55)
        self._writeToFlash(0x555,0x80)
        self._writeToFlash(0x555,0xAA)
        self._writeToFlash(0x2AA,0x55)
        self._writeToFlash(address,0x30)
        self.waitForFlashReady()

    def bufferedWriteProm(self):
        # Reset the PROM
        self._resetCmd()
        # Create a burst data array
        dataArray = self.BurstData.get(read=False)

        # Set the block transfer size
        self.TranSize.set(0xFF)

        # Setup the status bar
        with click.progressbar(
            length   = self._mcs.size,
            label    = click.style('Writing PROM:  ', fg='green'),
        ) as bar:
            for i in range(self._mcs.size):
                if ( (i&0x1) == 0):
                    # Check for first byte of burst transfer
                    if ( (i&0x1FF) == 0):
                        # Throttle down printf rate
                        bar.update(0x1FF)
                        # Get the start bursting address
                        addr = int(self._mcs.entry[i][0])>>1 # 16-bit word addressing at the PROM
                        # Reset the counter
                        cnt = 0
                    # Get the data from MCS file
                    dataArray[cnt] = int(self._mcs.entry[i][1]) & 0xFF
                else:
                    # Get the data from MCS file
                    dataArray[cnt] |= (int(self._mcs.entry[i][1])   << 8)
                    cnt += 1
                    # Check for the last byte
                    if ( cnt == 256 ):

                        # Write burst data
                        self.BurstData.set(dataArray)
                        # Start a burst transfer
                        self.BurstTran.set(0x7FFFFFFF&addr)

            # Check for leftover data
            if (cnt != 256):
                # Fill the rest of the data array with ones
                for i in range(cnt, 256):
                    dataArray[i] = 0xFFFF

                # Write burst data
                self.BurstData.set(dataArray)
                # Start a burst transfer
                self.BurstTran.set(0x7FFFFFFF&addr)

            # Close the status bar
            bar.update(self._mcs.size)

    def writeProm(self):
        # Reset the PROM
        self._resetCmd()
        # Setup the status bar
        with click.progressbar(
            length   = self._mcs.size,
            label    = click.style('Writing PROM:  ', fg='green'),
        ) as bar:
            for i in range(self._mcs.size):
                if ( (i&0x1) == 0):
                    # Get the data and address from MCS file
                    addr = int(self._mcs.entry[i][0])>>1 # 16-bit word addressing at the PROM
                    data = int(self._mcs.entry[i][1]) & 0xFF
                else:
                    # Get the data for MCS file
                    data |= (int(self._mcs.entry[i][1])  << 8)

                    self._writeToFlash(0x555,0xAA)
                    self._writeToFlash(0x2AA,0x55)
                    self._writeToFlash(0x555,0xA0)
                    self._writeToFlash(addr,data)
                    self.waitForFlashReady()

                # Check for burst transfer
                if ( (i&0x1FF) == 0):
                    # Throttle down printf rate
                    bar.update(0x1FF)

            # Close the status bar
            bar.update(self._mcs.size)

    def bufferedVerifyProm(self):
        # Reset the PROM
        self._resetCmd()

        # Set the data bus
        self.DataWrBus.set(0xFFFFFFFF)
        # Set the block transfer size
        self.TranSize.set(0xFF)

        # Setup the status bar
        with click.progressbar(
            length  = self._mcs.size,
            label   = click.style('Verifying PROM:', fg='green'),
        ) as bar:
            for i in range(self._mcs.size):

                if ( (i&0x1) == 0):
                    # Get the data and address from MCS file
                    addr = int(self._mcs.entry[i][0])>>1 # 16-bit word addressing at the PROM
                    data = int(self._mcs.entry[i][1]) & 0xFF

                    # Check for burst transfer
                    if ( (i&0x1FF) == 0):
                        # Throttle down printf rate
                        bar.update(0x1FF)

                        # Start a burst transfer
                        self.BurstTran.set(0x80000000|addr)

                        # Get the data
                        dataArray = self.BurstData.get()

                else:
                    # Get the data for MCS file
                    data |= (int(self._mcs.entry[i][1])  << 8)
                    # Get the prom data from data array
                    prom = dataArray[(i&0x1FF)>>1]
                    # Compare PROM to file
                    if (data != prom):
                        click.secho(("\nAddr = 0x%x: MCS = 0x%x != PROM = 0x%x" % (addr,data,prom)), fg='red')
                        raise surf.misc.McsException('bufferedVerifyProm() Failed\n\n')
            # Close the status bar
            bar.update(self._mcs.size)

    def verifyProm(self):
        # Reset the PROM
        self._resetCmd()
        # Setup the status bar
        with click.progressbar(
            length  = self._mcs.size,
            label   = click.style('Verifying PROM:', fg='green'),
        ) as bar:
            for i in range(self._mcs.size):
                if ( (i&0x1) == 0):
                    # Get the data and address from MCS file
                    addr = int(self._mcs.entry[i][0])>>1 # 16-bit word addressing at the PROM
                    data = int(self._mcs.entry[i][1]) & 0xFF
                else:
                    # Get the data for MCS file
                    data |= (int(self._mcs.entry[i][1])  << 8)
                    # Get the prom data from data array
                    prom = self._readFromFlash(addr)
                    # Compare PROM to file
                    if (data != prom):
                        click.secho(("\nAddr = 0x%x: MCS = 0x%x != PROM = 0x%x" % (addr,data,prom)), fg='red')
                        raise surf.misc.McsException('verifyProm() Failed\n\n')

                # Check for burst transfer
                if ( (i&0x1FF) == 0):
                    # Throttle down printf rate
                    bar.update(0x1FF)

            # Close the status bar
            bar.update(self._mcs.size)

    # Generic FLASH write Command
    def _writeToFlash(self, addr, data):
        # Set the data bus
        self.DataWrBus.set(data)
        # Set the address bus and initiate the transfer
        self.AddrBus.set(addr&0x7FFFFFFF)

    # Generic FLASH read Command
    def _readFromFlash(self, addr):
        # Set the address
        self.AddrBus.set(addr|0x80000000)
        # Get the read data
        return self.DataRdBus.get()&0xFFFF

    def waitForFlashReady(self):
        while True:
            self._writeToFlash(0x555,0x70)
            status = self._readFromFlash(0x555)
            if ( (status&0x80) != 0 ):
                break
