#-----------------------------------------------------------------------------
# Title      : PyRogue RSSI module
#-----------------------------------------------------------------------------
# File       : RssiCore.py
#-----------------------------------------------------------------------------
# Description:
# PyRogue RSSI module
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class RssiCore(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(
            name         = 'OpenConn',
            description  = 'Open Connection Request (Server goes to listen state, Client actively requests the connection by sending SYN segment)',
            offset       = 0x00,
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'CloseConn',
            description  = 'Close Connection Request (Send a RST Segment to peer and close the connection)',
            offset       = 0x00,
            bitSize      = 1,
            bitOffset    = 0x01,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'Mode',
            description  = 'Mode: 0x0 = Use internal parameters from generics, 0x1 = Use parameters from registers',
            offset       = 0x00,
            bitSize      = 1,
            bitOffset    = 0x02,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'HeaderChksumEn',
            description  = 'Header checksum: 0x1 = Enable calculation and check, 0x0: Disable check and insert 0 in place of header checksum',
            offset       = 0x00,
            bitSize      = 1,
            bitOffset    = 0x03,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'InjectFault',
            description  = 'Inject fault to the next packet header checksum (Default 0x0). Acts on rising edge - injects exactly one fault in next segment',
            offset       = 0x00,
            bitSize      = 1,
            bitOffset    = 0x04,
            mode         = 'RW',
        ))

        # self.add(pr.RemoteVariable(
            # name         = 'InitSeqN',
            # description  = 'Initial sequence number [7:0]',
            # offset       = 0x04,
            # bitSize      = 8,
            # bitOffset    = 0,
            # mode         = 'RW',
        # ))

        # self.add(pr.RemoteVariable(
            # name         = 'locVersion',
            # description  = 'Version register [3:0]',
            # offset       = 0x08,
            # bitSize      = 4,
            # bitOffset    = 0,
            # mode         = 'RW',
            # disp         = '{:d}',
        # ))

        # self.add(pr.RemoteVariable(
            # name         = 'curVersion',
            # description  = 'Version register [3:0]',
            # offset       = 0x08,
            # bitSize      = 4,
            # bitOffset    = 16,
            # mode         = 'RO',
            # disp         = '{:d}',
        # ))

        varPrefix = ['loc','cur']
        for i in range(2):

            self.add(pr.RemoteVariable(
                name         = (varPrefix[i]+'MaxOutsSeg'),
                description  = 'Maximum out standing segments [7:0]',
                offset       = 0x0C,
                bitSize      = 8,
                bitOffset    = i*16,
                mode         = ('RW' if i==0 else 'RO'),
                disp         = '{:d}',
            ))

            self.add(pr.RemoteVariable(
                name         = (varPrefix[i]+'MaxSegSize'),
                description  = 'Maximum segment size [15:0]',
                offset       = 0x10,
                bitSize      = 16,
                bitOffset    = i*16,
                mode         = ('RW' if i==0 else 'RO'),
                disp         = '{:d}',
            ))

            self.add(pr.RemoteVariable(
                name         = (varPrefix[i]+'RetransTimeout'),
                description  = 'Retransmission timeout [15:0]',
                offset       = 0x14,
                bitSize      = 16,
                bitOffset    = i*16,
                mode         = ('RW' if i==0 else 'RO'),
                disp         = '{:d}',
            ))

            self.add(pr.RemoteVariable(
                name         = (varPrefix[i]+'CumAckTimeout'),
                description  = 'Cumulative acknowledgment timeout [15:0]',
                offset       = 0x18,
                bitSize      = 16,
                bitOffset    = i*16,
                mode         = ('RW' if i==0 else 'RO'),
                disp         = '{:d}',
            ))

            self.add(pr.RemoteVariable(
                name         = (varPrefix[i]+'NullSegTimeout'),
                description  = 'Null segment timeout [15:0]',
                offset       = 0x1C,
                bitSize      = 16,
                bitOffset    = i*16,
                mode         = ('RW' if i==0 else 'RO'),
                disp         = '{:d}',
            ))

            self.add(pr.RemoteVariable(
                name         = (varPrefix[i]+'MaxNumRetrans'),
                description  = 'Maximum number of retransmissions [7:0]',
                offset       = 0x20,
                bitSize      = 8,
                bitOffset    = i*16,
                mode         = ('RW' if i==0 else 'RO'),
                disp         = '{:d}',
            ))

            self.add(pr.RemoteVariable(
                name         = (varPrefix[i]+'MaxCumAck'),
                description  = 'Maximum cumulative acknowledgments [7:0]',
                offset       = 0x24,
                bitSize      = 8,
                bitOffset    = i*16,
                mode         = ('RW' if i==0 else 'RO'),
                disp         = '{:d}',
            ))

            # self.add(pr.RemoteVariable(
                # name         = (varPrefix[i]+'MaxOutOfSeq'),
                # description  = 'Max out of sequence segments (EACK) [7:0]',
                # offset       = 0x28,
                # bitSize      = 8,
                # bitOffset    = i*16,
                # mode         = ('RW' if i==0 else 'RO')',
                # disp         = '{:d}',
            # ))

        self.add(pr.RemoteVariable(
            name         = 'ConnectionActive',
            description  = 'Connection Active',
            offset       = 0x40,
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
        ))

        # self.add(pr.RemoteVariable(
            # name         = 'ErrMaxRetrans',
            # description  = 'Maximum retransmissions exceeded retransMax.',
            # offset       = 0x40,
            # bitSize      = 1,
            # bitOffset    = 0x01,
            # mode         = 'RO',
            # pollInterval = 1,
        # ))

        # self.add(pr.RemoteVariable(
            # name         = 'ErrNullTout',
            # description  = 'Null timeout reached (server) nullTout.',
            # offset       = 0x40,
            # bitSize      = 1,
            # bitOffset    = 0x02,
            # mode         = 'RO',
            # pollInterval = 1,
        # ))

        # self.add(pr.RemoteVariable(
            # name         = 'ErrAck',
            # description  = 'Error in acknowledgment mechanism.',
            # offset       = 0x40,
            # bitSize      = 1,
            # bitOffset    = 0x03,
            # mode         = 'RO',
            # pollInterval = 1,
        # ))

        # self.add(pr.RemoteVariable(
            # name         = 'ErrSsiFrameLen',
            # description  = 'SSI Frame length too long',
            # offset       = 0x40,
            # bitSize      = 1,
            # bitOffset    = 0x04,
            # mode         = 'RO',
            # pollInterval = 1,
        # ))

        # self.add(pr.RemoteVariable(
            # name         = 'ErrConnTout',
            # description  = 'Connection to peer timed out. Timeout defined in generic PEER_CONN_TIMEOUT_G (Default: 1000 ms)',
            # offset       = 0x40,
            # bitSize      = 1,
            # bitOffset    = 0x05,
            # mode         = 'RO',
            # pollInterval = 1,
        # ))

        # self.add(pr.RemoteVariable(
            # name         = 'ParamRejected',
            # description  = 'Client rejected the connection (parameters out of range), Server proposed new parameters (parameters out of range)',
            # offset       = 0x40,
            # bitSize      = 1,
            # bitOffset    = 0x06,
            # mode         = 'RO',
            # pollInterval = 1,
        # ))

        self.add(pr.RemoteVariable(
            name         = 'ValidCnt',
            description  = 'Number of valid segments [31:0]',
            offset       = 0x44,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'DropCnt',
            description  = 'Number of dropped segments [31:0]',
            offset       = 0x48,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RetransmitCnt',
            description  = 'Counts all retransmission requests within the active connection [31:0]',
            offset       = 0x4C,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'ReconnectCnt',
            description  = 'Counts all reconnections from reset [31:0]',
            offset       = 0x50,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxFrameRate',
            description  = 'Outbound Frame Rate',
            units        = 'Hz',
            offset       = 0x54,
            mode         = 'RO',
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxBandwidth',
            description  = 'Outbound Bandwidth',
            units        = 'B/s',
            offset       = 0x5C,
            bitSize      = 64,
            mode         = 'RO',
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxFrameRate',
            description  = 'Inbound Frame Rate',
            units        = 'Hz',
            offset       = 0x58,
            mode         = 'RO',
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxBandwidth',
            description  = 'Inbound Bandwidth',
            units        = 'B/s',
            offset       = 0x64,
            bitSize      = 64,
            mode         = 'RO',
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxTspState',
            description  = 'TX Transport FSM state',
            offset       = 0x6C,
            bitSize      = 8,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
            enum         = {
                0: 'INIT_S',
                1: 'DISS_CONN_S',
                2: 'CONN_S',
                3: 'SYN_H_S',
                4: 'ACK_H_S',
                5: 'RST_WE_S',
                6: 'RST_H_S',
                7: 'NULL_WE_S',
                8: 'NULL_H_S',
                9: 'DATA_WE_S',
                10: 'DATA_H_S',
                11: 'DATA_S',
                12: 'DATA_SENT_S',
                13: 'RESEND_INIT_S',
                14: 'RESEND_H_S',
                15: 'RESEND_DATA_S',
                16: 'RESEND_PP_S',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxAppState',
            description  = 'TX Application FSM state',
            offset       = 0x6C,
            bitSize      = 4,
            bitOffset    = 8,
            mode         = 'RO',
            pollInterval = 1,
            enum         = {
                0: 'IDLE_S',
                1: 'WAIT_SOF_S',
                2: 'SEG_RCV_S',
                3: 'SEG_RDY_S',
                4: 'SEG_LEN_ERR',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxAckState',
            description  = 'TX Acknowledge FSM state',
            offset       = 0x6C,
            bitSize      = 4,
            bitOffset    = 12,
            mode         = 'RO',
            pollInterval = 1,
            enum         = {
                0: 'IDLE_S',
                1: 'ACK_S',
                2: 'EACK_S',
                3: 'ERR_S',
                4: 'UNDEFINED',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxTspState',
            description  = 'RX Transport FSM state',
            offset       = 0x6C,
            bitSize      = 4,
            bitOffset    = 16,
            mode         = 'RO',
            pollInterval = 1,
            enum         = {
                0: 'WAIT_SOF_S',
                1: 'CHECK_S',
                2: 'SYN_CHECK_S',
                3: 'DATA_S',
                4: 'VALID_S',
                5: 'DROP_S',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxAppState',
            description  = 'RX Application FSM state',
            offset       = 0x6C,
            bitSize      = 4,
            bitOffset    = 20,
            mode         = 'RO',
            pollInterval = 1,
            enum         = {
                0: 'CHECK_BUFFER_S',
                1: 'DATA_S',
                2: 'SENT_S',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'ConnState',
            description  = 'Connection FSM state',
            offset       = 0x6C,
            bitSize      = 4,
            bitOffset    = 24,
            mode         = 'RO',
            pollInterval = 1,
            enum         = {
                0: 'CLOSED_S',
                1: 'SEND_SYN_S',
                2: 'WAIT_SYN_S',
                3: 'SEND_ACK_S',
                4: 'LISTEN_S',
                5: 'SEND_SYN_ACK_S',
                6: 'WAIT_ACK_S',
                7: 'OPEN_S',
                8: 'SEND_RST_S',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxLastAckN',
            description  = 'Last acknowledged Sequence number connected to TX module',
            offset       = 0x70,
            bitSize      = 8,
            bitOffset    = 0,
            mode         = 'RO',
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxSeqN',
            description  = 'Current received seqN',
            offset       = 0x70,
            bitSize      = 8,
            bitOffset    = 8,
            mode         = 'RO',
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxAckN',
            description  = 'Current received ackN',
            offset       = 0x70,
            bitSize      = 8,
            bitOffset    = 16,
            mode         = 'RO',
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxLastSeqN',
            description  = 'Last seqN received and sent to application (this is the ackN transmitted)',
            offset       = 0x70,
            bitSize      = 8,
            bitOffset    = 24,
            mode         = 'RO',
            disp         = '{:d}',
            pollInterval = 1,
        ))

        ##############################
        # Commands
        ##############################
        @self.command(name='C_OpenConn', description='Open connection request',)
        def C_OpenConn():
            self.CloseConn.set(0)
            self.OpenConn.set(1)

        @self.command(name='C_CloseConn', description='Close connection request',)
        def C_CloseConn():
            self.OpenConn.set(0)
            self.CloseConn.set(1)

        @self.command(name='C_RestartConn', description='Restart connection request',)
        def C_RestartConn():
            self.C_CloseConn()
            self.C_OpenConn()

        @self.command(name='C_InjectFault', description='Inject a single fault(for debug and test purposes only). Corrupts checksum during transmission',)
        def C_InjectFault():
            self.InjectFault.set(1)
            self.InjectFault.set(0)
