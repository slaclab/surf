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
# - Sweep: Keep the first `CoaXPressRx` assembly pass on the stable one-lane
#   path while still exercising all three externally visible outputs: config,
#   image header/data, and the synchronized ACK/event sidebands.
# - Stimulus: Drive one control-ack packet, one event packet, one `IO_ACK`,
#   and one rectangular image transaction directly into the raw receive lane,
#   keeping the receive-side packets spec-shaped where the current RTL can
#   consume that framing.
# - Checks: The assembled RX path must forward the config completion word,
#   export the event tag, pulse `trigAck`, emit the seven 32-bit image-header
#   words in order, and forward the programmed line payload with `SOF`/`TLAST`
#   behavior preserved through the output FIFOs.
# - Timing: All DUT-visible domains are driven in lockstep so the bench checks
#   the real FIFO/FSM sequencing without introducing unrelated clock skew.

import cocotb

from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks
from tests.protocols.coaxpress.coaxpress_test_utils import (
    CXP_EOP,
    CXP_IO_ACK,
    CXP_MARKER,
    CXP_PKT_CTRL_ACK_NO_TAG,
    CXP_PKT_EVENT,
    CXP_PKT_IMAGE_HEADER,
    CXP_PKT_IMAGE_LINE,
    CXP_SOP,
    append_snapshot_if_valid,
    reset_signals,
    repeat_byte,
    send_rx_word,
    set_initial_values,
)


HEADER_WORDS = [
    repeat_byte(0x12),
    repeat_byte(0x34),
    repeat_byte(0x56),
    repeat_byte(0x00),
    repeat_byte(0x00),
    repeat_byte(0x03),
    repeat_byte(0x00),
    repeat_byte(0x00),
    repeat_byte(0x04),
    repeat_byte(0x00),
    repeat_byte(0x00),
    repeat_byte(0x01),
    repeat_byte(0x00),
    repeat_byte(0x00),
    repeat_byte(0x05),
    repeat_byte(0x00),
    repeat_byte(0x00),
    repeat_byte(0x03),
    repeat_byte(0x00),
    repeat_byte(0x10),
    repeat_byte(0x00),
    repeat_byte(0x20),
    repeat_byte(0xAA),
]

EXPECTED_HDR_WORDS = [
    0x3456AA12,
    0x00000003,
    0x00000004,
    0x00000001,
    0x00000005,
    0x00000003,
    0x00200010,
]

def _capture_outputs(
    dut,
    *,
    cfg_beats: list[tuple[int, int, int]],
    data_beats: list[tuple[int, int, int, int]],
    hdr_beats: list[tuple[int, int, int, int]],
    event_tags: list[int],
    trig_ack_cycles: list[int],
    cycle_index: int,
) -> None:
    cfg_samples: list[dict[str, int]] = []
    data_samples: list[dict[str, int]] = []
    hdr_samples: list[dict[str, int]] = []
    append_snapshot_if_valid(cfg_samples, dut, valid_name="cfgTValid", field_names=("cfgTData", "cfgTKeep", "cfgTLast"))
    append_snapshot_if_valid(
        data_samples,
        dut,
        valid_name="dataTValid",
        field_names=("dataTData", "dataTKeep", "dataTLast", "dataTUser"),
    )
    append_snapshot_if_valid(
        hdr_samples,
        dut,
        valid_name="hdrTValid",
        field_names=("hdrTData", "hdrTKeep", "hdrTLast", "hdrTUser"),
    )
    cfg_beats.extend((sample["cfgTData"], sample["cfgTKeep"], sample["cfgTLast"]) for sample in cfg_samples)
    data_beats.extend(
        (sample["dataTData"], sample["dataTKeep"], sample["dataTLast"], sample["dataTUser"]) for sample in data_samples
    )
    hdr_beats.extend(
        (sample["hdrTData"], sample["hdrTKeep"], sample["hdrTLast"], sample["hdrTUser"]) for sample in hdr_samples
    )
    if int(dut.eventAck.value) == 1:
        event_tags.append(int(dut.eventTag.value))
    if int(dut.trigAck.value) == 1:
        trig_ack_cycles.append(cycle_index)


