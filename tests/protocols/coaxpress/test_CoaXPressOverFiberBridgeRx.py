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
# - Sweep: Exercise bridge RX low-speed packet decode, `IO_ACK`, embedded EOP
#   K-code reconstruction, HKP forwarding, HKP-to-payload transition, misplaced
#   control-character guardrails, `/Q/` no-output behavior, `/E/` abort behavior,
#   and recovery to a later packet.
# - Stimulus: Drive CXPoF start/payload/terminate sequences, housekeeping start
#   words, embedded marker/EOP K-codes, lane-misplaced `/S/`, `/Q/`, `/T/`, and
#   `/E/` controls, lane-0 `/Q/`, and explicit `/E/` aborts during active
#   low-speed packets.
# - Checks: The bridge must reconstruct repeated-byte `SOP`, packet-type,
#   payload, marker, and `EOP` words for valid packets, emit standalone `IO_ACK`,
#   forward raw HKP words, suppress malformed control traffic, and recover
#   cleanly.
# - Timing: The bench samples the reconstructed CXP word stream every cycle so
#   it checks the bridge's real shift-register latency and output ordering.

import cocotb

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.coaxpress.coaxpress_test_utils import (
    CXP_EOP,
    CXP_IDLE,
    CXP_IDLE_K,
    CXP_IO_ACK,
    CXP_MARKER,
    CXP_PKT_EVENT_ACK,
    CXP_SOP,
    CXPOF_ERROR,
    CXPOF_IDLE,
    CXPOF_RX_ERR_HKP_MALFORMED,
    CXPOF_RX_ERR_IDLE_ERROR,
    CXPOF_RX_ERR_PAYLOAD_ABORT,
    CXPOF_RX_ERR_SEQ_MISMATCH,
    CXPOF_SEQ,
    CXPOF_SOP_CTRL_HIGH_SPEED,
    CXPOF_SOP_CTRL_HKP,
    CXPOF_START,
    CXPOF_TERM,
    cycle,
    repeat_byte,
    reset_dut,
    start_clock,
)


def _cxp_start_word(packet_byte: int) -> int:
    return CXPOF_START | (CXPOF_SOP_CTRL_HIGH_SPEED << 8) | ((CXP_SOP & 0xFF) << 16) | (packet_byte << 24)


def _control_in_lane(control_byte: int, lane: int) -> int:
    shift = 8 * lane
    return (0x07070707 & ~(0xFF << shift)) | ((control_byte & 0xFF) << shift)


@cocotb.test()
async def coaxpress_over_fiber_bridge_rx_decode_test(dut):
    # Hold the bridge in its XGMII idle state until reset completes, then feed
    # one packetized CXP frame followed by a separate IO-ack indication.
    start_clock(dut.clk)
    dut.rst.setimmediatevalue(1)
    dut.xgmiiRxd.setimmediatevalue(0x07070707)
    dut.xgmiiRxc.setimmediatevalue(0xF)
    await reset_dut(dut, clk_name="clk", reset_names=("rst",))

    observed: list[tuple[int, int]] = []

    async def drive(rxd: int, rxc: int) -> None:
        dut.xgmiiRxd.value = rxd
        dut.xgmiiRxc.value = rxc
        await cycle(dut.clk, 1)
        sample = (int(dut.rxData.value), int(dut.rxDataK.value))
        if sample != (CXP_IDLE, CXP_IDLE_K):
            observed.append(sample)

    # Low-speed packet carrying a CoaXPress event-acknowledgment byte followed by
    # one 32-bit payload word and an EOP terminator.
    await drive(_cxp_start_word(CXP_PKT_EVENT_ACK), 0x1)
    await drive(0x11223344, 0x0)
    await drive(0x07FD00FD, 0xC)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    # Separate IO_ACK indication with no terminal payload word emitted.
    dut.xgmiiRxd.value = CXPOF_START | (CXPOF_SOP_CTRL_HIGH_SPEED << 8) | ((CXP_IO_ACK & 0xFF) << 16)
    dut.xgmiiRxc.value = 0x1
    await cycle(dut.clk, 1)
    sample = (int(dut.rxData.value), int(dut.rxDataK.value))
    if sample != (CXP_IDLE, CXP_IDLE_K):
        observed.append(sample)
    await drive(0x07FD0000, 0xC)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    assert observed == [
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK), 0x0),
        (0x11223344, 0x0),
        (CXP_EOP, 0xF),
        (CXP_IO_ACK, 0xF),
    ]


