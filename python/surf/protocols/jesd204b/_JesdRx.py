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
                    memBase     =  None,
                    offset      =  0x00,
                    hidden      =  False,
                    numRxLanes  =  6,
                    instantiate =  True,
                ):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden, )

        ##############################
        # Variables
        ##############################

        if (instantiate):
            self.addVariable(   name         = "Enable",
                                description  = "Enable mask. Example: 0x3F Enable ln0 to ln5.",
                                offset       =  0x00,
                                bitSize      =  numRxLanes,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            )

            self.addVariable(   name         = "SysrefDelay",
                                description  = "Sets the system reference delay in clock cycles. Use if you want to reduce the latency (The latency is indicated by ElBuffLatency status). ",
                                offset       =  0x04,
                                bitSize      =  5,
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
                                base         = "enum",
                                mode         = "RW",
                                enum         = {
                                                  0 : "Disabled",
                                                  1 : "Enabled",
                                               },
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
                                description  = "Invert Sync. Sync output has to be inverted in some systems depending on signal polarities on the PCB.",
                                offset       =  0x10,
                                bitSize      =  1,
                                bitOffset    =  0x04,
                                base         = "enum",
                                mode         = "RW",
                                enum         = {
                                                  0 : "Regular",
                                                  1 : "Inverted",
                                               },
                            )

            self.addVariable(   name         = "ScrambleEnable",
                                description  = "ScrambleEnable. Enable data scrambling (More info in Jesd204b standard).",
                                offset       =  0x10,
                                bitSize      =  1,
                                bitOffset    =  0x05,
                                base         = "enum",
                                mode         = "RW",
                                enum         = {
                                                  0 : "Disabled",
                                                  1 : "Enabled",
                                               },
                            )

            self.addVariable(   name         = "LinkErrMask",
                                description  = "Mask Enable the errors that are required to brake the link. bit 5-0: positionErr - s_bufOvf - s_bufUnf - dispErr - decErr - s_alignErr",
                                offset       =  0x14,
                                bitSize      =  6,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            )

            self.addVariable(   name         = "InvertAdcData",
                                description  = "Mask Enable the ADC data inversion. 1-Inverted, 0-normal.",
                                offset       =  0x18,
                                bitSize      =  numRxLanes,
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
                                number       =  numRxLanes,
                                stride       =  4,
                            )

            self.addVariables(  name         = "DataValid",
                                description  = "Jesd Data Valid. Goes high after the code synchronisation and ILAS sequence is complete (More info in Jesd204b standard).",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x01,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numRxLanes,
                                stride       =  4,
                            )

            self.addVariables(  name         = "AlignErr",
                                description  = "Jesd Character Alignment Error. The control characters in the data are missaligned. This error will trigger JESD re-synchronisation.",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x02,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numRxLanes,
                                stride       =  4,
                            )

            self.addVariables(  name         = "nSync",
                                description  = "Synchronisation request. 0 - Not synchronised. 1 - Indicades that code group synchronisation has been completed.",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x03,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numRxLanes,
                                stride       =  4,
                            )

            self.addVariables(  name         = "RxBuffUfl",
                                description  = "Jesd sync fifo buffer undeflow. This error will trigger JESD re-synchronisation.",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x04,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numRxLanes,
                                stride       =  4,
                            )

            self.addVariables(  name         = "RxBuffOfl",
                                description  = "Jesd elastic buffer overflow. This error will trigger JESD re-synchronisation.",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x05,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numRxLanes,
                                stride       =  4,
                            )

            self.addVariables(  name         = "PositionErr",
                                description  = "The position of K28.5 character during code group synchronisation is wrong. This error will trigger JESD re-synchronisation.",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x06,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numRxLanes,
                                stride       =  4,
                            )

            self.addVariables(  name         = "RxEnabled",
                                description  = "Rx Lane Enabled. Indicates if the lane had been enabled in configuration.",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x07,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numRxLanes,
                                stride       =  4,
                            )

            self.addVariables(  name         = "SysRefDetected",
                                description  = "System Reference input has been Detected.",
                                offset       =  0x41,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numRxLanes,
                                stride       =  4,
                            )

            self.addVariables(  name         = "CommaDetected",
                                description  = "The K28.5 characters detected in the serial stream. ",
                                offset       =  0x41,
                                bitSize      =  1,
                                bitOffset    =  0x01,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numRxLanes,
                                stride       =  4,
                            )

            self.addVariables(  name         = "DisparityErr",
                                description  = "Latched High when the data byte on RXDATA arrives with the wrong disparity. Indicates bad serial connection (Check HW).",
                                offset       =  0x41,
                                bitSize      =  4,
                                bitOffset    =  0x02,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numRxLanes,
                                stride       =  4,
                            )

            self.addVariables(  name         = "NotInTableErr",
                                description  = "NotInTableErr. When GT decoder received s 10-bit character that cannot be mapped into a valid 8B/10B character. Indicates bad serial connection (Check HW).",
                                offset       =  0x41,
                                bitSize      =  4,
                                bitOffset    =  0x06,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numRxLanes,
                                stride       =  4,
                            )

            self.addVariables(  name         = "ElBuffLatency",
                                description  = "Jesd204b elastic buffer latency in c-c. Can be adjusted by Sysref delay.",
                                offset       =  0x42,
                                bitSize      =  8,
                                bitOffset    =  0x02,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numRxLanes,
                                stride       =  4,
                            )

            self.addVariables(  name         = "ThresholdLow",
                                description  = "Threshold_Low. Debug funtionality. Threshold for generating a digital signal from the ADC data.",
                                offset       =  0xC0,
                                bitSize      =  16,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                                number       =  numRxLanes,
                                stride       =  4,
                            )

            self.addVariables(  name         = "ThresholdHigh",
                                description  = "Threshold_High. Debug funtionality. Threshold for generating a digital signal from the ADC data.",
                                offset       =  0xC2,
                                bitSize      =  16,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                                number       =  numRxLanes,
                                stride       =  4,
                            )

            self.addVariables(  name         = "StatusValidCnt",
                                description  = "StatusValidCnt. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.",
                                offset       =  0x100,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numRxLanes,
                                stride       =  4,
                            )

            self.addVariables(  name         = "RawData",
                                description  = "Raw data from GT.",
                                offset       =  0x140,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                                number       =  numRxLanes,
                                stride       =  4,
                            )

            ##############################
            # Commands
            ##############################

            self.addCommand(    name         = "ClearRxErrors",
                                description  = "Clear the registered errors of all RX lanes",
                                function     = """\
                                               self.ClearErrors.set(1)
                                               self.ClearErrors.set(0)
                                               """
                            )

            self.addCommand(    name         = "ResetRxGTs",
                                description  = "Toggle the reset of all RX MGTs",
                                function     = """\
                                               self.ResetGTs.set(1)
                                               self.ResetGTs.set(0)
                                               """
                            )

