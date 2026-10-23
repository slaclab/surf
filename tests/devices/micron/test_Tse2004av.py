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
# - Sweep: Each configuration control, event-status changes, clear-command
#   success/failure, lock behavior, bulk writes, and readback mismatches.
# - Stimulus: Real Rogue writes and reads against a simulated sensor register
#   window, with CLEAR and EVENT_STS behavior from the Renesas TSE2004GB2B0
#   datasheet, page 25. Inject transport failures and corrupt limit readback.
# - Checks: Controls retain independent bit positions and verification; status
#   is excluded from verification; CLEAR is not replayed by later writes;
#   the raw summary reads one block; failed/locked writes remain visible.
# - Timing: Synchronous memory transactions with a bounded Rogue timeout;
#   temperature conversion and electrical I2C timing are outside this model.

import pytest

pr = pytest.importorskip('pyrogue', reason='Sensor tests require Rogue/PyRogue')
rogue = pytest.importorskip('rogue', reason='Sensor tests require Rogue/PyRogue')
rim = pytest.importorskip('rogue.interfaces.memory')

from surf.devices.micron import Tse2004av  # noqa: E402


class SensorMemory(rim.Slave):
    """Configuration and limit registers in a 32-bit FPGA window."""

    def __init__(self):
        super().__init__(4, 4)
        self.config = 0
        self.limits = {0x08: 0, 0x0c: 0, 0x10: 0}
        self.event = False
        self.clears = 0
        self.failWrites = False
        self.failClearValue = None
        self.corruptConfigRead = 0
        self.corruptLimitRead = False
        self.reads = []
        self.writes = []

    def _doTransaction(self, transaction):
        with transaction.lock():
            address = transaction.address()
            if address not in (0x04, *self.limits) or transaction.size() != 4:
                transaction.error('Unexpected sensor register access')
                return
            if transaction.type() in (rim.Write, rim.Post):
                data = bytearray(4)
                transaction.getData(data, 0)
                value = int.from_bytes(data, 'little')
                self.writes.append((address, value))
                if (self.failWrites or (address == 0x04 and self.failClearValue is not None
                                       and bool(value & 0x20) == self.failClearValue)):
                    transaction.error('Injected sensor write failure')
                    return
                if address == 0x04:
                    # Locks persist until reset and freeze the documented
                    # controls; either lock also prevents entering shutdown.
                    frozen = 0x060b if self.config & 0x00c0 else 0
                    if self.config & 0x0040:
                        frozen |= 0x0004
                    if self.config & 0x00c0 and not self.config & 0x0100:
                        value &= ~0x0100
                    value = (value & ~frozen) | (self.config & frozen) | (self.config & 0x00c0)
                    # CLEAR reads zero; EVENT_STS and reserved bits do not store writes.
                    self.config = value & 0x07cf
                    # CLEAR releases EVENT only in interrupt mode.
                    if value & 0x20 and value & 0x01:
                        self.clears += 1
                        self.event = False
                else:
                    self.limits[address] = value
            else:
                self.reads.append(address)
                if address == 0x04:
                    value = self.config | (0x10 if self.event else 0)
                    value ^= self.corruptConfigRead
                else:
                    value = 0 if self.corruptLimitRead else self.limits[address]
                transaction.setData(value.to_bytes(4, 'little'), 0)
            transaction.done()


@pytest.fixture
def sensor_root():
    memory = SensorMemory()
    root = pr.Root(pollEn=False, initRead=False, initWrite=False, timeout=1.0)
    sensor = Tse2004av(name='Sensor', memBase=memory)
    root.add(sensor)
    try:
        root.start()
        yield sensor, memory
    finally:
        root.stop()


