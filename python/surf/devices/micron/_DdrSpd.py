#-----------------------------------------------------------------------------
# Title      : PyRogue Lookup tool at www.micron.com/spd
#-----------------------------------------------------------------------------
# Description:
# Decodes DDR4 SPD (Serial Presence Detect) contents.
# PyRogue Lookup tool at www.micron.com/spd
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

# Medium timebase used by the DDR4 SPD minimum-cycle-time field (byte 18),
# in picoseconds. Declared by name rather than as a bare literal so the
# assumption it encodes is visible where it is used.
SPD_MTB_MEDIUM_PS_C = 125

# SDRAM density code (low 4 bits of byte 4) to per-die density in megabits.
_SPD_DENSITY_MB_TABLE = {
    0: 256,
    1: 512,
    2: 1024,
    3: 2048,
    4: 4096,
    5: 8192,
    6: 16384,
    7: 32768,
    8: 12288,
    9: 24576,
}

# -----------------------------------------------------------------------------
# The byte offsets and field encodings decoded below are carried verbatim
# from this project's own decisions and were NOT independently re-derived
# from a JEDEC specification document or from the fitted part's datasheet:
#   - byte 4:  SDRAM density, low 4 bits, coded per _SPD_DENSITY_MB_TABLE
#   - byte 12: module organisation; low 3 bits are the device-width code
#     (0 => 4 bits wide), bits 5:3 are the package-rank count minus one
#   - byte 13: module memory bus width; low 3 bits are the primary-bus-width
#     code (0 => 8 bits wide), bits 4:3 are the ECC-width code
#   - byte 18: minimum average cycle time (tCKAVGmin) in units of the medium
#     timebase (125 ps)
#   - byte 14 bit 7: module thermal sensor presence flag
# If any offset or encoding above is wrong, these functions will return a
# plausible-looking but incorrect value; that risk is only retired by
# comparing a real board read against the parts actually fitted.
# -----------------------------------------------------------------------------

def spdSdramDensityMb(byte4):
    code = byte4 & 0x0F
    return _SPD_DENSITY_MB_TABLE.get(code, 0)

def spdDeviceWidth(byte12):
    code = byte12 & 0x07
    if code > 3:
        return 0
    return 4 << code

def spdPackageRanks(byte12):
    return ((byte12 >> 3) & 0x07) + 1

def spdPrimaryBusWidth(byte13):
    code = byte13 & 0x07
    if code > 3:
        return 0
    return 8 << code

def spdEccBits(byte13):
    code = (byte13 >> 3) & 0x03
    if code == 1:
        return 8
    return 0

def spdThermalSensorPresent(byte14):
    """DDR4 SPD byte 14 bit 7 is the Module Thermal Sensor presence flag, 1
    when the module incorporates a JC-42.4 thermal sensor and 0 when it does
    not. The sensor is optional and commonly omitted on non-ECC modules. The
    bool() call is load bearing: the field is displayed, and an int would
    render as a digit rather than as a word."""
    return bool((byte14 >> 7) & 0x01)

def spdTotalCapacityMiB(byte4, byte12, byte13):
    densityMb = spdSdramDensityMb(byte4)
    deviceWidth = spdDeviceWidth(byte12)
    if deviceWidth == 0:
        return 0
    primaryBusWidth = spdPrimaryBusWidth(byte13)
    packageRanks = spdPackageRanks(byte12)
    miBPerDie = densityMb // 8
    diesPerRank = primaryBusWidth // deviceWidth
    return miBPerDie * diesPerRank * packageRanks

def spdTckAvgMinPs(byte18):
    return byte18 * SPD_MTB_MEDIUM_PS_C

def spdSpeedBinMtps(byte18):
    if byte18 == 0:
        return 0
    tckPs = spdTckAvgMinPs(byte18)
    return round(2000000 / tckPs)

def decodeSpdPage0(pageBytes):
    byte4  = pageBytes[4]  & 0xFF
    byte12 = pageBytes[12] & 0xFF
    byte13 = pageBytes[13] & 0xFF
    byte14 = pageBytes[14] & 0xFF
    byte18 = pageBytes[18] & 0xFF
    return {
        'SdramDensityMb'  : spdSdramDensityMb(byte4),
        'DeviceWidth'     : spdDeviceWidth(byte12),
        'PackageRanks'    : spdPackageRanks(byte12),
        'PrimaryBusWidth' : spdPrimaryBusWidth(byte13),
        'EccBits'         : spdEccBits(byte13),
        'TotalCapacityMiB': spdTotalCapacityMiB(byte4, byte12, byte13),
        'TckAvgMinPs'     : spdTckAvgMinPs(byte18),
        'SpeedBinMtps'    : spdSpeedBinMtps(byte18),
        'ThermalSensorPresent': spdThermalSensorPresent(byte14),
    }

