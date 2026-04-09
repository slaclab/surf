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
# - Sweep: Keep one single-VC `Pgp2fcTx` wrapper instance and inject one FC
#   request while idle, while a frame is active, and immediately after a frame
#   completes.
# - Stimulus: Drive real VC0 words through the widened checked-in wrapper,
#   pulse `txFcValid` for one clock, and watch both `fcSent` and the serialized
#   PHY output.
# - Checks: The integrated `txFcValid -> fcSent` latency must match the idle
#   reference in every context, and the FC start word must still appear on the
#   wire in all cases.
# - Timing: The bench calibrates against the current wrapper/PHY timing and
#   uses bounded cycle searches instead of hard-coding absolute latencies.

import cocotb

from tests.protocols.pgp.pgp2_test_utils import K_FCD, PgpModuleTB, signal_int
from tests.protocols.pgp.pgp_test_utils import pgp_family_sources, run_pgp_wrapper_test


def fc_start_seen(dut, fc_word: int) -> bool:
    return signal_int(dut, "phyTxData") == (((fc_word & 0x00FF) << 8) | K_FCD) and signal_int(dut, "phyTxDataK") == 0b01


async def wait_for_signal(tb: PgpModuleTB, signal_name: str, *, value: int = 1, cycles: int = 64):
    for _ in range(cycles):
        if signal_int(tb.dut, signal_name) == value:
            return
        await tb.cycle()
    raise AssertionError(f"Timed out waiting for {signal_name}={value}")


async def drive_frame_word(
    tb: PgpModuleTB,
    *,
    data: int,
    sof: int = 0,
    last: int = 0,
    eofe: int = 0,
):
    tb.dut.vc0FrameData.value = data
    tb.dut.vc0FrameSof.value = sof
    tb.dut.vc0FrameLast.value = last
    tb.dut.vc0FrameEofe.value = eofe
    tb.dut.vc0FrameValid.value = 1

    while True:
        await tb.cycle()
        if signal_int(tb.dut, "vc0FrameReady") == 1:
            break

    tb.dut.vc0FrameValid.value = 0
    tb.dut.vc0FrameSof.value = 0
    tb.dut.vc0FrameLast.value = 0
    tb.dut.vc0FrameEofe.value = 0


async def measure_fc_request(tb: PgpModuleTB, *, fc_word: int):
    start_latency = None
    sent_latency = None

    tb.dut.txFcWord.value = fc_word
    tb.dut.txFcValid.value = 1

    for cycle in range(1, 48):
        await tb.cycle()
        if cycle == 1:
            tb.dut.txFcValid.value = 0

        if start_latency is None and fc_start_seen(tb.dut, fc_word):
            start_latency = cycle
        if sent_latency is None and signal_int(tb.dut, "fcSent") == 1:
            sent_latency = cycle

        if start_latency is not None and sent_latency is not None:
            break

    if start_latency is None:
        raise AssertionError("Timed out waiting for the FC start word on the integrated TX PHY output")
    if sent_latency is None:
        raise AssertionError("Timed out waiting for fcSent in the integrated TX path")

    return {
        "start_latency": start_latency,
        "sent_latency": sent_latency,
    }


@cocotb.test()
async def pgp2fc_tx_fixed_latency_test(dut):
    tb = PgpModuleTB(dut)
    await tb.reset()

    dut.txFcValid.value = 0
    dut.txFcWord.value = 0
    dut.vc0FrameValid.value = 0
    dut.vc0FrameData.value = 0
    dut.vc0FrameLast.value = 0
    dut.vc0FrameSof.value = 0
    dut.vc0FrameEofe.value = 0

    await wait_for_signal(tb, "linkReady", value=1, cycles=24)

    # Reference timing with no user frame traffic active.
    reference = await measure_fc_request(tb, fc_word=0x1111)

    # Keep a frame open, then inject FC while the scheduler is actively feeding cells.
    accepted_words = 0
    for idx in range(4):
        await drive_frame_word(tb, data=0x2000 + idx, sof=1 if idx == 0 else 0, last=0)
        accepted_words += 1
    assert accepted_words == 4

    active_case = await measure_fc_request(tb, fc_word=0x2222)

    for idx in range(4, 7):
        await drive_frame_word(tb, data=0x2000 + idx, last=0)
    await drive_frame_word(tb, data=0x2007, last=1)
    await wait_for_signal(tb, "frameTx", value=1, cycles=32)

    # Inject again immediately after a completed frame to cover the scheduler
    # transition back through its post-cell path.
    await tb.cycle()
    boundary_case = await measure_fc_request(tb, fc_word=0x3333)

    assert active_case["start_latency"] == reference["start_latency"]
    assert active_case["sent_latency"] == reference["sent_latency"]
    assert boundary_case["start_latency"] == reference["start_latency"]
    assert boundary_case["sent_latency"] == reference["sent_latency"]


def test_Pgp2fcTxFixedLatency():
    run_pgp_wrapper_test(
        test_file=__file__,
        toplevel="surf.pgp2fctxwrapper",
        wrapper_source="protocols/pgp/pgp2fc/core/wrappers/Pgp2fcTxWrapper.vhd",
        extra_sources=pgp_family_sources("pgp2fc"),
    )
