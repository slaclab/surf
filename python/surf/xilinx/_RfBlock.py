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

## Set Direction
##
##      CoarseMixFreq = MixerSettingsPtr->CoarseMixFreq;
##      NCOFreq = MixerSettingsPtr->Freq;
##
##      if ((NCOFreq < -(SamplingRate / 2.0)) || (NCOFreq > (SamplingRate / 2.0))) {
##        do {
##            if (NCOFreq < -(SamplingRate / 2.0)) {
##                NCOFreq += SamplingRate;
##            }
##            if (NCOFreq > (SamplingRate / 2.0)) {
##                NCOFreq -= SamplingRate;
##            }
##        } while ((NCOFreq < -(SamplingRate / 2.0)) || (NCOFreq > (SamplingRate / 2.0)));
##
##        if ((NyquistZone == XRFDC_EVEN_NYQUIST_ZONE) && (NCOFreq != 0)) {
##            NCOFreq *= -1;
##        }
##      }
##
##      /* NCO Frequency */
##      Freq = ((NCOFreq * XRFDC_NCO_FREQ_MULTIPLIER) / SamplingRate);
##      XRFdc_WriteReg16(InstancePtr, BaseAddr, XRFDC_ADC_NCO_FQWD_LOW_OFFSET, (u16)Freq);
##      ReadReg = (Freq >> XRFDC_NCO_FQWD_MID_SHIFT) & XRFDC_NCO_FQWD_MID_MASK;
##      XRFdc_WriteReg16(InstancePtr, BaseAddr, XRFDC_ADC_NCO_FQWD_MID_OFFSET, (u16)ReadReg);
##      ReadReg = (Freq >> XRFDC_NCO_FQWD_UPP_SHIFT) & XRFDC_NCO_FQWD_UPP_MASK;
##      XRFdc_WriteReg16(InstancePtr, BaseAddr, XRFDC_ADC_NCO_FQWD_UPP_OFFSET, (u16)ReadReg);
##
## Get Direction
##
##    /* NCO Frequency */
##    ReadReg = XRFdc_ReadReg16(InstancePtr, BaseAddr, XRFDC_ADC_NCO_FQWD_UPP_OFFSET);
##    Freq = ReadReg << XRFDC_NCO_FQWD_UPP_SHIFT;
##    ReadReg = XRFdc_ReadReg16(InstancePtr, BaseAddr, XRFDC_ADC_NCO_FQWD_MID_OFFSET);
##    Freq |= ReadReg << XRFDC_NCO_FQWD_MID_SHIFT;
##    ReadReg = XRFdc_ReadReg16(InstancePtr, BaseAddr, XRFDC_ADC_NCO_FQWD_LOW_OFFSET);
##    Freq |= ReadReg;
##    Freq &= XRFDC_NCO_FQWD_MASK;
##    Freq = (Freq << 16) >> 16;
##    MixerSettingsPtr->Freq = ((Freq * SamplingRate) / XRFDC_NCO_FREQ_MULTIPLIER);
##
##    /* Update NCO, CoarseMix freq based on calibration mode */
##    NCOFreq = MixerConfigPtr->Freq;
##
##    if ((NCOFreq > (SamplingRate / 2.0)) || (NCOFreq < -(SamplingRate / 2.0))) {
##
##        if ((NyquistZone == XRFDC_EVEN_NYQUIST_ZONE) && (MixerSettingsPtr->Freq != 0)) {
##            MixerSettingsPtr->Freq *= -1;
##        }
##
##        do {
##            if (NCOFreq < -(SamplingRate / 2.0)) {
##                NCOFreq += SamplingRate;
##                MixerSettingsPtr->Freq -= SamplingRate;
##            }
##            if (NCOFreq > (SamplingRate / 2.0)) {
##                NCOFreq -= SamplingRate;
##                MixerSettingsPtr->Freq += SamplingRate;
##            }
##        } while ((NCOFreq > (SamplingRate / 2.0)) || (NCOFreq < -(SamplingRate / 2.0)));
##    }


