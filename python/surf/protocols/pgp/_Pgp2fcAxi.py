#-----------------------------------------------------------------------------
# Title      : PyRogue _pgp2fcaxi Module
#-----------------------------------------------------------------------------
# Description:
# PyRogue _pgp2fcaxi Module
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

class Pgp2fcAxi(pr.Device):
    def __init__(self,
                 description = "Configuration and status of a PGP2FC link",
                 statusCountBits = 32,
                 errorCountBits  = 4,
                 writeEn = True,
                 **kwargs):

        super().__init__(description=description, **kwargs)

        self.writeEn = writeEn

        if writeEn:
            self.add(pr.RemoteVariable(
                name        = "Loopback",
                description = "GT Loopback Mode",
                offset      = 0xC,
                bitSize     = 3,
                bitOffset   = 0,
                mode        = "RW",
                base        = pr.UInt,
                enum = {0: 'No',
                        1: 'Near-end PCS',
                        2: 'Near-end PMA',
                        4: 'Far-end PMA',
                        6: 'Far-end PCS'},
            ))

            self.add(pr.RemoteVariable(
                name        = "LocData",
                description = "Sideband data to transmit",
                offset      = 0x10,
                bitSize     = 8,
                bitOffset   = 0,
                mode        = "RW",
                base        = pr.UInt,
            ))

            self.add(pr.RemoteVariable(
                name        = "LocDataEn",
                description = "Enable sideband data to transmit",
                offset      = 0x10,
                bitSize     = 1,
                bitOffset   = 8,
                mode        = "RW",
                base        = pr.Bool,
            ))

            self.add(pr.RemoteVariable(
                name        = "AutoStatus",
                description = "Auto Status Send Enable (PPI)",
                offset      = 0x14,
                bitSize     = 1,
                bitOffset   = 0,
                mode        = "RW",
                base        = pr.Bool,
            ))

        self.add(pr.RemoteVariable(
            name        = "RxPhyReady",
            offset      = 0x20,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = "RO",
            base        = pr.Bool,
            description = "RX Phy is Ready",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name        = "TxPhyReady",
            offset      = 0x20,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = "RO",
            base        = pr.Bool,
            description = "TX Phy is Ready",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name        = "RxLocalLinkReady",
            offset      = 0x20,
            bitSize     = 1,
            bitOffset   = 2,
            mode        = "RO",
            base        = pr.Bool,
            description = "Rx Local Link Ready",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name        = "RxRemLinkReady",
            offset      = 0x20,
            bitSize     = 1,
            bitOffset   = 3,
            mode        = "RO",
            base        = pr.Bool,
            description = "Rx Remote Link Ready",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name        = "TxLinkReady",
            offset      = 0x20,
            bitSize     = 1,
            bitOffset   = 4,
            mode        = "RO",
            base        = pr.Bool,
            description = "Tx Link Ready",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name        = "RxRemPause",
            offset      = 0x20,
            bitSize     = 4,
            bitOffset   = 12,
            mode        = "RO",
            base        = pr.UInt,
            description = "RX Remote Pause Asserted",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name        = "TxLocPause",
            offset      = 0x20,
            bitSize     = 4,
            bitOffset   = 16,
            mode        = "RO",
            base        = pr.UInt,
            description = "Tx Local Pause Asserted",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name        = "RxRemOverflow",
            offset      = 0x20,
            bitSize     = 4,
            bitOffset   = 20,
            mode        = "RO",
            base        = pr.UInt,
            description = "Received remote overflow flag",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name        = "TxLocOverflow",
            offset      = 0x20,
            bitSize     = 4,
            bitOffset   = 24,
            mode        = "RO",
            base        = pr.UInt,
            description = "Received local overflow flag",
            pollInterval = 1,
        ))


        self.add(pr.RemoteVariable(
            name        = "RxRemLinkData",
            offset      = 0x24,
            bitSize     = 8,
            bitOffset   = 0,
            mode        = "RO",
            base        = pr.UInt,
            description = "",
        ))

        countVars = [
            ["RxCellErrorCount",errorCountBits],
            ["RxLinkDownCount",errorCountBits],
            ["RxLinkErrorCount",errorCountBits],
            ["RxRemOverflow0Count",errorCountBits],
            ["RxRemOverflow1Count",errorCountBits],
            ["RxRemOverflow2Count",errorCountBits],
            ["RxRemOverflow3Count",errorCountBits],
            ["RxFrameErrorCount",errorCountBits],
            ["RxFrameCount",statusCountBits],
            ["TxLocOverflow0Count",errorCountBits],
            ["TxLocOverflow1Count",errorCountBits],
            ["TxLocOverflow2Count",errorCountBits],
            ["TxLocOverflow3Count",errorCountBits],
            ["TxFrameErrorCount",errorCountBits],
            ["TxFrameCount",statusCountBits],
        ]

        for offset, idx in enumerate(countVars):
            self.add(pr.RemoteVariable(
                name        = idx[0],
                offset      = ((offset*4)+0x28),
                disp        = '{:d}',
                bitSize     = idx[1],
                bitOffset   = 0,
                mode        = "RO",
                base        = pr.UInt,
                pollInterval = 1,
            ))

        self.add(pr.RemoteVariable(
            name        = "TxFcSentCount",
            offset      = 0x70,
            disp        = '{:d}',
            bitSize     = errorCountBits,
            bitOffset   = 0,
            mode        = "RO",
            base        = pr.UInt,
            pollInterval = 1
        ))

        self.add(pr.RemoteVariable(
            name        = "RxFcRecvCount",
            offset      = 0x74,
            disp        = '{:d}',
            bitSize     = errorCountBits,
            bitOffset   = 0,
            mode        = "RO",
            base        = pr.UInt,
            pollInterval = 1
        ))

        self.add(pr.RemoteVariable(
            name        = "RxFcErrCount",
            offset      = 0x78,
            disp        = '{:d}',
            bitSize     = errorCountBits,
            bitOffset   = 0,
            mode        = "RO",
            base        = pr.UInt,
            pollInterval = 1
        ))

        self.add(pr.RemoteVariable(
            name        = "RxRemLinkReadyCount",
            offset      = 0x7C,
            disp        = '{:d}',
            bitSize     = errorCountBits,
            bitOffset   = 0,
            mode        = "RO",
            base        = pr.UInt,
            pollInterval = 1
        ))

