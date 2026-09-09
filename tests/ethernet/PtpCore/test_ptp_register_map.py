#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Test methodology:
# - Sweep: All four distributed PyRogue banks and their RTL decode entries.
# - Stimulus: Parse maintained sources without importing unavailable PyRogue.
# - Checks: Exact field-start offsets/bits and access modes match RTL; software
#   fields never overlap or escape a 1 KiB bank; parent child offsets agree.
# - Timing: Static schema checks complement the real AXI/cocotb regressions.

import ast
from pathlib import Path
import re

import pytest

ROOT = Path(__file__).resolve().parents[3]
BANKS = [('PtpEndpoint', 'PtpReg'), ('PtpPhc', 'PtpPhc'),
         ('PtpPort', 'PtpPort'), ('PtpServo', 'PtpServo')]


@pytest.mark.parametrize('device,rtl', BANKS)
def test_local_register_schema(device, rtl):
    tree = ast.parse((ROOT/'python/surf/ethernet/ptp'/f'_{device}.py').read_text())
    source = (ROOT/'ethernet/PtpCore/rtl'/f'{rtl}.vhd').read_text()
    hardware = {}
    for ro, offset, bit in re.findall(
            r'axiSlaveRegister(R?)\(ep, toSlv\(16#([0-9A-F]+)#, 10\), (\d+),', source):
        key = int(offset, 16), int(bit)
        assert key not in hardware
        hardware[key] = 'RO' if ro else 'RW'
    software = {}
    occupied = set()
    children = {}
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        keywords = {kw.arg: kw.value for kw in node.keywords}
        if isinstance(node.func, ast.Name) and node.func.id in ('PtpPhc', 'PtpPort', 'PtpServo'):
            children[ast.literal_eval(keywords['name'])] = ast.literal_eval(keywords['offset'])
        if not isinstance(node.func, ast.Attribute) or node.func.attr not in ('RemoteVariable', 'RemoteCommand'):
            continue
        offset = ast.literal_eval(keywords['offset'])
        bit = ast.literal_eval(keywords.get('bitOffset', ast.Constant(0)))
        width = ast.literal_eval(keywords['bitSize'])
        mode = ast.literal_eval(keywords.get('mode', ast.Constant('RW')))
        name = ast.literal_eval(keywords['name'])
        if mode == 'WO':
            mode = 'RW'  # command strobes have deterministic hardware readback
        # Config bits are described individually in software but use a two-bit
        # vector in the central hardware endpoint.
        key = (offset, 0) if device == 'PtpEndpoint' and offset in (4, 0x44) and bit < 2 else (offset, bit)
        if device == 'PtpPort' and offset == 0x48:
            key = (offset, 0)  # packed ledger status
        assert hardware.get(key) == mode, (name, key, mode)
        software[key] = mode
        bits = set(range(offset*8+bit, offset*8+bit+width))
        assert max(bits) < 0x400*8
        assert not occupied.intersection(bits), name
        occupied.update(bits)
    assert software == hardware
    if device == 'PtpEndpoint':
        assert children == {'Phc': 0x400, 'Port': 0x800, 'Servo': 0xC00}
