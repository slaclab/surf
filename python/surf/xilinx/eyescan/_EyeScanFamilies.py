#-----------------------------------------------------------------------------
# Title      : Eye-scan transceiver families
#-----------------------------------------------------------------------------
# Description:
# Per-family descriptors (register roles, width tables, horizontal range) for
# the statistical eye scan. Families are keyed by string so no module needs to
# import the surf.xilinx package namespace.
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

from dataclasses import dataclass
from typing import Mapping

from surf.xilinx.eyescan._EyeScanTypes import EyeScanError

__all__ = [
    'PHASE_RULES',
    'EyeScanFamily',
    'GTHE3',
    'GTYE4',
    'FAMILIES',
    'UNSUPPORTED_FAMILIES',
    'getFamily',
]

# Phase-unification rules for bit 11 of ES_HORZ_OFFSET: 'sign' sets it for negative counts only,
# 'rate' sets it for every count when the line rate is above the family's rateThresholdGbps
PHASE_RULES = ('sign', 'rate')


@dataclass(frozen=True)
class EyeScanFamily:
    """Register roles and decode tables of one transceiver family.

    Parameters
    ----------
    name : str
        Family name, for example ``GTHE3``.
    hwVerified : bool
        True once the descriptor has been proven on hardware.
    regs : Mapping[str, str]
        Role to driver variable name.
    arrays : Mapping[str, tuple[str, int]]
        Role to (driver variable name, element count) for indexed variables.
        A name containing ``{}`` is formatted with each index 0 to count - 1
        to name one variable per word; a plain name is a list variable indexed
        0 to count - 1.
    busWidth : int
        Raw RX data bus width in bits.
    rxDataWidthCodes : Mapping[int, int]
        Raw RX_DATA_WIDTH code to width in bits.
    widthCombos : frozenset[tuple[int, int]]
        Allowed (RX_DATA_WIDTH bits, RX_INT_DATAWIDTH raw) pairs.
    rxOutDivCodes : Mapping[int, int]
        Raw RXOUT_DIV code to divider.
    horzBits : int
        Width of the horizontal offset field.
    countsPerHalfUiPerDiv : int
        Horizontal counts spanning half a UI at RXOUT_DIV of 1.
    phaseUnification : str
        Rule for the phase-unification bit (bit 11 of ES_HORZ_OFFSET), one of
        ``PHASE_RULES``. ``sign``: bit 11 is 1 only for negative counts;
        ``rate``: bit 11 is 1 for every count when the line rate is above
        ``rateThresholdGbps``.
    rateThresholdGbps : float
        Line rate above which the ``rate`` rule sets the phase-unification
        bit 11 of ES_HORZ_OFFSET; at or below it the bit is 0.
    vsCodeMax : int
        Largest vertical-offset code.
    defaultWidth : int
        Internal data width in bits that the scan time estimate assumes
        before a scan has read the lane.
    defaultDivider : int
        RXOUT_DIV divider that the scan time estimate assumes before a scan
        has read the lane.
    """

    name: str
    hwVerified: bool
    regs: Mapping[str, str]
    arrays: Mapping[str, tuple[str, int]]
    busWidth: int
    rxDataWidthCodes: Mapping[int, int]
    widthCombos: frozenset[tuple[int, int]]
    rxOutDivCodes: Mapping[int, int]
    horzBits: int
    countsPerHalfUiPerDiv: int
    phaseUnification: str
    rateThresholdGbps: float
    vsCodeMax: int
    defaultWidth: int
    defaultDivider: int


