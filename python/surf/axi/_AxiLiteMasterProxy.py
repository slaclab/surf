import pyrogue as pr
import rogue

import threading

class AxiLiteMasterProxy(pr.Device):

    def __init__(self, **kwargs):

        super().__init__(size=4 hubMin=4, hubMax=4, **kwargs)

        self._dataBa = bytearray(4)

        self.add(pr.RemoteVariable(
            name = 'Rnw',
            offset = 0x00,
            bitOffset = 0,
            bitSize = 1,
            base = pr.UInt,
            enum = {
                0: "Write",
                1: "Read"}))

        self.add(pr.RemoteVariable(
            name = 'Done',
            offset = 0x04,
            bitOffset = 0,
            bitSize = 1
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            name = 'Resp',
            offset 0x04,
            bitOffset = 1,
            bitSize = 2,
            base = pr.UInt,
            enum = {
                0 : 'OK',
                1 : 'EXOK',
                2 : 'SLVERR',
                3 : 'DECERR'}))

        self.add(pr.RemoteVariable(
            name = 'Addr',
            offset = 0x08,
            bitOffset = 0,
            bitSize = 32,
            base = pr.UInt))

        self.add(pr.RemoteVariable(
            name = 'Data',
            offset = 0x0C,
            bitOffset = 0,
            bitSize = 32,
            base = pr.UInt))

    def _doTransaction(self, transaction):
        with self._memLock, transaction.lock():
            # Clear any existing errors
            self._setError(0)

            # Get the transaction address and write it to the proxy address register
            addr = transaction.address()
            self.Addr.set(addr, write=True)

            if transation.type() == rogue.interfaces.memory.Write:
                # Convert data bytes to int and write data to proxy register
                transaction.getData(self._dataBa, 0)
                data = int.from_bytes(self._dataBa, 'little', signed=False)
                self.Data.set(data, write=True)

                # Kick off the proxy transaction
                self.Rnw.setDisp('Write', write=True)

            elif transaction.type() == rogue.interfaces.memory.Read or
                 transaction.type() == rogue.interfaces.memory.Verify:

                 # Kick off the read proxy txn
                 self.Rnw.setDisp('Read', write=True)

            else:
                # Post transactions not allowed
                transaction.error(f'Unsupported transaction type {transaction.type()}')
                return

            # Poll done register
            # Probably need some timeout here
            done = False
            while done is False:
                done = self.Done.get(read=True)
                time.sleep(.1)

            # Check for error flags
            resp = self.Resp.get(read=True)
            if resp != 0:
                tran.error(f'AXIL tranaction failed with RESP: {resp}')
                return

            # Finish the transaction
            if self.Rnw.valueDisp() == 'Write':
                tran.done()
            else:
                data = self.Data.get(read=True)
                self._dataBa = data.toBytes(4, 'little', signed=False)
                tran.setData(self._dataBa, 0)
                tran.done()


                
