#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
# Description:
#   RoCEv2 metadata-bus protocol layer.  Holds the enums, field-width tables,
#   bus builder, TX encoders, RX decoders and metadata-bus transport helpers
#   that drive the FPGA-side RoCEv2 engine (RoCEv2Engine) through its
#   SendMetaData / MetaDataTx / RecvMetaData / MetaDataRx registers.
#
#   This codec was relocated from rogue's pyrogue.protocols._RoCEv2 and
#   re-styled to surf/pyrogue camelCase.  The 303-bit MetaDataTx / 276-bit
#   MetaDataRx wire format and every field width are FROZEN — the existing FPGA
#   bitstream is reused, so any encoding drift breaks hardware.  The host-side
#   ibverbs pieces (RoCEv2Server, RoCEv2ServerCfg, GID detection) intentionally
#   stay in rogue; the engine setup/teardown methods live on RoCEv2Engine.
#-----------------------------------------------------------------------------
from __future__ import annotations

import enum
import time as _time
import typing

import rogue


# ---------------------------------------------------------------------------
# Public result type — the FPGA-side params the host server needs to call
# completeConnection(). Returned by RoCEv2Engine.setupConnection().
# ---------------------------------------------------------------------------

class RoCEv2FpgaParams(typing.NamedTuple):
    """FPGA-side params produced by setupConnection() for the host hand-off."""
    fpgaQpn:   int
    lkey:      int
    pdHandler: int
    rkey:      int


# ---------------------------------------------------------------------------
# Constants — must match BSVSettings.py / BusStructs.py in the firmware repo.
# Grouped into IntEnum / IntFlag / namespace classes; values are bit-identical
# to the firmware structs.  IntEnum/IntFlag members are int subclasses, so all
# the bitwise bus arithmetic (<<, >>, &, |) below operates on them directly.
# ---------------------------------------------------------------------------

class RoCEv2BusType(enum.IntEnum):
    """Metadata bus type tags (2-bit busType field)."""
    PD = 0
    MR = 1
    QP = 2


class RoCEv2ReqQp(enum.IntEnum):
    """QP request types."""
    CREATE  = 0
    DESTROY = 1
    MODIFY  = 2
    QUERY   = 3   # kept for completeness, not currently used


class RoCEv2Mtu(enum.IntEnum):
    """Path MTU codes (libibverbs ibv_mtu enum)."""
    MTU_256  = 1
    MTU_512  = 2
    MTU_1024 = 3
    MTU_2048 = 4
    MTU_4096 = 5


# Path MTU code -> payload size in bytes.
_PMTU_BYTES = {
    RoCEv2Mtu.MTU_256:  256,
    RoCEv2Mtu.MTU_512:  512,
    RoCEv2Mtu.MTU_1024: 1024,
    RoCEv2Mtu.MTU_2048: 2048,
    RoCEv2Mtu.MTU_4096: 4096,
}

class RoCEv2RnrTimer(enum.IntEnum):
    """IB-spec Min RNR NAK Timer Field codes (IBA Vol1 Table 45).  Member
    name encodes the RNR wait in milliseconds; code 0 is the special
    655.36ms slot."""
    MS_655_36 = 0
    MS_0_01   = 1
    MS_0_02   = 2
    MS_0_03   = 3
    MS_0_04   = 4
    MS_0_06   = 5
    MS_0_08   = 6
    MS_0_12   = 7
    MS_0_16   = 8
    MS_0_24   = 9
    MS_0_32   = 10
    MS_0_48   = 11
    MS_0_64   = 12
    MS_0_96   = 13
    MS_1_28   = 14
    MS_1_92   = 15
    MS_2_56   = 16
    MS_3_84   = 17
    MS_5_12   = 18
    MS_7_68   = 19
    MS_10_24  = 20
    MS_15_36  = 21
    MS_20_48  = 22
    MS_30_72  = 23
    MS_40_96  = 24
    MS_61_44  = 25
    MS_81_92  = 26
    MS_122_88 = 27
    MS_163_84 = 28
    MS_245_76 = 29
    MS_327_68 = 30
    MS_491_52 = 31


