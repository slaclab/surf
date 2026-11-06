#-----------------------------------------------------------------------------
# Title      : PGP4 link adapter of the eye-scan runner
#-----------------------------------------------------------------------------
# Description:
# Link evidence of a Pgp4AxiL lane for surf.xilinx.eyescan.runEyeScan: the
# link counters, the raw Ctrl word, the Status line fields and the GT loopback,
# plus the RX reset hook registration of the lane's EyeScan child.
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

from typing import Any

from surf.xilinx.eyescan import EyeScanLink, RawWordReader

__all__ = ['Pgp4EyeScanLink']


class Pgp4EyeScanLink(EyeScanLink):
    """Link adapter of a ``Pgp4AxiL`` lane.

    Parameters
    ----------
    pgp : surf.protocols.pgp.Pgp4AxiL
        PGP4 core of the lane.
    """

    hasLoopback = True

    def __init__(self, pgp: Any) -> None:
        self.pgp     = pgp
        self._reader = None

    @staticmethod
    def connectRxReset(gt: Any, pgp: Any, **kwargs: Any) -> None:
        """Register ``pgp.Ctrl.ResetRx`` and ``pgp.RxStatus.PhyRxActive`` as the RX reset hook of ``gt.EyeScan``.

        Registration only stores the hook, it never accesses hardware, so it
        can run while the device tree is built. Extra keyword arguments go to
        ``EyeScan.setRxReset``.
        """
        gt.EyeScan.setRxReset(reset = pgp.Ctrl.ResetRx, ready = pgp.RxStatus.PhyRxActive, **kwargs)

    def counters(self) -> dict:
        rx = self.pgp.RxStatus
        return {
            'LinkReady'    : int(rx.LinkReady.get()),
            'PhyRxInitCnt' : int(rx.PhyRxInitCnt.get()),
            'LinkDownCnt'  : int(rx.LinkDownCnt.get()),
        }

    def rawWords(self) -> dict:
        # The Ctrl word that holds Loopback and ResetRx, read through the Ctrl device
        ctrl = self.pgp.Ctrl
        if self._reader is None:
            self._reader = RawWordReader(ctrl)
        return {'Ctrl': f'0x{self._reader.read32(ctrl.ResetRx.offset):08X}'}

    def statusFields(self) -> dict:
        rx = self.pgp.RxStatus
        return {
            'PhyRxActive' : rx.PhyRxActive.get(),
            'LinkReady'   : rx.LinkReady.get(),
        }

    def getLoopback(self) -> int:
        return int(self.pgp.Ctrl.Loopback.get())

    def setLoopback(self, value: int) -> None:
        self.pgp.Ctrl.Loopback.set(value)
