#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

__all__ = ['WriteBlockedError', 'WriteGuardMixin']

class WriteBlockedError(Exception):
    """Raised by a pre-write listener to block a register write."""
    def __init__(self, path, msg='cannot write registers during acquisition'):
        self.path = path
        super().__init__(f'{path}: {msg}')


class WriteGuardMixin:
    """Device mixin that runs pre-write listeners before interactive register writes.

    Provides device-level pre-write listeners using only the stable
    Device.writeBlocks() funnel, so it depends on no optional rogue feature and works
    across rogue releases.

    Mechanism: an interactive ``RemoteVariable.set(write=True)`` routes through
    ``self._parent.writeBlocks(force=True, recurse=False, variable=self, ...)``. By
    overriding ``writeBlocks`` we run the registered listeners just before the
    transaction starts. A listener raises ``WriteBlockedError`` to abort the write.

    Behavior:
      * Only single interactive writes are guarded (``variable is not None``). Bulk
        writes (``variable is None``, from writeAll/setYaml/writeBlocks(recurse=True))
        are NOT guarded, since they do not route through the per-variable
        set()/setDisp()/post() path.
      * Posted writes (``RemoteCommand`` via ``cmd.post()``) and ``LocalVariable``
        writes bypass writeBlocks entirely, so they are inherently allowed. A
        non-whitelisted posted command issued mid-acquisition is therefore not blocked
        here; the acquisition start/stop commands are allowed either way, which is the
        behavior the guard exists to provide.

    Use as the first base class: ``class Foo(WriteGuardMixin, pr.Device)`` so that
    ``super().writeBlocks(...)`` resolves to ``pr.Device.writeBlocks``.
    """

    def addPreWriteListener(self, listener, stateVars=None):
        """Register a pre-write listener.

        Parameters
        ----------
        listener : callable
            Called as ``listener(path, value, state)`` immediately before an
            interactive write. ``path`` is the variable path, ``value`` is the staged
            write value, and ``state`` is a dict of ``{var.path: var.value()}`` for
            each variable in ``stateVars``. Raise ``WriteBlockedError`` to block.
        stateVars : list, optional
            Variables whose current values are captured into the ``state`` dict.
        """
        if not hasattr(self, '_preWriteListeners'):
            self._preWriteListeners = []
        self._preWriteListeners.append((listener, stateVars or []))

    def writeBlocks(self, *, variable=None, **kwargs):
        listeners = getattr(self, '_preWriteListeners', None)
        if variable is not None and listeners:
            value = variable.value()
            for listener, stateVars in listeners:
                state = {sv.path: sv.value() for sv in stateVars}
                listener(variable.path, value, state)
        super().writeBlocks(variable=variable, **kwargs)
