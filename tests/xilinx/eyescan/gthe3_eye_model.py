##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Emulated GTHE3 DRP memory for the eye-scan tests. The model holds 16-bit
# DRP words keyed by DRP address (byte address >> 2) behind a 32-bit AXI-Lite
# window and counts every bus transaction. Field positions are always derived
# from the live Gthe3Channel variables, never from copied constants.
#
# The eye-scan state machine follows UG576: the sampler is driven from DRP
# word 0x3C (ES_CONTROL, ES_ERRDET_EN, ES_EYE_SCAN_EN, ES_PRESCALE), reads
# status 0x0 until it is active, and then steps through WAIT (0x1), RESET
# (0x2), COUNT (0x6) and END (0x5) on status reads, so timing is a count of
# reads and never wall-clock time. With requireReset the sampler only becomes
# active when pmaReset() is called while both enables are set, which is what
# a PMA reset does on the silicon. With desyncResets chosen resets leave the
# sampler out of step with the data sampler, as about every second RX reset
# does on the C1100 GTYE4 lanes 4 and 6 at 15.46875 Gb/s. resetMode 'keep'
# and enableDraws model lanes 5 and 7 there: a reset keeps the alignment and
# only setting the enables again draws it afresh.

from types import SimpleNamespace

import pytest

pr = pytest.importorskip('pyrogue', reason='Eye-scan tests require Rogue/PyRogue')

import numpy as np  # noqa: E402
rim = pytest.importorskip('rogue.interfaces.memory', reason='Eye-scan tests require Rogue/PyRogue')

SAMPLE_MAX = 65535
ERROR_MAX = 65535

# Error ratio of one UT accumulation of a sampler out of step with the data at
# every offset (uncorrelated samples, half of them screened by the UT sign), as
# measured on C1100 GTYE4 lanes
DESYNC_BER = 0.25

# Error ratio at the data crossing of a live link: half the bits are transitions
CROSSING_BER = 0.25

# Raw RX_DATA_WIDTH code to bits, UG576 table
DATA_WIDTH_BITS = {2: 16, 3: 20, 4: 32, 5: 40, 6: 64, 7: 80}

STATE_STATUS = {'OFF': 0x0, 'WAIT': 0x1, 'RESET': 0x2, 'COUNT': 0x6, 'END': 0x5}


def fieldOf(var):
    """Return (drpWord, lsb, width) of a driver variable."""
    word = var.offset >> 2
    lsb = 8 * (var.offset & 3) + var.bitOffset[0]
    width = var.bitSize[0]
    assert lsb + width <= 16, f'{var.name} does not fit in one DRP word'
    return word, lsb, width


def fieldOf32(var):
    """Return (byteAddress, lsb, width) of a variable in a 32-bit register."""
    return int(var.address), var.bitOffset[0], var.bitSize[0]


def bitOf(word, lsb):
    return (word >> lsb) & 1


