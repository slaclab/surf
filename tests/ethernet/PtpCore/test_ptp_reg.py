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
# - Sweep: Four local AXI banks at zero/nonzero bases, decode/strobes/errors,
#   frozen candidates, all-or-none commits, shared limits, coherent snapshots,
#   MAC identity changes, immutable manual commands, and register-only reset.
# - Stimulus: Raw AXI-Lite transactions preserve deliberately unaligned addresses;
#   the real PHC prepares and executes commands while shadows are rewritten.
# - Checks: Active versus shadow state, local snapshot sequence/edge agreement,
#   full phase operand latching, accepted commit survival across AXI reset,
#   busy/ack/error ownership, IRQ W1C and build constants.
# - Timing: Clock edges are stepped explicitly; bus and command waits are bounded.

import os
import pytest
import cocotb
from cocotb.triggers import Timer
from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.PtpCore.ptp_reference import NS, Q16, Q32

@cocotb.test()
async def register_contract(d):
    base = int(os.environ["AXIL_BASE"])
    snapshots = []
    preparations = []
    applications = []
    for name in ('clk', 'rst', 'regRst', 'bankControlOverride', 'bankPrepare', 'bankApply', 'snapshotInhibit', 'axil_awaddr', 'axil_awvalid',
                 'axil_wdata', 'axil_wstrb', 'axil_wvalid', 'axil_araddr', 'axil_arvalid'):
        getattr(d, name).value = 0
    d.axil_bready.value = 1
    d.axil_rready.value = 1
    d.localMac.value = int.from_bytes(bytes.fromhex('020000000001'), 'little')

    async def edge(**values):
        d.clk.value = 0
        for name, value in values.items():
            getattr(d, name).value = value
        await Timer(4, unit='ns')
        observed = {name: int(getattr(d, 'axil_'+name).value) for name in
                    ('awready', 'wready', 'bvalid', 'bresp', 'arready', 'rvalid', 'rresp', 'rdata')}
        observed['configRestart'] = int(d.configRestart.value)
        if int(d.snapshotCapture.value):
            snapshots.append(int(d.timeTicks.value))
        if int(d.configPrepare.value):
            preparations.append(int(d.timeTicks.value))
        if int(d.configRestart.value):
            applications.append(int(d.timeTicks.value))
        d.clk.value = 1
        await Timer(4, unit='ns')
        return observed

    async def write(address, value, strobe=15, response=0):
        aw, w = 1, 1
        for _ in range(100):
            seen = await edge(axil_awvalid=aw, axil_awaddr=base+address, axil_wvalid=w,
                              axil_wdata=value, axil_wstrb=strobe)
            if seen['awready']:
                aw = 0
            if seen['wready']:
                w = 0
            if seen['bvalid']:
                assert not aw and not w
                assert seen['bresp'] == response, (hex(address), seen)
                return
        assert False, 'AXI write timeout'

    async def read(address, response=0):
        ar = 1
        for _ in range(100):
            seen = await edge(axil_arvalid=ar, axil_araddr=base+address)
            if seen['arready']:
                ar = 0
            if seen['rvalid']:
                assert not ar
                assert seen['rresp'] == response, (hex(address), seen)
                return seen['rdata']
        assert False, 'AXI read timeout'

    async def write_wide(address, value, words):
        for index in range(words):
            await write(address+4*index, (value >> (32*index)) & 0xffffffff)

    async def read_wide(address, words):
        value = 0
        for index in range(words):
            value |= (await read(address+4*index)) << (32*index)
        return value

    async def finish():
        for _ in range(100):
            value = await read(0x424)
            if not value & 1:
                assert value == 2
                return
        assert False, 'command acknowledgement timeout'

    async def commit(error=0):
        before = await read(0x048)
        await write(0x03C, 1)
        for _ in range(20):
            if await read(0x048) != before:
                assert await read(0x040) == error
                return
        assert False, 'configuration commit timeout'

    await edge(rst=1)
    await edge(rst=0)
    assert await read(0) == 0x20000
    # The crossbar decodes the actual base address; an unrelated high address
    # must not alias the bank selected by the same low 12 address bits.
    expected_base = base
    base = base ^ 0x10000000
    await read(0, response=3)
    await write(4, 3, response=3)
    base = expected_base
    for unused in (0x3F0, 0x7F0, 0xBF0, 0xFF0):
        await read(unused, response=3)
        await write(unused, 0, response=3)
    for unaligned in (0x005, 0x405, 0x805, 0xC05):
        await read(unaligned, response=2)
        await write(unaligned, 0, response=2)
    await read(0x3F0, response=3)
    await write(0x3F0, 1, response=3)
    await write(0x881, 0, response=2)
    assert await read_wide(0x880, 2) == 125000000
    await read(0x881, response=2)
    # SURF helpers require strobes covering the whole addressed field slice.
    # Narrow fields permit a byte write; a partial wide-field write is rejected.
    for address, value in ((0x004, 3), (0x404, 0), (0xC24, 0x03020100)):
        original = await read(address)
        await write(address, value, strobe=0, response=3)
        assert await read(address) == original
        if address == 0xC24:
            await write(address, value, strobe=1, response=3)
            assert await read(address) == original
        else:
            await write(address, value, strobe=1)
            assert await read(address) == (original & 0xFFFFFF00) | (value & 0xFF)
        await write(address, original)
    before = await read(0x808)
    await write(0x808, 0x201, strobe=1)
    assert await read(0x808) == (before & 0xFFFFFF00) | 1
    await write(0x808, 0)
    await write(0x8D0, 0, response=3)
    assert await read_wide(0x8D0, 2) == (1 << 64)-Q16
    assert await read_wide(0x8D8, 2) == 2*Q16
    assert await read(0x480) == 125000000
    assert await read_wide(0x8C0, 2) == 5000

    # Configuration stays inactive until one valid commit. Invalid commits leave
    # all active words intact, including the previous identity and enable bits.
    source = int('001122fffe3344550001', 16)
    await write_wide(0x820, source, 3)
    await write(0x810, 7)  # derive clock identity, preserve this port number
    await write(0x004, 1)
    assert not int(d.activeEnable.value)
    await commit()
    assert int(d.activeEnable.value)
    assert (await read_wide(0x870, 3)) == source
    assert (await read_wide(0x860, 3)) == int('020000fffe0000010007', 16)
    await write(0x8A4, 0x40000000)
    await write(0x004, 0)
    await commit(error=1)
    assert await read(0x040) == 1
    assert int(d.activeEnable.value)
    await write(0x8A4, 0)
    await write(0x004, 1)
    await commit()
    assert await read(0x040) == 0
    seen = await edge(localMac=int.from_bytes(bytes.fromhex('020000000002'), 'little'))
    assert seen['configRestart']
    assert (await read_wide(0x860, 3)) == int('020000fffe0000020007', 16)

    # Every owner validates its own candidate; one invalid servo setting must
    # prevent otherwise valid port and endpoint changes from taking effect.
    old_source = await read_wide(0x870, 3)
    await write_wide(0x820, source+1, 3)
    await write(0x004, 0)
    await write(0xC30, 200001)
    before_apply = len(applications)
    await commit(error=1)
    assert len(applications) == before_apply
    assert int(d.activeEnable.value)
    assert await read_wide(0x870, 3) == old_source
    await write(0xC30, 150000)
    await write(0x004, 1)
    await write_wide(0x820, source, 3)

    # Isolate the same bank prepare/apply pins used by the coordinator. Hold
    # candidates across multiple bus writes to prove they are immutable.
    await write(0xC20, 0x20000000)
    await write(0x404, 0)
    await write_wide(0x820, source+2, 3)
    await edge(bankControlOverride=1, bankPrepare=1)
    await edge(bankPrepare=0)
    await write(0xC20, 0x30000000)
    await write(0x404, 8)
    await write_wide(0x820, source+3, 3)
    await edge(bankApply=1)
    await edge(bankApply=0, bankControlOverride=0)
    assert await read(0xC94) == 0x20000000
    assert await read(0xC20) == 0x30000000
    assert await read(0x484) == 0
    assert await read(0x404) == 8
    assert await read_wide(0x870, 3) == source+2
    assert await read_wide(0x820, 3) == source+3
    await write(0xC20, 0x10000000)
    await write_wide(0x820, source, 3)
    await commit()
    assert await read(0xC94) == 0x10000000
    assert await read(0x484) == 8
    for port_addr, servo_addr in ((0x8E0, 0xCA0), (0x8E8, 0xCA8), (0x8F0, 0xCB0)):
        assert await read_wide(port_addr, 2) == await read_wide(servo_addr, 2)
        await write(servo_addr, 1, response=3)

    # Cancel a commit's AXI response while candidates are being prepared.
    # The accepted operation still applies every bank once, and software can
    # recover its completion through the sequence after the bus restarts.
    await write(0x004, 0)
    await write_wide(0x820, source+4, 3)
    sequence = await read(0x048)
    aw = w = 1
    for _ in range(40):
        count = len(preparations)
        seen = await edge(axil_awvalid=aw, axil_awaddr=base+0x03C,
                          axil_wvalid=w, axil_wdata=1, axil_wstrb=15)
        if seen['awready']:
            aw = 0
        if seen['wready']:
            w = 0
        if len(preparations) != count:
            break
    else:
        assert False, 'commit preparation was not observed'
    await edge(regRst=1, axil_awvalid=0, axil_wvalid=0)
    await edge(regRst=0)
    assert await read(0x048) == sequence+1
    assert not int(d.activeEnable.value)
    assert await read_wide(0x870, 3) == source+4
    await write(0x004, 1)
    await write_wide(0x820, source, 3)
    await commit()

    # Normalize a phase delta while PHC time is invalid. Mutating all shadow
    # words and resetting only the AXI endpoint cannot alter this queued command.
    delta = 2*NS*Q16+123*Q16+17
    await write_wide(0x438, delta, 4)
    before_ticks = int(d.timeTicks.value)
    before_time = (int(d.timeSeconds.value)*NS+int(d.timeNanoseconds.value))*Q32+int(d.timeFraction.value)
    await write(0x420, 0x81)
    await write_wide(0x438, (1 << 128)-99*Q16, 4)
    await write(0x420, 0x83, response=2)
    await write(0x03c, 1, response=2)
    await edge(regRst=1)
    await edge(regRst=0)
    assert await read(0x424) == 1
    await finish()
    elapsed = int(d.timeTicks.value)-before_ticks
    after_time = (int(d.timeSeconds.value)*NS+int(d.timeNanoseconds.value))*Q32+int(d.timeFraction.value)
    assert after_time-before_time == elapsed*8*Q32+delta*(1 << 16)
    assert int(d.timeGeneration.value) == 1
    assert int(d.activeEnable.value)

    # Multiword snapshots remain frozen while the PHC continues ticking.
    await write(0x100, 1)
    assert await read(0x104) == 1
    stamp = await read_wide(0x408, 4)
    ticks = await read_wide(0x460, 2)
    assert ticks == snapshots[-1]
    for bank_sequence in (0x7FC, 0xBFC, 0xFFC):
        assert await read(bank_sequence) == await read(0x104)
    for _ in range(20):
        await edge()
    assert await read_wide(0x408, 4) == stamp
    assert int(d.timeTicks.value) > ticks
    await write(0x050, 2)
    assert int(d.irq.value)
    await write(0x054, 2)
    assert not int(d.irq.value)

    # Automatic ownership rejects manual steering; PPS remains a safe command.
    await write(0x004, 3)
    await commit()
    await write(0x420, 0x82, response=2)
    await write(0x420, 0x8C)
    await finish()
    await edge(regRst=1)
    await edge(regRst=0)
    assert int(d.activeServo.value)
    assert int(d.timeGeneration.value) == 1

    # Accepted snapshots survive cancellation of bus responses. All three
    # local banks publish exactly one cohort once capture becomes qualified.
    sequence = await read(0x104)
    await edge(snapshotInhibit=1)
    await write(0x100, 1)
    assert await read(0x108) == 1
    await edge(regRst=1)
    await edge(regRst=0)
    assert await read(0x104) == sequence
    await edge(snapshotInhibit=0)
    for _ in range(5):
        await edge()
    assert await read(0x104) == sequence+1
    for bank_sequence in (0x7FC, 0xBFC, 0xFFC):
        assert await read(bank_sequence) == sequence+1
    assert await read_wide(0x460, 2) == snapshots[-1]


@pytest.mark.parametrize('base', [0, 0xA5800000])
def test_ptp_reg(base):
    run_surf_vhdl_test(test_file=__file__, toplevel='surf.ptpregwrapper',
                      parameters={'AXIL_BASE_ADDR_G': f'{base:032b}'}, extra_env={'AXIL_BASE': base})