#         self.add(pr.RemoteVariable(
#             name        = "ProtocolErrorCount",
#             offset      = 0xB0,
#             disp        = '{:d}',
#             bitSize     = errorCountBits,
#             bitOffset   = 0,
#             mode        = "RO",
#             base        = pr.UInt,
#             pollInterval = 1
#         ))

#         self.add(pr.RemoteCommand(
#             name        = 'AlignReset',
#             offset      = 0xA0,
#             bitSize     = 1,
#             bitOffset   = 0,
#             function    = pr.BaseCommand.toggle,
#         ))

#         self.add(pr.RemoteVariable(
#             name        = "AlignOverride",
#             offset      = 0xA0,
#             bitSize     = 1,
#             bitOffset   = 1,
#             mode        = "RW",
#             base        = pr.Bool,
#         ))

        # self.add(pr.RemoteVariable(
        #     name        = "AlignSlide",
        #     offset      = 0xA4,
        #     bitSize     = 1,
        #     bitOffset   = 0,
        #     mode        = "WO",
        #     base        = pr.Bool,
        # ))

#         self.add(pr.RemoteCommand(
#             name        = 'AlignSlide',
#             offset      = 0xA4,
#             bitSize     = 1,
#             bitOffset   = 0,
#             function    = pr.BaseCommand.touchZero,
#         ))

