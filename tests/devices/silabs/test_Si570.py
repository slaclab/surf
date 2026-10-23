##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Sweep: Frequency programming on parts with different internal crystal
#   frequencies, a factory_freq that does not match the part, repeated
#   programming, supported and unsupported output
#   frequencies, N1/HS_DIV/RFREQ field packing, deferred writes, self-clearing
#   command bits followed by forced bulk writes, a stuck self-clearing bit,
#   RST_REG with transient or persistent I2C failures during the reset, a
#   register read failure while the DCO is frozen, a max_freq speed-grade
#   limit, and a set while the device is disabled.
# - Stimulus: Real Rogue writes and reads against a simulated Si570 register
#   window behind a 32-bit FPGA I2C bridge. The model reloads NVM on RECALL,
#   self-clears RST_REG/NewFreq/RECALL after a read, fails reads while RST_REG
#   holds the I2C state machine in reset, and preserves the reserved bits of
#   register 137. Starting values follow the Skyworks Si570 datasheet
#   rev 1.6, section 3.2 (156.25 MHz, RFREQ 0x2BC011EB8, HS_DIV 4, N1 8).
# - Checks: Programmed registers match the datasheet example; the generated
#   output matches the request for each part's own fxtal; an fxtal calibration
#   outside the datasheet tolerance is rejected before any configuration write;
#   the freeze, write,
#   unfreeze and NewFreq order; no configuration write while the DCO runs;
#   reserved bits survive; cached command bits are never replayed; RST_REG
#   rides through failed reads during the reset and still raises when the I2C
#   failure persists; a failed configuration write still unfreezes the DCO
#   and pulses NewFreq; requests above max_freq or on a disabled device write
#   nothing.
# - Timing: Synchronous memory transactions with a bounded Rogue timeout. The
#   10 ms unfreeze to NewFreq limit is checked as back-to-back writes; DCO
#   settling and I2C electrical timing are outside this model.

import pytest

pr = pytest.importorskip('pyrogue', reason='Si570 tests require Rogue/PyRogue')
rogue = pytest.importorskip('rogue', reason='Si570 tests require Rogue/PyRogue')
rim = pytest.importorskip('rogue.interfaces.memory')

import surf.devices.silabs._Si570 as si570_module  # noqa: E402
from surf.devices.silabs import Si570  # noqa: E402

FACTORY_FREQ = 156.25

# Datasheet section 3.2 start-up registers 7-12
DATASHEET_NVM = [0x01, 0xC2, 0xBC, 0x01, 0x1E, 0xB8]

RST_REG = 0x80
NEW_FREQ = 0x40
FREEZE_M = 0x20
RECALL = 0x01
FREEZE_DCO = 0x10
RESERVED_137 = 0x28


def nvmWithFxtalOffset(ppm):
    """Factory registers for a part whose fxtal is offset by ppm."""
    rfreq = round(0x2BC011EB8 / (1 + ppm * 1e-6))
    return [0x01, 0xC0 | (rfreq >> 32)] + list(rfreq.to_bytes(5, 'big')[1:])


def decode(regs):
    """Return (HS_DIV, N1, RFREQ) from registers 7-12."""
    hsDiv = {0: 4, 1: 5, 2: 6, 3: 7, 5: 9, 7: 11}[regs[0] >> 5]
    n1 = (((regs[0] & 0x1f) << 2) | (regs[1] >> 6)) + 1
    rfreq = int.from_bytes(bytes([regs[1] & 0x3f] + regs[2:]), 'big') / 2**28
    return hsDiv, n1, rfreq


class Si570Memory(rim.Slave):
    """Si570 registers at 4-byte strides in an FPGA I2C bridge window."""

    def __init__(self, nvm):
        super().__init__(4, 4)
        self.nvm = list(nvm)
        self.config = list(nvm)
        self.reg135 = 0
        self.reg137 = RESERVED_137
        self.pending = 0
        self.stuck = 0
        # Reads that fail after RST_REG while the I2C state machine resets
        self.resetNacks = 1
        self.nackedReads = 0
        self.i2cResetReads = 0
        self.recalls = 0
        self.newFreqs = []
        self.unfrozenConfigWrites = []
        self.writes = []
        # Register reads (including verify) that fail once each, by register
        self.failReads = {}

        # fxtal implied by the factory configuration
        hsDiv, n1, rfreq = decode(self.nvm)
        self.fxtal = FACTORY_FREQ * hsDiv * n1 / rfreq

    def output(self):
        """Output frequency produced by the current configuration."""
        hsDiv, n1, rfreq = decode(self.config)
        return self.fxtal * rfreq / (hsDiv * n1)

    def _doTransaction(self, transaction):
        with transaction.lock():
            reg = transaction.address() // 4
            if (reg not in (*range(7, 13), 135, 137) or transaction.address() % 4
                    or transaction.size() != 4):
                transaction.error('Unexpected Si570 register access')
                return
            if transaction.type() in (rim.Write, rim.Post):
                data = bytearray(4)
                transaction.getData(data, 0)
                value = data[0]
                self.writes.append((reg, value))
                if reg == 135:
                    self.reg135 = value & (FREEZE_M | 0x10)
                    self.pending |= value & (RST_REG | NEW_FREQ | RECALL)
                    if value & (RST_REG | RECALL):
                        self.recalls += 1
                        self.config = list(self.nvm)
                    if value & RST_REG:
                        self.i2cResetReads = self.resetNacks
                    if value & NEW_FREQ:
                        self.newFreqs.append(bool(self.reg137 & FREEZE_DCO))
                elif reg == 137:
                    self.reg137 = value
                else:
                    if not self.reg137 & FREEZE_DCO:
                        self.unfrozenConfigWrites.append(reg)
                    self.config[reg - 7] = value
            else:
                if self.failReads.get(reg, 0):
                    self.failReads[reg] -= 1
                    transaction.error(f'Si570 register {reg} read failed')
                    return
                if self.i2cResetReads:
                    self.i2cResetReads -= 1
                    self.nackedReads += 1
                    transaction.error('Si570 I2C state machine in reset')
                    return
                if reg == 135:
                    value = self.reg135 | self.pending
                    # Operations complete after one observed busy read
                    self.pending &= self.stuck
                elif reg == 137:
                    value = self.reg137
                else:
                    value = self.config[reg - 7]
                transaction.setData(bytes([value, 0, 0, 0]), 0)
            transaction.done()


