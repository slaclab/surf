#-----------------------------------------------------------------------------
# Title      : PyRogue TenGigEthReg
#-----------------------------------------------------------------------------
# Description:
# PyRogue TenGigEthReg
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

from surf.ethernet import udp

class TenGigEthReg(pr.Device):
    def __init__(self, writeEn=False, **kwargs):
        super().__init__(**kwargs)

        ##############################
        # Variables
        ##############################

        allowAccess = 'RW' if writeEn else 'RO'

        statusName = [
            'phyReady',  # 0
            'rxPause',   # 1
            'txPause',   # 2
            'rxFrame',   # 3
            'rxOverFlow',# 4
            'rxCrcError',# 5
            'txFrame',   # 6
            'txUnderRun',# 7
            'txNotReady',# 8
            'txDisable', # 9
            'sigDet',    # 10
            'txFault',   # 11
            'gtTxRst',   # 12
            'gtRxRst',   # 13
            'rstCntDone',# 14
            'qplllock',  # 15
            'txRstdone', # 16
            'rxRstdone', # 17
            'txUsrRdy',  # 18
        ]

        for i in range(19):

            self.add(pr.RemoteVariable(
                name         = statusName[i]+'Cnt',
                description  = f'Count of {statusName[i]} events',
                offset       = 4*i,
                mode         = 'RO',
                pollInterval = 1,
            ))

        for i in range(19):
            self.add(pr.RemoteVariable(
                name         = statusName[i],
                description  = f'Current status of {statusName[i]}',
                offset       = 0x100,
                mode         = 'RO',
                bitSize      = 1,
                bitOffset    = i,
                pollInterval = 1,
            ))

        self.add(pr.RemoteVariable(
            name         = 'PhyStatus',
            description  = 'PHY status register bits',
            offset       =  0x108,
            bitSize      =  8,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'MacAddress',
            description  = 'MacAddress (big-Endian configuration)',
            offset       = 0x200,
            bitSize      = 48,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'MAC_ADDRESS',
            description  = 'MacAddress (human readable)',
            mode         = 'RO',
            linkedGet    = udp.getMacValue,
            dependencies = [self.variables['MacAddress']],
        ))

        self.add(pr.RemoteVariable(
            name         = 'PauseTime',
            description  = 'Pause frame quanta value',
            offset       = 0x21C,
            bitSize      = 16,
            mode         = allowAccess,
        ))

        self.add(pr.RemoteVariable(
            name         = 'FilterEnable',
            description  = 'Enable MAC address filtering',
            offset       = 0x228,
            bitSize      = 1,
            mode         = allowAccess,
        ))

        self.add(pr.RemoteVariable(
            name         = 'PauseEnable',
            description  = 'Enable flow control pause frames',
            offset       = 0x22C,
            bitSize      = 1,
            mode         = allowAccess,
        ))

        self.add(pr.RemoteVariable(
            name         = 'PauseFifoThreshold',
            description  = 'FIFO threshold level for triggering pause frames',
            offset       = 0x800,
            bitSize      = 16,
            mode         = allowAccess,
        ))

        if writeEn:

            self.add(pr.RemoteVariable(
                name         = 'pma_pmd_type',
                description  = 'PMA/PMD type selection for 10GigE PHY',
                offset       =  0x230,
                bitSize      =  3,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = 'pma_loopback',
                description  = 'Enable PMA loopback mode',
                offset       =  0x234,
                bitSize      =  1,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = 'pma_reset',
                description  = 'Issue a reset to the PMA layer',
                offset       =  0x238,
                bitSize      =  1,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = 'pcs_loopback',
                description  = 'Enable PCS loopback mode',
                offset       =  0x23C,
                bitSize      =  1,
                mode         = 'RW',
            ))

            self.add(pr.RemoteVariable(
                name         = 'pcs_reset',
                description  = 'Issue a reset to the PCS layer',
                offset       =  0x240,
                bitSize      =  1,
                mode         = 'RW',
            ))

        self.add(pr.RemoteVariable(
            name         = 'RollOverEn',
            description  = 'Enable counter rollover instead of saturation',
            offset       =  0xF00,
            bitSize      =  19,
            mode         = 'RW',
        ))

        self.add(pr.RemoteCommand(
            name         = 'CounterReset',
            description  = 'Reset all status counters',
            offset       = 0xFF4,
            bitSize      = 1,
            function     = lambda cmd: cmd.post(1),
            hidden       = False,
        ))

        self.add(pr.RemoteCommand(
            name         = 'SoftReset',
            description  = 'Issue a soft reset to the 10GigE MAC',
            offset       = 0xFF8,
            bitSize      = 1,
            function     = lambda cmd: cmd.post(1),
            hidden       = False,
        ))

        self.add(pr.RemoteCommand(
            name         = 'HardReset',
            description  = 'Issue a hard reset to the 10GigE MAC',
            offset       = 0xFFC,
            bitSize      = 1,
            function     = lambda cmd: cmd.post(1),
            hidden       = False,
        ))

    def hardReset(self):
        self.HardReset()

    def softReset(self):
        self.SoftReset()

    def countReset(self):
        self.CounterReset()