@pytest.mark.parametrize('name,value,word', [
    ('EventMode', 1, 0x0001),
    ('EventPolarity', 1, 0x0002),
    ('CriticalOnly', True, 0x0004),
    ('EventEnable', True, 0x0008),
    ('EventLock', True, 0x0040),
    ('CriticalLock', True, 0x0080),
    ('Shutdown', True, 0x0100),
    ('Hysteresis', 1, 0x0200),
    ('Hysteresis', 2, 0x0400),
    ('Hysteresis', 3, 0x0600),
])
def test_control_fields_write_and_verify(sensor_root, name, value, word):
    sensor, memory = sensor_root
    field = getattr(sensor, name)

    field.set(value)

    assert memory.config == word
    assert sensor.Configuration.get() == word
    memory.corruptConfigRead = word
    with pytest.raises(rogue.GeneralError, match='Verify error'):
        field.set(value)


@pytest.mark.parametrize('oldEvent,newEvent', [(False, True), (True, False)])
def test_status_changes_do_not_fail_control_verification(sensor_root, oldEvent, newEvent):
    sensor, memory = sensor_root
    memory.config = 0x0409
    memory.event = oldEvent
    assert sensor.Configuration.get() == 0x0409 | (0x10 if oldEvent else 0)
    assert memory.reads == [0x04]
    memory.event = newEvent

    sensor.Hysteresis.set(1)

    assert memory.config == 0x0209
    assert memory.clears == 0
    assert sensor.EventStatus.get() is newEvent
    memory.reads.clear()
    assert sensor.Configuration.get(read=False) == 0x0209 | (0x10 if newEvent else 0)
    assert memory.reads == []


def test_clear_event_preserves_controls_and_is_not_replayed(sensor_root):
    sensor, memory = sensor_root
    memory.config = 0x0409  # Hysteresis, interrupt mode, and EVENT enabled.
    memory.event = True
    sensor.Configuration.get()

    sensor.ClearEvent()

    assert memory.config == 0x0409
    assert memory.clears == 1
    assert memory.event is False
    assert [value & 0x20 for _, value in memory.writes] == [0x20, 0]
    # A new event must survive later control and forced bulk writes.
    memory.event = True
    sensor.EventPolarity.set(1)
    sensor.writeAndVerifyBlocks(force=True, recurse=False)
    assert memory.clears == 1
    assert sensor.EventStatus.get() is True
    assert sensor.Configuration.get() == 0x041b


@pytest.mark.parametrize('failClearValue', [True, False])
def test_failed_clear_is_not_replayed(sensor_root, failClearValue):
    sensor, memory = sensor_root
    memory.config = 0x0009
    memory.event = True
    sensor.Configuration.get()
    memory.failClearValue = failClearValue

    with pytest.raises(rogue.GeneralError, match='Injected sensor write failure'):
        sensor.ClearEvent()

    clears = memory.clears
    memory.failClearValue = None
    memory.event = True
    sensor.EventPolarity.set(1)
    sensor.writeAndVerifyBlocks(force=True, recurse=False)
    assert memory.clears == clears
    assert sensor.EventStatus.get() is True


@pytest.mark.parametrize('lock', ['EventLock', 'CriticalLock'])
def test_locked_control_write_fails_verification(sensor_root, lock):
    sensor, memory = sensor_root
    getattr(sensor, lock).set(True)

    with pytest.raises(rogue.GeneralError, match='Verify error'):
        sensor.Hysteresis.set(1)

    assert memory.config & 0x0600 == 0


def test_configuration_propagates_write_failure(sensor_root):
    sensor, memory = sensor_root
    memory.failWrites = True

    with pytest.raises(rogue.GeneralError):
        sensor.EventEnable.set(True)

    assert memory.config == 0


def test_alarm_limit_still_verifies_writes(sensor_root):
    sensor, memory = sensor_root
    sensor.UpperAlarmLimit.set(0x0500)
    assert memory.limits[0x08] == 0x0500
    memory.corruptLimitRead = True

    with pytest.raises(rogue.GeneralError, match='Verify error'):
        sensor.UpperAlarmLimit.set(0x0550)

    assert memory.limits[0x08] == 0x0550
