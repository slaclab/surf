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
# - Sweep: Exercise direct lookup, indexed lookup, and timeout-driven slot
#   reclamation in the ARP IP/MAC table.
# - Stimulus: Write entries through the IP/MAC write ports, query them by IP
#   and by explicit table position, then let one entry expire before writing a
#   replacement mapping.
# - Checks: Lookups must return the stored MAC/IP pair while live, and an
#   expired entry must disappear so a later write can replace it cleanly.
# - Timing: The wrapper uses a tiny clock-frequency generic so expiration is
#   proven with real timer rollovers instead of long fixed simulation delays.

from __future__ import annotations

import cocotb
import pytest

from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.EthMacCore.ethmac_test_utils import cycle
from tests.ethernet.UdpEngine.udp_test_utils import (
    LEGACY_IP_CFGS,
    LEGACY_MAC_CFGS,
    UDP_RTL_SOURCES,
    pulse_signal,
    setup_arp_ip_table_bench,
)


WRAPPER_PATH = "ethernet/UdpEngine/wrappers/ArpIpTableFlatWrapper.vhd"
POS_IP_MATCH_LOOKUP = 0
POS_TABLE_ENTRY0 = 1
EXPIRATION_WAIT_CYCLES = 24


@cocotb.test()
async def arp_ip_table_lookup_by_ip_and_position_test(dut):
    bench = await setup_arp_ip_table_bench(dut)

    # Seed the table exactly the way the integrated UDP stack does: one write
    # pulse for the IP half and one for the MAC half of the same entry.
    dut.ipWrAddr.value = LEGACY_IP_CFGS[1]
    await pulse_signal(dut.ipWrEn, clk=bench.clk)
    dut.macWrAddr.value = LEGACY_MAC_CFGS[1]
    await pulse_signal(dut.macWrEn, clk=bench.clk)

    # `pos=0` uses IP-match lookup while `pos=1` directly addresses entry 0 in
    # the small wrapper-configured table.
    dut.ipAddrIn.value = LEGACY_IP_CFGS[1]
    dut.pos.value = POS_IP_MATCH_LOOKUP
    await cycle(bench.clk, 1)
    assert int(dut.found.value) == 1
    assert int(dut.macAddr.value) == LEGACY_MAC_CFGS[1]

    dut.pos.value = POS_TABLE_ENTRY0
    await cycle(bench.clk, 1)
    assert int(dut.found.value) == 1
    assert int(dut.macAddr.value) == LEGACY_MAC_CFGS[1]
    assert int(dut.ipAddrOut.value) == LEGACY_IP_CFGS[1]


@cocotb.test()
async def arp_ip_table_expiration_reclaims_entry_test(dut):
    bench = await setup_arp_ip_table_bench(dut)

    # Start with one live entry so the wrapper's shortened timeout logic has
    # something concrete to age out.
    dut.ipWrAddr.value = LEGACY_IP_CFGS[1]
    await pulse_signal(dut.ipWrEn, clk=bench.clk)
    dut.macWrAddr.value = LEGACY_MAC_CFGS[1]
    await pulse_signal(dut.macWrEn, clk=bench.clk)

    # With the wrapper's tiny timing generics the entry should expire after a
    # handful of clock cycles if no inbound traffic refreshes the timer.
    await cycle(bench.clk, EXPIRATION_WAIT_CYCLES)
    dut.ipAddrIn.value = LEGACY_IP_CFGS[1]
    dut.pos.value = POS_IP_MATCH_LOOKUP
    await cycle(bench.clk, 2)
    assert int(dut.found.value) == 0

    # Reuse the reclaimed slot with a new mapping and confirm the old one no
    # longer answers while the new one does.
    dut.ipWrAddr.value = LEGACY_IP_CFGS[2]
    await pulse_signal(dut.ipWrEn, clk=bench.clk)
    await cycle(bench.clk, 2)
    dut.macWrAddr.value = LEGACY_MAC_CFGS[2]
    await pulse_signal(dut.macWrEn, clk=bench.clk)

    dut.ipAddrIn.value = LEGACY_IP_CFGS[1]
    dut.pos.value = POS_IP_MATCH_LOOKUP
    await cycle(bench.clk, 2)
    assert int(dut.found.value) == 0

    dut.ipAddrIn.value = LEGACY_IP_CFGS[2]
    await cycle(bench.clk, 2)
    assert int(dut.found.value) == 1
    assert int(dut.macAddr.value) == LEGACY_MAC_CFGS[2]


@pytest.mark.parametrize("parameters", [pytest.param({}, id="arp_ip_table_flat_wrapper")])
def test_ArpIpTable(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.arpiptableflatwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": UDP_RTL_SOURCES + [WRAPPER_PATH]},
    )