@cocotb.test()
async def coaxpress_over_fiber_bridge_rx_hkp_and_invalid_control_test(dut):
    # Keep the bridge idle through malformed lane placement for /S/ and /Q/,
    # then verify the HKP path emits raw K-coded words and recovers to normal
    # packet decode afterward.
    start_clock(dut.clk)
    dut.rst.setimmediatevalue(1)
    dut.xgmiiRxd.setimmediatevalue(0x07070707)
    dut.xgmiiRxc.setimmediatevalue(0xF)
    await reset_dut(dut, clk_name="clk", reset_names=("rst",))

    observed: list[tuple[int, int]] = []

    async def drive(rxd: int, rxc: int) -> None:
        dut.xgmiiRxd.value = rxd
        dut.xgmiiRxc.value = rxc
        await cycle(dut.clk, 1)
        sample = (int(dut.rxData.value), int(dut.rxDataK.value))
        if sample != (CXP_IDLE, CXP_IDLE_K):
            observed.append(sample)

    await drive(0x0707FB07, 0x2)
    await drive(0x07079C07, 0x2)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    await drive(CXPOF_START | ((CXPOF_SOP_CTRL_HIGH_SPEED | CXPOF_SOP_CTRL_HKP) << 8), 0x1)
    await drive(0x5C5C5C5C, 0xF)
    await drive(CXP_EOP, 0xF)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    await drive(_cxp_start_word(CXP_PKT_EVENT_ACK), 0x1)
    await drive(0x55667788, 0x0)
    await drive(0x07FD00FD, 0xC)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    assert observed == [
        (0x5C5C5C5C, 0xF),
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK), 0x0),
        (0x55667788, 0x0),
        (CXP_EOP, 0xF),
    ]


@cocotb.test()
async def coaxpress_over_fiber_bridge_rx_sequence_error_and_recovery_test(dut):
    # `/Q/` is tracked as a sequence counter: the first value initializes the
    # expected sequence, a following increment is accepted, and a skipped value
    # raises a sequence error while resynchronizing to later traffic. Then prove
    # an explicit `/E/` in a payload reports a classified abort without emitting
    # a synthetic CXP EOP and that the next packet still decodes cleanly.
    start_clock(dut.clk)
    dut.rst.setimmediatevalue(1)
    dut.xgmiiRxd.setimmediatevalue(0x07070707)
    dut.xgmiiRxc.setimmediatevalue(0xF)
    await reset_dut(dut, clk_name="clk", reset_names=("rst",))

    observed: list[tuple[int, int]] = []
    seq_samples: list[int] = []
    seq_errors: list[tuple[int, int]] = []
    error_codes: list[int] = []
    abort_pulses = 0
    error_pulses = 0

    async def drive(rxd: int, rxc: int) -> None:
        nonlocal abort_pulses, error_pulses
        dut.xgmiiRxd.value = rxd
        dut.xgmiiRxc.value = rxc
        await cycle(dut.clk, 1)
        sample = (int(dut.rxData.value), int(dut.rxDataK.value))
        if sample != (CXP_IDLE, CXP_IDLE_K):
            observed.append(sample)
        if int(dut.seqValid.value) == 1:
            seq_samples.append(int(dut.seqData.value))
        if int(dut.seqError.value) == 1:
            seq_errors.append((int(dut.seqData.value), int(dut.seqErrorExpected.value)))
        if int(dut.rxError.value) == 1:
            error_codes.append(int(dut.rxErrorCode.value))
        abort_pulses += int(dut.rxAbort.value)
        error_pulses += int(dut.rxError.value)

    await drive(CXPOF_SEQ | (0x00 << 8) | (0x12 << 16) | (0x34 << 24), 0x1)
    await drive(CXPOF_SEQ | (0x01 << 8) | (0x12 << 16) | (0x34 << 24), 0x1)
    await drive(CXPOF_SEQ | (0x03 << 8) | (0x12 << 16) | (0x34 << 24), 0x1)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    await drive(_cxp_start_word(CXP_PKT_EVENT_ACK), 0x1)
    await drive(0x11223344, 0x0)
    await drive(CXPOF_ERROR | (CXPOF_IDLE << 8) | (CXPOF_IDLE << 16) | (CXPOF_IDLE << 24), 0x1)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    await drive(_cxp_start_word(CXP_PKT_EVENT_ACK), 0x1)
    await drive(0x55667788, 0x0)
    await drive(0x07FD00FD, 0xC)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    assert seq_samples == [0x341200, 0x341201, 0x341203]
    assert seq_errors == [(0x341203, 0x341202)]
    assert abort_pulses == 1
    assert error_pulses == 2
    assert error_codes == [CXPOF_RX_ERR_SEQ_MISMATCH, CXPOF_RX_ERR_PAYLOAD_ABORT]
    assert observed == [
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK), 0x0),
        (0x11223344, 0x0),
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK), 0x0),
        (0x55667788, 0x0),
        (CXP_EOP, 0xF),
    ]


