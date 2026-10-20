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
# - Sweep: Real SURF MAC in GMII and XGMII for both MAC builds: the tapped MAC
#   with private PTP bypass and primary guard, and the PTP-only timing-port MAC.
# - Stimulus: Qualified one-/two-step Syncs, pause before TX admission, port restart with
#   a queued request, late completion/response, and (tapped build only)
#   application/spoofed traffic.
# - Checks: Persistent wire-key retirement, no stale measurement after restart,
#   eventual fresh E2E completion, and unchanged non-PTP application payload.
# - Timing: Pause holds a complete MAC-accepted frame; explicit zero pause drains
#   it without resetting MAC/PHC. All waits are bounded by simulator cycles.
#   Zero propagation delay reduces GHDL event scheduling in this long fixture;
#   registered cycle boundaries and the independent wire/FCS observer remain.
#   Leaf and model-MAC endpoint fixtures retain their 1 ns delay checks.
#   Sync spacing exceeds the configured rate-span minimum; FIFO last-write and
#   protocol counters establish completion instead of fixed settling delays.

import os

import cocotb
from cocotb.triggers import RisingEdge
import pytest
from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES, FlatEmacEndpoint,
    send_contiguous_frame, frame_beats_from_bytes, build_pause_frame)
from tests.ethernet.PtpCore.ptp_endpoint_test_utils import Bench, LOCAL
from tests.ethernet.PtpCore.ptp_wire_utils import ptp_frame

MAC_MODE = os.environ.get("MAC_MODE", "TAPPED")


@cocotb.test(skip=MAC_MODE != "TAPPED")
async def real_mac_lifecycle(d):
    b = Bench(d)
    await b.start()
    await b.configure()
    queued = 0
    responses_retired = wire_retired = 0
    allow_delay = False

    async def monitor_queued():
        """Lifetime agent: owned by b.tasks and stopped with the fixture."""
        nonlocal queued, responses_retired, wire_retired
        # Observe the real bypass FIFO accepting the final frame beat. A
        # ledger reservation alone does not prove the complete frame reached
        # the MAC before port reset. Payload/fate assertions use the wire.
        fifo = d.gen_mac.u_dut.u_mac.u_txfifo.byp_enabled.byp_fifo.u_fifo
        endpoint = d.gen_mac.u_dut
        engine = endpoint.u_endpoint.u_protocolengine
        while True:
            await RisingEdge(d.clk)
            if int(fifo.fifowritelast.value):
                queued += 1
            if int(engine.responsevalid.value) and int(engine.responseready.value):
                responses_retired += 1
            if int(endpoint.txmessageready.value):
                wire_retired += 1
            if not allow_delay:
                assert not int(engine.delayvalid.value), 'retired wire key offered a delay sample'

    async def counter_after(address, before):
        start = int(d.timeTicks.value)
        while int(d.timeTicks.value)-start < 9000:
            await b.snapshot()
            value = await b.read(address)
            if value > before:
                return value
        assert False, ('protocol completion timeout', hex(address), before)

    b.tasks.append(cocotb.start_soon(monitor_queued()))
    b.tasks.append(cocotb.start_soon(b.monitor_wire()))
    b.tasks.append(cocotb.start_soon(b.respond()))
    source = FlatEmacEndpoint(d, prefix="sAxis")
    source.set_idle()
    application = bytes.fromhex("0200000000020200000000010800")+bytes(range(80))
    await send_contiguous_frame(source, frame_beats_from_bytes(application), clk=d.clk)
    for _ in range(500):
        if b.other_tx:
            break
        await b.wait(1)
    assert b.other_tx == [application]
    spoof = ptp_frame(sequence=0, message_type=1, source=LOCAL)
    await send_contiguous_frame(source, frame_beats_from_bytes(spoof), clk=d.clk)
    await b.wait(100)
    assert int(d.primaryDropped.value) == 1
    assert b.tx_count == 0

    await b.source(2, spacing_cycles=1000)
    d.pauseEnable.value = 1
    async with b.rx_lock:
        # Even at eight clocks per pause quantum, 8192 quanta cover the
        # bounded FIFO-admission check and packet/AXI overhead. The
        # explicit zero-pause frame below still controls physical release.
        await b.wire(build_pause_frame(8192))
    await b.source(1, sequence=2, spacing_cycles=0)
    for _ in range(9000):
        if queued:
            break
        await b.wait(1)
    assert queued == 1, 'complete request did not enter the paused MAC'
    assert b.tx_count == 0, "request escaped pause"
    ledger = await b.read(0x2048)
    assert (ledger >> 16) & 255, "no unresolved MAC-accepted wire key"
    generation = int(d.timeGeneration.value)
    ticks = int(d.timeTicks.value)
    d.portRst.value = 1
    await b.wait(3)
    d.portRst.value = 0
    async with b.rx_lock:
        await b.wire(build_pause_frame(0))
    for _ in range(1000):
        if b.tx_count:
            break
        await b.wait(1)
    assert b.tx_count
    # Ledger retirement, rather than PortRejected, owns this stale response.
    # Both input handshakes follow their complete row scans. The monitor also
    # forbids a stale sample throughout those scans, before E2E can consume it.
    for _ in range(9000):
        if responses_retired and wire_retired:
            break
        await b.wait(1)
    assert responses_retired == 1 and wire_retired
    await b.wait(4)
    await b.snapshot()
    assert await b.read(0x2214) == 0, "retired request produced an E2E measurement"
    assert int(d.timeGeneration.value) == generation
    assert int(d.timeTicks.value) > ticks
    allow_delay = True
    await b.source(4, sequence=100, spacing_cycles=1000)
    assert await counter_after(0x2214, 0) > 0, "fresh exchanges did not recover"
    assert not int(d.timeFault.value)
    d._log.info('Completed MAC lifecycle at raw tick %d', int(d.timeTicks.value))
    b.stop()

