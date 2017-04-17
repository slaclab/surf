#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue _proms Module
#-----------------------------------------------------------------------------
# File       : _proms.py
# Created    : 2016-09-29
# Last update: 2016-09-29
#-----------------------------------------------------------------------------
# Description:
# PyRogue _proms Module
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
from contextlib import contextmanager
import collections
import numpy as np

McsEntry = collections.namedtuple('McsEntry', ['addr', 'data'])

class McsException(Exception):
    pass

def McsReader(filename, wordSize):

    def makeInt(a):
        return reduce(lambda x,y: x<<8+y, a)

    promBaseAddr = 0
    with open(filename, 'r') as f:
        for i, line in enumerate(f):
            if (i%10000)==0:
                print i

            line = line.strip()
            runSum = 0

            if line[0] != ':':
                raise McsException('McsReader.next(): Missing start code. Line: \n\t{:s}'.format(line))

            else:
                strings = [line[i:i+2] for i in xrange(1, len(line), 2)]
                bytes = [int(s, 16) for s in strings]

                s = reduce(lambda x,y: x+y, bytes[:-1]) & 0xFF
                c = (bytes[-1]*-1) & 0xFF
                if s != c:
                    raise McsException("Bad checksum on line: {:s}. Sum: {:x}, checksum: {:x}".format(line, s, c))

                # Parse out the record
                # Byte count
                byteCount = bytes[0]
                addr = makeInt(bytes[1:3])
                recordType = bytes[3]

                if byteCount > 16:
                    raise McsException('McsRead.next(): Invalid byte count: {:d}'.format(byteCount))

                if recordType == 0:
                    # Data Record
                    if byteCount == 0:
                        raise McsException('McsRead.next(): Invalid byte count: {:d} for recordType: {d}'.format(byteCount, recordType))

                    data = (makeInt(bytes[i:i+wordSize]) for i in xrange(4, len(bytes), wordSize))

                    for i, d in enumerate(data):
                        yield McsEntry(promBaseAddr + addr + (i*wordSize), d)

                elif recordType == 1:
                    # EOF Record
                    # do checksum
                    raise StopIteration

                elif recordType == 4:
                    #Extended Linear Address Record
                    if byteCount != 2:
                        raise McsException("Byte count: {:d} must be 2 for ELA records".format(byteCount))

                    elif addr != 0:
                        raise McsException("Addr: {:x} must be 0 for ELA records".format(addr))

                    promBaseAddr = int(strings[4]+strings[5], 16)* (2**16)
                        
def McsProperties(filename):
    startAddr = 0
    endAddr = 0
    for i,r in enumerate(McsReader(filename, 16)):
        if i == 0:
            startAddr = r.addr
        endAddr = r.addr
    return (startAddr, endAddr, endAddr-startAddr)
    
#     def startAddr(self):
#         return iter(self).next().addr

#     def endAddr(self):
#         rec = None
#         for i in self:
#             rec = i;
#         return rec.addr

#     def addrSize(self):
#         return self.endAddr()-self.startAddr()
                                   


