##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file, may be
## copied, modified, propagated, or distributed except according to the terms
## contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Sweep: Run `RssiAxiLiteRegItf` through a thin AXI-Lite wrapper with a
#   common AXI/device clock so register behavior is deterministic.
# - Stimulus: Use `cocotbext.axi` to issue ordinary AXI-Lite reads/writes while
#   driving flattened negotiated-parameter and status inputs directly.
# - Checks: Reset defaults, writable parameter readback, max-segment-size
#   clamping, status/counter packing, state/sequence packing, and DECERR
#   responses are verified at the register boundary.
# - Timing: Output checks wait a few AXI clocks after writes so synchronized
#   device-domain outputs settle even when the wrapper is later retimed.

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import run_surf_vhdl_test


REG_CONTROL = 0x00
REG_INIT_SEQ = 0x04
REG_VERSION = 0x08
REG_MAX_OUTS_SEG = 0x0C
REG_MAX_SEG_SIZE = 0x10
REG_RETRANS_TOUT = 0x14
REG_CUMUL_ACK_TOUT = 0x18
REG_NULL_SEG_TOUT = 0x1C
REG_MAX_RETRANS = 0x20
REG_MAX_CUM_ACK = 0x24
REG_MAX_OUTOFSEQ = 0x28
REG_CONNECTION_ID = 0x2C
REG_NEG_CONNECTION_ID = 0x30
REG_STATUS = 0x40
REG_VALID_CNT = 0x44
REG_DROP_CNT = 0x48
REG_RESEND_CNT = 0x4C
REG_RECON_CNT = 0x50
REG_FRAME_RATE_0 = 0x54
REG_FRAME_RATE_1 = 0x58
REG_BANDWIDTH_0_LOW = 0x5C
REG_BANDWIDTH_0_HIGH = 0x60
REG_BANDWIDTH_1_LOW = 0x64
REG_BANDWIDTH_1_HIGH = 0x68
REG_STATES = 0x6C
REG_SEQUENCES = 0x70


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "S_AXI"), dut.axilClk, dut.axilRst)
        cocotb.start_soon(Clock(dut.axilClk, 5.0, unit="ns").start())

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.axilClk)
            await Timer(1, unit="ns")

    def _set_defaults(self) -> None:
        self.dut.negParamVersion_i.value = 1
        self.dut.negParamChksumEn_i.value = 1
        self.dut.negParamTimeoutUnit_i.value = 6
        self.dut.negParamMaxOutsSeg_i.value = 5
        self.dut.negParamMaxSegSize_i.value = 512
        self.dut.negParamRetransTout_i.value = 60
        self.dut.negParamCumulAckTout_i.value = 12
        self.dut.negParamNullSegTout_i.value = 180
        self.dut.negParamMaxRetrans_i.value = 3
        self.dut.negParamMaxCumAck_i.value = 4
        self.dut.negParamMaxOutofseq_i.value = 0
        self.dut.negParamConnectionId_i.value = 0xCAFE_BABE

        self.dut.txLastAckN_i.value = 0
        self.dut.rxSeqN_i.value = 0
        self.dut.rxAckN_i.value = 0
        self.dut.rxLastSeqN_i.value = 0
        self.dut.txTspState_i.value = 0
        self.dut.txAppState_i.value = 0
        self.dut.txAckState_i.value = 0
        self.dut.rxTspState_i.value = 0
        self.dut.rxAppState_i.value = 0
        self.dut.connState_i.value = 0
        self.dut.frameRate0_i.value = 0
        self.dut.frameRate1_i.value = 0
        self.dut.bandwidth0_i.value = 0
        self.dut.bandwidth1_i.value = 0
        self.dut.status_i.value = 0
        self.dut.dropCnt_i.value = 0
        self.dut.validCnt_i.value = 0
        self.dut.resendCnt_i.value = 0
        self.dut.reconCnt_i.value = 0

    async def reset(self) -> None:
        self.dut.axilRst.setimmediatevalue(1)
        self._set_defaults()
        await self.cycle(4)
        self.dut.axilRst.value = 0
        await self.cycle(4)

    async def write(self, address: int, value: int) -> None:
        await axil_write_u32(self.axil, address, value)
        await self.cycle(2)

    async def read(self, address: int) -> int:
        return await axil_read_u32(self.axil, address)