@cocotb.test()
async def coaxpress_over_fiber_bridge_rx_embedded_eop_kcode_test(dut):
    # A high-speed CXP-PHY EOP can carry an embedded CoaXPress K-code in
    # EopData0. Cover the marker and packet-end cases explicitly so this bridge
    # is not only checked against the common K29.7 packet-end path.
    start_clock(dut.clk)
    dut.rst.setimmediatevalue(1)
    dut.xgmiiRxd.setimmediatevalue(0x07070707)
    dut.xgmiiRxc.setimmediatevalue(0xF)
    await reset_dut(dut, clk_name="clk", reset_names=("rst",))

    observed: list[tuple[int, int]] = []

    async def drive(rxd: int, rxc: int) -> None:
        dut.xgmiiRxd.value = rxd
        dut.xgmiiRxc.value = rxc
        await cycle(dut.clk, 1)
        sample = (int(dut.rxData.value), int(dut.rxDataK.value))
        if sample != (CXP_IDLE, CXP_IDLE_K):
            observed.append(sample)

    # First packet ends with embedded K28.3, which should reconstruct a CXP
    # stream-marker word rather than a packet-end word.
    await drive(_cxp_start_word(CXP_PKT_EVENT_ACK), 0x1)
    await drive(0x11223344, 0x0)
    await drive(0x07FD007C, 0xC)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    # A later packet using embedded K29.7 should still reconstruct the normal
    # CXP EOP word and prove the marker split did not corrupt state.
    await drive(_cxp_start_word(CXP_PKT_EVENT_ACK), 0x1)
    await drive(0x55667788, 0x0)
    await drive(0x07FD00FD, 0xC)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    assert observed == [
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK), 0x0),
        (0x11223344, 0x0),
        (CXP_MARKER, 0xF),
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK), 0x0),
        (0x55667788, 0x0),
        (CXP_EOP, 0xF),
    ]


@cocotb.test()
async def coaxpress_over_fiber_bridge_rx_hkp_eop_kcode_test(dut):
    # A high-speed HKP packet can carry a CoaXPress K-code word that is not
    # represented with XGMII control bits. The current bridge forwards that HKP
    # word on the CXP side with all K bits asserted and terminates cleanly when
    # the HKP word itself is the CXP EOP code.
    start_clock(dut.clk)
    dut.rst.setimmediatevalue(1)
    dut.xgmiiRxd.setimmediatevalue(0x07070707)
    dut.xgmiiRxc.setimmediatevalue(0xF)
    await reset_dut(dut, clk_name="clk", reset_names=("rst",))

    observed: list[tuple[int, int]] = []
    hkp_samples: list[tuple[int, int, int, int]] = []

    async def drive(rxd: int, rxc: int) -> None:
        dut.xgmiiRxd.value = rxd
        dut.xgmiiRxc.value = rxc
        await cycle(dut.clk, 1)
        sample = (int(dut.rxData.value), int(dut.rxDataK.value))
        if sample != (CXP_IDLE, CXP_IDLE_K):
            observed.append(sample)
        if int(dut.hkpValid.value) == 1:
            hkp_samples.append(
                (
                    int(dut.hkpData.value),
                    int(dut.hkpEop.value),
                    int(dut.hkpSof.value),
                    int(dut.hkpWordCount.value),
                )
            )

    await drive(CXPOF_START | ((CXPOF_SOP_CTRL_HIGH_SPEED | CXPOF_SOP_CTRL_HKP) << 8), 0x1)
    await drive(CXP_EOP, 0x0)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    await drive(_cxp_start_word(CXP_PKT_EVENT_ACK), 0x1)
    await drive(0x99AABBCC, 0x0)
    await drive(0x07FD00FD, 0xC)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    assert hkp_samples == [(CXP_EOP, 1, 1, 1)]
    assert observed == [
        (CXP_EOP, 0xF),
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK), 0x0),
        (0x99AABBCC, 0x0),
        (CXP_EOP, 0xF),
    ]