class Gthe3EyeModel(rim.Slave):
    """16-bit DRP words behind a 32-bit window with an eye-scan state machine.

    Parameters
    ----------
    requireReset : bool
        The sampler only activates on pmaReset() while both enables are set.
    countReads : int
        Number of status reads that return COUNT before END.
    zeroSamples : bool
        END is reached with a sample counter of zero.
    stuckStatus : int or None
        Raw status returned for every read while RUN is set.
    stuckIgnoresRun : bool
        Return ``stuckStatus`` for every status read, also with RUN cleared,
        like a sampler that stays in COUNT after ES_CONTROL is written 0.
    onState : callable or None
        Called with the state name on every state-machine transition.
    berFn : callable or None
        ``berFn(horzCount, utSign)`` gives the BER used to draw the errors.
        With neither ``berFn`` nor ``eyeFn`` the model is a clean link whose
        data transitions show at the two ends of the UI: a run at
        ``|count| >= half`` draws its errors at ``CROSSING_BER`` and every
        other position counts none.
    eyeFn : callable or None
        ``eyeFn(horzCount, vertCode, utSign)`` gives the BER of a 2D eye, where
        ``vertCode`` is signed (negative when RX_EYESCAN_VS_NEG_DIR is set);
        it takes precedence over ``berFn``.
    seed : int
        Seed of the Poisson draw.
    slowFrom : int or None
        A run started at this ES_PRESCALE or above stays in COUNT for
        ``slowReads`` status reads, like a deep-prescale run that takes seconds
        on silicon; clearing RUN still ends it at once.
    slowReads : int
        Status reads a slow run stays in COUNT.
    desyncResets : collection of int
        Numbers (1 for the first) of the pmaReset() calls that leave the
        sampler out of step with the data sampler: until the next reset every
        run counts errors at ``DESYNC_BER`` whatever the offset and ``berFn``.
        Any other reset brings it back in step. Used by resetMode 'table'.
    resetMode : str
        What a pmaReset() does to the alignment: 'table' sets it from
        ``desyncResets``, 'keep' leaves it as it is, 'flip' inverts it.
    enableDraws : sequence of bool
        Alignment drawn each time a write of the control word sets both
        enables when they were not both set (True is out of step), in order;
        once the sequence is used up such a write leaves the alignment as it is.
    endSamples : int or None
        A run that reaches END by itself holds this many samples instead of
        65535, as the C1100 GTYE4 lanes without a link measured; the run that
        a cleared RUN stops is unchanged.
    """

    FAMILY = 'GTHE3'

    def __init__(self, requireReset=True, countReads=3, zeroSamples=False,
                 stuckStatus=None, onState=None, berFn=None, seed=1, stuckIgnoresRun=False,
                 eyeFn=None, slowFrom=None, slowReads=0, desyncResets=(), resetMode='table',
                 enableDraws=(), endSamples=None):
        super().__init__(4, 4)
        self.words = {}
        self.reads = 0
        self.readAddrs = set()   # DRP word addresses touched by reads
        self.writes = []         # (DRP word address, 16-bit value) per write beat
        self.log = []            # ordered ('R' | 'W', DRP word address, value)
        self.phaseViolations = 0
        self.requireReset = requireReset
        self.countReads = countReads
        self.zeroSamples = zeroSamples
        self.stuckStatus = stuckStatus
        self.stuckIgnoresRun = stuckIgnoresRun
        self.onState = onState
        self.berFn = berFn
        self.eyeFn = eyeFn
        self.slowFrom = slowFrom
        self.slowReads = slowReads
        assert resetMode in ('table', 'keep', 'flip'), resetMode
        self.desyncResets = set(desyncResets)
        self.resetMode = resetMode
        self.enableDraws = list(enableDraws)
        self.endSamples = endSamples
        self.enableSets = 0      # control word writes that set both enables from not both set
        self.desynced = False    # out of step with the data sampler
        self.rng = np.random.default_rng(seed)
        self.resets = 0          # pmaReset() calls
        self.runs = 0            # RUN rising edges seen while active
        self.runLog = []         # (horz, vert, utSign, prescale) per RUN start
        self.negativeZero = 0    # RUN starts with VS_CODE 0 and VS_NEG_DIR 1
        self.active = False
        self.state = 'OFF'
        self._pos = None
        self._engaged = False    # set by the first write to the eye-scan control word
        self._left = 0           # COUNT reads still to serve
        self._total = 0          # COUNT reads of the run in progress

    @property
    def transactions(self):
        return self.reads + len(self.writes)

    # ------------------------------------------------------------------
    # Bus side
    # ------------------------------------------------------------------
    def _doTransaction(self, transaction):
        with transaction.lock():
            size = transaction.size()
            data = bytearray(size)
            isWrite = transaction.type() in (rim.Write, rim.Post)
            if isWrite:
                transaction.getData(data, 0)
            data = self.access(transaction.address(), size, isWrite, data)
            if not isWrite:
                transaction.setData(bytes(data), 0)
            transaction.done()

    def access(self, address, size, isWrite, data):
        """Serve one transaction at a DRP-space byte address; returns the data."""
        beats = [(address + beat) >> 2 for beat in range(0, size, 4)]
        if not isWrite and self._engaged and self._pos is not None and self._pos.status[0] in beats:
            # The status word decides the counters, so it is evaluated first
            self.words[self._pos.status[0]] = self._statusRead()
        for beat in range(0, size, 4):
            addr = (address + beat) >> 2
            if isWrite:
                value = int.from_bytes(data[beat:beat + 2], 'little')
                old = self.words.get(addr, 0)
                self.words[addr] = value
                self.writes.append((addr, value))
                self.log.append(('W', addr, value))
                if self._pos is not None and addr == self._pos.ctl[0]:
                    self._controlWrite(old, value)
            else:
                self.reads += 1
                self.readAddrs.add(addr)
                value = self.words.get(addr, 0)
                self.log.append(('R', addr, value))
                data[beat:beat + 4] = value.to_bytes(4, 'little')
        return data

    # ------------------------------------------------------------------
    # Raw word helpers
    # ------------------------------------------------------------------
    def setWord(self, addr, value):
        self.words[addr] = value

    def word(self, addr):
        return self.words.get(addr, 0)

    def setField(self, var, value):
        word, lsb, width = fieldOf(var)
        mask = ((1 << width) - 1) << lsb
        self.words[word] = (self.word(word) & ~mask) | ((value << lsb) & mask)

    def getField(self, var):
        word, lsb, width = fieldOf(var)
        return (self.word(word) >> lsb) & ((1 << width) - 1)

    def seedHardwareLike(self, gt):
        """Load the register values read from a cold KCU1500 GTH lane."""
        self.attach(gt)
        self.setField(gt.RX_DATA_WIDTH, 6)
        self.setField(gt.RX_INT_DATAWIDTH, 1)
        self.setField(gt.RXOUT_DIV, 1)
        self.setWord(gt.ES_HORZ_OFFSET.offset >> 2, 0x000F)
        self.setWord(gt.RXCFOK_CFG0.offset >> 2, 0x4000)
        self.setWord(gt.RX_EYESCAN_VS_CODE.offset >> 2, 0x1800)
        self.setWord(gt.ES_EYE_SCAN_EN.offset >> 2, 0x0000)
        self.setField(gt.es_control_status, 0x0)

    def seedNeighbours(self, gt):
        """Fill the shared words and the mask words with non-zero values."""
        self.attach(gt)
        self.setWord(self._pos.ctl[0], 0x00EA)            # ES_PRESCALE 0xA, bits 7:5 set
        self.setWord(self._pos.horz[0], 0x123F)           # ES_HORZ_OFFSET 0x123, deskew bits 3:0 set
        self.setWord(self._pos.ut[0], 0xF841)             # VS_CODE 0x10, VS_RANGE 1, bits 15:11 set
        self.setWord(gt.RXCFOK_CFG0.offset >> 2, 0x4000)
        for name, base in (('ES_SDATA_MASK', 0x5A00), ('ES_QUAL_MASK', 0x3C00), ('ES_QUALIFIER', 0x0E00)):
            for i in range(5):
                self.setWord(getattr(gt, name)[i].offset >> 2, base + 0x11 * (i + 1))

    def seedSnapshot(self, gt):
        """Raw words of every register the engine reads or writes."""
        addrs = {self._pos.ctl[0], self._pos.horz[0], self._pos.ut[0], gt.RXCFOK_CFG0.offset >> 2}
        for name in ('ES_SDATA_MASK', 'ES_QUAL_MASK', 'ES_QUALIFIER'):
            addrs.update(getattr(gt, name)[i].offset >> 2 for i in range(5))
        return {addr: self.word(addr) for addr in sorted(addrs)}

    # ------------------------------------------------------------------
    # Eye-scan state machine
    # ------------------------------------------------------------------
    def attach(self, gt):
        """Derive every field position from the live driver variables."""
        self._gt = gt
        self._pos = SimpleNamespace(
            ctl    = fieldOf(gt.ES_CONTROL),
            pre    = fieldOf(gt.ES_PRESCALE),
            en     = fieldOf(gt.ES_EYE_SCAN_EN),
            det    = fieldOf(gt.ES_ERRDET_EN),
            horz   = fieldOf(gt.ES_HORZ_OFFSET),
            ut     = fieldOf(gt.RX_EYESCAN_VS_UT_SIGN),
            vsCode = fieldOf(gt.RX_EYESCAN_VS_CODE),
            vsNeg  = fieldOf(gt.RX_EYESCAN_VS_NEG_DIR),
            status = fieldOf(gt.es_control_status),
            err    = fieldOf(gt.es_error_count),
            smp    = fieldOf(gt.es_sample_count),
            dataW  = fieldOf(gt.RX_DATA_WIDTH),
            intW   = fieldOf(gt.RX_INT_DATAWIDTH),
            rxOut  = fieldOf(gt.RXOUT_DIV),
        )

    def _field(self, pos):
        word, lsb, width = pos
        return (self.word(word) >> lsb) & ((1 << width) - 1)

    def _enter(self, name):
        self.state = name
        if self.onState is not None:
            self.onState(name)

    def _setActive(self, flag):
        self.active = flag
        self._enter('WAIT' if flag else 'OFF')

    def activate(self):
        """Make the sampler active as if a reset had already been issued."""
        self._engaged = True
        self._setActive(True)

    def pmaReset(self):
        """PMA reset: the sampler comes up only if both enables are set."""
        self.resets += 1
        if self.resetMode == 'table':
            self.desynced = self.resets in self.desyncResets
        elif self.resetMode == 'flip':
            self.desynced = not self.desynced
        if self._field(self._pos.en) and self._field(self._pos.det):
            self._setActive(True)

    def _runBit(self):
        return self._field((self._pos.ctl[0], self._pos.ctl[1], 1))

    def _controlWrite(self, old, new):
        self._engaged = True
        pos = self._pos
        en = bitOf(new, pos.en[1])
        det = bitOf(new, pos.det[1])
        if en and det and not (bitOf(old, pos.en[1]) and bitOf(old, pos.det[1])):
            self.enableSets += 1
            if self.enableDraws:
                self.desynced = self.enableDraws.pop(0)
        if not (en and det):
            if self.active:
                self._setActive(False)
        elif not self.requireReset and not self.active:
            self._setActive(True)
        run = bitOf(new, pos.ctl[1])
        wasRun = bitOf(old, pos.ctl[1])
        if self.active and run and not wasRun:
            self._start()
        elif self.active and wasRun and not run:
            self._stop()

    def _horzCount(self):
        horz = self._field(self._pos.horz) & 0x7FF
        return horz - 0x800 if horz & 0x400 else horz

    def _vertCode(self):
        code = self._field(self._pos.vsCode)
        return -code if self._field(self._pos.vsNeg) else code

    def _start(self):
        self.runs += 1
        pos = self._pos
        horz = self._field(pos.horz)
        self.runLog.append((self._horzCount(), self._vertCode(), self._field(pos.ut), self._field(pos.pre)))
        if self._field(pos.vsCode) == 0 and self._field(pos.vsNeg):
            self.negativeZero += 1
        # Bit 11 must equal the sign (bit 10) of the 11-bit offset
        if bitOf(horz, 11) != bitOf(horz, 10):
            self.phaseViolations += 1
        self.words[pos.err[0]] = 0
        self.words[pos.smp[0]] = 0
        slow = self.slowFrom is not None and self._field(pos.pre) >= self.slowFrom
        self._total = self.slowReads if slow else self.countReads
        self._left = self._total
        self._enter('RESET')

    def _stop(self):
        if self.state == 'COUNT':
            done = self._total - self._left
            self._counters(SAMPLE_MAX * done // max(self._total, 1))
            self._enter('END')

    def width(self):
        dataBits = DATA_WIDTH_BITS[self._field(self._pos.dataW)]
        return (20 if dataBits % 20 == 0 else 16) << self._field(self._pos.intW)

    def _halfRange(self):
        """Counts of half a UI at the RXOUT_DIV in the registers."""
        from surf.xilinx.eyescan import getFamily
        family = getFamily(self.FAMILY)
        return family.countsPerHalfUiPerDiv * family.rxOutDivCodes[self._field(self._pos.rxOut)]

    def _counters(self, samples):
        pos = self._pos
        if self.zeroSamples:
            samples = 0
        errors = 0
        # A clean link counts errors only at the data crossings, the two ends of the UI
        crossing = (self.eyeFn is None and self.berFn is None and not self.desynced
                    and abs(self._horzCount()) >= self._halfRange())
        if (self.desynced or self.eyeFn is not None or self.berFn is not None or crossing) and samples:
            horz = self._horzCount()
            ut = self._field(pos.ut)
            if self.desynced:
                ber = DESYNC_BER
            elif self.eyeFn is not None:
                ber = self.eyeFn(horz, self._vertCode(), ut)
            elif self.berFn is not None:
                ber = self.berFn(horz, ut)
            else:
                ber = CROSSING_BER
            bits = samples * (1 << (1 + self._field(pos.pre))) * self.width()
            errors = int(self.rng.poisson(ber * bits))
            if errors > ERROR_MAX:
                # Either counter saturating stops both
                samples = max(1, samples * ERROR_MAX // errors)
                errors = ERROR_MAX
        self.words[pos.err[0]] = errors
        self.words[pos.smp[0]] = samples

    def _statusRead(self):
        if self.stuckStatus is not None and (self.stuckIgnoresRun or self._runBit()):
            return self.stuckStatus
        if not self.active:
            return STATE_STATUS['OFF']
        if not self._runBit():
            if self.state != 'WAIT':
                self._enter('WAIT')
            return STATE_STATUS['WAIT']
        if self.state == 'RESET':
            self._enter('COUNT')
            return STATE_STATUS['RESET']
        if self.state == 'COUNT':
            if self._left > 0:
                self._left -= 1
                return STATE_STATUS['COUNT']
            self._counters(SAMPLE_MAX if self.endSamples is None else self.endSamples)
            self._enter('END')
        return STATE_STATUS[self.state]


class LaneMemory(rim.Slave):
    """Pgp4AxiL window at 0x0000 and the GTHE3 DRP model at 0x1000.

    Writing the ResetRx bit of the Ctrl word drops PhyRxActive. Clearing it
    pulses the GT PMA reset and raises PhyRxActive again after `riseReads`
    reads of the RxStatus word.
    """

    GT_BASE = 0x1000

    def __init__(self, gtModel, riseReads=2):
        super().__init__(4, 4)
        self.gt = gtModel
        self.riseReads = riseReads
        self.words = {}
        self.reads = 0
        self.writes = []         # (byte address, 32-bit value)
        self.phyActive = True
        self._rise = 0
        self._ctrl = None
        self._status = None

    def attach(self, lane):
        """Derive the Ctrl and RxStatus bit positions from the live variables."""
        self.ctrlAddr, self.resetLsb, _ = fieldOf32(lane.Ctrl.ResetRx)
        self.statusAddr, self.phyLsb, _ = fieldOf32(lane.RxStatus.PhyRxActive)
        self.words[self.statusAddr] = 1 << self.phyLsb

    def _doTransaction(self, transaction):
        with transaction.lock():
            address = transaction.address()
            size = transaction.size()
            data = bytearray(size)
            isWrite = transaction.type() in (rim.Write, rim.Post)
            if isWrite:
                transaction.getData(data, 0)
            if address >= self.GT_BASE:
                data = self.gt.access(address - self.GT_BASE, size, isWrite, data)
            else:
                self._lane(address, size, isWrite, data)
            if not isWrite:
                transaction.setData(bytes(data), 0)
            transaction.done()

    def _lane(self, address, size, isWrite, data):
        for beat in range(0, size, 4):
            addr = address + beat
            if isWrite:
                value = int.from_bytes(data[beat:beat + 4], 'little')
                old = self.words.get(addr, 0)
                self.words[addr] = value
                self.writes.append((addr, value))
                if addr == self.ctrlAddr:
                    self._ctrlWrite(old, value)
            else:
                self.reads += 1
                if addr == self.statusAddr:
                    self._statusRead()
                data[beat:beat + 4] = self.words.get(addr, 0).to_bytes(4, 'little')

    def _ctrlWrite(self, old, new):
        was = bitOf(old, self.resetLsb)
        now = bitOf(new, self.resetLsb)
        if now and not was:
            self.phyActive = False
            self._rise = 0
            self._setPhy()
        elif was and not now:
            self.gt.pmaReset()
            self._rise = self.riseReads

    def _statusRead(self):
        if not self.phyActive and self._rise > 0:
            self._rise -= 1
            if self._rise == 0:
                self.phyActive = True
                self._setPhy()

    def _setPhy(self):
        mask = 1 << self.phyLsb
        word = self.words.get(self.statusAddr, 0) & ~mask
        self.words[self.statusAddr] = word | (mask if self.phyActive else 0)


def _newRoot():
    return pr.Root(pollEn=False, initRead=False, initWrite=False, timeout=1.0)


def makeGtRoot(neighbours=True, **kw):
    """Started root with one Gthe3Channel over an emulated GT; returns (root, gt, model)."""
    import surf.xilinx as xil
    model = Gthe3EyeModel(**kw)
    root = _newRoot()
    gt = xil.Gthe3Channel(name='Gt', memBase=model)
    root.add(gt)
    model.seedHardwareLike(gt)
    if neighbours:
        model.seedNeighbours(gt)
    root.start()
    return root, gt, model


def makeLaneRoot(neighbours=True, riseReads=2, **kw):
    """Started root with a Pgp4AxiL lane and its Gthe3Channel behind LaneMemory.

    The reset hook is registered on the EyeScan child with ResetRx and
    PhyRxActive. Returns (root, gt, lane, model, mem).
    """
    import surf.protocols.pgp as pgp
    import surf.xilinx as xil
    model = Gthe3EyeModel(**kw)
    mem = LaneMemory(model, riseReads=riseReads)
    root = _newRoot()
    lane = pgp.Pgp4AxiL(name='Lane', offset=0x0, memBase=mem, writeEn=True, numVc=1)
    gt = xil.Gthe3Channel(name='Gt', offset=LaneMemory.GT_BASE, memBase=mem)
    root.add(lane)
    root.add(gt)
    model.seedHardwareLike(gt)
    if neighbours:
        model.seedNeighbours(gt)
    root.start()
    mem.attach(lane)
    gt.EyeScan.setRxReset(lane.Ctrl.ResetRx, lane.RxStatus.PhyRxActive,
                          settle=0.0, fallWait=0.05, timeout=0.5)
    return root, gt, lane, model, mem