def _spdPage0LinkGet(key):
    """Return a linkedGet callback that decodes the memory array's current
    value list and pulls out one page-0 field. One read of the array (the
    first dependency) satisfies every field's getter."""
    def _get(dev, var, read=True):
        pageBytes = var.dependencies[0].get(read=read)
        return decodeSpdPage0(pageBytes)[key]
    return _get

def _spdPage0SummaryGet(dev, var, read=True):
    pageBytes = var.dependencies[0].get(read=read)
    d = decodeSpdPage0(pageBytes)
    eccNote = ' (+ECC)' if d['EccBits'] else ''
    return (
        f"{d['TotalCapacityMiB']}MiB, {d['PackageRanks']}Rx{d['DeviceWidth']}, "
        f"{d['PrimaryBusWidth']}-bit bus{eccNote}, DDR4-{d['SpeedBinMtps']}"
    )

class DdrSpd(pr.Device):
    def __init__(   self,
            description = "Lookup tool at www.micron.com/spd",
            nelms       = 0x100,
            instantiate = True,
            hidden      = True,
            **kwargs):
        super().__init__(description=description, hidden=hidden, **kwargs)

        if (instantiate):
            self.add(pr.RemoteVariable(
                name        = "Mem",
                description = "Memory Array",
                offset      = 0,
                size        = (4*nelms),
                numValues   = nelms,
                valueBits   = 32,
                valueStride = 32,
                bitSize     = 32 * nelms,
                hidden      = True,
                # mode      = "RO",
            ))

            self.add(pr.LinkVariable(
                name         = 'SdramDensityMb',
                description  = 'SDRAM capacity per die',
                mode         = 'RO',
                units        = 'Mb',
                disp         = '{:d}',
                linkedGet    = _spdPage0LinkGet('SdramDensityMb'),
                dependencies = [self.Mem],
            ))

            self.add(pr.LinkVariable(
                name         = 'DeviceWidth',
                description  = 'SDRAM device width',
                mode         = 'RO',
                units        = 'bits',
                disp         = '{:d}',
                linkedGet    = _spdPage0LinkGet('DeviceWidth'),
                dependencies = [self.Mem],
            ))

            self.add(pr.LinkVariable(
                name         = 'PackageRanks',
                description  = 'Number of ranks per module',
                mode         = 'RO',
                disp         = '{:d}',
                linkedGet    = _spdPage0LinkGet('PackageRanks'),
                dependencies = [self.Mem],
            ))

            self.add(pr.LinkVariable(
                name         = 'PrimaryBusWidth',
                description  = 'Module primary bus width',
                mode         = 'RO',
                units        = 'bits',
                disp         = '{:d}',
                linkedGet    = _spdPage0LinkGet('PrimaryBusWidth'),
                dependencies = [self.Mem],
            ))

            self.add(pr.LinkVariable(
                name         = 'EccBits',
                description  = 'Module bus width extension for ECC',
                mode         = 'RO',
                units        = 'bits',
                disp         = '{:d}',
                linkedGet    = _spdPage0LinkGet('EccBits'),
                dependencies = [self.Mem],
            ))

            self.add(pr.LinkVariable(
                name         = 'TotalCapacityMiB',
                description  = 'Total module capacity',
                mode         = 'RO',
                units        = 'MiB',
                disp         = '{:d}',
                linkedGet    = _spdPage0LinkGet('TotalCapacityMiB'),
                dependencies = [self.Mem],
            ))

            self.add(pr.LinkVariable(
                name         = 'TckAvgMinPs',
                description  = 'Minimum SDRAM cycle time (tCKAVGmin)',
                mode         = 'RO',
                units        = 'ps',
                disp         = '{:d}',
                linkedGet    = _spdPage0LinkGet('TckAvgMinPs'),
                dependencies = [self.Mem],
            ))

            self.add(pr.LinkVariable(
                name         = 'SpeedBinMtps',
                description  = 'Module speed bin (data rate)',
                mode         = 'RO',
                units        = 'MT/s',
                disp         = '{:d}',
                linkedGet    = _spdPage0LinkGet('SpeedBinMtps'),
                dependencies = [self.Mem],
            ))

            self.add(pr.LinkVariable(
                name         = 'ThermalSensorPresent',
                description  = 'Module carries a JC-42.4 thermal sensor',
                mode         = 'RO',
                linkedGet    = _spdPage0LinkGet('ThermalSensorPresent'),
                dependencies = [self.Mem],
            ))

            self.add(pr.LinkVariable(
                name         = 'Page0Summary',
                description  = 'One-line human-readable summary of the decoded page-0 fields',
                mode         = 'RO',
                linkedGet    = _spdPage0SummaryGet,
                dependencies = [self.Mem],
            ))