@cocotb.test()
async def defaults_and_writable_parameters_read_back_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Default control enables header checksums, and generic-derived defaults
    # should be visible both through AXI-Lite reads and device-domain outputs.
    assert await tb.read(REG_CONTROL) == 0x8
    assert await tb.read(REG_INIT_SEQ) == 0x80
    assert await tb.read(REG_VERSION) & 0xF == 1
    assert await tb.read(REG_MAX_OUTS_SEG) & 0xFF == 8
    assert await tb.read(REG_MAX_SEG_SIZE) & 0xFFFF == 1024
    assert int(dut.appParamChksumEn_o.value) == 1

    await tb.write(REG_CONTROL, 0x1D)
    assert await tb.read(REG_CONTROL) == 0x1D
    assert int(dut.openRq_o.value) == 1
    assert int(dut.closeRq_o.value) == 0
    assert int(dut.mode_o.value) == 1
    assert int(dut.injectFault_o.value) == 1
    assert int(dut.appParamChksumEn_o.value) == 1

    await tb.write(REG_INIT_SEQ, 0x5A)
    await tb.write(REG_VERSION, 0x2)
    await tb.write(REG_MAX_OUTS_SEG, 0x6)
    await tb.write(REG_RETRANS_TOUT, 0x1234)
    await tb.write(REG_CUMUL_ACK_TOUT, 0x0056)
    await tb.write(REG_NULL_SEG_TOUT, 0x0789)
    await tb.write(REG_MAX_RETRANS, 0x04)
    await tb.write(REG_MAX_CUM_ACK, 0x09)
    await tb.write(REG_MAX_OUTOFSEQ, 0x0A)
    await tb.write(REG_CONNECTION_ID, 0x1357_9BDF)

    assert await tb.read(REG_INIT_SEQ) == 0x5A
    assert await tb.read(REG_VERSION) & 0xF == 0x2
    assert await tb.read(REG_MAX_OUTS_SEG) & 0xFF == 0x6
    assert await tb.read(REG_RETRANS_TOUT) & 0xFFFF == 0x1234
    assert await tb.read(REG_CUMUL_ACK_TOUT) & 0xFFFF == 0x0056
    assert await tb.read(REG_NULL_SEG_TOUT) & 0xFFFF == 0x0789
    assert await tb.read(REG_MAX_RETRANS) & 0xFF == 0x04
    assert await tb.read(REG_MAX_CUM_ACK) & 0xFF == 0x09
    assert await tb.read(REG_MAX_OUTOFSEQ) & 0xFF == 0x0A
    assert await tb.read(REG_CONNECTION_ID) == 0x1357_9BDF

    assert int(dut.initSeqN_o.value) == 0x5A
    assert int(dut.appParamVersion_o.value) == 0x2
    assert int(dut.appParamMaxOutsSeg_o.value) == 0x6
    assert int(dut.appParamRetransTout_o.value) == 0x1234
    assert int(dut.appParamConnectionId_o.value) == 0x1357_9BDF


@cocotb.test()
async def max_segment_size_clamps_to_supported_range_test(dut):
    tb = TB(dut)
    await tb.reset()

    await tb.write(REG_MAX_SEG_SIZE, 4)
    assert await tb.read(REG_MAX_SEG_SIZE) & 0xFFFF == 8
    assert int(dut.appParamMaxSegSize_o.value) == 8

    await tb.write(REG_MAX_SEG_SIZE, 2048)
    assert await tb.read(REG_MAX_SEG_SIZE) & 0xFFFF == 1024
    assert int(dut.appParamMaxSegSize_o.value) == 1024

    await tb.write(REG_MAX_SEG_SIZE, 128)
    assert await tb.read(REG_MAX_SEG_SIZE) & 0xFFFF == 128
    assert int(dut.appParamMaxSegSize_o.value) == 128