# RNR timer code -> RNR wait in milliseconds.
_MIN_RNR_TIMER_MS = {
    RoCEv2RnrTimer.MS_655_36: 655.36, RoCEv2RnrTimer.MS_0_01:    0.01,
    RoCEv2RnrTimer.MS_0_02:     0.02, RoCEv2RnrTimer.MS_0_03:    0.03,
    RoCEv2RnrTimer.MS_0_04:     0.04, RoCEv2RnrTimer.MS_0_06:    0.06,
    RoCEv2RnrTimer.MS_0_08:     0.08, RoCEv2RnrTimer.MS_0_12:    0.12,
    RoCEv2RnrTimer.MS_0_16:     0.16, RoCEv2RnrTimer.MS_0_24:    0.24,
    RoCEv2RnrTimer.MS_0_32:     0.32, RoCEv2RnrTimer.MS_0_48:    0.48,
    RoCEv2RnrTimer.MS_0_64:     0.64, RoCEv2RnrTimer.MS_0_96:    0.96,
    RoCEv2RnrTimer.MS_1_28:     1.28, RoCEv2RnrTimer.MS_1_92:    1.92,
    RoCEv2RnrTimer.MS_2_56:     2.56, RoCEv2RnrTimer.MS_3_84:    3.84,
    RoCEv2RnrTimer.MS_5_12:     5.12, RoCEv2RnrTimer.MS_7_68:    7.68,
    RoCEv2RnrTimer.MS_10_24:   10.24, RoCEv2RnrTimer.MS_15_36:  15.36,
    RoCEv2RnrTimer.MS_20_48:   20.48, RoCEv2RnrTimer.MS_30_72:  30.72,
    RoCEv2RnrTimer.MS_40_96:   40.96, RoCEv2RnrTimer.MS_61_44:  61.44,
    RoCEv2RnrTimer.MS_81_92:   81.92, RoCEv2RnrTimer.MS_122_88: 122.88,
    RoCEv2RnrTimer.MS_163_84: 163.84, RoCEv2RnrTimer.MS_245_76: 245.76,
    RoCEv2RnrTimer.MS_327_68: 327.68, RoCEv2RnrTimer.MS_491_52: 491.52,
}


class RoCEv2QpType(enum.IntEnum):
    """QP transport types."""
    RC = 2


class RoCEv2QpState(enum.IntEnum):
    """QP states (ibv_qp_state)."""
    RESET  = 0
    INIT   = 1
    RTR    = 2
    RTS    = 3
    SQD    = 4
    ERR    = 6
    CREATE = 8


class RoCEv2QpAttrMask(enum.IntFlag):
    """QP attribute mask bits (ibv_qp_attr_mask)."""
    STATE              = 1
    ACCESS_FLAGS       = 8
    PKEY_INDEX         = 16
    PATH_MTU           = 256
    TIMEOUT            = 512
    RETRY_CNT          = 1024
    RNR_RETRY          = 2048
    RQ_PSN             = 4096
    MAX_QP_RD_ATOMIC   = 8192
    MIN_RNR_TIMER      = 32768
    SQ_PSN             = 65536
    MAX_DEST_RD_ATOMIC = 131072
    DEST_QPN           = 1048576


class RoCEv2BusBits:
    """Total metadata bus widths."""
    TX = 303
    RX = 276   # informational only; actual bus may be shorter


class RoCEv2FieldW:
    """Metadata-bus field widths — derived from BSVSettings.py with
    MAX_PD=1, MAX_MR=2."""
    PD_ALLOC_OR_NOT = 1
    PD_INDEX        = 0    # int(log2(MAX_PD=1)) = 0
    PD_HANDLER      = 32
    PD_KEY          = 32   # PD_HANDLER - PD_INDEX = 32

    MR_ALLOC_OR_NOT = 1
    MR_INDEX        = 1    # int(log2(MAX_MR/MAX_PD = 2)) = 1
    MR_LADDR        = 64
    MR_LEN          = 32
    MR_ACCFLAGS     = 8
    MR_PDHANDLER    = 32
    MR_KEY          = 32
    MR_LKEYPART     = 31   # MR_KEY - MR_INDEX = 31
    MR_RKEYPART     = 31   # MR_KEY - MR_INDEX = 31
    MR_LKEYORNOT    = 1

    QPI_TYPE        = 4
    QPI_SQSIGALL    = 1

    QPA_QPSTATE     = 4
    QPA_CURRQPSTATE = 4
    QPA_PMTU        = 3
    QPA_QKEY        = 32
    QPA_RQPSN       = 24
    QPA_SQPSN       = 24
    QPA_DQPN        = 24
    QPA_QPACCFLAGS  = 8
    QPA_CAP         = 40
    QPA_PKEY        = 16
    QPA_SQDRAINING  = 1
    QPA_MAXREADATOMIC = 8
    QPA_MAXDESTRD     = 8
    QPA_RNRTIMER    = 5
    QPA_TIMEOUT     = 5
    QPA_RETRYCNT    = 3
    QPA_RNRRETRY    = 3

    QP_REQTYPE      = 2
    QP_PDHANDLER    = 32
    QP_QPN          = 24
    QP_ATTRMASK     = 26


