#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue JESD TX Module
#-----------------------------------------------------------------------------
# File       : JesdTx.py
# Created    : 2017-04-04
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
    def __init__(self, name="JesdTx", description="JESD TX Module", memBase=None, offset=0x0, hidden=False, numTxLanes=2):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden)

        digits = len(str(abs(numTxLanes-1)))

        ##############################
        # Variables
        ##############################

        self.add(pr.Variable(   name         = "Enable",
                                description  = "Enable mask. Example: 0x3 Enable ln0 and ln1.",
                                offset       =  0x00,
                                bitSize      =  numTxLanes,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "SubClass",
                                description  = "Jesd204b SubClass. 0 - For designs without sysref (no fixed latency). 1 - Fixed latency.",
                                offset       =  0x10,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "ReplaceEnable",
                                description  = "ReplaceEnable. Replace the control characters with data. (Should be 1 use 0 only for debug).",
                                offset       =  0x10,
                                bitSize      =  1,
                                bitOffset    =  0x01,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "ResetGTs",
                                description  = "ResetGTs. Request reset of the GT modules.",
                                offset       =  0x10,
                                bitSize      =  1,
                                bitOffset    =  0x02,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "ClearErrors",
                                description  = "Clear Jesd Errors and reset the status counters.",
                                offset       =  0x10,
                                bitSize      =  1,
                                bitOffset    =  0x03,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "InvertSync",
                                description  = "InvertSync. Invert sync input (the AMC card schematics should be checkes if inverted). ",
                                offset       =  0x10,
                                bitSize      =  1,
                                bitOffset    =  0x04,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "TestSigEnable",
                                description  = "Invert Sync. Sync output has to be inverted in some systems depending on signal polarities on the PCB.",
                                offset       =  0x10,
                                bitSize      =  1,
                                bitOffset    =  0x05,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "ScrambleEnable",
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
                            ))

        self.add(pr.Variable(   name         = "RampStep",
                                description  = "Ramp increment step and a period of the wave in c-c",
                                offset       =  0x14,
                                bitSize      =  16,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "SquarePeriod",
                                description  = "Ramp increment step and a period of the wave in c-c",
                                offset       =  0x16,
                                bitSize      =  16,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "LowAmplitudeVal",
                                description  = "Low value of the square waveform amplitude",
                                offset       =  0x18,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "HighAmplitudeVal",
                                description  = "High value of the square waveform amplitude",
                                offset       =  0x1C,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "InvertDacData",
                                description  = "Mask Enable the DAC data inversion. 1-Inverted, 0-normal.",
                                offset       =  0x20,
                                bitSize      =  numTxLanes,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        for i in range(numTxLanes):
            self.add(pr.Variable(   name         = "GTReady_%.*i" % (digits, i),
                                    description  = "GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data. Lane %.*i" % (digits, i),
                                    offset       =  0x40 + (0x04*i),
                                    bitSize      =  1,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

            self.add(pr.Variable(   name         = "DataValid_%.*i" % (digits, i),
                                    description  = "Jesd Data Valid. Goes high after the code synchronisation and ILAS sequence is complete (More info in Jesd204b standard). Lane %.*i" % (digits, i),
                                    offset       =  0x40 + (0x04*i),
                                    bitSize      =  1,
                                    bitOffset    =  0x01,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

            self.add(pr.Variable(   name         = "IlasActive_%.*i" % (digits, i),
                                    description  = "ILA sequence Active. Only 1 for 4 multiframe clock cycles then it drops (More info in Jesd204b standard). Lane %.*i" % (digits, i),
                                    offset       =  0x40 + (0x04*i),
                                    bitSize      =  1,
                                    bitOffset    =  0x02,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

            self.add(pr.Variable(   name         = "nSync_%.*i" % (digits, i),
                                    description  = "nSync. 0 - Not synchronised. 1 - Indicades that code group synchronisation has been completed. Lane %.*i" % (digits, i),
                                    offset       =  0x40 + (0x04*i),
                                    bitSize      =  1,
                                    bitOffset    =  0x03,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

            self.add(pr.Variable(   name         = "TxEnabled_%.*i" % (digits, i),
                                    description  = "Tx Lane Enabled. Indicates if the lane had been enabled in configuration. Lane %.*i" % (digits, i),
                                    offset       =  0x40 + (0x04*i),
                                    bitSize      =  1,
                                    bitOffset    =  0x04,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

            self.add(pr.Variable(   name         = "SysRefDetected_%.*i" % (digits, i),
                                    description  = "System Reference input has been Detected. Lane %.*i" % (digits, i),
                                    offset       =  0x40 + (0x04*i),
                                    bitSize      =  1,
                                    bitOffset    =  0x05,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

            self.add(pr.Variable(   name         = "dataOutMux_%.*i" % (digits, i),
                                    description  = "data_out_mux: Select between: b000 - Output zero, b001 - Parallel data from inside FPGA, b010 - Data from AXI stream (not used), b011 - Test data. Lane %.*i" % (digits, i),
                                    offset       =  0x80 + (0x04*i),
                                    bitSize      =  4,
                                    bitOffset    =  0x00,
                                    base         = "enum",
                                    mode         = "RW",
                                    enum         = {
                                                      0 : "OutputZero",
                                                      1 : "UserData",
                                                      2 : "AxiStream",
                                                      3 : "TestData",
                                                   },
                                ))

            self.add(pr.Variable(   name         = "testOutMux_%.*i" % (digits, i),
                                    description  = "test_out_mux[1:0]: Select between: b000 - Saw signal increment, b001 - Saw signal decrement, b010 - Square wave,  b011 - Output zero. Lane %.*i" % (digits, i),
                                    offset       =  0x80 + (0x04*i),
                                    bitSize      =  4,
                                    bitOffset    =  0x04,
                                    base         = "enum",
                                    mode         = "RW",
                                    enum         = {
                                                      0 : "SawIncrement",
                                                      1 : "SawDecrement",
                                                      2 : "SquareWave",
                                                      3 : "OutputZero",
                                                   },
                                ))

            self.add(pr.Variable(   name         = "StatusValidCnt_%.*i" % (digits, i),
                                    description  = "StatusValidCnt[31:0]. Shows stability of JESD lanes. Counts number of JESD re-syncronisations. Lane %.*i" % (digits, i),
                                    offset       =  0x100 + (0x04*i),
                                    bitSize      =  32,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        ##############################
        # Commands
        ##############################

        self.add(pr.Command (   name         = "ClearTxStatus",
                                description  = "Clear the status valid counter of TX lanes.",
                                function     = """\
                                               self.ClearErrors.set(1)
                                               self.ClearErrors.set(0)
                                               """
                            ))

        self.add(pr.Command (   name         = "ResetTxGTs",
                                description  = "Toggle the reset of all TX MGTs",
                                function     = """\
                                               self.ResetGTs.set(1)
                                               self.ResetGTs.set(0)
                                               """
                            ))

