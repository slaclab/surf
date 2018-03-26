#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AmcCarrier BSI Module
#-----------------------------------------------------------------------------
# File       : Ads54J60Channel.py
# Created    : 2017-04-04
#-----------------------------------------------------------------------------
# Description:
# PyRogue Ads54J60Channel Module
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

class Ads54J60Channel(pr.Device):
    def __init__( self,       
        name        = "Ads54J60Channel",
        description = "Ads54J60Channel Module",
        verify      =  False,
        **kwargs):
        super().__init__(name=name,description=description, **kwargs)         
        
        #######################
        # Paging base addresses
        #######################
        mainDigital = (0x1 << 14)
        jesdDigital = (0x2 << 14)
        jesdAnalog  = (0x3 << 14)

        ###################
        # Main Digital Page
        ###################

        # self.add(pr.RemoteVariable(   
            # name         = "PULSE_RESET",
            # description  = "",
            # offset       = (mainDigital + (4*0x000)),
            # bitSize      = 1,
            # bitOffset    = 0,
            # base         = pr.UInt,
            # mode         = "RW",
            # verify       = verify,
        # ))
        
        self.add(pr.RemoteVariable(   
            name         = "DECFIL_MODE3",
            description  = "",
            offset       = (mainDigital + (4*0x041)),
            bitSize      = 1,
            bitOffset    = 5,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))   

        self.add(pr.RemoteVariable(   
            name         = "DECFIL_EN",
            description  = "",
            offset       = (mainDigital + (4*0x041)),
            bitSize      = 1,
            bitOffset    = 4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))           

        self.add(pr.RemoteVariable(   
            name         = "DECFIL_MODE_2_0",
            description  = "",
            offset       = (mainDigital + (4*0x041)),
            bitSize      = 3,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "NYQUIST_ZONE",
            description  = "",
            offset       = (mainDigital + (4*0x042)),
            bitSize      = 3,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "FORMAT_SEL",
            description  = "",
            offset       = (mainDigital + (4*0x043)),
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "DIGITAL_GAIN",
            description  = "",
            offset       = (mainDigital + (4*0x044)),
            bitSize      = 7,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  

        self.add(pr.RemoteVariable(   
            name         = "FORMAT_EN",
            description  = "",
            offset       = (mainDigital + (4*0x04B)),
            bitSize      = 1,
            bitOffset    = 5,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "DEC_MOD_EN",
            description  = "",
            offset       = (mainDigital + (4*0x04D)),
            bitSize      = 1,
            bitOffset    = 3,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))   

        self.add(pr.RemoteVariable(   
            name         = "CTRL_NYQUIST",
            description  = "",
            offset       = (mainDigital + (4*0x04E)),
            bitSize      = 1,
            bitOffset    = 7,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "BUS_REORDER_EN1",
            description  = "",
            offset       = (mainDigital + (4*0x052)),
            bitSize      = 1,
            bitOffset    = 7,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))   

        self.add(pr.RemoteVariable(   
            name         = "DIG_GAIN_EN",
            description  = "",
            offset       = (mainDigital + (4*0x052)),
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  

        self.add(pr.RemoteVariable(   
            name         = "BUS_REORDER_EN2",
            description  = "",
            offset       = (mainDigital + (4*0x072)),
            bitSize      = 1,
            bitOffset    = 3,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  

        self.add(pr.RemoteVariable(   
            name         = "LSB_SEL_EN",
            description  = "",
            offset       = (mainDigital + (4*0x0AB)),
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  

        self.add(pr.RemoteVariable(   
            name         = "LSB_SELECT",
            description  = "",
            offset       = (mainDigital + (4*0x0AD)),
            bitSize      = 2,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        # self.add(pr.RemoteVariable(   
            # name         = "DIG_RESET",
            # description  = "",
            # offset       = (mainDigital + (4*0x0F7)),
            # bitSize      = 1,
            # bitOffset    = 0,
            # base         = pr.UInt,
            # mode         = "RW",
            # verify       = verify,
        # ))         
        
        ###################
        # JESD DIGITAL PAGE
        ###################
        
        self.add(pr.RemoteVariable(   
            name         = "CTRL_K",
            description  = "",
            offset       = (jesdDigital + (4*0x000)),
            bitSize      = 1,
            bitOffset    = 7,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 
        
        self.add(pr.RemoteVariable(   
            name         = "TESTMODE_EN",
            description  = "",
            offset       = (jesdDigital + (4*0x000)),
            bitSize      = 1,
            bitOffset    = 4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  

        self.add(pr.RemoteVariable(   
            name         = "FLIP_ADC_DATA",
            description  = "",
            offset       = (jesdDigital + (4*0x000)),
            bitSize      = 1,
            bitOffset    = 3,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  

        self.add(pr.RemoteVariable(   
            name         = "LANE_ALIGN",
            description  = "",
            offset       = (jesdDigital + (4*0x000)),
            bitSize      = 1,
            bitOffset    = 2,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "FRAME_ALIGN",
            description  = "",
            offset       = (jesdDigital + (4*0x000)),
            bitSize      = 1,
            bitOffset    = 1,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "TX_LINK_DIS",
            description  = "",
            offset       = (jesdDigital + (4*0x000)),
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  

        self.add(pr.RemoteVariable(   
            name         = "SYNC_REG",
            description  = "",
            offset       = (jesdDigital + (4*0x001)),
            bitSize      = 1,
            bitOffset    = 7,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "SYNC_REG_EN",
            description  = "",
            offset       = (jesdDigital + (4*0x001)),
            bitSize      = 1,
            bitOffset    = 6,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  

        self.add(pr.RemoteVariable(   
            name         = "JESD_FILTER",
            description  = "",
            offset       = (jesdDigital + (4*0x001)),
            bitSize      = 3,
            bitOffset    = 3,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "JESD_MODE",
            description  = "",
            offset       = (jesdDigital + (4*0x001)),
            bitSize      = 3,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  

        self.add(pr.RemoteVariable(   
            name         = "LINK_LAYER_TESTMODE",
            description  = "",
            offset       = (jesdDigital + (4*0x002)),
            bitSize      = 3,
            bitOffset    = 5,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  

        self.add(pr.RemoteVariable(   
            name         = "LINK_LAYER_RPAT",
            description  = "",
            offset       = (jesdDigital + (4*0x002)),
            bitSize      = 1,
            bitOffset    = 4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "LMFC_MASK_RESET",
            description  = "",
            offset       = (jesdDigital + (4*0x002)),
            bitSize      = 1,
            bitOffset    = 3,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "FORCE_LMFC_COUNT",
            description  = "",
            offset       = (jesdDigital + (4*0x003)),
            bitSize      = 1,
            bitOffset    = 7,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "LMFC_COUNT_INIT",
            description  = "",
            offset       = (jesdDigital + (4*0x003)),
            bitSize      = 5,
            bitOffset    = 2,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "RELEASE_ILANE_SEQ",
            description  = "",
            offset       = (jesdDigital + (4*0x003)),
            bitSize      = 2,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "SCRAMBLE_EN",
            description  = "",
            offset       = (jesdDigital + (4*0x005)),
            bitSize      = 1,
            bitOffset    = 7,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "FRAMES_PER_MULTI_FRAME",
            description  = "",
            offset       = (jesdDigital + (4*0x006)),
            bitSize      = 5,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "SUBCLASS",
            description  = "",
            offset       = (jesdDigital + (4*0x007)),
            bitSize      = 1,
            bitOffset    = 3,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))   

        self.add(pr.RemoteVariable(   
            name         = "AlwaysWrite0x1_A",
            description  = "Always set this bit to 1",
            offset       = (jesdDigital + (4*0x016)),
            bitSize      = 1,
            bitOffset    = 7,
            base         = pr.UInt,
            mode         = "WO",
            value        = 0x1,
            hidden       = True,
            verify       = False,
        ))        
        
        self.add(pr.RemoteVariable(   
            name         = "LANE_SHARE",
            description  = "",
            offset       = (jesdDigital + (4*0x016)),
            bitSize      = 1,
            bitOffset    = 4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "DA_BUS_REORDER",
            description  = "",
            offset       = (jesdDigital + (4*0x031)),
            bitSize      = 8,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))     

        self.add(pr.RemoteVariable(   
            name         = "DB_BUS_REORDER",
            description  = "",
            offset       = (jesdDigital + (4*0x032)),
            bitSize      = 8,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))             
        
        ##################
        # JESD ANALOG PAGE
        ##################
        
        self.add(pr.RemoteVariable(   
            name         = "SE_EMP_LANE_1",
            description  = "",
            offset       = (jesdAnalog + (4*0x012)),
            bitSize      = 6,
            bitOffset    = 2,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))         
        
        self.add(pr.RemoteVariable(   
            name         = "AlwaysWrite0x1_B",
            description  = "Always set this bit to 1",
            offset       = (jesdAnalog + (4*0x012)),
            bitSize      = 1,
            bitOffset    = 1,
            base         = pr.UInt,
            mode         = "WO",
            value        = 0x1,
            hidden       = True,
            verify       = False,
        ))
        
        self.add(pr.RemoteVariable(   
            name         = "SE_EMP_LANE_0",
            description  = "",
            offset       = (jesdAnalog + (4*0x013)),
            bitSize      = 6,
            bitOffset    = 2,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "SE_EMP_LANE_2",
            description  = "",
            offset       = (jesdAnalog + (4*0x014)),
            bitSize      = 6,
            bitOffset    = 2,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "SE_EMP_LANE_3",
            description  = "",
            offset       = (jesdAnalog + (4*0x015)),
            bitSize      = 6,
            bitOffset    = 2,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))   

        self.add(pr.RemoteVariable(   
            name         = "JESD_PLL_MODE",
            description  = "",
            offset       = (jesdAnalog + (4*0x016)),
            bitSize      = 2,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  

        self.add(pr.RemoteVariable(   
            name         = "PLL_RESET",
            description  = "",
            offset       = (jesdAnalog + (4*0x017)),
            bitSize      = 1,
            bitOffset    = 6,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))   

        self.add(pr.RemoteVariable(   
            name         = "FOVR_CHA",
            description  = "",
            offset       = (jesdAnalog + (4*0x01A)),
            bitSize      = 1,
            bitOffset    = 1,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "JESD_SWING",
            description  = "",
            offset       = (jesdAnalog + (4*0x01B)),
            bitSize      = 3,
            bitOffset    = 5,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "FOVR_CHA_EN",
            description  = "",
            offset       = (jesdAnalog + (4*0x01B)),
            bitSize      = 1,
            bitOffset    = 3,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))
