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
import rogue
import rogue.interfaces.memory as rim

import threading
import queue

# Exception types to catch and mask in _SpdPageProxy._pollWorker. Mirrors
# the transceiver module's page-select proxy, which this class is modelled
# on.
_SPD_POLL_EXC = (rogue.GeneralError, pr.MemoryError) if hasattr(pr, 'MemoryError') else (rogue.GeneralError,)

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

# -----------------------------------------------------------------------------
# Absolute-to-relative byte offset arithmetic for the page-1 decoded fields
# below: SPD absolute byte N on page 1 (bytes 256-511) sits at page-relative
# offset N-256. Serial number is absolute bytes 325-328 (relative 69-72),
# part number is absolute bytes 329-348 (relative 73-92). These fields are
# unreadable until the device map gains the page-select slave addresses
# (see _SpdPageProxy).
# -----------------------------------------------------------------------------

def _spdPage1SerialNumberGet(dev, var, read=True):
    pageBytes = var.dependencies[0].get(read=read)
    raw = bytes(int(b) & 0xFF for b in pageBytes[69:73])
    return raw.hex()

def _spdPage1PartNumberGet(dev, var, read=True):
    pageBytes = var.dependencies[0].get(read=read)
    raw = bytes(int(b) & 0xFF for b in pageBytes[73:93])
    return raw.decode('ascii', errors='replace').rstrip(' ')

class DdrSpdPage1(pr.Device):
    """Upper 256 bytes (page 1) of the DDR4 SPD EEPROM, exposed the same way
    the parent's page 0 is: a hidden Mem array plus decoded link variables.
    Unreachable until _SpdPageProxy's page-select slaves exist in the device
    map; ships as a child of DdrSpd with its enable false for exactly that
    reason."""
    def __init__(self, nelms=0x100, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name        = 'Mem',
            description = 'Memory Array (page 1, absolute SPD bytes 256-511)',
            offset      = 0,
            size        = (4*nelms),
            numValues   = nelms,
            valueBits   = 32,
            valueStride = 32,
            bitSize     = 32 * nelms,
            hidden      = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'SerialNumber',
            description  = 'Module serial number (absolute SPD bytes 325-328)',
            mode         = 'RO',
            linkedGet    = _spdPage1SerialNumberGet,
            dependencies = [self.Mem],
        ))

        self.add(pr.LinkVariable(
            name         = 'PartNumber',
            description  = 'Module part number (absolute SPD bytes 329-348)',
            mode         = 'RO',
            linkedGet    = _spdPage1PartNumberGet,
            dependencies = [self.Mem],
        ))