class RoCEv2QpDefaults:
    """Default QP tuning values."""
    ACC_PERM       = 0x0F   # local_write | remote_write | remote_read | remote_atomic
    RETRY_NUM      = 3
    RNR_TIMER      = 1
    TIMEOUT        = 14
    MAX_QP_RD_ATOM = 16
    CAP_VALUE      = 0x2020010100   # from Utils4Test.bsv


# QPA field widths in reqQp.getBus() order — single source of truth shared by
# the CREATE / MODIFY / DESTROY encoders so the three field sequences can never
# drift out of order relative to each other or to the firmware reqQp struct.
_QPA_FIELD_WIDTHS = (
    RoCEv2FieldW.QPA_QPSTATE, RoCEv2FieldW.QPA_CURRQPSTATE, RoCEv2FieldW.QPA_PMTU,
    RoCEv2FieldW.QPA_QKEY, RoCEv2FieldW.QPA_RQPSN, RoCEv2FieldW.QPA_SQPSN,
    RoCEv2FieldW.QPA_DQPN, RoCEv2FieldW.QPA_QPACCFLAGS, RoCEv2FieldW.QPA_CAP,
    RoCEv2FieldW.QPA_PKEY, RoCEv2FieldW.QPA_SQDRAINING, RoCEv2FieldW.QPA_MAXREADATOMIC,
    RoCEv2FieldW.QPA_MAXDESTRD, RoCEv2FieldW.QPA_RNRTIMER, RoCEv2FieldW.QPA_TIMEOUT,
    RoCEv2FieldW.QPA_RETRYCNT, RoCEv2FieldW.QPA_RNRRETRY,
)


# ---------------------------------------------------------------------------
# TX bus encoders — pure-int arithmetic, no external dependencies
#
# Pattern (mirrors BusStructs.py getBus() semantics):
#   Fields are concatenated LSB-aligned at bit 0 of the returned integer:
#   the last field's LSB lands at bit 0, the first field's MSB lands at
#   bit (used_bits-1).  Within this used region the first-listed field
#   is at the top and the last-listed field is at the bottom — i.e.
#   relative order is MSB-first within the used window, but the window
#   itself is NOT left-aligned in the 301-bit payload region; bits
#   [300:used_bits] are zero-padded.  The 2-bit bus type is written at
#   the TOP 2 bits (bits 302:301) of the 303-bit bus.  This matches the
#   FPGA BusStructs.py layout and the RX decoder offsets below (e.g.
#   _decodeRespType extracts (rx >> 274) & 0x3 from a 276-bit RX bus,
#   _decodePdResp reads successOrNot at bit 64, pd_handler at 63:32,
#   pd_key at 31:0 — same LSB-aligned-in-used-region convention).
# ---------------------------------------------------------------------------

def _mkBus(busType: int, *fields: tuple[int, int]) -> int:
    """Build a 303-bit TX metadata bus integer from (value, width) fields.

    Fields are concatenated LSB-aligned at bit 0 of the returned integer:
    the last field's LSB is at bit 0 and the first field's MSB is at bit
    ``used_bits-1``.  Within the used window the first-listed field sits
    at the top and the last-listed at the bottom (MSB-first ordering),
    but the window itself is right-aligned at bit 0 — bits
    ``[300:used_bits]`` are zero-padded, not occupied by a shifted
    payload.  The 2-bit bus type is written at the TOP 2 bits
    (bits 302:301) of the 303-bit bus, matching the FPGA BusStructs.py
    layout and the RX-side ``_decode*`` helpers, which all read fields
    at fixed offsets counted from bit 0 (e.g. ``_decodeRespType``
    extracts ``(rx >> 274) & 0x3`` from a 276-bit RX bus).
    """
    acc = 0
    used_bits = 0
    for value, width in fields:
        mask = (1 << width) - 1
        acc = (acc << width) | (int(value) & mask)
        used_bits += width

    if RoCEv2BusBits.TX - used_bits < 2:
        raise rogue.GeneralError(
            "_mkBus",
            f"Bus type cannot fit: fields consume {used_bits} of "
            f"{RoCEv2BusBits.TX} bits, need 2 reserved for bus type")

    # Low `used_bits` bits hold the meta payload; bus type at [302:301].
    full = acc | ((busType & 0x3) << (RoCEv2BusBits.TX - 2))
    return full


