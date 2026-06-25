#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
"""Structure + frozen-ABI parity tests for RoCEv2Engine.setupConnection() /
teardownConnection().

The structure tests assert the engine API shape. The parity test
drives a mock engine (recording every MetaDataTx write and replaying canned
firmware responses) through setupConnection() and asserts the captured bus
integers are bit-identical to rogue's hardware-proven _roce_setup_connection
for the same inputs (the metadata-bus wire format is frozen).

Requires the rogue dev checkout on PYTHONPATH (source setup_rogue.sh).
"""

import inspect
import logging
import random

import pytest

# rogue source-of-truth (snake_case originals). importorskip MUST precede the
# `import rogue` below so this module skips cleanly on runners without rogue
# (e.g. surf CI) instead of erroring out during collection.
rogue_mod = pytest.importorskip("pyrogue.protocols._RoCEv2")

import rogue                                          # noqa: E402
import surf.ethernet.roce as r                       # noqa: E402
import surf.ethernet.roce._RoCEv2Protocol as proto   # noqa: E402


# ---------------------------------------------------------------------------
# Structure / API-shape tests
# ---------------------------------------------------------------------------

def test_engine_has_setup_teardown():
    src = inspect.getsource(r.RoCEv2Engine)
    assert 'def setupConnection' in src
    assert 'def teardownConnection' in src
    for attr in ('self._fpgaQpn', 'self._pdHandler', 'self._lkey', 'self._rkey'):
        assert attr in src, attr


def test_setup_signature_flat_kwargs():
    sig = inspect.signature(r.RoCEv2Engine.setupConnection)
    for p in ('hostQpn', 'hostRqPsn', 'hostSqPsn', 'mrAddr', 'mrLen', 'pmtu',
              'minRnrTimer', 'rnrRetry', 'retryCount'):
        assert p in sig.parameters, p


def test_teardown_signature_no_required_args():
    assert list(inspect.signature(r.RoCEv2Engine.teardownConnection).parameters) == ['self']


def test_shadow_state_not_tree_variables():
    # shadow state must be plain private attrs, not pyrogue tree vars.
    src = inspect.getsource(r.RoCEv2Engine)
    assert "name='FpgaQpn'" not in src and 'name="FpgaQpn"' not in src


# ---------------------------------------------------------------------------
# Mock engine — records TX writes, replays scripted firmware responses
# ---------------------------------------------------------------------------

class _Reg:
    def __init__(self, value=0):
        self._v = value

    def set(self, v):
        self._v = v

    def get(self):
        return self._v


class _MockEngine:
    """Minimal RoceEngine-compatible double for setup/teardown parity tests."""
    def __init__(self, responses):
        # A real pyrogue device always has a logger; mirror that so the
        # production setup/teardown logging path exercises cleanly.
        self._log = logging.getLogger("test.RoCEv2Engine")
        self.SendMetaData = _Reg(0)
        self.MetaDataTx   = _Reg(0)
        self.RecvMetaData = _Reg(1)
        self.MetaDataRx   = _Reg(0)
        self.txWrites     = []
        self._responses   = list(responses)
        self._softResets  = 0
        # Bind the engine methods onto this double so the production code
        # under test (the real setupConnection/teardownConnection) runs.
        self._fpgaQpn   = 0
        self._pdHandler = 0
        self._lkey      = 0
        self._rkey      = 0

    def SoftReset(self):
        self._softResets += 1

    def _captureTx(self):
        # _sendMeta writes 0, then the payload, then toggles SendMetaData.
        # MetaDataTx holds the payload at the point SendMetaData rises.
        self.txWrites.append(self.MetaDataTx.get())
        # Pop the next scripted response for the following _waitResp.
        self.MetaDataRx.set(self._responses.pop(0))


def _make_setup_caller(method, responses):
    """Build a mock engine whose MetaDataTx.set records every payload and
    advances the canned response queue, then return a zero-arg callable that
    runs `method` (setupConnection / teardownConnection) bound to it."""
    eng = _MockEngine(responses)

    real_set = eng.MetaDataTx.set
    def recording_set(v):
        real_set(v)
    eng.MetaDataTx.set = recording_set

    # SendMetaData rising edge (set to 1) is where the FW would latch the bus
    # and produce a response; mirror that by capturing on the 0->1 of the
    # SendMetaData write performed by _sendMeta.
    sm_real = eng.SendMetaData.set
    def sm_set(v):
        prev = eng.SendMetaData.get()
        sm_real(v)
        if prev == 0 and v == 1:
            eng._captureTx()
    eng.SendMetaData.set = sm_set
    return eng


