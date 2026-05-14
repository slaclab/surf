#-----------------------------------------------------------------------------
# Description:
#
# Based on CMIS (Common Management Interface Specification) Rev 5.0 (May 2021)
# http://www.qsfp-dd.com/wp-content/uploads/2021/05/CMIS5p0.pdf
#
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

from surf.devices import transceivers
from surf.devices.transceivers._Qsfp import _UpperPageProxy, _ProxySlave, _POLL_EXC, _log  # noqa: F401

##############################################################################
# CMIS-specific enum dictionaries
##############################################################################

# CMIS spec revision compliance (lower page byte 1).  Upper nibble = major,
# lower nibble = minor.  Only published revisions are mapped explicitly; every
# other byte value resolves to 'Undefined' so the GUI cannot misreport an
# unrecognized revision as a known one (D4).
CmisRevisionDict = {
    0x30: 'CMIS 3.0',
    0x40: 'CMIS 4.0',
    0x50: 'CMIS 5.0',
    0x51: 'CMIS 5.1',
    0x52: 'CMIS 5.2',
}

for _code in range(0x100):
    CmisRevisionDict.setdefault(_code, 'Undefined')

# CMIS Module State Machine (lower page byte 3 bits 3:1) per CMIS §6.3.
ModuleStateDict = {
    0b001: 'ModuleLowPwr',
    0b010: 'ModulePwrUp',
    0b011: 'ModuleReady',
    0b100: 'ModulePwrDn',
    0b101: 'ModuleFault',
}


class QsfpDd(pr.Device):
    def __init__(self, advDebug=False, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.LocalVariable(
            name        = 'ErrorCount',
            description = 'I2C read failures after retry exhaustion (cumulative since Rogue start)',
            mode        = 'RO',
            value       = 0,
            typeStr     = 'UInt32',
        ))

        ################
        # Lower Page 00h
        ################

        self.add(pr.RemoteVariable(
            name        = 'Identifier',
            description = 'Type of serial transceiver (SFF-8024 form-factor code)',
            offset      = (0 << 2),
            bitSize     = 8,
            mode        = 'RO',
            enum        = transceivers.IdentifierDict,
        ))

        self.add(pr.RemoteVariable(
            name        = 'CmisRevision',
            description = 'CMIS spec revision compliance (upper nibble = major, lower nibble = minor)',
            offset      = (1 << 2),
            bitSize     = 8,
            mode        = 'RO',
            enum        = CmisRevisionDict,
        ))

        if advDebug:
            self.add(pr.RemoteVariable(
                name        = 'ModuleState',
                description = 'CMIS Module State Machine state (lower page byte 3 bits 3:1)',
                offset      = (3 << 2),
                bitSize     = 3,
                bitOffset   = 1,
                mode        = 'RO',
                enum        = ModuleStateDict,
            ))

        self.addRemoteVariables(
            name        = 'TemperatureRaw',
            description = 'Module temperature (signed 16-bit, 1/256 degC)',
            offset      = (14 << 2),
            bitSize     = 8,
            mode        = 'RO',
            number      = 2,  # BYTE14:BYTE15
            stride      = 4,
            hidden      = True,
        )

        self.add(pr.LinkVariable(
            name         = 'Temperature',
            description  = 'Internally measured module temperature',
            mode         = 'RO',
            linkedGet    = transceivers.getTemp,
            dependencies = [self.TemperatureRaw[0], self.TemperatureRaw[1]],
            units        = 'degC',
            disp         = '{:1.3f}',
        ))

        self.addRemoteVariables(
            name        = 'VccRaw',
            description = 'Module supply voltage (unsigned 16-bit, 100 uV)',
            offset      = (16 << 2),
            bitSize     = 8,
            mode        = 'RO',
            number      = 2,  # BYTE16:BYTE17
            stride      = 4,
            hidden      = True,
        )

        self.add(pr.LinkVariable(
            name         = 'Vcc',
            description  = 'Internally measured supply voltage in transceiver',
            mode         = 'RO',
            linkedGet    = transceivers.getVolt,
            dependencies = [self.VccRaw[0], self.VccRaw[1]],
            units        = 'V',
            disp         = '{:1.3f}',
        ))

        ##############################
        # Upper Page Proxy + children
        ##############################

        self.add(_CmisUpperPageProxy(
            name    = 'UpperPageProxy',
            memBase = self,
            offset  = 0x0000,
            hidden  = True,
        ))
        self.proxy = _ProxySlave(self.UpperPageProxy)

        # Note: the analog SFF-8636 class _QsfpUpperPage00h.py accepts an advDebug kwarg to
        # expose the byte-128 'UppperIdentifier' echo (a duplicate of lower-page byte 0
        # kept around for legacy diagnostics). CMIS does not have an analogous echo and
        # v1 has no other upper-page debug-only field, so we drop the kwarg. If a future
        # CMIS upper-page debug field needs gating, re-introduce advDebug then.
        self.add(QsfpDdUpperPage00h(
            name    = 'UpperPage00h',
            memBase = self.proxy,
            offset  = (0+1) << 10,
        ))

    def add(self, node):
        pr.Node.add(self, node)

        if isinstance(node, pr.Device):
            if node._memBase is None:
                node._setSlave(self.proxy)


