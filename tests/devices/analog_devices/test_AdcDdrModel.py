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
# - Sweep: Construct a non-default normalized map and all three device-specific
#   calibration adapters, including the two-lane AD9681 topology.
# - Stimulus: Use Rogue's memory emulator to write control and every delay lane;
#   construct calibration adapters with real device configuration models.
# - Checks: Verify register offsets, field widths/modes, memory readback, range
#   enforcement, blocking-command snapshot transaction count, bulk raw-snapshot
#   reads and grouped delay writes, staged-update callbacks, and physical-lane
#   channel mappings.
# - Timing: Memory transactions are synchronous software operations; ADC mode,
#   snapshot, and settling behavior is covered by the calibration mock test.

import pytest

pr = pytest.importorskip(
    'pyrogue',
    reason='ADC DDR model tests require Rogue/PyRogue')
rogue = pytest.importorskip(
    'rogue',
    reason='ADC DDR model tests require Rogue/PyRogue')
rim = pytest.importorskip(
    'rogue.interfaces.memory',
    reason='ADC DDR model tests require Rogue/PyRogue')

from surf.devices.analog_devices import (  # noqa: E402
    Ad9249Config,
    Ad9249ConfigGroup,
    Ad9249ChipConfig,
    Ad9249Readout,
    Ad9249ReadoutCalibration,
    Ad9249ReadoutBank,
    Ad9249ReadoutBankCalibration,
    Ad9252Config,
    Ad9252Readout,
    Ad9252ReadoutCalibration,
    Ad9681Config,
    Ad9681Readout,
    Ad9681ReadoutCalibration,
    AdcDdr,
    adcDdrDelayBits,
)


class CountingMemory(rim.Slave):
    def __init__(self, size=0x10000):
        super().__init__(4, size)
        self._memory = bytearray(size)
        self.transactions = []

    def _doTransaction(self, transaction):
        address = transaction.address()
        size = transaction.size()
        transactionType = transaction.type()
        self.transactions.append((transactionType, address, size))
        with transaction.lock():
            if transactionType in (rim.Write, rim.Post):
                data = bytearray(size)
                transaction.getData(data, 0)
                self._memory[address:address+size] = data
            else:
                transaction.setData(self._memory[address:address+size], 0)
            transaction.done()


@pytest.fixture
def memory_backed_readout():
    memory = rim.Emulate(4, 0x10000)
    root = pr.Root(name='Root', pollEn=False)
    readout = AdcDdr(
        name       = 'Readout',
        memBase    = memory,
        dataLanes  = 3,
        fcoLanes   = 2,
        channels   = 2,
        sampleBits = 14,
        serializationFactor = 8,
        delayBits  = 9)
    root.add(readout)
    root.start()
    try:
        yield readout
    finally:
        root.stop()


