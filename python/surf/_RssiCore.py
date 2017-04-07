#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue RSSI module
#-----------------------------------------------------------------------------
# File       : RssiCore.py
# Created    : 2017-04-04
#-----------------------------------------------------------------------------
# Description:
# PyRogue RSSI module
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

class RssiCore(pr.Device):
    def __init__(self, name="RssiCore", description="RSSI module", memBase=None, offset=0x0, hidden=False):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden)

        ##############################
        # Variables
        ##############################

        self.add(pr.Variable(   name         = "OpenConn",
                                description  = "Open Connection Request (Server goes to listen state, Client actively requests the connection by sending SYN segment)",
                                offset       =  0x00,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "CloseConn",
                                description  = "Close Connection Request (Send a RST Segment to peer and close the connection)",
                                offset       =  0x00,
                                bitSize      =  1,
                                bitOffset    =  0x01,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "Mode",
                                description  = "Mode:'0': Use internal parameters from generics,'1': Use parameters from registers",
                                offset       =  0x00,
                                bitSize      =  1,
                                bitOffset    =  0x02,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "HeaderChksumEn",
                                description  = "Header checksum: '1': Enable calculation and check, '0': Disable check and insert 0 in place of header checksum",
                                offset       =  0x00,
                                bitSize      =  1,
                                bitOffset    =  0x03,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "InjectFault",
                                description  = "Inject fault to the next packet header checksum (Default '0'). Acts on rising edge - injects exactly one fault in next segment",
                                offset       =  0x00,
                                bitSize      =  1,
                                bitOffset    =  0x04,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "InitSeqN",
                                description  = "Initial sequence number [7:0]",
                                offset       =  0x04,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "Version",
                                description  = "Version register [3:0]",
                                offset       =  0x08,
                                bitSize      =  4,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "MaxOutsSeg",
                                description  = "Maximum out standing segments [7:0]",
                                offset       =  0x0C,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "MaxSegSize",
                                description  = "Maximum segment size [15:0]",
                                offset       =  0x10,
                                bitSize      =  16,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "RetransTimeout",
                                description  = "Retransmission timeout [15:0]",
                                offset       =  0x14,
                                bitSize      =  16,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "CumAckTimeout",
                                description  = "Cumulative acknowledgment timeout [15:0]",
                                offset       =  0x18,
                                bitSize      =  16,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "NullSegTimeout",
                                description  = "Null segment timeout [15:0]",
                                offset       =  0x1C,
                                bitSize      =  16,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "MaxNumRetrans",
                                description  = "Maximum number of retransmissions [7:0]",
                                offset       =  0x20,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "MaxCumAck",
                                description  = "Maximum cumulative acknowledgments [7:0]",
                                offset       =  0x24,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "MaxOutOfSeq",
                                description  = "Max out of sequence segments (EACK) [7:0]",
                                offset       =  0x28,
                                bitSize      =  8,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "ConnectionActive",
                                description  = "Connection Active",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "ErrMaxRetrans",
                                description  = "Maximum retransmissions exceeded retransMax.",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x01,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "ErrNullTout",
                                description  = "Null timeout reached (server) nullTout.",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x02,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "ErrAck",
                                description  = "Error in acknowledgment mechanism.",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x03,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "ErrSsiFrameLen",
                                description  = "SSI Frame length too long",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x04,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "ErrConnTout",
                                description  = "Connection to peer timed out. Timeout defined in generic PEER_CONN_TIMEOUT_G (Default: 1000 ms)",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x05,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "ParamRejected",
                                description  = "Client rejected the connection (parameters out of range), Server proposed new parameters (parameters out of range)",
                                offset       =  0x40,
                                bitSize      =  1,
                                bitOffset    =  0x06,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "ValidCnt",
                                description  = "Number of valid segments [31:0]",
                                offset       =  0x44,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "DropCnt",
                                description  = "Number of dropped segments [31:0]",
                                offset       =  0x48,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "RetransmitCnt",
                                description  = "Counts all retransmission requests within the active connection [31:0]",
                                offset       =  0x4C,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "ReconnectCnt",
                                description  = "Counts all reconnections from reset [31:0]",
                                offset       =  0x50,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        for i in range(2):
            self.add(pr.Variable(   name         = "FrameRate_%i" % (i),
                                    description  = "Frame Rate (in units of Hz)%i" % (i),
                                    offset       =  0x54 + (i * 0x04),
                                    bitSize      =  32,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(2):
            self.add(pr.Variable(   name         = "Bandwidth_%i" % (i),
                                    description  = "Bandwidth (in units of bytes per second)%i" % (i),
                                    offset       =  0x5C + (i * 0x08),
                                    bitSize      =  64,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        ##############################
        # Commands
        ##############################

        self.add(pr.Command (   name         = "C_OpenConn",
                                description  = "Open connection request",
                                function     = """\
                                               self.OpenConn.set(1)
                                               self.OpenConn.set(0)
                                               """
                            ))

        self.add(pr.Command (   name         = "C_CloseConn",
                                description  = "Close connection request",
                                function     = """\
                                               self.CloseConn.set(1)
                                               self.CloseConn.set(0)
                                               """
                            ))

        self.add(pr.Command (   name         = "C_InjectFault",
                                description  = "Inject a single fault(for debug and test purposes only). Corrupts checksum during transmission",
                                function     = """\
                                               self.InjectFault.set(1)
                                               self.InjectFault.set(0)
                                               """
                            ))

