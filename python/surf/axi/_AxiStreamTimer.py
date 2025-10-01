import pyrogue as pr

class AxiStreamTimer(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name         = 'MeasureTime',
            offset       = 0x100,
            bitSize      = 1,
            base         = pr.Bool,
            mode         = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'EVENT_NUM_G',
            offset       = 0x000,
            bitSize      = 32,
            mode         = 'RO',
            disp         = '{:d}',
        ))

        # for evt_n in range(self.EVENT_NUM_G.get()):
        for evt_n in range(7):
            self.add(pr.RemoteVariable(
                name         = f'StartSOF[{evt_n}]',
                offset       = 0x004+0x004*evt_n,
                bitSize      = 32,
                mode         = 'RO',
                units        = 'Clock Cycles',
                disp         = '{:d}',
            ))

            self.add(pr.RemoteVariable(
                name         = f'StartEOF[{evt_n}]',
                offset       = 0x020+0x004*evt_n,
                bitSize      = 32,
                mode         = 'RO',
                units        = 'Clock Cycles',
                disp         = '{:d}',
            ))

            self.add(pr.RemoteVariable(
                name         = f'StopSOF[{evt_n}]',
                offset       = 0x03c+0x004*evt_n,
                bitSize      = 32,
                mode         = 'RO',
                units        = 'Clock Cycles',
                disp         = '{:d}',
            ))

            self.add(pr.RemoteVariable(
                name         = f'StopEOF[{evt_n}]',
                offset       = 0x058+0x004*evt_n,
                bitSize      = 32,
                mode         = 'RO',
                units        = 'Clock Cycles',
                disp         = '{:d}',
            ))
