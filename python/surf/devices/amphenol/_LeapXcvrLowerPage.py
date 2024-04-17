#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class LeapXcvrLowerPage(pr.Device):
    def __init__(self, isTx = True, writeEn=False, **kwargs):
        super().__init__(**kwargs)

        rwType = 'RW' if writeEn else 'RO'

        if isTx:
            self.add(pr.RemoteVariable(
                name        = 'TxRxUpperPage02Presence',
                offset      = (2 << 2),
                bitSize     = 2,
                bitOffset   = 4,
                mode        = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name        = 'RxDeviceAddressPresence',
                offset      = (2 << 2),
                bitSize     = 1,
                bitOffset   = 3,
                mode        = 'RO',
            ))

        self.add(pr.RemoteVariable(
            name        = 'PagingMemoryPresence',
            offset      = (2 << 2),
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'StatusIntL',
            offset      = (2 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DataNotReady',
            offset      = (2 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RO',
        ))

        if isTx:
            self.add(pr.RemoteVariable(
                name        = 'LosTxStatusSummary',
                offset      = (6 << 2),
                bitSize     = 1,
                bitOffset   = 7,
                mode        = 'RO',
            ))
        else:
            self.add(pr.RemoteVariable(
                name        = 'LosRxStatusSummary',
                offset      = (6 << 2),
                bitSize     = 1,
                bitOffset   = 6,
                mode        = 'RO',
            ))

        if isTx:
            self.add(pr.RemoteVariable(
                name        = 'FaultTxStatusSummary',
                offset      = (6 << 2),
                bitSize     = 1,
                bitOffset   = 5,
                mode        = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name        = 'BiasTxStatusSummary',
                offset      = (6 << 2),
                bitSize     = 1,
                bitOffset   = 4,
                mode        = 'RO',
            ))

        self.add(pr.RemoteVariable(
            name        = 'CdrLolTxStatusSummary' if isTx else 'RxLolStatusSummary',
            offset      = (6 << 2),
            bitSize     = 1,
            bitOffset   = 3,
            mode        = 'RO',
        ))

        if not isTx:
            self.add(pr.RemoteVariable(
                name        = 'PowerRxStatusSummary',
                offset      = (6 << 2),
                bitSize     = 1,
                bitOffset   = 2,
                mode        = 'RO',
            ))

        self.add(pr.RemoteVariable(
            name        = 'ModuleTxStatusSummary' if isTx else 'ModuleRxStatusSummary',
            offset      = (6 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LosTxMsb' if isTx else 'LosRxMsb',
            offset      = (7 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LosTxLsb' if isTx else 'LosRxLsb',
            offset      = (8 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
        ))

        if isTx:
            self.add(pr.LinkVariable(
                name         = 'LosTx',
                mode         = 'RO',
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                linkedGet    = lambda: self.LosTxLsb.value()+256*self.LosTxMsb.value(),
                dependencies = [self.LosTxLsb,self.LosTxMsb],
            ))
        else:
            self.add(pr.LinkVariable(
                name         = 'LosRx',
                mode         = 'RO',
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                linkedGet    = lambda: self.LosRxLsb.value()+256*self.LosRxMsb.value(),
                dependencies = [self.LosRxLsb,self.LosRxMsb],
            ))

        self.add(pr.RemoteVariable(
            name        = 'FaultTxMsb' if isTx else 'FaultRxMsb',
            offset      = (9 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'FaultTxLsb' if isTx else 'FaultRxLsb',
            offset      = (10 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
        ))

        if isTx:
            self.add(pr.LinkVariable(
                name         = 'FaultTx',
                mode         = 'RO',
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                linkedGet    = lambda: self.FaultTxLsb.value()+256*self.FaultTxMsb.value(),
                dependencies = [self.FaultTxLsb,self.FaultTxMsb],
            ))
        else:
            self.add(pr.LinkVariable(
                name         = 'FaultRx',
                mode         = 'RO',
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                linkedGet    = lambda: self.FaultRxLsb.value()+256*self.FaultRxMsb.value(),
                dependencies = [self.FaultRxLsb,self.FaultRxMsb],
            ))

            self.add(pr.RemoteVariable(
                name        = 'LolRxMsb',
                offset      = (12 << 2),
                bitSize     = 4,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = True,
            ))

            self.add(pr.RemoteVariable(
                name        = 'LolRxLsb',
                offset      = (13 << 2),
                bitSize     = 8,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = True,
            ))

            self.add(pr.LinkVariable(
                name         = 'LolRx',
                mode         = 'RO',
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                linkedGet    = lambda: self.LolRxLsb.value()+256*self.LolRxMsb.value(),
                dependencies = [self.LolRxLsb,self.LolRxMsb],
            ))

        if isTx:
            self.add(pr.RemoteVariable(
                name        = 'LolTxMsb',
                offset      = (15 << 2),
                bitSize     = 4,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = True,
            ))

            self.add(pr.RemoteVariable(
                name        = 'LolTxLsb',
                offset      = (16 << 2),
                bitSize     = 8,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = True,
            ))

            self.add(pr.LinkVariable(
                name         = 'LolTx',
                mode         = 'RO',
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                linkedGet    = lambda: self.LolTxLsb.value()+256*self.LolTxMsb.value(),
                dependencies = [self.LolTxLsb,self.LolTxMsb],
            ))

            self.add(pr.RemoteVariable(
                name        = 'TxTempMsb',
                offset      = (22 << 2),
                bitSize     = 8,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = True,
            ))

            self.add(pr.RemoteVariable(
                name        = 'TxTempLsb',
                offset      = (23 << 2),
                bitSize     = 8,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = True,
            ))

            self.add(pr.LinkVariable(
                name         = 'TxTemp',
                mode         = 'RO',
                disp         = '{:1.1f}',
                units        = 'degC',
                linkedGet    = lambda: float(self.TxTempMsb.value())+float(self.TxTempLsb.value())/256.0,
                dependencies = [self.TxTempMsb,self.TxTempLsb],
            ))

        self.add(pr.RemoteVariable(
            name        = 'TxVcc3p3Msb' if isTx else 'RxVcc3p3Msb',
            offset      = (26 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxVcc3p3Lsb' if isTx else 'RxVcc3p3Lsb',
            offset      = (27 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
        ))

        if isTx:
            self.add(pr.LinkVariable(
                name         = 'TxVcc3p3',
                mode         = 'RO',
                disp         = '{:1.3f}',
                units        = 'V',
                linkedGet    = lambda: float(self.TxVcc3p3Lsb.value()+256*self.TxVcc3p3Msb.value())*100.0E-6,
                dependencies = [self.TxVcc3p3Lsb,self.TxVcc3p3Msb],
            ))
        else:
            self.add(pr.LinkVariable(
                name         = 'RxVcc3p3',
                mode         = 'RO',
                disp         = '{:1.3f}',
                units        = 'V',
                linkedGet    = lambda: float(self.RxVcc3p3Lsb.value()+256*self.RxVcc3p3Msb.value())*100.0E-6,
                dependencies = [self.RxVcc3p3Lsb,self.RxVcc3p3Msb],
            ))

        if isTx:
            self.add(pr.RemoteVariable(
                name        = 'TxVccHiMsb',
                offset      = (28 << 2),
                bitSize     = 8,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = True,
            ))

            self.add(pr.RemoteVariable(
                name        = 'TxVccHiLsb',
                offset      = (29 << 2),
                bitSize     = 8,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = True,
            ))

            self.add(pr.LinkVariable(
                name         = 'TxVccHi',
                mode         = 'RO',
                disp         = '{:1.3f}',
                units        = 'V',
                linkedGet    = lambda: float(self.TxVccHiLsb.value()+256*self.TxVccHiMsb.value())*100.0E-6,
                dependencies = [self.TxVccHiLsb,self.TxVccHiMsb],
            ))

        else:
            self.add(pr.RemoteVariable(
                name        = 'RxModuleAppSelect',
                offset      = (40 << 2),
                bitSize     = 8,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = True,
            ))

        self.add(pr.RemoteVariable(
            name        = 'TxRateSelect' if isTx else 'RxRateSelect',
            offset      = (41 << 2),
            bitSize     = 5,
            bitOffset   = 0,
            mode        = 'RO',
        ))

        if isTx:
            self.add(pr.RemoteVariable(
                name        = 'HighPowerMode',
                offset      = (42 << 2),
                bitSize     = 1,
                bitOffset   = 0,
                mode        = 'RO',
            ))

        self.add(pr.RemoteVariable(
            name        = 'GlobalTxCdr' if isTx else 'GlobalRxCdr',
            offset      = (43 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = rwType,
        ))

        if writeEn:
            self.add(pr.RemoteVariable(
                name        = 'ResetTx' if isTx else 'ResetRx',
                offset      = (51 << 2),
                bitSize     = 1,
                bitOffset   = 0,
                mode        = 'WO',
            ))

        if not isTx:

            self.add(pr.RemoteVariable(
                name        = 'RxChDisableMsb',
                offset      = (52 << 2),
                bitSize     = 4,
                bitOffset   = 0,
                mode        = rwType,
                hidden      = True,
            ))

            self.add(pr.RemoteVariable(
                name        = 'RxChDisableLsb',
                offset      = (53 << 2),
                bitSize     = 8,
                bitOffset   = 0,
                mode        = rwType,
                hidden      = True,
            ))

            self.add(pr.LinkVariable(
                name         = 'RxChDisable',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                linkedGet    = lambda: self.RxChDisableLsb.value()+256*self.RxChDisableMsb.value(),
                linkedSet    = lambda value, write: self.RxChDisableLsb.set(value&0xFF) or self.RxChDisableMsb.set(value>>8),
                dependencies = [self.RxChDisableLsb,self.RxChDisableMsb],
            ))

        self.add(pr.RemoteVariable(
            name        = 'TxCdrBypassMsb' if isTx else 'RxCdrBypassMsb',
            offset      = (54 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = rwType,
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxCdrBypassLsb' if isTx else 'RxCdrBypassLsb',
            offset      = (55 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = rwType,
            hidden      = True,
        ))

        if isTx:
            self.add(pr.LinkVariable(
                name         = 'TxCdrBypass',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                linkedGet    = lambda: self.TxCdrBypassLsb.value()+256*self.TxCdrBypassMsb.value(),
                linkedSet    = lambda value, write: self.TxCdrBypassLsb.set(value&0xFF) or self.TxCdrBypassMsb.set(value>>8),
                dependencies = [self.TxCdrBypassLsb,self.TxCdrBypassMsb],
            ))
        else:
            self.add(pr.LinkVariable(
                name         = 'RxCdrBypass',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                linkedGet    = lambda: self.RxCdrBypassLsb.value()+256*self.RxCdrBypassMsb.value(),
                linkedSet    = lambda value, write: self.RxCdrBypassLsb.set(value&0xFF) or self.RxCdrBypassMsb.set(value>>8),
                dependencies = [self.RxCdrBypassLsb,self.RxCdrBypassMsb],
            ))

        self.add(pr.RemoteVariable(
            name        = 'TxSquelchDisableMsb' if isTx else 'RxSquelchDisableMsb',
            offset      = (56 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = rwType,
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxSquelchDisableLsb' if isTx else 'RxSquelchDisableLsb',
            offset      = (57 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = rwType,
            hidden      = True,
        ))

        if isTx:
            self.add(pr.LinkVariable(
                name         = 'TxSquelchDisable',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                linkedGet    = lambda: self.TxSquelchDisableLsb.value()+256*self.TxSquelchDisableMsb.value(),
                linkedSet    = lambda value, write: self.TxSquelchDisableLsb.set(value&0xFF) or self.TxSquelchDisableMsb.set(value>>8),
                dependencies = [self.TxSquelchDisableLsb,self.TxSquelchDisableMsb],
            ))
        else:
            self.add(pr.LinkVariable(
                name         = 'RxSquelchDisable',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                linkedGet    = lambda: self.RxSquelchDisableLsb.value()+256*self.RxSquelchDisableMsb.value(),
                linkedSet    = lambda value, write: self.RxSquelchDisableLsb.set(value&0xFF) or self.RxSquelchDisableMsb.set(value>>8),
                dependencies = [self.RxSquelchDisableLsb,self.RxSquelchDisableMsb],
            ))

        self.add(pr.RemoteVariable(
            name        = 'TxPolarityMsb' if isTx else 'RxPolarityMsb',
            offset      = (58 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = rwType,
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxPolarityLsb' if isTx else 'RxPolarityLsb',
            offset      = (59 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = rwType,
            hidden      = True,
        ))

        if isTx:
            self.add(pr.LinkVariable(
                name         = 'TxPolarity',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                linkedGet    = lambda: self.TxPolarityLsb.value()+256*self.TxPolarityMsb.value(),
                linkedSet    = lambda value, write: self.TxPolarityLsb.set(value&0xFF) or self.TxPolarityMsb.set(value>>8),
                dependencies = [self.TxPolarityLsb,self.TxPolarityMsb],
            ))
        else:
            self.add(pr.LinkVariable(
                name         = 'RxPolarity',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                linkedGet    = lambda: self.RxPolarityLsb.value()+256*self.RxPolarityMsb.value(),
                linkedSet    = lambda value, write: self.RxPolarityLsb.set(value&0xFF) or self.RxPolarityMsb.set(value>>8),
                dependencies = [self.RxPolarityLsb,self.RxPolarityMsb],
            ))

        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = f'InputEqualizationTx[{11-(2*i+0)}]' if isTx else f'OutputAmplitudeRX[{11-(2*i+0)}]',
                offset      = ((62+i) << 2),
                bitSize     = 4 if isTx else 3,
                bitOffset   = 4 if isTx else 5,
                mode        = rwType,
            ))

            self.add(pr.RemoteVariable(
                name        = f'InputEqualizationTx[{11-(2*i+1)}]' if isTx else f'OutputAmplitudeRX[{11-(2*i+1)}]',
                offset      = ((62+i) << 2),
                bitSize     = 4 if isTx else 3,
                bitOffset   = 0 if isTx else 1,
                mode        = rwType,
            ))

        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = f'InputMidEqualizationTx[{11-(2*i+0)}]' if isTx else f'OutputDeEmphasisRx[{11-(2*i+0)}]',
                offset      = ((68+i) << 2),
                bitSize     = 4 if isTx else 3,
                bitOffset   = 4 if isTx else 5,
                mode        = rwType,
            ))

            self.add(pr.RemoteVariable(
                name        = f'InputMidEqualizationTx[{11-(2*i+1)}]' if isTx else f'OutputDeEmphasisRx[{11-(2*i+1)}]',
                offset      = ((68+i) << 2),
                bitSize     = 4 if isTx else 3,
                bitOffset   = 0 if isTx else 1,
                mode        = rwType,
            ))


        if isTx:
            self.add(pr.RemoteVariable(
                name        = 'TxSquelchHysteresisDisableMsb',
                offset      = (74 << 2),
                bitSize     = 4,
                bitOffset   = 0,
                mode        = rwType,
                hidden      = True,
            ))

            self.add(pr.RemoteVariable(
                name        = 'TxSquelchHysteresisDisableLsb',
                offset      = (75 << 2),
                bitSize     = 8,
                bitOffset   = 0,
                mode        = rwType,
                hidden      = True,
            ))

            self.add(pr.LinkVariable(
                name         = 'TxSquelchHysteresisDisable',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                linkedGet    = lambda: self.TxSquelchHysteresisDisableLsb.value()+256*self.TxSquelchHysteresisDisableMsb.value(),
                linkedSet    = lambda value, write: self.TxSquelchHysteresisDisableLsb.set(value&0xFF) or self.TxSquelchHysteresisDisableMsb.set(value>>8),
                dependencies = [self.TxSquelchHysteresisDisableLsb,self.TxSquelchHysteresisDisableMsb],
            ))

            self.add(pr.RemoteVariable(
                name        = 'TxInputSquelchHysteresisThreshold',
                offset      = (76 << 2),
                bitSize     = 3,
                bitOffset   = 0,
                mode        = rwType,
                hidden      = True,
            ))

        self.add(pr.RemoteVariable(
            name        = 'TxOutputDisableMsb' if isTx else 'RxOutputDisableMsb',
            offset      = (116 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = rwType,
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxOutputDisableLsb' if isTx else 'RxOutputDisableLsb',
            offset      = (117 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = rwType,
            hidden      = True,
        ))

        if isTx:
            self.add(pr.LinkVariable(
                name         = 'TxOutputDisable',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                linkedGet    = lambda: self.TxOutputDisableLsb.value()+256*self.TxOutputDisableMsb.value(),
                linkedSet    = lambda value, write: self.TxOutputDisableLsb.set(value&0xFF) or self.TxOutputDisableMsb.set(value>>8),
                dependencies = [self.TxOutputDisableLsb,self.TxOutputDisableMsb],
            ))
        else:
            self.add(pr.LinkVariable(
                name         = 'RxOutputDisable',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                linkedGet    = lambda: self.RxOutputDisableLsb.value()+256*self.RxOutputDisableMsb.value(),
                linkedSet    = lambda value, write: self.RxOutputDisableLsb.set(value&0xFF) or self.RxOutputDisableMsb.set(value>>8),
                dependencies = [self.RxOutputDisableLsb,self.RxOutputDisableMsb],
            ))
