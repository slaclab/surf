#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device RssiCore
#-----------------------------------------------------------------------------
# File       : RssiCore.py
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for RssiCore
# Auto created from ../surf/protocols/rssi/yaml/RssiCore.yaml
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the 
# top-level directory of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of 'SLAC Firmware Standard Library', including this file, 
# may be copied, modified, propagated, or distributed except according to 
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class Rssi(pr.Device):
    def __init__(self, name="Rssi", memBase=None, offset=0, hidden=False):
        super(self.__class__, self).__init__(name, "RSSI module",
                                             memBase, offset, hidden)
                                             
        self.add(pr.Variable(name='openConn',
                description='Open Connection Request (Server goes to listen state, Client actively requests the connection by sending SYN segment)',
                hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=0, base='hex', mode='RW'))

        self.add(pr.Variable(name='closeConn',
                description='Close Connection Request (Send a RST Segment to peer and close the connection)',
                hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=1, base='hex', mode='RW'))

        self.add(pr.Variable(name='mode',
                description='Mode:\'0\': Use internal parameters from generics,\'1\': Use parameters from registers',
                hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=2, base='hex', mode='RW'))

        self.add(pr.Variable(name='headerChksumEn',
                description='Header checksum: \'1\': Enable calculation and check, \'0\': Disable check and insert 0 in place of header checksum',
                hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=3, base='hex', mode='RW'))

        self.add(pr.Variable(name='injectFault',
                description='Inject fault to the next packet header checksum (Default \'0\'). Acts on rising edge - injects exactly one fault in next segment',
                hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=4, base='hex', mode='RW'))

        self.add(pr.Variable(name='initSeqN',
                description='Initial sequence number [7:0]',
                hidden=False, enum=None, offset=0x4, bitSize=8, bitOffset=0, base='hex', mode='RW'))

        self.add(pr.Variable(name='version',
                description='Version register [3:0]',
                hidden=False, enum=None, offset=0x8, bitSize=4, bitOffset=0, base='hex', mode='RW'))

        self.add(pr.Variable(name='maxOutsSeg',
                description='Maximum out standing segments [7:0]',
                hidden=False, enum=None, offset=0xc, bitSize=8, bitOffset=0, base='hex', mode='RW'))

        self.add(pr.Variable(name='maxSegSize',
                description='Maximum segment size [15:0]',
                hidden=False, enum=None, offset=0x10, bitSize=16, bitOffset=0, base='hex', mode='RW'))

        self.add(pr.Variable(name='retransTimeout',
                description='Retransmission timeout [15:0]',
                hidden=False, enum=None, offset=0x14, bitSize=16, bitOffset=0, base='hex', mode='RW'))

        self.add(pr.Variable(name='cumAckTimeout',
                description='Cumulative acknowledgment timeout [15:0]',
                hidden=False, enum=None, offset=0x18, bitSize=16, bitOffset=0, base='hex', mode='RW'))

        self.add(pr.Variable(name='nullSegTimeout',
                description='Null segment timeout [15:0]',
                hidden=False, enum=None, offset=0x1c, bitSize=16, bitOffset=0, base='hex', mode='RW'))

        self.add(pr.Variable(name='maxNumRetrans',
                description='Maximum number of retransmissions [7:0]',
                hidden=False, enum=None, offset=0x20, bitSize=8, bitOffset=0, base='hex', mode='RW'))

        self.add(pr.Variable(name='maxCumAck',
                description='Maximum cumulative acknowledgments [7:0]',
                hidden=False, enum=None, offset=0x24, bitSize=8, bitOffset=0, base='hex', mode='RW'))

        self.add(pr.Variable(name='maxOutOfSeq',
                description='Max out of sequence segments (EACK) [7:0]',
                hidden=False, enum=None, offset=0x28, bitSize=8, bitOffset=0, base='hex', mode='RW'))

        self.add(pr.Variable(name='connectionActive',
                description='Connection Active',
                hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=0, base='hex', mode='RO'))

        self.add(pr.Variable(name='errMaxRetrans',
                description='Maximum retransmissions exceeded retransMax.',
                hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=1, base='hex', mode='RO'))

        self.add(pr.Variable(name='errNullTout',
                description='Null timeout reached (server) nullTout.',
                hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=2, base='hex', mode='RO'))

        self.add(pr.Variable(name='errAck',
                description='Error in acknowledgment mechanism.',
                hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=3, base='hex', mode='RO'))

        self.add(pr.Variable(name='errSsiFrameLen',
                description='SSI Frame length too long',
                hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=4, base='hex', mode='RO'))

        self.add(pr.Variable(name='errConnTout',
                description='Connection to peer timed out. Timeout defined in generic PEER_CONN_TIMEOUT_G (Default: 1000 ms)',
                hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=5, base='hex', mode='RO'))

        self.add(pr.Variable(name='paramRejected',
                description='Client rejected the connection (parameters out of range), Server proposed new parameters (parameters out of range)',
                hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=6, base='hex', mode='RO'))

        self.add(pr.Variable(name='validCnt',
                description='Number of valid segments [31:0]',
                hidden=False, enum=None, offset=0x44, bitSize=32, bitOffset=0, base='hex', mode='RO'))

        self.add(pr.Variable(name='dropCnt',
                description='Number of dropped segments [31:0]',
                hidden=False, enum=None, offset=0x48, bitSize=32, bitOffset=0, base='hex', mode='RO'))

        self.add(pr.Variable(name='retransmitCnt',
                description='Counts all retransmission requests within the active connection [31:0]',
                hidden=False, enum=None, offset=0x4c, bitSize=32, bitOffset=0, base='hex', mode='RO'))

        self.add(pr.Variable(name='reconnectCnt',
                description='Counts all reconnections from reset [31:0]',
                hidden=False, enum=None, offset=0x50, bitSize=32, bitOffset=0, base='uint', mode='RO'))

        self.add(pr.Variable(name='frameRate_0',
                description='Frame Rate (in units of Hz)',
                hidden=False, enum=None, offset=0x54, bitSize=32, bitOffset=0, base='uint', mode='RO'))

        self.add(pr.Variable(name='frameRate_1',
                description='Frame Rate (in units of Hz)',
                hidden=False, enum=None, offset=0x58, bitSize=32, bitOffset=0, base='uint', mode='RO'))

        self.add(pr.Variable(name='bandwidth_0',
                description='Bandwidth (in units of bytes per second)',
                hidden=False, enum=None, offset=0x5c, bitSize=64, bitOffset=0, base='uint', mode='RO'))

        self.add(pr.Variable(name='bandwidth_1',
                description='Bandwidth (in units of bytes per second)',
                hidden=False, enum=None, offset=0x64, bitSize=64, bitOffset=0, base='uint', mode='RO'))

        self.add(pr.Command(name='c_OpenConn',
                description='Open connection request',
                hidden=False, base='None',
                function="""\
                        dev.openConn.set(1)
                        dev.openConn.set(0)
                        """))

        self.add(pr.Command(name='c_CloseConn',
                description='Close connection request',
                hidden=False, base='None',
                function="""\
                        dev.closeConn.set(1)
                        dev.closeConn.set(0)
                        """))

        self.add(pr.Command(name='c_InjectFault',
                description='Inject a single fault(for debug and test purposes only). Corrupts checksum during transmission',
                hidden=False, base='None',
                function="""\
                        dev.injectFault.set(1)
                        dev.injectFault.set(0)
                        """))
