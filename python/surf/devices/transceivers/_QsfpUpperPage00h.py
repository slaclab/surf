#-----------------------------------------------------------------------------
# Description:
#
# Based on SFF-8636 Rev Rev 2.11 (03JAN2023)
# https://members.snia.org/document/dl/26418
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

#################################################
#               Upper Page 00h
#################################################
class QsfpUpperPage00h(pr.Device):
    def __init__(self, advDebug=False, **kwargs):
        super().__init__(**kwargs)

        if advDebug:

            self.add(pr.RemoteVariable(
                name         = 'UppperIdentifier',
                description  = 'Type of serial transceiver',
                offset       = (128 << 2),
                bitSize      = 5,
                mode         = 'RO',
                enum         = transceivers.IdentifierDict,
            ))

            self.add(pr.RemoteVariable(
                name         = 'LowPowerClass',
                description  = 'Extended Identifier of free side device. Includes power classes, CLEI codes, CDR capability (See Table 6-16)',
                offset       = (129 << 2),
                bitSize      = 2,
                bitOffset    = 6,
                mode         = 'RO',
                enum         = {
                    0x0: 'Power Class 1 (1.5 W max.)',
                    0x1: 'Power Class 2 (2.0 W max.)',
                    0x2: 'Power Class 3 (2.5 W max.)',
                    0x3: 'Power Class 4 (3.5 W max.) and Power Classes 5, 6 or 7',
                },
            ))

            self.add(pr.RemoteVariable(
                name         = 'PowerClass8Impl',
                description  = 'Power Class 8 implemented (Max power declared in byte 107)',
                offset       = (129 << 2),
                bitSize      = 1,
                bitOffset    = 5,
                mode         = 'RO',
                base         = pr.Bool,
            ))

            self.add(pr.RemoteVariable(
                name         = 'CleiCodePresent',
                description  = 'CLEI code present in Page 02h',
                offset       = (129 << 2),
                bitSize      = 1,
                bitOffset    = 4,
                mode         = 'RO',
                base         = pr.Bool,
            ))

        self.add(pr.RemoteVariable(
            name         = 'TxCdrPresent',
            description  = '0: No CDR in Tx, 1: CDR present in Tx',
            offset       = (129 << 2),
            bitSize      = 1,
            bitOffset    = 3,
            mode         = 'RO',
            base         = pr.Bool,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxCdrPresent',
            description  = '0: No CDR in Rx, 1: CDR present in Rx',
            offset       = (129 << 2),
            bitSize      = 1,
            bitOffset    = 2,
            mode         = 'RO',
            base         = pr.Bool,
        ))

        if advDebug:
            self.add(pr.RemoteVariable(
                name         = 'HighPowerClass',
                description  = 'See Byte 93 bit 2 to enable.',
                offset       = (129 << 2),
                bitSize      = 2,
                bitOffset    = 0,
                mode         = 'RO',
                enum         = {
                    0x0: 'Power Classes 1 to 4',
                    0x1: 'Power Class 5 (4.0 W max.) See Byte 93 bit 2 to enable.',
                    0x2: 'Power Class 6 (4.5 W max.) See Byte 93 bit 2 to enable.',
                    0x3: 'Power Class 7 (5.0 W max.) See Byte 93 bit 2 to enable',
                },
            ))

        self.add(pr.RemoteVariable(
            name        = 'Connector',
            description = 'Code for connector type',
            offset      = (130 << 2),
            bitSize     = 8,
            mode        = 'RO',
            enum        = transceivers.ConnectorDict,
        ))

        ###############################################################
        # TODO: Add registers 131 ~ 138
        ###############################################################

        if advDebug:

            self.add(pr.RemoteVariable(
                name        = 'Encoding',
                description = 'Code for serial encoding algorithm. (See SFF-8024 Transceiver Management)',
                offset      = (139 << 2),
                bitSize     = 8,
                mode        = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name        = 'SignalingRate',
                description = 'Nominal signaling rate, units of 100 MBd. For rate > 25.4 GBd, set this to FFh and use Byte 222.',
                offset      = (140 << 2),
                bitSize     = 8,
                mode        = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name        = 'ExtendedRateSelect',
                description = 'Tags for extended rate select compliance. See Table 6-18.',
                offset      = (141 << 2),
                bitSize     = 8,
                mode        = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name        = 'Length_SMF',
                description = 'Link length supported at the signaling rate in byte 140 or page 00h byte 222, for SMF fiber in km *. A value of 1 shall be used for reaches from 0 to 1 km.',
                offset      = (142 << 2),
                bitSize     = 8,
                mode        = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name        = 'Length_OM3',
                description = 'Link length supported at the signaling rate in byte 140 or page 00h byte 222, for EBW 50/125 um fiber (OM3), units of 2 m',
                offset      = (143 << 2),
                bitSize     = 8,
                mode        = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name        = 'Length_OM2',
                description = 'Link length supported at the signaling rate in byte 140 or page 00h byte 222, for 62.5/125 um fiber (OM1), units of 1 m *, or copper cable attenuation in dB at 25.78 GHz.',
                offset      = (145 << 2),
                bitSize     = 8,
                mode        = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name        = 'Length_OM1',
                description = 'Link length supported at the signaling rate in byte 140 or page 00h byte 222, for 50/125 um fiber (OM2), units of 1 m',
                offset      = (144 << 2),
                bitSize     = 8,
                mode        = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name        = 'Length_Copper',
                description = 'Length of passive or active cable assembly (units of 1 m) or link length supported at the signaling rate in byte 140 or page 00h byte 222, for OM4 50/125 um fiber (units of 2 m) as indicated by Byte 147. See 6.3.12',
                offset      = (146 << 2),
                bitSize     = 8,
                mode        = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name        = 'DeviceTechnology',
                description = 'Device technology (Table 6-19 and Table 6-20).',
                offset      = (147 << 2),
                bitSize     = 8,
                mode        = 'RO',
            ))

        self.addRemoteVariables(
            name         = 'VendorNameRaw',
            description  = 'SFP vendor name (ASCII)',
            offset       = (148 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.String,
            number       = 16,  # BYTE148:BYTE163
            stride       = 4,
            hidden       = True,
        )

        self.add(pr.LinkVariable(
            name         = 'VendorName',
            description  = 'SFP vendor name (ASCII)',
            mode         = 'RO',
            linkedGet    = transceivers.parseStrArrayByte,
            dependencies = [self.VendorNameRaw[x] for x in range(16)],
        ))

        # TODO: 164 1 Extended Module Extended Module codes for InfiniBand (See Table 6-21 )
        # TODO: 165-167 3 Vendor OUI Free side device vendor IEEE company ID

        self.addRemoteVariables(
            name         = 'VendorPnRaw',
            description  = 'Part number provided by SFP vendor (ASCII)',
            offset       = (168 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.String,
            number       = 16, # BYTE168:BYTE183
            stride       = 4,
            hidden       = True,
        )

        self.add(pr.LinkVariable(
            name         = 'VendorPn',
            description  = 'Part number provided by SFP vendor (ASCII)',
            mode         = 'RO',
            linkedGet    = transceivers.parseStrArrayByte,
            dependencies = [self.VendorPnRaw[x] for x in range(16)],
        ))

        self.addRemoteVariables(
            name         = 'VendorRevRaw',
            description  = 'Revision level for part number provided by vendor (ASCII)',
            offset       = (184 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.String,
            number       = 2, # BYTE184:BYTE185
            stride       = 4,
            hidden       = True,
        )

        self.add(pr.LinkVariable(
            name         = 'VendorRev',
            description  = 'Revision level for part number provided by vendor (ASCII)',
            mode         = 'RO',
            linkedGet    = transceivers.parseStrArrayByte,
            dependencies = [self.VendorRevRaw[x] for x in range(2)],
        ))

        # TODO: 186-187 2 Wavelength or Copper Cable Attenuation
        # TODO: 188-189 2 Wavelength tolerance or Copper Cable Attenuation
        # TODO: 190 1 Max case temp. Maximum case temperature
        # TODO: 191 1 CC_BASE Check code for base ID fields (Bytes 128-190)
        # TODO: 192 1 Link codes Extended Specification Compliance Codes (See SFF-8024)
        # TODO: 193-195 3 Options Optional features implemented. See Table 6-22.

        self.addRemoteVariables(
            name         = 'VendorSnRaw',
            description  = 'Serial number provided by vendor (ASCII)',
            offset       = (196 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.String,
            number       = 16, # BYTE196:BYTE211
            stride       = 4,
            hidden       = True,
        )

        self.add(pr.LinkVariable(
            name         = 'VendorSn',
            description  = 'Serial number provided by vendor (ASCII)',
            mode         = 'RO',
            linkedGet    = transceivers.parseStrArrayByte,
            dependencies = [self.VendorSnRaw[x] for x in range(16)],
        ))

        self.addRemoteVariables(
            name         = 'DateCode',
            description  = 'Vendor\'s manufacturing date code (ASCII)',
            offset       = (212 << 2),
            bitSize      = 8,
            mode         = 'RO',
            number       = 6, # BYTE212:BYTE219
            stride       = 4,
            base         = pr.String,
            hidden       = True,
        )

        self.add(pr.LinkVariable(
            name         = 'ManufactureDate',
            description  = 'Vendor\'s manufacturing date code (ASCII)',
            mode         = 'RO',
            linkedGet    = transceivers.getDate,
            dependencies = [self.DateCode[x] for x in [0,1,4,5,2,3] ],
        ))

        # TODO: 220 1 Diagnostic Monitoring Type Indicates which type of diagnostic monitoring is implemented (if any) in the free side device. Bit 1,0 Reserved. See Table 6-24.
        # TODO: 221 1 Enhanced Options Indicates which optional enhanced features are implemented in the free side device. See Table 6-24.
        # TODO: 222 1 Baud Rate, nominal Nominal baud rate per channel, units of 250 MBd. Complements Byte 140. See Table 6-26.
        # TODO: 223 1 CC_EXT Check code for the Extended ID Fields (Bytes 192-222)
        # TODO: 224-255 32 Vendor Specific Vendor Specific EEPROM
