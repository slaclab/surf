#-----------------------------------------------------------------------------
# Title      : Eye-scan register port
#-----------------------------------------------------------------------------
# Description:
# Resolves eye-scan register roles to the variables of a transceiver driver
# device at call time, decodes the data width and RXOUT_DIV settings, and
# provides the primed read-modify-write, snapshot and restore used around a
# scan.
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

from __future__ import annotations

import time
from typing import Any, Callable

from surf.xilinx.eyescan._EyeScanFamilies import EyeScanFamily
from surf.xilinx.eyescan._EyeScanMath import internalWidth, maskWords, sdataMask
from surf.xilinx.eyescan._EyeScanTypes import (
    STATUS_OFF,
    STATUS_WAIT,
    EyeScanError,
    EyeScanTimeout,
    decodeControlStatus,
)

__all__ = [
    'EyeScanPort',
]

# One variable per shared DRP word block: reading it loads the whole word into
# the shadow, so a later write of any field in the word keeps its neighbours
_PRIME_ROLES = ('control', 'horzOffset', 'vsUtSign')

# Scalar roles saved before a scan and written back afterwards, in write order
_RESTORE_ROLES = ('horzOffset', 'vsCode', 'vsRange', 'vsNegDir', 'vsUtSign', 'prescale')

_ARRAY_ROLES = ('sdataMask', 'qualMask', 'qualifier')

# Seconds ES_CONTROL=0 may take to reach an idle status
IDLE_TIMEOUT = 1.0


