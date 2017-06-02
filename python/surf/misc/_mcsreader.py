#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue _proms Module
#-----------------------------------------------------------------------------
# File       : _proms.py
# Created    : 2016-09-29
# Last update: 2016-09-29
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

class McsException(Exception):
    pass

class McsReader():

    def __init__(self,name="McsReader"):
        self.entry     = []
        self.startAddr = 0
        self.endAddr   = 0
        self.size      = 0
        
    def open(self, filename):   
        self.entry     = []
        self.startAddr = 0
        self.endAddr   = 0
        self.size      = 0
        baseAddr       = 0
        dataList       = []
        # Open the file
        with open(filename, 'r') as f:
            # Setup the status bar
            with click.progressbar(enumerate(f),label='Reading .MCS:\t') as bar:
                for i, line in bar:
                    # Readout a line
                    line = line.strip()
                        
                    # Check for "start code"
                    if line[0] != ':':
                        raise McsException('McsReader.open(): Missing start code. Line: \n\t{:s}'.format(line))
                    else:
                    
                        strings = [line[j:j+2] for j in range(1, len(line), 2)]
                        bytes = [int(s, 16) for s in strings]

                        s = functools.reduce(lambda x,y: x+y, bytes[:-1]) & 0xFF
                        c = (bytes[-1]*-1) & 0xFF
                        
                        if s != c:
                            raise McsException("McsReader.open(): Bad checksum on line: {:s}. Sum: {:x}, checksum: {:x}".format(line, s, c))

                        # Parse out the bytes
                        byteCount = bytes[0]
                        addr = int(bytes[1])<<8 | int(bytes[2])
                        recordType = bytes[3]
                       
                        if byteCount > 16:
                            raise McsException('McsReader.open(): Invalid byte count: {:d}'.format(byteCount))

                        elif recordType == 0: # Data RecordType           
                            
                            if byteCount == 0:
                                raise McsException('McsReader.open(): Invalid byte count: {:d} for recordType: {d}'.format(byteCount, recordType))
                            for j in range(byteCount):
                                # Put the address and data into a list
                                address = baseAddr + addr + j
                                data    = bytes[(byteCount-j)+3]
                                dataList.append([address, data])
                            
                            # Save the last address
                            self.endAddr = address
                            
                        elif recordType == 1: # End Of File RecordType 
                            break

                        elif recordType == 4: #Extended Linear Address RecordType
                            # Check for an invalid byte count
                            if byteCount != 2:
                                raise McsException("McsReader.open():Byte count: {:d} must be 2 for ELA records".format(byteCount))
                            # Check for an invalid address header
                            elif addr != 0:
                                raise McsException("McsReader.open(): Addr: {:x} must be 0 for ELA records".format(addr))
                            # Check for first address index (which is always the first line)
                            if (i==0):
                                self.startAddr = addr
                            # Update the base address 
                            baseAddr = int(strings[4]+strings[5], 16)* (2**16)
                        else: # Undefined RecordType
                            raise McsException('McsReader.open(): Invalid record type: {:d}'.format(recordType))    

        # Calculate the total size (in units of bytes)                
        self.size = (self.endAddr - self.startAddr) + 1
        
        # Convert to numpy array
        self.entry = np.array(dataList)
