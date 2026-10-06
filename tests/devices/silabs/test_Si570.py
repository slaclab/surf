#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Test methodology:
# - Sweep: per-device factory settings, repeated frequency changes, 38-bit RFREQ,
#   N1 limits, deferred writes, invalid requests and transaction failures.
# - Stimulus: real installed PyRogue with an in-memory byte-register slave.
# - Checks: independent register decode, calibration retention, command ordering,
#   no implicit/bulk writes, timing rejection and final readback verification.
# - Timing: deterministic software clock for polling/deadline checks. This does
#   not simulate RTL or qualify I2C/RSSI latency or physical output frequency.

from __future__ import annotations

import importlib.util
import math
from pathlib import Path
from types import SimpleNamespace
from typing import Any
import unittest
from unittest.mock import patch

import pyrogue as pr
import rogue.interfaces.memory as rim

# Load precisely the checked-out device without changing dependency import paths.
SOURCE = Path(__file__).resolve().parents[3] / 'python/surf/devices/silabs/_Si570.py'
SPEC = importlib.util.spec_from_file_location('si570_under_test', SOURCE)
si570 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(si570)


class Registers(rim.Slave):
    """Minimal Si570 register/command model, with no FPGA or network transport."""

    def __init__(self) -> None:
        super().__init__(4, 4)
        self.data = bytearray(1024)
        # Datasheet section 3.2: 156.25 MHz, HS_DIV=4, N1=8.
        self.factory = bytes([0x01, 0xc2, 0xbc, 0x01, 0x1e, 0xb8])
        self.events: list[tuple[str, int, int]] = []
        self.on_new_freq = lambda: None
        self.fail_register: int | None = None
        self.stuck_recall = False
        self.recall()

    def recall(self) -> None:
        for register, value in zip(range(7, 13), self.factory):
            self.data[4 * register] = value

    def _doTransaction(self, transaction: Any) -> None:
        address = transaction.address()
        size = transaction.size()
        if transaction.type() in (rim.Write, rim.Post):
            payload = bytearray(size)
            transaction.getData(payload, 0)
            self.events.append(('write', address // 4, payload[0]))
            if address // 4 == self.fail_register:
                transaction.error('injected I2C failure')
                return
            self.data[address:address + size] = payload
            if address == 4 * 135:
                if payload[0] & 1:
                    self.recall()
                if payload[0] & 0x40:
                    self.on_new_freq()
                self.data[address] &= 0x21 if self.stuck_recall else 0x20
        else:
            self.events.append(('read', address // 4, self.data[address]))
            transaction.setData(self.data[address:address + size], 0)
        transaction.done()


class TestSi570(unittest.TestCase):
    def setUp(self) -> None:
        self.now = 0.0
        self.clock_patch = patch.object(si570, 'time', SimpleNamespace(
            monotonic=lambda: self.now, sleep=self.advance))
        self.clock_patch.start()
        self.addCleanup(self.clock_patch.stop)
        self.memory = Registers()
        self.root = pr.Root(pollEn=False, initRead=False)
        self.dev = si570.Si570(name='Si570', factory_freq=156.25, memBase=self.memory)
        self.root.add(self.dev)
        self.addCleanup(self.root.stop)
        self.root.start()

    def advance(self, seconds: float) -> None:
        self.now += seconds

    def writes(self) -> list[tuple[str, int, int]]:
        return [event for event in self.memory.events if event[0] == 'write']

    def test_no_implicit_or_bulk_writes(self) -> None:
        self.assertEqual(self.writes(), [])
        self.assertTrue(math.isnan(self.dev.fxtal.get()))
        self.assertTrue(math.isnan(self.dev.Frequency.get()))
        with self.assertRaisesRegex(RuntimeError, 'Calibrate'):
            self.dev.Frequency.set(125.0)
        self.dev.Frequency.set(125.0, write=False)
        self.dev.writeAndVerifyBlocks(force=True)
        self.assertEqual(self.writes(), [])

    def test_factory_calibration_and_repeated_programming(self) -> None:
        self.dev.Calibrate()
        expected_xtal = 5000.0 * 2**28 / 0x2bc011eb8
        self.assertAlmostEqual(self.dev.fxtal.get(), expected_xtal)
        for requested in (125.0, 156.25, 100.0):
            self.memory.events.clear()
            self.dev.Frequency.set(requested)
            self.assertEqual(self.dev.fxtal.get(), expected_xtal)
            # Decode physical model bytes independently of the driver getters.
            regs = [self.memory.data[4 * i] for i in range(7, 13)]
            hs = {0: 4, 1: 5, 2: 6, 3: 7, 5: 9, 7: 11}[regs[0] >> 5]
            n1 = ((regs[0] & 31) * 4 + (regs[1] >> 6)) + 1
            rfreq = int.from_bytes(bytes([regs[1] & 63] + regs[2:]), 'big')
            actual = expected_xtal * rfreq / 2**28 / hs / n1
            self.assertAlmostEqual(actual, requested, places=7)
            self.assertAlmostEqual(self.dev.Frequency.get(), actual)
            writes = self.writes()
            self.assertEqual([e[1] for e in writes], [137, 7, 8, 9, 10, 11, 12, 137, 135])
            self.assertEqual(writes[0][2] & 16, 16)
            self.assertEqual(writes[-2][2] & 16, 0)
            self.assertEqual(writes[-1][2], 0x40)
            index = self.memory.events.index(writes[-2])
            self.assertEqual(self.memory.events[index + 1], writes[-1])

    def test_calibration_uses_this_device(self) -> None:
        self.dev.Calibrate()
        first = self.dev.fxtal.get()
        self.memory.factory = bytes([0x01, 0xc2, 0xbc, 0x10, 0x1e, 0xb8])
        self.dev.Calibrate()
        self.assertNotEqual(first, self.dev.fxtal.get())
        self.assertAlmostEqual(self.dev.fxtal.get(), 5000.0 * 2**28 / 0x2bc101eb8)

    def test_raw_field_widths_and_deferred_writes(self) -> None:
        self.dev.Config[7].get()
        self.dev.Config[8].get()
        self.memory.events.clear()
        value = (1 << 37) | 0x123456789
        self.dev.RFREQ_RAW.set(value, write=False)
        self.dev.N1.set(128, write=False)
        self.dev.HS_DIV_INT.set(11, write=False)
        self.assertEqual(self.memory.events, [])
        self.assertEqual(self.dev.RFREQ_RAW.get(read=False), value)
        self.assertEqual(self.dev.N1.get(read=False), 128)
        self.assertEqual(self.dev.HS_DIV_INT.get(read=False), 11)
        self.dev.RFREQ_RAW.set(value)
        self.dev.N1.set(128)
        self.assertEqual(self.dev.RFREQ_RAW.get(), value)
        self.assertEqual(self.dev.N1.get(), 128)
        with self.assertRaises(ValueError):
            self.dev.N1.set(3)
        with self.assertRaises(ValueError):
            self.dev.RFREQ_RAW.set(1 << 38)

    def test_invalid_frequency_has_no_writes(self) -> None:
        self.dev.Calibrate()
        self.memory.events.clear()
        for frequency in (0.0, -1.0, math.nan, math.inf, 2000.0):
            with self.assertRaises(ValueError):
                self.dev.Frequency.set(frequency)
        self.assertEqual(self.writes(), [])

    def test_deadline_violation_is_reported(self) -> None:
        self.dev.Calibrate()
        self.memory.on_new_freq = lambda: self.advance(0.011)
        with self.assertRaisesRegex(TimeoutError, '10 ms'):
            self.dev.Frequency.set(125.0)

    def test_recall_timeout_invalidates_calibration(self) -> None:
        self.dev.Calibrate()
        self.memory.stuck_recall = True
        with self.assertRaises(TimeoutError):
            self.dev.Calibrate()
        self.assertTrue(math.isnan(self.dev.fxtal.get()))

    def test_final_readback_mismatch(self) -> None:
        self.dev.Calibrate()
        self.memory.on_new_freq = self.memory.recall
        with self.assertRaisesRegex(RuntimeError, 'readback mismatch'):
            self.dev.Frequency.set(125.0)

    def test_failed_config_write_does_not_apply_partial_frequency(self) -> None:
        self.dev.Calibrate()
        self.memory.events.clear()
        self.memory.fail_register = 10
        with self.assertRaises(Exception):
            self.dev.Frequency.set(125.0)
        self.assertEqual(self.memory.data[4 * 137] & 16, 16)
        self.assertFalse(any(e[1] == 135 for e in self.writes()))


if __name__ == '__main__':
    unittest.main()