@cocotb.test()
async def status_counters_states_and_negotiated_parameters_read_back_test(dut):
    tb = TB(dut)
    await tb.reset()

    dut.negParamVersion_i.value = 3
    dut.negParamMaxOutsSeg_i.value = 7
    dut.negParamMaxSegSize_i.value = 0x0200
    dut.negParamRetransTout_i.value = 0x0101
    dut.negParamCumulAckTout_i.value = 0x0202
    dut.negParamNullSegTout_i.value = 0x0303
    dut.negParamMaxRetrans_i.value = 5
    dut.negParamMaxCumAck_i.value = 6
    dut.negParamMaxOutofseq_i.value = 2
    dut.negParamConnectionId_i.value = 0xCAFE_BABE

    dut.status_i.value = 0x155
    dut.validCnt_i.value = 0x1111_2222
    dut.dropCnt_i.value = 0x3333_4444
    dut.resendCnt_i.value = 0x5555_6666
    dut.reconCnt_i.value = 0x7777_8888
    dut.frameRate0_i.value = 0x0102_0304
    dut.frameRate1_i.value = 0x0506_0708
    dut.bandwidth0_i.value = 0x1122_3344_5566_7788
    dut.bandwidth1_i.value = 0x99AA_BBCC_DDEE_FF00
    dut.txTspState_i.value = 0x12
    dut.txAppState_i.value = 0x3
    dut.txAckState_i.value = 0x4
    dut.rxTspState_i.value = 0x5
    dut.rxAppState_i.value = 0x6
    dut.connState_i.value = 0x7
    dut.txLastAckN_i.value = 0x89
    dut.rxSeqN_i.value = 0xAB
    dut.rxAckN_i.value = 0xCD
    dut.rxLastSeqN_i.value = 0xEF
    await tb.cycle(4)

    assert (await tb.read(REG_VERSION) >> 16) & 0xF == 3
    assert (await tb.read(REG_MAX_OUTS_SEG) >> 16) & 0xFF == 7
    assert (await tb.read(REG_MAX_SEG_SIZE) >> 16) & 0xFFFF == 0x0200
    assert (await tb.read(REG_RETRANS_TOUT) >> 16) & 0xFFFF == 0x0101
    assert (await tb.read(REG_CUMUL_ACK_TOUT) >> 16) & 0xFFFF == 0x0202
    assert (await tb.read(REG_NULL_SEG_TOUT) >> 16) & 0xFFFF == 0x0303
    assert (await tb.read(REG_MAX_RETRANS) >> 16) & 0xFF == 5
    assert (await tb.read(REG_MAX_CUM_ACK) >> 16) & 0xFF == 6
    assert (await tb.read(REG_MAX_OUTOFSEQ) >> 16) & 0xFF == 2
    assert await tb.read(REG_NEG_CONNECTION_ID) == 0xCAFE_BABE

    assert await tb.read(REG_STATUS) & 0x1FF == 0x155
    assert await tb.read(REG_VALID_CNT) == 0x1111_2222
    assert await tb.read(REG_DROP_CNT) == 0x3333_4444
    assert await tb.read(REG_RESEND_CNT) == 0x5555_6666
    assert await tb.read(REG_RECON_CNT) == 0x7777_8888
    assert await tb.read(REG_FRAME_RATE_0) == 0x0102_0304
    assert await tb.read(REG_FRAME_RATE_1) == 0x0506_0708
    assert await tb.read(REG_BANDWIDTH_0_LOW) == 0x5566_7788
    assert await tb.read(REG_BANDWIDTH_0_HIGH) == 0x1122_3344
    assert await tb.read(REG_BANDWIDTH_1_LOW) == 0xDDEE_FF00
    assert await tb.read(REG_BANDWIDTH_1_HIGH) == 0x99AA_BBCC

    assert await tb.read(REG_STATES) == 0x0765_4312
    assert await tb.read(REG_SEQUENCES) == 0xEFCD_AB89


@cocotb.test()
async def unmapped_and_unaligned_accesses_return_decerr_test(dut):
    tb = TB(dut)
    await tb.reset()

    bad_read = await tb.axil.read(0x200, 4)
    assert bad_read.resp == AxiResp.DECERR

    bad_write = await tb.axil.write(0x200, (0xA5A5_5A5A).to_bytes(4, "little"))
    assert bad_write.resp == AxiResp.DECERR

    unaligned_read = await tb.axil.read(0x02, 4)
    assert unaligned_read.resp == AxiResp.DECERR

    unaligned_write = await tb.axil.write(0x02, (0x1234_5678).to_bytes(4, "little"))
    assert unaligned_write.resp == AxiResp.DECERR


PARAMETER_SWEEP = [pytest.param({}, id="axi_lite")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_RssiAxiLiteRegItf(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssiaxiliteregitfwrapper",
        parameters=parameters,
        extra_vhdl_sources={
            "surf": [
                "protocols/rssi/v1/rtl/RssiAxiLiteRegItf.vhd",
                "protocols/rssi/v1/wrappers/RssiAxiLiteRegItfWrapper.vhd",
            ],
        },
        force_compile=True,
    )
