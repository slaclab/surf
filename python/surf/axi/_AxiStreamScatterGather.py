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

class AxiStreamScatterGather(pr.Device):
    def __init__(self,
                 description='Debug registers for AxiStreamScatterGather module',
                 **kwargs):
        super().__init__(description=description, **kwargs)

        self.add(pr.RemoteVariable(
            name = 'RxRamWrAddr',
            description = 'Current write address pointer into the receive scatter-gather RAM',
            mode = 'RO',
            offset = 0x00,
            disp = '{:#08x}'))

        self.add(pr.RemoteVariable(
            name = 'RxSofAddr',
            description = 'RAM address of the start-of-frame for the current receive packet',
            mode = 'RO',
            offset = 0x04,
            disp = '{:#08x}'))

        self.add(pr.RemoteVariable(
            name = 'RxWordCount',
            description = 'Number of words received in the current scatter-gather frame',
            mode = 'RO',
            offset = 0x08,
            disp = '{:d}'))

        self.add(pr.RemoteVariable(
            name = 'RxFrameNumber',
            description = 'Sequential frame number of the current receive scatter-gather frame',
            mode = 'RO',
            offset = 0x0C,
            bitSize = 31,
            disp = '{:d}'))

        self.add(pr.RemoteVariable(
            name = 'RxError',
            description = 'Error flag set when a receive scatter-gather frame encounters a fault',
            mode = 'RO',
            offset = 0x0C,
            bitSize = 1,
            bitOffset = 31,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            name = 'TxRamRdAddr',
            description = 'Current read address pointer from the transmit scatter-gather RAM',
            mode = 'RO',
            offset = 0x10,
            disp = '{:#08x}'))

        self.add(pr.RemoteVariable(
            name = 'TxWordCount',
            description = 'Number of words transmitted in the current scatter-gather frame',
            mode = 'RO',
            offset = 0x14,
            disp = '{:d}'))

        self.add(pr.RemoteVariable(
            name = 'TxFrameNumber',
            description = 'Sequential frame number of the current transmit scatter-gather frame',
            mode = 'RO',
            offset = 0x18,
            disp = '{:d}'))

        self.add(pr.RemoteVariable(
            name = 'LongWords',
            description = 'Count of long (oversized) words detected in the scatter-gather stream',
            mode = 'RO',
            offset = 0x1C,
            disp = '{:d}'))

        self.add(pr.RemoteVariable(
            name = 'LongWordCount',
            description = 'Cumulative count of long-word events across all scatter-gather frames',
            mode = 'RO',
            offset = 0x20,
            disp = '{:d}'))

        self.add(pr.RemoteVariable(
            name = 'BadWords',
            description = 'Count of malformed or invalid words detected in the scatter-gather stream',
            mode = 'RO',
            offset = 0x24,
            disp = '{:d}'))

        self.add(pr.RemoteVariable(
            name = 'BadWordCount',
            description = 'Cumulative count of bad-word events across all scatter-gather frames',
            mode = 'RO',
            offset = 0x28,
            disp = '{:d}'))