def _encodeAllocPd(pdKey):
    """reqPd.getBus(): allocOrNot(1) + pdKey(32) + pdHandler(32)"""
    return _mkBus(RoCEv2BusType.PD,
        (1,     RoCEv2FieldW.PD_ALLOC_OR_NOT),
        (pdKey, RoCEv2FieldW.PD_KEY),
        (0,     RoCEv2FieldW.PD_HANDLER),    # pdHandler don't-care in request
    )


def _encodeAllocMr(pdHandler, laddr, length, lkeyPart, rkeyPart):
    """reqMr.getBus(): allocOrNot + mrLAddr + mrLen + mrAccFlags + mrPdHandler
                       + mrLKeyPart + mrRKeyPart + lKeyOrNot + lKey + rKey"""
    return _mkBus(RoCEv2BusType.MR,
        (1,                  RoCEv2FieldW.MR_ALLOC_OR_NOT),
        (laddr,              RoCEv2FieldW.MR_LADDR),
        (length,             RoCEv2FieldW.MR_LEN),
        (RoCEv2QpDefaults.ACC_PERM, RoCEv2FieldW.MR_ACCFLAGS),
        (pdHandler,          RoCEv2FieldW.MR_PDHANDLER),
        (lkeyPart,           RoCEv2FieldW.MR_LKEYPART),
        (rkeyPart,           RoCEv2FieldW.MR_RKEYPART),
        (0,                  RoCEv2FieldW.MR_LKEYORNOT),
        (0,                  RoCEv2FieldW.MR_KEY),    # lKey don't-care
        (0,                  RoCEv2FieldW.MR_KEY),    # rKey don't-care
    )


def _encodeCreateQp(pdHandler):
    """reqQp.getBus() for CREATE: all QPA fields + qpiType + qpiSqSigAll"""
    fields = [
        (RoCEv2ReqQp.CREATE, RoCEv2FieldW.QP_REQTYPE),
        (pdHandler,    RoCEv2FieldW.QP_PDHANDLER),
        (0,            RoCEv2FieldW.QP_QPN),
        (0,            RoCEv2FieldW.QP_ATTRMASK),
    ]
    # All QPA fields don't-care for CREATE
    fields.extend((0, w) for w in _QPA_FIELD_WIDTHS)
    fields.append((RoCEv2QpType.RC, RoCEv2FieldW.QPI_TYPE))
    fields.append((0,         RoCEv2FieldW.QPI_SQSIGALL))
    return _mkBus(RoCEv2BusType.QP, *fields)


def _encodeModifyQp(qpn, attrMask, qpState, pmtu,
                    dqpn=0, rqPsn=0, sqPsn=0,
                    minRnrTimer=RoCEv2QpDefaults.RNR_TIMER,
                    rnrRetry=RoCEv2QpDefaults.RETRY_NUM,
                    retryCount=RoCEv2QpDefaults.RETRY_NUM):
    """reqQp.getBus() for MODIFY — same field order as CREATE."""
    fields = [
        (RoCEv2ReqQp.MODIFY, RoCEv2FieldW.QP_REQTYPE),
        (0,            RoCEv2FieldW.QP_PDHANDLER),
        (qpn,          RoCEv2FieldW.QP_QPN),
        (attrMask,     RoCEv2FieldW.QP_ATTRMASK),
    ]
    # QPA field values in reqQp.getBus() order, paired with the shared
    # _QPA_FIELD_WIDTHS (strict=True fails loudly if the two ever diverge).
    qpaValues = [
        qpState,
        0,                                # currQpState (don't-care)
        pmtu,
        0,                                # qKey (don't-care)
        rqPsn,
        sqPsn,
        dqpn,
        0x0E,                             # qpAccFlags
        RoCEv2QpDefaults.CAP_VALUE,
        0xFFFF,                           # pKey
        0,                                # sqDraining (don't-care)
        RoCEv2QpDefaults.MAX_QP_RD_ATOM,  # maxReadAtomic
        RoCEv2QpDefaults.MAX_QP_RD_ATOM,  # maxDestRd
        minRnrTimer,
        RoCEv2QpDefaults.TIMEOUT,
        retryCount,
        rnrRetry,
    ]
    fields.extend((int(v), w)
                  for v, w in zip(qpaValues, _QPA_FIELD_WIDTHS, strict=True))
    fields.append((RoCEv2QpType.RC, RoCEv2FieldW.QPI_TYPE))
    fields.append((0,         RoCEv2FieldW.QPI_SQSIGALL))
    return _mkBus(RoCEv2BusType.QP, *fields)


