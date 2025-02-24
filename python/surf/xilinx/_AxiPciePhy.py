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
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'Status',
            offset       =  0x004,
            bitSize      =  16,
            bitOffset    =  16,
            mode         = 'RO',
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RevisionID',
            offset       =  0x008,
            bitSize      =  8,
            bitOffset    =  0,
            mode         = 'RO',
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'ProgIF',
            offset       =  0x008,
            bitSize      =  8,
            bitOffset    =  8,
            mode         = 'RO',
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'Subclass',
            offset       =  0x008,
            bitSize      =  8,
            bitOffset    =  16,
            mode         = 'RO',
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'ClassCode',
            offset       =  0x008,
            bitSize      =  8,
            bitOffset    =  24,
            mode         = 'RO',
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'CacheLineSize',
            offset       =  0x00C,
            bitSize      =  8,
            bitOffset    =  0,
            mode         = 'RO',
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LatencyTimer',
            offset       =  0x00C,
            bitSize      =  8,
            bitOffset    =  8,
            mode         = 'RO',
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'HeaderType',
            offset       =  0x00C,
            bitSize      =  8,
            bitOffset    =  16,
            mode         = 'RO',
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'BIST',
            offset       =  0x00C,
            bitSize      =  8,
            bitOffset    =  24,
            mode         = 'RO',
            hidden       =  True,
        ))

        for i in range(6):
            self.add(pr.RemoteVariable(
                name         = f'BaseAddressBar[{i}]',
                offset       =  0x010+(4*i),
                bitSize      =  32,
                bitOffset    =  0,
                mode         = 'RO',
                hidden       = (i!=0),
            ))

        self.add(pr.RemoteVariable(
            name         = 'CardbusCisPointer',
            offset       =  0x028,
            bitSize      =  32,
            bitOffset    =  0,
            mode         = 'RO',
            hidden       =  True,
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
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'CapabilitiesPointer',
            offset       =  0x034,
            bitSize      =  8,
            bitOffset    =  0,
            mode         = 'RO',
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'InterruptLine',
            offset       =  0x03C,
            bitSize      =  8,
            bitOffset    =  0,
            mode         = 'RO',
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'InterruptPin',
            offset       =  0x03C,
            bitSize      =  8,
            bitOffset    =  8,
            mode         = 'RO',
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'MinGrant',
            offset       =  0x03C,
            bitSize      =  8,
            bitOffset    =  16,
            mode         = 'RO',
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'MaxLatency',
            offset       =  0x03C,
            bitSize      =  8,
            bitOffset    =  24,
            mode         = 'RO',
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = "DevSpecRegion",
            description  = "The memory range from offset 0x40 to 0xFF in the PCI configuration header is referred to as the 'Device Specific Region'. This area is reserved for use by the device vendor and can contain any vendor-specific configuration or control registers.",
            offset       =  0x40,
            valueBits      =  8,
            valueStride    =  8,
            base         = pr.UInt,
            mode         = "RO",
            numValues       =  192,
            hidden       =  True,
        ))

        self.add(pr.LinkVariable(
            name         = 'LinkStatus',
            mode         = 'RO',
            linkedGet    = self.updateLinkStatus,
            dependencies = [self.CapabilitiesPointer, self.DevSpecRegion],
            hidden       =  True,
        ))

        speedEnum = {
            0: 'UNDEFINED',
            1: '2.5',
            2: '5',
            3: '8',
            4: '16',
            5: '32',
            6: '64',
            7: '128',
        }

        self.add(pr.LocalVariable(
            name   = 'LnkCapSpeed',
            mode   = 'RO',
            value  = 0,
            units  = 'GT/s',
            enum   = speedEnum
        ))

        self.add(pr.LocalVariable(
            name   = 'LnkCapWidth',
            mode   = 'RO',
            value  = 0,
            units  = 'lanes',
            disp   = '{:d}',
        ))

        self.add(pr.LocalVariable(
            name   = 'LnkStaSpeed',
            mode   = 'RO',
            value  = 0,
            units  = 'GT/s',
            enum   = speedEnum
        ))

        self.add(pr.LocalVariable(
            name   = 'LnkStaWidth',
            mode   = 'RO',
            value  = 0,
            units  = 'lanes',
            disp   = '{:d}',
        ))


    def updateLinkStatus(self):
        with self.root.updateGroup():
            # Check if value points to the Device Specific Region
            ptr = self.CapabilitiesPointer.value()
            if ptr >= 0x40:
                # Adjust the pointer to the start of the Device Specific Region
                adjusted_ptr = ptr - 0x40

                # Go to the Capabilities Pointer offset and get the Capabilities Express Endpoint offset
                ptrOffset = self.DevSpecRegion.value()[adjusted_ptr + 1] - 0x40

                # Capabilities Express Endpoint offset
                dev_spec_values = self.DevSpecRegion.value()
                linkCap = dev_spec_values[ptrOffset + 0x0C] | (dev_spec_values[ptrOffset + 0x0D] << 8)
                linkStatus = dev_spec_values[ptrOffset + 0x12] | (dev_spec_values[ptrOffset + 0x13] << 8)

                # Set the link speed and width capabilities
                self.LnkCapSpeed.set((linkCap >> 0) & 0xF)
                self.LnkCapWidth.set((linkCap >> 4) & 0xFF)

                # Set the link speed and width status
                self.LnkStaSpeed.set((linkStatus >> 0) & 0xF)
                self.LnkStaWidth.set((linkStatus >> 4) & 0xFF)
