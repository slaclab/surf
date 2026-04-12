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
    def __init__(self, isTx=True, writeEn=False, **kwargs):
        super().__init__(**kwargs)

        rwType = 'RW' if writeEn else 'RO'

        if isTx:
            self.add(pr.RemoteVariable(
                name        = 'TxRxUpperPage02Presence',
                offset      = (2 << 2),
                bitSize     = 2,
                bitOffset   = 4,
                mode        = 'RO',
                description = 'Indicates whether Upper Page 02 is supported and address type',
            ))

            self.add(pr.RemoteVariable(
                name        = 'RxDeviceAddressPresence',
                offset      = (2 << 2),
                bitSize     = 1,
                bitOffset   = 3,
                mode        = 'RO',
                description = 'Indicates whether Rx device address fields are present',
            ))

        self.add(pr.RemoteVariable(
            name        = 'PagingMemoryPresence',
            offset      = (2 << 2),
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'RO',
            description = 'Indicates whether paging memory is present (1 = Upper Page 00 only)',
        ))

        self.add(pr.RemoteVariable(
            name        = 'StatusIntL',
            offset      = (2 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
            description = 'Interrupt status: coded 1 when Int_L is asserted, clears when all flags cleared',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DataNotReady',
            offset      = (2 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RO',
            description = 'Data not ready flag: high until module has achieved power up and monitor data is valid',
        ))

        if isTx:
            self.add(pr.RemoteVariable(
                name        = 'LosTxStatusSummary',
                offset      = (6 << 2),
                bitSize     = 1,
                bitOffset   = 7,
                mode        = 'RO',
                description = 'TX LOS status summary: coded 1 when any LOS Tx flag is asserted',
            ))
        else:
            self.add(pr.RemoteVariable(
                name        = 'LosRxStatusSummary',
                offset      = (6 << 2),
                bitSize     = 1,
                bitOffset   = 6,
                mode        = 'RO',
                description = 'RX LOS status summary: coded 1 when any LOS Rx flag is asserted',
            ))

        if isTx:
            self.add(pr.RemoteVariable(
                name        = 'FaultTxStatusSummary',
                offset      = (6 << 2),
                bitSize     = 1,
                bitOffset   = 5,
                mode        = 'RO',
                description = 'TX fault status summary: coded 1 when any Fault Tx flag is asserted',
            ))

            self.add(pr.RemoteVariable(
                name        = 'BiasTxStatusSummary',
                offset      = (6 << 2),
                bitSize     = 1,
                bitOffset   = 4,
                mode        = 'RO',
                description = 'TX bias status summary: coded 1 when any Tx Bias alarm flag is asserted',
            ))

        self.add(pr.RemoteVariable(
            name        = 'CdrLolTxStatusSummary' if isTx else 'RxLolStatusSummary',
            offset      = (6 << 2),
            bitSize     = 1,
            bitOffset   = 3,
            mode        = 'RO',
            description = 'CDR loss-of-lock status summary: coded 1 when any CDR LOL flag is asserted',
        ))

        if not isTx:
            self.add(pr.RemoteVariable(
                name        = 'PowerRxStatusSummary',
                offset      = (6 << 2),
                bitSize     = 1,
                bitOffset   = 2,
                mode        = 'RO',
                description = 'RX optical power Hi-Lo alarm status summary',
            ))

        self.add(pr.RemoteVariable(
            name        = 'ModuleTxStatusSummary' if isTx else 'ModuleRxStatusSummary',
            offset      = (6 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
            description = 'Module status summary: coded 1 when any module-level alarm flag is asserted',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LosTxMsb' if isTx else 'LosRxMsb',
            offset      = (7 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
            description = 'Loss of signal per-channel flags MSB (channels 8-11), latched, clears on read',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LosTxLsb' if isTx else 'LosRxLsb',
            offset      = (8 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
            description = 'Loss of signal per-channel flags LSB (channels 0-7), latched, clears on read',
        ))


        if isTx:
            self.add(pr.LinkVariable(
                name         = 'LosTx',
                mode         = 'RO',
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                description  = 'TX loss of signal per-channel bitmask (12 channels)',
                linkedGet    = self._getLsbMsb,
                dependencies = [self.LosTxLsb, self.LosTxMsb],
            ))
        else:
            self.add(pr.LinkVariable(
                name         = 'LosRx',
                mode         = 'RO',
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                description  = 'RX loss of signal per-channel bitmask (12 channels)',
                linkedGet    = self._getLsbMsb,
                dependencies = [self.LosRxLsb, self.LosRxMsb],
            ))

        self.add(pr.RemoteVariable(
            name        = 'FaultTxMsb' if isTx else 'FaultRxMsb',
            offset      = (9 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
            description = 'Fault per-channel flags MSB (channels 8-11), latched, clears on read',
        ))

        self.add(pr.RemoteVariable(
            name        = 'FaultTxLsb' if isTx else 'FaultRxLsb',
            offset      = (10 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
            description = 'Fault per-channel flags LSB (channels 0-7), latched, clears on read',
        ))

        if isTx:
            self.add(pr.LinkVariable(
                name         = 'FaultTx',
                mode         = 'RO',
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                description  = 'TX fault per-channel bitmask (12 channels)',
                linkedGet    = self._getLsbMsb,
                dependencies = [self.FaultTxLsb, self.FaultTxMsb],
            ))
        else:
            self.add(pr.LinkVariable(
                name         = 'FaultRx',
                mode         = 'RO',
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                description  = 'RX fault per-channel bitmask (12 channels)',
                linkedGet    = self._getLsbMsb,
                dependencies = [self.FaultRxLsb, self.FaultRxMsb],
            ))

            self.add(pr.RemoteVariable(
                name        = 'LolRxMsb',
                offset      = (12 << 2),
                bitSize     = 4,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = True,
                description = 'RX CDR loss-of-lock per-channel flags MSB (channels 8-11)',
            ))

            self.add(pr.RemoteVariable(
                name        = 'LolRxLsb',
                offset      = (13 << 2),
                bitSize     = 8,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = True,
                description = 'RX CDR loss-of-lock per-channel flags LSB (channels 0-7)',
            ))

            self.add(pr.LinkVariable(
                name         = 'LolRx',
                mode         = 'RO',
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                description  = 'RX CDR loss-of-lock per-channel bitmask (12 channels)',
                linkedGet    = self._getLsbMsb,
                dependencies = [self.LolRxLsb, self.LolRxMsb],
            ))

        if isTx:
            self.add(pr.RemoteVariable(
                name        = 'LolTxMsb',
                offset      = (15 << 2),
                bitSize     = 4,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = True,
                description = 'TX CDR loss-of-lock per-channel flags MSB (channels 8-11)',
            ))

            self.add(pr.RemoteVariable(
                name        = 'LolTxLsb',
                offset      = (16 << 2),
                bitSize     = 8,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = True,
                description = 'TX CDR loss-of-lock per-channel flags LSB (channels 0-7)',
            ))

            self.add(pr.LinkVariable(
                name         = 'LolTx',
                mode         = 'RO',
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                description  = 'TX CDR loss-of-lock per-channel bitmask (12 channels)',
                linkedGet    = self._getLsbMsb,
                dependencies = [self.LolTxLsb, self.LolTxMsb],
            ))

            self.add(pr.RemoteVariable(
                name        = 'TxTempMsb',
                offset      = (22 << 2),
                bitSize     = 8,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = True,
                description = 'TX internal temperature monitor MSB (integer part in signed 2s complement)',
            ))

            self.add(pr.RemoteVariable(
                name        = 'TxTempLsb',
                offset      = (23 << 2),
                bitSize     = 8,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = True,
                description = 'TX internal temperature monitor LSB (fractional part in units of 1/256 deg C)',
            ))

            self.add(pr.LinkVariable(
                name         = 'TxTempR',
                mode         = 'RO',
                disp         = '{:1.1f}',
                units        = 'degC',
                description  = 'TX internal temperature monitor in degrees C',
                linkedGet    = lambda var, read: self._getLsbMsb(var, read)/256.0,
                dependencies = [self.TxTempMsb, self.TxTempLsb],
            ))

        self.add(pr.RemoteVariable(
            name        = 'TxVcc3p3Msb' if isTx else 'RxVcc3p3Msb',
            offset      = (26 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
            description = 'Internal Vcc3.3 monitor MSB (16-bit unsigned, 100 uV/LSB)',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxVcc3p3Lsb' if isTx else 'RxVcc3p3Lsb',
            offset      = (27 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = True,
            description = 'Internal Vcc3.3 monitor LSB (16-bit unsigned, 100 uV/LSB)',
        ))

        if isTx:
            self.add(pr.LinkVariable(
                name         = 'TxVcc3p3',
                mode         = 'RO',
                disp         = '{:1.3f}',
                units        = 'V',
                description  = 'TX internal Vcc3.3 supply voltage monitor',
                linkedGet    = lambda var, read: self._getLsbMsb(var, read) * 100.0E-6,
                dependencies = [self.TxVcc3p3Lsb, self.TxVcc3p3Msb],
            ))
        else:
            self.add(pr.LinkVariable(
                name         = 'RxVcc3p3',
                mode         = 'RO',
                disp         = '{:1.3f}',
                units        = 'V',
                description  = 'RX internal Vcc3.3 supply voltage monitor',
                linkedGet    = lambda var, read: self._getLsbMsb(var, read) * 100.0E-6,
                dependencies = [self.RxVcc3p3Lsb, self.RxVcc3p3Msb],
            ))

        if isTx:
            self.add(pr.RemoteVariable(
                name        = 'TxVccHiMsb',
                offset      = (28 << 2),
                bitSize     = 8,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = True,
                description = 'Internal VccHI monitor MSB (16-bit unsigned, 100 uV/LSB)',
            ))

            self.add(pr.RemoteVariable(
                name        = 'TxVccHiLsb',
                offset      = (29 << 2),
                bitSize     = 8,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = True,
                description = 'Internal VccHI monitor LSB (16-bit unsigned, 100 uV/LSB)',
            ))

            self.add(pr.LinkVariable(
                name         = 'TxVccHi',
                mode         = 'RO',
                disp         = '{:1.3f}',
                units        = 'V',
                description  = 'TX internal VccHI supply voltage monitor',
                linkedGet    = lambda var, read: self._getLsbMsb(var, read) * 100.0E-6,
                dependencies = [self.TxVccHiLsb, self.TxVccHiMsb],
            ))

        else:
            self.add(pr.RemoteVariable(
                name        = 'RxModuleAppSelect',
                offset      = (40 << 2),
                bitSize     = 8,
                bitOffset   = 0,
                mode        = 'RO',
                hidden      = True,
                description = 'RX module application select (not supported)',
            ))

        self.add(pr.RemoteVariable(
            name        = 'TxRateSelect' if isTx else 'RxRateSelect',
            offset      = (41 << 2),
            bitSize     = 5,
            bitOffset   = 0,
            mode        = 'RO',
            description = 'Rate select optimization bit-map (QDR/DDR/SDR/FDR/EDR operation)',
        ))

        if isTx:
            self.add(pr.RemoteVariable(
                name        = 'HighPowerMode',
                offset      = (42 << 2),
                bitSize     = 1,
                bitOffset   = 0,
                mode        = 'RO',
                description = 'High power mode flag: 1 = device may draw more than 6.0 W',
            ))

        self.add(pr.RemoteVariable(
            name        = 'GlobalTxCdr' if isTx else 'GlobalRxCdr',
            offset      = (43 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = rwType,
            description = 'Global CDR enable: 1 = all CDRs enabled; 0 = all CDRs bypassed',
        ))

        if writeEn:
            self.add(pr.RemoteVariable(
                name        = 'ResetTx' if isTx else 'ResetRx',
                offset      = (51 << 2),
                bitSize     = 1,
                bitOffset   = 0,
                mode        = 'WO',
                description = 'Software reset: writing 1 returns all registers to factory default values',
            ))

        if not isTx:

            self.add(pr.RemoteVariable(
                name        = 'RxChDisableMsb',
                offset      = (52 << 2),
                bitSize     = 4,
                bitOffset   = 0,
                mode        = rwType,
                hidden      = True,
                description = 'RX channel disable per-channel flags MSB (channels 8-11)',
            ))

            self.add(pr.RemoteVariable(
                name        = 'RxChDisableLsb',
                offset      = (53 << 2),
                bitSize     = 8,
                bitOffset   = 0,
                mode        = rwType,
                hidden      = True,
                description = 'RX channel disable per-channel flags LSB (channels 0-7)',
            ))

            self.add(pr.LinkVariable(
                name         = 'RxChDisable',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                description  = 'RX channel disable bitmask: writing 1 disables the whole channel',
                linkedGet    = self._getLsbMsb,
                linkedSet    = self._setLsbMsb,
                dependencies = [self.RxChDisableLsb, self.RxChDisableMsb],
            ))

        self.add(pr.RemoteVariable(
            name        = 'TxCdrBypassMsb' if isTx else 'RxCdrBypassMsb',
            offset      = (54 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = rwType,
            hidden      = True,
            description = 'CDR bypass per-channel flags MSB (channels 8-11): 1 = CDR individually bypassed',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxCdrBypassLsb' if isTx else 'RxCdrBypassLsb',
            offset      = (55 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = rwType,
            hidden      = True,
            description = 'CDR bypass per-channel flags LSB (channels 0-7): 1 = CDR individually bypassed',
        ))

        if isTx:
            self.add(pr.LinkVariable(
                name         = 'TxCdrBypass',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                description  = 'TX CDR bypass per-channel bitmask: 1 = CDR individually bypassed for that channel',
                linkedGet    = self._getLsbMsb,
                linkedSet    = self._setLsbMsb,
                dependencies = [self.TxCdrBypassLsb, self.TxCdrBypassMsb],
            ))
        else:
            self.add(pr.LinkVariable(
                name         = 'RxCdrBypass',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                description  = 'RX CDR bypass per-channel bitmask: 1 = CDR individually bypassed for that channel',
                linkedGet    = self._getLsbMsb,
                linkedSet    = self._setLsbMsb,
                dependencies = [self.RxCdrBypassLsb, self.RxCdrBypassMsb],
            ))

        self.add(pr.RemoteVariable(
            name        = 'TxSquelchDisableMsb' if isTx else 'RxSquelchDisableMsb',
            offset      = (56 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = rwType,
            hidden      = True,
            description = 'Squelch disable per-channel flags MSB (channels 8-11): 1 = squelch disabled',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxSquelchDisableLsb' if isTx else 'RxSquelchDisableLsb',
            offset      = (57 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = rwType,
            hidden      = True,
            description = 'Squelch disable per-channel flags LSB (channels 0-7): 1 = squelch disabled',
        ))

        if isTx:
            self.add(pr.LinkVariable(
                name         = 'TxSquelchDisable',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                description  = 'TX squelch disable per-channel bitmask: 1 = squelch disabled for that channel',
                linkedGet    = self._getLsbMsb,
                linkedSet    = self._setLsbMsb,
                dependencies = [self.TxSquelchDisableLsb, self.TxSquelchDisableMsb],
            ))
        else:
            self.add(pr.LinkVariable(
                name         = 'RxSquelchDisable',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                description  = 'RX squelch disable per-channel bitmask: 1 = squelch disabled for that channel',
                linkedGet    = self._getLsbMsb,
                linkedSet    = self._setLsbMsb,
                dependencies = [self.RxSquelchDisableLsb, self.RxSquelchDisableMsb],
            ))

        self.add(pr.RemoteVariable(
            name        = 'TxPolarityMsb' if isTx else 'RxPolarityMsb',
            offset      = (58 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = rwType,
            hidden      = True,
            description = 'Channel polarity flip per-channel flags MSB (channels 8-11): 1 = polarity inverted',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxPolarityLsb' if isTx else 'RxPolarityLsb',
            offset      = (59 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = rwType,
            hidden      = True,
            description = 'Channel polarity flip per-channel flags LSB (channels 0-7): 1 = polarity inverted',
        ))

        if isTx:
            self.add(pr.LinkVariable(
                name         = 'TxPolarity',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                description  = 'TX channel polarity flip bitmask: 1 = input polarity inverted for that channel',
                linkedGet    = self._getLsbMsb,
                linkedSet    = self._setLsbMsb,
                dependencies = [self.TxPolarityLsb, self.TxPolarityMsb],
            ))
        else:
            self.add(pr.LinkVariable(
                name         = 'RxPolarity',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                description  = 'RX channel polarity flip bitmask: 1 = output polarity inverted for that channel',
                linkedGet    = self._getLsbMsb,
                linkedSet    = self._setLsbMsb,
                dependencies = [self.RxPolarityLsb, self.RxPolarityMsb],
            ))

        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = f'InputEqualizationTx[{11-(2*i+0)}]' if isTx else f'OutputAmplitudeRX[{11-(2*i+0)}]',
                offset      = ((62+i) << 2),
                bitSize     = 4 if isTx else 3,
                bitOffset   = 4 if isTx else 5,
                mode        = rwType,
                description = 'TX input equalization control per channel (4-bit, 0=0dB, 1111b=11dB)' if isTx else 'RX output amplitude control per channel (3-bit, 000b=min, 111b=max)',
            ))

            self.add(pr.RemoteVariable(
                name        = f'InputEqualizationTx[{11-(2*i+1)}]' if isTx else f'OutputAmplitudeRX[{11-(2*i+1)}]',
                offset      = ((62+i) << 2),
                bitSize     = 4 if isTx else 3,
                bitOffset   = 0 if isTx else 1,
                mode        = rwType,
                description = 'TX input equalization control per channel (4-bit, 0=0dB, 1111b=11dB)' if isTx else 'RX output amplitude control per channel (3-bit, 000b=min, 111b=max)',
            ))

        for i in range(6):
            self.add(pr.RemoteVariable(
                name        = f'InputMidEqualizationTx[{11-(2*i+0)}]' if isTx else f'OutputDeEmphasisRx[{11-(2*i+0)}]',
                offset      = ((68+i) << 2),
                bitSize     = 4 if isTx else 3,
                bitOffset   = 4 if isTx else 5,
                mode        = rwType,
                description = 'TX mid-frequency input equalization control per channel (4-bit, 0=0dB, 1111b=4dB at 2GHz)' if isTx else 'RX output de-emphasis control per channel (3-bit, 000b=min, 111b=max)',
            ))

            self.add(pr.RemoteVariable(
                name        = f'InputMidEqualizationTx[{11-(2*i+1)}]' if isTx else f'OutputDeEmphasisRx[{11-(2*i+1)}]',
                offset      = ((68+i) << 2),
                bitSize     = 4 if isTx else 3,
                bitOffset   = 0 if isTx else 1,
                mode        = rwType,
                description = 'TX mid-frequency input equalization control per channel (4-bit, 0=0dB, 1111b=4dB at 2GHz)' if isTx else 'RX output de-emphasis control per channel (3-bit, 000b=min, 111b=max)',
            ))


        if isTx:
            self.add(pr.RemoteVariable(
                name        = 'TxSquelchHysteresisDisableMsb',
                offset      = (74 << 2),
                bitSize     = 4,
                bitOffset   = 0,
                mode        = rwType,
                hidden      = True,
                description = 'TX squelch hysteresis disable per-channel flags MSB (channels 8-11)',
            ))

            self.add(pr.RemoteVariable(
                name        = 'TxSquelchHysteresisDisableLsb',
                offset      = (75 << 2),
                bitSize     = 8,
                bitOffset   = 0,
                mode        = rwType,
                hidden      = True,
                description = 'TX squelch hysteresis disable per-channel flags LSB (channels 0-7)',
            ))

            self.add(pr.LinkVariable(
                name         = 'TxSquelchHysteresisDisable',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                description  = 'TX squelch hysteresis disable bitmask: 1 = hysteresis disabled for that channel',
                linkedGet    = self._getLsbMsb,
                linkedSet    = self._setLsbMsb,
                dependencies = [self.TxSquelchHysteresisDisableLsb, self.TxSquelchHysteresisDisableMsb],
            ))

            self.add(pr.RemoteVariable(
                name        = 'TxInputSquelchHysteresisThreshold',
                offset      = (76 << 2),
                bitSize     = 3,
                bitOffset   = 0,
                mode        = rwType,
                hidden      = True,
                description = 'TX input squelch threshold level (3-bit, default 011b = 35 mVpp)',
            ))

        self.add(pr.RemoteVariable(
            name        = 'TxOutputDisableMsb' if isTx else 'RxOutputDisableMsb',
            offset      = (116 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = rwType,
            hidden      = True,
            description = 'Output disable per-channel flags MSB (channels 8-11): 1 = output disabled',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxOutputDisableLsb' if isTx else 'RxOutputDisableLsb',
            offset      = (117 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = rwType,
            hidden      = True,
            description = 'Output disable per-channel flags LSB (channels 0-7): 1 = output disabled',
        ))

        if isTx:
            self.add(pr.LinkVariable(
                name         = 'TxOutputDisable',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                description  = 'TX output disable per-channel bitmask: 1 = output disabled for that channel',
                linkedGet    = self._getLsbMsb,
                linkedSet    = self._setLsbMsb,
                dependencies = [self.TxOutputDisableLsb, self.TxOutputDisableMsb],
            ))
        else:
            self.add(pr.LinkVariable(
                name         = 'RxOutputDisable',
                mode         = rwType,
                disp         = '0x{:x}',
                typeStr      = 'UInt12',
                description  = 'RX output disable per-channel bitmask: 1 = output disabled for that channel',
                linkedGet    = self._getLsbMsb,
                linkedSet    = self._setLsbMsb,
                dependencies = [self.RxOutputDisableLsb, self.RxOutputDisableMsb],
            ))


    def _getLsbMsb(self, var, read):
        with self.root.updateGroup():
            lsb = var.dependencies[0].get(read=read)
            msb = var.dependencies[1].get(read=read)
            return lsb + 256 * msb

    def _setLsbMsb(self, var, value, write):
        with self.root.updateGroup():
            var.dependencies[0].set(value & 0xff, write=write)
            var.dependencies[1].set((value >> 8) & 0xff, write=write)
