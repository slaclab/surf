##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

from __future__ import annotations

import itertools
from collections.abc import Iterable

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSink, AxiStreamSource

from tests.common.regression_utils import env_flag, parameter_case, run_surf_vhdl_test


def default_parameter_sweep():
    return [
        parameter_case("steady_state", ENABLE_IDLE_PAUSE="0", ENABLE_BACKPRESSURE="0"),
        parameter_case("idle_pause_only", ENABLE_IDLE_PAUSE="1", ENABLE_BACKPRESSURE="0"),
        parameter_case("backpressure_only", ENABLE_IDLE_PAUSE="0", ENABLE_BACKPRESSURE="1"),
        parameter_case("idle_pause_and_backpressure", ENABLE_IDLE_PAUSE="1", ENABLE_BACKPRESSURE="1"),
    ]


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


def incrementing_payload(length: int) -> bytearray:
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


def incrementing_payloads(lengths: Iterable[int]) -> list[bytearray]:
    return [incrementing_payload(length) for length in lengths]


class PgpLoopbackTB:
    """Common cocotb bench wiring for flattened PGP AXIS loopback wrappers."""

    def __init__(self, dut):
        self.dut = dut

        cocotb.start_soon(Clock(dut.AXIS_ACLK, 10.0, unit="ns").start())

        self.source = AxiStreamSource(
            bus=AxiStreamBus.from_prefix(dut, "S_AXIS"),
            clock=dut.AXIS_ACLK,
            reset=dut.AXIS_ARESETN,
            reset_active_level=False,
        )
        self.sink = AxiStreamSink(
            bus=AxiStreamBus.from_prefix(dut, "M_AXIS"),
            clock=dut.AXIS_ACLK,
            reset=dut.AXIS_ARESETN,
            reset_active_level=False,
        )

    def configure_optional_pauses(self):
        if env_flag("ENABLE_IDLE_PAUSE", default=False):
            self.source.set_pause_generator(cycle_pause())
        if env_flag("ENABLE_BACKPRESSURE", default=False):
            self.sink.set_pause_generator(cycle_pause())

    async def reset_and_wait_for_link(self):
        self.dut.AXIS_ARESETN.setimmediatevalue(0)

        for _ in range(2):
            await RisingEdge(self.dut.AXIS_ACLK)

        self.dut.AXIS_ARESETN.value = 0
        for _ in range(2):
            await RisingEdge(self.dut.AXIS_ACLK)

        self.dut.AXIS_ARESETN.value = 1
        for _ in range(2):
            await RisingEdge(self.dut.AXIS_ACLK)

        while int(self.dut.LINK_READY.value) != 1:
            await RisingEdge(self.dut.AXIS_ACLK)

    async def run_loopback(self, payloads: Iterable[bytes | bytearray]):
        expected_frames = []

        for payload in payloads:
            frame = AxiStreamFrame(payload)
            await self.source.send(frame)
            expected_frames.append(frame)

        for expected_frame in expected_frames:
            rx_frame = await self.sink.recv()
            assert rx_frame.tdata == expected_frame.tdata
            assert len(rx_frame.tdata) == len(expected_frame.tdata)

        assert self.sink.empty()


def run_pgp_wrapper_test(
    *,
    test_file: str,
    toplevel: str,
    wrapper_source: str,
    parameters: dict[str, object] | None = None,
    extra_env: dict[str, str] | None = None,
) -> None:
    run_surf_vhdl_test(
        test_file=test_file,
        toplevel=toplevel,
        parameters={} if parameters is None else parameters,
        extra_env=extra_env,
        extra_vhdl_sources={"surf": [wrapper_source]},
    )
