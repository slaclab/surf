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
# - Sweep: Physical offsets, four-byte/bulk transports, page enable state,
#   reads, rejected non-read requests, and selection/read/restoration failures.
# - Stimulus: Use real Rogue roots and memory transactions against an EEPROM
#   model whose two pages share a physical window. Inject failures and pause
#   selection to exercise concurrent access and transaction expiration.
# - Checks: Independent page caches, correct physical page/address/data,
#   bounded selection traffic, read-only enforcement, propagated errors, recovery,
#   invalid-request rejection, and worker startup/shutdown.
# - Timing: Threading events establish transaction ordering; waits are bounded.
#   Raw Rogue masters exercise queued and in-flight timeouts. No FPGA, I2C
#   electrical timing, or SPD timing/capacity decoding is modeled here.

from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
import threading

import pytest

pr = pytest.importorskip('pyrogue', reason='SPD proxy tests require Rogue/PyRogue')
rogue = pytest.importorskip('rogue', reason='SPD proxy tests require Rogue/PyRogue')
rim = pytest.importorskip('rogue.interfaces.memory')

from surf.devices.micron import DdrSpd, Tse2004av  # noqa: E402


class PagedMemory(rim.Slave):
    """FPGA register-window model: one SPD byte per 32-bit word."""

    def __init__(self, base=0, selects=(0x400, 0x800), maxAccess=0x1000):
        super().__init__(4, maxAccess)
        self.base = base
        self.selects = selects
        self.pages = [bytearray((i + 17) % 256 for i in range(256)),
                      bytearray((i + 139) % 256 for i in range(256))]
        self.pages[0][4] = 5
        self.pages[0][12] = 9
        self.pages[0][13] = 0x0b
        self.pages[0][14] = 0x80
        self.pages[0][18] = 6
        self.pages[1][69:73] = bytes.fromhex('12345678')
        self.pages[1][73:93] = b'EXAMPLE-DDR4-MODULE'.ljust(20, b' ')
        self.page = 0
        self.operations = []
        self.failures = []
        self.upperSelected = None
        self.releaseUpper = None

    def _doTransaction(self, transaction):
        with transaction.lock():
            address = transaction.address() - self.base
            size = transaction.size()
            kind = transaction.type()
            writing = kind in (rim.Write, rim.Post)
            if writing and address in self.selects:
                selected = self.selects.index(address)
                operation = f'select{selected}'
            elif 0 <= address and address + size <= 0x400:
                operation = 'write' if writing else 'read'
            else:
                transaction.error(f'Unmapped physical access: 0x{address:x}')
                return
            self.operations.append((operation, address, size, self.page, kind))

            if self.failures and self.failures[0] == (operation, self.page):
                self.failures.pop(0)
                # An SPA1 error need not mean the device stayed on page zero.
                if operation == 'select1':
                    self.page = 1
                transaction.error(f'injected {operation} failure')
                return

            if operation.startswith('select'):
                self.page = selected
                if selected == 1 and self.upperSelected is not None:
                    self.upperSelected.set()
                    if not self.releaseUpper.wait(5):
                        transaction.error('test did not release page selection')
                        return
            elif writing:
                data = bytearray(size)
                transaction.getData(data, 0)
                for index in range(0, size, 4):
                    self.pages[self.page][(address + index) // 4] = data[index]
            else:
                data = bytearray(size)
                for index in range(0, size, 4):
                    data[index] = self.pages[self.page][(address + index) // 4]
                transaction.setData(data, 0)
            transaction.done()


@contextmanager
def spd_root(*, parentOffset=0, spdOffset=0, selects=(0x400, 0x800),
             maxAccess=0x1000, sensor=False):
    memory = PagedMemory(parentOffset + spdOffset, selects, maxAccess)
    root = pr.Root(pollEn=False, initRead=False, initWrite=False, timeout=1.0)
    parent = pr.Device(name='Fpga', offset=parentOffset, memBase=memory)
    root.add(parent)
    spd = DdrSpd(name='Spd', offset=spdOffset,
                 spa0Offset=selects[0], spa1Offset=selects[1])
    parent.add(spd)
    if sensor:
        parent.add(Tse2004av(name='Sensor', offset=spdOffset + 0x400))
    try:
        root.start()
        yield root, spd, memory
    finally:
        if memory.releaseUpper is not None:
            memory.releaseUpper.set()
        root.stop()


@pytest.mark.parametrize('maxAccess', [4, 0x1000])
@pytest.mark.parametrize('parentOffset,spdOffset,selects', [
    (0, 0, (0x400, 0x800)),
    (0x10000, 0x2000, (0x1000, 0x1800)),
])
def test_full_pages_have_independent_caches(parentOffset, spdOffset, selects, maxAccess):
    with spd_root(parentOffset=parentOffset, spdOffset=spdOffset,
                  selects=selects, maxAccess=maxAccess) as (_, spd, memory):
        lower = list(spd.Mem.get())
        summary = spd.Page0Summary.get(read=False)
        assert lower == list(memory.pages[0])
        assert all(op[0] == 'read' for op in memory.operations)

        spd.Page1.enable.set(True)
        memory.operations.clear()
        assert spd.Page1.PartNumber.get() == 'EXAMPLE-DDR4-MODULE'
        assert spd.Page1.SerialNumber.get(read=False) == '12345678'
        assert list(spd.Page1.Mem.get(read=False)) == list(memory.pages[1])
        assert list(spd.Mem.get(read=False)) == lower
        assert spd.Page0Summary.get(read=False) == summary
        assert memory.page == 0
        # One page selection and restoration for the entire array read.
        assert [op[0] for op in memory.operations].count('select1') == 1
        assert [op[0] for op in memory.operations].count('select0') == 1
        assert [op[1] for op in memory.operations if op[0] == 'read'] == list(range(0, 0x400, 4))


def test_disabled_page_does_not_claim_or_write_selector_windows():
    # The old two-slave bridge can place the sensor where SPA0 would be in
    # a future map. Constructing the SPD device must not claim that address.
    with spd_root(sensor=True) as (root, spd, memory):
        assert spd.Page1.enable.value() is False
        spd.Mem.get()
        lower, upper = [page[:] for page in memory.pages]
        memory.operations.clear()
        # Limit the forced write to SPD; the modeled sensor is present only
        # to check root-level address ownership.
        spd.writeAndVerifyBlocks(force=True)
        assert memory.operations == []
        assert memory.pages == [lower, upper]
        assert memory.page == 0
        assert root.Fpga.Sensor.ManufacturerId.offset == 0x18


@pytest.mark.parametrize('page1Enabled', [False, True])
def test_variable_writes_and_forced_write_all_do_not_touch_hardware(page1Enabled):
    with spd_root() as (root, spd, memory):
        spd.Page1.enable.set(page1Enabled)
        pages = [page[:] for page in memory.pages]
        for variable in (spd.Mem, spd.Page1.Mem):
            assert variable.mode == 'RO'
            # Rogue permits updating an RO variable's local cache, but its
            # block must suppress hardware writes, including posted writes.
            variable.set(index=100, value=0x31)
            variable.post(0x72, index=100)
        root.ForceWrite.set(True)
        root.WriteAll()
        assert memory.operations == []
        assert memory.pages == pages
        assert memory.page == 0


def test_concurrent_lower_read_waits_for_upper_page(monkeypatch):
    with spd_root() as (_, spd, memory):
        spd.Page1.enable.set(True)
        lower, upper = memory.pages[0][100], memory.pages[1][100]
        memory.upperSelected = threading.Event()
        memory.releaseUpper = threading.Event()
        lowerSubmitted = threading.Event()
        original = spd._doTransaction

        def observe_submission(transaction):
            address = transaction.address()
            original(transaction)
            if address == 100 * 4:
                lowerSubmitted.set()

        monkeypatch.setattr(spd, '_doTransaction', observe_submission)
        with ThreadPoolExecutor(max_workers=2) as executor:
            first = executor.submit(spd.Page1.Mem.get, index=100)
            try:
                assert memory.upperSelected.wait(3)
                second = executor.submit(spd.Mem.get, index=100)
                assert lowerSubmitted.wait(3)
            finally:
                memory.releaseUpper.set()
            assert first.result(timeout=3) == upper
            assert second.result(timeout=3) == lower
            assert memory.page == 0


@pytest.mark.parametrize('failures', [
    [('select1', 0)],
    [('read', 1)],
    [('select0', 1)],
    [('read', 1), ('select0', 1)],
])
def test_failure_is_reported_and_next_lower_access_recovers(failures):
    with spd_root() as (_, spd, memory):
        spd.Page1.enable.set(True)
        memory.failures = failures[:]
        with pytest.raises(rogue.GeneralError, match='injected') as caught:
            spd.Page1.Mem.get(index=100)
        for phase, _ in failures:
            assert f'injected {phase} failure' in str(caught.value)
        assert not memory.failures
        assert memory.operations[-1][0] == 'select0'
        assert spd.PageProxy.ErrorCount.value() == 1

        # Disabling page 1 after a restoration failure must not suppress
        # the page-zero selection needed to recover the shared window.
        spd.Page1.enable.set(False)
        assert spd.Mem.get(index=100) == memory.pages[0][100]
        assert memory.page == 0


def make_master(slave, timeout=1000000):
    master = rim.Master()
    master._setSlave(slave)
    master._setTimeout(timeout)
    return master


def test_expired_queued_request_does_not_touch_hardware():
    with spd_root() as (_, spd, memory):
        spd.Page1.enable.set(True)
        master = make_master(spd.Page1, timeout=10000)
        data = bytearray(4)
        with spd.PageProxy._memLock:
            tid = master._reqTransaction(100 * 4, data, 4, 0, rim.Read)
            master._waitTransaction(tid)
            assert 'Timeout' in master._getError()
            assert memory.operations == []
        # This later request fences the queued work before checking bus traffic.
        assert spd.Page1.Mem.get(index=101) == memory.pages[1][101]
        assert [(op[0], op[1]) for op in memory.operations] == [
            ('select1', 0x800), ('read', 101 * 4), ('select0', 0x400)]
        assert spd.PageProxy.ErrorCount.value() == 0


def test_timeout_during_selection_still_restores_lower_page():
    with spd_root() as (_, spd, memory):
        spd.Page1.enable.set(True)
        memory.upperSelected = threading.Event()
        memory.releaseUpper = threading.Event()
        master = make_master(spd.Page1, timeout=10000)
        data = bytearray(4)
        tid = master._reqTransaction(100 * 4, data, 4, 0, rim.Read)
        try:
            assert memory.upperSelected.wait(3)
            master._waitTransaction(tid)
            assert 'Timeout' in master._getError()
        finally:
            memory.releaseUpper.set()
        assert spd.Mem.get(index=101) == memory.pages[0][101]
        assert not any(op[0] == 'read' and op[1] == 100 * 4 for op in memory.operations)
        assert memory.page == 0


@pytest.mark.parametrize('address,size', [(1, 4), (0, 3), (0x3fc, 8), (0x800, 4)])
def test_invalid_virtual_requests_do_not_alias_hardware(address, size):
    with spd_root() as (_, spd, memory):
        master = make_master(spd)
        data = bytearray(size)
        tid = master._reqTransaction(address, data, size, 0, rim.Read)
        master._waitTransaction(tid)
        assert master._getError()
        assert memory.operations == []


def test_raw_master_cannot_bypass_page1_enable():
    with spd_root() as (_, spd, memory):
        master = make_master(spd.Page1)
        data = bytearray(4)
        tid = master._reqTransaction(0, data, 4, 0, rim.Read)
        master._waitTransaction(tid)
        assert 'disabled' in master._getError()
        assert memory.operations == []


def test_non_read_transactions_cannot_bypass_read_only_variables():
    with spd_root() as (_, spd, memory):
        spd.Page1.enable.set(True)
        pages = [page[:] for page in memory.pages]
        master = make_master(spd)
        for address in (100 * 4, 0x400 + 100 * 4):
            for kind in (rim.Write, rim.Post, rim.Verify):
                master._clearError()
                data = bytearray([0x73, 0, 0, 0])
                tid = master._reqTransaction(address, data, 4, 0, kind)
                master._waitTransaction(tid)
                assert 'read-only' in master._getError()
        assert memory.operations == []
        assert memory.pages == pages
        assert memory.page == 0


def test_worker_follows_root_lifecycle():
    spd = DdrSpd(name='Spd', memBase=PagedMemory())
    assert spd.PageProxy._pollThread is None
    root = pr.Root(pollEn=False, initRead=False)
    root.add(spd)
    try:
        root.start()
        thread = spd.PageProxy._pollThread
        assert thread.is_alive()
    finally:
        root.stop()
    assert not thread.is_alive()
    master = make_master(spd)
    data = bytearray(4)
    tid = master._reqTransaction(0, data, 4, 0, rim.Read)
    master._waitTransaction(tid)
    assert 'not running' in master._getError()


def test_shutdown_rejects_queued_work_and_restores_active_page(monkeypatch):
    with spd_root() as (_, spd, memory):
        spd.Page1.enable.set(True)
        memory.upperSelected = threading.Event()
        memory.releaseUpper = threading.Event()
        stopping = threading.Event()
        original_put = spd.PageProxy._queue.put

        def observe_stop(item):
            original_put(item)
            if item is None:
                stopping.set()

        monkeypatch.setattr(spd.PageProxy._queue, 'put', observe_stop)
        first = make_master(spd.Page1)
        second = make_master(spd)
        firstData, secondData = bytearray(4), bytearray(4)
        firstId = first._reqTransaction(100 * 4, firstData, 4, 0, rim.Read)
        try:
            assert memory.upperSelected.wait(3)
            secondId = second._reqTransaction(101 * 4, secondData, 4, 0, rim.Read)
            with ThreadPoolExecutor(max_workers=1) as executor:
                stopped = executor.submit(spd.PageProxy._stop)
                try:
                    assert stopping.wait(3)
                finally:
                    memory.releaseUpper.set()
                stopped.result(timeout=3)
        finally:
            memory.releaseUpper.set()
        first._waitTransaction(firstId)
        second._waitTransaction(secondId)
        assert 'stopping' in first._getError()
        assert 'stopping' in second._getError()
        assert [op[0] for op in memory.operations] == ['select1', 'select0']
        assert memory.page == 0


def test_instantiate_false_remains_a_physical_device():
    root = pr.Root(pollEn=False, initRead=False)
    spd = DdrSpd(instantiate=False, memBase=rim.Emulate(4, 0x1000), offset=0x100)
    spd.add(pr.RemoteVariable(name='Custom', offset=0, bitSize=32))
    root.add(spd)
    try:
        root.start()
        spd.Custom.set(0x12345678)
        assert spd.Custom.get() == 0x12345678
    finally:
        root.stop()
