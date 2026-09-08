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
# - Sweep: AXI byte strobes/alignment/errors, atomic configuration, MAC identity
#   changes, manual command backpressure, shadow edits, and register-only reset.
# - Stimulus: Raw AXI-Lite transactions preserve deliberately unaligned addresses;
#   the real PHC executes commands after the wrapper releases backpressure.
# - Checks: Active versus shadow state, full phase operand latching, stable
#   coherent snapshots, busy/ack/error ownership, IRQ W1C and build constants.
# - Timing: Clock edges are stepped explicitly; bus and command waits are bounded.

import cocotb
from cocotb.triggers import Timer
from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.PtpCore.ptp_reference import NS, Q16, Q32

@cocotb.test()
async def register_contract(d):
    for name in ('clk', 'rst', 'regRst', 'commandBlock', 'axil_awaddr', 'axil_awvalid',
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
        d.clk.value = 1
        await Timer(4, unit='ns')
        return observed

    async def write(address, value, strobe=15, response=0):
        aw, w = 1, 1
        for _ in range(100):
            seen = await edge(axil_awvalid=aw, axil_awaddr=address, axil_wvalid=w,
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
            seen = await edge(axil_arvalid=ar, axil_araddr=address)
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
            value = await read(0x124)
            if not value & 1:
                assert value == 2
                return
        assert False, 'command acknowledgement timeout'

    await edge(rst=1)
    await edge(rst=0)
    assert await read(0) == 0x10000
    await read(0x800, response=3)
    await write(0x800, 1, response=3)
    await write(0x201, 0, response=2)
    assert await read_wide(0x200, 2) == 125000000
    await read(0x201, response=2)
    before = await read(0x008)
    await write(0x008, 0x201, strobe=1)
    assert await read(0x008) == (before & 0xFFFFFF00) | 1
    await write(0x008, 0)
    await write(0x410, 0, response=3)
    assert await read_wide(0x410, 2) == (1 << 64)-Q16
    assert await read_wide(0x418, 2) == 2*Q16
    assert await read(0x380) == 125000000
    assert await read_wide(0x384, 2) == 5000

    # Configuration stays inactive until one valid commit. Invalid commits leave
    # all active words intact, including the previous identity and enable bits.
    source = int('001122fffe3344550001', 16)
    await write_wide(0x020, source, 3)
    await write(0x010, 7)  # derive clock identity, preserve this port number
    await write(0x004, 0x9)
    assert not int(d.activeEnable.value)
    await write(0x03c, 1)
    assert int(d.activeEnable.value)
    assert int(d.activeSource.value) == source
    assert int(d.activeLocal.value) == int('020000fffe0000010007', 16)
    await write(0x234, 0x40000000)
    await write(0x004, 0x8)
    await write(0x03c, 1, response=2)
    assert await read(0x040) == 1
    assert int(d.activeEnable.value)
    await write(0x234, 0)
    await write(0x004, 0x9)
    await write(0x03c, 1)
    assert await read(0x040) == 0
    await edge(localMac=int.from_bytes(bytes.fromhex('020000000002'), 'little'))
    assert int(d.configRestart.value)
    assert int(d.activeLocal.value) == int('020000fffe0000020007', 16)

    # Normalize a phase delta while PHC time is invalid. Mutating all shadow
    # words and resetting only the AXI endpoint cannot alter this queued command.
    delta = 2*NS*Q16+123*Q16+17
    await write_wide(0x138, delta, 4)
    await edge(commandBlock=1)
    await write(0x120, 0x81)
    await write_wide(0x138, (1 << 128)-99*Q16, 4)
    await write(0x120, 0x83, response=2)
    await write(0x03c, 1, response=2)
    await edge(regRst=1)
    await edge(regRst=0)
    for _ in range(200):
        if int(d.commandValid.value):
            break
        await edge()
    assert int(d.commandValid.value)
    assert int(d.commandPhaseSeconds.value) == 2
    assert int(d.commandPhaseFraction.value) == (123*Q16+17) << 16
    assert await read(0x124) == 1
    before_ticks = int(d.timeTicks.value)
    before_time = (int(d.timeSeconds.value)*NS+int(d.timeNanoseconds.value))*Q32+int(d.timeFraction.value)
    await edge(commandBlock=0)
    await finish()
    elapsed = int(d.timeTicks.value)-before_ticks
    after_time = (int(d.timeSeconds.value)*NS+int(d.timeNanoseconds.value))*Q32+int(d.timeFraction.value)
    assert after_time-before_time == elapsed*8*Q32+delta*(1 << 16)
    assert int(d.timeGeneration.value) == 1
    assert int(d.activeEnable.value)

    # Multiword snapshots remain frozen while the PHC continues ticking.
    await write(0x100, 1)
    assert await read(0x104) == 1
    stamp = await read_wide(0x108, 4)
    ticks = await read_wide(0x160, 2)
    for _ in range(20):
        await edge()
    assert await read_wide(0x108, 4) == stamp
    assert int(d.timeTicks.value) > ticks
    await write(0x050, 2)
    assert int(d.irq.value)
    await write(0x054, 2)
    assert not int(d.irq.value)

    # Automatic ownership rejects manual steering; PPS remains a safe command.
    await write(0x004, 0xB)
    await write(0x03c, 1)
    await write(0x120, 0x82, response=2)
    await write(0x120, 0x8C)
    await finish()
    await edge(regRst=1)
    await edge(regRst=0)
    assert int(d.activeServo.value)
    assert int(d.timeGeneration.value) == 1


def test_ptp_reg():
    run_surf_vhdl_test(test_file=__file__, toplevel='surf.ptpregwrapper')
