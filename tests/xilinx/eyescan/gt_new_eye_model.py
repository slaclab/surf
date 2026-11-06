##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Emulated GTYE3 (UltraScale GTY) and GTHE4 (UltraScale+ GTH) DRP memories for
# the eye-scan tests. Neither family has been run on hardware; the models
# follow the user guides only. The GTHE3 state machine is reused as it is,
# since it derives every field position from the live driver variables.
#
# GTYE3 (UG578 Table B-2) has the GTYE4 eye-scan layout: status words at 0x251
# to 0x253, ten individually named words per mask array, RX_DATA_WIDTH codes
# up to 160 bits and RX_INT_DATAWIDTH up to 2, so its model is the GTYE4 one
# with a 64-bit seed.
#
# GTHE4 (UG576 Table C-2) has the same DRP addresses as GTYE4, including the
# ten mask words per array, but UG576 Table 4-20 note 1 keeps mask words 5 to 9
# for GTY transceivers only and the GTH sampler stays 40 bits wide. The
# descriptor therefore writes the five low words like GTHE3, and the seed is
# a 32-bit lane (RX_DATA_WIDTH raw 6, RX_INT_DATAWIDTH raw 1) like the SURF
# UltraScale+ GTH IP cores.

import pytest

pr = pytest.importorskip('pyrogue', reason='Eye-scan tests require Rogue/PyRogue')

from tests.xilinx.eyescan.gthe3_eye_model import Gthe3EyeModel  # noqa: E402
from tests.xilinx.eyescan.gtye4_eye_model import MASK_NAMES, Gtye4EyeModel, maskVars  # noqa: E402

# Mask words of each array the GTHE4 scan writes (the driver names ten)
GTHE4_SCAN_WORDS = 5


class Gtye3EyeModel(Gtye4EyeModel):
    """GTYE4 sampler model over the Gtye3Channel field positions."""

    FAMILY = 'GTYE3'


class Gthe4EyeModel(Gthe3EyeModel):
    """GTHE3 sampler model over the Gthe4Channel field positions.

    The mask arrays are the ten individually named words of the driver; the
    seed fills all of them so a scan that strays into words 5 to 9 is caught
    by the register restore checks.
    """

    FAMILY = 'GTHE4'

    def __init__(self, **kw):
        super().__init__(**kw)
        self.horzLog = []

    def _doMaxAccess(self):
        # RX_PRBS_ERR_CNT spans six bytes, so a ReadAll block of Gthe4Channel is eight bytes
        return 8

    def seedNeighbours(self, gt):
        """Fill the shared words and all thirty mask words with non-zero values."""
        self.attach(gt)
        self.setWord(self._pos.ctl[0], 0x00EA)            # ES_PRESCALE 0xA, bits 7:5 set
        self.setWord(self._pos.horz[0], 0x123F)           # ES_HORZ_OFFSET 0x123, deskew bits 3:0 set
        self.setWord(self._pos.ut[0], 0xF841)             # VS_CODE 0x10, VS_RANGE 1, bits 15:11 set
        self.setWord(gt.RXCFOK_CFG0.offset >> 2, 0x4000)
        for name, base in (('ES_SDATA_MASK', 0x5A00), ('ES_QUAL_MASK', 0x3C00), ('ES_QUALIFIER', 0x0E00)):
            for i, var in enumerate(maskVars(gt, name)):
                self.setWord(var.offset >> 2, base + 0x11 * (i + 1))

    def seedSnapshot(self, gt):
        """Raw words of every register the engine reads or writes, plus the GTY-only mask words."""
        addrs = {self._pos.ctl[0], self._pos.horz[0], self._pos.ut[0], gt.RXCFOK_CFG0.offset >> 2}
        for name in MASK_NAMES:
            addrs.update(var.offset >> 2 for var in maskVars(gt, name))
        return {addr: self.word(addr) for addr in sorted(addrs)}

    def _start(self):
        from tests.xilinx.eyescan.gthe3_eye_model import bitOf
        horz = self._field(self._pos.horz)
        self.horzLog.append((self._horzCount(), bitOf(horz, 11)))
        super()._start()


def _makeRoot(cls, model, neighbours, **kw):
    import surf.xilinx as xil
    root = pr.Root(pollEn=False, initRead=False, initWrite=False, timeout=1.0)
    gt = getattr(xil, cls)(name='Gt', memBase=model)
    root.add(gt)
    model.seedHardwareLike(gt)
    if neighbours:
        model.seedNeighbours(gt)
    root.start()
    return root, gt, model


def makeGtye3Root(neighbours=True, **kw):
    """Started root with one Gtye3Channel over an emulated GT; returns (root, gt, model)."""
    return _makeRoot('Gtye3Channel', Gtye3EyeModel(**kw), neighbours)


def makeGthe4Root(neighbours=True, **kw):
    """Started root with one Gthe4Channel over an emulated GT; returns (root, gt, model)."""
    return _makeRoot('Gthe4Channel', Gthe4EyeModel(**kw), neighbours)
