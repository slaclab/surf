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
#   a non-Linear VOUT_MODE, the NOT_IMPLEMENTED command lists, the BMR474
#   manufacturer register map, and the simpleDisplay/hidden policy.
# - Stimulus: Real Rogue reads against a simulated AxiLitePMbusMasterCore
#   register window (one PMBus command per 32-bit word at 4*command, I2C
#   configuration word at 0x400). VOUT_MODE and READ_VOUT are preloaded from
#   the "PMBus Command Details" tables of 1/28701-BMR467 Rev E and
#   1/28701-BMR474 Rev A.
# - Checks: Decoded volts match the datasheet value within 1 mV; the 16-bit
#   mantissa is never sign-extended; VID/Direct modes return NaN; removed
#   commands are absent; present commands keep documented offsets, widths,
#   modes and poll intervals; raw registers hide with simpleDisplay while the
#   LinkVariables stay visible.
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
from surf.devices.flex._Bmr467 import NOT_IMPLEMENTED as BMR467_NOT_IMPLEMENTED  # noqa: E402
from surf.devices.flex._Bmr474 import NOT_IMPLEMENTED as BMR474_NOT_IMPLEMENTED  # noqa: E402

# (VOUT_MODE, READ_VOUT raw, expected volts) from the Flex command tables.
# 0x13 = exponent -13 (BMR467), 0x16 = exponent -10 (BMR474).
LINEAR16_VECTORS = [
    (0x13, 0x1CCD, 0.900),
    (0x13, 0x1B33, 0.850),
    (0x16, 0x0400, 1.000),
    (0x16, 0x0366, 0.850),
]

VOUT_MODE_CMD = 0x20
READ_VOUT_CMD = 0x8B


class PmbusMemory(rim.Slave):
    """AxiLitePMbusMasterCore register window: one command per 32-bit word."""

    def __init__(self):
        super().__init__(4, 0x1000)
        self.regs = {}

    def _doTransaction(self, transaction):
        with transaction.lock():
            address = transaction.address()
            size = transaction.size()
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


@pytest.mark.parametrize('device,notImplemented', [
    ('Bmr467', BMR467_NOT_IMPLEMENTED),
    ('Bmr474', BMR474_NOT_IMPLEMENTED),
])
def test_not_implemented_commands_are_absent(flex_root, device, notImplemented):
    dev, _ = flex_root[device]
    for name in notImplemented:
        assert not hasattr(dev, name), f'{device}.{name} should be removed'
    # Base-class commands both parts implement remain present.
    for name in ('OPERATION', 'ON_OFF_CONFIG', 'VOUT_MODE', 'VOUT_COMMAND', 'READ_VIN', 'READ_VOUT', 'READ_IOUT', 'READ_TEMPERATURE_1', 'STATUS_WORD'):
        assert hasattr(dev, name), f'{device}.{name} missing'


def test_bmr467_specific_commands(flex_root):
    dev, _ = flex_root['Bmr467']
    # Single-rail part: PAGE and PHASE are not implemented.
    assert not hasattr(dev, 'PAGE')
    assert not hasattr(dev, 'PHASE')
    assert dev.READ_IOUT0.offset == 4 * 0xF2
    assert dev.READ_IOUT1.offset == 4 * 0xE3
    assert list(dev.READ_IOUT0.bitSize) == [16]
    assert list(dev.READ_IOUT1.bitSize) == [16]
    assert dev.READ_IOUT0.pollInterval == 1
    assert dev.READ_IOUT1.pollInterval == 1
    assert dev.SECURITY_LEVEL.mode == 'RO'


def test_bmr474_specific_commands(flex_root):
    dev, _ = flex_root['Bmr474']
    # Two-phase part keeps PAGE and PHASE from the base class.
    assert dev.PAGE.offset == 4 * 0x00
    assert dev.PHASE.offset == 4 * 0x04
    expected = {
        'VOUT_MIN':                   (0x2B, 16, 'RW'),
        'POWER_MODE':                 (0x34, 8,  'RW'),
        'READ_MFR_VOUT':              (0xD4, 16, 'RO'),
        'STATUS_PHASES':              (0xDC, 16, 'RO'),
        'PIN_DETECT_OVERRIDE':        (0xEE, 8,  'RW'),
        'SLAVE_ADDRESS':              (0xEF, 8,  'RO'),
        'MFR_SPECIFIC_WRITE_PROTECT': (0xFB, 16, 'RW'),
    }
    for name, (command, bitSize, mode) in expected.items():
        var = getattr(dev, name)
        assert var.offset == 4 * command, name
        assert list(var.bitSize) == [bitSize], name
        assert var.mode == mode, name
    assert dev.READ_MFR_VOUT.pollInterval == 1


@pytest.mark.parametrize('device,rawNames', [
    ('Bmr467', ('DEADTIME_MAX', 'READ_IOUT0', 'SECURITY_LEVEL', 'VOUT_MODE', 'READ_VOUT')),
    ('Bmr474', ('VOUT_MIN', 'POWER_MODE', 'READ_MFR_VOUT', 'VOUT_MODE', 'READ_VOUT')),
])
def test_simple_display_hides_raw_registers_only(flex_root, device, rawNames):
    dev, _ = flex_root[device]
    for name in rawNames:
        assert getattr(dev, name).hidden is True, f'{device}.{name} should be hidden'
    for name in ('VIN', 'VOUT', 'IOUT'):
        assert getattr(dev, name).hidden is False, f'{device}.{name} should be visible'


@pytest.mark.parametrize('cls,rawName', [(Bmr467, 'DEADTIME_MAX'), (Bmr474, 'POWER_MODE')])
def test_simple_display_false_shows_raw_registers(cls, rawName):
    memory = PmbusMemory()
    root = pr.Root(pollEn=False, initRead=False, initWrite=False, timeout=1.0)
    dev = cls(name='Dev', memBase=memory, simpleDisplay=False)
    root.add(dev)
    try:
        root.start()
        assert getattr(dev, rawName).hidden is False
        assert dev.VOUT_MODE.hidden is False
        assert dev.VOUT.hidden is False
    finally:
        root.stop()