# Response builders (mirror the RX layout the decoders read).
def _pdResp(ok, pdHandler):
    rx = (proto.RoCEv2BusType.PD << 274)
    rx |= (1 if ok else 0) << (proto.RoCEv2FieldW.PD_KEY + proto.RoCEv2FieldW.PD_HANDLER)
    rx |= (pdHandler & 0xFFFFFFFF) << proto.RoCEv2FieldW.PD_KEY
    return rx


def _mrResp(ok, lkey, rkey):
    success_bit = (proto.RoCEv2FieldW.MR_KEY * 2 + proto.RoCEv2FieldW.MR_RKEYPART +
                   proto.RoCEv2FieldW.MR_LKEYPART + proto.RoCEv2FieldW.MR_PDHANDLER +
                   proto.RoCEv2FieldW.MR_ACCFLAGS + proto.RoCEv2FieldW.MR_LEN +
                   proto.RoCEv2FieldW.MR_LADDR)
    rx = (proto.RoCEv2BusType.MR << 274)
    rx |= (1 if ok else 0) << success_bit
    rx |= (lkey & 0xFFFFFFFF) << proto.RoCEv2FieldW.MR_KEY
    rx |= (rkey & 0xFFFFFFFF)
    return rx


def _qpResp(ok, qpn, state):
    rx = (proto.RoCEv2BusType.QP << 274)
    rx |= (1 if ok else 0) << 273
    rx |= (qpn & 0xFFFFFF) << 249
    rx |= (state & 0xF) << 213
    return rx


_INPUTS = dict(hostQpn=0x123456, hostRqPsn=0xABCDEF, hostSqPsn=0x0F0F0F,
               mrAddr=0xDEADBEEFCAFE, mrLen=0x40000, pmtu=4,
               minRnrTimer=1, rnrRetry=7, retryCount=3)


def _scripted_responses():
    return [
        _pdResp(True, 0xAABBCCDD),
        _mrResp(True, 0x11112222, 0x33334444),
        _qpResp(True, 0x010203, proto.RoCEv2QpState.RESET),
        _qpResp(True, 0x010203, proto.RoCEv2QpState.INIT),
        _qpResp(True, 0x010203, proto.RoCEv2QpState.RTR),
        _qpResp(True, 0x010203, proto.RoCEv2QpState.RTS),
    ]


def test_setup_returns_fpga_params_and_shadow_state():
    eng = _make_setup_caller(None, _scripted_responses())
    random.seed(0xC0FFEE)
    result = r.RoCEv2Engine.setupConnection(eng, **_INPUTS)
    assert isinstance(result, proto.RoCEv2FpgaParams)
    assert result.fpgaQpn   == 0x010203
    assert result.lkey      == 0x11112222
    assert result.pdHandler == 0xAABBCCDD
    assert result.rkey      == 0x33334444
    # Shadow state set on the device after resources go live.
    assert eng._fpgaQpn   == 0x010203
    assert eng._pdHandler == 0xAABBCCDD
    assert eng._lkey      == 0x11112222
    assert eng._rkey      == 0x33334444
    # SoftReset stale-clear pulsed before allocation.
    assert eng._softResets == 1


def test_setup_tx_parity_with_rogue():
    # Drive the surf engine method and rogue's original through identical
    # inputs + identical RNG seed; the captured MetaDataTx integers must match.
    seed = 0x12345
    eng = _make_setup_caller(None, _scripted_responses())
    random.seed(seed)
    r.RoCEv2Engine.setupConnection(eng, **_INPUTS)
    surf_writes = list(eng.txWrites)

    rogue_eng = _make_setup_caller(None, _scripted_responses())
    random.seed(seed)
    rogue_mod._roce_setup_connection(
        rogue_eng,
        host_qpn      = _INPUTS['hostQpn'],
        host_rq_psn   = _INPUTS['hostRqPsn'],
        host_sq_psn   = _INPUTS['hostSqPsn'],
        mr_laddr      = _INPUTS['mrAddr'],
        mr_len        = _INPUTS['mrLen'],
        pmtu          = _INPUTS['pmtu'],
        min_rnr_timer = _INPUTS['minRnrTimer'],
        rnr_retry     = _INPUTS['rnrRetry'],
        retry_count   = _INPUTS['retryCount'],
    )
    rogue_writes = list(rogue_eng.txWrites)
    assert surf_writes == rogue_writes
    assert len(surf_writes) == 6  # PD, MR, QP create, INIT, RTR, RTS


