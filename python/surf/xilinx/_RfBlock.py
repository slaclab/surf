#-----------------------------------------------------------------------------
# Title      : Xilinx RFSoC RF data converter block
#-----------------------------------------------------------------------------
# Description:
# Xilinx RFSoC RF data converter block
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

class RfTile(pr.Device):
    def __init__(
            self,
            isAdc       = False, # True if this is an ADC tile
            description = "RFSoC data converter block registers",
            **kwargs):
        super().__init__(description=description, **kwargs)

        ##############################
        # Variables
        ##############################

        if isAdc is False:
            self.add(pr.RemoteVariable(
                name         = "dataPathMode",
                description  = "DAC DataPath Mode",
                offset       =  0x0034,
                bitSize      =  2,
                bitOffset    =  0,
                mode         = "RO",
                enum         = {0: "FullBw", 1: "NA", 2: "HalfBwImr", 3: "FullBwByPass"},
                overlapEn    = True,
            ))

            self.add(pr.RemoteVariable(
                name         = "dataInterpData",
                description  = "DAC Interpolation Data. 0 = Real, 1 = IQ",
                offset       =  0x0044,
                bitSize      =  1,
                bitOffset    =  0,
                mode         = "RO",
                enum         = {0: "Real", 1: "IQ"},
                overlapEn    = True,
            ))

        if isAdc is True:

            self.add(pr.RemoteVariable(
                name         = "adcDecimationConfig",
                description  = "ADC Decimation Configuration",
                offset       =  0x0040,
                bitSize      =  2,
                bitOffset    =  0,
                mode         = "RO",
                enum         = {0: "I Data", 1: "Q DATA", 2: "IQ Data", 3: "4GSPS"},
                overlapEn    = True,
            ))

            self.add(pr.RemoteVariable(
                name         = "ncoPhaseMode",
                description  = "NCO Phase Mode",
                offset       =  0x00A8,
                bitSize      =  2,
                bitOffset    =  0,
                mode         = "RO",
                enum         = {0: "NA", 1: "Even", 2: "Odd", 3: "4Phase"},
                overlapEn    = True,
            ))


        self.add(pr.RemoteVariable(
            name         = "ncoFqwdUp",
            description  = "NCO Frequency Upper",
            offset       =  0x0094,
            bitSize      =  16,
            bitOffset    =  0,
            mode         = "RW",
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "ncoFqwdMid",
            description  = "NCO Frequency Middle",
            offset       =  0x0098,
            bitSize      =  16,
            bitOffset    =  0,
            mode         = "RW",
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "ncoFqwdLow",
            description  = "NCO Frequency Lower",
            offset       =  0x009C,
            bitSize      =  16,
            bitOffset    =  0,
            mode         = "RW",
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "ncoPhaseUp",
            description  = "NCO Phase Upper",
            offset       =  0x00A0,
            bitSize      =  16,
            bitOffset    =  0,
            mode         = "RO",
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "ncoPhaseLow",
            description  = "NCO Phase Lower",
            offset       =  0x00A4,
            bitSize      =  16,
            bitOffset    =  0,
            mode         = "RO",
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "mixerMode",
            description  = "Mixer Mode",
            offset       =  0x0088,
            bitSize      =  1,
            bitOffset    =  5,
            mode         = "RO",
            overlapEn    = True,
        ))

        self.add(pr.LocalVariable(
            name         = "samplingRate",
            description  = "Sampling Rate",
            value        = 0.0,
        ))

        self.add(pr.LocalVariable(
            name         = "nyquistZone",
            description  = "NyQuist Zone",
            value        = 0,
            enum         = {0: 'NotSet', 1: 'Even', 2: 'Odd'},
        ))

        self.add(pr.LinkVariable(
            name         = "ncoFrequency",
            description  = "NCO Frequency",
            linkedSet    = self._ncoFreqSet,
            linkedGet    = self._ncoFreqGet
        ))


    def _ncoFreqSet(self, value, write, verify, check):
        samplingRate = self.samplingRate.value()
        nyquistZone = self.nyquistZone.value()

        if nyquistZone == 0:
            return

        ncoFreq = value

        if (ncoFreq < -(samplingRate / 2.0)) or (ncoFreq > (samplingRate / 2.0)):
            while (ncoFreq < -(samplingRate / 2.0)) or (ncoFreq > (samplingRate / 2.0)):

                if ncoFreq < -(samplingRate / 2.0):
                    ncoFreq += samplingRate

                if ncoFreq > (samplingRate / 2.0):
                    ncoFreq -= samplingRate

            if (nyquistZone == 1) and (ncoFreq != 0):
                ncoFreq = ncoFreq * -1.0

        regFreq = int((ncoFreq * 2**48) / samplingRate)

        low = regFreq & 0xFFFF
        mid = (regFreq >> 16) & 0xFFFF
        up  = (regFreq >> 32) & 0xFFFF

        # Set The Values get the register values
        self.ncoFqwdLow.set(value=low, write=write, verify=verify, check=check)
        self.ncoFqwdMid.set(value=mid, write=write, verify=verify, check=check)
        self.ncoFqwdUp.set(vallue=up, write=write, verify=verify, check=check)


    def _ncoFreqGet(self, read, check):
        samplingRate = self.samplingRate.value()
        nyquistZone = self.nyquistZone.value()

        if nyquistZone == 0:
            return 0.0

        # First get the register values
        low = self.ncoFqwdLow.get(read=read, check=check)
        mid = self.ncoFqwdMid.get(read=read, check=check)
        up  = self.ncoFqwdUp.get(read=read, check=check)

        regFreq = low
        regFreq |= mid << 16
        regFreq |= up  << 32

        # Get Direction
        retFreq = (regFreq * samplingRate) / (2**48)
        ncoFreq = retFreq

        if (ncoFreq < -(samplingRate / 2.0)) or (ncoFreq > (samplingRate / 2.0)):

            if (nyquistZone == 1) and (retFreq != 0):
                retFreq = retFreq * -1.0

            while (ncoFreq < -(samplingRate / 2.0)) or (ncoFreq > (samplingRate / 2.0)):

                if ncoFreq < -(samplingRate / 2.0):
                    ncoFreq += samplingRate
                    retFreq -= samplingRate

                if ncoFreq > (samplingRate / 2.0):
                    ncoFreq -= samplingRate
                    retFreq += samplingRate

        return retFreq
