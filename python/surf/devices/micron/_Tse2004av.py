#-----------------------------------------------------------------------------
# Title      : PyRogue _Tse2004av Module
#-----------------------------------------------------------------------------
# Description:
# PyRogue _Tse2004av Module
#
# CAVEAT: the register pointer assignments below follow the JC-42.4 standard
# temperature-sensor layout (Capability, Configuration, Alarm limits, Ambient
# Temperature, Manufacturer ID, Device ID/Revision) and were NOT confirmed
# against a TSE2004AV part datasheet in the session that wrote this file. A
# consumer should confirm that ManufacturerId and DeviceIdRevision read
# plausible, fixed values before trusting the writable Configuration and
# alarm-limit registers, since a wrong pointer on a writable register is
# worse than a wrong pointer on a read-only one. The decoded Temperature
# variable below follows the same JC-42.4 scale and sign convention as the
# pointer map above it, was likewise not confirmed against a part datasheet,
# so the identity registers remain the gate a consumer must check first.
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
            name        = 'Configuration',
            description = 'Sensor Configuration Register',
            offset      = (0x01 << 2),
            bitSize     = 16,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
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
