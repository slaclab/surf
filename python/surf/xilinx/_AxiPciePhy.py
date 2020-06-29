#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite monitoring for AXI Bridge for PCI Express
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Lite monitoring for AXI Bridge for PCI Express (Refer to PG055 and PG194)
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

class AxiPciePhy(pr.Device):
    def __init__(
            self,
            description = 'AXI-Lite monitoring for AXI Bridge for PCI Express (Refer to PG055 and PG194)',
            **kwargs):
        super().__init__(description=description, **kwargs)

        ##############################
        # Variables
        ##############################
        self.add(pr.RemoteVariable(
            name         = 'VendorID',
            offset       =  0x000,
            bitSize      =  16,
            bitOffset    =  0,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DeviceID',
            offset       =  0x000,
            bitSize      =  16,
            bitOffset    =  16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'Command',
            offset       =  0x004,
            bitSize      =  16,
            bitOffset    =  0,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'Status',
            offset       =  0x004,
            bitSize      =  16,
            bitOffset    =  16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'RevisionID',
            offset       =  0x008,
            bitSize      =  8,
            bitOffset    =  0,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ProgIF',
            offset       =  0x008,
            bitSize      =  8,
            bitOffset    =  8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'Subclass',
            offset       =  0x008,
            bitSize      =  8,
            bitOffset    =  16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ClassCode',
            offset       =  0x008,
            bitSize      =  8,
            bitOffset    =  24,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'CacheLineSize',
            offset       =  0x00C,
            bitSize      =  8,
            bitOffset    =  0,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LatencyTimer',
            offset       =  0x00C,
            bitSize      =  8,
            bitOffset    =  8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'HeaderType',
            offset       =  0x00C,
            bitSize      =  8,
            bitOffset    =  16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'BIST',
            offset       =  0x00C,
            bitSize      =  8,
            bitOffset    =  24,
            mode         = 'RO',
        ))

        for i in range(6):
            self.add(pr.RemoteVariable(
                name         = f'BaseAddressBar[{i}]',
                offset       =  0x010+(4*i),
                bitSize      =  32,
                bitOffset    =  0,
                mode         = 'RO',
            ))

        self.add(pr.RemoteVariable(
            name         = 'CardbusCisPointer',
            offset       =  0x028,
            bitSize      =  32,
            bitOffset    =  0,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'SubVendorId',
            offset       =  0x02C,
            bitSize      =  16,
            bitOffset    =  0,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'SubDeviceId',
            offset       =  0x02C,
            bitSize      =  16,
            bitOffset    =  16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ExpansionRomBaseAddress',
            offset       =  0x030,
            bitSize      =  32,
            bitOffset    =  0,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'CapabilitiesPointer',
            offset       =  0x034,
            bitSize      =  8,
            bitOffset    =  0,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'InterruptLine',
            offset       =  0x03C,
            bitSize      =  8,
            bitOffset    =  0,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'InterruptPin',
            offset       =  0x03C,
            bitSize      =  8,
            bitOffset    =  8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MinGrant',
            offset       =  0x03C,
            bitSize      =  8,
            bitOffset    =  16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MaxLatency',
            offset       =  0x03C,
            bitSize      =  8,
            bitOffset    =  24,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'Gen2Capable',
            description  = 'If set, underlying integrated block supports PCIe Gen2 speed.',
            offset       =  0x130,
            bitSize      =  1,
            bitOffset    =  0,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'Gen3Capable',
            description  = 'If set, underlying integrated block supports PCIe Gen3 speed.',
            offset       =  0x130,
            bitSize      =  1,
            bitOffset    =  3,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RootPortPresent',
            description  = 'Indicates the underlying integrated block is a Root Port when this bit is set. If set, Root Port registers are present in this interface.',
            offset       =  0x130,
            bitSize      =  1,
            bitOffset    =  1,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'UpConfigCapable',
            description  = 'Indicates the underlying integrated block is upconfig capable when this bit is set.',
            offset       =  0x130,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LinkRateGen2',
            description  = '0b = 2.5 GT/s (if bit[12] = 0), or 8.0GT/s (if bit[12] = 1), 1b = 5.0 GT/s',
            offset       =  0x144,
            bitSize      =  1,
            bitOffset    =  0,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LinkRateGen3',
            description  = 'Reports the current link rate. 0b = see bit[0]. 1b = 8.0 GT/s',
            offset       =  0x144,
            bitSize      =  1,
            bitOffset    =  12,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LinkWidth16',
            description  = 'Reports the current link width. 0b = See bit[2:1]. 1b = x16.',
            offset       =  0x144,
            bitSize      =  1,
            bitOffset    =  13,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LinkWidth',
            description  = 'Reports the current link width. 00b = x1, 01b = x2, 10b = x4, 11b = x8.',
            offset       =  0x144,
            bitSize      =  2,
            bitOffset    =  1,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'LnkCapSpeed',
            description  = 'LnkCapSpeed',
            mode         = 'RO',
            linkedGet    = lambda: '8.0' if self.Gen3Capable.value() else ( '5.0' if self.Gen2Capable.value() else '2.5'),
            dependencies = [self.Gen3Capable,self.Gen2Capable],
            units        = 'GT/s',
        ))

        self.add(pr.LinkVariable(
            name         = 'LnkStaSpeed',
            description  = 'LnkStaSpeed',
            mode         = 'RO',
            linkedGet    = lambda: '8.0' if self.LinkRateGen3.value() else ( '5.0' if self.LinkRateGen2.value() else '2.5'),
            dependencies = [self.LinkRateGen3,self.LinkRateGen2],
            units        = 'GT/s',
        ))

        self.add(pr.LinkVariable(
            name         = 'LnkStaWidth',
            description  = 'LnkStaWidth',
            mode         = 'RO',
            linkedGet    = lambda: 16 if self.LinkWidth16.value() else 2**self.LinkWidth.value(),
            dependencies = [self.LinkWidth16,self.LinkWidth],
            units        = '# of lanes',
        ))