def test_normalized_map_geometry_and_memory_readback(memory_backed_readout):
    readout = memory_backed_readout

    assert readout.Version.offset == 0x000
    for name, offset, bitOffset, bitSize in (
            ('DataLanes', 0x004, 0, 8),
            ('FcoLanes', 0x004, 8, 8),
            ('Channels', 0x004, 16, 8),
            ('SampleBits', 0x004, 24, 8),
            ('DelayBits', 0x008, 0, 8),
            ('SerializationFactor', 0x008, 8, 8),
            ('PatternCheck', 0x008, 16, 1)):
        variable = readout.nodes[name]
        assert variable.offset == offset
        assert variable.bitOffset == [bitOffset]
        assert variable.bitSize == [bitSize]
        assert variable.mode == 'RO'
    for name in ('DataLanes', 'FcoLanes', 'Channels', 'SampleBits', 'SerializationFactor'):
        assert readout.nodes[name].hidden
    assert not readout.DelayBits.hidden
    assert 'Capabilities0' not in readout.nodes
    assert 'Capabilities1' not in readout.nodes
    assert readout.CaptureReset.offset == 0x00C
    assert readout.Relock.offset == 0x010
    assert readout.Snapshot.offset == 0x014
    assert readout.ClearCounters.offset == 0x018
    assert readout.DelayReady.offset == 0x01C
    assert readout.LockedMask.offset == 0x020
    assert readout.SnapshotSequence.offset == 0x024
    assert readout.Relock.bitOffset == [0]
    assert readout.Snapshot.bitOffset == [0]
    assert readout.ClearCounters.bitOffset == [0]
    pattern = readout.PatternTester
    assert pattern.offset == 0x800
    assert pattern.Start.offset == 0x000
    assert pattern.Abort.offset == 0x004
    assert pattern.Start.bitOffset == [0]
    assert pattern.Abort.bitOffset == [0]
    assert pattern.Alternating.address == 0x808
    assert pattern.ReferenceChannel.bitOffset == [8]
    assert pattern.ChannelMask.bitSize == [2]
    assert pattern.FcoMask.bitSize == [2]
    assert pattern.DataMask.bitSize == [14]
    assert pattern.Samples.address == 0x820
    assert pattern.Busy.address == 0x828
    assert pattern.AllFcoPass.bitOffset == [6]
    assert pattern.Sequence.address == 0x82C
    assert pattern.ChannelPassed.address == 0x834
    assert pattern.WordErrorCount[1].address == 0x844
    assert pattern.BitErrorMask[1].address == 0x884
    assert pattern.FcoErrorCount[1].address == 0x8C4
    assert not any(name.startswith('Pattern') and
                   name not in ('PatternCheck', 'PatternTester')
                   for name in readout.nodes)
    assert readout.LockedMask.bitSize == [2]
    assert 'ClockPresent' not in readout.nodes
    assert 'OverflowMask' not in readout.nodes
    assert readout.DataDelayBulk.offset == 0x100
    assert readout.DataDelayBulk.numValues == 3
    assert readout.DataDelayBulk.valueBits == 9
    assert readout.DataDelayBulk.valueStride == 32
    assert readout.DataDelayBulk.hidden
    assert readout.DataDelay[2].mode == 'RW'
    assert readout.DataDelay[2].minimum == 0
    assert readout.DataDelay[2].maximum == 511
    assert readout.FcoDelay[1].offset == 0x204
    assert readout.FcoWord[1].offset == 0x304
    assert readout.FcoWord[1].bitSize == [8]
    assert readout.LostLockCount[1].offset == 0x344
    assert readout.OverflowCount.offset == 0x500
    assert readout.DebugSampleRaw.offset == 0x600
    assert readout.DebugSampleRaw.numValues == 8
    assert readout.DebugSampleRaw.valueBits == 14
    assert readout.DebugSampleRaw.valueStride == 32
    assert readout.DebugSampleRaw.varBytes == 32
    assert readout.nodes['DebugVoltage[1]'].units == 'V'
    assert readout.DebugVoltageRange.get() == 2.0
    assert readout.DebugVoltageFormat.get() == 1
    assert isinstance(readout.nodes['DebugVoltage[0]'].get(read=True), float)
    nodeNames = list(readout.nodes)
    assert max(nodeNames.index(f'DebugSample[{channel}]') for channel in range(2)) < (
        min(nodeNames.index(f'DebugVoltage[{channel}]') for channel in range(2)))
    assert readout.Version.mode == 'RO'
    assert isinstance(readout.DataDelay[0], pr.LinkVariable)

    readout.CaptureReset.set(True)
    assert readout.CaptureReset.get(read=True) is True
    pattern.Alternating.set(True)
    pattern.ChannelMask.set(3)
    pattern.DataMask.set(0x3FFF)
    assert pattern.Alternating.get(read=True) is True
    assert pattern.ChannelMask.get(read=True) == 3
    assert pattern.DataMask.get(read=True) == 0x3FFF
    for lane, value in enumerate((17, 255, 511)):
        readout.DataDelay[lane].set(value)
        assert readout.DataDelay[lane].get(read=True) == value
    for lane, value in enumerate((31, 300)):
        readout.FcoDelay[lane].set(value)
        assert readout.FcoDelay[lane].get(read=True) == value

    with pytest.raises(rogue.GeneralError, match='Value range error'):
        readout.DataDelay[0].set(512)


