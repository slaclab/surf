#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Sff8472 Module
#-----------------------------------------------------------------------------
# File       : Sff8472.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description: PyRogue Sff8472 Module
#
# Refer to AN-2030: Digital Diagnostic Monitoring Interface for Optical Transceivers
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

import pyrogue as pr

class Sff8472(pr.Device):
    def __init__(   
        self,       
        name        = "Sff8472",
        description = "SFF-8472 Module",
            **kwargs):
        
        super().__init__(
            name        = name,
            description = description,
            **kwargs)
               
        #####################################################
        #       Serial ID: Data Fields – Address A0h        #
        #####################################################
        
        ################
        # BASE ID FIELDS
        ################
        
        self.add(pr.RemoteVariable(
            name         = 'Identifier', 
            description  = 'Type of serial transceiver',
            offset       = (0 << 2),
            bitSize      = 8, 
            mode         = 'RO',
            enum        = {
                0x0: 'Unspecified', 
                0x1: 'GBIC', 
                0x2: 'Module/connector soldered to motherboard', 
                0x3: 'SFP or SFP+',
                0x4: '300 pin XBI', 
                0x5: 'XENPAK', 
                0x6: 'XFP', 
                0x7: 'XFF',
                0x8: 'XFP-E', 
                0x9: 'XPAK', 
                0xA: 'X2', 
                0xB: 'DWDM-SFP',
                0xC: 'QSFP',
                0xD: 'QSFP+',
                0xE: 'CXP',
            },
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'ExtIdentifier', 
            description = 'Extended identifier of type of serial transceiver',
            offset      = (1 << 2),
            bitSize     = 8, 
            mode        = 'RO',
            base        = pr.UInt,
        ))    

        self.add(pr.RemoteVariable(
            name        = 'Connector', 
            description = 'Code for connector type',
            offset      = (2 << 2),
            bitSize     = 8, 
            mode        = 'RO',
            enum        = {
                0x00: 'Unspecified', 
                0x01: 'SC', 
                0x02: 'Fibre Channel Style 1 copper connector', 
                0x03: 'Fibre Channel Style 2 copper connector',
                0x04: 'BNC/TNC', 
                0x05: 'Fibre Channel coaxial headers', 
                0x06: 'FiberJack', 
                0x07: 'LC',
                0x08: 'MT-RJ', 
                0x09: 'MU', 
                0x0A: 'SG', 
                0x0B: 'Optical pigtail',
                0x0C: 'MPO Parallel Optic',
                0x20: 'HSSDC II',
                0x21: 'Copper Pigtail',
                0x22: 'RJ45',
            },
        ))       
        
        ## Any some point we should rewrite this variable to display the Transceiver Compliance Codes as enums
        self.addRemoteVariables(   
            name         = 'Transceiver',
            description  = 'Code for electronic compatibility or optical compatibility',
            offset       = (3 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 8,
            stride       = 4,
        )        
        
        self.add(pr.RemoteVariable(
            name        = 'Encoding', 
            description = 'Code for serial encoding algorithm',
            offset      = (11 << 2),
            bitSize     = 8, 
            mode        = 'RO',
            enum        = {
                0x0: 'Unspecified', 
                0x1: '8B10B', 
                0x2: '4B5B', 
                0x3: 'NRZ',
                0x4: 'Manchester', 
                0x5: 'SONET Scrambled', 
                0x6: '64B/66B', 
            },
        ))  

        self.add(pr.RemoteVariable(
            name        = 'BrNominal', 
            description = 'The nominal bit rate (BR, nominal) is specified in units of 100 Megabits per second, rounded off to the nearest 100 Megabits per second. The bit rate includes those bits necessary to encode and delimit the signal as well as those bits carrying data information. A value of 0 indicates that the bit rate is not specified and must be determined from the transceiver technology. The actual information transfer rate will depend on the encoding of the data, as defined by the encoding value.',
            offset      = (12 << 2),
            bitSize     = 8, 
            mode        = 'RO',
            base        = pr.UInt,
            units       = '100 Mbps',
        ))  

        self.add(pr.RemoteVariable(
            name        = 'RateId', 
            description = 'The Rate Identifier refers to several (optional) industry standard definitions of Rate Select or Application Select control behaviors, intended to manage transceiver optimization for multiple operating rates.',
            offset      = (13 << 2),
            bitSize     = 8, 
            mode        = 'RO',
            enum        = {
                0x0: 'Unspecified', 
                0x1: 'SFF-8079 (4/2/1G Rate Select and AS0/AS1)', 
                0x2: 'SFF-8431 (8/4/2G RX Rate Select Only)', 
                0x3: 'Unspecified',
                0x4: 'SFF-8431 (8/4/2G TX Rate Select Only)', 
                0x5: 'Unspecified', 
                0x6: 'SFF-8431 (8/4/2G Independent TX and RX Rate Select)', 
                0x7: 'Unspecified', 
                0x8: 'FC-PI-5 (16/8/4G RX Rate Select Only) High=16G, Low=8/4G', 
                0x9: 'Unspecified', 
                0xA: 'FC-PI-5 (16/8/4G Independent TX and RX Rate Select) High=16G, Low=8/4G', 
            },
        ))  

        self.add(pr.RemoteVariable(
            name        = 'Length9umKm', 
            description = 'Link length supported for 9/125 um fiber',
            offset      = (14 << 2),
            bitSize     = 8, 
            mode        = 'RO',
            base        = pr.UInt,
            units       = 'km',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Length9um', 
            description = 'Link length supported for 9/125 um fiber',
            offset      = (15 << 2),
            bitSize     = 8, 
            mode        = 'RO',
            base        = pr.UInt,
            units       = '100 m',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Length50um[0]', 
            description = 'Link length supported for 50/125 um OM2 fiber',
            offset      = (16 << 2),
            bitSize     = 8, 
            mode        = 'RO',
            base        = pr.UInt,
            units       = '10 m',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Length62um', 
            description = 'Link length supported for 62.5/125 um OM1 fiber',
            offset      = (17 << 2),
            bitSize     = 8, 
            mode        = 'RO',
            base        = pr.UInt,
            units       = '10 m',
        )) 

        self.add(pr.RemoteVariable(
            name        = 'LengthCopper', 
            description = 'Link length supported for copper and Active Cable,',
            offset      = (18 << 2),
            bitSize     = 8, 
            mode        = 'RO',
            base        = pr.UInt,
            units       = 'm',
          
        ))         
        
        self.add(pr.RemoteVariable(
            name        = 'Length50um[1]', 
            description = 'Link length supported for 50/125 um fiber',
            offset      = (19 << 2),
            bitSize     = 8, 
            mode        = 'RO',
            base        = pr.UInt,
            units       = '10 m',
        ))         

        self.addRemoteVariables(   
            name         = 'VendorName',
            description  = 'SFP vendor name (ASCII)',
            offset       = (20 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 16,
            stride       = 4,
        )           
                  
        self.addRemoteVariables(   
            name         = 'VendorOui',
            description  = 'SFP vendor IEEE company ID',
            offset       = (37 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 3,
            stride       = 4,
        )  
        
        self.addRemoteVariables(   
            name         = 'VendorPn',
            description  = 'Part number provided by SFP vendor (ASCII)',
            offset       = (40 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 16,
            stride       = 4,
        )   

        self.addRemoteVariables(   
            name         = 'VendorRev',
            description  = 'Revision level for part number provided by vendor (ASCII)',
            offset       = (56 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 4,
            stride       = 4,
        ) 

        self.addRemoteVariables(   
            name         = 'Wavelength',
            description  = 'Laser wavelength',
            offset       = (60 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 2,
            stride       = 4,
        )

        self.add(pr.RemoteVariable(
            name        = 'CcBase', 
            description = 'Check code for Base ID Fields (addresses 0 to 62)',
            offset      = (63 << 2),
            bitSize     = 8, 
            mode        = 'RO',
            base        = pr.UInt,
        ))          
        
        ####################    
        # EXTENDED ID FIELDS
        ####################    
        
        self.addRemoteVariables(   
            name         = 'Options',
            description  = 'Indicates which optional transceiver signals are implemented',
            offset       = (64 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 2,
            stride       = 4,
        )          
        
        self.add(pr.RemoteVariable(
            name        = 'BrMax', 
            description = 'Upper bit rate margin',
            offset      = (66 << 2),
            bitSize     = 8, 
            mode        = 'RO',
            base        = pr.UInt,
            units       = '%',            
        ))   

        self.add(pr.RemoteVariable(
            name        = 'BrMin', 
            description = 'Lower bit rate margin',
            offset      = (67 << 2),
            bitSize     = 8, 
            mode        = 'RO',
            base        = pr.UInt,
            units       = '%',            
        ))           
        
        self.addRemoteVariables(   
            name         = 'VendorSn',
            description  = 'Serial number provided by vendor (ASCII)',
            offset       = (68 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 16,
            stride       = 4,
        ) 

        self.addRemoteVariables(   
            name         = 'DateCode',
            description  = 'Vendor’s manufacturing date code',
            offset       = (84 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 8,
            stride       = 4,
        )         
        
        self.add(pr.RemoteVariable(
            name        = 'DiagnosticMonitoringType', 
            description = 'Indicates which type of diagnostic monitoring is implemented (if any) in the transceiver',
            offset      = (92 << 2),
            bitSize     = 8, 
            mode        = 'RO',
            base        = pr.UInt,          
        )) 
        
        self.add(pr.RemoteVariable(
            name        = 'EnhancedOptions', 
            description = 'Indicates which optional enhanced features are implemented (if any) in the transceiver',
            offset      = (93 << 2),
            bitSize     = 8, 
            mode        = 'RO',
            base        = pr.UInt,          
        ))  

        self.add(pr.RemoteVariable(
            name        = 'Sff8472Compliance', 
            description = 'Indicates which revision of SFF-8472 the transceiver complies with',
            offset      = (94 << 2),
            bitSize     = 8, 
            mode        = 'RO',
            base        = pr.UInt,          
        ))   
     
        self.add(pr.RemoteVariable(
            name        = 'CcExt', 
            description = 'Check code for the Extended ID Fields (addresses 64 to 94)',
            offset      = (95 << 2),
            bitSize     = 8, 
            mode        = 'RO',
            base        = pr.UInt,
        ))        

        ###########################  
        # VENDOR SPECIFIC ID FIELDS
        ###########################  

        self.addRemoteVariables(   
            name         = 'VendorSpecificA',
            description  = 'Vendor Specific EEPROM',
            offset       = (96 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 32,
            stride       = 4,
        ) 

        # self.addRemoteVariables(   
            # name         = 'ReservedA',
            # description  = 'Reserved for SFF-8079',
            # offset       = (128 << 2),
            # bitSize      = 8,
            # mode         = 'RO',
            # base         = pr.UInt,
            # number       = 128,
            # stride       = 4,
        # )      


        #####################################################
        #       Diagnostics: Data Fields – Address A2h      #
        #####################################################
        
        ######################################
        # DIAGNOSTIC AND CONTROL/STATUS FIELDS
        ######################################
        
        # self.addRemoteVariables(   
            # name         = 'AwThresholds',
            # description  = 'Diagnostic Flag Alarm and Warning Thresholds',
            # offset       = ((256+0) << 2),
            # bitSize      = 8,
            # mode         = 'RO',
            # base         = pr.UInt,
            # number       = 40,
            # stride       = 4,
        # )    
        
        # self.addRemoteVariables(   
            # name         = 'UnallocatedA',
            # description  = 'Reserved',
            # offset       = ((256+40) << 2),
            # bitSize      = 8,
            # mode         = 'RO',
            # base         = pr.UInt,
            # number       = 16,
            # stride       = 4,
        # )   

        self.addRemoteVariables(   
            name         = 'ExtCalConstants',
            description  = 'Diagnostic Calibration Constants for Ext Cal',
            offset       = ((256+56) << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 36,
            stride       = 4,
        )           
        
        # self.addRemoteVariables(   
            # name         = 'UnallocatedB',
            # description  = 'Reserved',
            # offset       = ((256+92) << 2),
            # bitSize      = 8,
            # mode         = 'RO',
            # base         = pr.UInt,
            # number       = 3,
            # stride       = 4,
        # )           
        
        self.add(pr.RemoteVariable(
            name        = 'CcDmi', 
            description = 'Check Code for Base Diagnostic Fields 0-94',
            offset      = ((256+95) << 2),
            bitSize     = 8, 
            mode        = 'RO',
            base        = pr.UInt,
        ))           
        
        self.addRemoteVariables(   
            name         = 'Diagnostics',
            description  = 'Diagnostic Monitor Data (internal or external)',
            offset       = ((256+96) << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 10,
            stride       = 4,
        )              
        
        # self.addRemoteVariables(   
            # name         = 'UnallocatedC',
            # description  = 'Reserved',
            # offset       = ((256+109) << 2),
            # bitSize      = 8,
            # mode         = 'RO',
            # base         = pr.UInt,
            # number       = 4,
            # stride       = 4,
        # )         
        
        self.add(pr.RemoteVariable(
            name        = 'StatusControl', 
            description = 'Optional Status and Control Bits',
            offset      = ((256+110) << 2),
            bitSize     = 8, 
            mode        = 'RO',
            base        = pr.UInt,
        ))  

        # self.add(pr.RemoteVariable(
            # name         = 'ReservedB',
            # description  = 'Reserved for SFF-8079',
            # offset      = (111 << 2),
            # bitSize     = 8, 
            # mode        = 'RO',
            # base        = pr.UInt,
        # ))          
        
        self.addRemoteVariables(   
            name         = 'AlarmFlags',
            description  = 'Diagnostic Alarm Flags Status Bits',
            offset       = ((256+112) << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 2,
            stride       = 4,
        )     

        # self.addRemoteVariables(   
            # name         = 'UnallocatedD',
            # description  = 'Reserved',
            # offset       = ((256+114) << 2),
            # bitSize      = 8,
            # mode         = 'RO',
            # base         = pr.UInt,
            # number       = 2,
            # stride       = 4,
        # )         
        
        self.addRemoteVariables(   
            name         = 'Warning Flags',
            description  = 'Diagnostic Warning Flag Status Bits',
            offset       = ((256+116) << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 2,
            stride       = 4,
        ) 

        self.addRemoteVariables(   
            name         = 'ExtStatusControl',
            description  = 'Extened Module Control and Status Bits',
            offset       = ((256+118) << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 2,
            stride       = 4,
        )         
        
        ######################################
        # GENERAL USE FIELDS
        ######################################        
        
        self.addRemoteVariables(   
            name         = 'DiagnosticsVendorSpecific',
            description  = 'Diagnostics: Data Field Vendor Specific EEPROM',
            offset       = ((256+120) << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 8,
            stride       = 4,
        )   

        self.addRemoteVariables(   
            name         = 'UserEeprom',
            description  = 'User writeable non-volatile memory',
            offset       = ((256+128) << 2),
            bitSize      = 8,
            mode         = 'RW',
            base         = pr.UInt,
            number       = 120,
            stride       = 4,
            hidden       = True,
        )           
        
        self.addRemoteVariables(   
            name         = 'VendorControl',
            description  = 'Vendor specific control addresses',
            offset       = ((256+248) << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 8,
            stride       = 4,
        )
