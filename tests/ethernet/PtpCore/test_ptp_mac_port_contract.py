#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Test methodology:
# - Sweep: all bits of the capture, RX metadata and TX completion layouts,
#   zero/all-one and seeded mixed vectors; all 65,534 transport generations.
# - Stimulus: independent flat fields and packed inputs test encoding and
#   decoding separately. A controller drives the production PtpMacPort with
#   idle MAC traffic, delayed controller/owner acknowledgements, then repeated
#   complete abort handshakes. No internal state is forced or shortened.
# - Checks: explicit Python widths/offsets and reset encodings; no generation
#   advance before acknowledgement, no wrap/reopen/TX admission/RX token at
#   exhaustion, and system-reset recovery. Wire behavior belongs to the
#   separate GMII/XGMII composition tests.
# - Timing: combinational record functions settle for 1 ns; lifecycle inputs
#   change after the prior edge's TPD and outputs are sampled after 1.1 ns.
#   The idle-MAC wrapper uses TPD_G=0 ns; wire/capture alignment is tested by
#   the separate composition fixtures with their normal propagation delay.
#   The clock is a test-owned lifetime agent cancelled/joined on completion.

import os
import random

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import Timer

from tests.common.regression_utils import (
    cancel_and_join_tasks, cocotb_filtered_env, cocotb_test_filter, run_surf_vhdl_test, sample_after_tpd,
)


CAPTURE_FIELDS = [("timestamp", 96), ("ticks", 64), ("tickPhase", 3), ("generation", 32),
                  ("increment", 64), ("timeValid", 1), ("error", 1)]
FIELDS = CAPTURE_FIELDS + [("frameLength", 16), ("transportGeneration", 16),
                           ("cookie", 32), ("outcome", 2), ("captureValid", 1)]
LAYOUTS = {"capture": 261, "meta": 293, "completion": 312}


def initialize(dut):
    for name, _ in FIELDS:
        getattr(dut, name).value = 0
    for name in LAYOUTS:
        getattr(dut, name + "Bits").value = 0
    for name in ("clk", "openAdmission", "drainRequest", "abortRequest", "cancelAck", "macAck",
                 "txValid", "txGeneration"):
        getattr(dut, name).value = 0
    dut.rst.value = 1
    dut.ethClkEn.value = 1


@cocotb.test()
async def record_layouts(dut):
    initialize(dut)
    rng = random.Random(487)
    vectors = [{name: 0 for name, _ in FIELDS}, {name: (1 << width) - 1 for name, width in FIELDS}]
    for name, width in FIELDS:
        for bit in range(width):
            vectors.append({field: (1 << bit) if field == name else 0 for field, _ in FIELDS})
    vectors.extend({name: rng.getrandbits(width) for name, width in FIELDS} for _ in range(32))
    for vector in vectors:
        for name, value in vector.items():
            getattr(dut, name).value = value
        capture = 0
        for name, width in CAPTURE_FIELDS:
            capture = (capture << width) | vector[name]
        expected = {
            "capture": capture,
            "meta": (capture << 32) | (vector["frameLength"] << 16) | vector["transportGeneration"],
            "completion": (vector["cookie"] << 280) | (vector["outcome"] << 278) |
                          (vector["captureValid"] << 277) | (capture << 16) | vector["transportGeneration"],
        }
        for name in LAYOUTS:
            getattr(dut, name + "Bits").value = expected[name]
        await Timer(1, unit="ns")
        for name, width in LAYOUTS.items():
            assert len(getattr(dut, name + "Packed")) == width
            assert int(getattr(dut, name + "Packed").value) == expected[name], (name, vector, "encode")
            # Decoded fields are flattened without calling the production encoder.
            assert int(getattr(dut, name + "Decoded").value) == expected[name], (name, vector, "decode")
    assert int(dut.captureInit.value) == int(dut.metaInit.value) == 0
    assert int(dut.completionInit.value) == 2 << 278
    assert int(dut.normalStreamBits.value) == 141
    assert int(dut.timingStreamBits.value) == 149