def test_debug_sample_array_uses_one_bulk_transaction():
    memory = CountingMemory()
    expected = [0x100+index for index in range(32)]
    for index, sample in enumerate(expected):
        offset = 0x600 + 4*index
        memory._memory[offset:offset+4] = sample.to_bytes(4, 'little')
    root = pr.Root(name='Root', pollEn=False)
    readout = AdcDdr(
        name='Readout',
        memBase=memory,
        channels=8,
        sampleBits=14)
    root.add(readout)
    root.start()
    try:
        memory.transactions.clear()
        samples = readout.DebugSampleRaw.get(read=True)

        assert samples.shape == (32,)
        assert samples.tolist() == expected
        assert readout._getDebugSamples(read=False) == [
            expected[4*channel:4*(channel+1)]
            for channel in range(8)
        ]
        assert readout.nodes['DebugSample[1]'].get(read=False) == (
            '0x0104_0105_0106_0107')
        assert readout.nodes['DebugVoltage[1]'].get(read=False) == 0.03173828125
        assert memory.transactions == [(rim.Read, 0x600, 128)]
        assert readout.DebugSampleRaw._block.size == 128
    finally:
        root.stop()


@pytest.mark.parametrize(
    ('sample', 'inputRange', 'offsetBinary', 'expected'),
    (
        (0x0000, 2.0, False, 0.0),
        (0x1FFF, 2.0, False, 0.9998779296875),
        (0x2000, 2.0, False, -1.0),
        (0x0000, 2.0, True, -1.0),
        (0x3FFF, 2.0, True, 0.9998779296875),
        (0x0800, 1.0, False, 0.125),
    ),
)
def test_debug_voltage_conversion_through_public_model(
        sample, inputRange, offsetBinary, expected):
    memory = CountingMemory()
    memory._memory[0x600:0x604] = sample.to_bytes(4, 'little')
    root = pr.Root(name='Root', pollEn=False)
    readout = AdcDdr(
        name='Readout',
        memBase=memory,
        channels=1,
        sampleBits=14)
    root.add(readout)
    root.start()
    try:
        readout.DebugVoltageRange.set(inputRange)
        readout.DebugVoltageFormat.set(0 if offsetBinary else 1)

        assert readout.nodes['DebugVoltage[0]'].get(read=True) == expected
    finally:
        root.stop()


def test_snapshot_uses_one_command_and_one_bulk_read():
    memory = CountingMemory()
    root = pr.Root(name='Root', pollEn=False)
    readout = AdcDdr(
        name='Readout',
        memBase=memory,
        channels=8,
        sampleBits=14)
    root.add(readout)
    root.start()
    try:
        memory.transactions.clear()
        snapshots = readout.Snapshot()

        assert snapshots == ['0x0000_0000_0000_0000']*8
        assert memory.transactions == [
            (rim.Write, 0x014, 4),
            (rim.Read, 0x600, 128),
        ]
    finally:
        root.stop()


def test_data_delay_bulk_view_preserves_scalar_access_and_groups_transactions():
    memory = CountingMemory()
    root = pr.Root(name='Root', pollEn=False)
    readout = AdcDdr(
        name='Readout',
        memBase=memory,
        dataLanes=16,
        channels=8,
        sampleBits=14)
    root.add(readout)
    root.start()
    try:
        memory.transactions.clear()
        readout.DataDelay[3].set(7, write=True)

        assert memory.transactions == [
            (rim.Write, 0x10C, 4),
            (rim.Verify, 0x10C, 4),
        ]
        assert readout.DataDelayBulk.get(read=False, index=3) == 7

        memory.transactions.clear()
        readout._setDataDelays({lane: 11 for lane in range(8)})

        assert memory.transactions == [
            (rim.Write, 0x100, 32),
            (rim.Verify, 0x100, 32),
        ]
        assert readout._getDataDelays(read=False) == [11]*8 + [0]*8
        assert [readout.DataDelay[lane].get(read=False) for lane in range(16)] == (
            [11]*8 + [0]*8)
    finally:
        root.stop()


