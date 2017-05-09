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
    def __init__(self, **kwargs):
        super(self.__class__, self).__init__(
            description="Configuration and status of a downstream PGP link", **kwargs)

        #self.add(pr.Command(
        #    name="CountReset",
        #    description="Reset all of the counters",
        #    function=_countReset,
        #    offset = 0x0,
        #    bitSize=1,
        #    bitOffset=0))
        #Need to implement ResetRx and Flush

        self.add(pr.Variable(name="Loopback", description="GT Loopback Mode",
                                  offset = 0xC, bitSize=3, bitOffset=0, mode="RW", base="enum",
                                  enum={0: "Off",
                                        1: "NearPcs",
                                        2: "NearPma",
                                        4: "FarPma",
                                        5: "FarPcs"}))
        
        self.add(pr.Variable(name="LocData", description = "Sideband data to transmit",
                             offset = 0x10, bitSize = 8, bitOffset = 0, mode = "RW", base = 'hex'))
        self.add(pr.Variable(name="LocDataEn", description = "Enable sideband data to transmit",
                             offset = 0x10, bitSize = 1, bitOffset = 8, mode = "RW", base = 'bool'))
        
        self.add(pr.Variable(name="AutoStatus", description = "Auto Status Send Enable (PPI)",
                             offset = 0x14, bitSize = 1, bitOffset = 0, mode = "RW", base = 'bool'));

        self.add(pr.Variable(name="RxPhyReady",       offset = 0x20, bitSize = 1, bitOffset = 0, mode = "RO", base = 'bool', description = "RX Phy is Ready"));
        self.add(pr.Variable(name="TxPhyReady",       offset = 0x20, bitSize = 1, bitOffset = 1, mode = "RO", base = 'bool', description = "TX Phy is Ready"));
        self.add(pr.Variable(name="RxLocalLinkReady", offset = 0x20, bitSize = 1, bitOffset = 2, mode = "RO", base = 'bool', description = "Rx Local Link Ready"));
        self.add(pr.Variable(name="RxRemLinkReady",   offset = 0x20, bitSize = 1, bitOffset = 3, mode = "RO", base = 'bool', description = "Rx Remote Link Ready"));
        self.add(pr.Variable(name="TxLinkReady",      offset = 0x20, bitSize = 1, bitOffset = 4, mode = "RO", base = 'bool', description = "Tx Link Ready"));
        self.add(pr.Variable(name="RxLinkPolarity",   offset = 0x20, bitSize = 2, bitOffset = 8, mode = "RO", base = 'bool', description = "Rx Link Polarity"));
        self.add(pr.Variable(name="RxRemPause",       offset = 0x20, bitSize = 4, bitOffset = 12, mode = "RO", base = 'bool', description = "RX Remote Pause Asserted"));
        self.add(pr.Variable(name="TxLocPause",       offset = 0x20, bitSize = 4, bitOffset = 16, mode = "RO", base = 'bool', description = "Tx Local Pause Asserted"));
        self.add(pr.Variable(name="RxRemOverflow",    offset = 0x20, bitSize = 4, bitOffset = 20, mode = "RO", base = 'bool', description = "Received remote overflow flag"));
        self.add(pr.Variable(name="TxLocOverflow",    offset = 0x20, bitSize = 4, bitOffset = 24, mode = "RO", base = 'bool', description = "Received local overflow flag"));


        self.add(pr.Variable(name="RxRemLinkData", offset = 0x24, bitSize = 8, bitOffset = 0, mode = "RO", base = 'hex', description = ""));
        
        countVars = [
            "RxCellErrorCount", "RxLinkDownCount", "RxLinkErrorCount",
            "RxRemOverflow0Count", "RxRemOverflow1Count", "RxRemOverflow2Count", "RxRemOverflow3Count",
            "RxFrameErrorCoumt", "RxFrameCount",
            "TxLocOverflow0Count","TxLocOverflow1Count","TxLocOverflow2Count","TxLocOverflow3Count",
            "TxFrameErrorCount", "TxFrameCount"]

        for offset, name in enumerate(countVars):
            self.add(pr.Variable(name=name, offset=((offset*4)+0x28), bitSize=32, bitOffset=0, mode="RO", base='hex'))

        self.add(pr.Variable(name="RxClkFreq", offset = 0x64, bitSize = 32, bitOffset = 0, mode = "RO", base = 'string', description = "",
                             getFunction = _convertFrequency, pollInterval=5));

        self.add(pr.Variable(name="TxClkFreq", offset = 0x68, bitSize = 32, bitOffset = 0, mode = "RO", base = 'string', description = "",
                             getFunction = _convertFrequency, pollInterval=5));
        
        self.add(pr.Variable(name="LastTxOpCode", offset = 0x70, bitSize = 8, bitOffset = 0, mode = "RO", base = 'hex', description = ""));

        self.add(pr.Variable(name="LastRxOpCode", offset = 0x74, bitSize = 8, bitOffset = 0, mode = "RO", base = 'hex', description = ""));
        
        self.add(pr.Variable(name="TxOpCodeCount", offset = 0x78, bitSize = 8, bitOffset = 0, mode = "RO", base = 'hex', description = ""));
        
        self.add(pr.Variable(name="RxOpCodeCount", offset = 0x7C, bitSize = 8, bitOffset = 0, mode = "RO", base = 'hex', description = ""));

        self.add(pr.Command(name='CountReset', offset=0x00, bitSize=1, bitOffset=0, mode='RW', function=pr.Command.toggle))
        self.add(pr.Command(name="ResetRx", offset=0x04, bitSize=1, bitOffset=0, mode='RW',  function=pr.Command.toggle))
        self.add(pr.Command(name="Flush", offset=0x08, bitSize=1, bitOffset=0, mode='RW',  function=pr.Command.toggle))

        def _resetFunc(dev, rstType):
            """Application specific reset function"""
            if rstType == 'soft':
                self.Flush()
            elif rstType == 'hard':
                self.ResetRx()
            elif rstType == 'count':
                self.CountReset()
                                        
def _convertFrequency(dev, var):
    return '{:f} Mhz'.format(var.block.getUInt(var.bitOffset, var.bitSize) * 1e-6)
    
