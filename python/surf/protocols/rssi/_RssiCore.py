#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue RSSI module
#-----------------------------------------------------------------------------
# File       : RssiCore.py
# Created    : 2017-04-12
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
    def __init__(   self,       
            name        = "RssiCore",
            description = "RSSI module",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(    
            name         = "OpenConn",
            description  = "Open Connection Request (Server goes to listen state, Client actively requests the connection by sending SYN segment)",
            offset       =  0x00,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "CloseConn",
            description  = "Close Connection Request (Send a RST Segment to peer and close the connection)",
            offset       =  0x00,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "Mode",
            description  = "Mode:'0': Use internal parameters from generics,'1': Use parameters from registers",
            offset       =  0x00,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "HeaderChksumEn",
            description  = "Header checksum: '1': Enable calculation and check, '0': Disable check and insert 0 in place of header checksum",
            offset       =  0x00,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "InjectFault",
            description  = "Inject fault to the next packet header checksum (Default '0'). Acts on rising edge - injects exactly one fault in next segment",
            offset       =  0x00,
            bitSize      =  1,
            bitOffset    =  0x04,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "InitSeqN",
            description  = "Initial sequence number [7:0]",
            offset       =  0x04,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "Version",
            description  = "Version register [3:0]",
            offset       =  0x08,
            bitSize      =  4,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "MaxOutsSeg",
            description  = "Maximum out standing segments [7:0]",
            offset       =  0x0C,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "MaxSegSize",
            description  = "Maximum segment size [15:0]",
            offset       =  0x10,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "RetransTimeout",
            description  = "Retransmission timeout [15:0]",
            offset       =  0x14,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "CumAckTimeout",
            description  = "Cumulative acknowledgment timeout [15:0]",
            offset       =  0x18,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "NullSegTimeout",
            description  = "Null segment timeout [15:0]",
            offset       =  0x1C,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "MaxNumRetrans",
            description  = "Maximum number of retransmissions [7:0]",
            offset       =  0x20,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "MaxCumAck",
            description  = "Maximum cumulative acknowledgments [7:0]",
            offset       =  0x24,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "MaxOutOfSeq",
            description  = "Max out of sequence segments (EACK) [7:0]",
            offset       =  0x28,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "ConnectionActive",
            description  = "Connection Active",
            offset       =  0x40,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(    
            name         = "ErrMaxRetrans",
            description  = "Maximum retransmissions exceeded retransMax.",
            offset       =  0x40,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = pr.UInt,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(    
            name         = "ErrNullTout",
            description  = "Null timeout reached (server) nullTout.",
            offset       =  0x40,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = pr.UInt,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(    
            name         = "ErrAck",
            description  = "Error in acknowledgment mechanism.",
            offset       =  0x40,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = pr.UInt,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(    
            name         = "ErrSsiFrameLen",
            description  = "SSI Frame length too long",
            offset       =  0x40,
            bitSize      =  1,
            bitOffset    =  0x04,
            base         = pr.UInt,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(    
            name         = "ErrConnTout",
            description  = "Connection to peer timed out. Timeout defined in generic PEER_CONN_TIMEOUT_G (Default: 1000 ms)",
            offset       =  0x40,
            bitSize      =  1,
            bitOffset    =  0x05,
            base         = pr.UInt,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(    
            name         = "ParamRejected",
            description  = "Client rejected the connection (parameters out of range), Server proposed new parameters (parameters out of range)",
            offset       =  0x40,
            bitSize      =  1,
            bitOffset    =  0x06,
            base         = pr.UInt,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(    
            name         = "ValidCnt",
            description  = "Number of valid segments [31:0]",
            offset       =  0x44,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(    
            name         = "DropCnt",
            description  = "Number of dropped segments [31:0]",
            offset       =  0x48,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(    
            name         = "RetransmitCnt",
            description  = "Counts all retransmission requests within the active connection [31:0]",
            offset       =  0x4C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(    
            name         = "ReconnectCnt",
            description  = "Counts all reconnections from reset [31:0]",
            offset       =  0x50,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            pollInterval = 1,
        ))
        
        self.add(pr.RemoteVariable(    
            name         = 'TxFrameRate',
            description  = 'Outbound Frame Rate',
            units        = 'Hz',
            offset       =  0x54,
            base         = pr.UInt,
            mode         = "RO",
            disp         = '{:d}',
            pollInterval = 1,
        ))   
        
        self.add(pr.RemoteVariable(    
            name         = 'TxBandwidth',
            description  = 'Outbound Bandwidth',
            units        = 'B/s',
            offset       =  0x5C,
            bitSize      =  64,
            base         = pr.UInt,
            mode         = "RO",
            disp         = '{:d}',
            pollInterval = 1,
        ))           
        
        self.add(pr.RemoteVariable(    
            name         = 'RxFrameRate',
            description  = 'Inbound Frame Rate',
            units        = 'Hz',
            offset       =  0x58,
            base         = pr.UInt,
            mode         = "RO",
            disp         = '{:d}',
            pollInterval = 1,
        ))           
        
        self.add(pr.RemoteVariable(    
            name         = 'RxBandwidth',
            description  = 'Inbound Bandwidth',
            units        = 'B/s',
            offset       =  0x64,
            bitSize      =  64,
            base         = pr.UInt,
            mode         = "RO",
            disp         = '{:d}',
            pollInterval = 1,
        ))           

        ##############################
        # Commands
        ##############################
        @self.command(name="C_OpenConn", description="Open connection request",)
        def C_OpenConn():        
           self.OpenConn.set(0)

        @self.command(name="C_CloseConn", description="Close connection request",)
        def C_CloseConn():                        
           self.CloseConn.set(1)
           self.CloseConn.set(0)
                        
        @self.command(name="C_InjectFault", description="Inject a single fault(for debug and test purposes only). Corrupts checksum during transmission",)
        def C_InjectFault():                        
           self.InjectFault.set(1)
           self.InjectFault.set(0)