def test_device_specific_calibration_adapters():
    ad9249Config = Ad9249ConfigGroup(name='Ad9249Config')
    ad9249Readout = Ad9249ReadoutBank(name='Ad9249Readout')
    ad9249 = Ad9249ReadoutBankCalibration(
        name='Ad9249Calibration',
        config=ad9249Config,
        readout=ad9249Readout)
    assert ad9249._dataLaneToChannel == tuple(range(8))
    assert ad9249._configUpdate is None

    ad9249Full = Ad9249ReadoutCalibration(
        name='Ad9249FullCalibration',
        config=Ad9249Config(name='Ad9249FullConfig'),
        readout=Ad9249Readout(name='Ad9249FullReadout'))
    assert len(ad9249Full.Bank) == 2
    assert all(isinstance(process, Ad9249ReadoutBankCalibration)
               for process in ad9249Full.Bank.values())

    ad9252Config = Ad9252Config(name='Ad9252Config')
    ad9252Readout = Ad9252Readout(name='Ad9252Readout')
    ad9252 = Ad9252ReadoutCalibration(
        name='Ad9252Calibration',
        config=ad9252Config,
        readout=ad9252Readout)
    assert ad9252._dataLaneToChannel == tuple(range(8))
    assert ad9252._configUpdate == ad9252Config.DeviceUpdate

    ad9681Config = Ad9681Config(name='Ad9681Config')
    ad9681Readout = Ad9681Readout(name='Ad9681Readout')
    ad9681 = Ad9681ReadoutCalibration(
        name='Ad9681Calibration',
        config=ad9681Config,
        readout=ad9681Readout)
    assert ad9681._dataLaneToChannel == tuple(range(8))+tuple(range(8))
    assert ad9681._configUpdate is None
    assert ad9681.UsePatternTester.value() is False
    assert ad9681.UsePatternTester.mode == 'RW'
    assert ad9681.RunTime.value() == 0.0
    assert ad9681.RunTime.mode == 'RO'
    assert ad9681.RunTime.units == 's'


def test_ad9252_config_register_fields():
    config = Ad9252Config(name='Config')

    assert config.UserTestMode.offset == 0x34
    assert config.UserTestMode.bitOffset == [6]
    assert config.UserTestMode.bitSize == [2]
    assert config.DcoFcoDrive2x.description == 'Set DCO and FCO output drive strength.'


def test_ad9249_chip_config_constructs_both_banks():
    config = Ad9249ChipConfig()

    assert config.BankConfig[0].offset == 0x0000
    assert config.BankConfig[1].offset == 0x0200


def test_ad9249_resolution_sample_rate_override_register_fields():
    config = Ad9249ConfigGroup(name='Config')

    assert config.DeviceUpdate.offset == 0x3FC
    assert config.ResolutionSampleRateOverride.offset == 0x400
    assert config.ResolutionSampleRateOverride.bitOffset == [6]
    assert config.ResolutionSampleRateOverride.bitSize == [1]
    assert config.Resolution.offset == 0x400
    assert config.Resolution.bitOffset == [4]
    assert config.Resolution.bitSize == [2]
    assert config.SampleRate.offset == 0x400
    assert config.SampleRate.bitOffset == [0]
    assert config.SampleRate.bitSize == [3]


def test_ad9681_resolution_sample_rate_override_register_fields():
    config = Ad9681Config(name='Config')

    assert config.DeviceUpdate.offset == 0x3FC
    assert config.ResolutionSampleRateOverride.offset == 0x400
    assert config.ResolutionSampleRateOverride.bitOffset == [6]
    assert config.ResolutionSampleRateOverride.bitSize == [1]
    assert config.Resolution.offset == 0x400
    assert config.Resolution.bitOffset == [4]
    assert config.Resolution.bitSize == [2]
    assert config.SampleRate.offset == 0x400
    assert config.SampleRate.bitOffset == [0]
    assert config.SampleRate.bitSize == [3]


@pytest.mark.parametrize('configType', (Ad9249ConfigGroup, Ad9252Config, Ad9681Config))
def test_config_write_blocks_forwards_arguments(monkeypatch, configType):
    calls = []

    def writeBlocks(self, **kwargs):
        calls.append(kwargs)

    monkeypatch.setattr(pr.Device, 'writeBlocks', writeBlocks)
    config = configType(name='Config')
    updates = []
    config.DeviceUpdate = lambda: updates.append(True)
    variable = object()

    config.writeBlocks(
        force=True,
        recurse=False,
        variable=variable,
        checkEach=True,
        index=3,
        testOption='forwarded')

    assert calls == [{
        'force': True,
        'recurse': False,
        'variable': variable,
        'checkEach': True,
        'index': 3,
        'testOption': 'forwarded',
    }]
    assert updates == [True]