#         self.add(pr.RemoteVariable(
#             name        = "Aligned",
#             offset      = 0xA8,
#             bitSize     = 1,
#             bitOffset   = 0,
#             mode        = "RO",
#             base        = pr.Bool,
#         ))

#         self.add(pr.RemoteVariable(
#             name        = "AlignSlideDone",
#             offset      = 0xA8,
#             bitSize     = 1,
#             bitOffset   = 1,
#             mode        = "RO",
#             base        = pr.Bool,
#         ))

#         self.add(pr.RemoteVariable(
#             name        = "AlignPhase",
#             offset      = 0xA8,
#             bitSize     = 1,
#             bitOffset   = 2,
#             mode        = "RO",
#             base        = pr.UInt,
#         ))

#         self.add(pr.RemoteVariable(
#             name        = "AlignPhaseDone",
#             offset      = 0xA8,
#             bitSize     = 1,
#             bitOffset   = 3,
#             mode        = "RO",
#             base        = pr.Bool,
#         ))

        # self.add(pr.RemoteVariable(
        #     name        = "AlignPhaseReq",
        #     offset      = 0xAC,
        #     bitSize     = 1,
        #     bitOffset   = 0,
        #     mode        = "WO",
        #     base        = pr.Bool,
        # ))

#         self.add(pr.RemoteCommand(
#             name        = 'AlignPhaseReq',
#             offset      = 0xAC,
#             bitSize     = 1,
#             bitOffset   = 0,
#             function    = pr.BaseCommand.touchZero,
#         ))

        self.add(pr.RemoteCommand(
            name        = 'CountReset',
            offset      = 0x00,
            bitSize     = 1,
            bitOffset   = 0,
            function    = pr.BaseCommand.toggle,
        ))

        self.add(pr.RemoteCommand(
            name        = "ResetRx",
            offset      = 0x04,
            bitSize     = 1,
            bitOffset   = 0,
            function    = pr.BaseCommand.toggle,
        ))

        self.add(pr.RemoteCommand(
            name        = 'ResetTx',
            offset      = 0x04,
            bitSize     = 1,
            bitOffset   = 1,
            function    = pr.BaseCommand.toggle,
        ))

        self.add(pr.RemoteCommand(
            name = 'ResetGt',
            offset = 0x04,
            bitSize = 1,
            bitOffset =2,
            function = pr.BaseCommand.toggle,
        ))

        if writeEn:
            self.add(pr.RemoteCommand(
                name        = "Flush",
                offset      = 0x08,
                bitSize     = 1,
                bitOffset   = 0,
                function    = pr.BaseCommand.toggle,
            ))


        self.add(pr.RemoteVariable(
            name         = "RxClkFreqRaw",
            offset       = 0x64,
            bitSize      = 32,
            mode         = "RO",
            base         = pr.UInt,
            hidden       = True,
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "TxClkFreqRaw",
            offset       = 0x68,
            bitSize      = 32,
            mode         = "RO",
            base         = pr.UInt,
            hidden       = True,
            pollInterval = 1,
        ))

        def convtMHz(var, read):
            return var.dependencies[0].get(read=read) * 1.0E-6

        self.add(pr.LinkVariable(
            name         = "RxClkFreq",
            mode         = "RO",
            units        = "MHz",
            disp         = '{:0.6f}',
            dependencies = [self.RxClkFreqRaw],
            linkedGet    = convtMHz,
        ))

        self.add(pr.LinkVariable(
            name         = "TxClkFreq",
            mode         = "RO",
            units        = "MHz",
            disp         = '{:0.6f}',
            dependencies = [self.TxClkFreqRaw],
            linkedGet    = convtMHz,
        ))

    def initialize(self):
        if self.writeEn:
            self.Flush()

    def hardReset(self):
        if self.writeEn:
            self.ResetTx()
            self.ResetRx()

    def countReset(self):
        self.CountReset()
