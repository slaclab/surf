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
# - Sweep: All five distributed PyRogue banks and their RTL decode entries.
# - Stimulus: Parse maintained sources without importing unavailable PyRogue.
# - Checks: Exact field-start offsets/bits and access modes match literal RTL
#   decodes or the preserved word-bank ABI; software fields never overlap or
#   escape a 4 KiB bank; parent child offsets agree, including the PHC core's
#   placement in the 32 KiB endpoint. AXI tests cover RAM decodes.
#   The documented ABI independently anchors widths, exact access and signedness;
#   in-memory mutations must fail for truncated fields and altered commands.
# - Timing: Static schema checks complement the real AXI/cocotb regressions.

import ast
from pathlib import Path
import re

import pytest

ROOT = Path(__file__).resolve().parents[3]
BANKS = [('PtpEndpoint', 'PtpEndpointControl'), ('PtpPhcCore', 'PtpPhcControl'),
         ('PtpPhc', 'PtpPhc'), ('PtpProtocolEngine', 'PtpProtocolReg'), ('PtpServo', 'PtpServo')]
CHILDREN = {
    'PtpEndpoint': {'ProtocolEngine': 0x2000, 'Servo': 0x3000, 'PhcCore': 0x4000},
    'PtpPhcCore': {'Phc': 0x1000},
}

# Numerical interpretation is an ABI property even when RTL stores an slv.
# Compare against the owning register guide and signed arithmetic consumers,
# not against another extraction of the Python device under test.
SIGNED_FIELDS = {
    'PtpEndpoint': set(),
    'PtpPhcCore': set(),
    'PtpPhc': {'Phase', 'RateAddend', 'AppliedRateAddend'},
    'PtpProtocolEngine': {'MaxPathDelay', 'IngressLatency', 'EgressLatency',
                          'CurrentUtcOffset', 'ExchangeSyncCorrection', 'ExchangeDelayCorrection'},
    'PtpServo': {'StepThreshold', 'LockThreshold', 'UnlockThreshold', 'DelayAsymmetry',
                 'Offset', 'FilteredDelay', 'RateCommand'},
}


def documented_schema(device):
    source = (ROOT/'ethernet/PtpCore/register-map.md').read_text()
    section = source.split(f'## {device} fields\n', 1)[1].split('\n## ', 1)[0]
    bank = dict(PtpEndpoint=0, PtpPhcCore=0x4000, PtpPhc=0x5000, PtpProtocolEngine=0x2000, PtpServo=0x3000)[device]
    fields = {}
    for offset, name, bits, access in re.findall(
            r'^\| `(0x[0-9A-Fa-f]+)` \| `([^`]+)` \| ([0-9:]+) \| (RO|RW|WO) \|', section, re.M):
        high, _, low = bits.partition(':')
        bit = int(low or high)
        fields[name] = (int(offset, 16)-bank, bit, int(high)-bit+1,
                        access, name in SIGNED_FIELDS[device])
    assert fields and SIGNED_FIELDS[device] <= fields.keys()
    return fields


# Preserved word-bank ABI from the documented register map. Dynamic RAM
# decoders replace axiSlaveRegister calls; the bus regression exercises these
# addresses and strobes. Keep this independent schema for software comparison.
WORD_BANK_FIELDS = {
    'PtpPhc': {
        (0x008, 0): 'RO',
        (0x010, 0): 'RO',
        (0x014, 0): 'RO',
        (0x018, 0): 'RO',
        (0x01C, 0): 'RO',
        (0x028, 0): 'RW',
        (0x030, 0): 'RW',
        (0x034, 0): 'RW',
        (0x038, 0): 'RW',
        (0x048, 0): 'RW',
        (0x058, 0): 'RO',
        (0x060, 0): 'RO',
    },
    'PtpProtocolEngine': {
        (0x004, 4): 'RW',
        (0x008, 0): 'RW',
        (0x008, 8): 'RW',
        (0x010, 0): 'RW',
        (0x020, 0): 'RW',
        (0x080, 0): 'RW',
        (0x088, 0): 'RW',
        (0x090, 0): 'RW',
        (0x098, 0): 'RW',
        (0x0A0, 0): 'RW',
        (0x0A8, 0): 'RW',
        (0x0B0, 0): 'RW',
        (0x0B8, 0): 'RW',
        (0x130, 0): 'RO',
        (0x138, 0): 'RO',
        (0x13C, 0): 'RO',
        (0x140, 0): 'RO',
        (0x160, 0): 'RO',
        (0x170, 0): 'RO',
        (0x180, 0): 'RO',
        (0x190, 0): 'RO',
        (0x1A0, 0): 'RO',
        (0x1B0, 0): 'RO',
        (0x1B8, 0): 'RO',
        (0x1BC, 0): 'RO',
        (0x1BC, 16): 'RO',
        (0x200, 0): 'RO',
        (0x204, 0): 'RO',
        (0x208, 0): 'RO',
        (0x20C, 0): 'RO',
        (0x210, 0): 'RO',
        (0x214, 0): 'RO',
        (0x218, 0): 'RO',
    },
    'PtpServo': {
        (0x004, 2): 'RW',
        (0x020, 0): 'RW',
        (0x024, 0): 'RW',
        (0x028, 0): 'RW',
        (0x02C, 0): 'RW',
        (0x030, 0): 'RW',
        (0x038, 0): 'RW',
        (0x040, 0): 'RW',
        (0x048, 0): 'RW',
        (0x050, 0): 'RW',
        (0x054, 0): 'RW',
        (0x060, 0): 'RW',
        (0x068, 0): 'RW',
        (0x070, 0): 'RW',
        (0x078, 0): 'RW',
        (0x080, 0): 'RW',
        (0x094, 0): 'RO',
        (0x098, 0): 'RO',
        (0x100, 0): 'RO',
        (0x110, 0): 'RO',
        (0x120, 0): 'RO',
        (0x200, 0): 'RO',
    },
}


