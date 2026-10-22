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

# Datasheet nominal internal crystal frequency (MHz), used for readback only
# until fxtal is calibrated. Actual parts vary by up to +/-2000 ppm.
_FXTAL_NOMINAL = 114.285

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
    **kwargs : Any
        Additional arguments forwarded to ``pyrogue.Device``.

    Notes
    -----
    The internal crystal frequency (fxtal) varies by up to +/-2000 ppm
    between parts and must be calibrated per device. Executing ``RECALL``
    reloads the factory configuration and calibrates ``fxtal``; setting
    ``Frequency`` does this automatically the first time.
    """

    def __init__(self, factory_freq: float, **kwargs: Any) -> None:
        """Create the Si570 model."""
        super().__init__(**kwargs)
        self.factory_freq = factory_freq

        ADDR_SIZE = 4

        for i in range(7, 13):
            self.add(pr.RemoteVariable(
                name        = f'Config[{i}]',
                description = 'Entire configuration space as an array of registers',
                offset      = i * ADDR_SIZE,
                bitOffset   = 0,
                bitSize     = 8,
                hidden      = True,
                overlapEn   = True))

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
            linkedSet    = lambda value, write: self.RFREQ_RAW.set(int(value*2**28), write=write)))

        # RST_REG, NewFreq, FreezeM and RECALL share register 135, so every
        # write of that register replays the cached value of all four bits
        def pulse(cmd: pr.RemoteCommand) -> None:
            try:
                # Never replay a cached self-clearing bit with this pulse
                for bit in (self.RST_REG, self.NewFreq, self.RECALL):
                    if bit is not cmd and bit.value():
                        bit.set(0, write=False)
                cmd.set(1)

                # The device clears the bit on completion, and the readback
                # also refreshes the cached copy of register 135
                deadline = time.monotonic() + _POLL_TIMEOUT
                while cmd.get(read=True):
                    if time.monotonic() > deadline:
                        raise TimeoutError(f'{cmd.path} did not self-clear within {_POLL_TIMEOUT} s')
                    time.sleep(_POLL_PERIOD)
            finally:
                # Keep a later bulk write from replaying an incomplete pulse
                if cmd.value():
                    cmd.set(0, write=False)

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
            function    = pulse))

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

            # Registers now hold the factory configuration for factory_freq
            rfreq = self.RFREQ.get(read=True)
            if rfreq == 0:
                raise ValueError('Si570 RFREQ reads zero after RECALL; cannot calibrate fxtal')
            self.fxtal.set(self.factory_freq * self.HS_DIV_INT.get(read=True) * self.N1.get(read=True) / rfreq)

        self.add(pr.RemoteCommand(
            name        = 'RECALL',
            description = """
            Write NVM bits into RAM.
            Effectively resets the chip without interrupting I2C.
            Restores the factory output frequency and calibrates fxtal""",
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
            verify      = False))

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
            if write is False or self.enable.value() is not True:
                return

            with self.root.updateGroup():
                n1, hs_div = find_params(value)
                fdco = value * hs_div * n1

                if self.fxtal.value() == 0.0:
                    self.RECALL()
                rfreq = fdco / self.fxtal.value()

                # Freeze, refreshing the cached reserved bits of register 137 first
                self.FreezeDCO.get(read=True)
                self.FreezeDCO.set(1, write=True)

                # Write new config
                self.N1.set(n1, write=False)
                self.HS_DIV_INT.set(hs_div, write=False)
                self.RFREQ.set(rfreq, write=False)
                self.writeAndVerifyBlocks()

                # Unfreeze
                self.FreezeDCO.set(0, write=True)

                # NewFreq
                self.NewFreq()

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
            Readback uses the nominal fxtal (+/-2000 ppm) until fxtal is calibrated""",
            units        = 'MHz',
            dependencies = [self.N1, self.HS_DIV_INT, self.RFREQ, self.fxtal],
            linkedGet    = get_freq,
            linkedSet    = set_freq))
