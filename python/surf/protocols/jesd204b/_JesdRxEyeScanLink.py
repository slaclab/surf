#-----------------------------------------------------------------------------
# Title      : JESD204b RX link adapter of the eye-scan runner
#-----------------------------------------------------------------------------
# Description:
# Link evidence of one JesdRx lane for surf.xilinx.eyescan.runEyeScan: the
# lane bits of the status registers that span every lane, the per-lane error
# counters, the raw Enable and control words, the Status line fields, plus the
# RX reset hook registration of the lane's EyeScan child.
#
# JesdRx has one RX reset for the whole link, ResetGTs. In the AMC carrier GT
# wrappers it resets every GT of the bay, the TX GTs (DAC link) included. The
# hook registered here pulses that shared reset and waits only for the RX
# DataValid bit of its own lane, so the lanes of one JesdRx must scan one at a
# time (--parallel false) and the application has to check, or bring up again,
# the TX side after the scan; the runner does not.
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

from __future__ import annotations

from typing import Any, Callable

from surf.xilinx.eyescan import EyeScanLink, RawWordReader

__all__ = ['JesdRxEyeScanLink']


def _numLanes(jesdRx: Any) -> int:
    """Return the RX lane count of a ``JesdRx`` device (the width of its ``Enable`` register)."""
    return int(jesdRx.Enable.bitSize[0])


def _checkLane(jesdRx: Any, lane: int) -> int:
    """Return ``lane`` as an int, or raise ``ValueError`` when ``jesdRx`` has no such lane."""
    lane = int(lane)
    count = _numLanes(jesdRx)
    if not 0 <= lane < count:
        raise ValueError(f'{jesdRx.path} has {count} RX lanes, no lane {lane}')
    return lane


def _laneBit(var: Any, lane: int) -> bool:
    """Return bit ``lane`` of a status variable that spans every lane (lane i at bit i), read from hardware."""
    return bool((int(var.get()) >> lane) & 1)


class JesdRxEyeScanLink(EyeScanLink):
    """Link adapter of one lane of a ``JesdRx`` core.

    Parameters
    ----------
    jesdRx : surf.protocols.jesd204b.JesdRx
        JESD204b receiver that owns the lane.
    lane : int
        Lane index within ``jesdRx``.

    Raises
    ------
    ValueError
        If ``lane`` is outside the RX lanes of ``jesdRx``.
    """

    # The JESD GT wrappers expose no loopback control
    hasLoopback = False

    def __init__(self, jesdRx: Any, lane: int) -> None:
        self.jesdRx  = jesdRx
        self.lane    = _checkLane(jesdRx, lane)
        self._reader = None

    @staticmethod
    def laneReady(jesdRx: Any, lane: int) -> Callable[[], bool]:
        """Return the ready callable of ``lane``: a fresh read of the lane's ``DataValid`` bit.

        ``DataValid`` is one variable spanning every lane (lane i at bit i), so
        the variable itself cannot serve as the ready signal of one lane: it
        would read True as soon as any lane is valid.
        """
        lane = _checkLane(jesdRx, lane)

        def ready() -> bool:
            return _laneBit(jesdRx.DataValid, lane)
        return ready

    @staticmethod
    def connectRxReset(
            gt: Any,
            jesdRx: Any,
            lane: int,
            *,
            settle: float = 1.0,
            timeout: float = 10.0,
            **kwargs: Any) -> None:
        """Register ``jesdRx.ResetGTs`` and the ``DataValid`` bit of ``lane`` as the RX reset hook of ``gt.EyeScan``.

        Registration only stores the hook, it never accesses hardware, so it
        can run while the device tree is built. ``ResetGTs`` resets every GT
        of the link, so the lanes of one ``jesdRx`` must not scan in parallel,
        and the hook waits for the RX lane only: whether the TX GTs the reset
        also hit come back is for the application to check. After the reset
        the lane returns through PLL lock, CDR lock, code group synchronization
        and the ILAS, which takes longer than the GT relock the ``setRxReset``
        defaults are tuned for; hence the longer ``settle`` and ``timeout``.
        Extra keyword arguments go to ``EyeScan.setRxReset``.

        Raises
        ------
        ValueError
            If ``lane`` is outside the RX lanes of ``jesdRx``.
        """
        gt.EyeScan.setRxReset(
            reset   = jesdRx.ResetGTs,
            ready   = JesdRxEyeScanLink.laneReady(jesdRx, lane),
            settle  = settle,
            timeout = timeout,
            **kwargs)

    def counters(self) -> dict:
        rx, lane = self.jesdRx, self.lane
        return {
            'LinkReady'      : int(_laneBit(rx.DataValid, lane)),
            'StatusValidCnt' : int(rx.StatusValidCnt[lane].get()),
            'DisparityErr'   : int(rx.DisparityErr[lane].get()),
            'NotInTableErr'  : int(rx.NotInTableErr[lane].get()),
            'AlignErr'       : int(_laneBit(rx.AlignErr, lane)),
            'PositionErr'    : int(_laneBit(rx.PositionErr, lane)),
        }

    def rawWords(self) -> dict:
        # The configuration words only: Enable (0x00) and the control word at
        # 0x10 that holds ResetGTs next to SubClass, ReplaceEnable, ClearErrors,
        # InvertSync and ScrambleEnable; 'Ctrl' is this adapter's name for it.
        # The per-lane status word carries latched error nibbles that change
        # under a scan, so it is reported through counters() instead.
        rx = self.jesdRx
        if self._reader is None:
            self._reader = RawWordReader(rx)
        return {
            'Enable' : f'0x{self._reader.read32(rx.Enable.offset):08X}',
            'Ctrl'   : f'0x{self._reader.read32(rx.ResetGTs.offset):08X}',
        }

    def statusFields(self) -> dict:
        rx, lane = self.jesdRx, self.lane
        return {
            'GTReady'       : _laneBit(rx.GTReady, lane),
            'DataValid'     : _laneBit(rx.DataValid, lane),
            'nSync'         : _laneBit(rx.nSync, lane),
            'CommaDetected' : _laneBit(rx.CommaDetected, lane),
        }