class _CmisUpperPageProxy(_UpperPageProxy):
    """CMIS variant that writes bank-select byte 126 before page-select byte 127.

    v1 always writes bank=0 (no banked pages are wired in this version; D1 keeps
    the write unconditional per CMIS §8.2.2 + RES-08 mask).
    """

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name        = 'BankSelectByte',
            description = 'CMIS byte 126: bank select (always 0 in v1)',
            offset      = (126 << 2),
            bitSize     = 8,
            mode        = 'WO',
            hidden      = True,
            groups      = ['NoStream', 'NoState', 'NoConfig'],
        ))

        self._bankArmed = False

    def _writePageSelect(self, pageSelect):
        """CMIS §8.2.2: BankSelect MUST be applied before PageSelect.

        v1 always writes bank=0 once at first transaction; the parent's RES-08
        mask absorbs any module NACK (D1).
        """
        if not self._bankArmed:
            self._bankArmed = True
            self.BankSelectByte.set(value=0, write=True)
        super()._writePageSelect(pageSelect)


class QsfpDdUpperPage00h(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.addRemoteVariables(
            name        = 'VendorNameRaw',
            description = 'CMIS vendor name (ASCII)',
            offset      = (129 << 2),
            bitSize     = 8,
            mode        = 'RO',
            base        = pr.String,
            number      = 16,  # BYTE129:BYTE144
            stride      = 4,
            hidden      = True,
        )

        self.add(pr.LinkVariable(
            name         = 'VendorName',
            description  = 'CMIS vendor name (ASCII)',
            mode         = 'RO',
            linkedGet    = transceivers.parseStrArrayByte,
            dependencies = [self.VendorNameRaw[x] for x in range(16)],
        ))

        self.addRemoteVariables(
            name        = 'VendorPnRaw',
            description = 'CMIS vendor part number (ASCII)',
            offset      = (148 << 2),
            bitSize     = 8,
            mode        = 'RO',
            base        = pr.String,
            number      = 16,  # BYTE148:BYTE163
            stride      = 4,
            hidden      = True,
        )

        self.add(pr.LinkVariable(
            name         = 'VendorPn',
            description  = 'CMIS vendor part number (ASCII)',
            mode         = 'RO',
            linkedGet    = transceivers.parseStrArrayByte,
            dependencies = [self.VendorPnRaw[x] for x in range(16)],
        ))

        self.addRemoteVariables(
            name        = 'VendorSnRaw',
            description = 'CMIS vendor serial number (ASCII)',
            offset      = (166 << 2),
            bitSize     = 8,
            mode        = 'RO',
            base        = pr.String,
            number      = 16,  # BYTE166:BYTE181
            stride      = 4,
            hidden      = True,
        )

        self.add(pr.LinkVariable(
            name         = 'VendorSn',
            description  = 'CMIS vendor serial number (ASCII)',
            mode         = 'RO',
            linkedGet    = transceivers.parseStrArrayByte,
            dependencies = [self.VendorSnRaw[x] for x in range(16)],
        ))

        self.addRemoteVariables(
            name        = 'DateCode',
            description = "Vendor's manufacturing date code (ASCII YYMMDD; CMIS lot code bytes 188-189 dropped in v1)",
            offset      = (182 << 2),
            bitSize     = 8,
            mode        = 'RO',
            base        = pr.String,
            number      = 6,  # BYTE182:BYTE187 (YYMMDD only; CMIS LL lot code bytes 188-189 dropped)
            stride      = 4,
            hidden      = True,
        )

        self.add(pr.LinkVariable(
            name         = 'ManufactureDate',
            description  = "Vendor's manufacturing date code (ASCII)",
            mode         = 'RO',
            linkedGet    = transceivers.getDate,
            dependencies = [self.DateCode[x] for x in [0, 1, 4, 5, 2, 3]],
        ))
