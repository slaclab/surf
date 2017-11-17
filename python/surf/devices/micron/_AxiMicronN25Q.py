#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite Micron N25Q and Micron MT25Q PROM
#-----------------------------------------------------------------------------
# File       : AxiMicronN25Q.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Lite Micron N25Q and Micron MT25Q PROM
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

class AxiMicronN25Q(pr.Device):
    def __init__(self,       
            name        = "AxiMicronN25Q",
            description = "AXI-Lite Micron N25Q and Micron MT25Q PROM",
            addrMode    = False, # False = 24-bit Address mode, True = 32-bit Address Mode
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)
        
        self._mcs      = McsReader()        
        self._addrMode = addrMode     
        
        ##############################
        # Variables
        ##############################        
        self.add(pr.RemoteVariable(
            name         = "Test",
            description  = "Scratch Pad tester register",
            offset       =  0x00,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))              
        
        ##############################
        # Constants
        ##############################                
        
        self.WRITE_3BYTE_CMD = (0x02 << 16)
        self.WRITE_4BYTE_CMD = (0x12 << 16)

        self.READ_3BYTE_CMD  = (0x03 << 16)
        self.READ_4BYTE_CMD  = (0x13 << 16)
           
        self.FLAG_STATUS_REG = (0x70 << 16)
        self.FLAG_STATUS_RDY = (0x80)
           
        self.WRITE_ENABLE_CMD  = (0x06 << 16)
        self.WRITE_DISABLE_CMD = (0x04 << 16)

        self.ADDR_ENTER_CMD = (0xB7 << 16)
        self.ADDR_EXIT_CMD  = (0xE9 << 16)
           
        self.ERASE_CMD  = (0xD8 << 16)

        self.STATUS_REG_WR_CMD = (0x01 << 16)
        self.STATUS_REG_RD_CMD = (0x05 << 16)

        self.DEV_ID_RD_CMD = (0x9F << 16)

        self.WRITE_NONVOLATILE_CONFIG = (0xB1 << 16)
        self.WRITE_VOLATILE_CONFIG    = (0x81 << 16)
        self.READ_NONVOLATILE_CONFIG  = (0xB5 << 16)
        self.READ_VOLATILE_CONFIG     = (0x85 << 16)

        ## Default Configuration:
        ## Number of dummy clock cycles = 0xF
        ## XIP mode at power-on reset = 0x7
        ## Output driver strength = x7
        ## Double transfer rate protocol = 0x1 ( = Disabled and only used in MT25Q only)
        ## Reset/hold = 0x0 (disabled to be MT25Q pin compatible with N25Q)
        ## Quad I/O protocol = 0x1
        ## Dual I/O protocol = 0x1
        ## 128Mb segment select = 0x1
        self.DEFAULT_3BYTE_CONFIG = 0xFFEF
        self.DEFAULT_4BYTE_CONFIG = 0xFFEE

        self.READ_MASK   = 0x00000000 
        self.WRITE_MASK  = 0x80000000 
        self.VERIFY_MASK = 0x40000000         

        @self.command(value='',description="Load the .MCS into PROM",)
        def LoadMcsFile(arg):
            
            click.secho(('LoadMcsFile: %s' % arg), fg='green')
            
            # Start time measurement for profiling
            start = time.time()
            
            # Reset the SPI interface
            self.resetFlash()            
            
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
            click.secho(('LoadMcsFile() took %d seconds' % int(elapsed)), fg='green')
            
            # Add a power cycle reminder
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
                    
    def eraseProm(self): 
        # Set the starting address index
        address    = self._mcs.startAddr        
        # 64kB per sector
        ERASE_SIZE = 0x10000 
        # Setup the status bar
        with click.progressbar(
            iterable = range(int((self._mcs.size)/ERASE_SIZE)),
            label    = click.style('Erasing PROM:  ', fg='green'),
        ) as bar:
            for i in bar:
                # Execute the erase command
                self.eraseCmd(address)
                # Increment by one block
                address += ERASE_SIZE        
        # Check the corner case
        if ( address<self._mcs.endAddr ): 
            self.eraseCmd(address)

    def writeProm(self):        
        # Initialize the variables
        wordCnt = 0
        byteCnt = 0
        # Create a burst data array
        dataArray = [0] * 64  
        # Setup the status bar
        with click.progressbar(
            length   = self._mcs.size,
            label    = click.style('Writing PROM:  ', fg='green'),
        ) as bar:        
            for i in range(self._mcs.size): 
                # Check for first byte of burst transfer
                if ( (i&0xFFF) == 0):
                    # Throttle down printf rate
                    bar.update(0xFFF)               
                # Get the start bursting address
                if ( (byteCnt==0) and (wordCnt==0) ):
                    addr = int(self._mcs.entry[i][0])
                # Pack the bytes into a 32-bit word
                if ( byteCnt==0 ):
                    wrd = (int(self._mcs.entry[i][1]) & 0xFF) << (8*(3-byteCnt))
                else:
                    wrd |= (int(self._mcs.entry[i][1]) & 0xFF) << (8*(3-byteCnt))
                # Increment the counter
                byteCnt += 1    
                # Check the byte counter
                if ( byteCnt==4 ):
                    byteCnt = 0
                    dataArray[wordCnt] = wrd
                    wordCnt += 1
                    if ( wordCnt==64 ):
                        wordCnt = 0
                        self.setDataReg(dataArray)
                        self.writeCmd(addr)                      
            # Check for leftover data
            if (wordCnt != 0):
                while(wordCnt != 0):
                    # Pack the bytes into a 32-bit word
                    if ( byteCnt==0 ):
                        wrd = (0xFF) << (8*(3-byteCnt))
                    else:
                        wrd |= (0xFF) << (8*(3-byteCnt))            
                    # Increment the counter
                    byteCnt += 1    
                    # Check the byte counter
                    if ( byteCnt==4 ):
                        byteCnt = 0
                        dataArray[wordCnt] = wrd
                        wordCnt += 1
                        if ( wordCnt==64 ):
                            wordCnt = 0
                            self.setDataReg(dataArray)
                            self.writeCmd(addr)
                            break
            # Close the status bar
            bar.update(self._mcs.size)         

    def verifyProm(self): 
        # Initialize the variables
        wordCnt = 0
        byteCnt = 0    
        # Setup the status bar
        with click.progressbar(
            length  = self._mcs.size,
            label   = click.style('Verifying PROM:', fg='green'),           
        ) as bar:
            for i in range(self._mcs.size):
                # Check for first byte of burst transfer
                if ( (i&0xFFF) == 0):
                    # Throttle down printf rate
                    bar.update(0xFFF)      
                # Get the start bursting address
                if ( (byteCnt==0) and (wordCnt==0) ):
                    # Start address of a burst transfer
                    self.readCmd(int(self._mcs.entry[i][0])) 
                    # Get the data
                    dataArray = self.getDataReg()
                # Get the data/addr for MCS file
                data = int(self._mcs.entry[i][1])
                addr = int(self._mcs.entry[i][0])
                # Get the prom data from data array                    
                prom = ((dataArray[wordCnt] >> 8*(3-byteCnt)) & 0xFF)
                # Compare PROM to file
                if (data != prom):
                    click.secho(("\nAddr = 0x%x: MCS = 0x%x != PROM = 0x%x" % (addr,data,prom)), fg='red')
                    raise McsException('verifyProm() Failed\n\n')                    
                # Increment the counter
                byteCnt += 1    
                # Check the byte counter
                if ( byteCnt==4 ):
                    byteCnt = 0
                    wordCnt += 1
                    if ( wordCnt==64 ):
                        wordCnt = 0
            # Close the status bar
            bar.update(self._mcs.size)  
  
    def eraseCmd(self, address): 
        self.setAddrReg(address) 
        if (self._addrMode):  
            self.setCmd(self.WRITE_MASK|self.ERASE_CMD|0x4)    
        else:
            self.setCmd(self.WRITE_MASK|self.ERASE_CMD|0x3) 
 
    def writeCmd(self, address): 
        self.setAddrReg(address) 
        if (self._addrMode):  
            self.setCmd(self.WRITE_MASK|self.WRITE_4BYTE_CMD|0x104)     
        else:
            self.setCmd(self.WRITE_MASK|self.WRITE_3BYTE_CMD|0x103)   
 
    def readCmd(self, address):
        self.waitForFlashReady()   
        self.setAddrReg(address) 
        if (self._addrMode):  
            self.setCmd(self.READ_MASK|self.READ_4BYTE_CMD|0x104)     
        else:
            self.setCmd(self.READ_MASK|self.READ_3BYTE_CMD|0x103)

    def setAddr32BitMode(self, addrMode):
        # Update local value
        self._addrMode = addrMode 
        # Set the addressing mode
        self.setModeReg()        
        if (self._addrMode):
            self.enter32BitMode()
        else:
            self.exit32BitMode()
            
    def enter32BitMode(self):
        self.setCmd(self.WRITE_MASK|self.ADDR_ENTER_CMD)    
        
    def exit32BitMode(self): 
        self.setCmd(self.WRITE_MASK|self.ADDR_EXIT_CMD)     
        
    def setPromStatusReg(self, value):
        self.waitForFlashReady()   
        if(self._addrMode):
            self.setAddrReg((value&0xFF)<<24)
            self.setCmd(self.WRITE_MASK|self.STATUS_REG_WR_CMD|0x1)    
        else:
            self.setAddrReg((value&0xFF)<<16)
            self.setCmd(self.WRITE_MASK|self.STATUS_REG_WR_CMD|0x1)         

    def getPromStatusReg(self):
        self.waitForFlashReady()
        self.setCmd(self.READ_MASK|self.STATUS_REG_RD_CMD|0x1)
        return (self.getCmdReg()&0xFF)  
        
    def getManufacturerId(self):
        self.waitForFlashReady()
        self.setCmd(self.READ_MASK|self.DEV_ID_RD_CMD|0x1)
        return (self.getCmdReg()&0xFF)      
        
    def getManufacturerType(self):
        self.waitForFlashReady()
        self.setCmd(self.READ_MASK|self.DEV_ID_RD_CMD|0x2)
        return (self.getCmdReg()&0xFF)     
        
    def getManufacturerCapacity(self):  
        self.waitForFlashReady()
        self.setCmd(self.READ_MASK|self.DEV_ID_RD_CMD|0x3)
        return (self.getCmdReg()&0xFF)              
            
    def resetFlash(self):
        # Send the enable reset command
        self.setCmdReg(self.WRITE_MASK|(0x66 << 16))
        # Send the reset command
        self.setCmdReg(self.WRITE_MASK|(0x99 << 16))
        # Set the addressing mode
        self.setModeReg()
        # Check the address mode
        if (self._addrMode):
            self.enter32BitMode()
            self.setAddrReg(self.DEFAULT_4BYTE_CONFIG<<16)
            self.setCmd(self.WRITE_MASK|self.WRITE_NONVOLATILE_CONFIG|0x2)
            self.waitForFlashReady()     
            self.setCmd(self.WRITE_MASK|self.WRITE_VOLATILE_CONFIG|0x2)        
        else:
            self.exit32BitMode()
            self.setAddrReg(self.DEFAULT_3BYTE_CONFIG<<8)
            self.setCmd(self.WRITE_MASK|self.WRITE_NONVOLATILE_CONFIG|0x2)        
            self.waitForFlashReady()
            self.setCmd(self.WRITE_MASK|self.WRITE_VOLATILE_CONFIG|0x2)    
            
    def writeEnable(self):
        self.waitForFlashReady()   
        self.setCmdReg(self.WRITE_MASK|self.WRITE_ENABLE_CMD)
        
    def writeDisable(self):
        self.waitForFlashReady()   
        self.setCmdReg(self.WRITE_MASK|self.WRITE_DISABLE_CMD) 
        
    def waitForFlashReady(self):  
        while True:
            # Get the status register
            self.setCmd(self.READ_MASK|self.FLAG_STATUS_REG|0x1)
            status = (self.getCmdReg()&0xFF) 
            # Check if not busy
            if ( (status & self.FLAG_STATUS_RDY) != 0 ):
                break
                
    def setCmd(self,value):     
        if ( value&self.WRITE_MASK ):
            self.writeEnable()
        self.setCmdReg(value) 
                
    def setModeReg(self):
        if (self._addrMode):
            self._rawWrite(0x04,0x1)
        else:
            self._rawWrite(0x04,0x0)
            
    def setAddrReg(self,value):            
        self._rawWrite(0x08,value)            
        
    def setCmdReg(self,value):            
        self._rawWrite(0x0C,value)         
        
    def getCmdReg(self):            
        return (self._rawRead(offset=0x0C))
        
    def setDataReg(self,values):            
        self._rawWrite(0x200,values)     
        
    def getDataReg(self):            
        return (self._rawRead(offset=0x200,numWords=64))
