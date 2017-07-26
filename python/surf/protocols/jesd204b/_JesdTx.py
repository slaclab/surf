#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue JESD TX Module
#-----------------------------------------------------------------------------
# File       : JesdTx.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue JESD TX Module
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

class JesdTx(pr.Device):
    def __init__(   self,       
            name        = "JesdTx",
            description = "JESD TX Module",
            numTxLanes  =  2,
            instantiate =  True,
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        ##############################
        # Variables
        ##############################

        if (instantiate):
            self.add(pr.RemoteVariable(    
                name         = "Enable",
                description  = "Enable mask. Example: 0x3 Enable ln0 and ln1.",
                offset       =  0x00,
                bitSize      =  numTxLanes,
                bitOffset    =  0x00,
                base         = pr.UInt,
                mode         = "RW",
            ))
                            
            self.add(pr.RemoteVariable(    
                name         = "Polarity",
                description  = "0 = non-inverted, 1 = inverted",
                offset       =  0x08,
                bitSize      =  numTxLanes,
                bitOffset    =  0,
                base         = pr.UInt,
                mode         = "RW",
            ))         

            self.add(pr.RemoteVariable(    
                name         = "Loopback",
                description  = "0 = normal mode, 1 = internal loopback",
                offset       =  0x0C,
                bitSize      =  numTxLanes,
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
                base         = pr.UInt,
                mode         = "RW",
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
                description  = "InvertSync. Invert sync input (the AMC card schematics should be checkes if inverted). ",
                offset       =  0x10,
                bitSize      =  1,
                bitOffset    =  0x04,
                base         = pr.UInt,
                mode         = "RW",
            ))
    
            self.add(pr.RemoteVariable(    
                name         = "TestSigEnable",
                description  = "Invert Sync. Sync output has to be inverted in some systems depending on signal polarities on the PCB.",
                offset       =  0x10,
                bitSize      =  1,
                bitOffset    =  0x05,
                base         = pr.UInt,
                mode         = "RW",
            ))
    
            self.add(pr.RemoteVariable(    
                name         = "ScrambleEnable",
                description  = "ScrambleEnable. Enable data scrambling (More info in Jesd204b standard). ",
                offset       =  0x10,
                bitSize      =  1,
                bitOffset    =  0x06,
                mode         = "RW",
                enum         = {
                    0 : "Disabled",
                    1 : "Enabled",
                },
            ))
    
            self.add(pr.RemoteVariable(    
                name         = "RampStep",
                description  = "Ramp increment step and a period of the wave in c-c",
                offset       =  0x14,
                bitSize      =  16,
                bitOffset    =  0x00,
                base         = pr.UInt,
                mode         = "RW",
            ))
    
            self.add(pr.RemoteVariable(    
                name         = "SquarePeriod",
                description  = "Ramp increment step and a period of the wave in c-c",
                offset       =  0x14,
                bitSize      =  16,
                bitOffset    =  16,
                base         = pr.UInt,
                mode         = "RW",
            ))
    
            self.add(pr.RemoteVariable(    
                name         = "LowAmplitudeVal",
                description  = "Low value of the square waveform amplitude",
                offset       =  0x18,
                bitSize      =  32,
                bitOffset    =  0x00,
                base         = pr.UInt,
                mode         = "RW",
            ))
    
            self.add(pr.RemoteVariable(    
                name         = "HighAmplitudeVal",
                description  = "High value of the square waveform amplitude",
                offset       =  0x1C,
                bitSize      =  32,
                bitOffset    =  0x00,
                base         = pr.UInt,
                mode         = "RW",
            ))
    
            self.add(pr.RemoteVariable(    
                name         = "InvertDacData",
                description  = "Mask Enable the DAC data inversion. 1-Inverted, 0-normal.",
                offset       =  0x20,
                bitSize      =  numTxLanes,
                bitOffset    =  0x00,
                base         = pr.UInt,
                mode         = "RW",
            ))

            self.add(pr.RemoteVariable( 
                name         = "GTReady",
                description  = "GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data.",
                offset       = range(0x40,0x40+4*numTxLanes+1,4),
                bitSize      = 1,
                bitOffset    = 0,
                mode         = "RO",
                pollInterval = 1,
            ))  
                            
            self.add(pr.RemoteVariable( 
                name         = "DataValid",
                description  = "Jesd Data Valid. Goes high after the code synchronization and ILAS sequence is complete (More info in Jesd204b standard).",
                offset       = range(0x40,0x40+4*numTxLanes+1,4),
                bitSize      = 1,
                bitOffset    = 1,
                mode         = "RO",
                pollInterval = 1,
            ))  

            self.add(pr.RemoteVariable( 
                name         = "IlasActive",
                description  = "ILA sequence Active. Only 1 for 4 multiframe clock cycles then it drops (More info in Jesd204b standard).",
                offset       = range(0x40,0x40+4*numTxLanes+1,4),
                bitSize      = 1,
                bitOffset    = 2,
                mode         = "RO",
                pollInterval = 1,
            ))  

            self.add(pr.RemoteVariable( 
                name         = "nSync",
                description  = "nSync. 0 - Not synchronised. 1 - Indicades that code group synchronization has been completed.",
                offset       = range(0x40,0x40+4*numTxLanes+1,4),
                bitSize      = 1,
                bitOffset    = 3,
                mode         = "RO",
                pollInterval = 1,
            ))  

            self.add(pr.RemoteVariable( 
                name         = "TxEnabled",
                description  = "Tx Lane Enabled. Indicates if the lane had been enabled in configuration.",
                offset       = range(0x40,0x40+4*numTxLanes+1,4),
                bitSize      = 1,
                bitOffset    = 4,
                mode         = "RO",
                pollInterval = 1,
            ))  

            self.add(pr.RemoteVariable( 
                name         = "SysRefDetected",
                description  = "System Reference input has been Detected.",
                offset       = range(0x40,0x40+4*numTxLanes+1,4),
                bitSize      = 1,
                bitOffset    = 5,
                mode         = "RO",
                pollInterval = 1,
            ))  
    
            self.addRemoteVariables(   
                name         = "StatusValidCnt",
                description  = "StatusValidCnt[31:0]. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.",
                offset       =  0x100,
                bitSize      =  32,
                bitOffset    =  0x00,
                base         = pr.UInt,
                mode         = "RO",
                number       =  numTxLanes,
                stride       =  4,
                pollInterval =  1,
            )  
    
            self.addRemoteVariables(   
                name         = "txDiffCtrl",
                description  = "TX diff. swing control",
                offset       =  0x200,
                bitSize      =  8,
                bitOffset    =  0,
                base         = pr.UInt,
                mode         = "RW",
                number       =  numTxLanes,
                stride       =  4,
            )   

            self.addRemoteVariables(   
                name         = "txPostCursor",
                description  = "TX post cursor control",
                offset       =  0x200,
                bitSize      =  8,
                bitOffset    =  8,
                base         = pr.UInt,
                mode         = "RW",
                number       =  numTxLanes,
                stride       =  4,
            )

            self.addRemoteVariables(   
                name         = "txPreCursor",
                description  = "TX pre cursor control",
                offset       =  0x200,
                bitSize      =  8,
                bitOffset    =  16,
                base         = pr.UInt,
                mode         = "RW",
                number       =  numTxLanes,
                stride       =  4,
            )                            
    
            self.addRemoteVariables(   
                name         = "dataOutMux",
                description  = "data_out_mux: Select between: b000 - Output zero, b001 - Parallel data from inside FPGA, b010 - Data from AXI stream (not used), b011 - Test data",
                offset       =  0x80,
                bitSize      =  4,
                bitOffset    =  0x00,
                mode         = "RW",
                number       =  numTxLanes,
                stride       =  4,
                enum         = {
                    0 : "OutputZero",
                    1 : "UserData",
                    2 : "OutputOnes",
                    3 : "TestData",
                },
            )
    
            self.addRemoteVariables(   
                name         = "testOutMux",
                description  = "test_out_mux[1:0]: Select between: b000 - Saw signal increment, b001 - Saw signal decrement, b010 - Square wave,  b011 - Output zero",
                offset       =  0x80,
                bitSize      =  4,
                bitOffset    =  0x04,
                mode         = "RW",
                number       =  numTxLanes,
                stride       =  4,
                enum         = {
                    0 : "SawIncrement",
                    1 : "SawDecrement",
                    2 : "SquareWave",
                    3 : "OutputZero",
                },
            )    
    
            ##############################
            # Commands
            ##############################
            @self.command(name="CmdClearErrors", description="Clear the status valid counter of TX lanes.",)
            def CmdClearErrors():    
                self.ClearErrors.set(1)
                self.ClearErrors.set(0)

            @self.command(name="CmdResetGTs", description="Toggle the reset of all TX MGTs",)
            def CmdResetGTs(): 
                self.ResetGTs.set(1)
                self.ResetGTs.set(0)                            
