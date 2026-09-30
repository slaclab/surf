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
# - Sweep: AxiLitePMbusMasterCore through AxiLitePMbusMasterCoreWrapper
#   (10 MHz axilClk, 100 kHz SCL, BMR467 access ROM, slave 0x26,
#   ignoreResp = 0 so I2C failures return SLVERR plus the I2cPkg fail code).
# - Stimulus: AXI-Lite reads/writes of PMBus commands at 4*command against
#   the cycle-level SMBus slave model in smbus_test_utils.
# - Checks: Word then byte reads return exactly the transferred bytes (no
#   stale upper bits); a write is stored by the slave and reads back.
# - Timing: The model updates the bus on falling clock edges; the DUT samples
#   through its own filters and synchronizers.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.common.regression_utils import run_surf_vhdl_test
from tests.protocols.pmbus.smbus_test_utils import SmbusSlave

CLK_PERIOD_NS = 100

SLAVE_ADDRESS = 0x26

# PMBus commands (BMR467 access ROM: VOUT_MODE is a byte, the others words)
VOUT_MODE = 0x20
VOUT_COMMAND = 0x21

REGISTERS = {
    VOUT_MODE: 0x13,       # exponent -13
    VOUT_COMMAND: 0x1B33,  # 0.85 V
}


class TB:
    def __init__(self, dut):
        self.dut = dut

        # 10 MHz axilClk, matching the wrapper FREQ_HZ
        cocotb.start_soon(Clock(dut.S_AXI_ACLK, CLK_PERIOD_NS, unit="ns").start())
        self.axil = AxiLiteMaster(
            bus=AxiLiteBus.from_prefix(dut, "S_AXI"),
            clock=dut.S_AXI_ACLK,
            reset=dut.S_AXI_ARESETN,
            reset_active_level=False,
        )

        # Idle bus, then start the slave model on the resolved lines
        dut.sclIn.value = 1
        dut.sdaIn.value = 1
        self.slave = SmbusSlave(dut, dut.S_AXI_ACLK, SLAVE_ADDRESS, REGISTERS)
        self.slave_task = cocotb.start_soon(self.slave.run())

    async def reset(self):
        self.dut.S_AXI_ARESETN.value = 0
        for _ in range(10):
            await RisingEdge(self.dut.S_AXI_ACLK)
        self.dut.S_AXI_ARESETN.value = 1
        for _ in range(10):
            await RisingEdge(self.dut.S_AXI_ACLK)

    async def read(self, command):
        resp = await self.axil.read(4 * command, 4)
        return int.from_bytes(resp.data, "little"), resp.resp

    async def write(self, command, value):
        resp = await self.axil.write(4 * command, value.to_bytes(4, "little"))
        return resp.resp


@cocotb.test()
async def pmbus_read_mask_and_write_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Word read first so its upper byte is left in the I2C read register
    value, resp = await tb.read(VOUT_COMMAND)
    assert resp == AxiResp.OKAY
    assert value == 0x1B33

    # Byte read: only the transferred byte, no stale 0x1B above it
    value, resp = await tb.read(VOUT_MODE)
    assert resp == AxiResp.OKAY
    assert value == 0x13, hex(value)

    # Write then read back through the slave
    assert await tb.write(VOUT_COMMAND, 0x1A00) == AxiResp.OKAY
    await Timer(100, unit="us")
    value, resp = await tb.read(VOUT_COMMAND)
    assert resp == AxiResp.OKAY
    assert value == 0x1A00


def test_AxiLitePMbusMasterCore():
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.axilitepmbusmastercorewrapper",
        # protocols/pmbus is only loaded by ruckus for Vivado builds
        extra_vhdl_sources={"surf": [
            "protocols/pmbus/rtl/PMbusPkg.vhd",
            "protocols/pmbus/rtl/FlexPMbusPkg.vhd",
            "protocols/pmbus/rtl/AxiLitePMbusMasterCore.vhd",
            "protocols/pmbus/wrappers/AxiLitePMbusMasterCoreWrapper.vhd",
        ]},
    )
