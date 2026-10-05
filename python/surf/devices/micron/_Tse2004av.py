#-----------------------------------------------------------------------------
# Title      : PyRogue _Tse2004av Module
#-----------------------------------------------------------------------------
# Description:
# JEDEC TSE2004av temperature-sensor registers and temperature decoding,
# as documented in the Renesas TSE2004GB2B0 datasheet, pages 23-27:
# https://www.renesas.com/en/document/dst/tse2004gb2b0-datasheet
# The FPGA I2C bridge must map each 16-bit sensor register to a 32-bit word
# and preserve the sensor word's byte order.
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

def decodeTse2004avTemperature(raw):
    """Decode a raw 16-bit JC-42.4 ambient-temperature register word into
    degrees Celsius. The low 13 bits are a signed, two's complement field
    at 0.0625 degrees Celsius per count; bits 15 down to 13 are alarm flags
    and carry no temperature information, so they are masked off and
    discarded here. No rounding, truncation, or clamping is applied."""
    code = raw & 0x1FFF
    if code & 0x1000:
        code -= 0x2000
    return code * 0.0625

def _tse2004avTemperatureGet(dev, var, read=True):
    raw = var.dependencies[0].get(read=read)
    return decodeTse2004avTemperature(raw)

def _tse2004avConfigurationGet(dev, var, read=True):
    # All fields share one block: read it once, then assemble the cached bits.
    # CLEAR and reserved bits always read zero and are omitted.
    var.dependencies[0].get(read=read)
    return sum(int(field.get(read=False)) << field.bitOffset[0]
               for field in var.dependencies)

def _tse2004avClearEvent(cmd):
    try:
        cmd.set(1)
    finally:
        # Complete the pulse even on failure so a later control or bulk write
        # cannot replay a cached CLEAR bit. Writing zero has no clear effect.
        cmd.set(0)

class Tse2004av(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name        = 'Capability',
            description = 'Capability Register',
            offset      = (0x00 << 2),
            bitSize     = 16,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'EventMode',
            description = 'EVENT pin mode; frozen when either limit lock is set',
            offset      = (0x01 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
            enum        = {0: 'Comparator', 1: 'Interrupt'},
        ))

        self.add(pr.RemoteVariable(
            name        = 'EventPolarity',
            description = 'EVENT pin active level; frozen when either limit lock is set',
            offset      = (0x01 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            base        = pr.UInt,
            mode        = 'RW',
            enum        = {0: 'ActiveLow', 1: 'ActiveHigh'},
        ))

        self.add(pr.RemoteVariable(
            name        = 'CriticalOnly',
            description = 'Limit EVENT to critical temperature; frozen by EventLock',
            offset      = (0x01 << 2),
            bitSize     = 1,
            bitOffset   = 2,
            base        = pr.Bool,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'EventEnable',
            description = 'Enable the EVENT pin; frozen when either limit lock is set',
            offset      = (0x01 << 2),
            bitSize     = 1,
            bitOffset   = 3,
            base        = pr.Bool,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'EventStatus',
            description = 'True while the sensor asserts the EVENT pin',
            offset      = (0x01 << 2),
            bitSize     = 1,
            bitOffset   = 4,
            base        = pr.Bool,
            mode        = 'RO',
        ))

        self.add(pr.RemoteCommand(
            name        = 'ClearEvent',
            description = 'Release EVENT in interrupt mode; ignored in comparator mode',
            offset      = (0x01 << 2),
            bitSize     = 1,
            bitOffset   = 5,
            function    = _tse2004avClearEvent,
        ))

        self.add(pr.RemoteVariable(
            name        = 'EventLock',
            description = 'Lock high/low limits and related controls until sensor power-on reset',
            offset      = (0x01 << 2),
            bitSize     = 1,
            bitOffset   = 6,
            base        = pr.Bool,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CriticalLock',
            description = 'Lock the critical limit and related controls until sensor power-on reset',
            offset      = (0x01 << 2),
            bitSize     = 1,
            bitOffset   = 7,
            base        = pr.Bool,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Shutdown',
            description = 'Stop temperature conversion; either limit lock prevents setting this bit',
            offset      = (0x01 << 2),
            bitSize     = 1,
            bitOffset   = 8,
            base        = pr.Bool,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Hysteresis',
            description = 'Temperature drop needed to release an event; frozen by either limit lock',
            offset      = (0x01 << 2),
            bitSize     = 2,
            bitOffset   = 9,
            base        = pr.UInt,
            mode        = 'RW',
            enum        = {0: 'Disabled', 1: '1.5 degC', 2: '3 degC', 3: '6 degC'},
        ))

        # A LinkVariable keeps the raw read interface without overlapping the
        # RemoteVariables: an RO hardware alias would mask their verification.
        self.add(pr.LinkVariable(
            name         = 'Configuration',
            description  = 'Configuration register readback; write the named control fields',
            mode         = 'RO',
            disp         = '0x{:04x}',
            linkedGet    = _tse2004avConfigurationGet,
            dependencies = [self.EventMode, self.EventPolarity, self.CriticalOnly,
                            self.EventEnable, self.EventStatus, self.EventLock,
                            self.CriticalLock, self.Shutdown, self.Hysteresis],
        ))

        self.add(pr.RemoteVariable(
            name        = 'UpperAlarmLimit',
            description = 'Upper Alarm Temperature Limit Register',
            offset      = (0x02 << 2),
            bitSize     = 16,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LowerAlarmLimit',
            description = 'Lower Alarm Temperature Limit Register',
            offset      = (0x03 << 2),
            bitSize     = 16,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CriticalLimit',
            description = 'Critical Temperature Limit Register',
            offset      = (0x04 << 2),
            bitSize     = 16,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'AmbientTemperature',
            description = 'Ambient Temperature Register',
            offset      = (0x05 << 2),
            bitSize     = 16,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))

        self.add(pr.LinkVariable(
            name         = 'Temperature',
            description  = 'Decoded ambient temperature (JC-42.4 signed 13-bit field at 0.0625 degC per count, alarm flag bits discarded)',
            mode         = 'RO',
            units        = 'degC',
            disp         = '{:.4f}',
            linkedGet    = _tse2004avTemperatureGet,
            dependencies = [self.AmbientTemperature],
        ))

        self.add(pr.RemoteVariable(
            name        = 'ManufacturerId',
            description = 'Manufacturer ID Register',
            offset      = (0x06 << 2),
            bitSize     = 16,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DeviceIdRevision',
            description = 'Device ID and Revision Register',
            offset      = (0x07 << 2),
            bitSize     = 16,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))
