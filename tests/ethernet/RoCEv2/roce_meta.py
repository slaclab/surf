##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
"""Self-contained RoCEv2 metadata-bus encoders/decoders for cocotb.

Pure-int reimplementation of the QP-bring-up encoding in
surf/python/surf/ethernet/roce/_RoCEv2Protocol.py (which pulls in `rogue` and
the pyrogue register tree). Field widths/offsets copied verbatim so the bus
layout matches the firmware RoceConfigurator + blue-rdma mkMetaDataSrv exactly.
"""

# ---- bus geometry ----
TX_BITS = 303
RX_BITS = 276

# ---- bus types ----
BUS_PD = 0
BUS_MR = 1
BUS_QP = 2

# ---- reqQp types (RoCEv2ReqQp — FROZEN, matches blue-rdma controller) ----
QP_CREATE  = 0
QP_DESTROY = 1
QP_MODIFY  = 2

# ---- QP states / type (RoCEv2QpState ibv_qp_state) ----
QPS_INIT = 1
QPS_RTR  = 2
QPS_RTS  = 3
QPS_ERR  = 6   # IBV_QPS_ERR
QPT_RC   = 2

# ---- attr-mask bits (RoCEv2QpAttrMask ibv_qp_attr_mask values) ----
M_STATE              = 1        # 1 << 0
M_ACCESS_FLAGS       = 8        # 1 << 3
M_PKEY_INDEX         = 16       # 1 << 4
M_PATH_MTU           = 256      # 1 << 8
M_TIMEOUT            = 512      # 1 << 9
M_RETRY_CNT          = 1024     # 1 << 10
M_RNR_RETRY          = 2048     # 1 << 11
M_RQ_PSN             = 4096     # 1 << 12
M_MAX_QP_RD_ATOMIC   = 8192     # 1 << 13
M_MIN_RNR_TIMER      = 32768    # 1 << 15
M_SQ_PSN             = 65536    # 1 << 16
M_MAX_DEST_RD_ATOMIC = 131072   # 1 << 17
M_DEST_QPN           = 1048576  # 1 << 20

# ---- field widths (RoCEv2FieldW, MAX_PD=1 MAX_MR=2) ----
PD_ALLOC_OR_NOT = 1
PD_HANDLER = 32
PD_KEY     = 32
MR_ALLOC_OR_NOT = 1
MR_LADDR = 64
MR_LEN = 32
MR_ACCFLAGS = 8
MR_PDHANDLER = 32
MR_KEY = 32
MR_LKEYPART = 31
MR_RKEYPART = 31
MR_LKEYORNOT = 1
QPI_TYPE = 4
QPI_SQSIGALL = 1
QPA_QPSTATE = 4
QPA_CURRQPSTATE = 4
QPA_PMTU = 3
QPA_QKEY = 32
QPA_RQPSN = 24
QPA_SQPSN = 24
QPA_DQPN = 24
QPA_QPACCFLAGS = 8
QPA_CAP = 40
QPA_PKEY = 16
QPA_SQDRAINING = 1
QPA_MAXREADATOMIC = 8
QPA_MAXDESTRD = 8
QPA_RNRTIMER = 5
QPA_TIMEOUT = 5
QPA_RETRYCNT = 3
QPA_RNRRETRY = 3
QP_REQTYPE = 2
QP_PDHANDLER = 32
QP_QPN = 24
QP_ATTRMASK = 26

ACC_PERM = 0x0F
CAP_VALUE = 0x2020010100
MAX_QP_RD_ATOM = 16
TIMEOUT_DEF = 14

_QPA_FIELD_WIDTHS = (
    QPA_QPSTATE, QPA_CURRQPSTATE, QPA_PMTU, QPA_QKEY, QPA_RQPSN, QPA_SQPSN,
    QPA_DQPN, QPA_QPACCFLAGS, QPA_CAP, QPA_PKEY, QPA_SQDRAINING,
    QPA_MAXREADATOMIC, QPA_MAXDESTRD, QPA_RNRTIMER, QPA_TIMEOUT,
    QPA_RETRYCNT, QPA_RNRRETRY,
)


def _mkBus(busType, *fields):
    acc = 0
    used = 0
    for value, width in fields:
        mask = (1 << width) - 1
        acc = (acc << width) | (int(value) & mask)
        used += width
    return acc | ((busType & 0x3) << (TX_BITS - 2))


def encode_alloc_pd(pdKey):
    return _mkBus(BUS_PD, (1, PD_ALLOC_OR_NOT), (pdKey, PD_KEY), (0, PD_HANDLER))


def encode_alloc_mr(pdHandler, laddr, length, lkeyPart, rkeyPart):
    return _mkBus(BUS_MR,
        (1, MR_ALLOC_OR_NOT), (laddr, MR_LADDR), (length, MR_LEN),
        (ACC_PERM, MR_ACCFLAGS), (pdHandler, MR_PDHANDLER),
        (lkeyPart, MR_LKEYPART), (rkeyPart, MR_RKEYPART),
        (0, MR_LKEYORNOT), (0, MR_KEY), (0, MR_KEY))


def encode_create_qp(pdHandler):
    fields = [(QP_CREATE, QP_REQTYPE), (pdHandler, QP_PDHANDLER), (0, QP_QPN), (0, QP_ATTRMASK)]
    fields += [(0, w) for w in _QPA_FIELD_WIDTHS]
    fields += [(QPT_RC, QPI_TYPE), (0, QPI_SQSIGALL)]
    return _mkBus(BUS_QP, *fields)


def encode_modify_qp(qpn, attrMask, qpState, pmtu, dqpn=0, rqPsn=0, sqPsn=0,
                     minRnrTimer=1, rnrRetry=3, retryCount=3):
    fields = [(QP_MODIFY, QP_REQTYPE), (0, QP_PDHANDLER), (qpn, QP_QPN), (attrMask, QP_ATTRMASK)]
    qpaValues = [qpState, 0, pmtu, 0, rqPsn, sqPsn, dqpn, 0x0E, CAP_VALUE, 0xFFFF,
                 0, MAX_QP_RD_ATOM, MAX_QP_RD_ATOM, minRnrTimer, TIMEOUT_DEF, retryCount, rnrRetry]
    fields += [(int(v), w) for v, w in zip(qpaValues, _QPA_FIELD_WIDTHS)]
    fields += [(QPT_RC, QPI_TYPE), (0, QPI_SQSIGALL)]
    return _mkBus(BUS_QP, *fields)


def decode_resp_type(rx):
    return (rx >> 274) & 0x3


def decode_pd_resp(rx):
    success = bool((rx >> (PD_KEY + PD_HANDLER)) & 1)
    pdHandler = (rx >> PD_KEY) & ((1 << PD_HANDLER) - 1)
    return success, pdHandler


def decode_mr_resp(rx):
    success_bit = (MR_KEY + MR_KEY + MR_RKEYPART + MR_LKEYPART + MR_PDHANDLER
                   + MR_ACCFLAGS + MR_LEN + MR_LADDR)
    success = bool((rx >> success_bit) & 1)
    rkey = rx & ((1 << MR_KEY) - 1)
    lkey = (rx >> MR_KEY) & ((1 << MR_KEY) - 1)
    return success, lkey, rkey


def decode_qp_resp(rx):
    success = bool((rx >> 273) & 1)
    qpn = (rx >> 249) & ((1 << 24) - 1)
    qpState = (rx >> 213) & 0xF
    return success, qpn, qpState