@cocotb.test()
async def coaxpress_over_fiber_bridge_rx_error_after_sop_recovery_test(dut):
    # `/E/` immediately after the SOP/type phase is another abort placement that
    # matters for recovery. The bridge may already have emitted the CXP SOP and
    # type words queued by the start word, but it must not invent an EOP for the
    # aborted packet and must accept the next clean packet.
    start_clock(dut.clk)
    dut.rst.setimmediatevalue(1)
    dut.xgmiiRxd.setimmediatevalue(0x07070707)
    dut.xgmiiRxc.setimmediatevalue(0xF)
    await reset_dut(dut, clk_name="clk", reset_names=("rst",))

    observed: list[tuple[int, int]] = []
    abort_pulses = 0
    error_codes: list[int] = []

    async def drive(rxd: int, rxc: int) -> None:
        nonlocal abort_pulses
        dut.xgmiiRxd.value = rxd
        dut.xgmiiRxc.value = rxc
        await cycle(dut.clk, 1)
        sample = (int(dut.rxData.value), int(dut.rxDataK.value))
        if sample != (CXP_IDLE, CXP_IDLE_K):
            observed.append(sample)
        abort_pulses += int(dut.rxAbort.value)
        if int(dut.rxError.value) == 1:
            error_codes.append(int(dut.rxErrorCode.value))

    await drive(_cxp_start_word(CXP_PKT_EVENT_ACK), 0x1)
    await drive(CXPOF_ERROR | (CXPOF_IDLE << 8) | (CXPOF_IDLE << 16) | (CXPOF_IDLE << 24), 0x1)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    await drive(_cxp_start_word(CXP_PKT_EVENT_ACK), 0x1)
    await drive(0x12345678, 0x0)
    await drive(0x07FD00FD, 0xC)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    assert abort_pulses == 1
    assert error_codes == [CXPOF_RX_ERR_PAYLOAD_ABORT]
    assert observed == [
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK), 0x0),
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK), 0x0),
        (0x12345678, 0x0),
        (CXP_EOP, 0xF),
    ]


@cocotb.test()
async def coaxpress_over_fiber_bridge_rx_idle_error_code_test(dut):
    # `/E/` while idle is still an error/abort indication, but it has a distinct
    # cause code from an active-packet abort.
    start_clock(dut.clk)
    dut.rst.setimmediatevalue(1)
    dut.xgmiiRxd.setimmediatevalue(0x07070707)
    dut.xgmiiRxc.setimmediatevalue(0xF)
    await reset_dut(dut, clk_name="clk", reset_names=("rst",))

    error_codes: list[int] = []
    abort_pulses = 0

    async def drive(rxd: int, rxc: int) -> None:
        nonlocal abort_pulses
        dut.xgmiiRxd.value = rxd
        dut.xgmiiRxc.value = rxc
        await cycle(dut.clk, 1)
        abort_pulses += int(dut.rxAbort.value)
        if int(dut.rxError.value) == 1:
            error_codes.append(int(dut.rxErrorCode.value))

    await drive(CXPOF_ERROR | (CXPOF_IDLE << 8) | (CXPOF_IDLE << 16) | (CXPOF_IDLE << 24), 0x1)
    await drive(0x07070707, 0xF)

    assert abort_pulses == 1
    assert error_codes == [CXPOF_RX_ERR_IDLE_ERROR]


@cocotb.test()
async def coaxpress_over_fiber_bridge_rx_hkp_then_payload_mix_test(dut):
    # A housekeeping start word may be followed by one raw K-coded HKP word and
    # then normal data/EOP handling. This locks down the current RTL contract for
    # the HKP-to-payload transition without claiming full housekeeping semantics.
    start_clock(dut.clk)
    dut.rst.setimmediatevalue(1)
    dut.xgmiiRxd.setimmediatevalue(0x07070707)
    dut.xgmiiRxc.setimmediatevalue(0xF)
    await reset_dut(dut, clk_name="clk", reset_names=("rst",))

    observed: list[tuple[int, int]] = []
    hkp_samples: list[tuple[int, int, int, int]] = []

    async def drive(rxd: int, rxc: int) -> None:
        dut.xgmiiRxd.value = rxd
        dut.xgmiiRxc.value = rxc
        await cycle(dut.clk, 1)
        sample = (int(dut.rxData.value), int(dut.rxDataK.value))
        if sample != (CXP_IDLE, CXP_IDLE_K):
            observed.append(sample)
        if int(dut.hkpValid.value) == 1:
            hkp_samples.append(
                (
                    int(dut.hkpData.value),
                    int(dut.hkpEop.value),
                    int(dut.hkpSof.value),
                    int(dut.hkpWordCount.value),
                )
            )

    hkp_word = 0x9C5C3CBC
    await drive(CXPOF_START | ((CXPOF_SOP_CTRL_HIGH_SPEED | CXPOF_SOP_CTRL_HKP) << 8), 0x1)
    await drive(hkp_word, 0xF)
    await drive(0x10203040, 0x0)
    await drive(0x07FD00FD, 0xC)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    assert hkp_samples == [(hkp_word, 0, 1, 1)]
    assert observed == [
        (hkp_word, 0xF),
        (0x10203040, 0x0),
        (CXP_EOP, 0xF),
    ]


