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
import gzip
import os
import fnmatch

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

        # Check for non-compressed .MCS file
        if fnmatch.fnmatch(filename, '*.mcs'):
            gzipEn = False
        elif fnmatch.fnmatch(filename, '*.mcs.gz'):
            gzipEn = True
        else:
            click.secho('\nUnsupported file extension detected', fg='red')
            raise McsException('McsReader.open(): failed')  
            
        # Find the length of the file
        f = gzip.open(filename, "rb") if (gzipEn) else open(filename, "r")
        length = 0
        for line in iter(f):
            length += 1
        f.close()  
        # Setup the status bar
        with click.progressbar(
            length = length,
            label  = click.style('Reading .MCS:  ', fg='green'),
        ) as bar:            
            # Open the file
            with ( gzip.open(filename, "rb") if (gzipEn) else open(filename, 'r') ) as f:            
                for i, line in enumerate(f):
                    # Readout a line
                    line = line.strip()
                    
                    # Check if GZIP and convert to standard string
                    if (gzipEn):
                        line = str(line)[2:]
                        line = str(line)[:-1]
                    
                    # Throttle down printf rate
                    if ( (i&0xFFF) == 0):
                        bar.update(0xFFF)                      
                        
                    # Check for "start code"
                    if line[0] != ':':
                        click.secho( ('\nMissing start code. Line[%d]: {:%s}' % (i,line)), fg='red')
                        raise McsException('McsReader.open(): failed')                         
                    else:
                    
                        strings = [line[j:j+2] for j in range(1, len(line), 2)]
                        bytes = [int(s, 16) for s in strings]

                        s = functools.reduce(lambda x,y: x+y, bytes[:-1]) & 0xFF
                        c = (bytes[-1]*-1) & 0xFF
                        
                        if s != c:                            
                            click.secho('\nBad checksum on line: {:s}. Sum: {:x}, checksum: {:x}'.format(line, s, c), fg='red')
                            raise McsException('McsReader.open(): failed') 

                        # Parse out the bytes
                        byteCount = bytes[0]
                        addr = int(bytes[1])<<8 | int(bytes[2])
                        recordType = bytes[3]
                       
                        if byteCount > 16:
                            click.secho('\nInvalid byte count: {:d}'.format(byteCount), fg='red')
                            raise McsException('McsReader.open(): failed') 

                        elif recordType == 0: # Data RecordType           
                            
                            if byteCount == 0:
                                click.secho('\nInvalid byte count: {:d} for recordType: {d}'.format(byteCount, recordType), fg='red')
                                raise McsException('McsReader.open(): failed') 
                            for j in range(byteCount):
                                # Put the address and data into a list
                                address = baseAddr + addr + j
                                data    = bytes[j+4]
                                dataList.append([address, data])
                            
                            # Save the last address
                            self.endAddr = address
                            
                        elif recordType == 1: # End Of File RecordType 
                            break

                        elif recordType == 4: #Extended Linear Address RecordType
                            # Check for an invalid byte count
                            if byteCount != 2:
                                click.secho('\nMcsReader.open():Byte count: {:d} must be 2 for ELA records'.format(byteCount), fg='red')
                                raise McsException('McsReader.open(): failed')  
                            # Check for an invalid address header
                            elif addr != 0:
                                click.secho('\nAddr: {:x} must be 0 for ELA records'.format(addr), fg='red')
                                raise McsException('McsReader.open(): failed')  
                            # Update the base address 
                            baseAddr = int(strings[4]+strings[5], 16)* (2**16)
                            # Check for first address index (which is always the first line)
                            if (i==0):
                                self.startAddr = baseAddr
                        else: # Undefined RecordType
                            click.secho('\nInvalid record type: {:d}'.format(recordType), fg='red')
                            raise McsException('McsReader.open(): failed')    
                            
            # Close the status bar
            bar.update(length)          
            
        # Calculate the total size (in units of bytes)                
        self.size = (self.endAddr - self.startAddr) + 1
        
        # Convert to numpy array
        self.entry = np.array(dataList,dtype=np.int32)
   
