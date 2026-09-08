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
# - Sweep: GMII/XGMII autonomous endpoint, independent wire model and real MAC.
# - Stimulus: AXI-Lite configuration/commands, independent two-step master,
#   oscillator error, Delay_Req responses, loss and restart.
# - Checks: Register atomicity, timestamp provenance, acquisition, lock/holdover,
#   valid command sequencing, and primary traffic identity ownership.
# - Timing: The master's clock is simulation time, independent of the DUT PHC.
#   Wire timestamps include XGMII lane phase; every wait has a cycle bound.

import os
from fractions import Fraction
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, Lock
from cocotb.queue import Queue
from cocotb.utils import get_sim_time
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp
from tests.ethernet.PtpCore.ptp_wire_utils import xgmii_words, WireObserver, IDLE
from tests.ethernet.PtpCore.ptp_reference import NS, Q16, nearest

SOURCE = bytes.fromhex("001122fffe3344550001")
LOCAL = bytes.fromhex("020000fffe0000010001")

class Bench:
    def __init__(self, d):
        self.d = d
        self.mode = os.environ["MODE"]
        self.real_mac = os.environ["REAL_MAC"] == "1"
        self.frequency = 125000000 if self.mode == "GMII" else 156250000
        ppm = int(os.environ.get("OSCILLATOR_PPM", "0"))
        self.allow_step = os.environ.get("ALLOW_STEP", "1") == "1"
        self.period = 2*round(NS/self.frequency/(1+ppm/1000000)*1000000/2)/1000000
        self.other_tx = []
        self.rx_lock = Lock()
        self.responses = Queue()
        self.tx_frames = Queue()
        self.tx_count = 0
        self.epoch = 42*NS
        self.delay = Fraction(100)
        self.tasks = []
        for name in ("clk", "rst", "portRst", "regRst", "pauseEnable", "gmiiRxd", "gmiiRxDv", "gmiiRxEr",
                     "sAxisTValid", "sAxisTData", "sAxisTKeep", "sAxisTLast", "sAxisSof", "sAxisEofe", "sAxisTDest",
                     "modelGmiiTxd", "modelGmiiTxEn"):
            getattr(d, name).value = 0
        d.phyReady.value = 1
        d.localMac.value = int.from_bytes(bytes.fromhex("020000000001"), "little")
        d.mAxisTReady.value = 1
        d.modelTxReady.value = 1
        d.xgmiiRxd.value = d.modelXgmiiTxd.value = IDLE
        d.xgmiiRxc.value = d.modelXgmiiTxc.value = 255
        self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(d, "axil"), d.clk, d.rst)

    async def start(self):
        self.tasks.append(cocotb.start_soon(Clock(self.d.clk, self.period, unit="ns").start()))
        self.d.rst.value = 1
        await self.wait(12)
        self.d.rst.value = 0
        await self.wait(20)

    async def wait(self, count):
        for _ in range(count):
            await RisingEdge(self.d.clk)
            await Timer(1.1, unit="ns")

    async def write(self, address, value, width=4):
        result = await self.axil.write(address, value.to_bytes(width, "little"))
        assert result.resp == AxiResp.OKAY, (hex(address), result)

    async def read(self, address, width=4):
        result = await self.axil.read(address, width)
        assert result.resp == AxiResp.OKAY, (hex(address), result)
        return int.from_bytes(result.data, "little")

    async def snapshot(self):
        before = await self.read(0x104)
        await self.write(0x100, 1)
        for _ in range(20):
            if await self.read(0x104) != before:
                return
        assert False, "snapshot command timeout"

    async def manual(self, kind, value=0):
        await self.write(0x120, 0x80 | kind | (value << 3))
        for _ in range(100):
            state = await self.read(0x124)
            if not state & 1:
                assert state & 2 and not state & 4, state
                return
        assert False, "manual PHC command timeout"

    async def configure(self):
        await self.write(0x020, int.from_bytes(SOURCE, "big"), 12)
        # Short functional intervals retain the real PHC nominal increment.
        # Fractional correction fields avoid quantizing the independent source
        # to whole-ns accuracy during this accelerated packet schedule.
        for address, value in {0x200: 2500, 0x208: 10000, 0x210: 12000, 0x218: 16000,
                               0x220: 24000, 0x228: 12000, 0x230: 800, 0x238: 12000,
                               0x240: 500, 0x248: 12000}.items():
            await self.write(address, value, 8)
        await self.write(0x330, 3)
        await self.write(0x004, 0xF if self.allow_step else 0xB)
        await self.write(0x03C, 1)
        assert await self.read(0x040) == 0

    def frame(self, kind, sequence, remote=0, correction=0):
        size = {0: 44, 8: 44, 9: 54, 11: 64}[kind]
        message = bytearray(size)
        message[0:2] = bytes((kind, 0x12))
        message[2:4] = size.to_bytes(2, "big")
        message[6:8] = (0x200 if kind == 0 else 0).to_bytes(2, "big")
        message[8:16] = correction.to_bytes(8, "big", signed=True)
        message[20:30] = SOURCE
        message[30:32] = sequence.to_bytes(2, "big")
        message[32] = {0: 0, 8: 2, 9: 3, 11: 5}[kind]
        message[33] = 0x7f
        sec, ns = divmod(remote, NS)
        message[34:44] = sec.to_bytes(6, "big")+ns.to_bytes(4, "big")
        if kind == 9:
            message[44:54] = LOCAL
        return (bytes.fromhex("011b1900000000112233445588f7")+message).ljust(60, b"\x00")

    async def wire(self, frame, tx=False, lane=0, corrupt=False):
        d = self.d
        capture = None
        if self.mode == "XGMII":
            data = d.modelXgmiiTxd if tx else d.xgmiiRxd
            control = d.modelXgmiiTxc if tx else d.xgmiiRxc
            for index, (word, ctrl) in enumerate(xgmii_words(frame, lane=lane, corrupt_crc=corrupt)):
                await FallingEdge(d.clk)
                data.value = word
                control.value = ctrl
                await RisingEdge(d.clk)
                if index == 1:
                    capture = Fraction(int(get_sim_time(unit="fs")), 1000000)+Fraction(lane, 8)*Fraction(str(self.period))
            await FallingEdge(d.clk)
            data.value = IDLE
            control.value = 255
        else:
            import zlib
            data = d.modelGmiiTxd if tx else d.gmiiRxd
            enable = d.modelGmiiTxEn if tx else d.gmiiRxDv
            raw = b"\x55"*7+b"\xd5"+frame+zlib.crc32(frame).to_bytes(4, "little")
            for index, byte in enumerate(raw):
                await FallingEdge(d.clk)
                data.value = byte
                enable.value = 1
                await RisingEdge(d.clk)
                if index == 8:
                    capture = Fraction(int(get_sim_time(unit="fs")), 1000000)
            await FallingEdge(d.clk)
            enable.value = 0
            await self.wait(12)
        return capture

    async def model_mac(self):
        partial = bytearray()
        while True:
            await RisingEdge(self.d.clk)
            if int(self.d.modelTxValid.value) and int(self.d.modelTxReady.value):
                keep = int(self.d.modelTxKeep.value)
                if not partial:
                    assert int(self.d.modelTxSof.value)
                raw = int(self.d.modelTxData.value).to_bytes(8, "little")
                partial.extend(raw[:keep.bit_count()])
                if int(self.d.modelTxLast.value):
                    assert len(partial) == 58
                    await self.tx_frames.put(bytes(partial).ljust(60, b"\x00"))
                    partial.clear()

    async def model_wire(self):
        while True:
            frame = await self.tx_frames.get()
            await self.wire(frame, tx=True, lane=4 if self.mode == "XGMII" else 0)

    async def monitor_wire(self):
        observer = WireObserver(period_ns=Fraction(str(self.period)))
        gmii = bytearray()
        gmii_time = None
        while True:
            await RisingEdge(self.d.clk)
            now = Fraction(int(get_sim_time(unit="fs")), 1000000)
            frame = None
            capture = None
            if self.mode == "XGMII":
                count = len(observer.frames)
                observer.sample(int(self.d.xgmiiTxd.value), int(self.d.xgmiiTxc.value), now)
                if len(observer.frames) > count:
                    item = observer.frames[-1]
                    assert item.capture.valid
                    frame, capture = item.frame, item.capture.timestamp
            elif int(self.d.gmiiTxEn.value):
                if len(gmii) == 8:
                    gmii_time = now
                gmii.append(int(self.d.gmiiTxd.value))
            elif gmii:
                import zlib
                assert gmii[:8] == b"\x55"*7+b"\xd5"
                frame, capture = bytes(gmii[8:-4]), gmii_time
                assert int.from_bytes(gmii[-4:], "little") == zlib.crc32(frame)
                gmii.clear()
            if frame is not None and frame[12:14] == b"\x88\xf7":
                assert frame[14:18] == b"\x01\x12\x00\x2c"
                assert frame[20:30] == bytes(10)
                assert frame[34:44] == LOCAL
                assert frame[46:58] == b"\x01\x7f"+bytes(10)
                seq = int.from_bytes(frame[44:46], "big")
                self.tx_count += 1
                await self.responses.put((seq, capture+self.epoch+self.delay))
            elif frame is not None:
                self.other_tx.append(frame)

    async def respond(self):
        while True:
            seq, arrival = await self.responses.get()
            integer = int(arrival)
            correction = -nearest((arrival-integer)*Q16)
            async with self.rx_lock:
                await self.wire(self.frame(9, seq, integer, correction))

    async def source(self, count, sequence=0):
        for index in range(count):
            async with self.rx_lock:
                capture = await self.wire(self.frame(0, sequence+index), lane=4*(index % 2) if self.mode == "XGMII" else 0)
                origin = capture+self.epoch-self.delay
                integer = int(origin)
                await self.wire(self.frame(8, sequence+index, integer, nearest((origin-integer)*Q16)))
            await self.wait(2200)
            self.d._log.info("Sync %d: active=%s quality=%s valid=%s generation=%s tx=%d", sequence+index,
                             self.d.portActive.value, self.d.servoState.value, self.d.timeValid.value,
                             self.d.timeGeneration.value, self.tx_count)

    def stop(self):
        for task in self.tasks:
            task.cancel()
