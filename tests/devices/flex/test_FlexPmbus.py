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
# - Sweep: LINEAR16 VOUT vectors for both Flex exponents (VOUT_MODE 0x13 and
#   0x16) through the shared decoder and through the Bmr467/Bmr474 VOUT links,
#   a non-Linear VOUT_MODE, LINEAR11 VIN/IOUT/TEMPERATURE[1] vectors, and the
#   node map of both parts.
# - Stimulus: Real Rogue reads against a simulated AxiLitePMbusMasterCore
#   register window (one PMBus command per 32-bit word at 4*command).
#   VOUT_MODE and READ_VOUT are preloaded from the "PMBus Command Details"
#   tables of 1/28701-BMR467 Rev E and 1/28701-BMR474 Rev A.
# - Checks: Decoded values match within 1 mV/mA/mdegC; the 16-bit LINEAR16
#   mantissa is never sign-extended; VID/Direct modes return NaN; only VIN,
#   VOUT, IOUT and TEMPERATURE[1] are visible; the raw registers keep their
#   PMBus offsets, widths and RO mode and stay hidden; nothing is polled; no
#   RemoteCommand is defined; ReadAll touches only the five measurement
#   registers and WriteAll issues no transaction.
# - Timing: Synchronous memory transactions with a bounded Rogue timeout. No
#   SMBus transfer-type behaviour is modelled here: the access-ROM constants
#   in FlexPMbusPkg are covered by the VHDL flow, not by this file.

import math

import pytest

pr = pytest.importorskip('pyrogue', reason='Flex PMBus tests require Rogue/PyRogue')
rogue = pytest.importorskip('rogue', reason='Flex PMBus tests require Rogue/PyRogue')
rim = pytest.importorskip('rogue.interfaces.memory')

import surf.protocols.i2c  # noqa: E402
from surf.devices.flex import Bmr467, Bmr474  # noqa: E402

# (VOUT_MODE, READ_VOUT raw, expected volts) from the Flex command tables.
# 0x13 = exponent -13 (BMR467), 0x16 = exponent -10 (BMR474).
LINEAR16_VECTORS = [
    (0x13, 0x1CCD, 0.900),
    (0x13, 0x1B33, 0.850),
    (0x16, 0x0400, 1.000),
    (0x16, 0x0366, 0.850),
]

# (LinkVariable, raw register, LINEAR11 raw, expected value)
LINEAR11_VECTORS = [
    ('VIN',            'READ_VIN',           0xE0C0, 12.0),   # 192 * 2^-4
    ('IOUT',           'READ_IOUT',          0xF02A, 10.5),   # 42 * 2^-2
    ('IOUT',           'READ_IOUT',          0xF7FC, -1.0),   # -4 * 2^-2
    ('TEMPERATURE[1]', 'READ_TEMPERATURE_1', 0xF064, 25.0),   # 100 * 2^-2
]

VOUT_MODE_CMD = 0x20
READ_VOUT_CMD = 0x8B

# Raw registers behind the measurements: name -> (PMBus command, bit size)
RAW_REGISTERS = {
    'VOUT_MODE':          (0x20, 8),
    'READ_VIN':           (0x88, 16),
    'READ_VOUT':          (0x8B, 16),
    'READ_IOUT':          (0x8C, 16),
    'READ_TEMPERATURE_1': (0x8D, 16),
}

MEASUREMENTS = {'VIN', 'VOUT', 'IOUT', 'TEMPERATURE[1]'}


class PmbusMemory(rim.Slave):
    """AxiLitePMbusMasterCore register window: one command per 32-bit word."""

    def __init__(self):
        super().__init__(4, 0x1000)
        self.regs = {}
        self.accesses = []

    def _doTransaction(self, transaction):
        with transaction.lock():
            address = transaction.address()
            size = transaction.size()
            self.accesses.append((transaction.type(), address))
            if transaction.type() in (rim.Write, rim.Post):
                data = bytearray(size)
                transaction.getData(data, 0)
                for i in range(0, size, 4):
                    self.regs[address + i] = int.from_bytes(data[i:i + 4], 'little')
            else:
                data = bytearray()
                for i in range(0, size, 4):
                    data += self.regs.get(address + i, 0).to_bytes(4, 'little')
                transaction.setData(bytes(data), 0)
            transaction.done()

    def setCommand(self, command, value):
        self.regs[4 * command] = value


class FakeDependency:
    def __init__(self, value):
        self.value = value

    def get(self, read=False):
        return self.value


class FakeLink:
    def __init__(self, voutMode, raw):
        self.dependencies = [FakeDependency(voutMode), FakeDependency(raw)]


@pytest.fixture
def flex_root():
    memory467 = PmbusMemory()
    memory474 = PmbusMemory()
    root = pr.Root(pollEn=False, initRead=False, initWrite=False, timeout=1.0)
    bmr467 = Bmr467(name='Bmr467', memBase=memory467)
    bmr474 = Bmr474(name='Bmr474', memBase=memory474)
    root.add(bmr467)
    root.add(bmr474)
    try:
        root.start()
        yield {'Bmr467': (bmr467, memory467), 'Bmr474': (bmr474, memory474)}
    finally:
        root.stop()


