#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
"""Frozen-ABI parity tests for the relocated RoCEv2 metadata-bus codec.

These assert that surf's ported ``_RoCEv2Protocol`` produces bit-identical
TX integers and extracts identical RX fields versus the hardware-proven rogue
``pyrogue.protocols._RoCEv2`` originals (the 303-bit MetaDataTx / 276-bit
MetaDataRx wire format is frozen — the existing FPGA bitstream is reused).

Requires the rogue dev checkout on PYTHONPATH (source setup_rogue.sh).
"""

import random

import pytest

# rogue source-of-truth (snake_case originals)
rogue_mod = pytest.importorskip("pyrogue.protocols._RoCEv2")

# surf port under test (camelCase)
import surf.ethernet.roce._RoCEv2Protocol as p  # noqa: E402


def test_decode_resp_type_offset():
    assert p._decodeRespType(1 << 274) == 1
    for rx in (0, 1 << 274, 2 << 274, 3 << 274, (1 << 276) - 1):
        assert p._decodeRespType(rx) == rogue_mod._decode_resp_type(rx)


def test_mkbus_bustype_placement():
    bus = p._mkBus(p.RoCEv2BusType.PD, (1, 1), (0xDEADBEEF, 32), (0, 32))
    assert (bus >> 301) == 0  # PD == 0 at bits [302:301]


def test_alloc_pd_parity():
    for pd_key in (0, 1, 0xDEADBEEF, (1 << 32) - 1, 0x12345678):
        assert p._encodeAllocPd(pd_key) == rogue_mod._encode_alloc_pd(pd_key)


def test_alloc_mr_parity():
    rng = random.Random(1234)
    for _ in range(8):
        args = dict(
            pd_handler=rng.getrandbits(32),
            laddr=rng.getrandbits(64),
            length=rng.getrandbits(32),
            lkey_part=rng.getrandbits(31),
            rkey_part=rng.getrandbits(31),
        )
        got = p._encodeAllocMr(args["pd_handler"], args["laddr"], args["length"],
                               args["lkey_part"], args["rkey_part"])
        exp = rogue_mod._encode_alloc_mr(**args)
        assert got == exp


def test_create_qp_parity():
    for pd_handler in (0, 1, 0xABCDEF01, (1 << 32) - 1):
        assert p._encodeCreateQp(pd_handler) == rogue_mod._encode_create_qp(pd_handler)


def test_modify_qp_parity():
    rng = random.Random(99)
    for _ in range(8):
        qpn = rng.getrandbits(24)
        attr_mask = rng.getrandbits(26)
        qp_state = rng.choice([0, 1, 2, 3, 6])
        pmtu = rng.choice([1, 2, 3, 4, 5])
        dqpn = rng.getrandbits(24)
        rq_psn = rng.getrandbits(24)
        sq_psn = rng.getrandbits(24)
        got = p._encodeModifyQp(qpn, attr_mask, qp_state, pmtu,
                                dqpn=dqpn, rqPsn=rq_psn, sqPsn=sq_psn)
        exp = rogue_mod._encode_modify_qp(qpn, attr_mask, qp_state, pmtu,
                                          dqpn=dqpn, rq_psn=rq_psn, sq_psn=sq_psn)
        assert got == exp


def test_dealloc_err_destroy_parity():
    rng = random.Random(7)
    for _ in range(8):
        pd_handler = rng.getrandbits(32)
        lkey = rng.getrandbits(32)
        rkey = rng.getrandbits(32)
        qpn = rng.getrandbits(24)
        assert p._encodeDeallocMr(pd_handler, lkey, rkey) == \
            rogue_mod._encode_dealloc_mr(pd_handler, lkey, rkey)
        assert p._encodeDeallocPd(pd_handler) == rogue_mod._encode_dealloc_pd(pd_handler)
        assert p._encodeErrQp(qpn) == rogue_mod._encode_err_qp(qpn)
        assert p._encodeDestroyQp(qpn) == rogue_mod._encode_destroy_qp(qpn)


def test_decode_resp_parity():
    rng = random.Random(42)
    for _ in range(16):
        rx = rng.getrandbits(276)
        assert p._decodePdResp(rx) == rogue_mod._decode_pd_resp(rx)
        assert p._decodeMrResp(rx) == rogue_mod._decode_mr_resp(rx)
        assert p._decodeQpResp(rx) == rogue_mod._decode_qp_resp(rx)


def test_decode_qp_resp_known_offsets():
    # qpn at bit 249 width 24, qpState at bit 213 width 4, success at bit 273
    rx = (1 << 273) | (0xABCDEF << 249) | (0x3 << 213)
    success, qpn, qp_state = p._decodeQpResp(rx)
    assert success is True
    assert qpn == 0xABCDEF
    assert qp_state == 0x3


def test_mkbus_overflow_raises():
    import rogue
    with pytest.raises(rogue.GeneralError):
        # 302 bits of payload leaves < 2 bits for the bus type
        p._mkBus(p.RoCEv2BusType.QP, (0, 302))


def test_fpga_params_result_type():
    # setupConnection() returns a named result object carrying the
    # FPGA-side params (fpgaQpn/lkey/pdHandler/rkey) in that field order.
    import surf.ethernet.roce as r
    params = r.RoCEv2FpgaParams(fpgaQpn=0x10, lkey=0x20, pdHandler=0x30, rkey=0x40)
    assert params.fpgaQpn   == 0x10
    assert params.lkey      == 0x20
    assert params.pdHandler == 0x30
    assert params.rkey      == 0x40
    if hasattr(r.RoCEv2FpgaParams, "_fields"):
        names = list(r.RoCEv2FpgaParams._fields)
    else:
        import dataclasses
        names = [f.name for f in dataclasses.fields(r.RoCEv2FpgaParams)]
    assert names == ["fpgaQpn", "lkey", "pdHandler", "rkey"]


def test_no_host_side_symbols():
    # Host-side / engine-method pieces must NOT be ported here.
    for forbidden in ("RoCEv2Server", "RoCEv2ServerCfg", "detectGidIndex",
                      "_roceSetupConnection", "_roceTeardown",
                      "_roce_setup_connection", "_roce_teardown"):
        assert not hasattr(p, forbidden), f"{forbidden} should not be in _RoCEv2Protocol"