@cocotb.test()
async def coaxpress_rx_one_lane_integration_test(dut):
    start_lockstep_clocks(dut.dataClk, dut.cfgClk, dut.txClk, dut.rxClk, period_ns=4.0)
    set_initial_values(
        dut,
        {
            "rxData": 0,
            "rxDataK": 0,
            "rxLinkUp": 1,
            "rxFsmRst": 0,
            "rxNumberOfLane": 0,
            "dataTReady": 1,
            "hdrTReady": 1,
        },
    )
    await reset_signals(
        dut,
        clk=dut.rxClk,
        reset_names=("dataRst", "cfgRst", "txRst", "rxRst"),
        assert_cycles=4,
        release_cycles=4,
    )

    cfg_beats: list[tuple[int, int, int]] = []
    data_beats: list[tuple[int, int, int, int]] = []
    hdr_beats: list[tuple[int, int, int, int]] = []
    event_tags: list[int] = []
    trig_ack_cycles: list[int] = []

    sequence = [
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_CTRL_ACK_NO_TAG), 0x0),
        (repeat_byte(0x00), 0x0),
        (0x04000000, 0x0),
        (0x01234567, 0x0),
        (0xCAFEBABE, 0x0),
        (CXP_EOP, 0xF),
        (CXP_SOP, 0xF),
        (repeat_byte(CXP_PKT_EVENT), 0x0),
        (repeat_byte(0x10), 0x0),
        (repeat_byte(0x11), 0x0),
        (repeat_byte(0x12), 0x0),
        (repeat_byte(0x13), 0x0),
        (repeat_byte(0x5A), 0x0),
        (0x00010000, 0x0),
        (repeat_byte(0x00), 0x0),
        (0x11223344, 0x0),
        (0xA5A5A5A5, 0x0),
        (CXP_EOP, 0xF),
        (CXP_IO_ACK, 0xF),
        (repeat_byte(0x01), 0x0),
        (CXP_SOP, 0xF),
        (repeat_byte(0x01), 0x0),
        (repeat_byte(0x22), 0x0),
        (repeat_byte(0x33), 0x0),
        (repeat_byte(0x00), 0x0),
        (repeat_byte(25), 0x0),
        (CXP_MARKER, 0xF),
        (repeat_byte(CXP_PKT_IMAGE_HEADER), 0x0),
        *[(word, 0xF) for word in HEADER_WORDS],
        (CXP_SOP, 0xF),
        (repeat_byte(0x01), 0x0),
        (repeat_byte(0x44), 0x0),
        (repeat_byte(0x55), 0x0),
        (repeat_byte(0x00), 0x0),
        (repeat_byte(5), 0x0),
        (CXP_MARKER, 0xF),
        (repeat_byte(CXP_PKT_IMAGE_LINE), 0x0),
        (0x11111111, 0x0),
        (0x22222222, 0x0),
        (0x33333333, 0x0),
        (0xBEEFBEEF, 0x0),
        (CXP_EOP, 0xF),
    ]

    for cycle_index, (data, data_k) in enumerate(sequence):
        await send_rx_word(dut, data=data, data_k=data_k, clk=dut.rxClk)
        _capture_outputs(
            dut,
            cfg_beats=cfg_beats,
            data_beats=data_beats,
            hdr_beats=hdr_beats,
            event_tags=event_tags,
            trig_ack_cycles=trig_ack_cycles,
            cycle_index=cycle_index,
        )

    for cycle_index in range(40):
        await send_rx_word(dut, data=0xB53C3CBC, data_k=0x7, clk=dut.rxClk)
        _capture_outputs(
            dut,
            cfg_beats=cfg_beats,
            data_beats=data_beats,
            hdr_beats=hdr_beats,
            event_tags=event_tags,
            trig_ack_cycles=trig_ack_cycles,
            cycle_index=cycle_index + len(sequence),
        )

    assert cfg_beats == [(0x0123456700000000, 0xFF, 0)]
    assert event_tags == [0x5A]
    assert trig_ack_cycles
    assert [beat[:3] for beat in hdr_beats] == [(word, 0xF, 1 if index == len(EXPECTED_HDR_WORDS) - 1 else 0) for index, word in enumerate(EXPECTED_HDR_WORDS)]
    assert [beat[0] for beat in hdr_beats] == EXPECTED_HDR_WORDS
    assert data_beats == [
        (0x11111111, 0xF, 0, 0),
        (0x22222222, 0xF, 0, 0),
        (0x33333333, 0xF, 1, 0),
    ]


def test_CoaXPressRx():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.coaxpressrxwrapper",
        extra_vhdl_sources={
            "surf": [
                "protocols/coaxpress/core/rtl/CoaXPressPkg.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxWordPacker.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxLaneMux.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxLane.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRxHsFsm.vhd",
                "protocols/coaxpress/core/rtl/CoaXPressRx.vhd",
                "protocols/coaxpress/core/wrappers/CoaXPressRxWrapper.vhd",
            ]
        },
    )
