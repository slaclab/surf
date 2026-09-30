##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

"""Cycle-level SMBus slave model on a resolved open-drain bus.

The model runs once per falling edge of the DUT clock. It resolves SCL/SDA as
a wired-AND of the master output enables (``'0'`` = master pulls low) and its
own drive, feeds the resolved levels back to the DUT, and then reacts to the
edges it saw:

- START/STOP (SDA edge while SCL is high) resynchronize the protocol state;
  STOP clears the latched command code, a repeated START keeps it.
- Address and command bytes are sampled on SCL rising edges and ACKed;
  another address is NACKed.
- Read data is sent little-endian (PMBus word order), one bit per SCL falling
  edge, for as many bytes as the master ACKs.
"""

from cocotb.triggers import FallingEdge


class SmbusSlave:
    def __init__(self, dut, clock, address, registers):
        self.dut = dut
        self.clock = clock
        self.address = address
        self.registers = dict(registers)
        self.scl = 1
        self.sda = 1
        self.cmd = None
        self._reset_protocol()

    # ------------------------------------------------------------------
    # Bus resolution
    # ------------------------------------------------------------------
    async def run(self):
        """Lifetime agent: resolve and serve the bus until cocotb ends the test."""
        while True:
            await FallingEdge(self.clock)

            # Wired-AND of the master and the slave drivers (the slave never stretches SCL)
            master_scl_low = str(self.dut.sclOEn.value) == "0"
            master_sda_low = str(self.dut.sdaOEn.value) == "0"
            scl = 0 if master_scl_low else 1
            sda = 0 if (master_sda_low or self._sda_low) else 1
            self.dut.sclIn.value = scl
            self.dut.sdaIn.value = sda

            self._on_bus(scl, sda)
            self.scl, self.sda = scl, sda

    # ------------------------------------------------------------------
    # Protocol state
    # ------------------------------------------------------------------
    def _reset_protocol(self):
        self._phase = "idle"
        self._expect = "addr"
        self._bits = 0
        self._shift = 0
        self._sda_low = False
        self._master_ack = False
        self._tx_data = b""
        self._tx_index = 0
        self._tx_byte = 0
        self._tx_bit = 7
        self._write_bytes = []

    def _on_bus(self, scl, sda):
        if self.scl and scl:
            if self.sda and not sda:
                # START or repeated START: the command code survives a repeated START
                self._reset_protocol()
                self._phase = "rx"
                return
            if not self.sda and sda:
                self.cmd = None
                self._reset_protocol()
                return

        if not self.scl and scl:
            # Rising edge: sample
            if self._phase == "rx":
                self._shift = ((self._shift << 1) | sda) & 0xFF
                self._bits += 1
            elif self._phase == "ack_in":
                self._master_ack = sda == 0

        elif self.scl and not scl:
            # Falling edge: drive the next bit
            if self._phase == "rx" and self._bits == 8:
                self._byte_received()
            elif self._phase == "ack_out":
                self._sda_low = False
                if self._expect == "tx":
                    self._start_read_data()
                else:
                    self._phase = "rx"
                    self._bits = 0
                    self._shift = 0
            elif self._phase == "tx":
                self._tx_bit -= 1
                if self._tx_bit < 0:
                    self._sda_low = False
                    self._phase = "ack_in"
                else:
                    self._sda_low = not ((self._tx_byte >> self._tx_bit) & 1)
            elif self._phase == "ack_in":
                if self._master_ack:
                    self._tx_index += 1
                    self._load_tx_byte()
                else:
                    self._phase = "wait_stop"

    def _byte_received(self):
        value = self._shift
        if self._expect == "addr":
            if (value >> 1) != self.address:
                self._phase = "wait_stop"
                return
            self._expect = "tx" if (value & 1) else "cmd"
        elif self._expect == "cmd":
            self.cmd = value
            self._write_bytes = []
            self._expect = "data"
        else:
            self._write_bytes.append(value)
            self.registers[self.cmd] = int.from_bytes(bytes(self._write_bytes), "little")
        self._sda_low = True
        self._phase = "ack_out"

    def _start_read_data(self):
        self._tx_data = self.registers.get(self.cmd, 0).to_bytes(4, "little")
        self._tx_index = 0
        self._load_tx_byte()

    def _load_tx_byte(self):
        self._tx_byte = self._tx_data[self._tx_index] if self._tx_index < len(self._tx_data) else 0
        self._tx_bit = 7
        self._sda_low = not ((self._tx_byte >> 7) & 1)
        self._phase = "tx"