@cocotb.test()
async def coaxpress_over_fiber_bridge_rx_hkp_malformed_status_test(dut):
    # HKP words are still raw-forwarded, but the bridge now classifies malformed
    # HKP control masks instead of treating all HKP traffic as opaque good data.
    start_clock(dut.clk)
    dut.rst.setimmediatevalue(1)
    dut.xgmiiRxd.setimmediatevalue(0x07070707)
    dut.xgmiiRxc.setimmediatevalue(0xF)
    await reset_dut(dut, clk_name="clk", reset_names=("rst",))

    hkp_errors: list[int] = []
    error_codes: list[int] = []

    async def drive(rxd: int, rxc: int) -> None:
        dut.xgmiiRxd.value = rxd
        dut.xgmiiRxc.value = rxc
        await cycle(dut.clk, 1)
        if int(dut.hkpError.value) == 1:
            hkp_errors.append(int(dut.hkpWordCount.value))
        if int(dut.rxError.value) == 1:
            error_codes.append(int(dut.rxErrorCode.value))

    await drive(CXPOF_START | ((CXPOF_SOP_CTRL_HIGH_SPEED | CXPOF_SOP_CTRL_HKP) << 8), 0x1)
    await drive(0x5C5C3CBC, 0x5)
    await drive(0x07070707, 0xF)

    assert hkp_errors == [1]
    assert error_codes == [CXPOF_RX_ERR_HKP_MALFORMED]


@cocotb.test()
async def coaxpress_over_fiber_bridge_rx_control_lane_guardrail_sweep_test(dut):
    # `/S/`, `/Q/`, `/T/`, and `/E/` are lane-sensitive XGMII control bytes.
    # Misplaced control bytes should not leak any CoaXPress words, and a later
    # valid low-speed packet must still decode.
    start_clock(dut.clk)
    dut.rst.setimmediatevalue(1)
    dut.xgmiiRxd.setimmediatevalue(0x07070707)
    dut.xgmiiRxc.setimmediatevalue(0xF)
    await reset_dut(dut, clk_name="clk", reset_names=("rst",))

    observed: list[tuple[int, int]] = []

    async def drive(rxd: int, rxc: int) -> None:
        dut.xgmiiRxd.value = rxd
        dut.xgmiiRxc.value = rxc
        await cycle(dut.clk, 1)
        sample = (int(dut.rxData.value), int(dut.rxDataK.value))
        if sample != (CXP_IDLE, CXP_IDLE_K):
            observed.append(sample)

    for control_byte in (CXPOF_START, CXPOF_SEQ, CXPOF_ERROR):
        for lane in (1, 2, 3):
            await drive(_control_in_lane(control_byte, lane), 1 << lane)
            await drive(0x07070707, 0xF)

    # `/T/` outside an active packet is also malformed for this bridge input. It
    # is swept separately because lane 2 is valid only as part of a terminate
    # word once a payload is already active.
    for lane in (0, 1, 2, 3):
        await drive(_control_in_lane(CXPOF_TERM, lane), 1 << lane)
        await drive(0x07070707, 0xF)

    await drive(_cxp_start_word(CXP_PKT_EVENT_ACK), 0x1)
    await drive(0xA1B2C3D4, 0x0)
    await drive(0x07FD00FD, 0xC)
    await drive(0x07070707, 0xF)
    await drive(0x07070707, 0xF)

    assert observed == [
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT_ACK), 0x0),
        (0xA1B2C3D4, 0x0),
        (CXP_EOP, 0xF),
    ]


def test_CoaXPressOverFiberBridgeRx():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.coaxpressoverfiberbridgerx",
        extra_vhdl_sources={
            "surf": [
                "protocols/coaxpress/core/rtl/CoaXPressPkg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressOverFiberBridgeRx.vhd",
            ]
        },
    )
