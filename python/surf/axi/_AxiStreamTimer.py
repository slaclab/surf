import pyrogue as pr

class AxiStreamTimerChannel(pr.Device):
    def __init__(self, NEvents, NStreams, **kwargs):
        super().__init__(**kwargs)

        self.NEvents  = NEvents
        self.NStreams = NStreams

        for ev in range(self.NEvents):
            self.add(pr.RemoteVariable(
                    name         = f'SOF[{ev}]',
                    offset       = (8*self.NStreams*ev),
                    bitSize      = 32,
                    mode         = 'RO',
                    units        = 'Clock Cycles',
                    disp         = '{:d}',
                ))

            self.add(pr.RemoteVariable(
                name         = f'EOF[{ev}]',
                offset       = 4+(8*self.NStreams*ev),
                bitSize      = 32,
                mode         = 'RO',
                units        = 'Clock Cycles',
                disp         = '{:d}',
            ))



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

        for ch in range(self.NStreams):
            self.add(AxiStreamTimerChannel(
                name         = f'Channel[{ch}]',
                offset       = 12+(ch*8),
                NEvents      = self.NEvents,
                NStreams     = self.NStreams,
                expand       = True,
            ))