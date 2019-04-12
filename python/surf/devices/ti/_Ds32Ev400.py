#!/usr/bin/env python
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

class Ds32Ev400(pr.Device):
    def __init__(   self,       
        name        = 'Ds32Ev400',
        description = 'Ds32Ev400 Module',
        **kwargs):
        
        super().__init__(name=name,description=description,**kwargs)

        self.add(pr.RemoteVariable(    
            name         = 'SmBusEnable',
            description  = '0: Disabled, 1: Enabled',
            offset       = (0x07 << 2),
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'RW', 
        ))          
        
        self.add(pr.RemoteVariable(    
            name         = 'SD',
            description  = 'Signal Detect',
            offset       = (0x00 << 2),
            bitSize      = 4,
            bitOffset    = 0,
            mode         = 'RO', 
            pollInterval = 1,
        ))    

        self.add(pr.RemoteVariable(    
            name         = 'ID',
            description  = 'ID Revision',
            offset       = (0x00 << 2),
            bitSize      = 4,
            bitOffset    = 4,
            mode         = 'RO', 
        ))        
        
        self.add(pr.RemoteVariable(    
            name         = 'En[0]',
            description  = 'enable controlled by SMBus',
            offset       = (0x01 << 2),
            bitSize      = 1,
            bitOffset    = 3,
            mode         = 'RW', 
        ))    

        self.add(pr.RemoteVariable(    
            name         = 'En[1]',
            description  = 'enable controlled by SMBus',
            offset       = (0x01 << 2),
            bitSize      = 1,
            bitOffset    = 7,
            mode         = 'RW', 
        ))  

        self.add(pr.RemoteVariable(    
            name         = 'En[2]',
            description  = 'enable controlled by SMBus',
            offset       = (0x02 << 2),
            bitSize      = 1,
            bitOffset    = 3,
            mode         = 'RW', 
        ))    

        self.add(pr.RemoteVariable(    
            name         = 'En[3]',
            description  = 'enable controlled by SMBus',
            offset       = (0x02 << 2),
            bitSize      = 1,
            bitOffset    = 7,
            mode         = 'RW', 
        ))          
        
        self.add(pr.RemoteVariable(    
            name         = 'Boost[0]',
            description  = 'equalizer boost setting controlled by SMBus',
            offset       = (0x01 << 2),
            bitSize      = 3,
            bitOffset    = 0,
            mode         = 'RW', 
        ))    

        self.add(pr.RemoteVariable(    
            name         = 'Boost[1]',
            description  = 'equalizer boost setting controlled by SMBus',
            offset       = (0x01 << 2),
            bitSize      = 3,
            bitOffset    = 4,
            mode         = 'RW', 
        ))  

        self.add(pr.RemoteVariable(    
            name         = 'Boost[2]',
            description  = 'equalizer boost setting controlled by SMBus',
            offset       = (0x02 << 2),
            bitSize      = 3,
            bitOffset    = 0,
            mode         = 'RW', 
        ))    

        self.add(pr.RemoteVariable(    
            name         = 'Boost[3]',
            description  = 'equalizer boost setting controlled by SMBus',
            offset       = (0x02 << 2),
            bitSize      = 3,
            bitOffset    = 4,
            mode         = 'RW', 
        ))          
        
        self.add(pr.RemoteVariable(    
            name         = 'OeL[0]',
            description  = '0: enabled, 1: disabled',
            offset       = (0x03 << 2),
            bitSize      = 1,
            bitOffset    = 3,
            mode         = 'RW', 
        ))    

        self.add(pr.RemoteVariable(    
            name         = 'OeL[1]',
            description  = '0: enabled, 1: disabled',
            offset       = (0x03 << 2),
            bitSize      = 1,
            bitOffset    = 7,
            mode         = 'RW', 
        ))  

        self.add(pr.RemoteVariable(    
            name         = 'OeL[2]',
            description  = '0: enabled, 1: disabled',
            offset       = (0x04 << 2),
            bitSize      = 1,
            bitOffset    = 3,
            mode         = 'RW', 
        ))    

        self.add(pr.RemoteVariable(    
            name         = 'OeL[3]',
            description  = '0: enabled, 1: disabled',
            offset       = (0x04 << 2),
            bitSize      = 1,
            bitOffset    = 7,
            mode         = 'RW', 
        ))             
        
        self.add(pr.RemoteVariable(    
            name         = 'BoostControl[0]',
            description  = 'BST_N setting controlled by SMBus',
            offset       = (0x03 << 2),
            bitSize      = 3,
            bitOffset    = 0,
            mode         = 'RW', 
        ))    

        self.add(pr.RemoteVariable(    
            name         = 'BoostControl[1]',
            description  = 'BST_N setting controlled by SMBus',
            offset       = (0x03 << 2),
            bitSize      = 3,
            bitOffset    = 4,
            mode         = 'RW', 
        ))  

        self.add(pr.RemoteVariable(    
            name         = 'BoostControl[2]',
            description  = 'BST_N setting controlled by SMBus',
            offset       = (0x04 << 2),
            bitSize      = 3,
            bitOffset    = 0,
            mode         = 'RW', 
        ))    

        self.add(pr.RemoteVariable(    
            name         = 'BoostControl[3]',
            description  = 'BST_N setting controlled by SMBus',
            offset       = (0x04 << 2),
            bitSize      = 3,
            bitOffset    = 4,
            mode         = 'RW', 
        ))               
        
        for i in range(4):
        
            self.add(pr.RemoteVariable(    
                name         = f'SdOnThreshold[{i}]',
                description  = 'Signal Detect ON threshold',
                offset       = (0x05 << 2),
                bitSize      = 2,
                bitOffset    = 2*i,
                mode         = 'RW', 
            )) 

            self.add(pr.RemoteVariable(    
                name         = f'SdOffThreshold[{i}]',
                description  = 'Signal Detect OFF threshold',
                offset       = (0x06 << 2),
                bitSize      = 2,
                bitOffset    = 2*i,
                mode         = 'RW', 
            ))             
            
        self.add(pr.RemoteVariable(    
            name         = 'OutputLevel',
            description  = 'Sets the output diff. swing',
            offset       = (0x08 << 2),
            bitSize      = 2,
            bitOffset    = 2,
            mode         = 'RW', 
        ))          
        