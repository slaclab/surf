##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################


def ring_buffer_axil_addr(bus_index: int, buf: int = 0, high: int = 0) -> int:
    # The ring-buffer register maps pack MODE/STATUS more tightly than the
    # start/end/next/trig RAM windows, so keep the address encoding in one
    # shared helper instead of repeating the bit math in each bench.
    if bus_index in (4, 5):
        return (bus_index << 9) | (buf << 2)
    return (bus_index << 9) | (buf << 3) | (high << 2)


async def axil_read_u32(master, address: int) -> int:
    from cocotbext.axi import AxiResp

    txn = await master.read(address, 4)
    assert txn.resp == AxiResp.OKAY
    return int.from_bytes(txn.data, "little")


async def axil_write_u32(master, address: int, value: int) -> None:
    from cocotbext.axi import AxiResp

    txn = await master.write(address, value.to_bytes(4, "little"))
    assert txn.resp == AxiResp.OKAY