GTHE3 = EyeScanFamily(
    name                  = 'GTHE3',
    hwVerified            = True,
    regs                  = {
        'eyeScanEn':      'ES_EYE_SCAN_EN',
        'errDetEn':       'ES_ERRDET_EN',
        'control':        'ES_CONTROL',
        'prescale':       'ES_PRESCALE',
        'horzOffset':     'ES_HORZ_OFFSET',
        'vsCode':         'RX_EYESCAN_VS_CODE',
        'vsRange':        'RX_EYESCAN_VS_RANGE',
        'vsNegDir':       'RX_EYESCAN_VS_NEG_DIR',
        'vsUtSign':       'RX_EYESCAN_VS_UT_SIGN',
        'errorCount':     'es_error_count',
        'sampleCount':    'es_sample_count',
        'controlStatus':  'es_control_status',
        'rxDataWidth':    'RX_DATA_WIDTH',
        'rxIntDataWidth': 'RX_INT_DATAWIDTH',
        'rxOutDiv':       'RXOUT_DIV',
    },
    arrays                = {
        'sdataMask':      ('ES_SDATA_MASK', 5),
        'qualMask':       ('ES_QUAL_MASK',  5),
        'qualifier':      ('ES_QUALIFIER',  5),
    },
    busWidth              = 40,
    rxDataWidthCodes      = {2: 16, 3: 20, 4: 32, 5: 40, 6: 64, 7: 80},
    widthCombos           = frozenset({(16, 0), (20, 0), (32, 0), (32, 1), (40, 0), (40, 1), (64, 1), (80, 1)}),
    rxOutDivCodes         = {0: 1, 1: 2, 2: 4, 3: 8, 4: 16},
    horzBits              = 12,
    countsPerHalfUiPerDiv = 32,
    # Bit 11 is 0 for counts >= 0 and 1 for negative counts, which `x & 0xFFF` produces
    phaseUnification      = 'sign',
    # UG578 v1.3 Table 4-20: at or below 10 Gb/s the rate rule sets bit 11 to 0
    rateThresholdGbps     = 10.0,
    vsCodeMax             = 127,
    # The shipped KCU1500 GTH lanes
    defaultWidth          = 32,
    defaultDivider        = 2,
)

# UG578: 160-bit sdata, qualifier and qualifier-mask words, RX_DATA_WIDTH codes up to 160 bits and the Table 4-49 width pairs
GTYE4 = EyeScanFamily(
    name                  = 'GTYE4',
    # Varium C1100 lanes 4-7 at 6.25 Gb/s: the battery passed on the first run (one card, one image)
    hwVerified            = True,
    regs                  = dict(GTHE3.regs),
    arrays                = {
        'sdataMask':      ('ES_SDATA_MASK{}', 10),
        'qualMask':       ('ES_QUAL_MASK{}',  10),
        'qualifier':      ('ES_QUALIFIER{}',  10),
    },
    busWidth              = 80,
    rxDataWidthCodes      = {2: 16, 3: 20, 4: 32, 5: 40, 6: 64, 7: 80, 8: 128, 9: 160},
    widthCombos           = frozenset({(16, 0), (20, 0), (32, 0), (32, 1), (40, 0), (40, 1),
                                       (64, 1), (64, 2), (80, 1), (80, 2), (128, 2), (160, 2)}),
    # RXOUT_DIV raw 5 (divider 32) stays out: +-0.5 UI would be +-1024 counts, past the 11-bit offset
    rxOutDivCodes         = {0: 1, 1: 2, 2: 4, 3: 8, 4: 16},
    horzBits              = 12,
    countsPerHalfUiPerDiv = 32,
    # Kept at 'sign': Varium C1100 lanes 4-7 at 6.25, 10.3125, 15.46875 and 25 Gb/s did not separate the rules, and at 6.25 Gb/s 'rate' ran 4-7 counts narrower
    phaseUnification      = 'sign',
    rateThresholdGbps     = 10.0,
    vsCodeMax             = 127,
    # The shipped GTY IPs use a 64-bit internal width; divider 2 is the 6.25 Gb/s QPLL0 setting
    defaultWidth          = 64,
    defaultDivider        = 2,
)

FAMILIES = {'GTHE3': GTHE3, 'GTYE4': GTYE4}

UNSUPPORTED_FAMILIES = ('GTPE2', 'GTXE2')


def getFamily(name: str) -> EyeScanFamily:
    """Return the descriptor of a transceiver family.

    Parameters
    ----------
    name : str
        Family name.

    Returns
    -------
    EyeScanFamily
        The descriptor registered under ``name``.

    Raises
    ------
    EyeScanError
        If the family is not supported yet or the name is unknown.
    """
    if name in FAMILIES:
        return FAMILIES[name]
    if name in UNSUPPORTED_FAMILIES:
        raise EyeScanError(f'{name}: eye scan is not supported for this family yet')
    raise EyeScanError(f'{name}: unknown eye-scan family')
