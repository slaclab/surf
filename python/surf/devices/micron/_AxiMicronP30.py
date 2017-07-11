#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite Micron P30 PROM
#-----------------------------------------------------------------------------
# File       : AxiMicronP30.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Lite Micron P30 PROM
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the rogue software platform, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr
import click
from surf.misc._mcsreader import *

class AxiMicronP30(pr.Device):
    def __init__(self,       
            name        = "AxiMicronP30",
            description = "AXI-Lite Micron P30 PROM",
            **kwargs):
        super(self.__class__, self).__init__(name=name, description=description, **kwargs)
        
        self._mcs = McsReader()        
        
        ##############################
        # Variables
        ##############################        
        self.add(pr.RemoteVariable(
            name         = "Test",
            description  = "Scratch Pad tester register",
            offset       =  0x0C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW"))
            
        @self.command(value='',description="Load the .MCS into PROM",)
        def LoadMcsFile(arg):    
            print ( "LoadMcsFile: %s" % arg)
            
            # Configuration: Force default configurations
            self._writeToFlash(0xFD4F,0x60,0x03)            
            
            # # Open the MCS file
            self._mcs.open(arg)                                           
            
            # Erase the PROM
            self.eraseProm()
            
            # Write to the PROM
            self.writeProm()
            
            # # Verify the PROM
            # self.verifyProm()
                        
    def eraseProm(self):
        # Set the starting address index
        address    = self._mcs.startAddr        
        # Assume the smallest block size of 16-kword/block
        ERASE_SIZE = 0x4000 
        # Setup the status bar
        with click.progressbar(
            iterable = range(int(self._mcs.size/ERASE_SIZE)),
            label    = '\t'+click.style('Erasing PROM:', bg='blue', fg='white')+'\t', 
        ) as bar:
            for i in bar:
                # Execute the erase command
                self._eraseCmd(address)
                # Increment by one block
                address += ERASE_SIZE
                
    # Erase Command
    def _eraseCmd(self, address):
        # Unlock the Block
        self._writeToFlash(address,0x60,0xD0)
        # Reset the status register
        self._writeToFlash(address,0x50,0x50)
        # Send the erase command
        self._writeToFlash(address,0x20,0xD0)
        while True:
            # Get the status register
            status = self._readFromFlash(address,0x70)
            # Check for erasing failure
            if( (status&0x20) != 0 ):            
                # Unlock the Block
                self._writeToFlash(address,0x60,0xD0)
                # Reset the status register
                self._writeToFlash(address,0x50,0x50)
                # Send the erase command
                self._writeToFlash(address,0x20,0xD0)                   
            elif( (status&0x80) != 0 ):
                break
        # Lock the Block
        self._writeToFlash(address,0x60,0x01)
        
    def writeProm(self):
        # Create a burst data array
        dataArray = [0] * 256
        # Set the block transfer size
        self._rawWrite(0x80,0xFF)        
        # Setup the status bar
        with click.progressbar(
            length   = self._mcs.size,
            label    = '\t'+click.style('Writing PROM:', bg='blue', fg='white')+'\t',   
        ) as bar:        
            for i in range(self._mcs.size):        
                if ( (i&0x1) == 0):
                    # Check for first byte of burst transfer
                    if ( (i&0x1FF) == 0):
                        # Throttle down printf rate
                        bar.update(0x1FF)            
                        # Get the start bursting address
                        addr =  self._mcs.entry[i][0]
                        # Reset the counter
                        cnt = 0
                    # Get the data from MCS file
                    dataArray[cnt] = (self._mcs.entry[i][1] << 8)
                else:
                    # Get the data from MCS file
                    dataArray[cnt] |= (self._mcs.entry[i][1]  << 8)
                    cnt += 1
                    # Check for the last byte
                    if ( cnt == 256 ):


                        # Write burst data
                        self._rawWrite(address=0x400, data=dataArray)
                        # Start a burst transfer
                        self._rawWrite(0x84,0x7FFFFFFF&addr)   
                        
            # Check for leftover data
            if (cnt != 256):
                # Fill the rest of the data array with ones
                for i in range(cnt, 256):
                    dataArray[i] = 0xFFFF


                # Write burst data
                self._rawWrite(address=0x400, data=dataArray)
                # Start a burst transfer
                self._rawWrite(0x84,0x7FFFFFFF&addr)                  

                
            # Close the status bar
            bar.update(self._mcs.size)  

    def verifyProm(self):     
        # Set the data bus 
        self._rawWrite(0x0,0xFFFFFFFF)
        # Set the block transfer size
        self._rawWrite(0x80,0xFF)
        # Setup the status bar
        with click.progressbar(
            length  = self._mcs.size,
            label   = '\t'+click.style('Verifying PROM:', bg='blue', fg='white')+'\t',               
        ) as bar:
            for i in range(self._mcs.size):
                if ( (i&0x1) == 0):
                    # Get the data and address from MCS file
                    addr =  self._mcs.entry[i][0]        
                    data = (self._mcs.entry[i][1] << 8)               
                    # Check for burst transfer
                    if ( (i&0x1FF) == 0):
                        # Throttle down printf rate
                        bar.update(0x1FF)
                        # Start a burst transfer
                        self._rawWrite(0x84,0x80000000|addr)
                        # Get the data
                        dataArray = self._rawRead(address=0x400,size=256,model=pr.UInt,stride=4)                
                else:
                    # Get the data for MCS file
                    data |= (self._mcs.entry[i][1]  << 8)
                    # Get the prom data from data array
                    prom = dataArray[(i>>1)]&0xFFFF
                    # Compare PROM to file
                    if (data != prom):
                        print ("\nAddr = 0x%x: data 0x%x != prom 0x%x" % (addr,data,prom))
                        raise McsException('verifyProm() Failed')
            # Close the status bar
            bar.update(self._mcs.size)  
        
    # Generic FLASH write Command 
    def _writeToFlash(self, addr, cmd, data):
        # Set the data bus 
        self._rawWrite(0x0, ((cmd&0xFFFF)<< 16) | (data&0xFFFF))
        # Set the address bus and initiate the transfer
        self._rawWrite(0x4,addr&0x7FFFFFFF)   
        
    # Generic FLASH read Command
    def _readFromFlash(self, addr, cmd):  
        # Set the data bus 
        self._rawWrite(0x0, ((cmd&0xFFFF)<< 16) | 0xFF)    
        # Set the address
        self._rawWrite(0x4,addr|0x80000000)  
        # Get the read data 
        return (self._rawRead(0x8)&0xFFFF) 
