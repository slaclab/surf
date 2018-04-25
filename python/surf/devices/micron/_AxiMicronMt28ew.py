#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite Micron MT28EW PROM
#-----------------------------------------------------------------------------
# File       : AxiMicronMt28ew.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Lite Micron MT28EW PROM
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
from surf.misc._mcsreader import *
import click
import time
import datetime

class AxiMicronMt28ew(pr.Device):
    def __init__(self,       
            name        = "AxiMicronMt28ew",
            description = "AXI-Lite Micron MT28EW PROM",
            **kwargs):
        super().__init__(
            name        = name, 
            description = description, 
            size        = (0x1 << 12), 
            **kwargs)
        
        self._mcs = McsReader()        
        self._progDone = False 
        
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
            
            click.secho(('LoadMcsFile: %s' % arg), fg='green')
            self._progDone = False 
            
            # Start time measurement for profiling
            start = time.time()
                        
            # Open the MCS file
            self._mcs.open(arg)
            
            # Erase the PROM
            self.eraseProm()
            
            # Write to the PROM
            self.writeProm()
            
            # Verify the PROM
            self.verifyProm()
            
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
                a IPROG CMD, reboot, or power cycle is be required.\n\
                ***************************************************\n\
                ***************************************************\n\n"\
                , bg='green',
            )
            
    # Reset Command
    def _resetCmd(self):
        self._writeToFlash(0x555,0xAA)
        self._writeToFlash(0x2AA,0x55)
        self._writeToFlash(0x000,0xF0)
        
    def eraseProm(self):
        # Reset the PROM
        self._resetCmd()
        # Set the starting address index
        address    = self._mcs.startAddr >> 1        
        # Uniform block size of 64-kword/block
        ERASE_SIZE = 0x10000 
        # Setup the status bar
        with click.progressbar(
            iterable = range(int((self._mcs.size)/ERASE_SIZE)),
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
        while True:
            status = self._readFromFlash(address)               
            if( (status&0x80) != 0 ):
                break
        
    def writeProm(self):
        # Reset the PROM
        self._resetCmd()    
        # Create a burst data array
        dataArray = [0] * 256
        # Set the block transfer size
        self._rawWrite(0x80,0xFF)        
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
                        self._rawWrite(offset=0x400, data=dataArray)
                        # Start a burst transfer
                        self._rawWrite(offset=0x84, data=0x7FFFFFFF&addr)                           
            # Check for leftover data
            if (cnt != 256):
                # Fill the rest of the data array with ones
                for i in range(cnt, 256):
                    dataArray[i] = 0xFFFF
                # Write burst data
                self._rawWrite(offset=0x400, data=dataArray)
                # Start a burst transfer
                self._rawWrite(offset=0x84, data=0x7FFFFFFF&addr)                  
            # Close the status bar
            bar.update(self._mcs.size)  

    def verifyProm(self):  
        # Reset the PROM
        self._resetCmd()    
        # Set the data bus 
        self._rawWrite(offset=0x0, data=0xFFFFFFFF)
        # Set the block transfer size
        self._rawWrite(offset=0x80, data=0xFF)
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
                        self._rawWrite(offset=0x84, data=0x80000000|addr)
                        # Get the data
                        dataArray = self._rawRead(offset=0x400,numWords=256)  
                else:
                    # Get the data for MCS file
                    data |= (int(self._mcs.entry[i][1])  << 8)
                    # Get the prom data from data array
                    prom = dataArray[(i&0x1FF)>>1]
                    # Compare PROM to file
                    if (data != prom):
                        click.secho(("\nAddr = 0x%x: MCS = 0x%x != PROM = 0x%x" % (addr,data,prom)), fg='red')
                        raise McsException('verifyProm() Failed\n\n')
            # Close the status bar
            bar.update(self._mcs.size)  
        
    # Generic FLASH write Command 
    def _writeToFlash(self, addr, data):
        # Set the data bus 
        self._rawWrite(offset=0x0, data=data)
        # Set the address bus and initiate the transfer
        self._rawWrite(offset=0x4,data=addr&0x7FFFFFFF)   
        
    # Generic FLASH read Command
    def _readFromFlash(self, addr):    
        # Set the address
        self._rawWrite(offset=0x4, data=addr|0x80000000)  
        # Get the read data 
        return (self._rawRead(offset=0x8)&0xFFFF) 
