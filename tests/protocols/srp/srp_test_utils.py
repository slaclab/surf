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

from dataclasses import dataclass

from cocotb.triggers import RisingEdge, with_timeout

from tests.axi.utils import wait_sampled_ready


SRP_VERSION = 0x03
SRP_READ = 0x0
SRP_WRITE = 0x1
SRP_POSTED_WRITE = 0x2
SRP_NULL = 0x3

FOOTER_FRAME_ERROR = 1 << 10
FOOTER_VERSION_MISMATCH = 1 << 11
FOOTER_REQUEST_ERROR = 1 << 12
FOOTER_ADDRESS_ERROR = 1 << 7


@dataclass(frozen=True)
class SrpV3Request:
    opcode: int
    tid: int
    address: int
    byte_count: int
    version: int = SRP_VERSION
    timeout: int = 0
    prot: int = 0
    spare: int = 0
    ignore_mem_resp: int = 0

    @property
    def req_size(self) -> int:
        return self.byte_count - 1

    @property
    def response_header(self) -> list[int]:
        return srpv3_header(
            opcode=self.opcode,
            tid=self.tid,
            address=self.address,
            req_size=self.req_size,
            version=SRP_VERSION,
            timeout=self.timeout,
            prot=self.prot,
            spare=self.spare,
            ignore_mem_resp=self.ignore_mem_resp,
        )


@dataclass(frozen=True)
class AxisResponse:
    words: list[int]
    tdest: list[int]
    tuser: list[int]
    tkeep: list[int]

    @property
    def footer(self) -> int:
        return self.words[-1]


