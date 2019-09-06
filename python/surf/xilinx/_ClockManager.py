#!/usr/bin/env python
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the 
# top-level directory of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of 'SLAC Firmware Standard Library', including this file, 
# may be copied, modified, propagated, or distributed except according to 
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import rogue
import pyrogue as pr
    
class ClockManager(pr.Device):
    def __init__(   self,       
            name        = "ClockManager",
            description = "MMCM and PLL Dynamic Reconfiguration (refer to XAPP888: https://www.xilinx.com/support/documentation/application_notes/xapp888_7Series_DynamicRecon.pdf)",
            type        = None, # [MMCME2,PLLE2,MMCME3,PLLE3,MMCME4,PLLE4]
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        # Determine the number of clkout
        if (type is 'PLLE3') or (type is 'PLLE4'):
            numClkOut = 2
        elif (type is 'PLLE2'):
            numClkOut = 6
        elif (type is 'MMCME2') or (type is 'MMCME3') or (type is 'MMCME4'):
            numClkOut = 7
        else:
            raise ValueError('ClockManager: Invalid type (%s)' % (type) )
        
        # Determine if UltraScale or not
        UltraScale = False if (type is 'MMCME2') or (type is 'PLLE2') else True
        
        ##############################################################################
        #            ClkReg1 Bitmap for CLKOUT[6:0]
        ##############################################################################
        # CLKOUT0 Register 1 (Address=0x08)
        # CLKOUT1 Register 1 (Address=0x0A)
        # CLKOUT2 Register 1 (Address=0x0C): Not available for PLLE3 or PLLE4
        # CLKOUT3 Register 1 (Address=0x0E): Not available for PLLE3 or PLLE4
        # CLKOUT4 Register 1 (Address=0x10): Not available for PLLE3 or PLLE4
        # CLKOUT5 Register 1 (Address=0x06)
        # CLKOUT6 Register 1 (Address=0x12): Not available for PLLE2, PLLE3, or PLLE4
        ClkReg1 = [0x08,0x0A,0x0C,0x0E,0x10,0x06,0x12]
        
        for i in range(numClkOut):
        
            if (type is not 'PLLE3') and (type is not 'PLLE4'):
                self.add(pr.RemoteVariable(   
                    name         = f'PHASE_MUX[{i}]',
                    description = """
                        Chooses an initial phase offset for the clock output, the
                        resolution is equal to 1/8 VCO period. Not available in
                        UltraScale PLLE3 and UltraScale+ PLLE4.                    
                        """,                
                    offset       =  (ClkReg1[i] << 2),
                    bitSize      =  3,
                    bitOffset    =  13,
                    mode         = "RW",
                ))   

            self.add(pr.RemoteVariable(   
                name         = f'HIGH_TIME[{i}]',
                description = """
                    Sets the amount of time in VCO cycles that the clock output
                    remains High.                  
                    """,                
                offset       =  (ClkReg1[i] << 2),
                bitSize      =  6,
                bitOffset    =  6,
                mode         = "RW",
            )) 

            self.add(pr.RemoteVariable(   
                name         = f'LOW_TIME[{i}]',
                description = """
                    Sets the amount of time in VCO cycles that the clock output
                    remains Low.                  
                    """,                
                offset       =  (ClkReg1[i] << 2),
                bitSize      =  6,
                bitOffset    =  0,
                mode         = "RW",
            ))
            
        ##############################################################################         
        # CLKFBOUT Register 1 (Address=0x14)    
        ##############################################################################         
            
        if (type is not 'PLLE3') and (type is not 'PLLE4'):
            self.add(pr.RemoteVariable(   
                name         = 'PHASE_MUX_FB',
                description = """
                    Chooses an initial phase offset for the clock output, the
                    resolution is equal to 1/8 VCO period. Not available in
                    UltraScale PLLE3 and UltraScale+ PLLE4.                    
                    """,                
                offset       =  (0x14 << 2),
                bitSize      =  3,
                bitOffset    =  13,
                mode         = "RW",
            ))   

        self.add(pr.RemoteVariable(   
            name         = 'HIGH_TIME_FB',
            description = """
                Sets the amount of time in VCO cycles that the clock output
                remains High.                  
                """,                
            offset       =  (0x14 << 2),
            bitSize      =  6,
            bitOffset    =  6,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = 'LOW_TIME_FB',
            description = """
                Sets the amount of time in VCO cycles that the clock output
                remains Low.                  
                """,                
            offset       =  (0x14 << 2),
            bitSize      =  6,
            bitOffset    =  0,
            mode         = "RW",
        ))            

        ##############################################################################
        #            ClkReg2 Bitmap for CLKOUT[6:0]
        ############################################################################## 
        # CLKOUT0 Register 2 (Address=0x09)         
        # CLKOUT1 Register 2 (Address=0x0B)
        # CLKOUT2 Register 2 (Address=0x0D): Not available for PLLE3 or PLLE4
        # CLKOUT3 Register 2 (Address=0x0F): Not available for PLLE3 or PLLE4
        # CLKOUT4 Register 2 (Address=0x11): Not available for PLLE3 or PLLE4    
        # CLKOUT5 Register 2 (Address=0x07) 
        # CLKOUT6 Register 2 (Address=0x13): Not available for PLLE2, PLLE3, or PLLE4           
        ClkReg2 = [0x09,0x0B,0x0D,0x0F,0x11,0x07,0x13]        
        
        for i in range(numClkOut):        
        
            ###############################
            # CLKOUT0
            ###############################
            if (i==0):
            
                if (type is 'MMCME2') or (type is 'MMCME3') or (type is 'MMCME4'):
            
                    self.add(pr.RemoteVariable(   
                        name         = 'FRAC[0]',
                        description = """
                            Fractional divide counter setting for CLKOUT0. Equivalent to
                            additional divide of 1/8.               
                            """,                
                        offset       =  (ClkReg2[i] << 2),
                        bitSize      =  3,
                        bitOffset    =  12,
                        mode         = "RW",
                    ))    

                    self.add(pr.RemoteVariable(   
                        name         = 'FRAC_EN[0]',
                        description = """
                            Enable fractional divider circuitry for CLKOUT0.
                            """,                
                        offset       =  (ClkReg2[i] << 2),
                        bitSize      =  1,
                        bitOffset    =  11,
                        mode         = "RW",
                    ))

                    self.add(pr.RemoteVariable(   
                        name         = 'FRAC_WF_R[0]',
                        description = """
                            Adjusts CLKOUT0 rising edge for improved duty cycle accuracy
                            when using fractional counter.
                            """,                
                        offset       =  (ClkReg2[i] << 2),
                        bitSize      =  1,
                        bitOffset    =  10,
                        mode         = "RW",
                    ))    

                
            ###############################
            # CLKOUT1
            ###############################
            if (i==1):
                if (type is 'PLLE3') or (type is 'PLLE4'):
                    self.add(pr.RemoteVariable(   
                        name         = f'CLKOUTPHY_MODE[{i}]',
                        description = """
                            For the PLLE3 and PLLE4, determines CLKPHYOUT
                            frequency based on the VCO frequency.
                            """,                
                        offset       =  (ClkReg2[i] << 2),
                        bitSize      =  2,
                        bitOffset    =  13,
                        mode         = "RW",
                    ))                  
            
            ##############################################
            # CLKOUT5 register with CLKOUT0 Configurations
            ##############################################
            if (i==5):           
                if (type is 'MMCME2') or (type is 'MMCME3') or (type is 'MMCME4'):            
                    self.add(pr.RemoteVariable(   
                        name         = 'PHASE_MUX_F_CLKOUT[0]',
                        description = """
                            CLKOUT0 data required when using fractional
                            counter. Chooses an initial phase offset for the
                            falling edge of the clock output. The resolution is
                            equal to 1/8 VCO period. Not available in UltraScale
                            PLLE3 and UltraScale+ PLLE4.             
                            """,                
                        offset       =  (ClkReg2[i] << 2),
                        bitSize      =  3,
                        bitOffset    =  13 if UltraScale else 11,
                        mode         = "RW",
                    )) 

                    self.add(pr.RemoteVariable(   
                        name         = 'FRAC_WF_F_CLKOUT[0]',
                        description = """
                            Adjusts CLKOUT0 falling edge for improved duty
                            cycle accuracy when using fractional counter.            
                            """,                
                        offset       =  (ClkReg2[i] << 2),
                        bitSize      =  1,
                        bitOffset    =  12 if UltraScale else 10,
                        mode         = "RW",
                    )) 
                    
            ###############################################
            # CLKOUT6 register with CLKFBOUT Configurations
            ###############################################
            if (i==6):    
                if (type is 'MMCME2') or (type is 'MMCME3') or (type is 'MMCME4'): 
                    self.add(pr.RemoteVariable(   
                        name         = 'PHASE_MUX_F_CLKOUT_FB',
                        description = """
                            CLKFBOUT data required when using fractional
                            counter. Chooses an initial phase offset for the
                            falling edge of the clock output. The resolution is
                            equal to 1/8 VCO period. Not available in UltraScale
                            PLLE3 and UltraScale+ PLLE4.             
                            """,                
                        offset       =  (ClkReg2[i] << 2),
                        bitSize      =  3,
                        bitOffset    =  13 if UltraScale else 11,
                        mode         = "RW",
                    )) 

                    self.add(pr.RemoteVariable(   
                        name         = 'FRAC_WF_F_CLKOUT_FB',
                        description = """
                            Adjusts CLKFBOUT falling edge for improved duty
                            cycle accuracy when using fractional counter.            
                            """,                
                        offset       =  (ClkReg2[i] << 2),
                        bitSize      =  1,
                        bitOffset    =  12 if UltraScale else 10,
                        mode         = "RW",
                    ))                 
                
            ##############################################################################     
                
            self.add(pr.RemoteVariable(   
                name         = f'MX[{i}]',
                description = """
                    Must be set to 2'b00.
                    """,                
                offset       =  (ClkReg2[i] << 2),
                bitSize      =  2,
                bitOffset    =  8,
                mode         = "WO",
            ))   
            
            self.add(pr.RemoteVariable(   
                name         = f'EDGE[{i}]',
                description = """
                    Chooses the edge that the High Time counter transitions on.
                    """,                
                offset       =  (ClkReg2[i] << 2),
                bitSize      =  1,
                bitOffset    =  7,
                mode         = "RW",
            ))  

            self.add(pr.RemoteVariable(   
                name         = f'NO_COUNT[{i}]',
                description = """
                    Bypasses the High and Low Time counters.
                    """,                
                offset       =  (ClkReg2[i] << 2),
                bitSize      =  1,
                bitOffset    =  6,
                mode         = "RW",
            ))  

            self.add(pr.RemoteVariable(   
                name         = f'DELAY_TIME[{i}]',
                description = """
                    Phase offset with a resolution equal to the VCO period.
                    """,                
                offset       =  (ClkReg2[i] << 2),
                bitSize      =  6,
                bitOffset    =  0,
                mode         = "RW",
            ))                       
            
        ##############################################################################            
        
        if (type is 'MMCME2') or (type is 'MMCME3') or (type is 'MMCME4'):
            
            self.add(pr.RemoteVariable(   
                name         = 'FRAC_FB',
                description = """
                    Fractional divide counter setting for CLKFBOUT. Equivalent to
                    additional divide of 1/8.               
                    """,                
                offset       =  (0x15 << 2),
                bitSize      =  3,
                bitOffset    =  12,
                mode         = "RW",
            ))    

            self.add(pr.RemoteVariable(   
                name         = 'FRAC_EN_FB',
                description = """
                    Enable fractional divider circuitry for CLKFBOUT.
                    """,                
                offset       =  (0x15 << 2),
                bitSize      =  1,
                bitOffset    =  11,
                mode         = "RW",
            ))

            self.add(pr.RemoteVariable(   
                name         = 'FRAC_WF_R_FB',
                description = """
                    Adjusts CLKFBOUT rising edge for improved duty cycle accuracy
                    when using fractional counter.
                    """,                
                offset       =  (0x15 << 2),
                bitSize      =  1,
                bitOffset    =  10,
                mode         = "RW",
            ))                
    
        ##############################################################################         
        # CLKFBOUT Register 2 (Address=0x15)    
        ############################################################################## 
    
        self.add(pr.RemoteVariable(   
            name         = 'MX_FB',
            description = """
                Must be set to 2'b00.
                """,                
            offset       =  (0x15 << 2),
            bitSize      =  2,
            bitOffset    =  8,
            mode         = "WO",
        ))   
        
        self.add(pr.RemoteVariable(   
            name         = 'EDGE_FB',
            description = """
                Chooses the edge that the High Time counter transitions on.
                """,                
            offset       =  (0x15 << 2),
            bitSize      =  1,
            bitOffset    =  7,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = 'NO_COUNT_FB',
            description = """
                Bypasses the High and Low Time counters.
                """,                
            offset       =  (0x15 << 2),
            bitSize      =  1,
            bitOffset    =  6,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = 'DELAY_TIME_FB',
            description = """
                Phase offset with a resolution equal to the VCO period.
                """,                
            offset       =  (0x15 << 2),
            bitSize      =  6,
            bitOffset    =  0,
            mode         = "RW",
        )) 

        ##############################################################################
        #            DIVCLK Bitmap
        ##############################################################################          
        # DIVCLK Register (Address=0x16)    
        
        self.add(pr.RemoteVariable(   
            name         = 'EDGE_DIV',
            description = """
                Chooses the edge that the High Time counter transitions on.
                """,                
            offset       =  (0x16 << 2),
            bitSize      =  1,
            bitOffset    =  13,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = 'NO_COUNT_DIV',
            description = """
                Bypasses the High and Low Time counters.
                """,                
            offset       =  (0x16 << 2),
            bitSize      =  1,
            bitOffset    =  12,
            mode         = "RW",
        ))        
        
        self.add(pr.RemoteVariable(   
            name         = 'HIGH_TIME_DIV',
            description = """
                Sets the amount of time in VCO cycles that the clock output
                remains High.                  
                """,                
            offset       =  (0x16 << 2),
            bitSize      =  6,
            bitOffset    =  6,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = 'LOW_TIME_DIV',
            description = """
                Sets the amount of time in VCO cycles that the clock output
                remains Low.                  
                """,                
            offset       =  (0x16 << 2),
            bitSize      =  6,
            bitOffset    =  0,
            mode         = "RW",
        ))          
        
        ##############################################################################
        #            Lock Group Bitmap
        ##############################################################################          
        # Lock Register 1 (Address=0x18)
        # Lock Register 2 (Address=0x19)
        # Lock Register 3 (Address=0x1A)        
        
        self.add(pr.RemoteVariable(   
            name         = 'LockReg[0]',
            description = """
                Three additional LOCK configuration registers must also be updated based on how the MMCM
                is programmed. These values are automatically setup by the reference design.
                """,                
            offset       =  (0x18 << 2),
            bitSize      =  16,
            bitOffset    =  0,
            mode         = "RW",
        ))  
        
        self.add(pr.RemoteVariable(   
            name         = 'LockReg[1]',
            description = """
                Three additional LOCK configuration registers must also be updated based on how the MMCM
                is programmed. These values are automatically setup by the reference design.
                """,                
            offset       =  (0x19 << 2),
            bitSize      =  16,
            bitOffset    =  0,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = 'LockReg[2]',
            description = """
                Three additional LOCK configuration registers must also be updated based on how the MMCM
                is programmed. These values are automatically setup by the reference design.
                """,                
            offset       =  (0x1A << 2),
            bitSize      =  16,
            bitOffset    =  0,
            mode         = "RW",
        ))           
        
        ##############################################################################
        #            Filter Group Bitmap
        ##############################################################################          
        # Filter Register 1 (Address=0x4E)
        # Filter Register 2 (Address=0x4F)   
        self.add(pr.RemoteVariable(   
            name         = 'FiltReg[0]',
            description = """
                This bit is pulled from the lookup table provided in the reference design.
                """,                
            offset       =  (0x4E << 2),
            bitSize      =  16,
            bitOffset    =  0,
            mode         = "RW",
        ))  
        
        self.add(pr.RemoteVariable(   
            name         = 'FiltReg[1]',
            description = """
                This bit is pulled from the lookup table provided in the reference design.
                """,                
            offset       =  (0x4F << 2),
            bitSize      =  16,
            bitOffset    =  0,
            mode         = "RW",
        ))  

        ##############################################################################
        #            PowerReg Bitmap
        ##############################################################################         
        # Power Register (Address=0x27): UltraScale and UltraScale+
        # Power Register (Address=0x28): 7 series
  
        self.add(pr.RemoteVariable(   
            name         = 'POWER',
            description = """
                These bits must all be set High when performing DRP.
                """,                
            offset       = (0x27 << 2) if (UltraScale) else (0x28 << 2),
            bitSize      = 16,
            bitOffset    = 0,
            mode         = "WO",
            value        = 0xFFFF
        ))      