@cocotb.test(timeout_time=20, timeout_unit="ms")
async def generation_exhaustion(dut):
    initialize(dut)
    clock = cocotb.start_soon(Clock(dut.clk, 8, unit="ns").start())

    async def edge(count=1):
        for _ in range(count):
            await sample_after_tpd(dut.clk, propagation_time=1.1)

    async def until(signal):
        for _ in range(12):
            await edge()
            if int(signal.value):
                return
        raise AssertionError(f"No {signal._name} during bounded abort handshake")

    try:
        await edge(6)
        dut.rst.value = 0
        dut.txValid.value = 1
        await edge(4)
        assert int(dut.lifecycleGeneration.value) == 0
        assert int(dut.admissionOpen.value) == int(dut.txReady.value) == int(dut.nextToken.value) == 0
        dut.txValid.value = 0
        dut.openAdmission.value = 1
        await edge(3)
        assert int(dut.lifecycleGeneration.value) == int(dut.admissionOpen.value) == 1

        for expected in range(2, 65536):
            dut.openAdmission.value = 0
            dut.abortRequest.value = 1
            await until(dut.cancelRequest)
            assert int(dut.admissionOpen.value) == 0
            if expected == 2:
                await edge(4)
                assert int(dut.lifecycleGeneration.value) == 1 and not int(dut.macRequest.value)
            dut.cancelAck.value = 1
            await until(dut.macRequest)
            if expected == 2:
                await edge(4)
                assert int(dut.lifecycleGeneration.value) == 1 and not int(dut.abortDone.value)
            dut.macAck.value = 1
            await until(dut.abortDone)
            assert int(dut.lifecycleGeneration.value) == expected
            assert int(dut.faults.value) == int(expected == 65535)
            dut.abortRequest.value = 0
            dut.cancelAck.value = 0
            dut.macAck.value = 0
            await edge(2)
            dut.openAdmission.value = 1
            await edge(2)
            assert int(dut.admissionOpen.value) == int(expected != 65535)
            if expected % 4096 == 0:
                dut._log.info("Transport generation sweep reached %d/65535", expected)

        # Exhaustion remains closed for current/stale requests and another abort.
        for request_generation in (65534, 65535, 0, 1):
            dut.txGeneration.value = request_generation
            dut.txValid.value = 1
            dut.openAdmission.value = 0
            await edge(2)
            dut.openAdmission.value = 1
            await edge(3)
            assert int(dut.txReady.value) == int(dut.nextToken.value) == int(dut.admissionOpen.value) == 0
        dut.txValid.value = 0
        dut.abortRequest.value = 1
        dut.cancelAck.value = 1
        dut.macAck.value = 1
        await until(dut.abortDone)
        assert int(dut.lifecycleGeneration.value) == 65535 and int(dut.faults.value) == 1

        initialize(dut)
        await edge(6)
        dut.rst.value = 0
        await edge(3)
        assert int(dut.lifecycleGeneration.value) == int(dut.faults.value) == 0
        dut.openAdmission.value = 1
        await edge(3)
        assert int(dut.lifecycleGeneration.value) == int(dut.admissionOpen.value) == 1
    finally:
        await cancel_and_join_tasks([clock])


@pytest.mark.parametrize("scenario", [
    "record_layouts",
    pytest.param("generation_exhaustion", marks=pytest.mark.skipif(
        os.environ.get("RUN_PTP_GENERATION_EXHAUSTION") != "1",
        reason="exhaustive lifecycle sweep; set RUN_PTP_GENERATION_EXHAUSTION=1")),
])
def test_ptp_mac_port_contract(scenario):
    run_surf_vhdl_test(
        test_file=__file__, toplevel="surf.PtpMacPortContractWrapper",
        extra_env=cocotb_filtered_env({}, cocotb_test_filter(scenario)),
        extra_vhdl_sources={"surf": ["ethernet/PtpCore/wrappers/PtpMacPortContractWrapper.vhd"]},
    )
