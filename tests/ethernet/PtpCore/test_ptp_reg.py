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
# - Sweep: Five 4 KiB AXI banks, including the PHC core control bank, at
#   zero/nonzero bases, decode/strobes/errors,
#   frozen candidates, all-or-none commits, shared limits, coherent snapshots,
#   MAC identity changes, immutable manual commands, and register-only reset.
# - Stimulus: Raw AXI-Lite transactions preserve deliberately unaligned addresses;
#   the real PHC prepares and executes commands while shadows are rewritten.
# - Checks: Twelve-bit bank decode and 32 KiB aperture bounds, low address-bit
#   aliases and field strobes, active versus shadow state,
#   local snapshot sequence/edge agreement, registered request stability,
#   full phase operand latching, accepted commit survival across AXI reset,
#   signed phase remainder/epoch boundaries and signed96 admission from signed128,
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

    clock_started = False

    async def edge(**values):
        nonlocal clock_started
        published = int(d.snapshotCapture.value) if clock_started else 0
        was_reset = int(d.rst.value) if clock_started else 1
        d.clk.value = 0
        for name, value in values.items():
            getattr(d, name).value = value
        await Timer(4, unit='ns')
        if not was_reset and not int(d.rst.value):
            assert int(d.snapshotCapture.value) == published, 'snapshot request changed between edges'
        observed = {name: int(getattr(d, 'axil_'+name).value) for name in
                    ('awready', 'wready', 'bvalid', 'bresp', 'arready', 'rvalid', 'rresp', 'rdata')}
        observed['configRestart'] = int(d.configRestart.value)
        observed['configApply'] = int(d.configApply.value)
        if int(d.snapshotCapture.value):
            snapshots.append(int(d.timeTicks.value))
        if int(d.configPrepare.value):
            preparations.append(int(d.timeTicks.value))
        if int(d.configApply.value):
            applications.append(int(d.timeTicks.value))
        d.clk.value = 1
        await Timer(4, unit='ns')
        clock_started = True
        return observed

    async def write(address, value, strobe=15, response=0):
        aw, w = 1, 1
        for _ in range(4*48+32):
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
        for _ in range(4*48+32):
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

    async def finish(error=0):
        # Word-serial phase normalization is bounded by 5000 engine clocks;
        # each complete AXI status read advances several clocks.
        for _ in range(1000):
            value = await read(0x5024)
            if not value & 1:
                assert value == 2+4*error
                return
        assert False, 'command acknowledgement timeout'

    async def commit(error=0):
        before = await read(0x048)
        await write(0x03C, 1)
        # The 48-word port clone takes 196 clocks; each status transaction
        # advances multiple clocks, including crossbar response stages.
        for _ in range(100):
            if await read(0x048) != before:
                assert await read(0x040) == error
                return
        assert False, 'configuration commit timeout'

    await edge(rst=1)
    await edge(rst=0)
    assert await read(0) == 0x30000
    assert await read(0x4000) == 0x10000
    # The PHC core runs under endpoint coordination: its local submissions
    # would be a second coordinator and are refused.
    assert await read(0x4008) == 0x31F
    await write(0x403C, 1, response=2)
    await write(0x4100, 1, response=2)
    # The crossbar decodes the actual base address; an unrelated high address
    # must not alias the bank selected by the same low 15 address bits.
    expected_base = base
    base = base ^ 0x10000000
    await read(0, response=3)
    await write(4, 3, response=3)
    base = expected_base
    # Each bank decodes all 12 local address bits. Unallocated upper quarters
    # must not alias the control word at local 0x004 as a 10-bit decode would.
    for bank in (0x0000, 0x2000, 0x3000, 0x4000, 0x5000):
        for unused_offset in (0x404, 0x804, 0xC04):
            await read(bank+unused_offset, response=3)
            await write(bank+unused_offset, 0, response=3)
    # The former PHC slot, the unused top 8 KiB and the next 32 KiB window
    # are outside every bank of this endpoint's crossbar.
    for unmapped in (0x1000, 0x1004, 0x6000, 0x7FFC, 0x8000, 0x8004):
        await read(unmapped, response=3)
        await write(unmapped, 0, response=3)
    for unused in (0x3F0, 0x23F0, 0x33F0, 0x43F0, 0x53F0):
        await read(unused, response=3)
        await write(unused, 0, response=3)
    # Exercise every moved word-bank address through the real AXI crossbar.
    # Multiword fields keep their padded final word and all read-only protections.
    for bank, rw, ro in (
            (0x5000, [(0x28, 10)], [(0x08, 6), (0x58, 4)]),
            (0x2000, [(0x04, 2), (0x10, 3), (0x20, 3), (0x80, 12), (0xB0, 1), (0xB8, 2)],
             [(0x130, 12), (0x160, 3), (0x170, 3), (0x180, 3), (0x190, 3), (0x1A0, 8), (0x200, 7)]),
            (0x3000, [(0x04, 1), (0x20, 5), (0x38, 8), (0x60, 10)],
             [(0x94, 2), (0x100, 10), (0x200, 1)])):
        for fields, writable in ((rw, True), (ro, False)):
            for start, count in fields:
                for offset in range(start, start+4*count, 4):
                    value = await read(bank+offset)
                    await write(bank+offset, value, response=0 if writable else 3)
                    assert await read(bank+offset) == value

    # SURF register helpers ignore address bits 1:0. All four byte addresses
    # select the same word; write strobes still select eligible field slices.
    for address, mask in ((0x004, 1), (0x4004, 1), (0x5004, 8), (0x2004, 16), (0x3004, 4)):
        original = await read(address)
        for low_bits in (1, 2, 3):
            assert await read(address+low_bits) == await read(address)
            value = original ^ mask if low_bits % 2 else original
            await write(address+low_bits, value, strobe=1)
            assert await read(address) == value
            await write(address+low_bits, original ^ value, strobe=0, response=3)
            assert await read(address) == value
        await write(address, original)
    await read(0x3F0, response=3)
    await write(0x3F0, 1, response=3)
    original_interval = await read_wide(0x2080, 2)
    assert original_interval == 125000000
    await write(0x2081, 0x12345678)
    assert await read_wide(0x2080, 2) == (original_interval & ~0xffffffff) | 0x12345678
    assert await read(0x2083) == 0x12345678
    await write(0x2082, 0, strobe=1, response=3)
    assert await read(0x2080) == 0x12345678
    await write_wide(0x2080, original_interval, 2)
    # Low-bit aliases do not make read-only or unmapped words writable.
    assert await read(0x5083) == 125000000
    await write(0x5083, 0, response=3)
    await read(0x3F3, response=3)
    await write(0x3F3, 0, response=3)
    # SURF helpers require strobes covering the whole addressed field slice.
    # Narrow fields permit a byte write; a partial wide-field write is rejected.
    for address, value in ((0x004, 1), (0x4004, 1), (0x5004, 0), (0x3024, 0x03020100)):
        original = await read(address)
        await write(address, value, strobe=0, response=3)
        assert await read(address) == original
        if address == 0x3024:
            await write(address, value, strobe=1, response=3)
            assert await read(address) == original
        else:
            await write(address, value, strobe=1)
            assert await read(address) == (original & 0xFFFFFF00) | (value & 0xFF)
        await write(address, original)
    before = await read(0x2008)
    await write(0x2008, 0x201, strobe=1)
    assert await read(0x2008) == (before & 0xFFFFFF00) | 1
    await write(0x2008, 0)
    await write(0x20D0, 0, response=3)
    assert await read_wide(0x20D0, 2) == (1 << 64)-Q16
    assert await read_wide(0x20D8, 2) == 2*Q16
    assert await read(0x5080) == 125000000
    assert await read_wide(0x20C0, 2) == 5000

    # Configuration stays inactive until one valid commit. Invalid commits leave
    # all active words intact, including the previous identity and enable bits.
    source = int('001122fffe3344550001', 16)
    await write_wide(0x2020, source, 3)
    await write(0x2010, 7)  # derive clock identity, preserve this port number
    await write(0x004, 1)
    assert not int(d.activeEnable.value)
    await commit()
    assert int(d.activeEnable.value)
    assert (await read_wide(0x2070, 3)) == source
    assert (await read_wide(0x2060, 3)) == int('020000fffe0000010007', 16)
    await write(0x20A4, 0x40000000)
    await write(0x004, 0)
    await commit(error=1)
    assert await read(0x040) == 1
    assert int(d.activeEnable.value)
    await write(0x20A4, 0)
    await write(0x004, 1)
    await commit()
    assert await read(0x040) == 0
    seen = await edge(localMac=int.from_bytes(bytes.fromhex('020000000002'), 'little'))
    # Port detects identity here; PtpEndpointControl adds another register hop.
    assert not seen['configRestart']
    assert not (await edge())['configRestart']
    assert (await edge())['configRestart']
    assert (await read_wide(0x2060, 3)) == int('020000fffe0000020007', 16)

    # Every owner validates its own candidate; one invalid servo setting must
    # prevent otherwise valid port and endpoint changes from taking effect.
    old_source = await read_wide(0x2070, 3)
    await write_wide(0x2020, source+1, 3)
    await write(0x004, 0)
    await write(0x3030, 200001)
    before_apply = len(applications)
    await commit(error=1)
    assert len(applications) == before_apply
    assert int(d.activeEnable.value)
    assert await read_wide(0x2070, 3) == old_source
    await write(0x3030, 150000)
    await write(0x004, 1)
    await write_wide(0x2020, source, 3)

    # The advertised shared-service floor is enforced on the frozen candidate.
    assert await read(0x20F8) == 70347776
    previous_timeout = await read_wide(0x2090, 2)
    await write_wide(0x2090, 70347775, 2)
    await commit(error=1)
    await write_wide(0x2090, 70347776, 2)
    await commit()
    await write_wide(0x2090, previous_timeout, 2)
    await commit()

    # Isolate the same bank prepare/apply pins used by the coordinator. Hold
    # candidates across multiple bus writes to prove they are immutable.
    await write(0x3020, 0x20000000)
    await write(0x5004, 0)
    await write_wide(0x2020, source+2, 3)
    await edge(bankControlOverride=1, bankPrepare=1)
    await edge(bankPrepare=0)
    await write(0x3020, 0x30000000)
    await write(0x5004, 8)
    await write_wide(0x2020, source+3, 3)
    await edge(bankApply=1)
    await edge(bankApply=0, bankControlOverride=0)
    assert await read(0x3094) == 0x20000000
    assert await read(0x3020) == 0x30000000
    assert await read(0x5084) == 0
    assert await read(0x5004) == 8
    assert await read_wide(0x2070, 3) == source+2
    assert await read_wide(0x2020, 3) == source+3
    await write(0x3020, 0x10000000)
    await write_wide(0x2020, source, 3)
    await commit()
    assert await read(0x3094) == 0x10000000
    assert await read(0x5084) == 8
    for port_addr, servo_addr in ((0x20E0, 0x30A0), (0x20E8, 0x30A8), (0x20F0, 0x30B0)):
        assert await read_wide(port_addr, 2) == await read_wide(servo_addr, 2)
        await write(servo_addr, 1, response=3)

    # Cancel a commit's AXI response while candidates are being prepared.
    # The accepted operation still applies every bank once, and software can
    # recover its completion through the sequence after the bus restarts.
    await write(0x004, 0)
    await write_wide(0x2020, source+4, 3)
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
    for _ in range(100):
        if await read(0x048) == sequence+1:
            break
    assert await read(0x048) == sequence+1
    assert not int(d.activeEnable.value)
    assert await read_wide(0x2070, 3) == source+4
    await write(0x004, 1)
    await write_wide(0x2020, source, 3)
    await commit()

    # Normalize a phase delta while PHC time is invalid. Mutating all shadow
    # words and resetting only the AXI endpoint cannot alter this queued command.
    delta = 2*NS*Q16+123*Q16+17
    await write_wide(0x5038, delta, 4)
    before_ticks = int(d.timeTicks.value)
    before_time = (int(d.timeSeconds.value)*NS+int(d.timeNanoseconds.value))*Q32+int(d.timeFraction.value)
    await write(0x5020, 0x81)
    await write_wide(0x5038, (1 << 128)-99*Q16, 4)
    await write(0x5020, 0x83, response=2)
    await write(0x03c, 1, response=2)
    await edge(regRst=1)
    await edge(regRst=0)
    assert await read(0x5024) == 1
    await finish()
    elapsed = int(d.timeTicks.value)-before_ticks
    after_time = (int(d.timeSeconds.value)*NS+int(d.timeNanoseconds.value))*Q32+int(d.timeFraction.value)
    assert after_time-before_time == elapsed*8*Q32+delta*(1 << 16)
    assert int(d.timeGeneration.value) == 1
    assert int(d.activeEnable.value)

    # Multiword snapshots remain frozen while the PHC continues ticking.
    await write(0x100, 1)
    for _ in range(20):
        if await read(0x108) == 0:
            break
    assert await read(0x108) == 0
    assert await read(0x104) == 1
    stamp = await read_wide(0x5008, 4)
    ticks = await read_wide(0x5060, 2)
    assert ticks == snapshots[-1]
    for bank_sequence in (0x53FC, 0x23FC, 0x33FC, 0x4104):
        assert await read(bank_sequence) == await read(0x104)
    for _ in range(20):
        await edge()
    assert await read_wide(0x5008, 4) == stamp
    assert int(d.timeTicks.value) > ticks
    await write(0x050, 2)
    assert int(d.irq.value)
    await write(0x054, 2)
    assert not int(d.irq.value)

    # A read admitted during copying stays on the previous published bank,
    # including after the new cohort publishes while its AXI response is held.
    old_sequence = await read(0x104)
    old_ticks = ticks
    await write(0x100, 1)
    ar = 1
    for _ in range(40):
        seen = await edge(axil_arvalid=ar, axil_araddr=base+0x5060, axil_rready=0)
        if seen['arready']:
            ar = 0
        if seen['rvalid']:
            assert seen['rresp'] == 0 and seen['rdata'] == (old_ticks & 0xffffffff)
            break
    else:
        assert False, 'old snapshot read did not complete during publication'
    for _ in range(20):
        seen = await edge(axil_arvalid=0)
        assert seen['rvalid'] and seen['rdata'] == (old_ticks & 0xffffffff)
    await edge(axil_rready=1)
    assert await read(0x104) == old_sequence+1
    assert await read_wide(0x5060, 2) == snapshots[-1]

    # Automatic ownership rejects manual steering; PPS remains a safe command.
    await write(0x004, 1)
    await write(0x4004, 1)
    await commit()
    assert await read(0x4044) & 1
    await write(0x5020, 0x82, response=2)
    await write(0x5020, 0x8C)
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
    assert int(d.snapshotCapture.value), 'snapshot issue was not registered'
    # Inhibition arriving after issue must not split the cohort or withdraw
    # the registered request. All banks and the coordinator complete together.
    await edge(snapshotInhibit=1)
    assert not int(d.snapshotCapture.value), 'snapshot request did not pulse'
    await edge(snapshotInhibit=0)
    for _ in range(20):
        if await read(0x108) == 0:
            break
    assert await read(0x108) == 0
    assert await read(0x104) == sequence+1
    for bank_sequence in (0x53FC, 0x23FC, 0x33FC, 0x4104):
        assert await read(bank_sequence) == sequence+1
    assert await read_wide(0x5060, 2) == snapshots[-1]

    # Exercise the manual fixed-divisor path with a safe epoch in the middle
    # of its range. The independent integer oracle retains every Q16 bit;
    # negative sub-second residues must truncate toward zero before conversion.
    divisor = NS*Q16
    deltas = (0, 1, -1, divisor-1, 1-divisor, divisor, -divisor,
              divisor+1, -divisor-1, (1 << 40)*divisor+17,
              -(1 << 40)*divisor-17)
    for delta in deltas:
        await edge(rst=1)
        await edge(rst=0)
        await write_wide(0x5028, 1 << 46, 2)
        await write(0x5020, 0x80)
        await finish()
        await write_wide(0x5038, delta, 4)
        before_ticks = int(d.timeTicks.value)
        before_time = (int(d.timeSeconds.value)*NS+int(d.timeNanoseconds.value))*Q32+int(d.timeFraction.value)
        before_generation = int(d.timeGeneration.value)
        await write(0x5020, 0x81)
        # Change all shadow words and reset AXI while each signed division is
        # in flight. Accepted arithmetic continues with the original operand.
        await write_wide(0x5038, ~delta, 4)
        await edge(regRst=1)
        await edge(regRst=0)
        await finish()
        elapsed = int(d.timeTicks.value)-before_ticks
        after_time = (int(d.timeSeconds.value)*NS+int(d.timeNanoseconds.value))*Q32+int(d.timeFraction.value)
        assert after_time-before_time == elapsed*8*Q32+delta*Q16, delta
        assert int(d.timeGeneration.value) == before_generation+1
        assert not await read(0x5068)

    # Preparation requires the full submitted value to fit signed96 Q16 ns.
    # Wider values must fail before reaching the PHC command slot, even when
    # their seconds quotient fits signed64. The signed96 endpoints reach the
    # clock and fault at its 48-bit epoch boundary. Reset after each fatal case
    # so a prior fault cannot hide a later admission/epoch error.
    limits = (
        ((1 << 127)-1, False), (-(1 << 127), False),
        ((1 << 63)*divisor, False), (-((1 << 63)+1)*divisor, False),
        ((1 << 63)*divisor-1, False), (-((1 << 63)+1)*divisor+1, False),
        (1 << 95, False), (-(1 << 95)-1, False),
        ((1 << 95)-1, True), (-(1 << 95), True),
    )
    for delta, reaches_clock in limits:
        await edge(rst=1)
        await edge(rst=0)
        await write_wide(0x5038, delta, 4)
        before_ticks = int(d.timeTicks.value)
        before_time = (int(d.timeSeconds.value)*NS+int(d.timeNanoseconds.value))*Q32+int(d.timeFraction.value)
        await write(0x5020, 0x81)
        await finish(error=1)
        elapsed = int(d.timeTicks.value)-before_ticks
        after_time = (int(d.timeSeconds.value)*NS+int(d.timeNanoseconds.value))*Q32+int(d.timeFraction.value)
        assert int(d.timeGeneration.value) == int(reaches_clock), delta
        assert await read(0x5068) == int(reaches_clock), delta
        if reaches_clock:
            assert before_time <= after_time < before_time+elapsed*8*Q32
        else:
            assert after_time-before_time == elapsed*8*Q32, delta


@pytest.mark.parametrize('base', [0, 0xA5808000])
def test_ptp_reg(base):
    run_surf_vhdl_test(test_file=__file__, toplevel='surf.ptpregwrapper',
                      extra_vhdl_sources={"surf": ["ethernet/PtpCore/wrappers/PtpRegWrapper.vhd"]},
                      parameters={'AXIL_BASE_ADDR_G': f'{base:032b}'}, extra_env={'AXIL_BASE': base})
