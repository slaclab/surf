#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue JESD RX Module
#-----------------------------------------------------------------------------
# File       : JesdRx.py
# Created    : 2017-04-04
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
    def __init__(self, name="JesdRx", description="JESD RX Module", memBase=None, offset=0x0, hidden=False, numRxLanes=6):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden)

        digits = len(str(abs(numRxLanes-1)))

        ##############################
        # Variables
        ##############################

        self.add(pr.Variable(   name         = "Enable",
                                description  = "Enable mask. Example: 0x3F Enable ln0 to ln5.",
                                offset       =  0x00,
                                bitSize      =  numRxLanes,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "SysrefDelay",
                                description  = "Sets the system reference delay in clock cycles. Use if you want to reduce the latency (The latency is indicated by ElBuffLatency status). ",
                                offset       =  0x04,
                                bitSize      =  5,
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
                                base         = "enum",
                                mode         = "RW",
                                enum         = {
                                                  0 : "Disabled",
                                                  1 : "Enabled",
                                               },
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
                            ))

        self.add(pr.Variable(   name         = "ScrambleEnable",
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
                            ))

        self.add(pr.Variable(   name         = "LinkErrMask",
                                description  = "Mask Enable the errors that are required to brake the link. bit 5-0: positionErr - s_bufOvf - s_bufUnf - dispErr - decErr - s_alignErr",
                                offset       =  0x14,
                                bitSize      =  6,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "InvertAdcData",
                                description  = "Mask Enable the ADC data inversion. 1-Inverted, 0-normal.",
                                offset       =  0x18,
                                bitSize      =  numRxLanes,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        for i in range(numRxLanes):
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

            self.add(pr.Variable(   name         = "AlignErr_%.*i" % (digits, i),
                                    description  = "Jesd Character Alignment Error. The control characters in the data are missaligned. This error will trigger JESD re-synchronisation. Lane %.*i" % (digits, i),
                                    offset       =  0x40 + (0x04*i),
                                    bitSize      =  1,
                                    bitOffset    =  0x02,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

            self.add(pr.Variable(   name         = "nSync_%.*i" % (digits, i),
                                    description  = "Synchronisation request. 0 - Not synchronised. 1 - Indicades that code group synchronisation has been completed. Lane %.*i" % (digits, i),
                                    offset       =  0x40 + (0x04*i),
                                    bitSize      =  1,
                                    bitOffset    =  0x03,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

            self.add(pr.Variable(   name         = "RxBuffUfl_%.*i" % (digits, i),
                                    description  = "Jesd sync fifo buffer undeflow. This error will trigger JESD re-synchronisation. Lane %.*i" % (digits, i),
                                    offset       =  0x40 + (0x04*i),
                                    bitSize      =  1,
                                    bitOffset    =  0x04,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

            self.add(pr.Variable(   name         = "RxBuffOfl_%.*i" % (digits, i),
                                    description  = "Jesd elastic buffer overflow. This error will trigger JESD re-synchronisation. Lane %.*i" % (digits, i),
                                    offset       =  0x40 + (0x04*i),
                                    bitSize      =  1,
                                    bitOffset    =  0x05,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

            self.add(pr.Variable(   name         = "PositionErr_%.*i" % (digits, i),
                                    description  = "The position of K28.5 character during code group synchronisation is wrong. This error will trigger JESD re-synchronisation. Lane %.*i" % (digits, i),
                                    offset       =  0x40 + (0x04*i),
                                    bitSize      =  1,
                                    bitOffset    =  0x06,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

            self.add(pr.Variable(   name         = "RxEnabled_%.*i" % (digits, i),
                                    description  = "Rx Lane Enabled. Indicates if the lane had been enabled in configuration. Lane %.*i" % (digits, i),
                                    offset       =  0x40 + (0x04*i),
                                    bitSize      =  1,
                                    bitOffset    =  0x07,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

            self.add(pr.Variable(   name         = "SysRefDetected_%.*i" % (digits, i),
                                    description  = "System Reference input has been Detected. Lane %.*i" % (digits, i),
                                    offset       =  0x41 + (0x04*i),
                                    bitSize      =  1,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

            self.add(pr.Variable(   name         = "CommaDetected_%.*i" % (digits, i),
                                    description  = "The K28.5 characters detected in the serial stream. Lane %.*i" % (digits, i),
                                    offset       =  0x41 + (0x04*i),
                                    bitSize      =  1,
                                    bitOffset    =  0x01,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

            self.add(pr.Variable(   name         = "DisparityErr_%.*i" % (digits, i),
                                    description  = "Latched High when the data byte on RXDATA arrives with the wrong disparity. Indicates bad serial connection (Check HW). Lane %.*i" % (digits, i),
                                    offset       =  0x41 + (0x04*i),
                                    bitSize      =  4,
                                    bitOffset    =  0x02,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

            self.add(pr.Variable(   name         = "NotInTableErr_%.*i" % (digits, i),
                                    description  = "NotInTableErr. When GT decoder received s 10-bit character that cannot be mapped into a valid 8B/10B character. Indicates bad serial connection (Check HW). Lane %.*i" % (digits, i),
                                    offset       =  0x41 + (0x04*i),
                                    bitSize      =  4,
                                    bitOffset    =  0x06,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

            self.add(pr.Variable(   name         = "ElBuffLatency_%.*i" % (digits, i),
                                    description  = "Jesd204b elastic buffer latency in c-c. Can be adjusted by Sysref delay. Lane %.*i" % (digits, i),
                                    offset       =  0x42 + (0x04*i),
                                    bitSize      =  8,
                                    bitOffset    =  0x02,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

            self.add(pr.Variable(   name         = "ThresholdLow_%.*i" % (digits, i),
                                    description  = "Threshold_Low. Debug funtionality. Threshold for generating a digital signal from the ADC data. Lane %.*i" % (digits, i),
                                    offset       =  0xC0 + (0x04*i),
                                    bitSize      =  16,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RW",
                                ))

            self.add(pr.Variable(   name         = "ThresholdHigh_%.*i" % (digits, i),
                                    description  = "Threshold_High. Debug funtionality. Threshold for generating a digital signal from the ADC data. Lane %.*i" % (digits, i),
                                    offset       =  0xC2 + (0x04*i),
                                    bitSize      =  16,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RW",
                                ))

            self.add(pr.Variable(   name         = "StatusValidCnt_%.*i" % (digits, i),
                                    description  = "StatusValidCnt. Shows stability of JESD lanes. Counts number of JESD re-syncronisations. Lane %.*i" % (digits, i),
                                    offset       =  0x100 + (0x04*i),
                                    bitSize      =  32,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

            self.add(pr.Variable(   name         = "RawData_%.*i" % (digits, i),
                                    description  = "Raw data from GT. Lane %.*i" % (digits, i),
                                    offset       =  0x140 + (0x04*i),
                                    bitSize      =  32,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        ##############################
        # Commands
        ##############################

        self.add(pr.Command (   name         = "ClearRxErrors",
                                description  = "Clear the registered errors of all RX lanes",
                                function     = """\
                                               self.ClearErrors.set(1)
                                               self.ClearErrors.set(0)
                                               """
                            ))

        self.add(pr.Command (   name         = "ResetRxGTs",
                                description  = "Toggle the reset of all RX MGTs",
                                function     = """\
                                               self.ResetGTs.set(1)
                                               self.ResetGTs.set(0)
                                               """
                            ))

