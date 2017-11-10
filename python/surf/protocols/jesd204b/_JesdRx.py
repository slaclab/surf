#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue JESD RX Module
#-----------------------------------------------------------------------------
# File       : JesdRx.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue JESD RX Module
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

class JesdRx(pr.Device):
    def __init__(   self,       
            name        = "JesdRx",
            description = "JESD RX Module",
            numRxLanes  =  6,
            instantiate =  True,
            debug	    =  False,
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        ##############################
        # Variables
        ##############################

        if (instantiate):
            self.add(pr.RemoteVariable(    
                name         = "Enable",
                description  = "Enable mask. Example: 0x3F Enable ln0 to ln5.",
                offset       =  0x00,
                bitSize      =  numRxLanes,
                bitOffset    =  0x00,
                base         = pr.UInt,
                mode         = "RW",
            ))

            self.add(pr.RemoteVariable(    
                name         = "SysrefDelay",
                description  = "Sets the system reference delay in clock cycles. Use if you want to reduce the latency (The latency is indicated by ElBuffLatency status). ",
                offset       =  0x04,
                bitSize      =  5,
                bitOffset    =  0x00,
                base         = pr.UInt,
                mode         = "RW",
            ))
                            
            self.add(pr.RemoteVariable(    
                name         = "Polarity",
                description  = "0 = non-inverted, 1 = inverted",
                offset       =  0x08,
                bitSize      =  numRxLanes,
                bitOffset    =  0,
                base         = pr.UInt,
                mode         = "RW",
            ))                              

            self.add(pr.RemoteVariable(    
                name         = "SubClass",
                description  = "Jesd204b SubClass. 0 - For designs without sysref (no fixed latency). 1 - Fixed latency.",
                offset       =  0x10,
                bitSize      =  1,
                bitOffset    =  0x00,
                base         = pr.UInt,
                mode         = "RW",
            ))

            self.add(pr.RemoteVariable(    
                name         = "ReplaceEnable",
                description  = "ReplaceEnable. Replace the control characters with data. (Should be 1 use 0 only for debug).",
                offset       =  0x10,
                bitSize      =  1,
                bitOffset    =  0x01,
                mode         = "RW",
                enum         = {
                    0 : "Disabled",
                    1 : "Enabled",
                },
            ))

            self.add(pr.RemoteVariable(    
                name         = "ResetGTs",
                description  = "ResetGTs. Request reset of the GT modules.",
                offset       =  0x10,
                bitSize      =  1,
                bitOffset    =  0x02,
                base         = pr.UInt,
                mode         = "RW",
            ))

            self.add(pr.RemoteVariable(    
                name         = "ClearErrors",
                description  = "Clear Jesd Errors and reset the status counters.",
                offset       =  0x10,
                bitSize      =  1,
                bitOffset    =  0x03,
                base         = pr.UInt,
                mode         = "RW",
            ))

            self.add(pr.RemoteVariable(    
                name         = "InvertSync",
                description  = "Invert Sync. Sync output has to be inverted in some systems depending on signal polarities on the PCB.",
                offset       =  0x10,
                bitSize      =  1,
                bitOffset    =  0x04,
                mode         = "RW",
                enum         = {
                    0 : "Regular",
                    1 : "Inverted",
                },
            ))

            self.add(pr.RemoteVariable(    
                name         = "ScrambleEnable",
                description  = "ScrambleEnable. Enable data scrambling (More info in Jesd204b standard).",
                offset       =  0x10,
                bitSize      =  1,
                bitOffset    =  0x05,
                mode         = "RW",
                enum         = {
                    0 : "Disabled",
                    1 : "Enabled",
                },
            ))

            self.add(pr.RemoteVariable(    
                name         = "LinkErrMask",
                description  = "Mask Enable the errors that are required to brake the link. bit 5-0: positionErr - s_bufOvf - s_bufUnf - dispErr - decErr - s_alignErr",
                offset       =  0x14,
                bitSize      =  6,
                bitOffset    =  0x00,
                base         = pr.UInt,
                mode         = "RW",
            ))

            self.add(pr.RemoteVariable(    
                name         = "InvertAdcData",
                description  = "Mask Enable the ADC data inversion. 1-Inverted, 0-normal.",
                offset       =  0x18,
                bitSize      =  numRxLanes,
                bitOffset    =  0x00,
                base         = pr.UInt,
                mode         = "RW",
            ))

            self.add(pr.RemoteVariable( 
                name         = "GTReady",
                description  = "GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data.",
                offset       = range(0x40,0x40+4*numRxLanes,4),
                bitSize      = 1,
                bitOffset    = 0,
                mode         = "RO",
                pollInterval = 1,
            ))

            self.add(pr.RemoteVariable( 
                name         = "DataValid",
                description  = "Jesd Data Valid. Goes high after the code synchronization and ILAS sequence is complete (More info in Jesd204b standard).",
                offset       = range(0x40,0x40+4*numRxLanes,4),
                bitSize      = 1,
                bitOffset    = 1,
                mode         = "RO",
                pollInterval = 1,
            ))

            self.add(pr.RemoteVariable( 
                name         = "AlignErr",
                description  = "Jesd Character Alignment Error. The control characters in the data are missaligned. This error will trigger JESD re-synchronization.",
                offset       = range(0x40,0x40+4*numRxLanes,4),
                bitSize      = 1,
                bitOffset    = 2,
                mode         = "RO",
                pollInterval = 1,
            ))

            self.add(pr.RemoteVariable( 
                name         = "nSync",
                description  = "Synchronisation request. 0 - Not synchronised. 1 - Indicades that code group synchronization has been completed.",
                offset       = range(0x40,0x40+4*numRxLanes,4),
                bitSize      = 1,
                bitOffset    = 3,
                mode         = "RO",
            ))  

            self.add(pr.RemoteVariable( 
                name         = "RxBuffUfl",
                description  = "Jesd sync fifo buffer undeflow. This error will trigger JESD re-synchronization.",
                offset       = range(0x40,0x40+4*numRxLanes,4),
                bitSize      = 1,
                bitOffset    = 4,
                mode         = "RO",
                pollInterval = 1,
            ))  

            self.add(pr.RemoteVariable( 
                name         = "RxBuffOfl",
                description  = "Jesd elastic buffer overflow. This error will trigger JESD re-synchronization.",
                offset       = range(0x40,0x40+4*numRxLanes,4),
                bitSize      = 1,
                bitOffset    = 5,
                mode         = "RO",
                pollInterval = 1,
            ))  

            self.add(pr.RemoteVariable( 
                name         = "PositionErr",
                description  = "The position of K28.5 character during code group synchronization is wrong. This error will trigger JESD re-synchronization.",
                offset       = range(0x40,0x40+4*numRxLanes,4),
                bitSize      = 1,
                bitOffset    = 6,
                mode         = "RO",
                pollInterval = 1,
            ))  

            self.add(pr.RemoteVariable( 
                name         = "RxEnabled",
                description  = "Rx Lane Enabled. Indicates if the lane had been enabled in configuration.",
                offset       = range(0x40,0x40+4*numRxLanes,4),
                bitSize      = 1,
                bitOffset    = 7,
                mode         = "RO",
                pollInterval = 1,
            ))  

            self.add(pr.RemoteVariable( 
                name         = "SysRefDetected",
                description  = "System Reference input has been Detected.",
                offset       = range(0x40,0x40+4*numRxLanes,4),
                bitSize      = 1,
                bitOffset    = 8,
                mode         = "RO",
                pollInterval = 1,
            ))  

            self.add(pr.RemoteVariable( 
                name         = "CommaDetected",
                description  = "The K28.5 characters detected in the serial stream. ",
                offset       = range(0x40,0x40+4*numRxLanes,4),
                bitSize      = 1,
                bitOffset    = 9,
                mode         = "RO",
                pollInterval = 1,
            ))  

            self.addRemoteVariables(   
                name         = "DisparityErr",
                description  = "Latched High when the data byte on RXDATA arrives with the wrong disparity. Indicates bad serial connection (Check HW).",
                offset       =  0x40,
                bitSize      =  4,
                bitOffset    =  10,
                base         = pr.UInt,
                mode         = "RO",
                number       =  numRxLanes,
                stride       =  4,
                pollInterval = 1,
            )

            self.addRemoteVariables(   
                name         = "NotInTableErr",
                description  = "NotInTableErr. When GT decoder received s 10-bit character that cannot be mapped into a valid 8B/10B character. Indicates bad serial connection (Check HW).",
                offset       =  0x40,
                bitSize      =  4,
                bitOffset    =  14,
                base         = pr.UInt,
                mode         = "RO",
                number       =  numRxLanes,
                stride       =  4,
                pollInterval = 1,
            )

            self.addRemoteVariables(   
                name         = "ElBuffLatency",
                description  = "Jesd204b elastic buffer latency in c-c. Can be adjusted by Sysref delay.",
                offset       =  0x40,
                bitSize      =  8,
                bitOffset    =  18,
                base         = pr.UInt,
                mode         = "RO",
                number       =  numRxLanes,
                stride       =  4,
                pollInterval = 1,
            )
                            
            if (debug):
                self.addRemoteVariables(   
                    name         = "ThresholdLow",
                    description  = "Threshold_Low. Debug funtionality. Threshold for generating a digital signal from the ADC data.",
                    offset       =  0xC0,
                    bitSize      =  16,
                    bitOffset    =  0x00,
                    base         = pr.UInt,
                    mode         = "RW",
                    number       =  numRxLanes,
                    stride       =  4,
                )

                self.addRemoteVariables(   
                    name         = "ThresholdHigh",
                    description  = "Threshold_High. Debug funtionality. Threshold for generating a digital signal from the ADC data.",
                    offset       =  0xC0,
                    bitSize      =  16,
                    bitOffset    =  16,
                    base         = pr.UInt,
                    mode         = "RW",
                    number       =  numRxLanes,
                    stride       =  4,
                )

            self.addRemoteVariables(   
                name         = "StatusValidCnt",
                description  = "StatusValidCnt. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.",
                offset       =  0x100,
                bitSize      =  32,
                bitOffset    =  0x00,
                base         = pr.UInt,
                mode         = "RO",
                number       =  numRxLanes,
                stride       =  4,
                pollInterval = 1,
            )


            self.addRemoteVariables(   
                name         = "RawData",
                description  = "Raw data from GT.",
                offset       =  0x140,
                bitSize      =  32,
                bitOffset    =  0x00,
                base         = pr.UInt,
                mode         = "RO",
                number       =  numRxLanes,
                stride       =  4,
                pollInterval = 1,
            )

            ##############################
            # Commands
            ##############################
            
            @self.command(name="CmdClearErrors", description="Clear the status valid counter of RX lanes.",)
            def CmdClearErrors():    
                self.ClearErrors.set(1)
                self.ClearErrors.set(0)

            @self.command(name="CmdResetGTs", description="Toggle the reset of all RX MGTs",)
            def CmdResetGTs(): 
                self.ResetGTs.set(1)
                self.ResetGTs.set(0)                    
                
