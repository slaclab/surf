#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AmcCarrier BSI Module
#-----------------------------------------------------------------------------
# File       : Adc32Rf45Channel.py
# Created    : 2017-04-04
#-----------------------------------------------------------------------------
# Description:
# PyRogue Adc32Rf45Channel Module
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the rogue software platform, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class Adc32Rf45Channel(pr.Device):
    def __init__( self,       
        name        = "Adc32Rf45Channel",
        description = "Adc32Rf45Channel Module",
        verify      =  False,
        **kwargs):
        super().__init__(name=name,description=description, **kwargs) 
        
        #######################
        # Paging base addresses
        #######################
        offsetCorrector = (0x1 << 14)
        digitalGain     = (0x2 << 14)
        mainDigital     = (0x3 << 14)
        jesdDigital     = (0x4 << 14)
        decFilter       = (0x5 << 14)
        pwrDet          = (0x6 << 14)
        
        ##################
        # Offset Corr Page 
        ##################
        self.add(pr.RemoteVariable(   
            name         = "SEL_EXT_EST",
            description  = "This bit selects the external estimate for the offset correction block",
            offset       =  (offsetCorrector + (4*0x34)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "FREEZE_OFFSET_CORR",
            description  = "Use this bit to freeze the offset estimation process of the offset corrector",
            offset       =  (offsetCorrector + (4*0x68)),
            bitSize      =  1,
            bitOffset    =  7,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))                        

        self.add(pr.RemoteVariable(   
            name         = "AlwaysWrite0x1_A",
            description  = "Always set this bit to 1",
            offset       =  (offsetCorrector + (4*0x68)),
            bitSize      =  1,
            bitOffset    =  5,
            base         = pr.UInt,
            mode         = "WO",
            value        = 0x1,
            hidden       = True,
            verify       = False,
        ))

        self.add(pr.RemoteVariable(   
            name         = "DIS_OFFSET_CORR",
            description  = "0 = Offset correction block is enabled, 1 = Offset correction block is disabled",
            offset       =  (offsetCorrector + (4*0x68)),
            bitSize      =  1,
            bitOffset    =  2,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "AlwaysWrite0x1_B",
            description  = "Always set this bit to 1",
            offset       =  (offsetCorrector + (4*0x68)),
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.UInt,
            mode         = "WO",
            value        = 0x1,
            hidden       = True,
            verify       = False,
        ))

        ###################
        # Digital Gain Page
        ###################
        self.add(pr.RemoteVariable(   
            name         = "DIGITAL_GAIN",
            description  = "These bits set the digital gain of the ADC output data prior to decimation up to 11 dB",
            offset       =  (digitalGain + (4*0x0A6)),
            bitSize      =  4,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",                        
            verify       = verify,
        ))   

        ###################
        # Main Digital Page
        ###################

        self.add(pr.RemoteVariable(   
            name         = "NQ_ZONE_EN",
            description  = "0 = Nyquist zone specification disabled, 1 = Nyquist zone specification enabled",
            offset       =  (mainDigital + (4*0x0A2)),
            bitSize      =  1,
            bitOffset    =  3,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "NYQUIST_ZONE",
            description  = "These bits specify the operating Nyquist zone for the analog correction loop",
            offset       =  (mainDigital + (4*0x0A2)),
            bitSize      =  3,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        ###################
        # JESD DIGITAL PAGE
        ###################
        self.add(pr.RemoteVariable(   
            name         = "CTRL_K",
            description  = "0 = Default is five frames per multiframe, 1 = Frames per multiframe can be set in register 06h",
            offset       =  (jesdDigital + (4*0x001)),
            bitSize      =  1,
            bitOffset    =  7,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "TESTMODE_EN",
            description  = "0 = Test mode disabled, 1 = Test mode enabled",
            offset       =  (jesdDigital + (4*0x001)),
            bitSize      =  1,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "LANE_ALIGN",
            description  = "0 = Normal operation, 1 = Inserts lane alignment characters",
            offset       =  (jesdDigital + (4*0x001)),
            bitSize      =  1,
            bitOffset    =  2,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "FRAME_ALIGN",
            description  = "0 = Normal operation, 1 = Inserts frame alignment characters",
            offset       =  (jesdDigital + (4*0x001)),
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "TX_LINK_DIS",
            description  = "0 = Normal operation, 1 = ILA disabled",
            offset       =  (jesdDigital + (4*0x001)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "SYNC_REG",
            description  = "0 = Normal operation, 1 = ADC output data are replaced with K28.5 characters",
            offset       =  (jesdDigital + (4*0x002)),
            bitSize      =  1,
            bitOffset    =  7,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "SYNC_REG_EN",
            description  = "0 = Normal operation, 1 = SYNC control through the SPI is enabled",
            offset       =  (jesdDigital + (4*0x002)),
            bitSize      =  1,
            bitOffset    =  6,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "12BIT_MODE",
            description  = "00 = Normal operation, 14-bit output, 01 & 10 = Unused, 11 = High-efficient data packing enabled",
            offset       =  (jesdDigital + (4*0x002)),
            bitSize      =  2,
            bitOffset    =  2,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "JESD_MODE0",
            description  = "These bits select the configuration register to configure the correct LMFS frame assemblies for different decimation settings;",
            offset       =  (jesdDigital + (4*0x002)),
            bitSize      =  2,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "LINK_LAYER_TESTMODE",
            description  = "These bits generate a pattern",
            offset       =  (jesdDigital + (4*0x003)),
            bitSize      =  3,
            bitOffset    =  5,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "LINK_LAY_RPAT",
            description  = "0 = Normal operation, 1 = Changes disparity",
            offset       =  (jesdDigital + (4*0x003)),
            bitSize      =  1,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "LMFC_MASK_RESET",
            description  = "0 = Normal operation",
            offset       =  (jesdDigital + (4*0x003)),
            bitSize      =  1,
            bitOffset    =  3,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "JESD_MODE1",
            description  = "These bits select the configuration register to configure the correct LMFS frame assemblies for different decimation settings",
            offset       =  (jesdDigital + (4*0x003)),
            bitSize      =  1,
            bitOffset    =  2,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  

        self.add(pr.RemoteVariable(   
            name         = "JESD_MODE2",
            description  = "These bits select the configuration register to configure the correct LMFS frame assemblies for different decimation settings",
            offset       =  (jesdDigital + (4*0x003)),
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "RAMP_12BIT",
            description  = "This bit enables the RAMP test pattern for 12-bit mode only (LMFS = 82820): 0 = Normal data output, 1 = Digital output is the RAMP pattern",
            offset       =  (jesdDigital + (4*0x003)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(
            name         = "REL_ILA_SEQ",
            description  = "These bits delay the generation of the lane alignment sequence by 0, 1, 2, or 3 multiframes after the code group synchronization",
            offset       =  (jesdDigital + (4*0x004)),
            bitSize      =  2,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))     

        self.add(pr.RemoteVariable(   
            name         = "SCRAMBLE_EN",
            description  = "0 = Scrambling disabled, 1 = Scrambling enabled",
            offset       =  (jesdDigital + (4*0x006)),
            bitSize      =  1,
            bitOffset    =  7,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "FRAMES_PER_MULTIFRAME",
            description  = "These bits set the number of multiframes. Actual K is the value in hex + 1 (that is, 0Fh is K = 16).",
            offset       =  (jesdDigital + (4*0x007)),
            bitSize      =  5,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  

        self.add(pr.RemoteVariable(   
            name         = "40X_MODE",
            description  = "This register must be set for 40X mode operation: 000 = Register is set for 20X and 80X mode, 111 = Register must be set for 40X mode",
            offset       =  (jesdDigital + (4*0x016)),
            bitSize      =  3,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "LANE0_POL",
            description  = "0 = Polarity as given in the pinout (noninverted), 1 = Inverts polarity (positive, P, or negative, M)",
            offset       =  (jesdDigital + (4*0x017)),
            bitSize      =  1,
            bitOffset    =  3,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "LANE1_POL",
            description  = "0 = Polarity as given in the pinout (noninverted), 1 = Inverts polarity (positive, P, or negative, M)",
            offset       =  (jesdDigital + (4*0x017)),
            bitSize      =  1,
            bitOffset    =  2,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "LANE2_POL",
            description  = "0 = Polarity as given in the pinout (noninverted), 1 = Inverts polarity (positive, P, or negative, M)",
            offset       =  (jesdDigital + (4*0x017)),
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "LANE3_POL",
            description  = "0 = Polarity as given in the pinout (noninverted), 1 = Inverts polarity (positive, P, or negative, M)",
            offset       =  (jesdDigital + (4*0x017)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "SEL_EMP_LANE0",
            description  = "These bits select the amount of de-emphasis for the JESD output transmitter.",
            offset       =  (jesdDigital + (4*0x032)),
            bitSize      =  6,
            bitOffset    =  2,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "SEL_EMP_LANE1",
            description  = "These bits select the amount of de-emphasis for the JESD output transmitter.",
            offset       =  (jesdDigital + (4*0x033)),
            bitSize      =  6,
            bitOffset    =  2,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "SEL_EMP_LANE2",
            description  = "These bits select the amount of de-emphasis for the JESD output transmitter.",
            offset       =  (jesdDigital + (4*0x034)),
            bitSize      =  6,
            bitOffset    =  2,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "SEL_EMP_LANE3",
            description  = "These bits select the amount of de-emphasis for the JESD output transmitter.",
            offset       =  (jesdDigital + (4*0x035)),
            bitSize      =  6,
            bitOffset    =  2,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "CMOS_SYNCB",
            description  = "0 = Differential SYNCB input, 1 = Single-ended SYNCB input using pin 63",
            offset       =  (jesdDigital + (4*0x036)),
            bitSize      =  1,
            bitOffset    =  6,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "PLL_MODE",
            description  = "These bits select the PLL multiplication factor",
            offset       =  (jesdDigital + (4*0x037)),
            bitSize      =  2,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "MASK_CLKDIV_SYSREF",
            description  = "0 = Input clock divider is reset when SYSREF is asserted, 1 = Input clock divider ignores SYSREF assertions",
            offset       =  (jesdDigital + (4*0x03E)),
            bitSize      =  1,
            bitOffset    =  6,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "MASK_NCO_SYSREF",
            description  = "0 = NCO phase and LMFC counter are reset when SYSREF is asserted, 1 = NCO and LMFC counter ignore SYSREF assertions",
            offset       =  (jesdDigital + (4*0x03E)),
            bitSize      =  1,
            bitOffset    =  5,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    
                        
        ########################
        # DECIMATION FILTER PAGE
        ########################                        
        self.add(pr.RemoteVariable(   
            name         = "DDC_EN",
            description  = "0 = Bypass mode (DDC disabled), 1 = Decimation filter enabled",
            offset       =  (decFilter + (4*0x000)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "DECIM_FACTOR",
            description  = "These bits configure the decimation filter setting.",
            offset       =  (decFilter + (4*0x001)),
            bitSize      =  3,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "DUAL_BAND_EN",
            description  = "0 = Single-band DDC, 1 = Dual-band DDC",
            offset       =  (decFilter + (4*0x002)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "REAL_OUT_EN",
            description  = "0 = Complex output format, 1 = Real output format",
            offset       =  (decFilter + (4*0x005)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "DDC_MUX",
            description  = "0 = Normal operation, 1 = DDC block takes input from the alternate ADC",
            offset       =  (decFilter + (4*0x006)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "DDC0_NCO1_LSB",
            description  = "These bits are the LSB of the NCO frequency word for NCO1 of DDC0 (band 1).",
            offset       =  (decFilter + (4*0x007)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "DDC0_NCO1_MSB",
            description  = "These bits are the MSB of the NCO frequency word for NCO1 of DDC0 (band 1).",
            offset       =  (decFilter + (4*0x008)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable( 
            name         = "DDC0_NCO2_LSB",
            description  = "These bits are the LSB of the NCO frequency word for NCO2 of DDC0 (band 1).",
            offset       =  (decFilter + (4*0x009)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "DDC0_NCO2_MSB",
            description  = "These bits are the MSB of the NCO frequency word for NCO2 of DDC0 (band 1).",
            offset       =  (decFilter + (4*0x00A)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    
                        
        self.add(pr.RemoteVariable(   
            name         = "DDC0_NCO3_LSB",
            description  = "These bits are the LSB of the NCO frequency word for NCO3 of DDC0 (band 1).",
            offset       =  (decFilter + (4*0x00B)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "DDC0_NCO3_MSB",
            description  = "These bits are the MSB of the NCO frequency word for NCO3 of DDC0 (band 1).",
            offset       =  (decFilter + (4*0x00C)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "DDC0_NCO4_LSB",
            description  = "These bits are the LSB of the NCO frequency word for NCO4 of DDC0 (band 1).",
            offset       =  (decFilter + (4*0x00D)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "DDC0_NCO4_MSB",
            description  = "These bits are the MSB of the NCO frequency word for NCO4 of DDC0 (band 1).",
            offset       =  (decFilter + (4*0x00E)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "NCO_SEL_PIN",
            description  = "0 = NCO selection through SPI (see address 0h10), 1 = NCO selection through GPIO pins",
            offset       =  (decFilter + (4*0x00F)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "NCO_SEL",
            description  = "These bits enable NCO selection through register setting.",
            offset       =  (decFilter + (4*0x010)),
            bitSize      =  2,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "LMFC_RESET_MODE",
            description  = "These bits reset the configuration for all DDCs and NCOs.",
            offset       =  (decFilter + (4*0x011)),
            bitSize      =  2,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "DDC0_6DB_GAIN",
            description  = "0 = Normal operation, 1 = 6-dB digital gain is added",
            offset       =  (decFilter + (4*0x014)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    
                        
        self.add(pr.RemoteVariable(   
            name         = "DDC1_6DB_GAIN",
            description  = "0 = Normal operation, 1 = 6-dB digital gain is added",
            offset       =  (decFilter + (4*0x016)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    
                        
        self.add(pr.RemoteVariable(   
            name         = "DDC_DET_LAT",
            description  = "These bits ensure deterministic latency depending on the decimation setting used",
            offset       =  (decFilter + (4*0x01E)),
            bitSize      =  3,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    
                        
        self.add(pr.RemoteVariable(   
            name         = "WBF_6DB_GAIN",
            description  = "0 = Normal operation, 1 = 6-dB digital gain is added",
            offset       =  (decFilter + (4*0x01F)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "CUSTOM_PATTERN1_LSB",
            description  = "These bits set the custom test pattern",
            offset       =  (decFilter + (4*0x033)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "CUSTOM_PATTERN1_MSB",
            description  = "These bits set the custom test pattern",
            offset       =  (decFilter + (4*0x034)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "CUSTOM_PATTERN2_LSB",
            description  = "These bits set the custom test pattern",
            offset       =  (decFilter + (4*0x035)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "CUSTOM_PATTERN2_MSB",
            description  = "These bits set the custom test pattern",
            offset       =  (decFilter + (4*0x036)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "TEST_PATTERN_SEL",
            description  = "These bits select the test pattern output on the channel.",
            offset       =  (decFilter + (4*0x037)),
            bitSize      =  4,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "TEST_PAT_RES",
            description  = "0 = Normal operation, 1 = Reset the test pattern",
            offset       =  (decFilter + (4*0x03A)),
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    
                        
        self.add(pr.RemoteVariable(   
            name         = "TP_RES_EN",
            description  = "0 = Reset disabled, 1 = Reset enabled",
            offset       =  (decFilter + (4*0x03A)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    
                        
        #####################
        # Power Detector PAGE
        #####################
        self.add(pr.RemoteVariable(   
            name         = "PKDET_EN",
            description  = "0 = Power detector disabled, 1 = Power detector enabled",
            offset       =  (pwrDet + (4*0x000)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    
                        
        self.add(pr.RemoteVariable(   
            name         = "BLKPKDET_LSB",
            description  = "This register specifies the block length in terms of number of samples (S) used for peak power computation",
            offset       =  (pwrDet + (4*0x001)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "BLKPKDET_MSB",
            description  = "This register specifies the block length in terms of number of samples (S) used for peak power computation",
            offset       =  (pwrDet + (4*0x002)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "BLKPKDET16",
            description  = "This register specifies the block length in terms of number of samples (S) used for peak power computation",
            offset       =  (pwrDet + (4*0x003)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "BLKTHHH",
            description  = "These registers set the four different thresholds for the hysteresis function threshold values from 0 to 256 (2TH), where 256 is equivalent to the peak amplitude.",
            offset       =  (pwrDet + (4*0x007)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "BLKTHHL",
            description  = "These registers set the four different thresholds for the hysteresis function threshold values from 0 to 256 (2TH), where 256 is equivalent to the peak amplitude.",
            offset       =  (pwrDet + (4*0x008)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "BLKTHLH",
            description  = "These registers set the four different thresholds for the hysteresis function threshold values from 0 to 256 (2TH), where 256 is equivalent to the peak amplitude.",
            offset       =  (pwrDet + (4*0x009)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "BLKTHLL",
            description  = "These registers set the four different thresholds for the hysteresis function threshold values from 0 to 256 (2TH), where 256 is equivalent to the peak amplitude.",
            offset       =  (pwrDet + (4*0x00A)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    
                        
        self.add(pr.RemoteVariable(   
            name         = "DWELL_LSB",
            description  = "DWELL time counter",
            offset       =  (pwrDet + (4*0x00B)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "DWELL_MSB",
            description  = "DWELL time counter",
            offset       =  (pwrDet + (4*0x00C)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    
                        
        self.add(pr.RemoteVariable(   
            name         = "FILT0LPSEL",
            description  = "0 = Use the output of the high comparators (HH and HL) as the input of the IIR filter, 1 = Combine the output of the high (HH and HL) and low (LH and LL) comparators to generate a 3-level input to the IIR filter (–1, 0, 1)",
            offset       =  (pwrDet + (4*0x00D)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "TIMECONST",
            description  = "These bits set the crossing detector time period",
            offset       =  (pwrDet + (4*0x00E)),
            bitSize      =  4,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "FIL0THH_LSB",
            description  = "Comparison thresholds for the crossing detector counter",
            offset       =  (pwrDet + (4*0x00F)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "FIL0THH_MSB",
            description  = "Comparison thresholds for the crossing detector counter",
            offset       =  (pwrDet + (4*0x010)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "FIL0THL_LSB",
            description  = "Comparison thresholds for the crossing detector counter",
            offset       =  (pwrDet + (4*0x011)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "FIL0THL_MSB",
            description  = "Comparison thresholds for the crossing detector counter",
            offset       =  (pwrDet + (4*0x012)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    
                        
        self.add(pr.RemoteVariable(   
            name         = "IIR0_2BIT_EN",
            description  = "0 = Selects 1-bit output format, 1 = Selects 2-bit output format",
            offset       =  (pwrDet + (4*0x013)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "FIL1THH_LSB",
            description  = "Comparison thresholds for the crossing detector counter",
            offset       =  (pwrDet + (4*0x016)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "FIL1THH_MSB",
            description  = "Comparison thresholds for the crossing detector counter",
            offset       =  (pwrDet + (4*0x017)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "FIL1THL_LSB",
            description  = "Comparison thresholds for the crossing detector counter",
            offset       =  (pwrDet + (4*0x018)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "FIL1THL_MSB",
            description  = "Comparison thresholds for the crossing detector counter",
            offset       =  (pwrDet + (4*0x019)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "IIR1_2BIT_EN",
            description  = "0 = Selects 1-bit output format, 1 = Selects 2-bit output format",
            offset       =  (pwrDet + (4*0x01A)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    
                        
        self.add(pr.RemoteVariable(   
            name         = "DWELLIIR_LSB",
            description  = "DWELL time counter for the IIR output comparators",
            offset       =  (pwrDet + (4*0x01D)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "DWELLIIR_MSB",
            description  = "DWELL time counter for the IIR output comparators",
            offset       =  (pwrDet + (4*0x01E)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    
                        
        self.add(pr.RemoteVariable(   
            name         = "RMSDET_EN",
            description  = "0 = Power detector disabled, 1 = Power detector enabled",
            offset       =  (pwrDet + (4*0x020)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    
                        
        self.add(pr.RemoteVariable(   
            name         = "PWRDETACCU",
            description  = "These bits program the block length to be used for RMS power computation",
            offset       =  (pwrDet + (4*0x021)),
            bitSize      =  5,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    
                        
        self.add(pr.RemoteVariable(   
            name         = "PWRDETH_LSB",
            description  = "The computed average power is compared against these high and low thresholds",
            offset       =  (pwrDet + (4*0x022)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "PWRDETH_MSB",
            description  = "The computed average power is compared against these high and low thresholds",
            offset       =  (pwrDet + (4*0x023)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "PWRDETL_LSB",
            description  = "The computed average power is compared against these high and low thresholds",
            offset       =  (pwrDet + (4*0x024)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "PWRDETL_MSB",
            description  = "The computed average power is compared against these high and low thresholds",
            offset       =  (pwrDet + (4*0x025)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    
                        
        self.add(pr.RemoteVariable(   
            name         = "RMS_2BIT_EN",
            description  = "0 = Selects 1-bit output format, 1 = Selects 2-bit output format",
            offset       =  (pwrDet + (4*0x027)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "RESET_AGC",
            description  = "0 = Clear AGC reset, 1 = Set AGC reset",
            offset       =  (pwrDet + (4*0x02B)),
            bitSize      =  1,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "OUTSEL_GPIO1",
            description  = "These bits set the function or signal for each GPIO pin.",
            offset       =  (pwrDet + (4*0x032)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "OUTSEL_GPIO2",
            description  = "These bits set the function or signal for each GPIO pin.",
            offset       =  (pwrDet + (4*0x033)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "OUTSEL_GPIO3",
            description  = "These bits set the function or signal for each GPIO pin.",
            offset       =  (pwrDet + (4*0x034)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "OUTSEL_GPIO4",
            description  = "These bits set the function or signal for each GPIO pin.",
            offset       =  (pwrDet + (4*0x035)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "IODIR_GPIO4",
            description  = "0 = Input (for the NCO control), 1 = Output (for the AGC alarm function)",
            offset       =  (pwrDet + (4*0x037)),
            bitSize      =  1,
            bitOffset    =  3,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    
                        
        self.add(pr.RemoteVariable(   
            name         = "IODIR_GPIO3",
            description  = "0 = Input (for the NCO control), 1 = Output (for the AGC alarm function)",
            offset       =  (pwrDet + (4*0x037)),
            bitSize      =  1,
            bitOffset    =  2,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "IODIR_GPIO2",
            description  = "0 = Input (for the NCO control), 1 = Output (for the AGC alarm function)",
            offset       =  (pwrDet + (4*0x037)),
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "IODIR_GPIO1",
            description  = "0 = Input (for the NCO control), 1 = Output (for the AGC alarm function)",
            offset       =  (pwrDet + (4*0x037)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "INSEL1",
            description  = "These bits select which GPIO pin is used for the INSEL1 bit",
            offset       =  (pwrDet + (4*0x038)),
            bitSize      =  2,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "INSEL0",
            description  = "These bits select which GPIO pin is used for the INSEL0 bit.",
            offset       =  (pwrDet + (4*0x038)),
            bitSize      =  2,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        @self.command(name = "TestPattern", description  = "Set the Digital bank Test Pattern mode")        
        def TestPattern(arg):
            self.TEST_PATTERN_SEL.set(int(arg))
            self.TEST_PAT_RES.set(0x1)
            self.TEST_PAT_RES.set(0x0)
  
