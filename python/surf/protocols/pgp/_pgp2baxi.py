#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue _pgp2baxi Module
#-----------------------------------------------------------------------------
# File       : _pgp2baxi.py
# Created    : 2016-09-29
# Last update: 2016-09-29
#-----------------------------------------------------------------------------
# Description:
# PyRogue _pgp2baxi Module
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

class Pgp2bAxi(pr.Device):
    def __init__(self, 
            name        = "Pgp2bAxi",
            description = "Configuration and status of a downstream PGP link",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 
        
        self.add(pr.RemoteVariable(
            name        = "Loopback", 
            description = "GT Loopback Mode",
            offset      = 0xC, 
            bitSize     = 3, 
            bitOffset   = 0, 
            mode        = "RW", 
            enum        = {
                0: "Off",
                1: "NearPcs",
                2: "NearPma",
                4: "FarPma",
                5: "FarPcs",
            },
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
        ))
        
        self.add(pr.RemoteVariable(
            name        = "TxPhyReady",       
            offset      = 0x20, 
            bitSize     = 1, 
            bitOffset   = 1, 
            mode        = "RO", 
            base        = pr.Bool, 
            description = "TX Phy is Ready",
        ))
        
        self.add(pr.RemoteVariable(
            name        = "RxLocalLinkReady", 
            offset      = 0x20, 
            bitSize     = 1, 
            bitOffset   = 2, 
            mode        = "RO", 
            base        = pr.Bool, 
            description = "Rx Local Link Ready",
        ))
        
        self.add(pr.RemoteVariable(
            name        = "RxRemLinkReady",   
            offset      = 0x20, 
            bitSize     = 1, 
            bitOffset   = 3, 
            mode        = "RO", 
            base        = pr.Bool, 
            description = "Rx Remote Link Ready",
        ))
        
        self.add(pr.RemoteVariable(
            name        = "TxLinkReady",      
            offset      = 0x20, 
            bitSize     = 1, 
            bitOffset   = 4, 
            mode        = "RO", 
            base        = pr.Bool, 
            description = "Tx Link Ready",
        ))
        
        self.add(pr.RemoteVariable(
            name        = "RxLinkPolarity",   
            offset      = 0x20, 
            bitSize     = 2, 
            bitOffset   = 8, 
            mode        = "RO", 
            base        = pr.UInt, 
            description = "Rx Link Polarity",
        ))
        
        self.add(pr.RemoteVariable(
            name        = "RxRemPause",       
            offset      = 0x20, 
            bitSize     = 4, 
            bitOffset   = 12, 
            mode        = "RO", 
            base        = pr.UInt, 
            description = "RX Remote Pause Asserted",
        ))
        
        self.add(pr.RemoteVariable(
            name        = "TxLocPause",       
            offset      = 0x20, 
            bitSize     = 4, 
            bitOffset   = 16, 
            mode        = "RO", 
            base        = pr.UInt, 
            description = "Tx Local Pause Asserted",
        ))
        
        self.add(pr.RemoteVariable(
            name        = "RxRemOverflow",    
            offset      = 0x20, 
            bitSize     = 4, 
            bitOffset   = 20, 
            mode        = "RO", 
            base        = pr.UInt, 
            description = "Received remote overflow flag",
        ))
        
        self.add(pr.RemoteVariable(
            name        = "TxLocOverflow",    
            offset      = 0x20, 
            bitSize     = 4,
            bitOffset   = 24, 
            mode        = "RO", 
            base        = pr.UInt, 
            description = "Received local overflow flag",
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
            "RxCellErrorCount", 
            "RxLinkDownCount", 
            "RxLinkErrorCount",
            "RxRemOverflow0Count", 
            "RxRemOverflow1Count", 
            "RxRemOverflow2Count", 
            "RxRemOverflow3Count",
            "RxFrameErrorCoumt", 
            "RxFrameCount",
            "TxLocOverflow0Count",
            "TxLocOverflow1Count",
            "TxLocOverflow2Count",
            "TxLocOverflow3Count",
            "TxFrameErrorCount", 
            "TxFrameCount",
        ]

        for offset, name in enumerate(countVars):
            self.add(pr.RemoteVariable(
                name        = name, 
                offset      = ((offset*4)+0x28), 
                bitSize     = 32, 
                bitOffset   = 0, 
                mode        = "RO", 
                base        = pr.UInt,
            ))

        self.add(pr.RemoteVariable(
            name        = "LastTxOpCode", 
            offset      = 0x70, 
            bitSize     = 8, 
            bitOffset   = 0, 
            mode        = "RO", 
            base        = pr.UInt, 
            description = "",
        ))

        self.add(pr.RemoteVariable(
            name        = "LastRxOpCode", 
            offset      = 0x74, 
            bitSize     = 8, 
            bitOffset   = 0, 
            mode        = "RO", 
            base        = pr.UInt, 
            description = "",
        ))
        
        self.add(pr.RemoteVariable(
            name        = "TxOpCodeCount", 
            offset      = 0x78, 
            bitSize     = 8, 
            bitOffset   = 0, 
            mode        = "RO", 
            base        = pr.UInt, 
            description = "",
        ))
        
        self.add(pr.RemoteVariable(
            name        = "RxOpCodeCount", 
            offset      = 0x7C, 
            bitSize     = 8, 
            bitOffset   = 0, 
            mode        = "RO", 
            base        = pr.UInt, 
            description = "",
        ))

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
            name        = "Flush", 
            offset      = 0x08, 
            bitSize     = 1, 
            bitOffset   = 0, 
            function    = pr.BaseCommand.toggle,
        ))

        def _resetFunc(dev, rstType):
            """Application specific reset function"""
            if rstType == 'soft':
                self.Flush()
            elif rstType == 'hard':
                self.ResetRx()
            elif rstType == 'count':
                self.CountReset()

        self.add(pr.RemoteVariable(
            name         = "RxClkFreqRaw", 
            offset       = 0x64, 
            bitSize      = 32, 
            mode         = "RO", 
            base         = pr.UInt, 
            hidden       = True, 
            pollInterval = 5,
        ))
        
        self.add(pr.RemoteVariable(
            name         = "TxClkFreqRaw", 
            offset       = 0x68, 
            bitSize      = 32, 
            mode         = "RO", 
            base         = pr.UInt, 
            hidden       = True, 
            pollInterval = 5,
        ))

        self.add(pr.LinkVariable(
            name         = "RxClkFreq", 
            mode         = "RO", 
            units        = "MHz", 
            dependencies = [self.RxClkFreqRaw], 
            linkedGet    = self._convertFrequency,
        ))
        
        self.add(pr.LinkVariable(
            name         = "TxClkFreq", 
            mode         = "RO", 
            units        = "MHz", 
            dependencies = [self.TxClkFreqRaw], 
            linkedGet    = self._convertFrequency,
        ))
             
    @staticmethod
    def _convertFrequency(dev, var):
        value   = var.dependencies[0].get(read=False)
        fpValue = value*1e-6
        return '%0.1f'%(fpValue)

