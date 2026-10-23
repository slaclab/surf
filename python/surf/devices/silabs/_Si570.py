#-----------------------------------------------------------------------------
# Title      : PyRogue Si570 model
#-----------------------------------------------------------------------------
# Description:
# Si570 I2C programmable XO register map and frequency programming procedure
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

from __future__ import annotations

import time
from typing import Any

import pyrogue as pr
import rogue
import rogue.interfaces.memory as rim

# Datasheet nominal internal crystal frequency (MHz), used for readback only
# until fxtal is calibrated. Actual parts vary by up to +/-2000 ppm.
_FXTAL_NOMINAL = 114.285

# Datasheet Table 11 bounds fxtal to +/-2000 ppm of nominal. A calibration
# outside this wider margin means factory_freq is wrong or the part keeps its
# configuration in registers 13-18 (7 ppm stability), not a real crystal
_FXTAL_MAX_PPM = 3000

# DCO frequency range (MHz)
_FDCO_MIN = 4850.0
_FDCO_MAX = 5670.0

# Changes within this window of the center frequency (the last NewFreq or
# RECALL) only retune RFREQ, so the output does not stop (datasheet 3.1.1)
_SMALL_CHANGE_PPM = 3500

# Self-clearing bits in register 135 are polled at this period until clear
_POLL_PERIOD  = 0.001
_POLL_TIMEOUT = 1.0

