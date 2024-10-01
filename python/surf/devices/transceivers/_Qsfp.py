#-----------------------------------------------------------------------------
# Description:
#
# Based on SFF-8636 Rev Rev 2.10a (24SEPT2019)
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

class Qsfp(pr.Device):
    def __init__(self,**kwargs):
        super().__init__(**kwargs)

        ################
        # Lower Page 00h
        ################

        self.addRemoteVariables(
            name         = 'DevMon',
            description  = 'Diagnostic Monitor Data',
            offset       = (22 << 2),
            bitSize      = 8,
            mode         = 'RO',
            number       = 6,
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
            dependencies = [self.DevMon[0],self.DevMon[1]],
        ))

        self.add(pr.LinkVariable(
            name         = 'Vcc',
            description  = 'Internally measured supply voltage in transceiver',
            mode         = 'RO',
            units        = 'V',
            linkedGet    = transceivers.getVolt,
            disp         = '{:1.3f}',
            dependencies = [self.DevMon[4],self.DevMon[5]],
        ))

        self.addRemoteVariables(
            name         = 'RxPwrRaw',
            description  = 'Rx input power',
            offset       = (34 << 2),
            bitSize      = 8,
            mode         = 'RO',
            number       = 8,
            stride       = 4,
            hidden       = True,
        )

        for i in range(4):
            self.add(pr.LinkVariable(
                name         = f'RxPower[{i}]',
                description  = 'Measured RX input power',
                mode         = 'RO',
                units        = 'dBm',
                linkedGet    = transceivers.getOpticalPwr,
                disp         = '{:1.3f}',
                dependencies = [self.RxPwrRaw[2*i+0],self.RxPwrRaw[2*i+1]],
            ))


        self.addRemoteVariables(
            name         = 'TxBiasRaw',
            description  = 'Tx bias current',
            offset       = (42 << 2),
            bitSize      = 8,
            mode         = 'RO',
            number       = 8,
            stride       = 4,
            hidden       = True,
        )

        for i in range(4):
            self.add(pr.LinkVariable(
                name         = f'TxBias[{i}]',
                description  = 'Internally measured TX Bias Current',
                mode         = 'RO',
                units        = 'mA',
                linkedGet    = transceivers.getTxBias,
                disp         = '{:1.3f}',
                dependencies = [self.TxBiasRaw[2*i+0],self.TxBiasRaw[2*i+1]],
            ))

        self.addRemoteVariables(
            name         = 'TxPwrRaw',
            description  = 'Tx output power',
            offset       = (50 << 2),
            bitSize      = 8,
            mode         = 'RO',
            number       = 8,
            stride       = 4,
            hidden       = True,
        )

        for i in range(4):
            self.add(pr.LinkVariable(
                name         = f'TxPower[{i}]',
                description  = 'Measured TX output power',
                mode         = 'RO',
                units        = 'dBm',
                linkedGet    = transceivers.getOpticalPwr,
                disp         = '{:1.3f}',
                dependencies = [self.TxPwrRaw[2*i+0],self.TxPwrRaw[2*i+1]],
            ))

        for i in range(4):
            self.add(pr.RemoteVariable(
                name         = f'TxDisable[{i}]',
                description  = 'Tx_Disable bit that allows software disable of transmitters, Writing 1 disables the laser of the channel',
                offset       = (86 << 2),
                bitSize      = 1,
                bitOffset    = i,
                mode         = 'RW',
                base         = pr.Bool,
            ))

        ################
        # Upper Page 00h
        ################

        self.add(pr.RemoteVariable(
            name         = 'Identifier',
            description  = 'Type of serial transceiver',
            offset       = (128 << 2),
            bitSize      = 8,
            mode         = 'RO',
            enum         = transceivers.IdentifierDict,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Connector',
            description = 'Code for connector type',
            offset      = (130 << 2),
            bitSize     = 8,
            mode        = 'RO',
            enum        = transceivers.ConnectorDict,
        ))

        self.addRemoteVariables(
            name         = 'VendorNameRaw',
            description  = 'SFP vendor name (ASCII)',
            offset       = (148 << 2),
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
            offset       = (168 << 2),
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
            offset       = (184 << 2),
            bitSize      = 8,
            mode         = 'RO',
            base         = pr.String,
            number       = 2,
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

        self.addRemoteVariables(
            name         = 'VendorSnRaw',
            description  = 'Serial number provided by vendor (ASCII)',
            offset       = (196 << 2),
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
            offset       = (212 << 2),
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
            dependencies = [self.DateCode[x] for x in [0,1,4,5,2,3] ],
        ))

        ###############################################################
        # TODO: Need to add the ability in the future to use
        # Page Select Byte (address=127) for other optional page access
        ###############################################################
