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
# - Sweep: Upper page 00h reads through the QSFP upper-page proxy with an I2C
#   read failure on a plain variable, on a retrying string LinkVariable, and
#   on the page-select write.
# - Stimulus: Real Rogue transactions against a simulated SFF-8636 2-wire
#   memory (lower page, page-select byte 127, upper page 00h) behind a 32-bit
#   FPGA I2C bridge, with per-byte read failures and page-select NACKs.
# - Checks: A failed upper-page read raises instead of returning zeros; the
#   retrying LinkVariable recovers without counting an error; after any
#   failure the next access rewrites the page-select byte; the proxy worker
#   is a daemon thread.
# - Timing: Synchronous memory transactions with a bounded Rogue timeout.

import pytest

pr = pytest.importorskip('pyrogue', reason='QSFP tests require Rogue/PyRogue')
rogue = pytest.importorskip('rogue', reason='QSFP tests require Rogue/PyRogue')
rim = pytest.importorskip('rogue.interfaces.memory')

from surf.devices.transceivers import Qsfp  # noqa: E402

PAGE_SELECT = 127
CONNECTOR = 130          # upper page 00h byte 130
VENDOR_NAME = 148        # upper page 00h bytes 148-163


class QsfpMemory(rim.Slave):
    """SFF-8636 memory map at 4-byte strides in an FPGA I2C bridge window."""

    def __init__(self):
        super().__init__(4, 4)
        self.lower = [0] * 128
        self.upper = {0: [0] * 128}
        self.page = 0
        self.pageWrites = []
        self.failReads = {}       # byte -> number of reads that fail
        self.failPageWrites = 0

    def _doTransaction(self, transaction):
        with transaction.lock():
            byte = transaction.address() >> 2
            if transaction.type() in (rim.Write, rim.Post):
                data = bytearray(4)
                transaction.getData(data, 0)
                if byte == PAGE_SELECT:
                    if self.failPageWrites:
                        self.failPageWrites -= 1
                        transaction.error('page select NACK')
                        return
                    self.page = data[0]
                    self.pageWrites.append(data[0])
                elif byte < 128:
                    self.lower[byte] = data[0]
                else:
                    self.upper.setdefault(self.page, [0] * 128)[byte - 128] = data[0]
            else:
                if self.failReads.get(byte, 0):
                    self.failReads[byte] -= 1
                    transaction.error(f'I2C read of byte {byte} failed')
                    return
                if byte < 128:
                    value = self.lower[byte]
                else:
                    value = self.upper.get(self.page, [0] * 128)[byte - 128]
                transaction.setData(bytes([value, 0, 0, 0]), 0)
            transaction.done()


@pytest.fixture
def qsfp_root():
    memory = QsfpMemory()
    memory.upper[0][CONNECTOR - 128] = 0x0C
    for i, c in enumerate(b'FS              '):
        memory.upper[0][VENDOR_NAME - 128 + i] = c
    root = pr.Root(pollEn=False, initRead=False, initWrite=False, timeout=1.0)
    root.add(Qsfp(name='Qsfp', memBase=memory))
    root.start()
    try:
        yield root.Qsfp, memory
    finally:
        root.stop()


def test_upper_page_read_failure_is_reported_not_zero(qsfp_root):
    qsfp, memory = qsfp_root
    memory.failReads = {CONNECTOR: 1}

    with pytest.raises(rogue.GeneralError):
        qsfp.UpperPage00h.Connector.get(read=True)

    assert qsfp.UpperPage00h.Connector.get(read=True) == 0x0C
    assert qsfp.UpperPageProxy._pollThread.is_alive()


def test_retrying_string_recovers_without_counting_an_error(qsfp_root):
    qsfp, memory = qsfp_root
    memory.failReads = {VENDOR_NAME + 2: 1}

    assert qsfp.UpperPage00h.VendorName.get(read=True).strip() == 'FS'
    assert qsfp.ErrorCount.get() == 0


@pytest.mark.parametrize('failPageWrite', [False, True])
def test_page_select_is_rewritten_after_a_failure(qsfp_root, failPageWrite):
    qsfp, memory = qsfp_root
    assert qsfp.UpperPage00h.Connector.get(read=True) == 0x0C
    assert memory.pageWrites == [0]

    # A failed read (or a failed page-select write) disarms the proxy
    memory.failReads = {CONNECTOR: 1}
    with pytest.raises(rogue.GeneralError):
        qsfp.UpperPage00h.Connector.get(read=True)
    if failPageWrite:
        memory.failPageWrites = 1
        with pytest.raises(rogue.GeneralError):
            qsfp.UpperPage00h.Connector.get(read=True)

    assert qsfp.UpperPage00h.Connector.get(read=True) == 0x0C
    assert memory.pageWrites == [0, 0]


def test_upper_page_proxy_worker_is_daemon(qsfp_root):
    qsfp, _ = qsfp_root
    assert qsfp.UpperPageProxy._pollThread.daemon
