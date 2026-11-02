##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Emulated GTYE4 DRP memory for the eye-scan tests. The eye-scan state machine
# of the GTHE3 model is reused as it is: it derives every field position from
# the live driver variables, and the GTYE4 sampler uses the same control and
# status protocol (UG578). What differs is the seed of a cold C1100 lane
# (64-bit RX_DATA_WIDTH and RX_INT_DATAWIDTH raw 2, so W is 64), the ten words
# of each mask array (individually named variables on Gtye4Channel), the two
# wider RX_DATA_WIDTH codes, and a log of the raw horizontal offset word of
# every run start.

import pytest

pr = pytest.importorskip('pyrogue', reason='Eye-scan tests require Rogue/PyRogue')

from tests.xilinx.eyescan.gthe3_eye_model import Gthe3EyeModel, bitOf  # noqa: E402

MASK_NAMES = ('ES_SDATA_MASK', 'ES_QUAL_MASK', 'ES_QUALIFIER')
MASK_WORDS = 10

# Raw RX_DATA_WIDTH code to bits, UG578 table
DATA_WIDTH_BITS = {2: 16, 3: 20, 4: 32, 5: 40, 6: 64, 7: 80, 8: 128, 9: 160}


def maskVars(gt, name):
    """The ten word variables of one mask array, word 0 first."""
    return [getattr(gt, f'{name}{i}') for i in range(MASK_WORDS)]


class Gtye4EyeModel(Gthe3EyeModel):
    """GTHE3 sampler model over the Gtye4Channel field positions.

    Attributes
    ----------
    horzLog : list
        ``(signed horizontal count, bit 11 of the raw horizontal field)`` per
        run start.
    """

    FAMILY = 'GTYE4'

    def __init__(self, **kw):
        super().__init__(**kw)
        self.horzLog = []

    def _doMaxAccess(self):
        # RX_PRBS_ERR_CNT spans six bytes, so a ReadAll block of Gtye4Channel is
        # eight bytes; a four byte limit makes Rogue 6.15.0 crash on it
        return 8

    def seedHardwareLike(self, gt):
        """Load the register values of a cold C1100 GTY lane (W 64, RXOUT_DIV 2)."""
        super().seedHardwareLike(gt)
        self.setField(gt.RX_INT_DATAWIDTH, 2)

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
        """Raw words of every register the engine reads or writes."""
        addrs = {self._pos.ctl[0], self._pos.horz[0], self._pos.ut[0], gt.RXCFOK_CFG0.offset >> 2}
        for name in MASK_NAMES:
            addrs.update(var.offset >> 2 for var in maskVars(gt, name))
        return {addr: self.word(addr) for addr in sorted(addrs)}

    def width(self):
        dataBits = DATA_WIDTH_BITS[self._field(self._pos.dataW)]
        return (20 if dataBits % 20 == 0 else 16) << self._field(self._pos.intW)

    def _start(self):
        horz = self._field(self._pos.horz)
        self.horzLog.append((self._horzCount(), bitOf(horz, 11)))
        super()._start()


def makeGtyRoot(neighbours=True, **kw):
    """Started root with one Gtye4Channel over an emulated GT; returns (root, gt, model)."""
    import surf.xilinx as xil
    model = Gtye4EyeModel(**kw)
    root = pr.Root(pollEn=False, initRead=False, initWrite=False, timeout=1.0)
    gt = xil.Gtye4Channel(name='Gt', memBase=model)
    root.add(gt)
    model.seedHardwareLike(gt)
    if neighbours:
        model.seedNeighbours(gt)
    root.start()
    return root, gt, model
