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
# - Purpose: Pin the RSSI header encoder independently of checksum generation
#   and transmit-state sequencing.  This file is the byte-layout oracle for
#   ACK, DATA, NULL, RST, and SYN headers emitted by the RTL.
# - DUT shape: Run `RssiHeaderReg` directly with the default SURF RSSI
#   header-size generics.  The test drives scalar request strobes and flattened
#   parameter fields, then samples the 64-bit header word returned for each
#   requested address.
# - Stimulus: Register one coherent set of TX sequence, RX acknowledgment,
#   busy, ACK-valid, and SYN negotiation parameters.  Request ACK, DATA, NULL,
#   RST, and SYN header words by address.  DATA is checked both with and without
#   a valid ACK so the ACK-bit capture rule is explicit.
# - Checks: Emitted words must match the shared Python protocol helper for flag
#   bits, busy propagation, ACK bit capture, sequence/ack fields, header
#   lengths, reserved bytes, checksum placeholders, and all SYN parameter
#   fields.  The test intentionally compares protocol-order bytes so endian
#   mistakes in the packed 64-bit word are visible.
# - Timing: Inputs are captured while no header strobe is active.  Each header
#   request is sampled after the module's registered one-cycle response, which
#   matches the timing assumed by `RssiTxFsm` when it asks for a header word
#   before checksum insertion.

import cocotb
import pytest
from cocotb.clock import Clock

