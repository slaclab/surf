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

import math
import time
from typing import Any

import pyrogue as pr

class Si570(pr.Device):
    """Si570 with the configuration bank at registers 7 through 12.

    Parameters
    ----------
    factory_freq : float
        Factory NVM startup frequency in MHz, not the currently programmed rate.
    **kwargs : Any
        PyRogue Device options.

    Notes
    -----
    Call Calibrate explicitly before setting Frequency. It recalls factory NVM,
    changes the output to factory_freq and caches this device's crystal estimate.
    Construction performs no I/O. Before calibration, fxtal/Frequency return NaN.
    Frequency is calculated from registers, not measured. Keep clock consumers
    reset during programming. Raw register edits require the caller to manage
    the freeze/update sequence. Bulk register operations are disabled.
    Si570 7 ppm variants with configuration at registers 13--18 are not supported.
    """

    def __init__(self, factory_freq: float, **kwargs: Any) -> None:
        if not math.isfinite(factory_freq) or factory_freq <= 0:
            raise ValueError('factory_freq must be a positive finite frequency in MHz')
        super().__init__(**kwargs)
        self.factory_freq = factory_freq
        self._fxtal: float | None = None

        ADDR_SIZE = 4

        for i in range(7, 13):
            self.add(pr.RemoteVariable(
                name        = f'Config[{i}]',
                description = 'Entire configuration space as an array of registers',
                offset      = i * ADDR_SIZE,
                bitOffset   = 0,
                bitSize     = 8,
                bulkOpEn    = False,
                hidden      = True,
                overlapEn   = True))

        # Extract N1 register value
        def n1_raw_get(read: bool) -> int:
            high = self.Config[7].get(read=read)
            low = self.Config[8].get(read=read)
            return ((high & 0x1f) << 2) | ((low & 0xc0) >> 6)

        def n1_raw_set(value: int, write: bool) -> None:
            if not 0 <= value <= 127 or (value != 0 and value % 2 == 0):
                raise ValueError('N1 must be 1 or an even integer from 2 through 128')
            high = self.Config[7].get(read=write) & 0xe0
            low = self.Config[8].get(read=write) & 0x3f

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

        self.add(pr.LinkVariable(
            name         = 'N1',
            description  = """
            Sets the value for CLKOUT output divider.
            Can be 1 or any even number up to 128.
            Value will be formatted for register as described on datasheet page 23""",
            dependencies = [self.N1_RAW],
            linkedGet    = lambda read: self.N1_RAW.get(read=read) + 1,
            linkedSet    = lambda value, write: self.N1_RAW.set(value-1, write=write)))

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

        # Extract RFREQ from registers
        def rfreq_raw_get(read: bool) -> int:
            ret = 0
            for i in range(8, 13):
                ret = ret << 8 | self.Config[i].get(read=read)

            ret &= 0x3fffffffff
            return ret

        def rfreq_raw_set(value: int, write: bool) -> None:
            if not 0 <= value < 2**38:
                raise ValueError('RFREQ_RAW must fit in 38 bits')
            tmp = value
            for i in reversed(range(8, 13)):
                if i == 8:
                    old = self.Config[i].get(read=write)
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
            linkedSet    = lambda value, write: self.RFREQ_RAW.set(int(value*2**28), write=write)))

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
            function    = pr.Command.touchOne))

        self.add(pr.RemoteCommand(
            name        = 'NewFreq',
            description = 'Alerts the DSPLL that a new frequency configuration has been applied',
            offset      = 135 * ADDR_SIZE,
            bitOffset   = 6,
            bitSize     = 1,
            hidden      = True,
            function    = pr.Command.touchOne))

        self.add(pr.RemoteVariable(
            name        = 'FreezeM',
            description = 'Prevents interim frequency changes when writing RFREQ registers',
            offset      = 135 * ADDR_SIZE,
            bitOffset   = 5,
            bitSize     = 1,
            hidden      = True,
            base        = pr.UInt,
            bulkOpEn    = False))

        self.add(pr.RemoteCommand(
            name        = 'RECALL',
            description = """
            Write NVM bits into RAM.
            Effectively resets the chip without interrupting I2C""",
            offset      = 135 * ADDR_SIZE,
            bitOffset   = 0,
            bitSize     = 1,
            function    = pr.Command.touchOne))

        self.add(pr.RemoteVariable(
            name        = 'FreezeDCO',
            description = 'Freezes the DSPLL so the frequency configuration can be modified',
            hidden      = True,
            offset      = 137 * ADDR_SIZE,
            bitSize     = 1,
            bulkOpEn    = False,
            bitOffset   = 4))

        def wait_clear(command: Any) -> None:
            # Bound polling; each underlying bus transaction also has its timeout.
            deadline = time.monotonic() + 1.0
            while command.get(read=True):
                if time.monotonic() >= deadline:
                    raise TimeoutError(f'Si570 {command.name} did not complete')
                time.sleep(0.001)

        def calibrate() -> None:
            self._fxtal = None
            # Refresh register 135 so old cached command bits are not replayed.
            self.RECALL.get(read=True)
            self.RECALL()
            wait_clear(self.RECALL)
            rfreq = self.RFREQ.get(read=True)
            n1 = self.N1.get(read=True)
            hs_div = self.HS_DIV_INT.get(read=True)
            if rfreq <= 0 or (n1 != 1 and n1 % 2 != 0):
                raise ValueError('Invalid Si570 factory configuration')
            self._fxtal = self.factory_freq * hs_div * n1 / rfreq

        self.add(pr.LocalCommand(
            name        = 'Calibrate',
            description = 'Recall factory NVM and cache crystal calibration; changes the output clock.',
            function    = calibrate))

        def get_fxtal(read: bool) -> float:
            # Never recompute with factory_freq after the output has been changed.
            return math.nan if self._fxtal is None else self._fxtal

        self.add(pr.LinkVariable(
            name         = 'fxtal',
            description  = 'Cached crystal estimate from Calibrate; NaN until calibrated',
            units        = 'MHz',
            dependencies = [self.RFREQ, self.HS_DIV_INT, self.N1],
            linkedGet    = get_fxtal))


        n1_array = [1] + [x for x in range(2, 2**7 + 1, 2)]
        hs_div_array = [11, 9, 7, 6, 5, 4]

        def find_params(f1: float) -> tuple[int, int]:
            if not math.isfinite(f1) or not 10.0 <= f1 <= 1417.5:
                raise ValueError('Frequency must be finite and within 10--1417.5 MHz; check the part speed grade')
            # want low N1 and high HS_DIV
            for n1 in n1_array:
                for hs_div in hs_div_array:
                    fdco = f1 * hs_div * n1
                    if 4850 <= fdco <= 5670:
                        return n1, hs_div
            raise ValueError('No valid Si570 dividers for the requested frequency')

        def set_freq(value: float, write: bool) -> None:
            if write is False:
                return

            if self._fxtal is None:
                raise RuntimeError('Call Si570.Calibrate before programming Frequency')

            with self.root.updateGroup():
                n1, hs_div = find_params(value)
                fdco = value * hs_div * n1
                rfreq = int(fdco / self._fxtal * 2**28)
                if not 0 < rfreq < 2**38:
                    raise ValueError('Calculated RFREQ does not fit in 38 bits')
                hs_raw = {4: 0, 5: 1, 6: 2, 7: 3, 9: 5, 11: 7}[hs_div]
                n1_raw = n1 - 1
                config = [(hs_raw << 5) | (n1_raw >> 2),
                          ((n1_raw & 3) << 6) | (rfreq >> 32)]
                config += [(rfreq >> shift) & 0xff for shift in (24, 16, 8, 0)]

                # Freeze
                self.FreezeDCO.get(read=True)  # Preserve reserved bits.
                self.NewFreq.get(read=True)  # Refresh command register cache.
                self.FreezeDCO.set(1, write=True, verify=False)
                if self.FreezeDCO.get(read=True) != 1:
                    raise RuntimeError('Si570 did not freeze the DCO')

                # Explicit byte writes do not bulk-write control/command registers.
                for register, byte in zip(range(7, 13), config):
                    # Check write completion before starting a separate readback.
                    self.Config[register].set(byte, write=True, verify=False)
                    if self.Config[register].get(read=True) != byte:
                        raise RuntimeError('Si570 configuration readback mismatch while frozen')

                # No readback between these writes: NewFreq must follow within 10 ms.
                start = time.monotonic()
                self.FreezeDCO.set(0, write=True, verify=False)
                self.NewFreq()
                if time.monotonic() - start >= 0.010:
                    raise TimeoutError('Si570 unfreeze/NewFreq exceeded 10 ms; clock state is uncertain')
                wait_clear(self.NewFreq)
                time.sleep(0.010)  # Allow the specified large-change settling time.
                actual = [self.Config[i].get(read=True) for i in range(7, 13)]
                if actual != config:
                    raise RuntimeError('Si570 configuration readback mismatch after NewFreq')

        def get_freq(read: bool) -> float:
            if self._fxtal is None:
                return math.nan
            n1 = self.N1.get(read=read)
            hs_div = self.HS_DIV_INT.get(read=read)
            rfreq = self.RFREQ.get(read=read)
            fxtal = self.fxtal.get(read=read)

            return (fxtal * rfreq)/(hs_div * n1)


        self.add(pr.LinkVariable(
            name         = 'Frequency',
            description  = """
            Set the frequency in MHz.
            Automatically calculates all register values and performs the frequency update procedure described in the datasheet""",
            units        = 'MHz',
            dependencies = [self.N1, self.HS_DIV_INT, self.RFREQ, self.fxtal],
            linkedGet    = get_freq,
            linkedSet    = set_freq))