class AxiMicronN25Q(pr.Device):
    def __init__(self, **kwargs):
        super(self.__class__, self).__init__(description='Micron N25Q PROM Programming Firmware', **kwargs)

        self.add(pr.Variable(name='Test', offset=0x00, mode='RW', base='hex'))
        self.add(pr.Variable(name='Addr32Bit', offset=0x04, mode='RW', base=bool, hidden=True))
        self.add(pr.Variable(name='Addr', offset=0x08, mode='RW', base='hex', hidden=True))
        self.add(pr.Variable(name='Cmd', offset=0x0C, mode='RW', base='hex', hidden=True))

        for i in xrange(64):
            self.add(pr.Variable(name='Data[{:d}]'.format(i),
                                 offset=((0x80+i)*4), mode='RW', base='hex', hidden=True))

        self._promSize = 0
        self._promStartAddr = 0
        self._filePath = ''
        self._addr32BitMode = False
        self._addrShift = 16

        # Write commands need to run the WRITE_ENABLE command first
        self.__commands = {
            # RESET Operations
            'RESET_ENABLE': {"code": 0x66, 'write': True, 'reqEn': False},
            'RESET_MEMORY': {'code': 0x99, 'write': True, 'reqEn': False},
            # IDENTIFICATION Operations
            'READ_ID': {'code': 0x9F, 'write': False, 'reqEn': False,
                        'subcmds': {'ManufacturerId': 0x1, 'ManufacturerType': 0x2, 'ManufacturerCapacity': 0x3}},
            # READ Operations
            'READ_3BYTE': {'code': 0x03, 'write': False, 'reqEn': False},
            'READ_4BYTE': {'code': 0x13, 'write': False, 'reqEn': False},
            # Write Operations
            'WRITE_ENABLE': {'code': 0x06, 'write': True, 'reqEn': False},
            'WRITE_DISABLE': {'code': 0x04, 'write': True, 'reqEn': False},
            # Register Operations
            'READ_STATUS_REGISTER': {'code': 0x05, 'write': False, 'reqEn': False},            
            'WRITE_STATUS_REGISTER': {'code': 0x01, 'write': True, 'reqEn': True},
            'READ_FLAG_STATUS_REGISTER': {'code': 0x70, 'write': , 'reqEn': False,
                                          'subcmds': {'busy': 0x1}},
            'READ_NV_CONFIG_REGISTER': {'code': 0xB5, 'write': False, 'reqEn': False},
            'WRITE_NV_CONFIG_REGISTER': {'code': 0xB1, 'write': True, 'reqEn': True},
            'READ_VOL_CONFIG_REGISTER': {'code': 0x85, 'write': False, 'reqEn': False},
            'WRITE_VOL_CONFIG_REGISTER': {'code': 0x81, 'write': True, 'reqEn': True},
            # Program Operations
            'PAGE_PROGRAM_3BYTE': {'code': 0x02, 'write': True, 'reqEn': True},            
            'PAGE_PROGRAM_4BYTE': {'code': 0x12, 'write': True, 'reqEn': True},
            # Erase Operations
            'SUBSECTOR_ERASE': {'code': 0x20, 'write': True, 'reqEn': True},
            'SECTOR_ERASE': {'code': 0xD8, 'write': True, 'reqEn': True}}

    def _sendCmd(self, cmd, subcmd=''):
        cmdParams = self.__commands[cmd]
        if (cmdParams['reqEn']):
            self.sendCmd('WRITE_ENABLE')
        value = cmdParams['write'] & 0x80000000 # Write mask
        value = value | (cmdParams['code'] << 16) # Cmd code
        value = value | (cmdParams['subcmd'][subcmd]) # Subcommand
        self.Cmd.set(value)

    def _readCmd(self, cmd, subcmd=''):
        self.sendCmd(cmd, subcmd)
        return self.Cmd.get()
   
    def _waitForFlashReady(self):
        while((self._readCmd('READ_FLAG_STATUS_REGISTER', 'busy') & 0x80) == 0):
            pass

    def setAddr32BitMode(self, en):
        self._addr32BitMode = en
        self._addrShift = 16 + (en*8)
        if en:
            self._sendCmd('ADDR_ENTER')
        else:
            self._sendCmd('ADDR_EXIT')
        self.Addr32Bit.set(en)

    def _sendAddr(self, addr):
        self.Addr.set((addr&0xFF)<<self._addrShift)

    def _eraseCmd(self, address):
        sendAddr(address)
        sendCmd('SECTOR_ERASE', self._addr32BitMode)

        
    def setPromStatusReg(self, value):
        self.Addr.set((value&0xFF)<<self._addrShift)
        self.setCmd(WRITE_MASK|STATUS_REG_WR_CMD|0x1)
        self.waitForFlashReady()

    def getPromStatusReg(self):
        self.waitForFlashReady()
        self.Cmd.set(READ_MASK|STATUS_REG_RD_CMD|0x1)
        return self.Cmd.get()
            

     @property
    def filePath(self):
        return self._filePath

    @filePath.setter
    def filePath(self, fp):
        self._filePath = fp;
        self._startAddr, _, self._promSize = McsProperties(fp)


    def eraseProm(self):
        address = self._promStartAddr
        size = self._promSize * 1.0
        percentage = 0.0
        skim = 5.0

        print "************************************************"
        print "Starting Erase ..."

        while (address < (self._promStartAddr+self._promSize)):
            self.eraseCommand(address)
            address += ERASE_SIZE