@cocotb.test(skip=MAC_MODE != "TIMING_PORT")
async def timing_port_mac_lifecycle(d):
    """The same lifecycle on the PTP-only timing-port MAC."""
    b = Bench(d)
    await b.start()
    await b.configure()
    responses_retired = wire_retired = 0
    allow_delay = False

    async def monitor_retire():
        """Lifetime agent: owned by b.tasks and stopped with the fixture."""
        nonlocal responses_retired, wire_retired
        endpoint = d.gen_port_mac.u_dut
        engine = endpoint.u_endpoint.u_protocolengine
        while True:
            await RisingEdge(d.clk)
            if int(engine.responsevalid.value) and int(engine.responseready.value):
                responses_retired += 1
            if int(endpoint.txmessageready.value):
                wire_retired += 1
            if not allow_delay:
                assert not int(engine.delayvalid.value), 'retired wire key offered a delay sample'

    async def counter_after(address, before):
        start = int(d.timeTicks.value)
        while int(d.timeTicks.value)-start < 9000:
            await b.snapshot()
            value = await b.read(address)
            if value > before:
                return value
        assert False, ('protocol completion timeout', hex(address), before)

    b.tasks.append(cocotb.start_soon(monitor_retire()))
    b.tasks.append(cocotb.start_soon(b.monitor_wire()))
    b.tasks.append(cocotb.start_soon(b.respond()))
    assert int(d.primaryDropped.value) == 0

    await b.source(2, spacing_cycles=1000)
    d.pauseEnable.value = 1
    async with b.rx_lock:
        await b.wire(build_pause_frame(8192))
    await b.source(1, sequence=2, spacing_cycles=0)
    # The request is admitted to the port and held by pause: its key is
    # unresolved and nothing reaches the wire.
    for _ in range(9000):
        if (await b.read(0x2048) >> 16) & 255:
            break
        await b.wait(1)
    assert (await b.read(0x2048) >> 16) & 255, "no unresolved port-accepted wire key"
    await b.wait(200)
    assert b.tx_count == 0, "request escaped pause"
    generation = int(d.timeGeneration.value)
    ticks = int(d.timeTicks.value)
    d.portRst.value = 1
    await b.wait(3)
    d.portRst.value = 0
    async with b.rx_lock:
        await b.wire(build_pause_frame(0))
    for _ in range(1000):
        if b.tx_count:
            break
        await b.wait(1)
    assert b.tx_count
    # The port completes the held frame SENT after restart; the ledger, not
    # PortRejected, retires the stale response and its wire key.
    for _ in range(9000):
        if responses_retired and wire_retired:
            break
        await b.wait(1)
    assert responses_retired == 1 and wire_retired
    await b.wait(4)
    await b.snapshot()
    assert await b.read(0x2214) == 0, "retired request produced an E2E measurement"
    assert int(d.timeGeneration.value) == generation
    assert int(d.timeTicks.value) > ticks
    allow_delay = True
    await b.source(4, sequence=100, spacing_cycles=1000)
    assert await counter_after(0x2214, 0) > 0, "fresh exchanges did not recover"
    assert not int(d.timeFault.value)
    d._log.info('Completed timing-port MAC lifecycle at raw tick %d', int(d.timeTicks.value))
    b.stop()


@pytest.mark.parametrize("mac_mode", ["TAPPED", "TIMING_PORT"])
@pytest.mark.parametrize("mode", ["XGMII", "GMII"])
@pytest.mark.parametrize("two_step", [True, False], ids=["two-step", "one-step"])
def test_ptp_endpoint_mac(mode, two_step, mac_mode):
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ptpendpointloopbackwrapper",
                      parameters={"TPD_PS_G": 0, "PHY_TYPE_G": mode, "CLK_FREQ_G": 125000000 if mode == "GMII" else 156250000,
                                  "PACKET_LIFETIME_G": 5000, "MAC_ENABLE_G": True, "MAC_MODE_G": mac_mode},
                      extra_env={"TWO_STEP": int(two_step), "MODE": mode, "REAL_MAC": 1, "MAC_MODE": mac_mode},
                      extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + ["ethernet/PtpCore/wrappers/PtpEndpointLoopbackWrapper.vhd"]})