class _SpdPageProxy(pr.Device):
    """Serializes access to the DDR4 SPD's upper page (page 1) behind the two
    page-select I2C slave addresses: 0x36 selects the lower page (the
    power-up default) and 0x37 selects the upper page. These are separate
    seven-bit I2C slave addresses, not a register inside the SPD slave
    itself, and unlike the transceiver module's page select they are absent
    from the device map of the bitstream currently on the board. spa0Offset
    and spa1Offset predict where those two slaves will land in a later
    four-entry device map, where device select moves to araddr bits 11:10
    and the SPD stays at device 0: the two page-select slaves fall at the
    device-1 and device-2 windows, 0x400 and 0x800. They are constructor
    parameters, not baked-in constants, precisely so that prediction can be
    corrected here without a second edit to this file once the real map
    exists.

    Modelled on surf.devices.transceivers._Qsfp's _UpperPageProxy, with one
    addition: after servicing an upper-page transaction the worker restores
    the lower-page select, so a page-1 read cannot leave the device selected
    on the upper page for the next page-0 reader."""
    def __init__(self, spa0Offset, spa1Offset, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.LocalVariable(
            name        = 'ErrorCount',
            description = 'I2C page-select failures masked by the worker (cumulative since Rogue start)',
            mode        = 'RO',
            value       = 0,
            typeStr     = 'UInt32',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SelectLowerPage',
            description = 'Page-select command to slave 0x36 (lower page, power-up default)',
            offset      = spa0Offset,
            bitSize     = 8,
            mode        = 'WO',
            hidden      = True,
            groups      = ['NoStream', 'NoState', 'NoConfig'],
        ))

        self.add(pr.RemoteVariable(
            name        = 'SelectUpperPage',
            description = 'Page-select command to slave 0x37 (upper page)',
            offset      = spa1Offset,
            bitSize     = 8,
            mode        = 'WO',
            hidden      = True,
            groups      = ['NoStream', 'NoState', 'NoConfig'],
        ))

        # No separate page buffer variable: on real DDR4 SPD hardware, page 0
        # and page 1 answer at the identical I2C byte-address window (0-255);
        # the internal page-select state, not the address, decides which
        # page's content a read returns. Declaring a second RemoteVariable
        # at that same real address (as the transceiver's UpperPage does at
        # its own, disjoint, byte range) makes Rogue's own root-level
        # overlap check raise NodeError at start() time, because it compares
        # real addresses per memory slave with no exception for this kind of
        # aliasing. The worker below reuses the parent's own Mem variable as
        # the physical access point instead, which is the accurate model:
        # the same address, read after the page-select write below, genuinely
        # returns different content.
        self._lastSelect = None
        self._queue = queue.Queue()
        self._pollThread = threading.Thread(target=self._pollWorker)
        self._pollThread.start()

    def proxyTransaction(self, transaction):
        self._queue.put(transaction)

    def _pollWorker(self):
        while True:
            transaction = self._queue.get()
            if transaction is None:
                return
            with self._memLock, transaction.lock():
                try:
                    regIndex = (transaction.address() >> 2) & 0xFF

                    if self._lastSelect != 'upper':
                        self.SelectUpperPage.set(value=1, write=True)
                        self._lastSelect = 'upper'

                    if (transaction.type() == rim.Write) or (transaction.type() == rim.Post):
                        dataBa = bytearray(4)
                        transaction.getData(dataBa, 0)
                        data = int.from_bytes(dataBa, 'little', signed=False)
                        self.parent.Mem.set(index=regIndex, value=data, write=True)
                        transaction.done()
                    else:
                        data = self.parent.Mem.get(index=regIndex, read=True)
                        dataBa = bytearray(int(data).to_bytes(4, 'little', signed=False))
                        transaction.setData(dataBa, 0)
                        transaction.done()

                    # Restore the power-up default so this transaction cannot
                    # leave the SPD selected on the upper page for the next
                    # page-0 reader.
                    self.SelectLowerPage.set(value=1, write=True)
                    self._lastSelect = 'lower'

                except _SPD_POLL_EXC:
                    try:
                        tt = transaction.type()
                        if (tt == rim.Write) or (tt == rim.Post):
                            transaction.done()
                        else:
                            dataBa = bytearray(4)
                            transaction.setData(dataBa, 0)
                            transaction.done()
                    except Exception:
                        pass
                    try:
                        self.ErrorCount.set(self.ErrorCount.value() + 1, write=False)
                    except Exception:
                        pass

    def _stop(self):
        self._queue.put(None)
        self._pollThread.join()

class _SpdProxySlave(rim.Slave):

    def __init__(self, pageProxy):
        super().__init__(4, 4)
        self._pageProxy = pageProxy

    def _doTransaction(self, transaction):
        self._pageProxy.proxyTransaction(transaction)

class DdrSpd(pr.Device):
    def __init__(   self,
            description = "Lookup tool at www.micron.com/spd",
            nelms       = 0x100,
            instantiate = True,
            hidden      = True,
            spa0Offset  = 0x400,
            spa1Offset  = 0x800,
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

            self.pageProxy = _SpdPageProxy(
                name       = 'PageProxy',
                spa0Offset = spa0Offset,
                spa1Offset = spa1Offset,
                memBase    = self,
                offset     = 0,
                hidden     = True,
            )
            self.add(self.pageProxy)

            self.pageProxySlave = _SpdProxySlave(self.pageProxy)

            self.add(DdrSpdPage1(
                name    = 'Page1',
                nelms   = nelms,
                memBase = self.pageProxySlave,
                offset  = (1 << 10), # Page 1 plus 1 mem address region offset, matching the transceiver's page-plus-one convention
                enabled = False,
                hidden  = True,
            ))
