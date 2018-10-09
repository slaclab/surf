#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Description: PyRogue Cypress S25FL PROM Series
# 
# Note: Used with surf/devices/Micron/n25q firmware
#
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the rogue software platform, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue             as pr
import surf.devices.micron as micron
import surf.misc           as misc
import click
import time
import datetime

class CypressS25Fl(micron.AxiMicronN25Q):
    def __init__(self,
            name        = "CypressS25Fl",
            description = "Container for Cypress S25FL PROM device",
            addrMode    = False, # False = 24-bit Address mode, True = 32-bit Address Mode
            **kwargs
        ):
        super().__init__(
            name        = name, 
            description = description, 
            **kwargs
        )

        ########################################
        # Overwrite with Cypress S25FL Constants
        ########################################
        self.FLAG_STATUS_REG = (0x05 << 16)
        self.FLAG_STATUS_RDY = (0x01)
        self.BRAC_CMD        = (0xB9 << 16)
        
    def _LoadMcsFile(self,arg):
        
        click.secho(('LoadMcsFile: %s' % arg), fg='green')
        self._progDone = False 
        
        # Start time measurement for profiling
        start = time.time()
        
        # Reset the SPI interface
        self.resetFlash()
        
        # Print the status registers
        print("CypressS25Fl Manufacturer ID Code  = {}".format(hex(self.getManufacturerId())))
        print("CypressS25Fl Manufacturer Type     = {}".format(hex(self.getManufacturerType())))
        print("CypressS25Fl Manufacturer Capacity = {}".format(hex(self.getManufacturerCapacity())))
        print("CypressS25Fl Status Register       = {}".format(hex(self.getPromStatusReg())))
        
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
            a IPROG CMD or power cycle is be required.\n\
            ***************************************************\n\
            ***************************************************\n\n"\
            , bg='green',
        )        

    def resetFlash(self):
        # Send the "Mode Bit Reset" command
        self.setCmdReg(self.WRITE_MASK|(0xFF << 16))
        time.sleep(0.001)
        # Send the "Software Reset" Command
        self.setCmdReg(self.WRITE_MASK|(0xF0 << 16))
        time.sleep(0.001)
        # Set the addressing mode
        self.setModeReg()
        # Check the address mode
        if (self._addrMode):
            self.setCmd(self.WRITE_MASK|self.BRAC_CMD|0x80)
        else:
            self.setCmd(self.WRITE_MASK|self.BRAC_CMD)            

    def waitForFlashReady(self):
        while True:
            # Get the status register
            self.setCmdReg(self.READ_MASK|self.FLAG_STATUS_REG|0x1)
            status = (self.getCmdReg()&0xFF) 
            # Check if not busy
            if ( (status & self.FLAG_STATUS_RDY) == 0 ): # active Low READY
                break            
