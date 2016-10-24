#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device RssiCore
#-----------------------------------------------------------------------------
# File       : RssiCore.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-10-24
# Last update: 2016-10-24
#-----------------------------------------------------------------------------
# Description:
# Device creator for RssiCore
# Auto created from ../surf/protocols/rssi/yaml/RssiCore.yaml
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the rogue software platform, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue

def create(name, offset, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x100,
                         description='RSSI module')

    dev.add(pyrogue.Variable(name='OpenConn',
                             description='Open Connection Request (Server goes to listen state, Client actively requests the connection by sending SYN segment)',
                             hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CloseConn',
                             description='Close Connection Request (Send a RST Segment to peer and close the connection)',
                             hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Mode',
                             description='Mode:'0': Use internal parameters from generics,'1': Use parameters from registers',
                             hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='HeaderChksumEn',
                             description='Header checksum: '1': Enable calculation and check, '0': Disable check and insert 0 in place of header checksum',
                             hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='InjectFault',
                             description='Inject fault to the next packet header checksum (Default '0'). Acts on rising edge - injects exactly one fault in next segment',
                             hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='InitSeqN',
                             description='Initial sequence number [7:0]',
                             hidden=False, enum=None, offset=0x4, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Version',
                             description='Version register [3:0]',
                             hidden=False, enum=None, offset=0x8, bitSize=4, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='MaxOutsSeg',
                             description='Maximum out standing segments [7:0]',
                             hidden=False, enum=None, offset=0xc, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='MaxSegSize',
                             description='Maximum segment size [15:0]',
                             hidden=False, enum=None, offset=0x10, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RetransTimeout',
                             description='Retransmission timeout [15:0]',
                             hidden=False, enum=None, offset=0x14, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CumAckTimeout',
                             description='Cumulative acknowledgment timeout [15:0]',
                             hidden=False, enum=None, offset=0x18, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='NullSegTimeout',
                             description='Null segment timeout [15:0]',
                             hidden=False, enum=None, offset=0x1c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='MaxNumRetrans',
                             description='Maximum number of retransmissions [7:0]',
                             hidden=False, enum=None, offset=0x20, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='MaxCumAck',
                             description='Maximum cumulative acknowledgments [7:0]',
                             hidden=False, enum=None, offset=0x24, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='MaxOutOfSeq',
                             description='Max out of sequence segments (EACK) [7:0]',
                             hidden=False, enum=None, offset=0x28, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ConnectionActive',
                             description='Connection Active',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ErrMaxRetrans',
                             description='Maximum retransmissions exceeded retransMax.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ErrNullTout',
                             description='Null timeout reached (server) nullTout.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ErrAck',
                             description='Error in acknowledgment mechanism.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ErrSsiFrameLen',
                             description='SSI Frame length too long',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ErrConnTout',
                             description='Connection to peer timed out. Timeout defined in generic PEER_CONN_TIMEOUT_G (Default: 1000 ms)',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=5, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ParamRejected',
                             description='Client rejected the connection (parameters out of range), Server proposed new parameters (parameters out of range)',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ValidCnt',
                             description='Number of valid segments [31:0]',
                             hidden=False, enum=None, offset=0x44, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='DropCnt',
                             description='Number of dropped segments [31:0]',
                             hidden=False, enum=None, offset=0x48, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RetransmitCnt',
                             description='Counts all retransmission requests within the active connection [31:0]',
                             hidden=False, enum=None, offset=0x4c, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ReconnectCnt',
                             description='Counts all reconnections from reset [31:0]',
                             hidden=False, enum=None, offset=0x50, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='FrameRate_0',
                             description='Frame Rate (in units of Hz)',
                             hidden=False, enum=None, offset=0x54, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='FrameRate_1',
                             description='Frame Rate (in units of Hz)',
                             hidden=False, enum=None, offset=0x58, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Bandwidth_0',
                             description='Bandwidth (in units of bytes per second)',
                             hidden=False, enum=None, offset=0x5c, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Bandwidth_1',
                             description='Bandwidth (in units of bytes per second)',
                             hidden=False, enum=None, offset=0x64, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Command(name='C_OpenConn',
                            description='Open connection request',
                            hidden=False, base=None,
                            function="""\
                                     dev.OpenConn.set(1)
                                     dev.OpenConn.set(0)
                                     """

    dev.add(pyrogue.Command(name='C_CloseConn',
                            description='Close connection request',
                            hidden=False, base=None,
                            function="""\
                                     dev.CloseConn.set(1)
                                     dev.CloseConn.set(0)
                                     """

    dev.add(pyrogue.Command(name='C_InjectFault',
                            description='Inject a single fault(for debug and test purposes only). Corrupts checksum during transmission',
                            hidden=False, base=None,
                            function="""\
                                     dev.InjectFault.set(1)
                                     dev.InjectFault.set(0)
                                     """

