import pyrogue as pr

class AxiStreamDmaV2Desc(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(description='', **kwargs)

        
        self.add(pr.RemoteVariable(
            name='HwEnable',
            mode = 'RO',
            offset=0x0,
            bitOffset=0,
            bitSize=1,
        ))
        
        self.add(pr.RemoteVariable(
            name='Version',
            mode = 'RO',            
            offset=0x0,
            bitOffset=24,
            bitSize=8,
        ))

        self.add(pr.RemoteVariable(
            name='IntEnable',
            mode = 'RO',            
            offset=0x4,
            bitOffset=0,
            bitSize=1,
        ))
        
        self.add(pr.RemoteVariable(
            name='ContEn',
            mode = 'RO',
            offset=0x8,
            bitOffset=0,
            bitSize=1,
        ))
        
        self.add(pr.RemoteVariable(
            name='DropEn',
            mode = 'RO',
            offset=0xC,
            bitOffset=0,
            bitSize=1,
        ))

        self.add(pr.RemoteVariable(
            name='WrBaseAddr',
            mode = 'RO',
            offset=0x10,
            bitOffset=0,
            bitSize=64,
        ))
        
        self.add(pr.RemoteVariable(
            name='RdBaseAddr',
            mode = 'RO',
            offset=0x14,
            bitOffset=0,
            bitSize=64,
        ))
        
        self.add(pr.RemoteVariable(
            name='FifoReset',
            mode = 'RO',
            offset=0x20,
            bitOffset=0,
            bitSize=1,
        ))
        self.add(pr.RemoteVariable(
            name='BufBaseAddr',
            mode = 'RO',
            offset=0x24,
            bitOffset=0,
            bitSize=32,
        ))
        
        self.add(pr.RemoteVariable(
            name='MaxSize',
            mode = 'RO',
            offset=0x28,
            bitOffset=0,
            bitSize=24,
            disp='{:d}',
        ))
        
        self.add(pr.RemoteVariable(
            name='Online',
            mode = 'RO',
            offset=0x2C,
            bitOffset=0,
            bitSize=1,
        ))
        
        self.add(pr.RemoteVariable(
            name='Acknowledge',
            mode = 'RO',
            offset=0x30,
            bitOffset=0,
            bitSize=1,
        ))

        self.add(pr.RemoteVariable(
            name='ChanCount',
            mode = 'RO',
            offset=0x34,
            bitOffset=0,
            bitSize=8,
        ))

        self.add(pr.RemoteVariable(
            name='DescAwidth',
            mode = 'RO',
            offset=0x38,
            bitOffset=0,
            bitSize=8,
        ))
        
        self.add(pr.RemoteVariable(
            name='DescCache',
            mode = 'RO',
            offset=0x3C,
            bitOffset=0,
            bitSize=4,
        ))
        self.add(pr.RemoteVariable(
            name='BuffCache',
            mode = 'RO',
            offset=0x3C,
            bitOffset=8,
            bitSize=4,
        ))
        
        self.add(pr.RemoteVariable(
            name='FifoDin',
            mode = 'RO',
            offset=0x40,
            bitOffset=0,
            bitSize=32,
        ))
        
        self.add(pr.RemoteVariable(
            name='IntAckCount',
            mode = 'RO',
            offset=0x4C,
            bitOffset=0,
            bitSize=16,
        ))
        
        self.add(pr.RemoteVariable(
            name='IntEnableDup',
            mode = 'RO',
            offset=0x4C,
            bitOffset=17,
            bitSize=1,
        ))
        
        self.add(pr.RemoteVariable(
            name='IntReqCount',
            mode = 'RO',
            offset=0x50,
            bitOffset=0,
            bitSize=32,
        ))
        
        self.add(pr.RemoteVariable(
            name='WrIndex',
            mode = 'RO',
            offset=0x54,
            bitOffset=0,
            bitSize=32,
        ))
        self.add(pr.RemoteVariable(
            name='RdIndex',
            mode = 'RO',
            offset=0x58,
            bitOffset=0,
            bitSize=32,
        ))
        
        self.add(pr.RemoteVariable(
            name='WrReqMissed',
            mode = 'RO',
            offset=0x5C,
            bitOffset=0,
            bitSize=32,
        ))
