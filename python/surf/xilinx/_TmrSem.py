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

class TmrInject(pr.Device):
    def __init__(
            self,
            description = 'Xilinx TMR Soft Error Mitigation (SEM) registers (refer to PG268 v1.0, page 52 - 55)',
            **kwargs):
        super().__init__(description=description, **kwargs)

        self.add(pr.RemoteVariable(
            name         = 'MON_RECEIVE',
            description  = 'Monitor receive data',
            offset       = 0x0,
            bitSize      = 8,
            bitOffset    = 0,
            mode         = 'RO',
            updateNotify = False,
            bulkOpEn     = False,
            hidden       = True,
            verify       = False,
        ))

        self.add(pr.RemoteVariable(
            name         = 'MON_TRANSMIT',
            description  = 'Monitor transmit data',
            offset       = 0x4,
            bitSize      = 8,
            bitOffset    = 0,
            mode         = 'WO',
            updateNotify = False,
            bulkOpEn     = False,
            hidden       = True,
            verify       = False,
        ))

        self.add(pr.RemoteVariable(
            name         = 'Interrupt',
            description  = 'Indicates that interrupt is enabled: 0 = Interrupt is disabled, 1 = Interrupt is enabled',
            offset       = 0x8,
            bitSize      = 1,
            bitOffset    = 4,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxFifoFull',
            description  = 'Indicates if the transmit FIFO is full: 0 = Transmit FIFO is not full, 1 = Transmit FIFO is full',
            offset       = 0x8,
            bitSize      = 1,
            bitOffset    = 3,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxFifoEmpty',
            description  = 'Indicates if the transmit FIFO is Empty: 0 = Transmit FIFO is not Empty, 1 = Transmit FIFO is Empty',
            offset       = 0x8,
            bitSize      = 1,
            bitOffset    = 2,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxFifoFull',
            description  = 'Indicates if the receive FIFO is full: 0 = receive FIFO is not full, 1 = receive FIFO is full',
            offset       = 0x8,
            bitSize      = 1,
            bitOffset    = 1,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxFifoValidData',
            description  = 'Indicates if the receive FIFO has valid data: 0 = Receive FIFO is empty, 1 = Receive FIFO has valid data',
            offset       = 0x8,
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'InterruptEnabled',
            description  = 'Enable interrupt for the MDM JTAG Monitor: 0 = Disable interrupt signal, 1 = Enable interrupt signal',
            offset       = 0xC,
            bitSize      = 1,
            bitOffset    = 4,
            mode         = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ResetRxFIFO',
            description  = 'Reset/clear the receive FIFO, Writing a 1 to this bit position clears the receive FIFO: 0 = Do nothing, 1 = Clear the receive FIFO',
            offset       = 0xC,
            bitSize      = 1,
            bitOffset    = 1,
            mode         = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ResetTxFIFO',
            description  = 'Reset/clear the transmit FIFO, Writing a 1 to this bit position clears the transmit FIFO: 0 = Do nothing, 1 = Clear the transmit FIFO',
            offset       = 0xC,
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'WO',
        ))
