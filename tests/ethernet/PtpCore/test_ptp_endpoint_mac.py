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
# - Sweep: Real SURF MAC in GMII and XGMII, private PTP bypass and primary guard.
# - Stimulus: Qualified Sync pairs, pause before TX admission, port restart with
#   a queued request, late completion/response, and application/spoofed traffic.
# - Checks: Persistent wire-key retirement, no stale measurement after restart,
#   eventual fresh E2E completion, and unchanged non-PTP application payload.
# - Timing: Pause holds a complete MAC-accepted frame; explicit zero pause drains
#   it without resetting MAC/PHC. All waits are bounded by simulator cycles.

import cocotb
import pytest
from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import (
    ETHMAC_RTL_SOURCES, ROCE_ANALYSIS_SOURCES, FlatEmacEndpoint,
    send_contiguous_frame, frame_beats_from_bytes, build_pause_frame)
from tests.ethernet.PtpCore.ptp_endpoint_test_utils import Bench, LOCAL
from tests.ethernet.PtpCore.ptp_wire_utils import ptp_frame

@cocotb.test()
async def real_mac_lifecycle(d):
    b = Bench(d)
    await b.start()
    await b.configure()
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

    await b.source(2)
    d.pauseEnable.value = 1
    async with b.rx_lock:
        await b.wire(build_pause_frame(2000))
    await b.source(1, sequence=2)
    assert b.tx_count == 0, "request escaped pause"
    ledger = await b.read(0x848)
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
    await b.wait(200)
    await b.snapshot()
    assert await b.read(0xA14) == 0, "retired request produced an E2E measurement"
    assert int(d.timeGeneration.value) == generation
    assert int(d.timeTicks.value) > ticks
    await b.source(4, sequence=100)
    await b.snapshot()
    assert await b.read(0xA14) > 0, "fresh exchanges did not recover"
    assert not int(d.timeFault.value)
    b.stop()

@pytest.mark.parametrize("mode", ["XGMII", "GMII"])
def test_ptp_endpoint_mac(mode):
    run_surf_vhdl_test(test_file=__file__, toplevel="surf.ptpendpointloopbackwrapper",
                      parameters={"PHY_TYPE_G": mode, "CLK_FREQ_G": 125000000 if mode == "GMII" else 156250000,
                                  "PACKET_LIFETIME_G": 5000, "MAC_ENABLE_G": True},
                      extra_env={"MODE": mode, "REAL_MAC": 1},
                      extra_vhdl_sources={"surf": ETHMAC_RTL_SOURCES + ROCE_ANALYSIS_SOURCES})