class EyeScanPort:
    """Role-based access to the eye-scan variables of one driver device.

    Parameters
    ----------
    device : Any
        Transceiver driver device (for example ``Gthe3Channel``).
    family : EyeScanFamily
        Descriptor naming the driver variable behind each role.
    """

    def __init__(self, device: Any, family: EyeScanFamily) -> None:
        self.device = device
        self.family = family

    def var(self, role: str) -> Any:
        """Return the driver variable that implements ``role``.

        Parameters
        ----------
        role : str
            Role name, a key of the family register table.

        Returns
        -------
        Any
            The driver variable behind the role.

        Raises
        ------
        EyeScanError
            If the driver has no variable for the role.
        """
        name = self.family.regs.get(role)
        var = getattr(self.device, name, None) if name is not None else None
        if var is None:
            raise EyeScanError(f'{self.family.name}: driver has no variable {name} for role {role}')
        return var

    def words(self, role: str) -> list[Any]:
        """Return the ordered variables of an indexed ``role``.

        Parameters
        ----------
        role : str
            Role name, a key of the family array table.

        Returns
        -------
        list of Any
            The driver variables in word order.

        Raises
        ------
        EyeScanError
            If the driver lacks any variable of the role.
        """
        entry = self.family.arrays.get(role)
        if entry is not None and '{}' in entry[0]:
            found = [getattr(self.device, entry[0].format(i), None) for i in range(entry[1])]
            if any(var is None for var in found):
                raise EyeScanError(f'{self.family.name}: driver has no variable {entry[0]} for role {role}')
            return found
        group = getattr(self.device, entry[0], None) if entry is not None else None
        if not isinstance(group, dict) or len(group) < entry[1]:
            name = entry[0] if entry is not None else None
            raise EyeScanError(f'{self.family.name}: driver has no variable {name} for role {role}')
        return [group[i] for i in range(entry[1])]

    def read(self, role: str) -> int:
        """Read ``role`` from hardware.

        Parameters
        ----------
        role : str
            Role name, a key of the family register table.

        Returns
        -------
        int
            The raw register value.

        Raises
        ------
        EyeScanError
            If the driver has no variable for the role.
        """
        return int(self.var(role).get())

    def _widthRaw(self) -> tuple[int, int]:
        return self.read('rxDataWidth'), self.read('rxIntDataWidth')

    def _widthText(self, dataRaw: int, intRaw: int) -> str:
        return f'{self.family.name}: unsupported width setting RX_DATA_WIDTH raw {dataRaw}, RX_INT_DATAWIDTH raw {intRaw}'

    def widthDescription(self) -> str:
        """Return the raw width register values as text (reads hardware).

        Returns
        -------
        str
            ``RX_DATA_WIDTH`` and ``RX_INT_DATAWIDTH`` raw values.
        """
        dataRaw, intRaw = self._widthRaw()
        return f'RX_DATA_WIDTH raw {dataRaw}, RX_INT_DATAWIDTH raw {intRaw}'

    def bitsPerSample(self) -> int:
        """Return the internal data width in bits, read from hardware.

        Returns
        -------
        int
            Bits per sample at the sampler.

        Raises
        ------
        EyeScanError
            If the raw codes are unknown or the pair is not allowed for the
            family; the text names both raw values.
        """
        dataRaw, intRaw = self._widthRaw()
        bits = self.family.rxDataWidthCodes.get(dataRaw)
        if bits is None or (bits, intRaw) not in self.family.widthCombos:
            raise EyeScanError(self._widthText(dataRaw, intRaw))
        return internalWidth(bits, intRaw)

    def rxOutDiv(self) -> int:
        """Return the RXOUT_DIV divider, read from hardware.

        Returns
        -------
        int
            The decoded divider.

        Raises
        ------
        EyeScanError
            If the raw code is not supported by the family.
        """
        raw = self.read('rxOutDiv')
        div = self.family.rxOutDivCodes.get(raw)
        if div is None:
            raise EyeScanError(f'{self.family.name}: unsupported RXOUT_DIV raw {raw}')
        return div

    def horzHalfRange(self) -> int:
        """Return the horizontal counts spanning half a UI.

        Returns
        -------
        int
            Counts per half UI at the current RXOUT_DIV.
        """
        return self.family.countsPerHalfUiPerDiv * self.rxOutDiv()

    def write(self, role: str, value: int, verify: bool = True) -> None:
        """Write ``role``; the owning DRP word is written from its primed shadow.

        Parameters
        ----------
        role : str
            Role name, a key of the family register table.
        value : int
            Raw value to write.
        verify : bool
            Read the value back after the write.
        """
        self.var(role).set(value, verify=verify)

    def prime(self) -> None:
        """Read one variable of every shared word so no write uses a zero shadow."""
        for role in _PRIME_ROLES:
            self.var(role).get()
        for role in _ARRAY_ROLES:
            for var in self.words(role):
                var.get()

    def snapshot(self) -> dict:
        """Return the raw values of every register a scan changes.

        Must be taken after :meth:`prime`, which loaded the shadows read here.
        ES_CONTROL is not recorded: :meth:`restore` always leaves it 0, so the
        sampler is stopped after every scan, in the same way ES_EYE_SCAN_EN and
        ES_ERRDET_EN stay set.

        Returns
        -------
        dict
            Raw value of each scalar role, and a list of raw words for each
            mask array role.
        """
        snap = {}
        for role in _RESTORE_ROLES:
            snap[role] = int(self.var(role).get(read=False))
        for role in _ARRAY_ROLES:
            snap[role] = [int(var.get(read=False)) for var in self.words(role)]
        return snap

    def writeMasks(self, width: int) -> None:
        """Unmask ``width`` sdata bits and open the qualifier for every sample.

        Parameters
        ----------
        width : int
            Number of sdata bits to unmask.
        """
        for var in self.words('qualMask'):
            var.set(0xFFFF)
        for var in self.words('qualifier'):
            var.set(0x0000)
        sdata = self.words('sdataMask')
        for var, value in zip(sdata, maskWords(sdataMask(width, self.family.busWidth), len(sdata))):
            var.set(value)

    def waitStatus(self, accept: tuple[int, ...], timeout: float = IDLE_TIMEOUT,
                   sleep: Callable[[float], None] = time.sleep) -> int:
        """Wait for a raw ``es_control_status`` in ``accept`` and return it.

        Parameters
        ----------
        accept : tuple of int
            Raw status values that end the wait.
        timeout : float
            Seconds to wait.
        sleep : callable
            Sleep function; an abortable sleep may raise to stop the wait.

        Returns
        -------
        int
            The accepted raw status.

        Raises
        ------
        EyeScanTimeout
            If no accepted status was seen when the deadline passes.
        """
        deadline = time.monotonic() + timeout
        while True:
            status = self.read('controlStatus')
            if status in accept:
                return status
            if time.monotonic() >= deadline:
                raise EyeScanTimeout(
                    f'es_control_status stayed {decodeControlStatus(status)} (0x{status:X}) '
                    f'for {timeout:g} s after ES_CONTROL was cleared')
            sleep(0.002)

    def waitIdle(self, timeout: float = IDLE_TIMEOUT, sleep: Callable[[float], None] = time.sleep) -> int:
        """Wait for status WAIT or OFF and return the raw status.

        Parameters
        ----------
        timeout : float
            Seconds to wait.
        sleep : callable
            Sleep function; an abortable sleep may raise to stop the wait.

        Returns
        -------
        int
            The accepted raw status.

        Raises
        ------
        EyeScanTimeout
            If neither status was seen when the deadline passes.
        """
        return self.waitStatus((STATUS_WAIT, STATUS_OFF), timeout, sleep)

    def restore(self, snapshot: dict) -> None:
        """Write back a :meth:`snapshot`, ES_CONTROL first.

        Parameters
        ----------
        snapshot : dict
            The mapping returned by :meth:`snapshot`.

        ES_CONTROL is written 0 and left there, so the sampler stays stopped; a
        saved RUN bit is never restored. The enables are never touched. Waits
        here ignore any abort request so a stopped scan still leaves the
        registers as it found them.

        Every step is attempted whatever an earlier step did: the idle wait, each
        scalar role in ``_RESTORE_ROLES`` order, then each word of the mask
        arrays. A step that fails does not skip the later writes.

        Raises
        ------
        Exception
            The first exception any step raised, after the last write was tried.
        """
        first = None

        def attempt(step: Callable[[], Any]) -> None:
            nonlocal first
            try:
                step()
            except Exception as exc:
                if first is None:
                    first = exc

        def stop() -> None:
            self.write('control', 0)
            self.waitIdle()

        attempt(stop)
        for role in _RESTORE_ROLES:
            attempt(lambda role=role: self.write(role, snapshot[role]))
        for role in _ARRAY_ROLES:
            words = []

            def lookup(role=role, words=words) -> None:
                words.extend(self.words(role))

            attempt(lookup)
            for var, value in zip(words, snapshot[role]):
                attempt(lambda var=var, value=value: var.set(value))
        if first is not None:
            raise first
