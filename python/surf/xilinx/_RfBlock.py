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

class RfBlock(pr.Device):
    def __init__(
            self,
            RestartSM   = None,  # Pointer to the RestartSM remote variable
            isAdc       = False, # True if this is an ADC tile
            description = 'RFSoC data converter block registers',
            **kwargs):
        super().__init__(description=description, **kwargs)

        self.RestartSM = RestartSM

        ##############################
        # Variables
        ##############################

        if isAdc is False:
            self.add(pr.RemoteVariable(
                name         = 'dataPathMode',
                description  = 'DAC DataPath Mode',
                offset       =  0x0034,
                bitSize      =  2,
                bitOffset    =  0,
                mode         = 'RO',
                enum         = {0: 'FullBw', 1: 'NA', 2: 'HalfBwImr', 3: 'FullBwByPass'},
            ))

            self.add(pr.RemoteVariable(
                name         = 'dataInterpData',
                description  = 'DAC Interpolation Data. 0 = Real, 1 = IQ',
                offset       =  0x0044,
                bitSize      =  1,
                bitOffset    =  0,
                mode         = 'RO',
                enum         = {0: 'Real', 1: 'IQ'},
            ))

        if isAdc is True:

            self.add(pr.RemoteVariable(
                name         = 'adcDecimationConfig',
                description  = 'ADC Decimation Configuration',
                offset       =  0x0040,
                bitSize      =  2,
                bitOffset    =  0,
                mode         = 'RO',
                enum         = {0: 'I Data', 1: 'Q DATA', 2: 'IQ Data', 3: '4GSPS'},
            ))

            self.add(pr.RemoteVariable(
                name         = 'ncoPhaseMode',
                description  = 'NCO Phase Mode',
                offset       =  0x00A8,
                bitSize      =  2,
                bitOffset    =  0,
                mode         = 'RO',
                enum         = {0: 'NA', 1: 'Even', 2: 'Odd', 3: '4Phase'},
            ))


        self.add(pr.RemoteVariable(
            name         = 'ncoFqwdUp',
            description  = 'NCO Frequency Upper',
            offset       =  0x0094,
            bitSize      =  16,
            bitOffset    =  0,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ncoFqwdMid',
            description  = 'NCO Frequency Middle',
            offset       =  0x0098,
            bitSize      =  16,
            bitOffset    =  0,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ncoFqwdLow',
            description  = 'NCO Frequency Lower',
            offset       =  0x009C,
            bitSize      =  16,
            bitOffset    =  0,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ncoPhaseUp',
            description  = 'NCO Phase Upper',
            offset       =  0x00A0,
            bitSize      =  16,
            bitOffset    =  0,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ncoPhaseLow',
            description  = 'NCO Phase Lower',
            offset       =  0x00A4,
            bitSize      =  16,
            bitOffset    =  0,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'mixerMode',
            description  = 'Mixer Mode',
            offset       =  0x0088,
            bitSize      =  1,
            bitOffset    =  5,
            mode         = 'RO',
        ))

        self.add(pr.LocalVariable(
            name         = 'samplingRate',
            description  = 'Sampling Rate',
            value        = 0.0,
            units        = 'MHz',
        ))

        self.add(pr.LocalVariable(
            name         = 'nyquistZone',
            description  = 'NyQuist Zone',
            value        = 0,
        ))

        self.add(pr.LinkVariable(
            name         = 'ncoFrequency',
            description  = 'NCO Frequency',
            linkedSet    = self._ncoFreqSet,
            linkedGet    = self._ncoFreqGet,
            dependencies = [self.samplingRate, self.nyquistZone, self.ncoFqwdUp, self.ncoFqwdMid, self.ncoFqwdLow],
            units        = 'MHz',
        ))


    def _ncoFreqSet(self, value, write, verify, check):
        samplingRate = self.samplingRate.value()
        #nyquistZone = self.nyquistZone.value()

        if samplingRate == 0:
            return

        ncoFreq = value

        # TODO: Re-do the logic below using the nyquist zone to set the correct NCO frequency, taking a value larger than the same rate

#        if (ncoFreq < -(samplingRate / 2.0)) or (ncoFreq > (samplingRate / 2.0)):
#            while (ncoFreq < -(samplingRate / 2.0)) or (ncoFreq > (samplingRate / 2.0)):
#
#                if ncoFreq < -(samplingRate / 2.0):
#                    ncoFreq += samplingRate
#
#                if ncoFreq > (samplingRate / 2.0):
#                    ncoFreq -= samplingRate
#
#            if (nyquistZone == 1) and (ncoFreq != 0):
#                ncoFreq = ncoFreq * -1.0

        regFreq = int((ncoFreq * 2**48) / samplingRate)

        ba = regFreq.to_bytes(6, byteorder='little', signed=True)

        # Set The Values get the register values
        self.ncoFqwdLow.set(value=int.from_bytes(ba[0:2], byteorder='little', signed=False), write=write, verify=verify, check=check)
        self.ncoFqwdMid.set(value=int.from_bytes(ba[2:4], byteorder='little', signed=False), write=write, verify=verify, check=check)
        self.ncoFqwdUp.set (value=int.from_bytes(ba[4:6], byteorder='little', signed=False), write=write, verify=verify, check=check)

        # Reset the tile after changing the NCO value
        self.RestartSM.set(value=0x1, write=write, verify=False, check=False)

    def _ncoFreqGet(self, read, check):
        samplingRate = self.samplingRate.value()
        #nyquistZone = self.nyquistZone.value()

        if samplingRate == 0:
            return 0.0

        # First get the register values
        ba = bytearray(6)
        ba[0:2] = self.ncoFqwdLow.get(read=read, check=check).to_bytes(2, byteorder='little', signed=False)
        ba[2:4] = self.ncoFqwdMid.get(read=read, check=check).to_bytes(2, byteorder='little', signed=False)
        ba[4:6] = self.ncoFqwdUp.get (read=read, check=check).to_bytes(2, byteorder='little', signed=False)

        regFreq = int.from_bytes(ba,  byteorder='little', signed=True)

        # Get Direction
        retFreq = (regFreq * samplingRate) / (2**48)

        # TODO: Re-do the logic below using the nyquist zone to get the correct NCO frequency, returning a value larger than the same rate

#        ncoFreq = retFreq
#
#        print(f'{self.name}, regFreq = {regFreq} {regFreq:#x}, retFreq = {retFreq}')
#
#        if (ncoFreq < -(samplingRate / 2.0)) or (ncoFreq > (samplingRate / 2.0)):
#
#            if (nyquistZone == 1) and (retFreq != 0):
#                retFreq = retFreq * -1.0
#
#            while (ncoFreq < -(samplingRate / 2.0)) or (ncoFreq > (samplingRate / 2.0)):
#
#                if ncoFreq < -(samplingRate / 2.0):
#                    ncoFreq += samplingRate
#                    retFreq -= samplingRate
#
#                if ncoFreq > (samplingRate / 2.0):
#                    ncoFreq -= samplingRate
#                    retFreq += samplingRate

        return retFreq