class FlatSrpAxis:
    def __init__(
        self,
        dut,
        *,
        clk,
        source_prefix: str = "S_AXIS",
        sink_prefix: str = "M_AXIS",
        data_bytes: int = 4,
    ):
        self.dut = dut
        self.clk = clk
        self.source_prefix = source_prefix
        self.sink_prefix = sink_prefix
        self.data_bytes = data_bytes

    def _sig(self, prefix: str, suffix: str):
        return getattr(self.dut, f"{prefix}_{suffix}")

    def init_source(self, *, prefix: str | None = None):
        prefix = self.source_prefix if prefix is None else prefix
        self._sig(prefix, "TVALID").setimmediatevalue(0)
        self._sig(prefix, "TDATA").setimmediatevalue(0)
        self._sig(prefix, "TKEEP").setimmediatevalue((1 << self.data_bytes) - 1)
        self._sig(prefix, "TLAST").setimmediatevalue(0)
        if hasattr(self.dut, f"{prefix}_TDEST"):
            self._sig(prefix, "TDEST").setimmediatevalue(0)
        if hasattr(self.dut, f"{prefix}_TID"):
            self._sig(prefix, "TID").setimmediatevalue(0)
        self._sig(prefix, "TUSER").setimmediatevalue(0)

    def init_sink(self, *, prefix: str | None = None, ready: int = 1):
        prefix = self.sink_prefix if prefix is None else prefix
        self._sig(prefix, "TREADY").setimmediatevalue(ready)

    async def send_words(self, words: list[int], *, tdest: int = 0, prefix: str | None = None):
        await self.send_packed_words(words, tdest=tdest, prefix=prefix)

    async def send_packed_words(self, words: list[int], *, tdest: int = 0, prefix: str | None = None):
        prefix = self.source_prefix if prefix is None else prefix
        words_per_beat = self.data_bytes // 4
        if words_per_beat < 1:
            raise ValueError("SRP helpers require at least one 32-bit word per stream beat")

        chunks = [
            words[index : index + words_per_beat]
            for index in range(0, len(words), words_per_beat)
        ]

        for index, chunk in enumerate(chunks):
            data = 0
            for word_index, word in enumerate(chunk):
                data |= (word & 0xFFFF_FFFF) << (32 * word_index)

            self._sig(prefix, "TVALID").value = 1
            self._sig(prefix, "TDATA").value = data
            self._sig(prefix, "TKEEP").value = (1 << (4 * len(chunk))) - 1
            self._sig(prefix, "TLAST").value = int(index == len(chunks) - 1)
            if hasattr(self.dut, f"{prefix}_TDEST"):
                self._sig(prefix, "TDEST").value = tdest
            if hasattr(self.dut, f"{prefix}_TID"):
                self._sig(prefix, "TID").value = 0
            self._sig(prefix, "TUSER").value = 0x2 if index == 0 else 0x0

            await wait_sampled_ready(
                self._sig(prefix, "TREADY"),
                clk=self.clk,
            )

        self._sig(prefix, "TVALID").value = 0
        self._sig(prefix, "TLAST").value = 0
        self._sig(prefix, "TUSER").value = 0

    async def _recv_response_unbounded(self, *, prefix: str) -> AxisResponse:
        prefix = self.sink_prefix if prefix is None else prefix
        self._sig(prefix, "TREADY").value = 1
        words = []
        tdest = []
        tuser = []
        tkeep = []

        while True:
            await RisingEdge(self.clk)
            if int(self._sig(prefix, "TVALID").value) != 1:
                continue

            data = int(self._sig(prefix, "TDATA").value)
            keep = int(self._sig(prefix, "TKEEP").value) if hasattr(self.dut, f"{prefix}_TKEEP") else (1 << self.data_bytes) - 1
            active_bytes = keep.bit_count()
            active_words = max(1, (active_bytes + 3) // 4)

            for word_index in range(active_words):
                words.append((data >> (32 * word_index)) & 0xFFFF_FFFF)
                if hasattr(self.dut, f"{prefix}_TDEST"):
                    tdest.append(int(self._sig(prefix, "TDEST").value))
                if hasattr(self.dut, f"{prefix}_TKEEP"):
                    tkeep.append(0xF)

            if hasattr(self.dut, f"{prefix}_TUSER"):
                tuser.append(int(self._sig(prefix, "TUSER").value))
            if int(self._sig(prefix, "TLAST").value) == 1:
                return AxisResponse(words=words, tdest=tdest, tuser=tuser, tkeep=tkeep)

    async def recv_response(self, *, prefix: str | None = None, timeout_time: int = 20) -> AxisResponse:
        prefix = self.sink_prefix if prefix is None else prefix
        return await with_timeout(
            self._recv_response_unbounded(prefix=prefix),
            timeout_time,
            "us",
        )

    async def expect_no_response(self, *, cycles: int = 80, prefix: str | None = None):
        prefix = self.sink_prefix if prefix is None else prefix
        self._sig(prefix, "TREADY").value = 1
        for _ in range(cycles):
            await RisingEdge(self.clk)
            assert int(self._sig(prefix, "TVALID").value) == 0


def srpv3_header(
    *,
    opcode: int,
    tid: int,
    address: int,
    req_size: int,
    version: int = SRP_VERSION,
    timeout: int = 0,
    prot: int = 0,
    spare: int = 0,
    ignore_mem_resp: int = 0,
) -> list[int]:
    word0 = (
        (version & 0xFF)
        | ((opcode & 0x3) << 8)
        | ((spare & 0x7FF) << 10)
        | ((ignore_mem_resp & 0x1) << 14)
        | ((prot & 0x7) << 21)
        | ((timeout & 0xFF) << 24)
    )
    return [
        word0,
        tid & 0xFFFF_FFFF,
        address & 0xFFFF_FFFF,
        (address >> 32) & 0xFFFF_FFFF,
        req_size & 0xFFFF_FFFF,
    ]


def srpv3_frame(request: SrpV3Request, payload: list[int] | None = None) -> list[int]:
    payload = [] if payload is None else payload
    return srpv3_header(
        opcode=request.opcode,
        tid=request.tid,
        address=request.address,
        req_size=request.req_size,
        version=request.version,
        timeout=request.timeout,
        prot=request.prot,
        spare=request.spare,
        ignore_mem_resp=request.ignore_mem_resp,
    ) + payload


def assert_srpv3_response(
    response: AxisResponse,
    request: SrpV3Request,
    payload: list[int],
    *,
    footer_mask: int = 0,
    footer_value: int = 0,
    expected_tdest: int | None = None,
):
    assert response.words[:5] == request.response_header
    assert response.words[5:-1] == [word & 0xFFFF_FFFF for word in payload]
    assert response.footer & footer_mask == footer_value

    if expected_tdest is not None:
        assert response.tdest == [expected_tdest] * len(response.words)

    if response.tkeep:
        assert response.tkeep == [0xF] * len(response.words)
    if response.tuser:
        assert response.tuser[0] & 0x2 == 0x2