# ---------------------------------------------------------------------------
# RX bus decoders — mirror BusStructs.py slice_vec / get_bool exactly
#
# Convention: bit 0 = LSB of the response integer.
# Fields extracted as: (rx >> lsb) & ((1 << width) - 1)
#
# respPd layout (from BusStructs.py):
#   bits [PD_KEY_B-1 : 0]                = pdKey      [31:0]
#   bits [PD_KEY_B+PD_HANDLER_B-1 : 32]  = pdHandler  [63:32]
#   bit  [PD_KEY_B+PD_HANDLER_B]         = successOrNot  bit 64
#   bits [275:274]                        = busType
#
# respMr layout:
#   bits [31:0]   = rKey
#   bits [63:32]  = lKey
#   ...more fields...
#   bit  [success_bit]  = successOrNot
#   bits [275:274]      = busType
#
# respQp layout:
#   bit  273      = successOrNot
#   bits [272:249] = qpn
#   bits [216:213] = qpaQpState
#   bits [275:274] = busType
# ---------------------------------------------------------------------------

def _decodeRespType(rx):
    """Extract busType from bits [275:274] (LSB convention)."""
    return (rx >> 274) & 0x3


def _decodePdResp(rx):
    """
    Decode PD allocation response.
    Returns (success: bool, pdHandler: int).
    """
    success   = bool((rx >> (RoCEv2FieldW.PD_KEY + RoCEv2FieldW.PD_HANDLER)) & 1)
    pdHandler = (rx >> RoCEv2FieldW.PD_KEY) & ((1 << RoCEv2FieldW.PD_HANDLER) - 1)
    return success, pdHandler


def _decodeMrResp(rx):
    """
    Decode MR allocation response.
    Returns (success: bool, lkey: int, rkey: int).
    From respMr.__init__: rKey at [31:0], lKey at [63:32].
    """
    success_bit = (RoCEv2FieldW.MR_KEY + RoCEv2FieldW.MR_KEY + RoCEv2FieldW.MR_RKEYPART + RoCEv2FieldW.MR_LKEYPART +
                   RoCEv2FieldW.MR_PDHANDLER + RoCEv2FieldW.MR_ACCFLAGS + RoCEv2FieldW.MR_LEN + RoCEv2FieldW.MR_LADDR)
    success = bool((rx >> success_bit) & 1)
    rkey    = rx & ((1 << RoCEv2FieldW.MR_KEY) - 1)
    lkey    = (rx >> RoCEv2FieldW.MR_KEY) & ((1 << RoCEv2FieldW.MR_KEY) - 1)
    return success, lkey, rkey


def _decodeQpResp(rx):
    """
    Decode QP create/modify response.
    Returns (success: bool, qpn: int, qpState: int).
    From respQp.__init__: successOrNot at bit 273, qpn at [272:249],
    qpaQpState at [216:213].
    """
    success = bool((rx >> 273) & 1)
    qpn     = (rx >> 249) & ((1 << 24) - 1)
    qpState = (rx >> 213) & 0xF
    return success, qpn, qpState


# ---------------------------------------------------------------------------
# Metadata bus transport helpers
# ---------------------------------------------------------------------------

def _sendMeta(engine, busValue):
    """
    Send a metadata bus message via any RoceEngine-compatible object.

    The firmware triggers on the RISING EDGE of metaDataIsSet (0→1).
    Writing 0 first ensures a clean rising edge every time.
    """
    engine.SendMetaData.set(0)
    engine.MetaDataTx.set(busValue)
    engine.SendMetaData.set(1)
    engine.SendMetaData.set(0)


