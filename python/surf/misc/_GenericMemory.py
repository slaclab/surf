#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Generic Memory Module
#-----------------------------------------------------------------------------
# File       : GenericMemory.py
# Created    : 2017-04-04
#-----------------------------------------------------------------------------
# Description:
# PyRogue Generic Memory Module
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
import rogue.interfaces.memory as rim

class GenericMemory(pr.Device):
    def __init__(   self, 
        name        = "GenericMemory", 
        description = "Generic Memory Module", 
        memBase     =  None, 
        offset      =  0x0, 
        hidden      =  True, 
        nelms       =  1, 
        bitSize     =  32, 
        bitOffset   =  0, 
        stride      =  4,
        base        = "hex", 
        mode        = "RW", 
        instantiate =  True,
        expand      =  False,
    ):
        super().__init__(
            name        = name,
            description = description,
            memBase     = memBase,
            offset      = offset,
            hidden      = hidden,
            expand      = expand,
        )           

        ##############################
        # Variables
        ##############################
        
        if (instantiate):
            self.addRemoteVariables(  
                name         = "Mem",
                description  = "Memory Array",
                offset       =  0x00,
                bitSize      =  bitSize,
                bitOffset    =  bitOffset,
                base         =  base,
                mode         =  mode,
                number       =  nelms,
                stride       =  stride,
                hidden = hidden,
            )

        @self.command()
        def fill():
            for i,v in self.Mem.items():
                v.set(i, write=False)
            self.writeBlocks(force=True)
            self.checkBlocks()
        

    def writeBlocks(self, force=False, recurse=True, variable=None, checkEach=False):
        
        if not self.enable.get(): return

        """
        Write all of the blocks held by this Device to memory
        """
        self._log.debug(f'Calling {self.path}._writeBlocks')
        #print(f'Calling {self.path}.writeBlocks(recurse={recurse}, variable={variable}, checkEach={checkEach}')                

        # Process local blocks.
        if variable is not None:
            for b in self._getBlocks(variable):
                if (force or block.stale):                
                    b.startTransaction(rim.Write, check=checkEach)

        else:
            for block in self._blocks:
                if (force or block.stale) and block.bulkEn:
                    block.startTransaction(rim.Write, check=checkEach)

            if recurse:
                for key,value in self.devices.items():
                    value.writeBlocks(force=force, recurse=True, checkEach=checkEach)
                

    def readBlocks(self, recurse=True, variable=None, checkEach=False):

        if not self.enable.get(): return

        """
        Perform background reads
        """
        self._log.debug(f'Calling {self.path}._readBlocks(recurse={recurse}, variable={variable}, checkEach={checkEach}')
        #print(f'Calling {self.path}.readBlocks(recurse={recurse}, variable={variable}, checkEach={checkEach})')        

        # Process local blocks. 
        if variable is not None:
            for b in self._getBlocks(variable):
                b.startTransaction(rim.Read, checkEach)

        else:
            for block in self._blocks:
                if block.bulkEn:
                    block.startTransaction(rim.Read, checkEach)

            if recurse:
                for key,value in self.devices.items():
                    value.readBlocks(recurse=True, checkEach=checkEach)


    def verifyBlocks(self, recurse=True, variable=None, checkEach=False):

        if not self.enable.get(): return
        
        """
        Perform background verify
        """
        #print(f'Calling {self.path}.verifyBlocks(recurse={recurse}, variable={variable}, checkEach={checkEach}')                

        # Process local blocks.
        if variable is not None:
            for b in self._getBlocks(variable):
                b.startTransaction(rim.Verify, checkEach)

        else:
            for block in self._blocks:
                if block.bulkEn:
                    block.startTransaction(rim.Verify, checkEach)

            if recurse:
                for key,value in self.devices.items():
                    value.verifyBlocks(recurse=True, checkEach=checkEach)