@pytest.mark.parametrize('configType', (Ad9249ConfigGroup, Ad9252Config, Ad9681Config))
def test_device_update_writes_transfer_strobe(configType):
    memory = CountingMemory()
    root = pr.Root(name='Root', pollEn=False)
    config = configType(name='Config', memBase=memory)
    root.add(config)
    root.start()
    try:
        memory.transactions.clear()
        config.DeviceUpdate()

        assert int.from_bytes(memory._memory[0x3FC:0x400], 'little') == 1
        assert memory.transactions == [(rim.Write, 0x3FC, 4)]
    finally:
        root.stop()


def test_device_specific_readout_geometry():
    ad9249 = Ad9249Readout(name='Ad9249')
    assert len(ad9249.Bank) == 2
    for bank, readout in ad9249.Bank.items():
        assert readout.offset == 0x1000*bank
        assert (
            readout._dataLanes,
            readout._fcoLanes,
            readout._channels,
            readout._sampleBits,
            readout._serializationFactor,
            readout._delayBits,
        ) == (8, 1, 8, 14, 14, 9)

    ad9252 = Ad9252Readout(name='Ad9252')
    assert (
        ad9252._dataLanes,
        ad9252._fcoLanes,
        ad9252._channels,
        ad9252._sampleBits,
        ad9252._serializationFactor,
        ad9252._delayBits,
    ) == (8, 1, 8, 14, 14, 9)

    ad9681 = Ad9681Readout(name='Ad9681')
    assert (
        ad9681._dataLanes,
        ad9681._fcoLanes,
        ad9681._channels,
        ad9681._sampleBits,
        ad9681._serializationFactor,
        ad9681._delayBits,
    ) == (16, 2, 8, 14, 8, 9)


@pytest.mark.parametrize(
    ('deviceFamily', 'delayBits'),
    (
        ('7SERIES', 5),
        ('ULTRASCALE', 9),
        ('ULTRASCALE_PLUS', 9),
    ),
)
def test_device_family_selects_native_delay_width(deviceFamily, delayBits):
    assert adcDdrDelayBits(deviceFamily) == delayBits
    assert Ad9249ReadoutBank(
        name='Ad9249', deviceFamily=deviceFamily)._delayBits == delayBits
    assert Ad9252Readout(
        name='Ad9252', deviceFamily=deviceFamily)._delayBits == delayBits
    assert Ad9681Readout(
        name='Ad9681', deviceFamily=deviceFamily)._delayBits == delayBits


@pytest.mark.parametrize(
    ('constructor', 'kwargs', 'message'),
    (
        (AdcDdr, {'dataLanes': 65}, 'dataLanes'),
        (AdcDdr, {'channels': 0}, 'channels'),
        (AdcDdr, {'sampleBits': 17}, 'sampleBits'),
        (AdcDdr, {'serializationFactor': 17}, 'serializationFactor'),
        (Ad9249ReadoutBank, {'deviceFamily': 'SPARTAN6'}, 'deviceFamily'),
        (Ad9252Readout, {'channels': 9}, 'channels'),
        (Ad9252Readout, {'deviceFamily': 'SPARTAN6'}, 'deviceFamily'),
        (Ad9681Readout, {'deviceFamily': 'SPARTAN6'}, 'deviceFamily'),
    ),
)
def test_readout_geometry_rejects_values_outside_rtl_limits(
        constructor, kwargs, message):
    with pytest.raises(ValueError, match=message):
        constructor(name='Readout', **kwargs)


def test_ad9681_adapter_requires_device_specific_readout():
    config = Ad9681Config(name='Config')
    wrong = AdcDdr(name='Wrong', dataLanes=8, fcoLanes=1, channels=8)

    with pytest.raises(TypeError, match='must be an Ad9681Readout'):
        Ad9681ReadoutCalibration(
            name='Calibration',
            config=config,
            readout=wrong)
