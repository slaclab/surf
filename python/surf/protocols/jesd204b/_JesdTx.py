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
                    memBase     =  None,
                    offset      =  0x00,
                    hidden      =  False,
                    numTxLanes  =  2,
                    instantiate =  True,
                    expand	    =  True,
                ):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden, expand=expand)  

        ##############################
        # Variables
        ##############################

        if (instantiate):
            self.addVariable(   name         = "Enable",
                                description  = "Enable mask. Example: 0x3 Enable ln0 and ln1.",
                                offset       =  0x00,
                                bitSize      =  numTxLanes,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            )
    
            self.addVariable(   name         = "SubClass",
                                description  = "Jesd204b SubClass. 0 - For designs without sysref (no fixed latency). 1 - Fixed latency.",
                                offset       =  0x10,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            )
    
            self.addVariable(   name         = "ReplaceEnable",
                                description  = "ReplaceEnable. Replace the control characters with data. (Should be 1 use 0 only for debug).",
                                offset       =  0x10,
                                bitSize      =  1,
                                bitOffset    =  0x01,
                                base         = "hex",
                                mode         = "RW",
                            )
    
            self.addVariable(   name         = "ResetGTs",
                                description  = "ResetGTs. Request reset of the GT modules.",
                                offset       =  0x10,
                                bitSize      =  1,
                                bitOffset    =  0x02,
                                base         = "hex",
                                mode         = "RW",
                            )
    
            self.addVariable(   name         = "ClearErrors",
                                description  = "Clear Jesd Errors and reset the status counters.",
                                offset       =  0x10,
                                bitSize      =  1,
                                bitOffset    =  0x03,
                                base         = "hex",
                                mode         = "RW",
                            )
    
            self.addVariable(   name         = "InvertSync",
                                description  = "InvertSync. Invert sync input (the AMC card schematics should be checkes if inverted). ",
                                offset       =  0x10,
                                bitSize      =  1,
                                bitOffset    =  0x04,
                                base         = "hex",
                                mode         = "RW",
                            )
    
            self.addVariable(   name         = "TestSigEnable",
                                description  = "Invert Sync. Sync output has to be inverted in some systems depending on signal polarities on the PCB.",
                                offset       =  0x10,
                                bitSize      =  1,
                                bitOffset    =  0x05,
                                base         = "hex",
                                mode         = "RW",
                            )
    
            self.addVariable(   name         = "ScrambleEnable",
                                description  = "ScrambleEnable. Enable data scrambling (More info in Jesd204b standard). ",
                                offset       =  0x10,
                                bitSize      =  1,
                                bitOffset    =  0x06,
                                base         = "enum",
                                mode         = "RW",
                                enum         = {
                                                  0 : "Disabled",
                                                  1 : "Enabled",
                                               },
                            )
    
            self.addVariable(   name         = "RampStep",
                                description  = "Ramp increment step and a period of the wave in c-c",
                                offset       =  0x14,
                                bitSize      =  16,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            )
    
            self.addVariable(   name         = "SquarePeriod",
                                description  = "Ramp increment step and a period of the wave in c-c",
                                offset       =  0x14,
                                bitSize      =  16,
                                bitOffset    =  16,
                                base         = "hex",
                                mode         = "RW",
                            )
    
            self.addVariable(   name         = "LowAmplitudeVal",
                                description  = "Low value of the square waveform amplitude",
                                offset       =  0x18,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            )
    
            self.addVariable(   name         = "HighAmplitudeVal",
                                description  = "High value of the square waveform amplitude",
                                offset       =  0x1C,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            )
    
            self.addVariable(   name         = "InvertDacData",
                                description  = "Mask Enable the DAC data inversion. 1-Inverted, 0-normal.",
                                offset       =  0x20,
                                bitSize      =  numTxLanes,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            )
    
            self.addVariables(  name         = "GTReady",
                                description  = "GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data.",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numTxLanes,
                                stride       =  4,
                            )
    
            self.addVariables(  name         = "DataValid",
                                description  = "Jesd Data Valid. Goes high after the code synchronisation and ILAS sequence is complete (More info in Jesd204b standard).",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x01,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numTxLanes,
                                stride       =  4,
                            )
    
            self.addVariables(  name         = "IlasActive",
                                description  = "ILA sequence Active. Only 1 for 4 multiframe clock cycles then it drops (More info in Jesd204b standard).",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x02,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numTxLanes,
                                stride       =  4,
                            )
    
            self.addVariables(  name         = "nSync",
                                description  = "nSync. 0 - Not synchronised. 1 - Indicades that code group synchronisation has been completed.",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x03,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numTxLanes,
                                stride       =  4,
                            )
    
            self.addVariables(  name         = "TxEnabled",
                                description  = "Tx Lane Enabled. Indicates if the lane had been enabled in configuration.",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x04,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numTxLanes,
                                stride       =  4,
                            )
    
            self.addVariables(  name         = "SysRefDetected",
                                description  = "System Reference input has been Detected.",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x05,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numTxLanes,
                                stride       =  4,
                            )
    
            self.addVariables(  name         = "dataOutMux",
                                description  = "data_out_mux: Select between: b000 - Output zero, b001 - Parallel data from inside FPGA, b010 - Data from AXI stream (not used), b011 - Test data",
                                offset       =  0x80,
                                bitSize      =  4,
                                bitOffset    =  0x00,
                                base         = "enum",
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
    
            self.addVariables(  name         = "testOutMux",
                                description  = "test_out_mux[1:0]: Select between: b000 - Saw signal increment, b001 - Saw signal decrement, b010 - Square wave,  b011 - Output zero",
                                offset       =  0x80,
                                bitSize      =  4,
                                bitOffset    =  0x04,
                                base         = "enum",
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
    
            self.addVariables(  name         = "StatusValidCnt",
                                description  = "StatusValidCnt[31:0]. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.",
                                offset       =  0x100,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numTxLanes,
                                stride       =  4,
                            )
    
    
    
            self.addVariables(  name         = "txDiffCtrl",
                                description  = "TX diff. swing control",
                                offset       =  0x200,
                                bitSize      =  8,
                                bitOffset    =  0,
                                base         = "hex",
                                mode         = "RW",
                                number       =  numTxLanes,
                                stride       =  4,
                            )   

            self.addVariables(  name         = "txPostCursor",
                                description  = "TX post cursor control",
                                offset       =  0x200,
                                bitSize      =  8,
                                bitOffset    =  8,
                                base         = "hex",
                                mode         = "RW",
                                number       =  numTxLanes,
                                stride       =  4,
                            )

            self.addVariables(  name         = "txPreCursor",
                                description  = "TX pre cursor control",
                                offset       =  0x200,
                                bitSize      =  8,
                                bitOffset    =  16,
                                base         = "hex",
                                mode         = "RW",
                                number       =  numTxLanes,
                                stride       =  4,
                            )                            
    
            ##############################
            # Commands
            ##############################
    
    
            def clearErrors(dev, cmd, arg):
                dev.ClearErrors.set(1)
                dev.ClearErrors.set(0)
            self.addCommand(    name         = "CmdClearErrors",
                                description  = "Clear the status valid counter of TX lanes.",
                                function     = clearErrors
                            )

            def resetGTs(dev, cmd, arg):
                dev.ResetGTs.set(1)
                dev.ResetGTs.set(0)                            
            self.addCommand(    name         = "CmdResetGTs",
                                description  = "Toggle the reset of all RX MGTs",
                                function     = resetGTs
                            )    