def check_local_register_schema(device, rtl, python_source):
    tree = ast.parse(python_source)
    source = (ROOT/'ethernet/PtpCore/rtl'/f'{rtl}.vhd').read_text()
    expected = documented_schema(device)
    described = {}
    hardware = {}
    for ro, offset, bit in re.findall(
            r'axiSlaveRegister(R?)\(ep, x"([0-9A-F]{3})", (\d+),', source):
        key = int(offset, 16), int(bit)
        assert key not in hardware
        hardware[key] = 'RO' if ro else 'RW'
    hardware.update(WORD_BANK_FIELDS.get(device, {}))
    software = {}
    occupied = set()
    children = {}
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        keywords = {kw.arg: kw.value for kw in node.keywords}
        if isinstance(node.func, ast.Name) and node.func.id in ('PtpPhcCore', 'PtpPhc', 'PtpProtocolEngine', 'PtpServo'):
            children[ast.literal_eval(keywords['name'])] = ast.literal_eval(keywords['offset'])
        if not isinstance(node.func, ast.Attribute) or node.func.attr not in ('RemoteVariable', 'RemoteCommand'):
            continue
        offset = ast.literal_eval(keywords['offset'])
        bit = ast.literal_eval(keywords.get('bitOffset', ast.Constant(0)))
        width = ast.literal_eval(keywords['bitSize'])
        mode = ast.literal_eval(keywords.get('mode', ast.Constant('RW')))
        name = ast.literal_eval(keywords['name'])
        base = ast.unparse(keywords.get('base', ast.Attribute(value=ast.Name(id='pr'), attr='UInt')))
        assert base in ('pr.Int', 'pr.UInt'), (name, base)
        access = 'WO' if node.func.attr == 'RemoteCommand' else mode
        described[name] = (offset, bit, width, access, base == 'pr.Int')
        assert described[name] == expected.get(name), f'schema {name}: {described[name]} != {expected.get(name)}'
        if device in ('PtpEndpoint', 'PtpPhcCore') and name in ('CommitConfig', 'Snapshot'):
            assert node.func.attr == 'RemoteCommand', f'command {name}: expected RemoteCommand'
            assert ast.unparse(keywords['function']) == 'pr.BaseCommand.createTouch(1)', f'command {name}: strobe'
        if mode == 'WO':
            mode = 'RW'  # command strobes have deterministic hardware readback
        # The capability fields are described individually in software but are
        # one constant word in hardware.
        key = (offset, 0) if device == 'PtpPhcCore' and offset == 0x008 else (offset, bit)
        if device == 'PtpProtocolEngine' and offset == 0x48:
            key = (offset, 0)  # packed ledger status
        assert hardware.get(key) == mode, (name, key, mode)
        software[key] = mode
        bits = set(range(offset*8+bit, offset*8+bit+width))
        assert max(bits) < 0x1000*8
        assert not occupied.intersection(bits), name
        occupied.update(bits)
    assert software == hardware
    assert described == expected
    assert children == CHILDREN.get(device, {})


@pytest.mark.parametrize('device,rtl', BANKS)
def test_local_register_schema(device, rtl):
    check_local_register_schema(device, rtl, (ROOT/'python/surf/ethernet/ptp'/f'_{device}.py').read_text())


@pytest.mark.parametrize('device,rtl,name,keyword,replacement', [
    ('PtpPhc', 'PtpPhc', 'Seconds', 'bitSize', '32'),
    ('PtpPhc', 'PtpPhc', 'Phase', 'base', 'pr.UInt'),
    ('PtpProtocolEngine', 'PtpProtocolReg', 'CurrentUtcOffset', 'base', 'pr.UInt'),
    ('PtpEndpoint', 'PtpEndpointControl', 'IrqClear', 'mode', "'RW'"),
    ('PtpEndpoint', 'PtpEndpointControl', 'CommitConfig', 'function', 'pr.BaseCommand.createTouch(0)'),
    ('PtpPhcCore', 'PtpPhcControl', 'Owner', 'bitOffset', '1'),
    ('PtpPhcCore', 'PtpPhcControl', 'Snapshot', 'function', 'pr.BaseCommand.createTouch(0)'),
    ('PtpServo', 'PtpServo', 'DelayAsymmetry', 'bitSize', '32'),
])
def test_schema_rejects_mutation(device, rtl, name, keyword, replacement):
    tree = ast.parse((ROOT/'python/surf/ethernet/ptp'/f'_{device}.py').read_text())
    changed = 0
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        keywords = {kw.arg: kw for kw in node.keywords}
        if 'name' in keywords and ast.literal_eval(keywords['name'].value) == name:
            keywords[keyword].value = ast.parse(replacement, mode='eval').body
            changed += 1
    assert changed == 1
    with pytest.raises(AssertionError, match=f'(schema|command) {name}'):
        check_local_register_schema(device, rtl, ast.unparse(tree))