# ---------------------------------------------------------------------------
# Up-front input validation (CR-01 / CR-02): out-of-range mrLen / QPN / PSN
# must be rejected before any bus traffic (so nothing is allocated), and an
# invalid pmtu must be rejected before it can KeyError after the QP is live.
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("override", [
    dict(mrLen=1 << proto.RoCEv2FieldW.MR_LEN),
    dict(mrLen=-1),
    dict(hostQpn=1 << proto.RoCEv2FieldW.QPA_DQPN),
    dict(hostRqPsn=1 << proto.RoCEv2FieldW.QPA_RQPSN),
    dict(hostSqPsn=1 << proto.RoCEv2FieldW.QPA_SQPSN),
    dict(pmtu=0),
    dict(pmtu=6),
    dict(pmtu=4096),
])
def test_setup_rejects_out_of_range_args(override):
    eng = _make_setup_caller(None, _scripted_responses())
    bad = {**_INPUTS, **override}
    with pytest.raises(rogue.GeneralError):
        r.RoCEv2Engine.setupConnection(eng, **bad)
    # Guard runs before any bus traffic / SoftReset — nothing allocated.
    assert eng.txWrites == []
    assert eng._softResets == 0
    assert eng._fpgaQpn == 0 and eng._pdHandler == 0


def test_setup_accepts_max_in_range_args():
    # Boundary: largest value that still fits each field must NOT be rejected.
    eng = _make_setup_caller(None, _scripted_responses())
    random.seed(0xBADC0DE)
    bad = {**_INPUTS,
           'mrLen':     (1 << proto.RoCEv2FieldW.MR_LEN) - 1,
           'hostQpn':   (1 << proto.RoCEv2FieldW.QPA_DQPN) - 1,
           'hostRqPsn': (1 << proto.RoCEv2FieldW.QPA_RQPSN) - 1,
           'hostSqPsn': (1 << proto.RoCEv2FieldW.QPA_SQPSN) - 1}
    result = r.RoCEv2Engine.setupConnection(eng, **bad)
    assert isinstance(result, proto.RoCEv2FpgaParams)


def test_teardown_noop_when_no_qp():
    eng = _make_setup_caller(None, [])
    eng._fpgaQpn = 0
    r.RoCEv2Engine.teardownConnection(eng)
    assert eng.txWrites == []   # no metadata-bus writes


def test_teardown_after_setup_frees_and_resets():
    eng = _make_setup_caller(None, _scripted_responses())
    random.seed(1)
    r.RoCEv2Engine.setupConnection(eng, **_INPUTS)
    eng.txWrites.clear()
    # Teardown replays ERR, DESTROY, MR dealloc, PD dealloc.
    eng._responses = [
        _qpResp(True, 0x010203, proto.RoCEv2QpState.ERR),
        _qpResp(True, 0x010203, proto.RoCEv2QpState.RESET),
        _mrResp(True, 0x11112222, 0x33334444),
        _pdResp(True, 0xAABBCCDD),
    ]
    r.RoCEv2Engine.teardownConnection(eng)
    assert len(eng.txWrites) == 4
    assert eng._fpgaQpn == 0 and eng._pdHandler == 0
    assert eng._lkey == 0 and eng._rkey == 0


def test_teardown_tx_parity_with_rogue():
    seed = 0x999
    eng = _make_setup_caller(None, _scripted_responses())
    random.seed(seed)
    r.RoCEv2Engine.setupConnection(eng, **_INPUTS)
    eng.txWrites.clear()
    eng._responses = [
        _qpResp(True, 0x010203, proto.RoCEv2QpState.ERR),
        _qpResp(True, 0x010203, proto.RoCEv2QpState.RESET),
        _mrResp(True, 0x11112222, 0x33334444),
        _pdResp(True, 0xAABBCCDD),
    ]
    r.RoCEv2Engine.teardownConnection(eng)
    surf_writes = list(eng.txWrites)

    rogue_eng = _make_setup_caller(None, [])
    rogue_eng._responses = [
        _qpResp(True, 0x010203, proto.RoCEv2QpState.ERR),
        _qpResp(True, 0x010203, proto.RoCEv2QpState.RESET),
        _mrResp(True, 0x11112222, 0x33334444),
        _pdResp(True, 0xAABBCCDD),
    ]
    rogue_mod._roce_teardown(rogue_eng, 0x010203,
                             pd_handler=0xAABBCCDD, lkey=0x11112222, rkey=0x33334444)
    assert surf_writes == list(rogue_eng.txWrites)
