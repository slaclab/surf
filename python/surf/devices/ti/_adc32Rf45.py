#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AmcCarrier BSI Module
#-----------------------------------------------------------------------------
# File       : Adc32Rf45.py
# Created    : 2017-04-04
#-----------------------------------------------------------------------------
# Description:
# PyRogue Adc32Rf45 Module
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
import time
from surf.devices.ti._adc32Rf45Channel import *

class Adc32Rf45(pr.Device):
    def __init__( self,       
            name        = "Adc32Rf45",
            description = "Adc32Rf45 Module",
            verify      =  False,
            **kwargs):
        super().__init__(
            name        = name, 
            description = description, 
            size        = (0x1 << 18), 
            **kwargs)
        
        ################
        # Base addresses
        ################
        generalAddr     = (0x0 << 14)
        offsetCorrector = (0x1 << 14) # With respect to CH  
        digitalGain     = (0x2 << 14) # With respect to CH  
        mainDigital     = (0x3 << 14) # With respect to CH  
        jesdDigital     = (0x4 << 14) # With respect to CH  
        decFilter       = (0x5 << 14) # With respect to CH  
        pwrDet          = (0x6 << 14) # With respect to CH        
        masterPage      = (0x7 << 14)
        analogPage      = (0x8 << 14)
        chA             = (0x0 << 14)
        chB             = (0x8 << 14)        
        
        #####################
        # Add Device Channels
        #####################
        self.add(Adc32Rf45Channel(name='CH[0]',description='Channel A',offset=(0x0 << 14),expand=False,verify=verify))
        self.add(Adc32Rf45Channel(name='CH[1]',description='Channel B',offset=(0x8 << 14),expand=False,verify=verify))      
        
        ##################
        # General Register
        ##################

        self.add(pr.RemoteCommand(  
            name         = "RESET",
            description  = "Send 0x81 value to reset the device",
            offset       =  (generalAddr + (4*0x000)),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            # mode         = "WO",
            hidden       =  True,
            function     = pr.BaseCommand.createTouch(0x81)
        ))

        self.add(pr.RemoteVariable(   
            name         = "HW_RST",
            description  = "Hardware Reset",
            offset       =  (0xF << 14),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            hidden       =  True,
        ))
                        
        #############
        # Master Page 
        #############
        self.add(pr.RemoteVariable(   
            name         = "PDN_SYSREF",
            description  = "0 = Normal operation, 1 = SYSREF input capture buffer is powered down and further SYSREF input pulses are ignored",
            offset       =  (masterPage + (4*0x020)),
            bitSize      =  1,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))
                        
        self.add(pr.RemoteVariable(   
            name         = "PDN_CHB",
            description  = "0 = Normal operation, 1 = Channel B is powered down",
            offset       =  (masterPage + (4*0x020)),
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))                          
                        
        self.add(pr.RemoteVariable(   
            name         = "GLOBAL_PDN",
            description  = "0 = Normal operation, 1 = Global power-down enabled",
            offset       =  (masterPage + (4*0x020)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  

        self.add(pr.RemoteVariable(   
            name         = "INCR_CM_IMPEDANCE",
            description  = "0 = VCM buffer directly drives the common point of biasing resistors, 1 = VCM buffer drives the common point of biasing resistors with > 5 kOhm",
            offset       =  (masterPage + (4*0x032)),
            bitSize      =  1,
            bitOffset    =  5,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))                          
                        
        self.add(pr.RemoteVariable(   
            name         = "AlwaysWrite0x1_A",
            description  = "Always set this bit to 1",
            offset       =  (masterPage + (4*0x039)),
            bitSize      =  1,
            bitOffset    =  6,
            base         = pr.UInt,
            mode         = "WO",
            value        = 0x1,
            hidden       = True,
            verify       = False,
        ))
                        
        self.add(pr.RemoteVariable(   
            name         = "AlwaysWrite0x1_B",
            description  = "Always set this bit to 1",
            offset       =  (masterPage + (4*0x039)),
            bitSize      =  1,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "WO",
            value        = 0x1,
            hidden       = True,
            verify       = False,
        ))                             

        self.add(pr.RemoteVariable(   
            name         = "PDN_CHB_EN",
            description  = "This bit enables the power-down control of channel B through the SPI in register 20h: 0 = PDN control disabled, 1 = PDN control enabled",
            offset       =  (masterPage + (4*0x039)),
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))                             

        self.add(pr.RemoteVariable(   
            name         = "SYNC_TERM_DIS",
            description  = "0 = On-chip, 100-Ohm termination enabled, 1 = On-chip, 100-Ohm termination disabled",
            offset       =  (masterPage + (4*0x039)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "SYSREF_DEL_EN",
            description  = "0 = SYSREF delay disabled, 1 = SYSREF delay enabled through register settings [3Ch (bits 1-0), 5Ah (bits 7-5)]",
            offset       =  (masterPage + (4*0x03C)),
            bitSize      =  1,
            bitOffset    =  6,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))    

        self.add(pr.RemoteVariable(   
            name         = "SYSREF_DEL_HI",
            description  = "When the SYSREF delay feature is enabled (3Ch, bit 6) the delay can be adjusted in 25-ps steps; the first step is 175 ps. The PVT variation of each 25-ps step is +/-10 ps. The 175-ps step is +/-50 ps",
            offset       =  (masterPage + (4*0x03C)),
            bitSize      =  2,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "JESD_OUTPUT_SWING",
            description  = "These bits select the output amplitude (VOD) of the JESD transmitter for all lanes.",
            offset       =  (masterPage + (4*0x3D)),
            bitSize      =  3,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        )) 

        self.add(pr.RemoteVariable(   
            name         = "SYSREF_DEL_LO",
            description  = "When the SYSREF delay feature is enabled (3Ch, bit 6) the delay can be adjusted in 25-ps steps; the first step is 175 ps. The PVT variation of each 25-ps step is +/-10 ps. The 175-ps step is +/-50 ps",
            offset       =  (masterPage + (4*0x05A)),
            bitSize      =  3,
            bitOffset    =  5,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(   
            name         = "SEL_SYSREF_REG",
            description  = "0 = SYSREF is logic low, 1 = SYSREF is logic high",
            offset       =  (masterPage + (4*0x057)),
            bitSize      =  1,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  
                        
        self.add(pr.RemoteVariable(   
            name         = "ASSERT_SYSREF_REG",
            description  = "0 = SYSREF is asserted by device pins, 1 = SYSREF can be asserted by the ASSERT SYSREF REG register bit",
            offset       =  (masterPage + (4*0x057)),
            bitSize      =  1,
            bitOffset    =  3,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  
                        
        self.add(pr.RemoteVariable(   
            name         = "SYNCB_POL",
            description  = "0 = Polarity is not inverted, 1 = Polarity is inverted",
            offset       =  (masterPage + (4*0x058)),
            bitSize      =  1,
            bitOffset    =  5,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))  
                       
        # ##########
        # # ADC PAGE 
        # ##########
        self.add(pr.RemoteVariable(   
            name         = "SLOW_SP_EN1",
            description  = "0 = ADC sampling rates are faster than 2.5 GSPS, 1 = ADC sampling rates are slower than 2.5 GSPS",
            offset       =  (analogPage + (4*0x03F)),
            bitSize      =  1,
            bitOffset    =  2,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))
                        
        self.add(pr.RemoteVariable(   
            name         = "SLOW_SP_EN2",
            description  = "0 = ADC sampling rates are faster than 2.5 GSPS, 1 = ADC sampling rates are slower than 2.5 GSPS",
            offset       =  (analogPage + (4*0x042)),
            bitSize      =  1,
            bitOffset    =  2,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))
                        
        ##############################
        # Commands
        ##############################
        @self.command(name         = "Init", description  = "Device Initiation")        
        def Init():        
            self.RESET()
            ##############
            # Analog trims
            ##############
            self._rawWrite(analogPage + (4*0x0022),0xC0) # Analog trims start here.
            self._rawWrite(analogPage + (4*0x0032),0x80) # Dither clk mux  : 1 :   FLOP CLK
            self._rawWrite(analogPage + (4*0x0033),0x08) # DAC Prog_vreg_1p5[2:0]  : 4 :   1.624
            self._rawWrite(analogPage + (4*0x0042),0x03) # Delay_element_trim  : 3 :   +6 fingers
            self._rawWrite(analogPage + (4*0x0043),0x03) # Prog_out_diff_reg1/reg_new  : 3 :   1.231
            self._rawWrite(analogPage + (4*0x0045),0x58) # Clk settings
            self._rawWrite(analogPage + (4*0x0046),0xC4) # Clk settings
            self._rawWrite(analogPage + (4*0x0047),0x01) # Clk settings
            self._rawWrite(analogPage + (4*0x0053),0x01) # Dither_clk_mux  : 1 :   DITHER_CLK_NEW
            self._rawWrite(analogPage + (4*0x0054),0x08) # Prog_ftrim_1/2x_hirange 
            self._rawWrite(analogPage + (4*0x0064),0x05) # Adither_msb_force[1:0]  : 2 :   force 0
            self._rawWrite(analogPage + (4*0x0072),0x84) # Offset_interleaving_sample_change  : Asserted
            self._rawWrite(analogPage + (4*0x008C),0x80) # Prog_trim_cdac_force  : Asserted
            self._rawWrite(analogPage + (4*0x0097),0x80) # Prog_trim_fdac_force  : Asserted
            self._rawWrite(analogPage + (4*0x00F0),0x38) # Fuse enable
            self._rawWrite(analogPage + (4*0x00F1),0xBF) # Analog trims ended here.            
            #####################
            # Global Analog Trims
            #####################
            self._rawWrite(masterPage + (4*0x0025),0x01) #  Global Analog Trims start here.		
            self._rawWrite(masterPage + (4*0x0026),0x40) # ...
            self._rawWrite(masterPage + (4*0x0027),0x80) # ...
            self._rawWrite(masterPage + (4*0x0029),0x40) # ...
            self._rawWrite(masterPage + (4*0x002A),0x80) # ...
            self._rawWrite(masterPage + (4*0x002C),0x40) # ...
            self._rawWrite(masterPage + (4*0x002D),0x80) # ...
            self._rawWrite(masterPage + (4*0x002F),0x40) # ...
            self._rawWrite(masterPage + (4*0x0034),0x01) #  CHB CAP NL DISABLE
            self._rawWrite(masterPage + (4*0x003F),0x01) #  CHA CAP NL DISABLE
            self._rawWrite(masterPage + (4*0x0039),0x50) # Iref_50u_inbuf_trim_reg[2:0]  : 0x5
            self._rawWrite(masterPage + (4*0x003B),0x28) # ...
            self._rawWrite(masterPage + (4*0x0040),0x80) # CHA Sha settings ( Vref_1p6_profg[2:0]  : 4 : -100m		Incm_prog[2:0]  : 4 : +80m)	
            self._rawWrite(masterPage + (4*0x0042),0x40) # ...
            self._rawWrite(masterPage + (4*0x0043),0x80) # ...
            self._rawWrite(masterPage + (4*0x0045),0x40) # ...
            self._rawWrite(masterPage + (4*0x0046),0x80) # ...
            self._rawWrite(masterPage + (4*0x0048),0x40) # ...
            self._rawWrite(masterPage + (4*0x0049),0x80) # ...
            self._rawWrite(masterPage + (4*0x004B),0x40) # ...
            self._rawWrite(masterPage + (4*0x0053),0x60) #  Clk buf Prog_outcm[1:0]  : 2 :   -50m 		 Prog_n_incm[1:0]  : 1 :   -60m		
            self._rawWrite(masterPage + (4*0x0059),0x02) #  No clock disable
            self._rawWrite(masterPage + (4*0x005B),0x08) #  Sp reg Outcm_prog[2:0]  : 4 :   -100m
            self._rawWrite(masterPage + (4*0x0062),0xE0) #  Sha current -60u	
            self._rawWrite(masterPage + (4*0x0065),0x81) #  Incm ->  m200m	
            self._rawWrite(masterPage + (4*0x006B),0x04) #  	
            self._rawWrite(masterPage + (4*0x006C),0x08) #  CSET disable	
            self._rawWrite(masterPage + (4*0x006E),0x80) #   Iref_10u_comp_trim  : 2 :   20u	
            self._rawWrite(masterPage + (4*0x006F),0xC0) #  Intr_coarse_ref_trim  : 3 :   60u	
            self._rawWrite(masterPage + (4*0x0070),0xC0) #  CSET disable	
            self._rawWrite(masterPage + (4*0x0071),0x03) #   CSET disable	
            self._rawWrite(masterPage + (4*0x0076),0xA0) #  Prog_stg1_idac_large  : 1 :   880u	
            self._rawWrite(masterPage + (4*0x0077),0x0A) #  Prog_stg1_idac_large  : 1 :   880u	
            self._rawWrite(masterPage + (4*0x007D),0x41) #  Clamp dis and Prog_sha_load_cap[1:0]  : 1 : 0f	
            self._rawWrite(masterPage + (4*0x0081),0x18) #  In_clk_delay_prog[2:0]  : 7 :   240f	
            self._rawWrite(masterPage + (4*0x0084),0x55) #  Prog_stg1_idac_large  : 1 :   880u	
            self._rawWrite(masterPage + (4*0x008A),0x41) #  Clamp dis and Prog_sha_load_cap[1:0]  : 1 : 0f	
            self._rawWrite(masterPage + (4*0x008E),0x18) #  In_clk_delay_prog[2:0]  : 7 :   240f	
            self._rawWrite(masterPage + (4*0x005c),0x07) #  No fuse blown, val = 0x00 //Refsys fuse en =0x07 - NEW PG            
            #########################
            # Additional Analog trims
            #########################
            self._rawWrite(analogPage + (4*0x0083),0x07) # flash convergence
            self._rawWrite(analogPage + (4*0x005C),0x01) # flash convergence
            ###################
            # IL Configurations
            ###################
            # Channel A
            self._rawWrite(mainDigital + chA + (4*0x0FF),0xC0) # Internal IL writes to improve performance. Transition TDD enable for both channels
            self._rawWrite(mainDigital + chA + (4*0x0A9),0x03) # Validities for transtion TDD count values
            self._rawWrite(mainDigital + chA + (4*0x0AB),0x77) # H2L transition TDD count MSB
            self._rawWrite(mainDigital + chA + (4*0x0AC),0x01) # H2L transition TDD count LSB
            self._rawWrite(mainDigital + chA + (4*0x0AD),0x77) # L2H transition TDD count MSB
            self._rawWrite(mainDigital + chA + (4*0x0AE),0x01) # L3H transition TDD count LSB
            self._rawWrite(mainDigital + chA + (4*0x096),0x0F) # Hw slope threshold1
            self._rawWrite(mainDigital + chA + (4*0x097),0x26) # Hw slope threshold2
            self._rawWrite(mainDigital + chA + (4*0x08F),0x0C) # Validity for VALIDITY_BIT_SECONDARY_ESTIM_GF_DBC_ERROR_THRESH, VALIDITY_BIT_SECONDARY_ESTIM_GF_DBFs_ERROR_THRESH
            self._rawWrite(mainDigital + chA + (4*0x08C),0x08) # Validity for IL_CORR_WINDOW
            self._rawWrite(mainDigital + chA + (4*0x080),0x0F) # RATIO_CHECK_HIGH_TH
            self._rawWrite(mainDigital + chA + (4*0x081),0xCB) # RATIO_CHECK_LOW_TH_HIGH_TH_RATIO
            self._rawWrite(mainDigital + chA + (4*0x07D),0x03) # Validities for RATIO_CHECK_HIGH_TH and RATIO_CHECK_LOW_TH_HIGH_TH_RATIO
            self._rawWrite(mainDigital + chA + (4*0x068),0x00) # BAND_EDGE_SMOOTH_EN (Value of 0 at [1:1])
            self._rawWrite(mainDigital + chA + (4*0x056),0x75) # SECONDARY_ESTIM_GF_DBFS_ERROR_THRESH
            self._rawWrite(mainDigital + chA + (4*0x057),0x75) # SECONDARY_ESTIM_GF_DBC_ERROR_THRESH
            self._rawWrite(mainDigital + chA + (4*0x053),0x00) # IL_CORR_WINDOW_DIS at bit position [2:2]
            self._rawWrite(mainDigital + chA + (4*0x04B),0x03) # ADJACENT_EST_CHECK_MAX_CLUSTER_SIZE
            self._rawWrite(mainDigital + chA + (4*0x049),0x80) # DC correction bandwidth settings
            self._rawWrite(mainDigital + chA + (4*0x043),0x20) # Validity bit for BAND_EDGE_SMOOTH_EN
            self._rawWrite(mainDigital + chA + (4*0x042),0x38) # Validity bit for DC correction bandwidth settings,Hw slope threshold,ADJACENT_EST_CHECK_MAX_CLUSTER_SIZE
            self._rawWrite(mainDigital + chA + (4*0x05A),0x04) # NL_FUSE_SAMPLING_FREQ_TOLERANCE
            self._rawWrite(mainDigital + chA + (4*0x071),0x20) # Validity for NL_FUSE_SAMPLING_FREQ_TOLERANCE0x60A2 0x19	// nyquist zone = 2
            # Channel B
            self._rawWrite(mainDigital + chB + (4*0x049),0x80) # DC correction bandwidth settings
            self._rawWrite(mainDigital + chB + (4*0x042),0x20) # Validity bit for DC correction bandwidth settings
            self._rawWrite(mainDigital + chB + (4*0x0A2),0x09) # nyquist zone = 2
            self._rawWrite(mainDigital + chB + (4*0x08D),0x50) # Firmware writes for NL correction
            self._rawWrite(mainDigital + chB + (4*0x08B),0x05) # Firmware writes for NL correction
            self._rawWrite(mainDigital + chB + (4*0x000),0x00) # clear reset            
            # Channel A/B & IL resets
            self._rawWrite(jesdDigital + chA + (4*0x000),0x00) # clear reset
            self._rawWrite(jesdDigital + chB + (4*0x000),0x00) # clear reset
            self._rawWrite(jesdDigital + chA + (4*0x000),0x01) # CHA digital reset
            self._rawWrite(jesdDigital + chB + (4*0x000),0x01) # CHB digital reset 
            self._rawWrite(jesdDigital + chA + (4*0x000),0x00) # clear reset
            self._rawWrite(jesdDigital + chB + (4*0x000),0x00) # clear reset
            self._rawWrite(jesdDigital + chA + (4*0x003),0x00) # No Bypass IL, bypass 0x80
            self._rawWrite(jesdDigital + chB + (4*0x003),0x00) # No Bypass IL, bypass 0x80            
            # Wait for 50 ms for the device to estimate the interleaving errors
            time.sleep(0.050)
            # Additional IL Configurations
            self._rawWrite(mainDigital + chA + (4*0x068),0x04) # Firmware freeze enable 0x04
            self._rawWrite(mainDigital + chA + (4*0x044),0x01) # Firmware freeze validity
            self._rawWrite(mainDigital + chA + (4*0x069),0x00) # Watch Dog timer Disable
            self._rawWrite(mainDigital + chA + (4*0x045),0x10) # Watch Dog timer Validity
            self._rawWrite(mainDigital + chA + (4*0x08D),0x64) # Firmware sensor read periodicity set to 100
            self._rawWrite(mainDigital + chA + (4*0x08B),0x20) # Firmware sensor read periodicity validity
            self._rawWrite(mainDigital + chA + (4*0x000),0x00) # clear reset
            self._rawWrite(mainDigital + chB + (4*0x000),0x00) # clear reset
            self._rawWrite(mainDigital + chA + (4*0x000),0x01) # CHA digital reset
            self._rawWrite(mainDigital + chB + (4*0x000),0x01) # CHB digital reset 
            self._rawWrite(mainDigital + chA + (4*0x000),0x00) # clear reset
            self._rawWrite(mainDigital + chB + (4*0x000),0x00) # clear reset            
            
        @self.command(name= "DigRst", description  = "Digital Reset")        
        def DigRst():               
            time.sleep(0.050)   # Wait for 50 ms for the device to estimate the interleaving errors          
            self._rawWrite(jesdDigital + chA + (4*0x000),0x00) # clear reset
            self._rawWrite(jesdDigital + chB + (4*0x000),0x00) # clear reset
            self._rawWrite(jesdDigital + chA + (4*0x000),0x01) # CHA digital reset
            self._rawWrite(jesdDigital + chB + (4*0x000),0x01) # CHB digital reset 
            self._rawWrite(jesdDigital + chA + (4*0x000),0x00) # clear reset
            self._rawWrite(jesdDigital + chB + (4*0x000),0x00) # clear reset        
            time.sleep(0.050)   # Wait for 50 ms for the device to estimate the interleaving errors          
            self._rawWrite(mainDigital + chA + (4*0x000),0x00) # clear reset
            self._rawWrite(mainDigital + chB + (4*0x000),0x00) # clear reset
            self._rawWrite(mainDigital + chA + (4*0x000),0x01) # CHA digital reset
            self._rawWrite(mainDigital + chB + (4*0x000),0x01) # CHB digital reset 
            self._rawWrite(mainDigital + chA + (4*0x000),0x00) # clear reset
            self._rawWrite(mainDigital + chB + (4*0x000),0x00) # clear reset   
            