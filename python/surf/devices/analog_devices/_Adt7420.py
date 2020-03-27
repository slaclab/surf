#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Analod Deviced ADT7420
#-----------------------------------------------------------------------------
# File       : _Adt7420.py
# Created    : 2019-07-17
#-----------------------------------------------------------------------------
# Description:
# Analog devices ADT7420 I2C temperature sensor
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the rogue software platform, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue         as pr

class Adt7420(pr.Device):
    def __init__(self,
            name        = "Adt7420",
            description = "Adt7420",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        self.add(pr.RemoteVariable(
            name        = 'TempMSByte',
            description = 'Temperature value most significant byte (Byte Address = 0x00: AXI-Lite: 0x00)',
            offset      = 0x0,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TempLSByte',
            description = 'Temperature value least significant byte (Byte Address = 0x01: AXI-Lite: 0x04)',
            offset      = 0x4,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Status',
            description = 'Status Register (Byte Address = 0x02: AXI-Lite: 0x08)',
            offset      = 0x8,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Config',
            description = 'Config Register (Byte Address = 0x03: AXI-Lite: 0x0C)',
            offset      = 0xC,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'THighMSByte',
            description = 'THIGH setpoint most significant byte (Byte Address = 0x04: AXI-Lite: 0x10)',
            offset      = 0x10,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'THighLSByte',
            description = 'THIGH setpoint least significant byte (Byte Address = 0x05: AXI-Lite: 0x14)',
            offset      = 0x14,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TLowMSByte',
            description = 'TLOW setpoint most significant byte (Byte Address = 0x06: AXI-Lite: 0x18)',
            offset      = 0x18,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TLowLSByte',
            description = 'TLOW setpoint least significant byte (Byte Address = 0x07: AXI-Lite: 0x1C)',
            offset      = 0x1C,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TCritMSByte',
            description = 'TCRIT setpoint most significant byte (Byte Address = 0x08: AXI-Lite: 0x20)',
            offset      = 0x20,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'THyst',
            description = 'THYST setpoint (Byte Address = 0x0A: AXI-Lite: 0x28)',
            offset      = 0x28,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ID',
            description = 'ID Register (Byte Address = 0x0B: AXI-Lite: 0x2C)',
            offset      = 0x2C,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))
