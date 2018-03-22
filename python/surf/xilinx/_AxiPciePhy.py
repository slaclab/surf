#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite monitoring for AXI Bridge for PCI Express
#-----------------------------------------------------------------------------
# File       : _AxiPciePhy.py
# Created    : 2017-06-24
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Lite monitoring for AXI Bridge for PCI Express (Refer to PG055 and PG194)
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

class AxiPciePhy(pr.Device):
    def __init__(   self,       
            name        = "AxiPciePhy",
            description = "AXI-Lite monitoring for AXI Bridge for PCI Express (Refer to PG055 and PG194)",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        ##############################
        # Variables
        ##############################        
        self.addRemoteVariables( 
            name         = "PcieConfigHdr",
            description  = "PCIe Configuration Space Header",
            offset       =  0x000,
            bitSize      =  32,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RO",
            number       =  76,
            stride       =  4,
            hidden       =  True,
        )        
        
        self.add(pr.LinkVariable(
            name         = 'VendorId',
            description  = 'Vendor ID',
            mode         = 'RO',
            dependencies = [self.PcieConfigHdr[0x000>>2]],
            disp         = '{:04X}',
            linkedGet    = lambda: (self.PcieConfigHdr[0x000>>2].value() >> 0) & 0xFFFF
        ))  

        self.add(pr.LinkVariable(
            name         = 'DeviceId',
            description  = 'Device ID',
            mode         = 'RO',
            dependencies = [self.PcieConfigHdr[0x000>>2]],
            disp         = '{:04X}',
            linkedGet    = lambda: (self.PcieConfigHdr[0x000>>2].value() >> 16) & 0xFFFF
        )) 

        self.add(pr.LinkVariable(
            name         = 'SubVendorId',
            description  = 'SubVendor ID',
            mode         = 'RO',
            dependencies = [self.PcieConfigHdr[0x02C>>2]],
            disp         = '{:04X}',
            linkedGet    = lambda: (self.PcieConfigHdr[0x02C>>2].value() >> 0) & 0xFFFF
        ))  

        self.add(pr.LinkVariable(
            name         = 'SubDeviceId',
            description  = 'SubDevice ID',
            mode         = 'RO',
            dependencies = [self.PcieConfigHdr[0x02C>>2]],
            disp         = '{:04X}',
            linkedGet    = lambda: (self.PcieConfigHdr[0x02C>>2].value() >> 16) & 0xFFFF
        )) 
        
        self.add(pr.LinkVariable(
            name         = 'Command',
            description  = '',
            mode         = 'RO',
            dependencies = [self.PcieConfigHdr[0x004>>2]],
            disp         = '{:04X}',
            linkedGet    = lambda: (self.PcieConfigHdr[0x004>>2].value() >> 0) & 0xFFFF
        ))  

        self.add(pr.LinkVariable(
            name         = 'Status',
            description  = '',
            mode         = 'RO',
            dependencies = [self.PcieConfigHdr[0x004>>2]],
            disp         = '{:04X}',
            linkedGet    = lambda: (self.PcieConfigHdr[0x004>>2].value() >> 16) & 0xFFFF
        ))    

        self.add(pr.LinkVariable(
            name         = 'BusNumber',
            description  = 'Bus Number of port for PCIe',
            mode         = 'RO',
            dependencies = [self.PcieConfigHdr[0x010>>2]],
            disp         = '{:01X}',
            linkedGet    = lambda: (self.PcieConfigHdr[0x010>>2].value() >> 20) & 0xF
        ))   

        self.add(pr.LinkVariable(
            name         = 'DeviceNumber',
            description  = 'Device Number of port for PCIe',
            mode         = 'RO',
            dependencies = [self.PcieConfigHdr[0x010>>2]],
            disp         = '{:02X}',
            linkedGet    = lambda: (self.PcieConfigHdr[0x010>>2].value() >> 11) & 0x1F
        )) 

        self.add(pr.LinkVariable(
            name         = 'FunctionNumber',
            description  = 'Function Number of port for PCIe',
            mode         = 'RO',
            dependencies = [self.PcieConfigHdr[0x010>>2]],
            disp         = '{:01X}',
            linkedGet    = lambda: (self.PcieConfigHdr[0x010>>2].value() >> 3) & 0x7
        )) 
        
        self.add(pr.RemoteVariable(    
            name         = "Gen2Capable",
            description  = "If set, underlying integrated block supports PCIe Gen2 speed.",
            offset       =  0x130,
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RO",
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "Gen3Capable",
            description  = "If set, underlying integrated block supports PCIe Gen3 speed.",
            offset       =  0x130,
            bitSize      =  1,
            bitOffset    =  3,
            base         = pr.UInt,
            mode         = "RO",
        ))  
        
        self.add(pr.RemoteVariable(    
            name         = "RootPortPresent",
            description  = "Indicates the underlying integrated block is a Root Port when this bit is set. If set, Root Port registers are present in this interface.",
            offset       =  0x130,
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.UInt,
            mode         = "RO",
        ))  

        self.add(pr.RemoteVariable(    
            name         = "UpConfigCapable",
            description  = "Indicates the underlying integrated block is upconfig capable when this bit is set.",
            offset       =  0x130,
            bitSize      =  1,
            bitOffset    =  2,
            base         = pr.UInt,
            mode         = "RO",
        )) 

        ##################################################
        # address 0x140 is not working for all 
        # Getting it from the configuration header instead
        ##################################################
        # self.add(pr.RemoteVariable(    
            # name         = "FunctionNumber",
            # description  = "Function number of the port for PCIe. Hard-wired to 0.",
            # offset       =  0x140,
            # bitSize      =  3,
            # bitOffset    =  0,
            # base         = pr.UInt,
            # mode         = "RO",
        # )) 
        
        # self.add(pr.RemoteVariable(    
            # name         = "DeviceNumber",
            # description  = "Device number of port for PCIe.",
            # offset       =  0x140,
            # bitSize      =  5,
            # bitOffset    =  3,
            # base         = pr.UInt,
            # mode         = "RO",
        # ))  
        
        # self.add(pr.RemoteVariable(    
            # name         = "BusNumber",
            # description  = "Bus Number of port for PCIe.",
            # offset       =  0x140,
            # bitSize      =  8,
            # bitOffset    =  8,
            # base         = pr.UInt,
            # mode         = "RO",
        # ))    

        self.add(pr.RemoteVariable(    
            name         = "LinkRateGen2",
            description  = "0b = 2.5 GT/s (if bit[12] = 0), or 8.0GT/s (if bit[12] = 1), 1b = 5.0 GT/s",
            offset       =  0x144,
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RO",
        ))  

        self.add(pr.RemoteVariable(    
            name         = "LinkRateGen3",
            description  = "Reports the current link rate. 0b = see bit[0]. 1b = 8.0 GT/s",
            offset       =  0x144,
            bitSize      =  1,
            bitOffset    =  12,
            base         = pr.UInt,
            mode         = "RO",
        ))          
        
        self.add(pr.RemoteVariable(    
            name         = "LinkWidth",
            description  = "Reports the current link width. 00b = x1, 01b = x2, 10b = x4, 11b = x8.",
            offset       =  0x144,
            bitSize      =  2,
            bitOffset    =  1,
            enum        = {
                0: "1", 
                1: "2", 
                2: "4", 
                3: "8",
            },
            mode         = "RO",
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "LinkWidth16",
            description  = "Reports the current link width. 0b = See bit[2:1]. 1b = x16.",
            offset       =  0x144,
            bitSize      =  1,
            bitOffset    =  13,
            base         = pr.UInt,
            mode         = "RO",
        ))      
        