class Si570(pr.Device):
    """PyRogue model for the Si570 I2C programmable XO.

    Only the 20 ppm and 50 ppm temperature stability parts (configuration
    registers 7-12) are supported.

    Parameters
    ----------
    factory_freq : float
        Factory start-up (NVM) output frequency in MHz, from the part number.
        Used to calibrate the per-device internal crystal frequency.
    max_freq : float, optional
        Highest output frequency in MHz the part's speed grade supports
        (1417.5 for grade A, 810 for grade B, 280 for grade C). ``Frequency``
        requests above it raise ``ValueError``. Defaults to 1417.5.
    **kwargs : Any
        Additional arguments forwarded to ``pyrogue.Device``.

    Notes
    -----
    The internal crystal frequency (fxtal) varies by up to +/-2000 ppm
    between parts and must be calibrated per device. Executing ``RECALL``
    reloads the factory configuration and calibrates ``fxtal``; setting
    ``Frequency`` does this automatically the first time. A calibration
    more than 3000 ppm from nominal raises ``ValueError`` instead of
    programming a wrong output frequency.

    RECALL returns the output to the factory frequency until the new
    configuration is applied, so the first ``Frequency`` write stops and
    restarts the output twice rather than once. Downstream logic that is
    sensitive to clock interruptions, such as MGT reference clocks, should
    expect this on the first write after start-up.

    A request within +/-3500 ppm of the center frequency (the last NewFreq or
    RECALL) that the current dividers can reach only retunes RFREQ under
    Freeze M, so the output changes without stopping. Larger changes use the
    full freeze, write, unfreeze and NewFreq sequence.

    Registers 7-12 are excluded from bulk register writes. A bulk write such
    as ``WriteAll`` or ``LoadConfig`` that changes them is applied with the
    full sequence instead of raw register writes; an invalid staged
    configuration (for example a cache that was never read) is not written.
    """

    def __init__(self, factory_freq: float, max_freq: float = 1417.5, **kwargs: Any) -> None:
        """Create the Si570 model."""
        super().__init__(**kwargs)
        self.factory_freq = factory_freq
        self.max_freq = max_freq
        self._centerFdco = None
        self._applying = False

        ADDR_SIZE = 4

        for i in range(7, 13):
            self.add(pr.RemoteVariable(
                name        = f'Config[{i}]',
                description = 'Entire configuration space as an array of registers',
                offset      = i * ADDR_SIZE,
                bitOffset   = 0,
                bitSize     = 8,
                hidden      = True,
                overlapEn   = True,
                bulkOpEn    = False))

        # Extract N1 register value
        def n1_raw_get(read: bool) -> int:
            high = self.Config[7].get(read=read)
            low = self.Config[8].get(read=read)
            return ((high & 0x1f) << 2) | ((low & 0xc0) >> 6)

        def n1_raw_set(value: int, write: bool) -> None:
            high = self.Config[7].value() & 0xe0
            low = self.Config[8].value() & 0x3f

            high |= (value & 0b01111100) >> 2
            low |= (value & 0x3) << 6

            self.Config[7].set(high, write=write)
            self.Config[8].set(low, write=write)

        self.add(pr.LinkVariable(
            name         = 'N1_RAW',
            description  = 'Raw N1 divider register value before decoding',
            dependencies = [self.Config[7], self.Config[8]],
            hidden       = True,
            linkedGet    = n1_raw_get,
            linkedSet    = n1_raw_set))

        def n1_set(value: int, write: bool) -> None:
            if value != 1 and (value % 2 != 0 or not 2 <= value <= 128):
                raise ValueError(f'Si570 N1 must be 1 or an even number from 2 to 128, got {value}')
            self.N1_RAW.set(value-1, write=write)

        self.add(pr.LinkVariable(
            name         = 'N1',
            description  = """
            Sets the value for CLKOUT output divider.
            Can be 1 or any even number up to 128.
            Value will be formatted for register as described on datasheet page 23""",
            dependencies = [self.N1_RAW],
            linkedGet    = lambda read: self.N1_RAW.get(read=read) + 1,
            linkedSet    = n1_set))

        # Enum for HS_DIV
        self.add(pr.RemoteVariable(
            name        = 'HS_DIV',
            description = 'Sets value for high speed divider that takes the DCO output fOSC as its clock input',
            overlapEn   = True,
            bulkOpEn    = False,
            offset      = 7 * ADDR_SIZE,
            bitSize     = 3,
            bitOffset   = 5,
            enum        = {
                0: '4',
                1: '5',
                2: '6',
                3: '7',
                5: '9',
                7: '11'}))

        # Map enum to link variable for setting as int
        self.add(pr.LinkVariable(
            name         = 'HS_DIV_INT',
            description  = 'Sets value for high speed divider that takes the DCO output fOSC as its clock input',
            hidden       = True,
            dependencies = [self.HS_DIV],
            linkedGet    = lambda read: int(self.HS_DIV.getDisp(read=read)),
            linkedSet    = lambda value, write: self.HS_DIV.setDisp(str(value), write=write)))

        # Extract RFREQ[37:0] from registers
        def rfreq_raw_get(read: bool) -> int:
            ret = 0
            for i in range(8, 13):
                ret = ret << 8 | self.Config[i].get(read=read)

            ret &= 0x3fffffffff
            return ret

        def rfreq_raw_set(value: int, write: bool) -> None:
            tmp = value
            for i in reversed(range(8, 13)):
                if i == 8:
                    old = self.Config[i].get(read=False)
                    tmp = (tmp & 0x3f) | (old & 0xc0)
                self.Config[i].set(tmp&0xFF, write=write)
                tmp = tmp >> 8

        self.add(pr.LinkVariable(
            name         = 'RFREQ_RAW',
            description  = 'Frequency control input to DCO',
            disp         = '0x{:x}',
            hidden       = True,
            dependencies = [self.Config[x] for x in range(8,13)],
            linkedGet    = rfreq_raw_get,
            linkedSet    = rfreq_raw_set))


        self.add(pr.LinkVariable(
            name         = 'RFREQ',
            description  = 'Frequency control input to DCO, formatted from fixed point',
            dependencies = [self.RFREQ_RAW],
            linkedGet    = lambda read: self.RFREQ_RAW.get(read=read) / 2**28,
            linkedSet    = lambda value, write: self.RFREQ_RAW.set(round(value*2**28), write=write)))

        # RST_REG, NewFreq, FreezeM and RECALL share register 135, so every
        # write of that register replays the cached value of all four bits
        def pulse(cmd: pr.RemoteCommand, i2c_reset: bool = False) -> None:
            try:
                # Never replay a cached self-clearing bit with this pulse
                for bit in (self.RST_REG, self.NewFreq, self.RECALL):
                    if bit is not cmd and bit.value():
                        bit.set(0, write=False)
                cmd.set(1)

                # The device clears the bit on completion, and the readback
                # also refreshes the cached copy of register 135
                deadline = time.monotonic() + _POLL_TIMEOUT
                while True:
                    try:
                        busy = cmd.get(read=True)
                    except rogue.GeneralError:
                        # RST_REG interrupts the I2C state machine, so reads
                        # fail until the internal reset completes
                        if not i2c_reset or time.monotonic() > deadline:
                            raise
                        busy = True
                    if not busy:
                        break
                    if time.monotonic() > deadline:
                        raise TimeoutError(f'{cmd.path} did not self-clear within {_POLL_TIMEOUT} s')
                    time.sleep(_POLL_PERIOD)
            finally:
                # Keep a later bulk write from replaying an incomplete pulse
                if cmd.value():
                    cmd.set(0, write=False)

        def reset_reg() -> None:
            pulse(self.RST_REG, i2c_reset=True)
            # The part restarts from NVM; the cached center frequency no longer applies
            self._centerFdco = None

        self.add(pr.RemoteCommand(
            name        = 'RST_REG',
            description = """
            Reset of all internal logic. Output tristated during reset.
            Automatically returns to 0 after reset completion.
            Interrupts I2C state machine. Not recommended to use""",
            offset      = 135 * ADDR_SIZE,
            bitOffset   = 7,
            bitSize     = 1,
            hidden      = True,
            function    = reset_reg))

        self.add(pr.RemoteCommand(
            name        = 'NewFreq',
            description = 'Alerts the DSPLL that a new frequency configuration has been applied',
            offset      = 135 * ADDR_SIZE,
            bitOffset   = 6,
            bitSize     = 1,
            hidden      = True,
            function    = pulse))

        self.add(pr.RemoteVariable(
            name        = 'FreezeM',
            description = 'Prevents interim frequency changes when writing RFREQ registers',
            offset      = 135 * ADDR_SIZE,
            bitOffset   = 5,
            bitSize     = 1,
            hidden      = True,
            base        = pr.UInt))

        def recall() -> None:
            pulse(self.RECALL)

            # Registers now hold the factory configuration for factory_freq.
            # Post the six register reads before waiting so the calibration
            # costs one pass over the I2C bridge, not one wait per field
            for i in range(7, 13):
                self.readBlocks(recurse=False, variable=self.Config[i])
            self.checkBlocks(recurse=False)

            rfreq = self.RFREQ.get(read=False)
            if rfreq == 0:
                raise ValueError('Si570 RFREQ reads zero after RECALL; cannot calibrate fxtal')
            fxtal = self.factory_freq * self.HS_DIV_INT.get(read=False) * self.N1.get(read=False) / rfreq
            ppm = (fxtal / _FXTAL_NOMINAL - 1) * 1e6
            if abs(ppm) > _FXTAL_MAX_PPM:
                raise ValueError(
                    f'Si570 calibrated fxtal {fxtal:.6f} MHz is {ppm:+.0f} ppm from nominal '
                    f'{_FXTAL_NOMINAL} MHz (limit +/-{_FXTAL_MAX_PPM} ppm); check factory_freq '
                    f'and that the part uses configuration registers 7-12')
            self.fxtal.set(fxtal)
            self._centerFdco = fxtal * rfreq

        self.add(pr.RemoteCommand(
            name        = 'RECALL',
            description = """
            Write NVM bits into RAM.
            Effectively resets the chip without interrupting I2C.
            Restores the factory output frequency and calibrates fxtal.
            The output runs at the factory frequency until Frequency is written again""",
            offset      = 135 * ADDR_SIZE,
            bitOffset   = 0,
            bitSize     = 1,
            function    = recall))

        # Unverified so unfreeze and NewFreq stay back to back (10 ms limit)
        self.add(pr.RemoteVariable(
            name        = 'FreezeDCO',
            description = 'Freezes the DSPLL so the frequency configuration can be modified',
            hidden      = True,
            offset      = 137 * ADDR_SIZE,
            bitSize     = 1,
            bitOffset   = 4,
            verify      = False,
            bulkOpEn    = False))

        self.add(pr.LocalVariable(
            name         = 'fxtal',
            description  = """
            Internal crystal frequency calculated as described in the datasheet.
            0.0 until calibrated by RECALL, which the first Frequency write performs""",
            mode         = 'RO',
            value        = 0.0,
            units        = 'MHz'))


        n1_array = [1] + [x for x in range(2, 2**7, 2)]
        hs_div_array = [11, 9, 7, 6, 5, 4]

        def find_params(f1: float) -> tuple[int, int]:
            # want low N1 and high HS_DIV
            if f1 >= 10:
                for n1 in n1_array:
                    for hs_div in hs_div_array:
                        fdco = f1 * hs_div * n1
                        if 4850 <= fdco <= 5670:
                            return n1, hs_div
            raise ValueError(f'Si570 cannot generate {f1} MHz; supported ranges are 10-945, 970-1134 and 1212.5-1417.5 MHz')

        def set_freq(value: float, write: bool) -> None:
            if write is False:
                return
            if self.enable.value() is not True:
                self._log.warning(f'{self.path} is disabled; Frequency={value} MHz not programmed')
                return

            with self.root.updateGroup():
                n1, hs_div = find_params(value)
                if value > self.max_freq:
                    raise ValueError(f'Si570 {value} MHz is above max_freq={self.max_freq} MHz for this part')

                if self.fxtal.value() == 0.0:
                    self.RECALL()
                fxtal = self.fxtal.value()

                # Small change: keep the dividers and retune RFREQ without stopping the
                # output, only if the part still holds the configuration this driver applied
                fdco = value * self.HS_DIV_INT.value() * self.N1.value()
                if (self._centerFdco is not None and _FDCO_MIN <= fdco <= _FDCO_MAX
                        and abs(fdco / self._centerFdco - 1) < _SMALL_CHANGE_PPM * 1e-6
                        and self._readHwConfig() == [v.value() for v in self._configVars()]):
                    self._smallChange(fdco / fxtal)
                    return

                self.N1.set(n1, write=False)
                self.HS_DIV_INT.set(hs_div, write=False)
                self.RFREQ.set(value * hs_div * n1 / fxtal, write=False)
                self._applyConfig()

        def get_freq(read: bool) -> float:
            n1 = self.N1.get(read=read)
            hs_div = self.HS_DIV_INT.get(read=read)
            rfreq = self.RFREQ.get(read=read)
            fxtal = self.fxtal.value() or _FXTAL_NOMINAL

            return (fxtal * rfreq)/(hs_div * n1)


        self.add(pr.LinkVariable(
            name         = 'Frequency',
            description  = """
            Set the frequency in MHz.
            Automatically calculates all register values and performs the frequency update procedure described in the datasheet.
            Changes within +/-3500 ppm of the last large change only retune RFREQ and do not stop the output.
            Readback uses the nominal fxtal (+/-2000 ppm) until fxtal is calibrated""",
            units        = 'MHz',
            dependencies = [self.N1, self.HS_DIV_INT, self.RFREQ, self.fxtal],
            linkedGet    = get_freq,
            linkedSet    = set_freq))


    def _configVars(self) -> list[pr.RemoteVariable]:
        return [self.Config[i] for i in range(7, 13)]

    def _readHwConfig(self) -> list[int]:
        """Read registers 7-12 from the part without touching the variable cache."""
        # Transactions this Hub starts itself do not get its offset added
        regs = []
        for i in range(7, 13):
            data = bytearray(4)
            tid = self._reqTransaction(self.offset + i * 4, data, 4, 0, rim.Read)
            self._waitTransaction(tid)
            err = self._getError()
            if err:
                raise pr.MemoryError(name=self.path, address=self.address + i * 4, msg=err)
            regs.append(data[0])
        return regs

    def _validConfig(self, regs: list[int]) -> bool:
        """True if registers 7-12 describe a configuration the DCO can run."""
        if (regs[0] >> 5) not in (0, 1, 2, 3, 5, 7):
            return False
        n1 = (((regs[0] & 0x1f) << 2) | (regs[1] >> 6)) + 1
        if n1 != 1 and n1 % 2 != 0:
            return False
        rfreq = int.from_bytes(bytes([regs[1] & 0x3f] + regs[2:]), 'big') / 2**28
        fdco = (self.fxtal.value() or _FXTAL_NOMINAL) * rfreq
        margin = _FXTAL_MAX_PPM * 1e-6
        return _FDCO_MIN * (1 - margin) <= fdco <= _FDCO_MAX * (1 + margin)

    def _writeConfigRegs(self, variables: list[pr.RemoteVariable]) -> None:
        for v in variables:
            pr.Device.writeBlocks(self, force=True, recurse=False, variable=v)
        for v in variables:
            self.verifyBlocks(recurse=False, variable=v)
        self.waitBlocks(recurse=False)

    def _applyConfig(self) -> None:
        """Write the cached registers 7-12 with the datasheet large-change sequence."""
        self._applying = True
        try:
            # Freeze, refreshing the cached reserved bits of register 137 first
            self.FreezeDCO.get(read=True)
            self.FreezeDCO.set(1, write=True)

            # Write new config
            try:
                self._writeConfigRegs(self._configVars())
            except Exception:
                # A frozen DCO with new dividers outputs a wrong frequency that
                # nothing reports. Unfreeze and apply what the registers now hold
                # so the output matches them, then report the original error
                try:
                    self.FreezeDCO.set(0, write=True)
                    self.NewFreq()
                except Exception as e:
                    self._log.error(f'{self.path}: recovery after a failed configuration write also failed: {e}')
                raise

            # Unfreeze
            self.FreezeDCO.set(0, write=True)

            # NewFreq
            self.NewFreq()

            if self.fxtal.value() != 0.0:
                self._centerFdco = self.fxtal.value() * self.RFREQ.value()
        finally:
            self._applying = False

    def _smallChange(self, rfreq: float) -> None:
        """Retune RFREQ under Freeze M so the output does not stop (datasheet 3.1.1)."""
        self.RFREQ.set(rfreq, write=False)
        self.FreezeM.set(1, write=True)
        try:
            self._writeConfigRegs([self.Config[i] for i in range(8, 13)])
        finally:
            self.FreezeM.set(0, write=True)

    def readBlocks(self, *, recurse: bool = True, variable: Any = None, **kwargs: Any) -> None:
        """Bulk reads (ReadAll) also cover registers 7-12, which are excluded from bulk operations."""
        super().readBlocks(recurse=recurse, variable=variable, **kwargs)
        if variable is None:
            for v in self._configVars():
                super().readBlocks(recurse=False, variable=v, **kwargs)

    def writeBlocks(self, *, force: bool = False, recurse: bool = True, variable: Any = None, **kwargs: Any) -> None:
        """Apply a changed registers 7-12 configuration from a bulk write with the datasheet sequence."""
        super().writeBlocks(force=force, recurse=recurse, variable=variable, **kwargs)
        if variable is None and not self._applying and self.enable.value() is True:
            staged = [v.value() for v in self._configVars()]
            if staged == self._readHwConfig():
                return
            if not self._validConfig(staged):
                self._log.warning(f'{self.path}: staged registers 7-12 {[hex(x) for x in staged]} are not a '
                                  f'valid configuration; not written')
                return
            self._applyConfig()
