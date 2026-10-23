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
# - Sweep: Proxied reads and writes, then one failing transaction of each kind
#   (a proxy register that fails verify, a downstream SLVERR, an unsupported
#   Post transaction), each followed by a normal proxied access.
# - Stimulus: Real Rogue transactions through the PyRogue AxiLiteMasterProxy
#   against a simulated proxy register window (Rnw/Done/Resp/Addr/Data) that
#   forwards to a small downstream register map.
# - Checks: Each failure is reported on that transaction only; the proxy
#   worker thread stays alive and the next proxied access succeeds.
# - Timing: Synchronous memory transactions with a bounded Rogue timeout, so a
#   dead worker shows up as a timeout instead of a hang.

import pytest

pr = pytest.importorskip('pyrogue', reason='AxiLiteMasterProxy tests require Rogue/PyRogue')
rogue = pytest.importorskip('rogue', reason='AxiLiteMasterProxy tests require Rogue/PyRogue')
rim = pytest.importorskip('rogue.interfaces.memory')

from surf.axi import AxiLiteMasterProxy  # noqa: E402

TARGET_ADDR = 0x1000


class ProxyMemory(rim.Slave):
    """AxiLiteMasterProxy register window with a downstream register map."""

    def __init__(self):
        super().__init__(4, 4)
        self.regs = {0x0: 0, 0x8: 0, 0xC: 0}
        self.done = 0
        self.resp = 0
        self.downstream = {}
        self.staleAddrReads = 0   # Addr readbacks that return the previous value
        self.failNext = False     # next downstream transaction returns SLVERR
        self.prevAddr = 0

    def _doTransaction(self, transaction):
        with transaction.lock():
            addr = transaction.address()
            if transaction.type() in (rim.Write, rim.Post):
                data = bytearray(4)
                transaction.getData(data, 0)
                value = int.from_bytes(data, 'little')
                if addr == 0x8:
                    self.prevAddr = self.regs[0x8]
                self.regs[addr] = value
                if addr == 0x0:
                    # Writing Rnw starts the downstream transaction
                    if self.failNext:
                        self.failNext = False
                        self.resp = 2
                    else:
                        self.resp = 0
                        if value & 0x1:
                            self.regs[0xC] = self.downstream.get(self.regs[0x8], 0)
                        else:
                            self.downstream[self.regs[0x8]] = self.regs[0xC]
                    self.done = 1
            else:
                if addr == 0x4:
                    value = (self.resp << 1) | self.done
                elif addr == 0x8 and self.staleAddrReads > 0:
                    self.staleAddrReads -= 1
                    value = self.prevAddr
                else:
                    value = self.regs.get(addr, 0)
                transaction.setData(value.to_bytes(4, 'little'), 0)
            transaction.done()


class Target(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.add(pr.RemoteVariable(name='Reg', offset=0x0, bitSize=32, mode='RW'))


@pytest.fixture
def proxy_root():
    memory = ProxyMemory()
    root = pr.Root(pollEn=False, initRead=False, initWrite=False, timeout=1.0)
    root.add(AxiLiteMasterProxy(name='Proxy', memBase=memory))
    root.Proxy.add(Target(name='Target', offset=TARGET_ADDR))
    root.start()
    yield root, memory
    root.stop()


def roundTrip(root, value):
    root.Proxy.Target.Reg.set(value, write=True)
    return root.Proxy.Target.Reg.get(read=True)


def test_proxied_write_and_read(proxy_root):
    root, memory = proxy_root
    assert roundTrip(root, 0x1234_5678) == 0x1234_5678
    assert memory.downstream[TARGET_ADDR] == 0x1234_5678


def test_proxy_register_verify_error_keeps_worker_alive(proxy_root):
    root, memory = proxy_root
    assert roundTrip(root, 0x1111_1111) == 0x1111_1111

    # A stale Addr readback fails the proxy's own verify on the next access
    root.Proxy.Regs.Addr.set(0x2000, write=True)
    memory.staleAddrReads = 1
    with pytest.raises(rogue.GeneralError):
        root.Proxy.Target.Reg.get(read=True)

    assert root.Proxy.Regs._pollThread.is_alive()
    assert roundTrip(root, 0x2222_2222) == 0x2222_2222


def test_downstream_error_keeps_worker_alive(proxy_root):
    root, memory = proxy_root
    memory.failNext = True
    with pytest.raises(rogue.GeneralError):
        root.Proxy.Target.Reg.get(read=True)

    assert root.Proxy.Regs._pollThread.is_alive()
    assert roundTrip(root, 0x3333_3333) == 0x3333_3333


def test_unsupported_post_keeps_worker_alive(proxy_root):
    root, memory = proxy_root
    with pytest.raises(rogue.GeneralError):
        root.Proxy.Target.Reg.post(0x4444_4444)

    assert root.Proxy.Regs._pollThread.is_alive()
    assert roundTrip(root, 0x5555_5555) == 0x5555_5555
