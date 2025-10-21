import pyrogue as pr

class AxiStreamTimer(pr.Device):
    def __init__(self, NStreams=1, NEvents=1, **kwargs):
        super().__init__(**kwargs)

        self.NStreams = NStreams
        self.NEvents  = NEvents

        self.add(pr.RemoteVariable(
            name         = 'MeasureTime',
            offset       = 0x000,
            bitSize      = 1,
            base         = pr.Bool,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'NumStreamsG',
            offset       = 0x004,
            bitSize      = 32,
            mode         = 'RO',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'NumEventG',
            offset       = 0x008,
            bitSize      = 32,
            mode         = 'RO',
            disp         = '{:d}',
        ))

        for ev in range(self.NEvents):
            for ch in range(self.NStreams):
                self.add(pr.RemoteVariable(
                    name         = f'Channel{ch}SOF{ev}',
                    offset       = 12+(ch*8)+(8*self.NStreams*ev),
                    bitSize      = 32,
                    mode         = 'RO',
                    units        = 'Clock Cycles',
                    disp         = '{:d}',
                ))

                self.add(pr.RemoteVariable(
                    name         = f'Channel{ch}EOF{ev}',
                    offset       = 16+(ch*8)+(8*self.NStreams*ev),
                    bitSize      = 32,
                    mode         = 'RO',
                    units        = 'Clock Cycles',
                    disp         = '{:d}',
                ))