@pytest.mark.parametrize('voutMode,raw,volts', LINEAR16_VECTORS)
def test_linear16_decoder_uses_unsigned_mantissa(voutMode, raw, volts):
    # Direct check of the shared helper; no Rogue tree needed.
    decoded = surf.protocols.i2c.getPMbusLinearDataFormat(FakeLink(voutMode, raw), read=False)
    assert decoded == pytest.approx(volts, abs=1e-3)
    assert decoded > 0.0


def test_linear16_decoder_never_sign_extends():
    # Bit 10 and bit 15 set: an 11-bit or 16-bit signed decode would go negative.
    assert surf.protocols.i2c.getPMbusLinearDataFormat(FakeLink(0x16, 0x0400), read=False) == pytest.approx(1.0)
    assert surf.protocols.i2c.getPMbusLinearDataFormat(FakeLink(0x16, 0x8000), read=False) == pytest.approx(32.0)
    assert surf.protocols.i2c.getPMbusLinearDataFormat(FakeLink(0x13, 0xFFFF), read=False) == pytest.approx(65535.0 / 8192.0)


@pytest.mark.parametrize('voutMode', [0x20, 0x40, 0x5F])
def test_linear16_decoder_rejects_vid_and_direct_modes(voutMode):
    # VOUT_MODE[7:5] = 001 (VID) or 010 (Direct) is not decodable here.
    assert math.isnan(surf.protocols.i2c.getPMbusLinearDataFormat(FakeLink(voutMode, 0x1CCD), read=False))


@pytest.mark.parametrize('device', ['Bmr467', 'Bmr474'])
@pytest.mark.parametrize('voutMode,raw,volts', LINEAR16_VECTORS)
def test_vout_link_reads_hardware(flex_root, device, voutMode, raw, volts):
    dev, memory = flex_root[device]
    memory.setCommand(VOUT_MODE_CMD, voutMode)
    memory.setCommand(READ_VOUT_CMD, raw)
    # read=True forces VOUT_MODE and READ_VOUT to be fetched from the window.
    assert dev.VOUT.get(read=True) == pytest.approx(volts, abs=1e-3)
    assert dev.VOUT_MODE.get(read=False) == voutMode
    assert dev.READ_VOUT.get(read=False) == raw


def test_vout_mode_is_read_from_hardware_not_defaulted(flex_root):
    dev, memory = flex_root['Bmr467']
    # Exponent -10 on a BMR467 tree must still decode with the hardware value.
    memory.setCommand(VOUT_MODE_CMD, 0x16)
    memory.setCommand(READ_VOUT_CMD, 0x0400)
    assert dev.VOUT.get(read=True) == pytest.approx(1.0, abs=1e-3)


@pytest.mark.parametrize('device', ['Bmr467', 'Bmr474'])
@pytest.mark.parametrize('link,rawName,raw,value', LINEAR11_VECTORS)
def test_linear11_links_read_hardware(flex_root, device, link, rawName, raw, value):
    dev, memory = flex_root[device]
    memory.setCommand(RAW_REGISTERS[rawName][0], raw)
    assert dev.node(link).get(read=True) == pytest.approx(value, abs=1e-3)


@pytest.mark.parametrize('device', ['Bmr467', 'Bmr474'])
def test_only_measurements_are_visible(flex_root, device):
    dev, _ = flex_root[device]
    visible = {name for name, var in dev.variables.items() if not var.hidden and name != 'enable'}
    assert visible == MEASUREMENTS
    for name in MEASUREMENTS:
        assert isinstance(dev.node(name), pr.LinkVariable), name
    remote = {name for name, var in dev.variables.items() if isinstance(var, pr.RemoteVariable)}
    assert remote == set(RAW_REGISTERS)
    for name, (command, bitSize) in RAW_REGISTERS.items():
        var = dev.node(name)
        assert var.offset == 4 * command, name
        assert list(var.bitSize) == [bitSize], name
        assert var.mode == 'RO', name
        assert var.hidden is True, name
    assert not [c for c in dev.commands.values() if isinstance(c, pr.RemoteCommand)]
    assert not dev.devices


@pytest.mark.parametrize('device', ['Bmr467', 'Bmr474'])
def test_nothing_is_polled(flex_root, device):
    dev, _ = flex_root[device]
    assert {name: var.pollInterval for name, var in dev.variables.items() if var.pollInterval} == {}


@pytest.mark.parametrize('device', ['Bmr467', 'Bmr474'])
def test_bulk_access_touches_only_measurement_registers(flex_root, device):
    dev, memory = flex_root[device]
    memory.accesses.clear()
    dev.root.ReadAll()
    assert {a for _, a in memory.accesses} == {4 * cmd for cmd, _ in RAW_REGISTERS.values()}
    assert {t for t, _ in memory.accesses} == {rim.Read}

    # Every register is RO: WriteAll must not start a PMBus transfer
    memory.accesses.clear()
    dev.root.WriteAll()
    assert memory.accesses == []
