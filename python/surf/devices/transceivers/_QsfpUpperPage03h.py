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
#               Upper Page 03h
#################################################
class QsfpUpperPage03h(pr.Device):
    def __init__(self, advDebug=False, **kwargs):
        super().__init__(**kwargs)

        ###############################################################
        # TODO: Add registers 128 ~ 223) - Free Side Device and Channel Thresholds
        ###############################################################

        self.add(pr.RemoteVariable(
            name         = 'MaxTxInputEqualization',
            description  = 'Max Tx input equalization supported (controls are in bytes 234-235 and codes are in Table 6-32)',
            offset       = (224 << 2),
            bitSize      = 4,
            bitOffset    = 4,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MaxRxOutputEmphasis',
            description  = 'Max Rx output emphasis supported (controls are in bytes 236-237 and codes are in Table 6-33)',
            offset       = (224 << 2),
            bitSize      = 4,
            bitOffset    = 0,
            mode         = 'RO',
        ))

        # 225 7-6 Reserved

        self.add(pr.RemoteVariable(
            name         = 'RxOutputEmphasisType',
            description  = 'Codes are in Table 6-29',
            offset       = (225 << 2),
            bitSize      = 2,
            bitOffset    = 4,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxOutputAmplitudeSupport',
            description  = 'Codes are in Table 6-29',
            offset       = (225 << 2),
            bitSize      = 4,
            bitOffset    = 0,
            mode         = 'RO',
        ))

        # 226 All Reserved

        if advDebug:

            self.add(pr.RemoteVariable(
                name        = 'ControllableHostSideFecSupport',
                description = 'See Page 03h, Byte 230, bit 7 for the control bit',
                offset      = (227 << 2),
                bitSize     = 1,
                bitOffset   = 7,
                mode        = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name        = 'ControllableMediaSideFecsupport',
                description = 'See Page 03h, Byte 230, bit 6 for the control bit',
                offset      = (227 << 2),
                bitSize     = 1,
                bitOffset   = 6,
                mode        = 'RO',
            ))

            # 227 5-4 Reserved

            self.add(pr.RemoteVariable(
                name        = 'TxForceSquelchImplemented',
                description = '0 = Tx Force Squelch not implemented, 1 = Tx Force Squelch implemented',
                offset      = (227 << 2),
                bitSize     = 1,
                bitOffset   = 3,
                mode        = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name        = 'RxLosLFastModeSupported',
                description = '0 = RxLOSL fast mode is not supported., 1 = RxLOSL fast mode supported',
                offset      = (227 << 2),
                bitSize     = 1,
                bitOffset   = 2,
                mode        = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name        = 'TxDisFastModeSupported',
                description = '0 = TxDis fast mode is not supported., 1 = TxDis fast mode supported',
                offset      = (227 << 2),
                bitSize     = 1,
                bitOffset   = 1,
                mode        = 'RO',
            ))

            # 227 0 Reserved

            self.add(pr.RemoteVariable(
                name        = 'MaximumTcStabilizationTime',
                description = 'Maximum time for the TC to reach its target working point under worst-case conditions (LSB = 1 s)',
                offset      = (228 << 2),
                bitSize     = 8,
                mode        = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name        = 'MaximumCtleSettlingTime',
                description = 'Maximum time needed by CTLE adaptive algorithm to converge to an appropriate value under worstcase conditions (LSB = 100 ms)',
                offset      = (229 << 2),
                bitSize     = 8,
                mode        = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name        = 'HostSideFecEnable',
                description = '0b = disable, 1b = enable. Default = 0',
                offset      = (230 << 2),
                bitSize     = 1,
                bitOffset   = 7,
                mode        = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name        = 'MediaSideFecEnable',
                description = '0b = disable, 1b = enable. Default = 0',
                offset      = (230 << 2),
                bitSize     = 1,
                bitOffset   = 6,
                mode        = 'RW',
            ))

            # 230 5-0 Reserved

        # 231 7-4 Reserved

        self.add(pr.RemoteVariable(
            name        = 'TxForceSquelch',
            description = '0b = No impact on Tx behavior 1b = Tx output squelched',
            offset      = (231 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
        ))

        # 232 All Reserved

        # 233 7-4 Reserved

        self.add(pr.RemoteVariable(
            name        = 'TxAEFreeze',
            description = 'Controls to freeze Tx input adaptive equalizers. 1 to freeze, else 0',
            offset      = (233 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxInputEqualizer[0]',
            description = 'Tx input equalizer controls (see Page 03h Byte 224 and Table 6-32)',
            offset      = (234 << 2),
            bitOffset   = 4,
            bitSize     = 4,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxInputEqualizer[1]',
            description = 'Tx input equalizer controls (see Page 03h Byte 224 and Table 6-32)',
            offset      = (234 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxInputEqualizer[2]',
            description = 'Tx input equalizer controls (see Page 03h Byte 224 and Table 6-32)',
            offset      = (235 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxInputEqualizer[3]',
            description = 'Tx input equalizer controls (see Page 03h Byte 224 and Table 6-32)',
            offset      = (235 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxOutputEqualizer[0]',
            description = 'Rx output emphasis controls (see Page 03h Byte 224 and Table 6-33)',
            offset      = (236 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxOutputEqualizer[1]',
            description = 'Rx output emphasis controls (see Page 03h Byte 224 and Table 6-33)',
            offset      = (236 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxOutputEqualizer[2]',
            description = 'Rx output emphasis controls (see Page 03h Byte 224 and Table 6-33)',
            offset      = (237 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxOutputEqualizer[3]',
            description = 'Rx output emphasis controls (see Page 03h Byte 224 and Table 6-33)',
            offset      = (237 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxOutputAmplitude[0]',
            description = 'Controls for Rx output differential amplitude. (See Table 6-31)',
            offset      = (238 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxOutputAmplitude[1]',
            description = 'Controls for Rx output differential amplitude. (See Table 6-31)',
            offset      = (238 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxOutputAmplitude[2]',
            description = 'Controls for Rx output differential amplitude. (See Table 6-31)',
            offset      = (239 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxOutputAmplitude[3]',
            description = 'Controls for Rx output differential amplitude. (See Table 6-31)',
            offset      = (239 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxSqDisable',
            description = 'Controls to disable squelch of Rx outputs 1 = Disabled, 0 = Enabled Default = 0',
            offset      = (240 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxSqDisable',
            description = 'Controls to disable squelch of Tx outputs 1 = Disabled, 0 = Enabled Default = 0',
            offset      = (240 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RxOutputDisable',
            description = 'Controls to disable Rx outputs 1 = Disabled, 0 = Enabled Default = 0',
            offset      = (241 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TxAdaptiveEqualization',
            description = 'Controls for Tx input adaptive equalizers. 1b=Enable (default) 0b=Disable (use manual EQ)',
            offset      = (241 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
        ))
