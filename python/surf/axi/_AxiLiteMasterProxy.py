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
import rogue

import threading
import time
import queue

class _Regs(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self._queue = queue.Queue()
        self._pollThread = threading.Thread(target=self._pollWorker)
        self._pollThread.start()

        self.add(pr.RemoteVariable(
            name      = 'Rnw',
            offset    = 0x00,
            bitOffset = 0,
            bitSize   = 1,
            enum      = {
                0: "Write",
                1: "Read",
            },
        ))

        self.add(pr.RemoteVariable(
            name      = 'Done',
            mode      = 'RO',
            offset    = 0x04,
            bitOffset = 0,
            bitSize   = 1,
            base      = pr.Bool,
        ))

        self.add(pr.RemoteVariable(
            name      = 'Resp',
            offset    = 0x04,
            bitOffset = 1,
            bitSize   = 2,
            enum      = {
                0 : 'OK',
                1 : 'EXOK',
                2 : 'SLVERR',
                3 : 'DECERR',
            },
        ))

        self.add(pr.RemoteVariable(
            name      = 'Addr',
            offset    = 0x08,
            bitOffset = 0,
            bitSize   = 32,
        ))

        self.add(pr.RemoteVariable(
            name      = 'Data',
            offset    = 0x0C,
            bitOffset = 0,
            bitSize   = 32,
        ))

    def proxyTransaction(self, transaction):
        self._queue.put(transaction)

    def _pollWorker(self):
        while True:
            #print('Main thread loop start')
            transaction = self._queue.get()
            with self._memLock, transaction.lock():
                #tranId = transaction.id()
                #print(f'Woke the pollWorker with id: {tranId}')

                # Get the transaction address and write it to the proxy address register
                addr = transaction.address()
                #print('Writing address')
                self.Addr.set(addr, write=True)
                #print(f'Wrote address {addr:x}')

                if transaction.type() == rogue.interfaces.memory.Write:
                    # Convert data bytes to int and write data to proxy register
                    transaction.getData(self._dataBa, 0)
                    data = int.from_bytes(self._dataBa, 'little', signed=False)
                    self.Data.set(data, write=True)
                    #print(f'Wrote data {data:x}')

                    # Kick off the proxy transaction
                    self.Rnw.setDisp('Write', write=True)
                    #print(f'Started write transaction: {tranId}')

                elif (transaction.type() == rogue.interfaces.memory.Read) or (transaction.type() == rogue.interfaces.memory.Verify):

                    # Kick off the read proxy txn
                    self.Rnw.setDisp('Read', write=True)
                    #print(f'Started read transaction: {tranId}')

                else:
                    # Post transactions not allowed
                    transaction.error(f'Unsupported transaction type {transaction.type()}')
                    return

                # Poll done register
                # Probably need some timeout here
                done = False
                while done is False:
                    done = self.Done.get(read=True)
                    #print(f'Polled done: {done}')
                    time.sleep(.1)

                # Check for error flags
                resp = self.Resp.get(read=True)
                #print(f'Resp: {resp}')
                if resp != 0:
                    transaction.error(f'AXIL tranaction failed with RESP: {resp}')

                # Finish the transaction
                elif self.Rnw.valueDisp() == 'Write':
                    transaction.done()
                else:
                    data = self.Data.get(read=True)
                    #print(f'Got read data: {data:x}')
                    dataBa = bytearray(data.to_bytes(4, 'little', signed=False))
                    #print(dataBa)
                    transaction.setData(dataBa, 0)
                    transaction.done()

class _ProxySlave(rogue.interfaces.memory.Slave):

    def __init__(self, regs):
        super().__init__(4,4)
        self._regs = regs

    def _doTransaction(self, transaction):
        #print('_ProxySlave._doTransaction')
        self._regs.proxyTransaction(transaction)

class AxiLiteMasterProxy(pr.Device):

    def __init__(self, hidden=True,**kwargs):
        super().__init__(hidden=hidden,**kwargs)

        self.add(_Regs(
            name    = 'Regs',
            memBase = self,
            offset  = 0x0000,
            hidden  = hidden,
        ))
        self.proxy = _ProxySlave(self.Regs)

    def add(self, node):
        pr.Node.add(self, node)

        if isinstance(node, pr.Device):
            if node._memBase is None:
                node._setSlave(self.proxy)
