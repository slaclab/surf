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
            name        = 'VendorID',
            description = 'PCI Vendor Identifier (assigned by PCI-SIG)',
            offset      = 0x000,
            bitSize     = 16,
            bitOffset   = 0,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DeviceID',
            description = 'PCI Device Identifier (assigned by vendor)',
            offset      = 0x000,
            bitSize     = 16,
            bitOffset   = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Command',
            description = 'PCI Command Register (controls device features: I/O, memory, bus mastering, etc.)',
            offset      = 0x004,
            bitSize     = 16,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Status',
            description = 'PCI Status Register (reports device capabilities and errors)',
            offset      = 0x004,
            bitSize     = 16,
            bitOffset   = 16,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'RevisionID',
            description = 'Revision ID of the device',
            offset      = 0x008,
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'ProgIF',
            description = 'Programming Interface (specific to the class/subclass, e.g. UHCI vs OHCI for USB)',
            offset      = 0x008,
            bitSize     = 8,
            bitOffset   = 8,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Subclass',
            description = 'PCI Subclass Code (defines function within class)',
            offset      = 0x008,
            bitSize     = 8,
            bitOffset   = 16,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'ClassCode',
            description = 'PCI Base Class Code (e.g. Network, Storage, Bridge, etc.)',
            offset      = 0x008,
            bitSize     = 8,
            bitOffset   = 24,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'CacheLineSize',
            description = 'System cache line size in 32-bit words',
            offset      = 0x00C,
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LatencyTimer',
            description = 'Latency Timer (maximum bus latency in PCI clocks)',
            offset      = 0x00C,
            bitSize     = 8,
            bitOffset   = 8,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'HeaderType',
            description = 'Header type (0=general device, 1=PCI-to-PCI bridge, etc.)',
            offset      = 0x00C,
            bitSize     = 8,
            bitOffset   = 16,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'BIST',
            description = 'Built-In Self-Test status/control',
            offset      = 0x00C,
            bitSize     = 8,
            bitOffset   = 24,
            mode        = 'RO',
            hidden      = True,
        ))

        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = f'BaseAddressBar[{i}]',
                description = f'Base Address Register {i} (maps device memory or I/O regions)',
                offset      = 0x010+(4*i),
                bitSize     = 32,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = (i!=0),
            ))

        self.add(pr.RemoteVariable(
            name        = 'CardbusCisPointer',
            description = 'Pointer to CardBus CIS (Card Information Structure)',
            offset      = 0x028,
            bitSize     = 32,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'SubVendorId',
            description = 'Subsystem Vendor ID (assigned to subsystem integrator)',
            offset      = 0x02C,
            bitSize     = 16,
            bitOffset   = 0,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SubDeviceId',
            description = 'Subsystem Device ID (assigned to subsystem integrator)',
            offset      = 0x02C,
            bitSize     = 16,
            bitOffset   = 16,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExpansionRomBaseAddress',
            description = 'Base Address of Expansion ROM (if implemented)',
            offset      = 0x030,
            bitSize     = 32,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'CapabilitiesPointer',
            description = 'Pointer to first capability structure in configuration space',
            offset      = 0x034,
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'InterruptLine',
            description = 'Interrupt Line (legacy PCI INTx mapping)',
            offset      = 0x03C,
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'InterruptPin',
            description = 'Interrupt Pin (INTA#, INTB#, INTC#, INTD#)',
            offset      = 0x03C,
            bitSize     = 8,
            bitOffset   = 8,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'MinGrant',
            description = 'Minimum Grant (PCI bus arbitration hint, in 250 ns units)',
            offset      = 0x03C,
            bitSize     = 8,
            bitOffset   = 16,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxLatency',
            description = 'Maximum Latency (PCI bus arbitration hint, in 250 ns units)',
            offset      = 0x03C,
            bitSize     = 8,
            bitOffset   = 24,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'DevSpecRegion',
            description = 'Device-Specific Region (0x40–0xFF, vendor-defined capability and control registers)',
            offset      = 0x40,
            valueBits   = 8,
            valueStride = 8,
            base        = pr.UInt,
            mode        = 'RO',
            numValues   = 192,
            hidden      = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'LinkStatus',
            description  = 'Link Status (derived from PCI Express Capability: negotiated link speed and width)',
            mode         = 'RO',
            linkedGet    = self.updateLinkStatus,
            dependencies = [self.CapabilitiesPointer, self.DevSpecRegion],
            hidden       = True,
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
            name        = 'LnkCapSpeed',
            description = 'Link Capabilities: Maximum Supported Link Speed',
            mode        = 'RO',
            value       = 0,
            units       = 'GT/s',
            enum        = speedEnum
        ))

        self.add(pr.LocalVariable(
            name        = 'LnkCapWidth',
            description = 'Link Capabilities: Maximum Supported Link Width',
            mode        = 'RO',
            value       = 0,
            units       = 'lanes',
            disp        = '{:d}',
        ))

        self.add(pr.LocalVariable(
            name        = 'LnkStaSpeed',
            description = 'Link Status: Negotiated Link Speed',
            mode        = 'RO',
            value       = 0,
            units       = 'GT/s',
            enum        = speedEnum
        ))

        self.add(pr.LocalVariable(
            name        = 'LnkStaWidth',
            description = 'Link Status: Negotiated Link Width',
            mode        = 'RO',
            value       = 0,
            units       = 'lanes',
            disp        = '{:d}',
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
                self.LnkCapSpeed.set( int((linkCap >> 0) & 0xF) )
                self.LnkCapWidth.set( int((linkCap >> 4) & 0xFF) )

                # Set the link speed and width status
                self.LnkStaSpeed.set( int((linkStatus >> 0) & 0xF) )
                self.LnkStaWidth.set( int((linkStatus >> 4) & 0xFF) )
