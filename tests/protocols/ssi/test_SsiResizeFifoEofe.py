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
# - Sweep: Cover the full legacy EOFE propagation matrix across the same 160
#   SSI configuration pairs.
# - Stimulus: Send one single-beat frame flagged with EOFE into the FIFO.
# - Checks: EOFE must propagate only when both source and destination user
#   modes preserve user metadata; otherwise the flag must be absent.
# - Timing: The test waits for one output beat after reset and checks it.

import itertools

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout

from tests.common.regression_utils import parameter_case, run_surf_vhdl_test


TKEEP_MODES = {"normal": 0, "comp": 1, "count": 2}
TUSER_MODES = {"normal": 0, "first_last": 1, "last": 2, "none": 3}


def legacy_cases():
    # Keep the historical EOFE matrix, but express it as pytest parameter cases
    # so each simulator run still reports a readable configuration id.
    cases = []
    for slave_data, master_data, slave_user_bits, master_user_bits in itertools.product(
        [1, 64], [1, 64], [2, 8], [2, 8]
    ):
        case_id = f"bytes_{slave_data}_to_{master_data}_ubits_{slave_user_bits}_to_{master_user_bits}"
        cases.append(
            parameter_case(
                case_id,
                SLAVE_DATA_BYTES_G=slave_data,
                MASTER_DATA_BYTES_G=master_data,
                SLAVE_TKEEP_MODE_G=TKEEP_MODES["comp"],
                MASTER_TKEEP_MODE_G=TKEEP_MODES["comp"],
                SLAVE_TUSER_MODE_G=TUSER_MODES["first_last"],
                MASTER_TUSER_MODE_G=TUSER_MODES["first_last"],
                SLAVE_TUSER_BITS_G=slave_user_bits,
                MASTER_TUSER_BITS_G=master_user_bits,
            )
        )

    for slave_keep, master_keep, slave_user, master_user in itertools.product(
        TKEEP_MODES.values(), TKEEP_MODES.values(), TUSER_MODES.values(), TUSER_MODES.values()
    ):
        cases.append(
            parameter_case(
                f"keep_{slave_keep}_to_{master_keep}_user_{slave_user}_to_{master_user}",
                SLAVE_DATA_BYTES_G=8,
                MASTER_DATA_BYTES_G=8,
                SLAVE_TKEEP_MODE_G=slave_keep,
                MASTER_TKEEP_MODE_G=master_keep,
                SLAVE_TUSER_MODE_G=slave_user,
                MASTER_TUSER_MODE_G=master_user,
                SLAVE_TUSER_BITS_G=4,
                MASTER_TUSER_BITS_G=4,
            )
        )
    return cases


class TB:
    def __init__(self, dut, slave_bytes):
        self.dut = dut
        self.slave_bytes = slave_bytes
        # This older wrapper uses AXI-style signal names directly, so the bench
        # drives the clock here instead of reusing the flat SSI helper.
        cocotb.start_soon(Clock(dut.AXIS_ACLK, 10.0, unit="ns").start())

    async def reset(self):
        # Assert reset long enough for both resize and FIFO state to settle, and
        # explicitly initialize every source-side port before releasing reset.
        self.dut.AXIS_ARESETN.setimmediatevalue(0)
        self.dut.S_AXIS_TVALID.setimmediatevalue(0)
        self.dut.S_AXIS_TDATA.setimmediatevalue(0)
        self.dut.S_AXIS_TKEEP.setimmediatevalue(0)
        self.dut.S_AXIS_TLAST.setimmediatevalue(0)
        self.dut.S_AXIS_TDEST.setimmediatevalue(0)
        self.dut.S_AXIS_EOFE.setimmediatevalue(0)
        self.dut.M_AXIS_TREADY.setimmediatevalue(1)
        for _ in range(24):
            await RisingEdge(self.dut.AXIS_ACLK)
        self.dut.AXIS_ARESETN.value = 1
        for _ in range(4):
            await RisingEdge(self.dut.AXIS_ACLK)

    async def send_eofe_frame(self):
        # Drive one single-beat frame that ends with `EOFE`. The test only
        # cares whether that flag survives the resize/FIFO path.
        self.dut.S_AXIS_TVALID.value = 1
        self.dut.S_AXIS_TLAST.value = 1
        self.dut.S_AXIS_TDEST.value = 0
        self.dut.S_AXIS_EOFE.value = 1
        self.dut.S_AXIS_TDATA.value = int.from_bytes(bytes(range(self.slave_bytes)), "little")
        self.dut.S_AXIS_TKEEP.value = (1 << self.slave_bytes) - 1
        while int(self.dut.S_AXIS_TREADY.value) != 1:
            await RisingEdge(self.dut.AXIS_ACLK)
        await RisingEdge(self.dut.AXIS_ACLK)
        self.dut.S_AXIS_TVALID.value = 0
        self.dut.S_AXIS_TLAST.value = 0
        self.dut.S_AXIS_EOFE.value = 0


@cocotb.test()
async def ssi_resize_fifo_eofe_test(dut):
    slave_bytes = int(dut.SLAVE_DATA_BYTES_G)
    slave_user_mode = int(dut.SLAVE_TUSER_MODE_G)
    master_user_mode = int(dut.MASTER_TUSER_MODE_G)
    tb = TB(dut, slave_bytes)

    # Reset first, then inject one terminal EOFE-tagged frame.
    await tb.reset()
    await tb.send_eofe_frame()

    async def wait_for_output_terminal_beat():
        while True:
            await RisingEdge(dut.AXIS_ACLK)
            if int(dut.M_AXIS_TVALID.value) == 1 and int(dut.M_AXIS_TLAST.value) == 1:
                return

    # Wait until the wrapper presents the outgoing terminal beat. Apply the
    # timeout to the full condition wait so the test cannot hang indefinitely
    # if the frame is lost.
    await with_timeout(wait_for_output_terminal_beat(), 1, "ms")

    # EOFE is observable only when both ends preserve user metadata.
    expected_eofe = 1 if slave_user_mode != TUSER_MODES["none"] and master_user_mode != TUSER_MODES["none"] else 0
    assert int(dut.M_AXIS_EOFE.value) == expected_eofe


PARAMETER_SWEEP = legacy_cases()


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SsiResizeFifoEofe(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.ssiresizefifoeofewrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["protocols/ssi/wrappers/SsiResizeFifoEofeWrapper.vhd"]},
    )