def makeRoot(nvm=DATASHEET_NVM, factoryFreq=FACTORY_FREQ, **kwargs):
    memory = Si570Memory(nvm)
    root = pr.Root(pollEn=False, initRead=False, initWrite=False, timeout=1.0)
    root.add(Si570(name='Si570', factory_freq=factoryFreq, memBase=memory, **kwargs))
    return root, memory


@pytest.fixture
def si570_root():
    root, memory = makeRoot()
    try:
        root.start()
        yield root, root.Si570, memory
    finally:
        root.stop()


def test_first_frequency_set_matches_datasheet_example(si570_root):
    _, si570, memory = si570_root

    si570.Frequency.set(161.132812)

    # Datasheet section 3.2 step 7
    assert memory.config == [0x01, 0xC2, 0xD1, 0xE1, 0x27, 0x88]
    assert memory.recalls == 1
    assert si570.fxtal.get() == pytest.approx(114.285, abs=1e-6)
    assert si570.Frequency.get() == pytest.approx(161.132812, rel=1e-9)


def test_frequency_update_sequence(si570_root):
    _, si570, memory = si570_root

    si570.Frequency.set(200.0)

    writes = memory.writes
    recall = writes.index((135, RECALL))
    freeze = writes.index((137, RESERVED_137 | FREEZE_DCO))
    unfreeze = writes.index((137, RESERVED_137))
    assert recall < freeze < unfreeze
    assert {reg for reg, _ in writes[freeze + 1:unfreeze]} == set(range(7, 13))
    assert writes[unfreeze + 1:] == [(135, NEW_FREQ)]
    assert memory.newFreqs == [False]
    assert memory.unfrozenConfigWrites == []


@pytest.mark.parametrize('ppm', [-1500, 0, 1000])
def test_output_uses_each_parts_own_fxtal(ppm):
    root, memory = makeRoot(nvmWithFxtalOffset(ppm))
    with root:
        assert memory.fxtal == pytest.approx(114.285 * (1 + ppm * 1e-6), rel=1e-9)

        for target in (161.132812, 156.25, 371.428571):
            root.Si570.Frequency.set(target)
            assert memory.output() == pytest.approx(target, rel=1e-9)
            assert root.Si570.Frequency.get() == pytest.approx(target, rel=1e-9)

        # fxtal is calibrated once; later changes do not reload the factory state
        assert memory.recalls == 1
        assert len(memory.newFreqs) == 3


@pytest.mark.parametrize('factoryFreq', [100.0, FACTORY_FREQ * (1 - 0.004), FACTORY_FREQ * (1 + 0.0031)])
def test_mismatched_factory_freq_is_rejected_before_any_config_write(factoryFreq):
    root, memory = makeRoot(factoryFreq=factoryFreq)
    with root:
        with pytest.raises(ValueError, match='fxtal'):
            root.Si570.Frequency.set(161.132812)

        assert root.Si570.fxtal.get() == 0.0
        assert memory.recalls == 1
        assert {reg for reg, _ in memory.writes} == {135}
        assert memory.config == DATASHEET_NVM


def test_factory_freq_within_datasheet_tolerance_is_accepted():
    root, memory = makeRoot(factoryFreq=FACTORY_FREQ * (1 + 0.002))
    with root:
        root.Si570.Frequency.set(161.132812)
        assert root.Si570.fxtal.get() == pytest.approx(114.285 * 1.002, rel=1e-9)


