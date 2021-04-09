#-----------------------------------------------------------------------------
# Description:
#
# Based on SFF-8472 Rev 12.3.2 (15MARCH2021)
# https://members.snia.org/document/dl/27187
#
# Based on SFF-8024 Rev 4.8a (15JAN2021)
# https://members.snia.org/document/dl/26423
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

class Sff8472(pr.Device):
    def __init__(self,diagnostics=False,**kwargs):
        super().__init__(**kwargs)

        #####################################################
        #       Serial ID: Data Fields – Address A0h        #
        #####################################################

        ################
        # BASE ID FIELDS
        ################

        self.add(pr.RemoteVariable(
            name         = 'Identifier',
            description  = 'Type of serial transceiver',
            offset       = (0 << 2),
            bitSize      = 8,
            mode         = 'RO',
            enum        = {
                0x00: 'Unspecified',
                0x01: 'GBIC',
                0x02: 'Motherboard',
                0x03: 'SFP',
                0x04: 'XBI',
                0x05: 'XENPAK',
                0x06: 'XFP',
                0x07: 'XFF',
                0x08: 'XFP-E',
                0x09: 'XPAK',
                0x0A: 'X2',
                0x0B: 'DWDM-SFP',
                0x0C: 'QSFP',
                0x0D: 'QSFP+',
                0x0E: 'CXP',
                0x0F: 'HD-4X',
                0x10: 'HD-8X',
                0x11: 'QSFP28',
                0x12: 'CXP28',
                0x13: 'CDFP-Style1/2',
                0x14: 'HD-4X-Fanout',
                0x15: 'HD-8X-Fanout',
                0x16: 'CDFP-Style3',
                0x17: 'microQSFP',
                0x18: 'QSFP-DD',
                0x19: 'OSFP',
                0x1A: 'SFP-DD',
                0x1B: 'DSFP',
                0x1C: 'MiniLinkx4',
                0x1D: 'MiniLinkx8',
                0x1E: 'QSFP+',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExtIdentifier',
            description = 'Extended identifier of type of serial transceiver',
            offset      = (1 << 2),
            bitSize     = 8,
            mode        = 'RO',
            enum        = {
                0x00: 'Unspecified',
                0x01: '100G AOC (Active Optical Cable) or 25GAUI C2M AOC',
                0x02: '100GBASE-SR4 or 25GBASE-SR',
                0x03: '100GBASE-LR4 or 25GBASE-LR',
                0x04: '100GBASE-ER4 or 25GBASE-ER',
                0x05: '100GBASE-SR10',
                0x06: '100G CWDM4',
                0x07: '100G PSM4 Parallel SMF',
                0x08: '100G ACC (Active Copper Cable) or 25GAUI C2M ACC',
                0x09: 'Obsolete (assigned before 100G CWDM4 MSA required FEC)',
                0x0A: 'Reserved_0x0A',
                0x0B: '100GBASE-CR4, 25GBASE-CR CA-25G-L or 50GBASE-CR2 with RS (Clause91) FEC',
                0x0C: '25GBASE-CR CA-25G-S or 50GBASE-CR2 with BASE-R (Clause 74 Fire code) FEC',
                0x0D: '25GBASE-CR CA-25G-N or 50GBASE-CR2 with no FEC',
                0x0E: '10 Mb/s Single Pair Ethernet',
                0x0F: 'Reserved_0x0F',
                0x10: '40GBASE-ER4',
                0x11: '4 x 10GBASE-SR',
                0x12: '40G PSM4 Parallel SMF',
                0x13: 'G959.1 profile P1I1-2D1',
                0x14: 'G959.1 profile P1S1-2D2',
                0x15: 'G959.1 profile P1L1-2D2',
                0x16: '10GBASE-T with SFI electrical interface',
                0x17: '100G CLR4',
                0x18: '100G AOC or 25GAUI C2M AOC',
                0x19: '100G ACC or 25GAUI C2M ACC',
                0x1A: '100GE-DWDM2',
                0x1B: '100G 1550nm WDM (4 wavelengths)',
                0x1C: '10GBASE-T Short Reach',
                0x1D: '5GBASE-T',
                0x1E: '2.5GBASE-T',
                0x1F: '40G SWDM4',
                0x20: '100G SWDM4',
                0x21: '100G PAM4 BiDi',
                0x22: '4WDM-10 MSA',
                0x23: '4WDM-20 MSA',
                0x24: '4WDM-40 MSA',
                0x25: '100GBASE-DR',
                0x26: '100G-FR or 100GBASE-FR1 (Clause 140), CAUI-4 (no FEC)',
                0x27: '100G-LR or 100GBASE-LR1 (Clause 140), CAUI-4 (no FEC)',
                0x28: '100G-SR1 (P802.3db, Clause tbd), CAUI-4 (no FEC)',
                0x29: '100GBASE-SR1, 200GBASE-SR2 or 400GBASE-SR4',
                0x2A: '100GBASE-FR1',
                0x2B: '100GBASE-LR1',
                0x30: 'Active Copper Cable with 50GAUI, 100GAUI-2 or 200GAUI-4 C2M',
                0x31: 'Active Optical Cable with 50GAUI, 100GAUI-2 or 200GAUI-4 C2M',
                0x32: 'Active Copper Cable with 50GAUI, 100GAUI-2 or 200GAUI-4 C2M',
                0x33: 'Active Optical Cable with 50GAUI, 100GAUI-2 or 200GAUI-4 C2M',
                0x3F: '100GBASE-CR1, 200GBASE-CR2 or 400GBASE-CR4',
                0x40: '50GBASE-CR, 100GBASE-CR2, or 200GBASE-CR4',
                0x41: '50GBASE-SR, 100GBASE-SR2, or 200GBASE-SR4',
                0x42: '50GBASE-FR or 200GBASE-DR4',
                0x43: '200GBASE-FR4',
                0x44: '200G 1550 nm PSM4',
                0x45: '50GBASE-LR',
                0x46: '200GBASE-LR4',
                0x47: '400GBASE-DR4',
                0x48: '400GBASE-FR4',
                0x49: '400GBASE-LR4-6',
                0x7f: '256GFC-SW4',
                0x80: 'Capable of 64GFC',
                0x81: 'Capable of 128GFC',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'Connector',
            description = 'Code for connector type',
            offset      = (2 << 2),
            bitSize     = 8,
            mode        = 'RO',
            enum        = {
                0x00: 'Unspecified',
                0x01: 'SC',
                0x02: 'Fibre Channel Style 1 copper connector',
                0x03: 'Fibre Channel Style 2 copper connector',
                0x04: 'BNC/TNC',
                0x05: 'Fibre Channel coaxial headers',
                0x06: 'Fiber Jack',
                0x07: 'LC',
                0x08: 'MT-RJ',
                0x09: 'MU',
                0x0A: 'SG',
                0x0B: 'Optical pigtail',
                0x0C: 'MPO 1x12',
                0x0D: 'MPO 2x16',
                0x20: 'HSSDC II',
                0x21: 'Copper Pigtail',
                0x22: 'RJ45',
                0x23: 'No separable connector',
                0x24: 'MXC 2x16',
                0x25: 'CS optical connector',
                0x26: 'SN',
                0x27: 'MPO 2x12',
                0x28: 'MPO 1x16',
            },
        ))

        ## Any some point we should rewrite this variable to display the Transceiver Compliance Codes as enums
        self.addRemoteVariables(
            name         = 'Transceiver',
            description  = 'Code for electronic compatibility or optical compatibility',
            offset       = (3 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 8,
            stride       = 4,
        )

        self.add(pr.RemoteVariable(
            name        = 'Encoding',
            description = 'Code for serial encoding algorithm',
            offset      = (11 << 2),
            bitSize     = 8,
            mode        = 'RO',
            enum        = {
                0x0: 'Unspecified',
                0x1: '8B10B',
                0x2: '4B5B',
                0x3: 'NRZ',
                0x4: 'Manchester',
                0x5: 'SONET Scrambled',
                0x6: '64B/66B',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'BrNominal',
            description = 'The nominal bit rate (BR, nominal) is specified in units of 100 Megabits per second, rounded off to the nearest 100 Megabits per second. The bit rate includes those bits necessary to encode and delimit the signal as well as those bits carrying data information. A value of 0 indicates that the bit rate is not specified and must be determined from the transceiver technology. The actual information transfer rate will depend on the encoding of the data, as defined by the encoding value.',
            offset      = (12 << 2),
            bitSize     = 8,
            mode        = 'RO',
            base        = pr.UInt,
            units       = '100 Mbps',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RateId',
            description = 'The Rate Identifier refers to several (optional) industry standard definitions of Rate Select or Application Select control behaviors, intended to manage transceiver optimization for multiple operating rates.',
            offset      = (13 << 2),
            bitSize     = 8,
            mode        = 'RO',
            enum        = {
                0x0: 'Unspecified',
                0x1: 'SFF-8079 (4/2/1G Rate Select and AS0/AS1)',
                0x2: 'SFF-8431 (8/4/2G RX Rate Select Only)',
                0x3: 'Unspecified',
                0x4: 'SFF-8431 (8/4/2G TX Rate Select Only)',
                0x5: 'Unspecified',
                0x6: 'SFF-8431 (8/4/2G Independent TX and RX Rate Select)',
                0x7: 'Unspecified',
                0x8: 'FC-PI-5 (16/8/4G RX Rate Select Only) High=16G, Low=8/4G',
                0x9: 'Unspecified',
                0xA: 'FC-PI-5 (16/8/4G Independent TX and RX Rate Select) High=16G, Low=8/4G',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'Length9umKm',
            description = 'Link length supported for 9/125 um fiber',
            offset      = (14 << 2),
            bitSize     = 8,
            mode        = 'RO',
            base        = pr.UInt,
            units       = 'km',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Length9um',
            description = 'Link length supported for 9/125 um fiber',
            offset      = (15 << 2),
            bitSize     = 8,
            mode        = 'RO',
            base        = pr.UInt,
            units       = '100 m',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Length50um[0]',
            description = 'Link length supported for 50/125 um OM2 fiber',
            offset      = (16 << 2),
            bitSize     = 8,
            mode        = 'RO',
            base        = pr.UInt,
            units       = '10 m',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Length62um',
            description = 'Link length supported for 62.5/125 um OM1 fiber',
            offset      = (17 << 2),
            bitSize     = 8,
            mode        = 'RO',
            base        = pr.UInt,
            units       = '10 m',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LengthCopper',
            description = 'Link length supported for copper and Active Cable,',
            offset      = (18 << 2),
            bitSize     = 8,
            mode        = 'RO',
            base        = pr.UInt,
            units       = 'm',

        ))

        self.add(pr.RemoteVariable(
            name        = 'Length50um[1]',
            description = 'Link length supported for 50/125 um fiber',
            offset      = (19 << 2),
            bitSize     = 8,
            mode        = 'RO',
            base        = pr.UInt,
            units       = '10 m',
        ))

        self.addRemoteVariables(
            name         = 'VendorName',
            description  = 'SFP vendor name (ASCII)',
            offset       = (20 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 16,
            stride       = 4,
        )

        self.addRemoteVariables(
            name         = 'VendorOui',
            description  = 'SFP vendor IEEE company ID',
            offset       = (37 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 3,
            stride       = 4,
        )

        self.addRemoteVariables(
            name         = 'VendorPn',
            description  = 'Part number provided by SFP vendor (ASCII)',
            offset       = (40 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 16,
            stride       = 4,
        )

        self.addRemoteVariables(
            name         = 'VendorRev',
            description  = 'Revision level for part number provided by vendor (ASCII)',
            offset       = (56 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 4,
            stride       = 4,
        )

        self.addRemoteVariables(
            name         = 'Wavelength',
            description  = 'Laser wavelength',
            offset       = (60 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 2,
            stride       = 4,
        )

        self.add(pr.RemoteVariable(
            name        = 'CcBase',
            description = 'Check code for Base ID Fields (addresses 0 to 62)',
            offset      = (63 << 2),
            bitSize     = 8,
            mode        = 'RO',
            base        = pr.UInt,
        ))

        ####################
        # EXTENDED ID FIELDS
        ####################

        self.addRemoteVariables(
            name         = 'Options',
            description  = 'Indicates which optional transceiver signals are implemented',
            offset       = (64 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 2,
            stride       = 4,
        )

        self.add(pr.RemoteVariable(
            name        = 'BrMax',
            description = 'Upper bit rate margin',
            offset      = (66 << 2),
            bitSize     = 8,
            mode        = 'RO',
            base        = pr.UInt,
            units       = '%',
        ))

        self.add(pr.RemoteVariable(
            name        = 'BrMin',
            description = 'Lower bit rate margin',
            offset      = (67 << 2),
            bitSize     = 8,
            mode        = 'RO',
            base        = pr.UInt,
            units       = '%',
        ))

        self.addRemoteVariables(
            name         = 'VendorSn',
            description  = 'Serial number provided by vendor (ASCII)',
            offset       = (68 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 16,
            stride       = 4,
        )

        self.addRemoteVariables(
            name         = 'DateCode',
            description  = 'Vendor’s manufacturing date code',
            offset       = (84 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 8,
            stride       = 4,
        )

        self.add(pr.RemoteVariable(
            name        = 'DiagnosticMonitoringType',
            description = 'Indicates which type of diagnostic monitoring is implemented (if any) in the transceiver',
            offset      = (92 << 2),
            bitSize     = 8,
            mode        = 'RO',
            base        = pr.UInt,
        ))

        self.add(pr.RemoteVariable(
            name        = 'EnhancedOptions',
            description = 'Indicates which optional enhanced features are implemented (if any) in the transceiver',
            offset      = (93 << 2),
            bitSize     = 8,
            mode        = 'RO',
            base        = pr.UInt,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Sff8472Compliance',
            description = 'Indicates which revision of SFF-8472 the transceiver complies with',
            offset      = (94 << 2),
            bitSize     = 8,
            mode        = 'RO',
            base        = pr.UInt,
        ))

        self.add(pr.RemoteVariable(
            name        = 'CcExt',
            description = 'Check code for the Extended ID Fields (addresses 64 to 94)',
            offset      = (95 << 2),
            bitSize     = 8,
            mode        = 'RO',
            base        = pr.UInt,
        ))

        ###########################
        # VENDOR SPECIFIC ID FIELDS
        ###########################

        self.addRemoteVariables(
            name         = 'VendorSpecificA',
            description  = 'Vendor Specific EEPROM',
            offset       = (96 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.UInt,
            number       = 32,
            stride       = 4,
        )

        #####################################################
        #       Diagnostics: Data Fields – Address A2h      #
        #####################################################

        ######################################
        # DIAGNOSTIC AND CONTROL/STATUS FIELDS
        ######################################
        if diagnostics:

            self.addRemoteVariables(
                name         = 'ExtCalConstants',
                description  = 'Diagnostic Calibration Constants for Ext Cal',
                offset       = ((256+56) << 2),
                bitSize      = 8,
                mode         = 'RO',
                base         = pr.UInt,
                number       = 36,
                stride       = 4,
            )

            self.add(pr.RemoteVariable(
                name        = 'CcDmi',
                description = 'Check Code for Base Diagnostic Fields 0-94',
                offset      = ((256+95) << 2),
                bitSize     = 8,
                mode        = 'RO',
                base        = pr.UInt,
            ))

            self.addRemoteVariables(
                name         = 'Diagnostics',
                description  = 'Diagnostic Monitor Data (internal or external)',
                offset       = ((256+96) << 2),
                bitSize      = 8,
                mode         = 'RO',
                base         = pr.UInt,
                number       = 10,
                stride       = 4,
            )

            self.add(pr.RemoteVariable(
                name        = 'StatusControl',
                description = 'Optional Status and Control Bits',
                offset      = ((256+110) << 2),
                bitSize     = 8,
                mode        = 'RO',
                base        = pr.UInt,
            ))

            self.addRemoteVariables(
                name         = 'AlarmFlags',
                description  = 'Diagnostic Alarm Flags Status Bits',
                offset       = ((256+112) << 2),
                bitSize      = 8,
                mode         = 'RO',
                base         = pr.UInt,
                number       = 2,
                stride       = 4,
            )

            self.addRemoteVariables(
                name         = 'WarningFlags',
                description  = 'Diagnostic Warning Flag Status Bits',
                offset       = ((256+116) << 2),
                bitSize      = 8,
                mode         = 'RO',
                base         = pr.UInt,
                number       = 2,
                stride       = 4,
            )

            self.addRemoteVariables(
                name         = 'ExtStatusControl',
                description  = 'Extened Module Control and Status Bits',
                offset       = ((256+118) << 2),
                bitSize      = 8,
                mode         = 'RO',
                base         = pr.UInt,
                number       = 2,
                stride       = 4,
            )

            ######################################
            # GENERAL USE FIELDS
            ######################################
            self.addRemoteVariables(
                name         = 'DiagnosticsVendorSpecific',
                description  = 'Diagnostics: Data Field Vendor Specific EEPROM',
                offset       = ((256+120) << 2),
                bitSize      = 8,
                mode         = 'RO',
                base         = pr.UInt,
                number       = 8,
                stride       = 4,
            )

            self.addRemoteVariables(
                name         = 'UserEeprom',
                description  = 'User writeable non-volatile memory',
                offset       = ((256+128) << 2),
                bitSize      = 8,
                mode         = 'RW',
                base         = pr.UInt,
                number       = 120,
                stride       = 4,
                hidden       = True,
            )

            self.addRemoteVariables(
                name         = 'VendorControl',
                description  = 'Vendor specific control addresses',
                offset       = ((256+248) << 2),
                bitSize      = 8,
                mode         = 'RO',
                base         = pr.UInt,
                number       = 8,
                stride       = 4,
            )