def _waitResp(engine, timeout_s=5.0):
    """
    Wait for firmware to process the request and return MetaDataRx value.

    The firmware clears metaDataIsReady on rising edge, sets it back when done.
    Processing takes microseconds so the 0 state may be too brief to observe.
    We briefly try to catch the 0, then wait for the 1.
    """
    deadline      = _time.monotonic() + timeout_s
    zero_deadline = _time.monotonic() + 0.02

    # Try briefly to observe RecvMetaData → 0 (firmware started). The 0 pulse
    # can be shorter than Python's polling resolution, so do not wait long here
    # when the response is already back to 1.
    while engine.RecvMetaData.get() != 0:
        if _time.monotonic() > zero_deadline:
            break
        _time.sleep(0.001)

    # Wait for RecvMetaData → 1 (response ready)
    while engine.RecvMetaData.get() != 1:
        if _time.monotonic() > deadline:
            raise rogue.GeneralError(
                '_waitResp',
                'Timeout waiting for RoceEngine response '
                '(RecvMetaData never went to 1)')
        _time.sleep(0.05)

    return engine.MetaDataRx.get()


# ---------------------------------------------------------------------------
# QP teardown / reconnect helpers
# ---------------------------------------------------------------------------

def _encodeDeallocMr(pdHandler, lkey, rkey):
    """Dealloc MR: allocOrNot=0, same field layout as alloc."""
    return _mkBus(RoCEv2BusType.MR,
        (0,         RoCEv2FieldW.MR_ALLOC_OR_NOT),  # allocOrNot=0
        (0,         RoCEv2FieldW.MR_LADDR),
        (0,         RoCEv2FieldW.MR_LEN),
        (0,         RoCEv2FieldW.MR_ACCFLAGS),
        (pdHandler, RoCEv2FieldW.MR_PDHANDLER),
        (0,         RoCEv2FieldW.MR_LKEYPART),
        (0,         RoCEv2FieldW.MR_RKEYPART),
        (0,         RoCEv2FieldW.MR_LKEYORNOT),
        (lkey,      RoCEv2FieldW.MR_KEY),
        (rkey,      RoCEv2FieldW.MR_KEY),
    )


def _encodeDeallocPd(pdHandler):
    """Dealloc PD: allocOrNot=0."""
    return _mkBus(RoCEv2BusType.PD,
        (0,         RoCEv2FieldW.PD_ALLOC_OR_NOT),  # allocOrNot=0
        (0,         RoCEv2FieldW.PD_KEY),
        (pdHandler, RoCEv2FieldW.PD_HANDLER),
    )


def _encodeErrQp(qpn):
    """REQ_QP_MODIFY → RoCEv2QpState.ERR — only RoCEv2QpAttrMask.STATE in attr mask."""
    return _encodeModifyQp(qpn, RoCEv2QpAttrMask.STATE, RoCEv2QpState.ERR, 1)


def _encodeDestroyQp(qpn):
    """REQ_QP_DESTROY — only valid from ERR state."""
    fields = [
        (RoCEv2ReqQp.DESTROY, RoCEv2FieldW.QP_REQTYPE),
        (0,             RoCEv2FieldW.QP_PDHANDLER),
        (qpn,           RoCEv2FieldW.QP_QPN),
        (0,             RoCEv2FieldW.QP_ATTRMASK),
    ]
    # All QPA + QPI fields don't-care (zeroed) for DESTROY.
    fields.extend((0, w) for w in _QPA_FIELD_WIDTHS)
    fields.append((0, RoCEv2FieldW.QPI_TYPE))
    fields.append((0, RoCEv2FieldW.QPI_SQSIGALL))
    return _mkBus(RoCEv2BusType.QP, *fields)


# ---------------------------------------------------------------------------
# Stale-resource error
# ---------------------------------------------------------------------------

def _staleResourceErr(stage):
    """GeneralError for an FPGA alloc/create step returning successOrNot=False
    — almost always stale resources from a prior session that crashed without a
    clean teardown.  ``stage`` names the failed step (e.g. 'PD allocation')."""
    return rogue.GeneralError(
        "setupConnection",
        f"FPGA {stage} failed — the FPGA RoCEv2 engine likely has stale "
        f"resources from a previous session that crashed without a clean "
        f"teardown. Reprogram the FPGA bitfile to reset its state.")
