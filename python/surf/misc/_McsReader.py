#-----------------------------------------------------------------------------
# Title      : PyRogue _proms Module
#-----------------------------------------------------------------------------
# Description:
# PyRogue _proms Module
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import numpy as np
import functools
import click
import gzip
import subprocess
import fnmatch

class McsException(Exception):
    pass

class McsReader():

    def __init__(self,name="McsReader"):
        self.entry     = []
        self.startAddr = 0
        self.endAddr   = 0
        self.size      = 0
        self.addrRange = 0
        self.lastAddr  = 0

    def open(self, filename, dbg=False):
        self.startAddr = 0
        self.endAddr   = 0
        self.size      = 0
        self.addrRange = 0
        self.lastAddr  = 0
        baseAddr       = 0
        idx            = 0
        firstAddr      = True

        # Check for non-compressed .MCS file
        if fnmatch.fnmatch(filename, '*.mcs'):
            # Set the flag
            gzipEn = False
            # Find the length of the file
            numLines = int(subprocess.check_output(f'wc -l {filename}', shell=True).split()[0])

        # Check for Compressed .MCS file
        elif fnmatch.fnmatch(filename, '*.mcs.gz'):
            # Set the flag
            gzipEn = True
            # Find the length of the file
            numLines = int(subprocess.check_output(f'zcat {filename} | wc -l', shell=True).split()[0])

        else:
            click.secho('\nUnsupported file extension detected', fg='red')
            raise McsException('McsReader.open(): failed')

        # Create an empty numpy array (up to 16B per line)
        self.entry = np.empty([16*numLines,2],dtype=np.int32)

        # Setup the status bar
        with click.progressbar(
            length = numLines,
            label  = click.style('Reading .MCS:  ', fg='green'),
        ) as bar:
            # Open the file
            with ( gzip.open(filename, "rb") if (gzipEn) else open(filename, 'r') ) as f:
                for i, line in enumerate(f):
                    # Readout a line
                    line = line.strip()

                    # Check if GZIP and convert to standard string
                    if (gzipEn):
                        line = str(line)[2:-1]

                    # Throttle down printf rate
                    if ( (i&0xFFF) == 0):
                        bar.update(0xFFF)

                    # Check for "start code"
                    if line[0] != ':':
                        click.secho( f'\nMissing start code. Line[{i}]: ({line})', fg='red')
                        raise McsException('McsReader.open(): failed')
                    else:

                        hexBytes = [int(line[j:j+2], 16) for j in range(1, len(line), 2)]

                        s = functools.reduce(lambda x,y: x+y, hexBytes[:-1]) & 0xFF
                        c = (hexBytes[-1]*-1) & 0xFF

                        if s != c:
                            click.secho('\nBad checksum on line: {:s}. Sum: {:x}, checksum: {:x}'.format(line, s, c), fg='red')
                            raise McsException('McsReader.open(): failed')

                        # Parse out the bytes
                        byteCount = hexBytes[0]
                        addr = int(hexBytes[1])<<8 | int(hexBytes[2])
                        recordType = hexBytes[3]

                        if byteCount > 16:
                            click.secho('\nInvalid byte count: {:d}'.format(byteCount), fg='red')
                            raise McsException('McsReader.open(): failed')

                        elif recordType == 0: # Data RecordType

                            if byteCount == 0:
                                click.secho(f'\nInvalid byte count: {byteCount} for recordType: {recordType}', fg='red')
                                raise McsException('McsReader.open(): failed')
                            for j in range(byteCount):
                                # Put the address and data into a list
                                address = baseAddr + addr + j
                                data = hexBytes[j+4]
                                self.entry[idx] = [address, data]
                                idx = idx + 1
                                # Check if not the start address
                                if (address != self.startAddr):
                                    # Check for non-contiguous address
                                    if ( address != (self.lastAddr+1) ) and firstAddr is False:
                                        click.secho('\n non-contiguous address detected: PreviousAddress={:x}, CurrentAddress={:x}'.format(self.lastAddr,address), fg='red')
                                        raise McsException('McsReader.open(): failed')
                                    else:
                                        self.lastAddr = address
                                        firstAddr     = False
                            # Save the last address
                            self.endAddr = address

                        elif recordType == 1: # End Of File RecordType
                            break

                        elif recordType == 4: #Extended Linear Address RecordType
                            # Check for an invalid byte count
                            if byteCount != 2:
                                click.secho(f'\nMcsReader.open():Byte count: {byteCount} must be 2 for ELA records', fg='red')
                                raise McsException('McsReader.open(): failed')
                            # Check for an invalid address header
                            elif addr != 0:
                                click.secho('\nAddr: {:x} must be 0 for ELA records'.format(addr), fg='red')
                                raise McsException('McsReader.open(): failed')
                            # Update the base address
                            baseAddr = int(line[9:11]+line[11:13], 16)* (2**16)
                            # Check for first address index (which is always the first line)
                            if (i==0):
                                self.startAddr = baseAddr
                                self.lastAddr  = baseAddr
                        else: # Undefined RecordType
                            click.secho('\nInvalid record type: {:d}'.format(recordType), fg='red')
                            raise McsException('McsReader.open(): failed')

            # Close the status bar
            bar.update(numLines)

        # Set the size of the entry array
        self.size = idx

        # Calculate the total size (in units of bytes)
        self.addrRange = (self.endAddr - self.startAddr) + 1

        # Print the MCS metadata
        if (dbg):
            print("mcs.size      = {}".format(hex(self.size)))
            print("mcs.startAddr = {}".format(hex(self.startAddr)))
            print("mcs.endAddr   = {}".format(hex(self.endAddr)))
            print("mcs.addrRange = {}".format(hex(self.addrRange)))
