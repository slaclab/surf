#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AmcCarrier BSI Module
#-----------------------------------------------------------------------------
# File       : Ads54J60.py
# Created    : 2017-04-04
#-----------------------------------------------------------------------------
# Description:
# PyRogue Ads54J60 Module
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
import time
from surf.devices.ti._ads54J60Channel import *

class Ads54J60(pr.Device):
    def __init__( self,       
            name        = "Ads54J60",
            description = "Ads54J60 Module",
            verify      = False,
            **kwargs):
        super().__init__(
            name        = name, 
            description = description, 
            size        = (0x1 << 18), 
            **kwargs)     
        
        ################
        # Base addresses
        ################
        generalAddr = (0x0 << 14)
        mainDigital = (0x1 << 14) # With respect to CH  
        jesdDigital = (0x2 << 14) # With respect to CH  
        jesdAnalog  = (0x3 << 14) # With respect to CH  
        masterPage  = (0x7 << 14)
        analogPage  = (0x8 << 14)
        unusedPages = (0xE << 14)
        chA         = (0x0 << 14)
        chB         = (0x8 << 14)        
        
        #####################
        # Add Device Channels
        #####################
        self.add(Ads54J60Channel(name='CH[0]',description='Channel A',offset=chA,expand=False,verify=verify,))
        self.add(Ads54J60Channel(name='CH[1]',description='Channel B',offset=chB,expand=False,verify=verify,))      
        
        ##################
        # General Register
        ##################

        self.add(pr.RemoteCommand(  
            name         = "RESET",
            description  = "Send 0x81 value to reset the device",
            offset       = (generalAddr + (4*0x000)),
            bitSize      = 8,
            bitOffset    = 0,
            base         = pr.UInt,
            # mode         = "WO",
            hidden       = True,
            function     = pr.BaseCommand.createTouch(0x81)
        ))

        self.add(pr.RemoteVariable(   
            name         = "HW_RST",
            description  = "Hardware Reset",
            offset       = (0xF << 14),
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            hidden       = True,
        ))
                        
        #############
        # Master Page 
        #############
        
        self.add(pr.RemoteVariable(   
            name         = "PDN_ADC_CHA_0",
            description  = "",
            offset       = (masterPage + (4*0x20)),
            bitSize      = 4,
            bitOffset    = 4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "PDN_ADC_CHB",
            description  = "",
            offset       = (masterPage + (4*0x20)),
            bitSize      = 4,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "PDN_BUFFER_CHB_0",
            description  = "",
            offset       = (masterPage + (4*0x20)),
            bitSize      = 2,
            bitOffset    = 6,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "PDN_BUFFER_CHA_0",
            description  = "",
            offset       = (masterPage + (4*0x20)),
            bitSize      = 2,
            bitOffset    = 4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))         
        
        self.add(pr.RemoteVariable(   
            name         = "PDN_ADC_CHA_1",
            description  = "",
            offset       = (masterPage + (4*0x23)),
            bitSize      = 4,
            bitOffset    = 4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "PDN_ADC_CHB_1",
            description  = "",
            offset       = (masterPage + (4*0x23)),
            bitSize      = 4,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))         
        
        self.add(pr.RemoteVariable(   
            name         = "PDN_BUFFER_CHB_1",
            description  = "",
            offset       = (masterPage + (4*0x24)),
            bitSize      = 2,
            bitOffset    = 6,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "PDN_BUFFER_CHA_1",
            description  = "",
            offset       = (masterPage + (4*0x24)),
            bitSize      = 2,
            bitOffset    = 4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  

        self.add(pr.RemoteVariable(   
            name         = "GLOBAL_PDN",
            description  = "",
            offset       = (masterPage + (4*0x26)),
            bitSize      = 1,
            bitOffset    = 7,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "OVERRIDE_PDN_PIN",
            description  = "",
            offset       = (masterPage + (4*0x26)),
            bitSize      = 1,
            bitOffset    = 6,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  

        self.add(pr.RemoteVariable(   
            name         = "PDN_MASK_SEL",
            description  = "",
            offset       = (masterPage + (4*0x26)),
            bitSize      = 1,
            bitOffset    = 5,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))          

        self.add(pr.RemoteVariable(   
            name         = "EN_INPUT_DC_COUPLING",
            description  = "",
            offset       = (masterPage + (4*0x4F)),
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))
        
        self.add(pr.RemoteVariable(   
            name         = "MASK_SYSREF",
            description  = "",
            offset       = (masterPage + (4*0x53)),
            bitSize      = 1,
            bitOffset    = 6,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  

        self.add(pr.RemoteVariable(   
            name         = "EN_SYSREF_DC_COUPLING",
            description  = "",
            offset       = (masterPage + (4*0x53)),
            bitSize      = 1,
            bitOffset    = 1,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "SET_SYSREF",
            description  = "",
            offset       = (masterPage + (4*0x53)),
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "ENABLE_MANUAL_SYSREF",
            description  = "",
            offset       = (masterPage + (4*0x54)),
            bitSize      = 1,
            bitOffset    = 7,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "PDN_MASK",
            description  = "",
            offset       = (masterPage + (4*0x55)),
            bitSize      = 1,
            bitOffset    = 4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  

        self.add(pr.RemoteVariable(   
            name         = "FOVR_CHB",
            description  = "",
            offset       = (masterPage + (4*0x59)),
            bitSize      = 1,
            bitOffset    = 7,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))          
        
        self.add(pr.RemoteVariable(   
            name         = "AlwaysWrite0x1_A",
            description  = "Always set this bit to 1",
            offset       = (masterPage + (4*0x59)),
            bitSize      = 1,
            bitOffset    = 5,
            base         = pr.UInt,
            mode         = "WO",
            value        = 0x1,
            hidden       = True,
            verify       = False,
        ))


        #############
        # Analog Page 
        #############
        
        self.add(pr.RemoteVariable(   
            name         = "FOVR_THRESHOLD_PROG",
            description  = "",
            offset       = (analogPage + (4*0x5F)),
            bitSize      = 8,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        ##############################
        # Commands
        ##############################   

        @self.command(name= "DigRst", description  = "Digital Reset")        
        def DigRst():               
            self._rawWrite(mainDigital + chA + (4*0x000),0x00) # CHA: clear reset
            self._rawWrite(mainDigital + chB + (4*0x000),0x00) # CHB: clear reset
            self._rawWrite(mainDigital + chA + (4*0x000),0x01) # CHA: PULSE RESET
            self._rawWrite(mainDigital + chB + (4*0x000),0x01) # CHB: PULSE RESET 
            self._rawWrite(mainDigital + chA + (4*0x000),0x00) # CHA: clear reset
            self._rawWrite(mainDigital + chB + (4*0x000),0x00) # CHB: clear reset 

        @self.command(name= "PllRst", description  = "PLL Reset")        
        def PllRst():               
            self._rawWrite(mainDigital + chA + (4*0x017),0x00) # CHA: PLL clear
            self._rawWrite(mainDigital + chB + (4*0x017),0x00) # CHB: PLL clear
            self._rawWrite(mainDigital + chA + (4*0x017),0x40) # CHA: PLL reset
            self._rawWrite(mainDigital + chB + (4*0x017),0x40) # CHB: PLL reset
            self._rawWrite(mainDigital + chA + (4*0x017),0x00) # CHA: PLL clear
            self._rawWrite(mainDigital + chB + (4*0x017),0x00) # CHB: PLL clear                 
        
        @self.command(name= "Init", description  = "Device Initiation")        
        def Init():        
            self.HW_RST.set(0x1)
            self.HW_RST.set(0x0)
            time.sleep(0.001)
            self.RESET()
            self._rawWrite(unusedPages, 0x00) # Clear any unwanted content from the unused pages of the JESD bank.
            
            self._rawWrite(mainDigital + chA + (4*0x0F7),0x01); # Use the DIG RESET register bit to reset all pages in the JESD bank (self-clearing bit)
            self._rawWrite(mainDigital + chB + (4*0x0F7),0x01); # Use the DIG RESET register bit to reset all pages in the JESD bank (self-clearing bit)     

            self._rawWrite(mainDigital + chA + (4*0x000),0x01) # CHA: PULSE RESET
            self._rawWrite(mainDigital + chB + (4*0x000),0x01) # CHB: PULSE RESET 
            self._rawWrite(mainDigital + chA + (4*0x000),0x00) # CHA: clear reset
            self._rawWrite(mainDigital + chB + (4*0x000),0x00) # CHB: clear reset 

            self._rawWrite(masterPage        + (4*0x059),0x20); # Set the ALWAYS WRITE 1 bit
            
            self.PllRst()
            