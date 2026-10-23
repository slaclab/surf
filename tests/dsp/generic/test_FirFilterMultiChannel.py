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
# - Sweep: Cover both the one-word direct cascade path and the multi-word cache
#   path by running one two-channel frame shape and one four-channel frame
#   shape.
# - Stimulus: Flatten the record ports through checked-in wrappers, program the
#   first coefficient over AXI-Lite, and stream AXI-Stream frames whose beat
#   count matches the wrapper's `NUM_CHANNELS_G/PARALLEL_G`.
# - Checks: The output frames must match a per-channel Python FIR model after
#   coefficient programming, and the AXI-Lite readback must reflect the written
#   coefficient word.
# - Timing: The axis and AXI-Lite clocks run in lockstep for the
#   `COMMON_CLK_G=true` case, and the bench checks frame-by-frame output order
#   rather than assuming zero-latency transport through the wrapper.

import cocotb
import os
from pathlib import Path
import pytest
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import run_surf_vhdl_test, start_lockstep_clocks
from tests.dsp.generic.dsp_test_utils import (
    fir_direct_outputs,
    pack_words_le,
    tick,
    to_signed_int,
    unpack_words_le,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.data_width = int(os.environ["DATA_WIDTH_G"])
        self.coeff_width = int(os.environ["COEFF_WIDTH_G"])
        self.num_channels = int(os.environ["NUM_CHANNELS_G"])
        self.parallel = int(os.environ["PARALLEL_G"])
        self.words_per_frame = self.num_channels // self.parallel
        self.axil = None
        self.source = None
        self.sink = None

        start_lockstep_clocks(dut.S_AXIS_ACLK, dut.M_AXIS_ACLK, dut.S_AXI_ACLK, period_ns=5.0)
        dut.S_AXIS_ARESETN.setimmediatevalue(0)
        dut.M_AXIS_ARESETN.setimmediatevalue(0)
        dut.S_AXI_ARESETN.setimmediatevalue(0)

    async def cycle(self, count=1):
        await tick(self.dut.S_AXIS_ACLK, count=count)

    async def reset(self):
        self.dut.S_AXIS_ARESETN.value = 0
        self.dut.M_AXIS_ARESETN.value = 0
        self.dut.S_AXI_ARESETN.value = 0
        await self.cycle(4)
        self.dut.S_AXIS_ARESETN.value = 1
        self.dut.M_AXIS_ARESETN.value = 1
        self.dut.S_AXI_ARESETN.value = 1
        await self.cycle(4)

    def start_agents(self):
        if self.axil is None:
            self.axil = AxiLiteMaster(
                AxiLiteBus.from_prefix(self.dut, "S_AXI"),
                self.dut.S_AXI_ACLK,
                self.dut.S_AXI_ARESETN,
                reset_active_level=False,
            )
        if self.source is None:
            self.source = AxiStreamSource(
                AxiStreamBus.from_prefix(self.dut, "S_AXIS"),
                self.dut.S_AXIS_ACLK,
                self.dut.S_AXIS_ARESETN,
                reset_active_level=False,
            )
        if self.sink is None:
            self.sink = AxiStreamSink(
                AxiStreamBus.from_prefix(self.dut, "M_AXIS"),
                self.dut.M_AXIS_ACLK,
                self.dut.M_AXIS_ARESETN,
                reset_active_level=False,
            )


def _parse_channel_vectors(raw: str) -> list[list[int]]:
    return [[int(value) for value in group.split(",")] for group in raw.split(";")]


@cocotb.test()
async def multichannel_data_and_axil_test(dut):
    tb = TB(dut)
    await tb.reset()
    tb.start_agents()

    coeff_mask = (1 << tb.coeff_width) - 1
    update_value = int(os.environ["COEFF_UPDATE_VALUE"])
    await axil_write_u32(tb.axil, 0x0, update_value)
    assert await axil_read_u32(tb.axil, 0x0) & coeff_mask == update_value & coeff_mask

    channel_vectors = _parse_channel_vectors(os.environ["CHANNEL_SAMPLES"])
    coeffs = [int(value) for value in os.environ["EXPECTED_COEFFS"].split(",")]
    expected_per_channel = [
        fir_direct_outputs(channel_samples, coeffs, data_width=tb.data_width, coeff_width=tb.coeff_width)
        for channel_samples in channel_vectors
    ]

    frame_count = len(channel_vectors[0])
    for frame_index in range(frame_count):
        frame_words: list[int] = []
        for beat_index in range(tb.words_per_frame):
            base = beat_index * tb.parallel
            frame_words.extend(
                channel_vectors[base + lane][frame_index]
                for lane in range(tb.parallel)
            )
        frame = AxiStreamFrame(pack_words_le(frame_words, word_width=tb.data_width))
        await tb.source.send(frame)
        rx_frame = await tb.sink.recv()
        observed_words = [
            to_signed_int(raw, tb.data_width)
            for raw in unpack_words_le(rx_frame.tdata, word_width=tb.data_width, count=tb.num_channels)
        ]
        expected_words = [channel_expected[frame_index] for channel_expected in expected_per_channel]
        assert observed_words == expected_words


@pytest.mark.parametrize(
    "parameters",
    [
        pytest.param(
            {
                "WRAPPER_NAME": "FirFilterMultiChannelTestWrapper",
                "WRAPPER_PATH": "dsp/generic/wrappers/FirFilterMultiChannelTestWrapper.vhd",
                "COMMON_CLK_G": True,
                "NUM_TAPS_G": 3,
                "NUM_CHANNELS_G": 2,
                "PARALLEL_G": 2,
                "DATA_WIDTH_G": 8,
                "COEFF_WIDTH_G": 4,
                "COEFFICIENTS_G": "(0 => 0, 1 => 0, 2 => 0)",
                "MEMORY_TYPE_G": '"distributed"',
                "SYNTH_MODE_G": '"inferred"',
                "COEFF_UPDATE_VALUE": 7,
                "EXPECTED_COEFFS": "7,0,0",
                "CHANNEL_SAMPLES": "3,-2,5;1,4,-3",
            },
            id="parallel_two_channel_common_clock",
        ),
        pytest.param(
            {
                "WRAPPER_NAME": "FirFilterMultiChannelCacheTestWrapper",
                "WRAPPER_PATH": "dsp/generic/wrappers/FirFilterMultiChannelCacheTestWrapper.vhd",
                "COMMON_CLK_G": True,
                "NUM_TAPS_G": 3,
                "NUM_CHANNELS_G": 4,
                "PARALLEL_G": 2,
                "DATA_WIDTH_G": 8,
                "COEFF_WIDTH_G": 4,
                "COEFFICIENTS_G": "(0 => 0, 1 => 0, 2 => 0)",
                "MEMORY_TYPE_G": '"distributed"',
                "SYNTH_MODE_G": '"inferred"',
                "COEFF_UPDATE_VALUE": 7,
                "EXPECTED_COEFFS": "7,0,0",
                "CHANNEL_SAMPLES": "3,-2,5;1,4,-3;2,0,-1;-4,3,2",
            },
            id="parallel_two_of_four_cache_path",
        ),
    ],
)
def test_FirFilterMultiChannel(parameters):
    wrapper_name = str(parameters["WRAPPER_NAME"])
    sim_build_key = str(
        Path(__file__).resolve().parents[2]
        / "sim_build"
        / "dsp"
        / "generic"
        / f"test_FirFilterMultiChannel.{wrapper_name}"
    )
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel=f"surf.{wrapper_name.lower()}",
        parameters=None,
        sim_build_key=sim_build_key,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": [
                str(parameters["WRAPPER_PATH"]),
            ]
        },
    )
