import pyrogue as pr
from contextlib import contextmanager
import collections
import numpy as np

McsEntry = collections.namedtuple('McsEntry', ['addr', 'data'])

class McsException(Exception):
    pass

class McsReader(object):

    def __init__(self, filePath):
        
        self._filePath = filePath

    def __iter__(self):
        # Initialize the generator and return it
        return self.next()

    def __enter__(self):
        return self

    def __exit__(self, type, value, trackeback):
        return False

    def next(self):

        promBaseAddr = 0

        with open(self._filePath, 'r') as f:
            self._file = f
            for i, line in enumerate(f):
                if (i%100)==0:
                    print i
                    
                line = line.strip()
                runSum = np.uint8(0)

                if line[0] != ':':
                    raise McsException('McsReader.next(): Missing start code. Line: \n\t{:s}'.format(line))

                else:
                    strings = [line[i:i+2] for i in xrange(1, len(line), 2)]
                    bytes = [np.uint8(int(s, 16)) for s in strings]

                    s = reduce(lambda x,y: np.uint8(x+y), bytes[:-1])
                    c = np.uint8(-1*bytes[-1])
                    if s != c:
                        raise McsException("Bad checksum on line: {:s}".format(line))

                    # Parse out the record
                    # Byte count
                    byteCount = bytes[0]
                    addr = int(strings[1]+strings[2], 16)
                    recordType = bytes[3]

                    if byteCount > 16:
                        raise McsException('McsRead.next(): Invalid byte count: {:d}'.format(byteCount))

                    if recordType == 0:
                        # Data Record
                        if byteCount == 0:
                            raise McsException('McsRead.next(): Invalid byte count: {:d} for recordType: {d}'.format(byteCount, recordType))

                        data = bytes[4:-1]

                        for i, d in enumerate(data):
                            yield McsEntry(promBaseAddr + addr + i, d)

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

                        promBaseAddr = int(strings[5]+strings[4], 16)
                        
                            
    def startAddr(self):
        return iter(self).next().addr

    def endAddr(self):
        rec = None
        for i in self:
            rec = i;
        return rec.addr

    def addrSize(self):
        return self.endAddr()-self.startAddr()
                                   


class AxiMicronN25Q(pr.Device):
    def __init__(self, **kwargs):
        super(self.__class__, self).__init__(description='Micron N25Q PROM Programming Firmware', **kwargs)

        self.add(pr.Variable(name='Test', offset=0x00, mode='RW', base='hex'))
        self.add(pr.Variable(name='Addr32Bit', offset=0x04, mode='RW', base='hex', hidden=True))
        self.add(pr.Variable(name='Addr', offset=0x08, mode='RW', base='hex', hidden=True))
        self.add(pr.Variable(name='Cmd', offset=0x0C, mode='RW', base='hex', hidden=True))

        for i in xrange(64):
            self.add(pr.Variable(name='Data[{:d}]'.format(i),
                                 offset=((0x80+i)*4), mode='RW', base='hex', hidden=True))

        self.promSize = 0
        self._promStartAddr = 0
        self._filePath = ''
        self._addr32BitMode = False


        
