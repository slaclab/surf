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
import rogue.interfaces.memory as rim

import threading
import queue

# Each SPD byte occupies one 32-bit word in the FPGA's I2C register window.
_SPD_PAGE_BYTES_C = 0x100 * 4

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
            mode        = 'RO',
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
    """Own both logical pages' read access to the physical SPD window.

    DdrSpd is the virtual memory hub and queues its requests here. The worker
    uses the hub's downstream Master API, bypassing both logical Mem caches.
    One request can cover a full page; selection, all word accesses, and
    restoration run as a single sequence relative to other SPD requests.

    spa0Offset/spa1Offset address the FPGA windows for I2C slaves 0x36/0x37,
    relative to DdrSpd's physical base. They are private transport addresses,
    so bulk variable writes cannot trigger page selection. Page 0 initially
    uses the EEPROM's power-up selection without touching these windows.
    Enabling Page1 opts into page selection. Once used, selectors remain in
    use even if Page1 is disabled, allowing recovery after a failed restore.
    """
    def __init__(self, spa0Offset, spa1Offset, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.LocalVariable(
            name        = 'ErrorCount',
            description = 'Failed SPD transactions, including page selection and restoration failures',
            mode        = 'RO',
            value       = 0,
            typeStr     = 'UInt32',
        ))

        self._selectOffsets = (spa0Offset, spa1Offset)
        self._pageSelectUsed = False
        self._queue = queue.Queue()
        self._queueLock = threading.Lock()
        self._accepting = False
        self._pollThread = None

    def _start(self):
        with self._queueLock:
            if self._pollThread is None:
                self._accepting = True
                self._pollThread = threading.Thread(target=self._pollWorker, name=self.path)
                self._pollThread.start()
        super()._start()

    def proxyTransaction(self, transaction):
        # Queue insertion and the shutdown sentinel must be ordered together.
        with self._queueLock:
            if self._accepting:
                self._queue.put(transaction)
                return
        with transaction.lock():
            if not transaction.expired():
                transaction.error('SPD proxy is not running')

    def _transfer(self, offset, data, transactionType):
        # Master requests go directly downstream from the virtual DdrSpd hub.
        # Add only its own physical offset; ancestor hubs add theirs later.
        master = self.parent
        master._clearError()
        tid = master._reqTransaction(master.offset + offset, data, len(data), 0, transactionType)
        master._waitTransaction(tid)
        error = master._getError()
        if error:
            raise RuntimeError(f'SPD access at offset 0x{offset:x}: {error}')

    def _selectPage(self, page):
        self._transfer(self._selectOffsets[page], bytearray([1, 0, 0, 0]), rim.Write)

    def _serviceTransaction(self, transaction):
        error = None
        restore = False
        data = None
        try:
            # Use a private read buffer and release the transaction lock
            # during downstream I/O so the caller can still time out.
            with transaction.lock():
                if transaction.expired():
                    return
                address = transaction.address()
                size = transaction.size()
                transactionType = transaction.type()

            # Validate the captured metadata outside the Rogue lock context;
            # its Python binding does not support exception unwinding.
            if transactionType != rim.Read:
                raise ValueError('SPD memory is read-only; only Read transactions are supported')
            page, offset = divmod(address, _SPD_PAGE_BYTES_C)
            if (page > 1 or address % 4 or size == 0 or size % 4
                    or offset + size > self.parent.Mem.numValues * 4):
                raise ValueError(f'Invalid SPD transaction: address=0x{address:x}, size={size}')
            data = bytearray(size)

            if not self._accepting:
                raise RuntimeError('SPD proxy is stopping')
            page1Enabled = self.parent.Page1.enable.value() is True
            if page == 1 and not page1Enabled:
                raise RuntimeError('SPD page 1 is disabled')

            if page1Enabled or self._pageSelectUsed:
                self._pageSelectUsed = True
                # An unsuccessful SPA1 may still have changed the hardware.
                # Attempt SPA0 even if the select or data transaction fails.
                restore = (page == 1)
                self._selectPage(page)

            for index in range(0, size, 4):
                with transaction.lock():
                    if transaction.expired():
                        break
                if not self._accepting:
                    raise RuntimeError('SPD proxy is stopping')
                word = bytearray(4)
                self._transfer(offset + index, word, rim.Read)
                data[index:index+4] = word

        except Exception as exc:
            error = str(exc)
        finally:
            if restore:
                try:
                    self._selectPage(0)
                except Exception as exc:
                    restoreError = f'Failed to restore SPD page 0: {exc}'
                    error = f'{error}; {restoreError}' if error else restoreError

        if error:
            self.ErrorCount.set(self.ErrorCount.value() + 1, write=False)

        # Complete once, after cleanup, and never publish data from a failed
        # request or touch a caller buffer that has already expired.
        with transaction.lock():
            if transaction.expired():
                return
            if error:
                transaction.error(error)
            else:
                transaction.setData(data, 0)
                transaction.done()

    def _pollWorker(self):
        while True:
            transaction = self._queue.get()
            if transaction is None:
                return
            with self._memLock:
                self._serviceTransaction(transaction)

    def _stop(self):
        with self._queueLock:
            self._accepting = False
            thread = self._pollThread
            if thread is not None:
                self._queue.put(None)
        if thread is not None:
            thread.join()
            self._pollThread = None
        super()._stop()

class DdrSpd(pr.Device):
    """Read-only DDR4 SPD with independent page caches over one physical window.

    offset/memBase describe the physical FPGA I2C bridge. Mem and Page1.Mem
    use virtual addresses 0x000 and 0x400 within this device. Page1 is disabled
    initially; enable it only when spa0Offset/spa1Offset map the page-select
    slaves in the firmware. All access affected by these selectors must pass
    through this device; external bus masters require separate coordination.
    EEPROM programming is unsupported; only private page-selection writes
    are issued to the hardware.
    """
    def __init__(   self,
            description = "Lookup tool at www.micron.com/spd",
            nelms       = 0x100,
            instantiate = True,
            hidden      = True,
            spa0Offset  = 0x400,
            spa1Offset  = 0x800,
            **kwargs):
        self._instantiate = instantiate
        super().__init__(
            description = description,
            hidden      = hidden,
            hubMin      = 4 if instantiate else 0,
            hubMax      = _SPD_PAGE_BYTES_C if instantiate else 0,
            **kwargs)

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
                mode        = "RO",
                hidden      = True,
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
                offset     = 0,
                hidden     = True,
            )
            self.add(self.pageProxy)

            self.add(DdrSpdPage1(
                name    = 'Page1',
                nelms   = nelms,
                offset  = _SPD_PAGE_BYTES_C,
                enabled = False,
                hidden  = True,
            ))

    def _doTransaction(self, transaction):
        if self._instantiate:
            self.pageProxy.proxyTransaction(transaction)
        else:
            super()._doTransaction(transaction)
