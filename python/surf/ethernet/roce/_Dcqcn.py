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

# DCQCN parameters (register map of surf/ethernet/RoCEv2/rtl/Dcqcn.vhd)
class Dcqcn(pr.Device):
    def __init__(self, clockPeriodNs=6.4, **kwargs):
        super().__init__(**kwargs)

        self._clockPeriodNs = clockPeriodNs

        # -------------------------
        # 0x000 - alphaG, dec_gain, timeStageThreshold, clampTgtRate
        # -------------------------

        self.add(pr.RemoteVariable(
            name        = 'AlphaG',
            description = '(1-g) factor for alpha update, Q0.10 fixed-point',
            offset      = 0x000,
            bitSize     = 10,
            bitOffset   = 0,
            mode        = 'RW',
            base        = pr.UInt,
        ))

        self.add(pr.LinkVariable(
            name        = 'AlphaG_real',
            description = '(1-g) as a floating-point value in [0, 1)',
            mode        = 'RW',
            units       = '',
            linkedGet   = lambda: self.AlphaG.value() / 1024.0,
            linkedSet   = lambda value, write: self.AlphaG.set(int(round(value * 1024.0)), write=write),
            dependencies = [self.AlphaG],
        ))

        self.add(pr.LinkVariable(
            name        = 'G_real',
            description = 'g factor for alpha update, floating-point value in (0, 1]',
            mode        = 'RW',
            units       = '',
            hidden      = True,
            linkedGet   = lambda: 1.0 - self.AlphaG.value() / 1024.0,
            linkedSet   = lambda value, write: self.AlphaG.set(int(round((1.0 - value) * 1024.0)), write=write),
            dependencies = [self.AlphaG],
        ))

        self.add(pr.RemoteVariable(
            name        = 'DecGain',
            description = 'Decrease gain exponent: Rc = Rc * (1 - alpha / 2^DecGain)',
            offset      = 0x000,
            bitSize     = 4,
            bitOffset   = 10,
            mode        = 'RW',
            base        = pr.UInt,
        ))

        self.add(pr.RemoteVariable(
            name        = 'TimeStageThreshold',
            description = 'Threshold (in increase stages) before transitioning to next increase stage',
            offset      = 0x000,
            bitSize     = 8,
            bitOffset   = 14,
            mode        = 'RW',
            base        = pr.UInt,
            units       = 'stages',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ClampTgtRate',
            description = 'Clamp target rate step: 0 = disabled, 1 = enabled',
            offset      = 0x000,
            bitSize     = 1,
            bitOffset   = 22,
            mode        = 'RW',
            base        = pr.UInt,
            enum        = {0: 'Disabled', 1: 'Enabled'},
        ))

        # -------------------------
        # 0x004 - Rai
        # -------------------------

        self.add(pr.RemoteVariable(
            name        = 'Rai',
            description = 'Additive increase step',
            offset      = 0x004,
            bitSize     = 32,
            bitOffset   = 0,
            mode        = 'RW',
            base        = pr.Int,
            units       = 'Byte/s',
        ))

        # -------------------------
        # 0x008 - Rhai
        # -------------------------

        self.add(pr.RemoteVariable(
            name        = 'Rhai',
            description = 'Hyper-active increase step',
            offset      = 0x008,
            bitSize     = 32,
            bitOffset   = 0,
            mode        = 'RW',
            base        = pr.Int,
            units       = 'Byte/s',
        ))

        # -------------------------
        # 0x00C - Rmin
        # -------------------------

        self.add(pr.RemoteVariable(
            name        = 'Rmin',
            description = 'Minimum rate floor',
            offset      = 0x00C,
            bitSize     = 32,
            bitOffset   = 0,
            mode        = 'RW',
            base        = pr.Int,
            units       = 'Byte/s',
        ))

        # -------------------------
        # 0x010 - rateIncInterval
        # -------------------------

        self.add(pr.RemoteVariable(
            name        = 'RateIncInterval',
            description = 'Rate increase timer interval in clock cycles',
            offset      = 0x010,
            bitSize     = 32,
            bitOffset   = 0,
            mode        = 'RW',
            base        = pr.UInt,
            units       = 'cycles',
        ))

        self.add(pr.LinkVariable(
            name        = 'RateIncInterval_ns',
            description = 'Rate increase timer interval in nanoseconds',
            mode        = 'RW',
            units       = 'ns',
            linkedGet   = lambda: self.RateIncInterval.value() * self._clockPeriodNs,
            linkedSet   = lambda value, write: self.RateIncInterval.set(
                              int(round(value / self._clockPeriodNs)), write=write),
            dependencies = [self.RateIncInterval],
        ))

        # -------------------------
        # 0x014 - rateDecInterval [15:0], alphaUpdInterval [31:16]
        # -------------------------

        self.add(pr.RemoteVariable(
            name        = 'RateDecInterval',
            description = 'Rate decrease timer interval in clock cycles',
            offset      = 0x014,
            bitSize     = 16,
            bitOffset   = 0,
            mode        = 'RW',
            base        = pr.UInt,
            units       = 'cycles',
        ))

        self.add(pr.LinkVariable(
            name        = 'RateDecInterval_ns',
            description = 'Rate decrease timer interval in nanoseconds',
            mode        = 'RW',
            units       = 'ns',
            linkedGet   = lambda: self.RateDecInterval.value() * self._clockPeriodNs,
            linkedSet   = lambda value, write: self.RateDecInterval.set(
                              int(round(value / self._clockPeriodNs)), write=write),
            dependencies = [self.RateDecInterval],
        ))

        self.add(pr.RemoteVariable(
            name        = 'AlphaUpdInterval',
            description = 'Alpha update timer interval in clock cycles',
            offset      = 0x014,
            bitSize     = 16,
            bitOffset   = 16,
            mode        = 'RW',
            base        = pr.UInt,
            units       = 'cycles',
        ))

        self.add(pr.LinkVariable(
            name        = 'AlphaUpdInterval_ns',
            description = 'Alpha update timer interval in nanoseconds',
            mode        = 'RW',
            units       = 'ns',
            linkedGet   = lambda: self.AlphaUpdInterval.value() * self._clockPeriodNs,
            linkedSet   = lambda value, write: self.AlphaUpdInterval.set(
                              int(round(value / self._clockPeriodNs)), write=write),
            dependencies = [self.AlphaUpdInterval],
        ))

        # -------------------------
        # 0x018 - Rc (read-only)
        # -------------------------

        self.add(pr.RemoteVariable(
            name        = 'Rc',
            description = 'Current transmission rate',
            offset      = 0x018,
            bitSize     = 32,
            bitOffset   = 0,
            mode        = 'RO',
            base        = pr.Int,
            units       = 'Byte/s',
            pollInterval = 1,
        ))

        # -------------------------
        # 0x01C - Rt (read-only)
        # -------------------------

        self.add(pr.RemoteVariable(
            name        = 'Rt',
            description = 'Target transmission rate',
            offset      = 0x01C,
            bitSize     = 32,
            bitOffset   = 0,
            mode        = 'RO',
            base        = pr.Int,
            units       = 'Byte/s',
            pollInterval = 1,
        ))

        # -------------------------
        # 0x020 - alpha (read-only)
        # -------------------------

        self.add(pr.RemoteVariable(
            name        = 'Alpha',
            description = 'Current alpha value, Q0.10 fixed-point',
            offset      = 0x020,
            bitSize     = 10,
            bitOffset   = 0,
            mode        = 'RO',
            base        = pr.UInt,
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name        = 'Alpha_real',
            description = 'Current alpha as a floating-point value in [0, 1]',
            mode        = 'RO',
            units       = '',
            linkedGet   = lambda: self.Alpha.value() / 1024.0,
            dependencies = [self.Alpha],
        ))
