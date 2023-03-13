#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
# Based on Xilinx/embeddedsw driver:
# https://github.com/Xilinx/embeddedsw/blob/master/XilinxProcessorIPLib/drivers/spips/src/xspips.c
# https://www.xilinx.com/htmldocs/registers/ug1087/ug1087-zynq-ultrascale-registers.html#mod___spi.html
# https://www.realdigital.org/doc/d1083e371f94b28e8868a69f17251767
#-----------------------------------------------------------------------------
# Must disable the Linux SPI driver in the device tree for this to work.
# Example:
# &spi0 {
# 	status = "disabled";
# };
#-----------------------------------------------------------------------------
# Virtual Address Decoding:
#   ADDR[50:48] = SPI Device Index
#   ADDR[46:44] = SPI Address Bytes
#   ADDR[43:40] = SPI Data Bytes
#   ADDR[33:02] = SPI Address available
#   ADDR[01:00] = Unused (32-bit word alignment)
#-----------------------------------------------------------------------------

import pyrogue as pr
import rogue

import threading
import time
import queue

class _Regs(pr.Device):
    def __init__(self,
            pollPeriod = 0.0,
            **kwargs):
        super().__init__(**kwargs)

        self._pollPeriod = pollPeriod

        self._queue = queue.Queue()
        self._pollThread = threading.Thread(target=self._pollWorker)
        self._pollThread.start()

        ####################################################################

        self.add(pr.RemoteVariable(
            name        = 'Modefail_gen_en',
            description = 'ModeFail Generation Enable: Change only when controller is not actively transmitting or receiving data.',
            offset      = 0x00,
            bitOffset   = 17,
            bitSize     = 1,
            mode        = 'RW',
            enum        = {
                0: "disable",
                1: "enable",
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'Man_start_en',
            description = 'Manual Start Enable: Change only when controller is not actively transmitting or receiving data.',
            offset      = 0x00,
            bitOffset   = 15,
            bitSize     = 1,
            mode        = 'RW',
            enum        = {
                0: "auto mode",
                1: "enables manual start",
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'Manual_CS',
            description = 'Manual CS: Change only when controller is not actively transmitting or receiving data.',
            offset      = 0x00,
            bitOffset   = 14,
            bitSize     = 1,
            mode        = 'RW',
            enum        = {
                0: "auto mode",
                1: "manual CS mode",
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'CS',
            description  = """
                Peripheral chip select lines.
                xxx0: slave 0 selected
                xx01: slave 1 selected
                x011: slave 2 selected
                0111: reserved
                1111: No slave selected
                Change only when controller is not actively transmitting or receiving data. """,
            offset      = 0x00,
            bitOffset   = 10,
            bitSize     = 4,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'PERI_SEL',
            description = 'Peripheral select decode: Change only when controller is not actively transmitting or receiving data.',
            offset      = 0x00,
            bitOffset   = 9,
            bitSize     = 1,
            mode        = 'RW',
            enum        = {
                0: "only 1 of 3 selects",
                1: "allow external 3-to-8 decode",
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'REF_CLK',
            description = 'Master reference clock select',
            offset      = 0x00,
            bitOffset   = 8,
            bitSize     = 1,
            mode        = 'RW',
            enum        = {
                0: "use SPI REFERENCE CLOCK",
                1: "not supported",
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'BAUD_RATE_DIV',
            description = 'Master mode baud rate divisor controls the amount the SPI_REF_CLK is divided for the controller. Change only when controller is not actively transmitting or receiving data.',
            offset      = 0x00,
            bitOffset   = 3,
            bitSize     = 3,
            mode        = 'RW',
            enum        = {
                0: "reserved",
                1: "div4",
                2: "div8",
                3: "div16",
                4: "div32",
                5: "div64",
                6: "div128",
                7: "div256",
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'CLK_PH',
            description = 'Clock phase: Change only when controller is not actively transmitting or receiving data.',
            offset      = 0x00,
            bitOffset   = 2,
            bitSize     = 1,
            mode        = 'RW',
            enum        = {
                0: "active_outside_the_word",
                1: "inactive_outside_the_word",
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'CLK_POL',
            description = 'Clock polarity outside SPI word: Change only when controller is not actively transmitting or receiving data.',
            offset      = 0x00,
            bitOffset   = 1,
            bitSize     = 1,
            mode        = 'RW',
            enum        = {
                0: "quiescent_low",
                1: "quiescent_high",
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'MODE_SEL',
            description = 'Mode select: Change only when controller is not actively transmitting or receiving data.',
            offset      = 0x00,
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RW',
            enum        = {
                0: "slave",
                1: "master",
            },
        ))

        ####################################################################

        self.add(pr.RemoteVariable(
            name        = 'SR',
            offset      = 0x04,
            bitSize     = 7,
            mode        = 'RW',
            verify      = False, # Readable, write 1 to clear
        ))

        self.add(pr.LinkVariable(
            name         = 'TX_FIFO_underflow',
            linkedGet    = lambda: 'True' if (self.SR.value()>>6)&0x1==1 else 'False',
            mode         = 'RO',
            dependencies = [self.SR],
        ))

        self.add(pr.LinkVariable(
            name         = 'RX_FIFO_full',
            linkedGet    = lambda: 'True' if (self.SR.value()>>5)&0x1==1 else 'False',
            mode         = 'RO',
            dependencies = [self.SR],
        ))

        self.add(pr.LinkVariable(
            name         = 'RX_FIFO_not_empty',
            linkedGet    = lambda: 'True' if (self.SR.value()>>4)&0x1==1 else 'False',
            mode         = 'RO',
            dependencies = [self.SR],
        ))

        self.add(pr.LinkVariable(
            name         = 'TX_FIFO_full',
            linkedGet    = lambda: 'True' if (self.SR.value()>>3)&0x1==1 else 'False',
            mode         = 'RO',
            dependencies = [self.SR],
        ))

        self.add(pr.LinkVariable(
            name         = 'TX_FIFO_not_full',
            linkedGet    = lambda: 'True' if (self.SR.value()>>2)&0x1==1 else 'False',
            mode         = 'RO',
            dependencies = [self.SR],
        ))

        self.add(pr.LinkVariable(
            name         = 'MODE_FAIL',
            linkedGet    = lambda: 'True' if (self.SR.value()>>1)&0x1==1 else 'False',
            mode         = 'RO',
            dependencies = [self.SR],
        ))

        self.add(pr.LinkVariable(
            name         = 'RX_OVERFLOW',
            linkedGet    = lambda: 'True' if (self.SR.value()>>0)&0x1==1 else 'False',
            mode         = 'RO',
            dependencies = [self.SR],
        ))

        ####################################################################

        self.add(pr.RemoteVariable(
            name        = 'IER',
            offset      = 0x08,
            bitSize     = 7,
            mode        = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'IDR',
            offset      = 0x0C,
            bitSize     = 7,
            mode        = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'IMR',
            offset      = 0x10,
            bitSize     = 7,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ER',
            description = 'SPI_Enable: Change only when controller is not actively transmitting or receiving data.',
            offset      = 0x14,
            bitSize     = 1,
            mode        = 'RW',
            # base        = pr.Bool,
        ))

        self.add(pr.RemoteVariable(
            name        = 'DR',
            description = 'Delay Register',
            offset      = 0x18,
            bitSize     = 32,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TXD',
            description = 'Data written to TX FIFO. Valid data bits are [7:0]. Note: The value of N in the Tx FIFO word length minus 1. In default configuration FIFO word size is 8.',
            offset      = 0x1C,
            # bitSize     = 8,
            bitSize     = 32,
            mode        = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RXD',
            description = 'Data read from RX FIFO. Valid data bits are [7:0].',
            offset      = 0x20,
            bitSize     = 8,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SICR',
            description = 'Slave Idle Count',
            offset      = 0x24,
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TXWR',
            description = 'Transmit FIFO Watermark',
            offset      = 0x28,
            bitSize     = 7,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RXWR',
            description = 'Receive FIFO Watermark',
            offset      = 0x2C,
            bitSize     = 7,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'module_ID',
            description = 'Module ID number: 0x90108',
            offset      = 0xFC,
            bitSize     = 24,
            mode        = 'RO',
        ))

        ####################################################################
        @self.command()
        def TestLoad():
            byteSize = 3
            txBuffer  = [x&0xFF for x in range(byteSize)]
            txBuffer[0] |= 0x80
            self.Transfer(0,txBuffer,byteSize)

        ####################################################################
        @self.command()
        def ResetHw():
            # Refresh CR register
            self.Modefail_gen_en.get()

            # Disable all Interrupts
            self.IDR.set(0x7F)

            # Disable device
            self.ER.set(0)

            # Write default value to RX and TX threshold registers
            # RX threshold should be set to 1 here as the corresponding
            # status bit is used to clear the FIFO next
            self.TXWR.set(1)
            self.RXWR.set(1)

            # Clear RXFIFO and check if Rx FIFO Not Empty
            while( (self.SR.get(read=True) & 0x10) != 0): # Rx FIFO Not Empty = 0x10
                self.RXD.get(read=True)

            # Read all RXFIFO entries
            for i in range(128):
                self.RXD.get(read=True)

            # Clear status register by writing 1 to the write to clear bits
            self.SR.set(0x7F)
            self.SR.get()

            # Configure for master manual mode with auto CS
            self.Man_start_en.set(0)
            self.MODE_SEL.set(1)
            self.Manual_CS.set(0)
            self.CS.set(0)
            self.Modefail_gen_en.set(1)

            # Enable device
            self.ER.set(1)

    ####################################################################

    def Transfer(self, devIdx, txBuffer, byteSize):
        # Set the RX watermark
        if self.RXWR.value() != byteSize:
            self.RXWR.set(byteSize, verify=False)

        # Set CS
        if self.CS.value() != devIdx:
            self.CS.set(devIdx, verify=False)

        # Load the TX FIFO
        self.Man_start_en.set(1, verify=False)
        for i in range(byteSize):
            self.TXD.set(txBuffer[i], verify=False)

        # Start the transfer
        self.Manual_CS.set(1) # Force manual due to observed CS glitch in waveforms when AUTO CS
        self.Man_start_en.set(0, verify=False)

        # Wait for the buffer to fill out
        while( (self.SR.get(read=True) & 0x10) == 0): # Rx FIFO Not Empty = 0x10
            time.sleep(self._pollPeriod)

        # Read the RX FIFO
        self.Manual_CS.set(0) # release manual due to observed CS glitch in waveforms when AUTO CS
        rxBuffer = [None for x in range(byteSize)]
        for i in range(byteSize):
            rxBuffer[i] = self.RXD.get(read=True)

        # Return the RX buffer
        return rxBuffer

    ####################################################################

    def proxyTransaction(self, transaction):
        self._queue.put(transaction)

    def _pollWorker(self):
        while True:
            #print('Main thread loop start')
            transaction = self._queue.get()
            if transaction is None:
                return

            with self._memLock, transaction.lock():
                #tranId = transaction.id()
                #print(f'Woke the pollWorker with id: {tranId}')

                # Get the transaction virtual address
                virtualAddress = transaction.address()

                # Decode the  virtual address metadata
                devIdx    = (virtualAddress >> 48) & 0x7
                addrBytes = (virtualAddress >> 44) & 0x7
                dataBytes = (virtualAddress >> 40) & 0x7
                byteSize  = addrBytes + dataBytes
                txBuffer  = [0xFF for x in range(byteSize)]

                # Fill the address bytes
                for i in range(addrBytes):
                    txBuffer[i] = ( virtualAddress >> ( 8*(addrBytes-1-i) )+2 ) & 0xFF

                # Check for write transaction
                if transaction.type() == rogue.interfaces.memory.Write:
                    # Convert data bytes to int and write data to proxy register
                    dataBa = bytearray(4)
                    transaction.getData(dataBa, 0)
                    data = int.from_bytes(dataBa, 'little', signed=False)

                    # Fill the data bytes
                    for i in range(dataBytes):
                        txBuffer[i+addrBytes] = ( data >> ( 8*(dataBytes-1-i) ) ) & 0xFF

                    #print(f'Started write transaction: {tranId}')

                # Check for read or verify transaction
                elif (transaction.type() == rogue.interfaces.memory.Read) or (transaction.type() == rogue.interfaces.memory.Verify):

                    # Set the R/W bit
                    txBuffer[0] |= 0x80
                    #print(f'Started read transaction: {tranId}')

                else:
                    # Post transactions not allowed
                    transaction.error(f'Unsupported transaction type {transaction.type()}')
                    return

                # Kick off the proxy transaction
                rxBuffer = self.Transfer(devIdx, txBuffer, byteSize)

                # Check the error flag
                resp = (self.SR.get(read=True) & 0x2)

                # Clear status register by writing 1 to the write to clear bits
                self.SR.set(0xFF)

                #print(f'Resp: {resp}')
                if resp != 0:
                    self.ResetHw()
                    transaction.error(f'AXIL tranaction failed with RESP: {resp}')

                # Finish the transaction
                elif self.Rnw.valueDisp() == 'Write':
                    transaction.done()

                else:
                    # parse the rxBuffer
                    data = 0x0
                    for i in range(dataBytes):
                        data = (data << 8) | rxBuffer[i+addrBytes]

                    #print(f'Got read data: {data:x}')
                    dataBa = bytearray(data.to_bytes(4, 'little', signed=False))

                    #print(dataBa)
                    transaction.setData(dataBa, 0)
                    transaction.done()

    def _stop(self):
        self._queue.put(None)
        self._pollThread.join()

class _ProxySlave(rogue.interfaces.memory.Slave):

    def __init__(self, regs):
        super().__init__(4,4)
        self._regs = regs

    def _doTransaction(self, transaction):
        #print('_ProxySlave._doTransaction')
        self._regs.proxyTransaction(transaction)

class SpiPs(pr.Device):

    def __init__(self,
            hidden     = True,
            pollPeriod = 0.0,
            **kwargs):
        super().__init__(hidden=hidden, **kwargs)

        self.add(_Regs(
            name       = 'Regs',
            memBase    = self,
            offset     = 0x0000,
            hidden     = hidden,
            pollPeriod = pollPeriod,
            expand     = True,
        ))
        self.proxy = _ProxySlave(self.Regs)

    def add(self, node):
        pr.Node.add(self, node)

        if isinstance(node, pr.Device):
            if node._memBase is None:
                node._setSlave(self.proxy)

    def Init(self):
        self.Regs.ResetHw()