def test_self_clearing_bits_are_not_replayed(si570_root):
    root, si570, memory = si570_root
    si570.Frequency.set(161.132812)
    si570.RST_REG()
    si570.Frequency.set(161.132812)
    memory.writes.clear()

    root.ForceWrite.set(True)
    root.WriteAll()
    si570.FreezeM.set(1)
    si570.FreezeM.set(0)

    assert [v for r, v in memory.writes if r == 135] == [0, FREEZE_M, 0]
    assert memory.recalls == 2
    assert len(memory.newFreqs) == 2


def test_stuck_self_clearing_bit_times_out_without_replay(si570_root, monkeypatch):
    _, si570, memory = si570_root
    monkeypatch.setattr(si570_module, '_POLL_TIMEOUT', 0.05)
    memory.stuck = RECALL

    with pytest.raises(TimeoutError, match='RECALL'):
        si570.RECALL()

    memory.stuck = 0
    memory.writes.clear()
    si570.FreezeM.set(1)

    assert memory.writes == [(135, FREEZE_M)]
    assert memory.recalls == 1


def test_rst_reg_rides_through_i2c_interruption(si570_root):
    _, si570, memory = si570_root
    memory.resetNacks = 3

    si570.RST_REG()

    assert memory.recalls == 1
    assert memory.nackedReads == 3
    assert si570.RST_REG.value() == 0

    memory.writes.clear()
    si570.FreezeM.set(1)
    assert memory.writes == [(135, FREEZE_M)]


def test_rst_reg_persistent_i2c_failure_raises_without_replay(si570_root, monkeypatch):
    _, si570, memory = si570_root
    monkeypatch.setattr(si570_module, '_POLL_TIMEOUT', 0.05)
    memory.resetNacks = 10**6

    with pytest.raises(rogue.GeneralError, match='I2C state machine in reset'):
        si570.RST_REG()

    memory.i2cResetReads = 0
    memory.writes.clear()
    si570.FreezeM.set(1)
    assert memory.writes == [(135, FREEZE_M)]


def test_rfreq_and_n1_share_register_8(si570_root):
    _, si570, memory = si570_root
    rfreq = (1 << 37) | 0x123456789

    si570.RFREQ_RAW.set(rfreq)
    si570.N1.set(10)

    assert memory.config[0] & 0x1f == 0b00010
    assert memory.config[1] == 0x40 | 0x20 | 0x01
    assert si570.RFREQ_RAW.get() == rfreq
    assert si570.N1.get() == 10


def test_deferred_field_writes(si570_root):
    _, si570, memory = si570_root

    si570.N1.set(4, write=False)
    si570.HS_DIV_INT.set(5, write=False)
    si570.RFREQ.set(43.75, write=False)
    assert memory.writes == []

    si570.writeAndVerifyBlocks()
    assert decode(memory.config) == (5, 4, 43.75)


def test_n1_limits(si570_root):
    _, si570, memory = si570_root

    si570.N1.set(128)
    assert si570.N1_RAW.get() == 127

    memory.writes.clear()
    for n1 in (0, 3, 129, 130):
        with pytest.raises(ValueError, match='N1'):
            si570.N1.set(n1)
    assert memory.writes == []


@pytest.mark.parametrize('freq', [5.0, 950.0, 1500.0])
def test_unsupported_frequency_is_rejected_before_any_write(si570_root, freq):
    _, si570, memory = si570_root

    with pytest.raises(ValueError, match='cannot generate'):
        si570.Frequency.set(freq)

    assert memory.writes == []


def test_disabled_device_ignores_frequency_set(si570_root, caplog):
    _, si570, memory = si570_root
    si570.enable.set(False)

    with caplog.at_level('WARNING'):
        si570.Frequency.set(161.132812)

    assert memory.writes == []
    assert si570.fxtal.get() == 0.0
    assert 'is disabled' in caplog.text


def test_failed_config_write_unfreezes_and_applies(si570_root):
    _, si570, memory = si570_root
    si570.Frequency.set(161.132812)

    # The verify read of register 12 fails after the DCO is frozen
    memory.failReads = {12: 1}
    memory.newFreqs.clear()
    with pytest.raises(Exception):
        si570.Frequency.set(200.0)

    # The DCO must not stay frozen on dividers it was not retuned for
    assert not memory.reg137 & FREEZE_DCO
    assert memory.reg137 & RESERVED_137 == RESERVED_137
    assert memory.newFreqs == [False]

    # The next request programs normally
    si570.Frequency.set(125.0)
    assert memory.output() == pytest.approx(125.0, rel=1e-9)
    assert not memory.reg137 & FREEZE_DCO


@pytest.mark.parametrize('freq', [810.000001, 850.0, 1300.0])
def test_max_freq_rejects_above_part_grade_before_any_write(freq):
    root, memory = makeRoot(max_freq=810.0)
    root.start()
    try:
        with pytest.raises(ValueError, match='max_freq'):
            root.Si570.Frequency.set(freq)
        assert memory.writes == []

        root.Si570.Frequency.set(810.0)
        assert memory.output() == pytest.approx(810.0, rel=1e-9)
    finally:
        root.stop()
