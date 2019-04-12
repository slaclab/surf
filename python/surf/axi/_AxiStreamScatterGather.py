import pyrogue as pr

class AxiStreamScatterGather(pr.Device):
    def __init__(self,
                 description='Debug registers for AxiStreamScatterGather module',
                 **kwargs):
        super().__init__(description=description, **kwargs)

        self.add(pr.RemoteVariable(
            name = 'RxRamWrAddr',
            mode = 'RO',
            offset = 0x00,
            disp = '{:#08x}'))
        
        self.add(pr.RemoteVariable(
            name = 'RxSofAddr',
            mode = 'RO',
            offset = 0x04,
            disp = '{:#08x}'))
        
        self.add(pr.RemoteVariable(
            name = 'RxWordCount',
            mode = 'RO',
            offset = 0x08,
            disp = '{:d}'))
        
        self.add(pr.RemoteVariable(
            name = 'RxFrameNumber',
            mode = 'RO',
            offset = 0x0C,
            bitSize = 31,
            disp = '{:d}'))

        self.add(pr.RemoteVariable(
            name = 'RxError',
            mode = 'RO',
            offset = 0x0C,
            bitSize = 1,
            bitOffset = 31,
            base = pr.Bool))
        
        self.add(pr.RemoteVariable(
            name = 'TxRamRdAddr',
            mode = 'RO',
            offset = 0x10,
            disp = '{:#08x}'))

        self.add(pr.RemoteVariable(
            name = 'TxWordCount',
            mode = 'RO',
            offset = 0x14,
            disp = '{:d}'))

        self.add(pr.RemoteVariable(
            name = 'TxFrameNumber',
            mode = 'RO',
            offset = 0x18,
            disp = '{:d}'))

        self.add(pr.RemoteVariable(
            name = 'LongWords',
            mode = 'RO',
            offset = 0x1C,
            disp = '{:d}'))

        self.add(pr.RemoteVariable(
            name = 'LongWordCount',
            mode = 'RO',
            offset = 0x20,
            disp = '{:d}'))

        self.add(pr.RemoteVariable(
            name = 'BadWords',
            mode = 'RO',
            offset = 0x24,
            disp = '{:d}'))
        
        self.add(pr.RemoteVariable(
            name = 'BadWordCount',
            mode = 'RO',
            offset = 0x28,
            disp = '{:d}'))
        
