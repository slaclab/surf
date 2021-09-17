#-----------------------------------------------------------------------------
# Description:
#
# Based on SFF-8472 Rev 12.3.2 (15MARCH2021)
# https://members.snia.org/document/dl/27187
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

class Sfp(pr.Device):
    def __init__(self,**kwargs):
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
            enum         = transceivers.IdentifierDict,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Connector',
            description = 'Code for connector type',
            offset      = (2 << 2),
            bitSize     = 8,
            mode        = 'RO',
            enum        = transceivers.ConnectorDict,
        ))

        self.addRemoteVariables(
            name         = 'VendorNameRaw',
            description  = 'SFP vendor name (ASCII)',
            offset       = (20 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.String,
            number       = 16,
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

        self.addRemoteVariables(
            name         = 'VendorPnRaw',
            description  = 'Part number provided by SFP vendor (ASCII)',
            offset       = (40 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.String,
            number       = 16,
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
            offset       = (56 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.String,
            number       = 4,
            stride       = 4,
            hidden       = True,
        )

        self.add(pr.LinkVariable(
            name         = 'VendorRev',
            description  = 'Revision level for part number provided by vendor (ASCII)',
            mode         = 'RO',
            linkedGet    = transceivers.parseStrArrayByte,
            dependencies = [self.VendorRevRaw[x] for x in range(4)],
        ))

        ####################
        # EXTENDED ID FIELDS
        ####################

        self.addRemoteVariables(
            name         = 'VendorSnRaw',
            description  = 'Serial number provided by vendor (ASCII)',
            offset       = (68 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.String,
            number       = 16,
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
            offset       = (84 << 2),
            bitSize      = 8,
            mode         = 'RO',
            number       = 6,
            stride       = 4,
            base         = pr.String,
            hidden      = True,
        )

        self.add(pr.LinkVariable(
            name         = 'ManufactureDate',
            description  = 'Vendor\'s manufacturing date code (ASCII)',
            mode         = 'RO',
            linkedGet    = transceivers.getDate,
            dependencies = [self.DateCode[x] for x in range(6)],
        ))

        #####################################################
        #       Diagnostics: Data Fields – Address A2h      #
        #####################################################

        ######################################
        # DIAGNOSTIC AND CONTROL/STATUS FIELDS
        ######################################

        self.addRemoteVariables(
            name         = 'Diagnostics',
            description  = 'Diagnostic Monitor Data (internal or external)',
            offset       = ((256+96) << 2),
            bitSize      = 8,
            mode         = 'RO',
            number       = 14,
            stride       = 4,
            hidden       = True,
        )

        self.add(pr.LinkVariable(
            name         = 'Temperature',
            description  = 'Internally measured module temperature',
            mode         = 'RO',
            units        = 'degC',
            linkedGet    = transceivers.getTemp,
            disp         = '{:1.3f}',
            dependencies = [self.Diagnostics[0],self.Diagnostics[1]],
        ))

        self.add(pr.LinkVariable(
            name         = 'Vcc',
            description  = 'Internally measured supply voltage in transceiver',
            mode         = 'RO',
            units        = 'V',
            linkedGet    = transceivers.getVolt,
            disp         = '{:1.3f}',
            dependencies = [self.Diagnostics[2],self.Diagnostics[3]],
        ))

        self.add(pr.LinkVariable(
            name         = 'TxBias',
            description  = 'Internally measured TX Bias Current',
            mode         = 'RO',
            units        = 'mA',
            linkedGet    = transceivers.getTxBias,
            disp         = '{:1.3f}',
            dependencies = [self.Diagnostics[4],self.Diagnostics[5]],
        ))

        self.add(pr.LinkVariable(
            name         = 'TxPower',
            description  = 'Measured TX output power',
            mode         = 'RO',
            units        = 'dBm',
            linkedGet    = transceivers.getOpticalPwr,
            disp         = '{:1.3f}',
            dependencies = [self.Diagnostics[6],self.Diagnostics[7]],
        ))

        self.add(pr.LinkVariable(
            name         = 'RxPower',
            description  = 'Measured RX input power',
            mode         = 'RO',
            units        = 'dBm',
            linkedGet    = transceivers.getOpticalPwr,
            disp         = '{:1.3f}',
            dependencies = [self.Diagnostics[8],self.Diagnostics[9]],
        ))