from tests.common.regression_utils import run_surf_vhdl_test
from tests.common.regression_utils import sample_after_tpd
from tests.protocols.rssi.rssi_test_utils import (
    RssiParams,
    build_ack_header,
    build_data_header,
    build_null_header,
    build_rst_header,
    build_syn_header,
    header_words,
    parse_header,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        # `RssiHeaderReg` has one synchronous state register and no ready/valid
        # handshake, so the testbench only needs a clock and deterministic
        # post-edge sampling.
        cocotb.start_soon(Clock(dut.clk_i, 5.0, unit="ns").start())

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            # Wait past the default `TPD_G` so registered outputs are settled
            # before Python reads them.
            await sample_after_tpd(self.dut.clk_i, propagation_time=2)

    async def reset(self) -> None:
        # Reset all header request strobes and data fields before deasserting
        # reset; otherwise the combinational address decode can briefly see
        # unknowns at time zero.
        self.dut.rst_i.setimmediatevalue(1)
        self.clear_header_selects()
        self.dut.ack_i.setimmediatevalue(0)
        self.dut.txSeqN_i.setimmediatevalue(0)
        self.dut.rxAckN_i.setimmediatevalue(0)
        self.dut.busyHeadSt_i.setimmediatevalue(0)
        self.dut.addr_i.setimmediatevalue(0)
        await self.set_params(RssiParams())
        await self.cycle(4)
        self.dut.rst_i.value = 0
        await self.cycle(2)

    def clear_header_selects(self) -> None:
        # Do not clear `busyHeadSt_i` here.  In the RTL this input is both the
        # captured local BUSY status and the value inserted into requested
        # headers; clearing it during a request would test a topology that
        # `RssiCore` does not use.
        self.dut.synHeadSt_i.value = 0
        self.dut.rstHeadSt_i.value = 0
        self.dut.dataHeadSt_i.value = 0
        self.dut.nullHeadSt_i.value = 0
        self.dut.ackHeadSt_i.value = 0

    async def set_params(self, params: RssiParams) -> None:
        # The wrapper flattens `RssiParamType` because GHDL/cocotb does not
        # expose record fields on the DUT port as Python child handles.
        self.dut.paramVersion_i.value = params.version
        self.dut.paramChksumEn_i.value = params.chksum_en
        self.dut.paramTimeoutUnit_i.value = params.timeout_unit
        self.dut.paramMaxOutsSeg_i.value = params.max_outs_seg
        self.dut.paramMaxSegSize_i.value = params.max_seg_size
        self.dut.paramRetransTout_i.value = params.retrans_tout
        self.dut.paramCumulAckTout_i.value = params.cumul_ack_tout
        self.dut.paramNullSegTout_i.value = params.null_seg_tout
        self.dut.paramMaxRetrans_i.value = params.max_retrans
        self.dut.paramMaxCumAck_i.value = params.max_cum_ack
        self.dut.paramMaxOutofseq_i.value = params.max_outofseq
        self.dut.paramConnectionId_i.value = params.connection_id

    async def capture_inputs(
        self,
        *,
        ack: int,
        busy: int,
        tx_seq: int,
        rx_ack: int,
        params: RssiParams | None = None,
    ) -> None:
        # HeaderReg samples these fields only while no header strobe is active.
        # Hold that idle condition for two cycles so the registered copy is
        # unambiguous before a header word is requested.
        self.clear_header_selects()
        if params is not None:
            await self.set_params(params)
        self.dut.ack_i.value = ack
        self.dut.busyHeadSt_i.value = busy
        self.dut.txSeqN_i.value = tx_seq
        self.dut.rxAckN_i.value = rx_ack
        await self.cycle(2)

    async def read_header_word(self, select_name: str, address: int) -> tuple[int, int, int]:
        # Address is a 64-bit word index into the generated header.  The output
        # response is registered, so one clock after asserting the selected
        # header request is the first valid sample point.
        self.clear_header_selects()
        getattr(self.dut, select_name).value = 1
        self.dut.addr_i.value = address
        await self.cycle()
        word = int(self.dut.headerData_o.value)
        ready = int(self.dut.ready_o.value)
        length = int(self.dut.headerLength_o.value)
        getattr(self.dut, select_name).value = 0
        await self.cycle()
        return word, ready, length


@cocotb.test()
async def non_syn_header_fields_test(dut):
    tb = TB(dut)
    await tb.reset()
    # Capture one common set of control fields, then ask for each non-SYN
    # segment type so differences in flag packing are easy to see.
    await tb.capture_inputs(ack=1, busy=1, tx_seq=0x22, rx_ack=0x33)

    cases = [
        ("ackHeadSt_i", build_ack_header(sequence=0x22, acknowledge=0x33, busy=True, enable_checksum=False)),
        ("dataHeadSt_i", build_data_header(sequence=0x22, acknowledge=0x33, ack=True, busy=True, enable_checksum=False)),
        ("nullHeadSt_i", build_null_header(sequence=0x22, acknowledge=0x33, ack=True, busy=True, enable_checksum=False)),
        ("rstHeadSt_i", build_rst_header(sequence=0x22, acknowledge=0x33, busy=True, enable_checksum=False)),
    ]

    for select_name, expected_header in cases:
        # The helper builds protocol-order bytes with a zero checksum field;
        # HeaderReg emits the same pre-checksum 64-bit word.
        word, ready, length = await tb.read_header_word(select_name, 0)
        assert ready == 1
        assert length == 1
        assert word == header_words(expected_header)[0]
        parsed = parse_header(expected_header)
        assert parsed.header_length == 8
        assert parsed.sequence == 0x22
        assert parsed.acknowledge == 0x33
        assert parsed.checksum == 0


@cocotb.test()
async def ack_bit_is_registered_before_header_request_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Change `ack_i` after the idle capture cycle.  The DATA header should use
    # the previously registered ACK state, not the just-changed pin value.
    await tb.capture_inputs(ack=0, busy=0, tx_seq=0x44, rx_ack=0x55)
    tb.dut.ack_i.value = 1
    word, ready, _ = await tb.read_header_word("dataHeadSt_i", 0)
    assert ready == 1
    assert word == header_words(
        build_data_header(sequence=0x44, acknowledge=0x55, ack=False, enable_checksum=False)
    )[0]

    # Repeat the check in the opposite direction so both ACK clear and ACK set
    # behavior are pinned.
    await tb.capture_inputs(ack=1, busy=0, tx_seq=0x44, rx_ack=0x55)
    tb.dut.ack_i.value = 0
    word, ready, _ = await tb.read_header_word("dataHeadSt_i", 0)
    assert ready == 1
    assert word == header_words(
        build_data_header(sequence=0x44, acknowledge=0x55, ack=True, enable_checksum=False)
    )[0]


@cocotb.test()
async def syn_header_parameter_words_test(dut):
    tb = TB(dut)
    params = RssiParams(
        version=2,
        chksum_en=1,
        max_outs_seg=0x0A,
        max_seg_size=0x05DC,
        retrans_tout=0x0102,
        cumul_ack_tout=0x0304,
        null_seg_tout=0x0506,
        max_retrans=0x07,
        max_cum_ack=0x08,
        max_outofseq=0x09,
        timeout_unit=0x0A,
        connection_id=0x1122_3344,
    )
    await tb.reset()
    # Use non-default values in every SYN parameter field so word boundaries and
    # byte ordering mistakes are visible in a single comparison.
    await tb.capture_inputs(ack=1, busy=0, tx_seq=0x66, rx_ack=0x77, params=params)

    expected = build_syn_header(
        sequence=0x66,
        acknowledge=0x77,
        ack=True,
        params=params,
        enable_checksum=False,
    )
    for address, expected_word in enumerate(header_words(expected)):
        # SYN spans three 64-bit words.  `headerLength_o` reports that word
        # count, not byte count.
        word, ready, length = await tb.read_header_word("synHeadSt_i", address)
        assert ready == 1
        assert length == 3
        assert word == expected_word

    parsed = parse_header(expected)
    assert parsed.params == params


@cocotb.test()
async def unmapped_header_address_returns_not_ready_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.capture_inputs(ack=1, busy=0, tx_seq=0x01, rx_ack=0x02)

    # Most header types deassert ready for out-of-range addresses.  NULL has a
    # preserved legacy behavior that reports ready with zero data.
    for select_name in ("ackHeadSt_i", "dataHeadSt_i", "rstHeadSt_i", "synHeadSt_i"):
        word, ready, _ = await tb.read_header_word(select_name, 3)
        assert ready == 0
        assert word == 0

    word, ready, _ = await tb.read_header_word("nullHeadSt_i", 3)
    assert ready == 1
    assert word == 0


PARAMETER_SWEEP = [pytest.param({}, id="default_header_sizes")]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_RssiHeaderReg(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rssiheaderregwrapper",
        parameters=parameters,
        extra_env=parameters,
    )
