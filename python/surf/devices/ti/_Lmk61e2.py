#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Lmk61e2 Module
#-----------------------------------------------------------------------------
# File       : Lmk61e2.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue Lmk61e2 Module
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

class Lmk61e2(pr.Device):
    def __init__(   self,       
        name        = "Lmk61e2",
        description = "Lmk61e2 Module",
        **kwargs):
        
        super().__init__(name=name,description=description,**kwargs)

        self.add(pr.RemoteVariable(
            name         = 'VNDRID_BY[1]', 
            description  = 'VNDRID_BY1 and VNDRID_BY0 registers are used to store the unique 16-bit Vendor Identification number assigned to I2C vendors.',
            offset       = (0 << 2),
            bitSize      = 8, 
            bitOffset    = 0, 
            mode         = 'RO',
        ))  

        self.add(pr.RemoteVariable(
            name         = 'VNDRID_BY[0]', 
            description  = 'VNDRID_BY0 and VNDRID_BY0 registers are used to store the unique 16-bit Vendor Identification number assigned to I2C vendors.',
            offset       = (1 << 2),
            bitSize      = 8, 
            bitOffset    = 0, 
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'PRODID', 
            description  = 'The Product Identification Number is a unique 8-bit identification number used to identify the LMK61E2.',
            offset       = (2 << 2),
            bitSize      = 8, 
            bitOffset    = 0, 
            mode         = 'RO',
        )) 

        self.add(pr.RemoteVariable(
            name         = 'REVID', 
            description  = 'The REVID register is used to identify the LMK61E2 mask revision',
            offset       = (3 << 2),
            bitSize      = 8, 
            bitOffset    = 0, 
            mode         = 'RO',
        )) 

        self.add(pr.RemoteVariable(
            name         = 'SLAVEADR', 
            description  = 'The SLAVEADR register reflects the 7-bit I2C Slave Address value initialized from from on-chip EEPROM',
            offset       = (8 << 2),
            bitSize      = 7, 
            bitOffset    = 1, 
            mode         = 'RO',
        ))         
        
        self.add(pr.RemoteVariable(
            name         = 'EEREV', 
            description  = 'The EEREV register provides an EEPROM image revision record. EEPROM Image Revision is automatically retrieved from EEPROM and stored in the EEREV register after a reset or after a EEPROM commit operation.',
            offset       = (9 << 2),
            bitSize      = 8, 
            bitOffset    = 0, 
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'AUTOSTRT', 
            description  = 'Autostart. If AUTOSTRT is set to 1 the device will automatically attempt to achieve lock and enable outputs after a device reset. A device reset can be triggered by the power-on-reset, RESETn pin or by writing to the RESETN_SW bit. If AUTOSTRT is 0 then the device will halt after the configuration phase, a subsequent write to set the AUTOSTRT bit to 1 will trigger the PLL Lock sequence.',
            offset       = (10 << 2),
            bitSize      = 1, 
            bitOffset    = 0, 
            mode         = 'RW',
        ))  

        self.add(pr.RemoteVariable(
            name         = 'ENCAL', 
            description  = 'Enable Frequency Calibration. Triggers PLL/VCO calibration on both PLLs in parallel on 0 –> 1 transition of ENCAL. This bit is self-clearing and set to a 0 after PLL/VCO calibration is complete. In powerup or software rest mode, AUTOSTRT takes precedence.',
            offset       = (10 << 2),
            bitSize      = 1, 
            bitOffset    = 1, 
            mode         = 'RW',
        )) 

        self.add(pr.RemoteVariable(
            name         = 'PLL_PDN', 
            description  = 'PLL Powerdown. The PLL_PDN bit determines whether PLL is automatically enabled and calibrated after a hardware reset. If the PLL_PDN bit is set to 1 during normal operation then PLL is disabled and the calibration circuit is reset. When PLL_PDN is then cleared to 0 PLL is re-enabled and the calibration sequence is automatically restarted.',
            offset       = (10 << 2),
            bitSize      = 1, 
            bitOffset    = 6, 
            mode         = 'RW',
        ))  

        self.add(pr.RemoteVariable(
            name         = 'XO_CAPCTRL_BY[1]', 
            description  = 'XO Offset Value bits [1:0]',
            offset       = (16 << 2),
            bitSize      = 2, 
            bitOffset    = 0, 
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'XO_CAPCTRL_BY[0]', 
            description  = 'XO Offset Value bits[9:2]',
            offset       = (17 << 2),
            bitSize      = 8, 
            bitOffset    = 0, 
            mode         = 'RW',
        ))        
        
        self.add(pr.RemoteVariable(
            name         = 'OUT_SEL', 
            description  = 'Channel Output Driver Format Select',
            offset       = (21 << 2),
            bitSize      = 2, 
            bitOffset    = 0, 
            mode         = 'RW',
        )) 

        self.add(pr.RemoteVariable(
            name         = 'DIFF_OUT_PD', 
            description  = 'Power down differential output buffer.',
            offset       = (21 << 2),
            bitSize      = 1, 
            bitOffset    = 7, 
            mode         = 'RW',
        ))         
        
        self.add(pr.RemoteVariable(
            name         = 'OUTDIV_BY[1]', 
            description  = 'Channel\'s Output Divider Byte 1 (Bit 8). The Channel Divider, OUT_DIV, is a 9-bit divider',
            offset       = (22 << 2),
            bitSize      = 1, 
            bitOffset    = 0, 
            mode         = 'RW',
        )) 

        self.add(pr.RemoteVariable(
            name         = 'OUTDIV_BY[0]', 
            description  = 'Channel\'s Output Divider Byte 0 (Bits 7-0).',
            offset       = (23 << 2),
            bitSize      = 8, 
            bitOffset    = 0, 
            mode         = 'RW',
        )) 

        self.add(pr.RemoteVariable(
            name         = 'PLL_NDIV_BY[1]', 
            description  = 'PLL N Divider Byte 1. PLL Integer N Divider bits [11:8].',
            offset       = (25 << 2),
            bitSize      = 4, 
            bitOffset    = 0, 
            mode         = 'RW',
        )) 

        self.add(pr.RemoteVariable(
            name         = 'PLL_NDIV_BY[0]', 
            description  = 'PLL N Divider Byte 0. PLL Integer N Divider bits [7:0].',
            offset       = (26 << 2),
            bitSize      = 8, 
            bitOffset    = 0, 
            mode         = 'RW',
        )) 

        self.add(pr.RemoteVariable(
            name         = 'PLL_FRACNUM_BY[2]', 
            description  = 'PLL Fractional Divider Numerator Byte 2. Bits [21:16]',
            offset       = (27 << 2),
            bitSize      = 6, 
            bitOffset    = 0, 
            mode         = 'RW',
        ))    

        self.add(pr.RemoteVariable(
            name         = 'PLL_FRACNUM_BY[1]', 
            description  = 'PLL Fractional Divider Numerator Byte 1. Bits [15:8].',
            offset       = (28 << 2),
            bitSize      = 8, 
            bitOffset    = 0, 
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'PLL_FRACNUM_BY[0]', 
            description  = 'PLL Fractional Divider Numerator Byte 0. Bits [7:0].',
            offset       = (29 << 2),
            bitSize      = 8, 
            bitOffset    = 0, 
            mode         = 'RW',
        ))  

        self.add(pr.RemoteVariable(
            name         = 'PLL_FRACDEN_BY[2]', 
            description  = 'PLL Fractional Divider Denominator Byte 2. Bits [21:16]',
            offset       = (30 << 2),
            bitSize      = 6, 
            bitOffset    = 0, 
            mode         = 'RW',
        ))    

        self.add(pr.RemoteVariable(
            name         = 'PLL_FRACDEN_BY[1]', 
            description  = 'PLL Fractional Divider Denominator Byte 1. Bits [15:8].',
            offset       = (31 << 2),
            bitSize      = 8, 
            bitOffset    = 0, 
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'PLL_FRACDEN_BY[0]', 
            description  = 'PLL Fractional Divider Denominator Byte 0. Bits [7:0].',
            offset       = (32 << 2),
            bitSize      = 8, 
            bitOffset    = 0, 
            mode         = 'RW',
        ))  

        self.add(pr.RemoteVariable(
            name         = 'PLL_ORDER', 
            description  = 'Mash Engine Order.',
            offset       = (33 << 2),
            bitSize      = 2, 
            bitOffset    = 0, 
            mode         = 'RW',
        ))  

        self.add(pr.RemoteVariable(
            name         = 'PLL_DTHRMODE', 
            description  = 'Mash Engine dither mode control.',
            offset       = (33 << 2),
            bitSize      = 2, 
            bitOffset    = 2, 
            mode         = 'RW',
        )) 

        self.add(pr.RemoteVariable(
            name         = 'PLL_CP', 
            description  = 'PLL Charge Pump Current',
            offset       = (34 << 2),
            bitSize      = 4, 
            bitOffset    = 0, 
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'PLL_D', 
            description  = 'PLL R Divider Frequency Doubler Enable. If PLL_D is 1 the R Divider Frequency Doubler is enabled.',
            offset       = (34 << 2),
            bitSize      = 1, 
            bitOffset    = 5, 
            mode         = 'RW',
        ))    

        self.add(pr.RemoteVariable(
            name         = 'PLL_ENABLE_C3', 
            description  = 'Disable third order capacitor in the low pass filter.',
            offset       = (35 << 2),
            bitSize      = 3, 
            bitOffset    = 0, 
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'PLL_CP_PHASE_SHIFT', 
            description  = 'Program Charge Pump Phase Shift.',
            offset       = (35 << 2),
            bitSize      = 3, 
            bitOffset    = 4, 
            mode         = 'RW',
        ))        
        
        self.add(pr.RemoteVariable(
            name         = 'PLL_LF_R2', 
            description  = 'PLL Loop Filter R2.',
            offset       = (36 << 2),
            bitSize      = 8, 
            bitOffset    = 0, 
            mode         = 'RW',
        ))  

        self.add(pr.RemoteVariable(
            name         = 'PLL_LF_C1', 
            description  = 'PLL Loop Filter C1. The value in pF is given by 5 + 50 * PLL_LF_C1 (in decimal).',
            offset       = (37 << 2),
            bitSize      = 3, 
            bitOffset    = 0, 
            mode         = 'RW',
        ))   

        self.add(pr.RemoteVariable(
            name         = 'PLL_LF_R3', 
            description  = 'PLL Loop Filter R3',
            offset       = (38 << 2),
            bitSize      = 7, 
            bitOffset    = 0, 
            mode         = 'RW',
        ))           
        
        self.add(pr.RemoteVariable(
            name         = 'PLL_LF_C3', 
            description  = 'PLL Loop Filter C3',
            offset       = (39 << 2),
            bitSize      = 3, 
            bitOffset    = 0, 
            mode         = 'RW',
        ))    

        self.add(pr.RemoteVariable(
            name         = 'PLL_VCOWAIT', 
            description  = 'VCO Wait Period',
            offset       = (42 << 2),
            bitSize      = 2, 
            bitOffset    = 0, 
            mode         = 'RW',
        )) 

        self.add(pr.RemoteVariable(
            name         = 'PLL_CLSDWAIT', 
            description  = 'Closed Loop Wait Period',
            offset       = (42 << 2),
            bitSize      = 2, 
            bitOffset    = 2, 
            mode         = 'RW',
        ))         
        
        self.add(pr.RemoteVariable(
            name         = 'NVMSCRC', 
            description  = 'The NVMSCRC register holds the Stored CRC (Cyclic Redundancy Check) byte that has been retreived from onchip EEPROM',
            offset       = (47 << 2),
            bitSize      = 8, 
            bitOffset    = 0, 
            mode         = 'RO',
        )) 

        self.add(pr.RemoteVariable(
            name         = 'NVMCNT', 
            description  = 'The NVMCNT register is intended to reflect the number of on-chip EEPROM Erase/Program cycles that have taken place in EEPROM. The count is automatically incremented by hardware and stored in EEPROM.',
            offset       = (48 << 2),
            bitSize      = 8, 
            bitOffset    = 0, 
            mode         = 'RO',
        ))         
        
        self.add(pr.RemoteVariable(
            name         = 'NVMPROG', 
            description  = 'EEPROM Program Start. The NVMPROG bit is used to begin an on-chip EEPROM Program cycle. The Program cycle is only initiated if the immediately preceding I2C transaction was a write to the NVMUNLK register with the appropriate code. The NVMPROG bit is automatically cleared to 0. If the NVMERASE and NVMPROG bits are set simultaneously then an ERASE/PROGRAM cycle will be executed The EEPROM Program operation takes around 115ms',
            offset       = (49 << 2),
            bitSize      = 1, 
            bitOffset    = 0, 
            mode         = 'RW',
        )) 

        self.add(pr.RemoteVariable(
            name         = 'NVMERASE', 
            description  = 'EEPROM Erase Start. The NVMERASE bit is used to begin an on-chip EEPROM Erase cycle. The Erase cycle is only initiated if the immediately preceding I2C transaction was a write to the NVMUNLK register with the appropriate code. The NVMERASE bit is automatically cleared to 0. The EEPROM Erase operation takes around 115ms.',
            offset       = (49 << 2),
            bitSize      = 1, 
            bitOffset    = 1, 
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'NVMBUSY', 
            description  = 'EEPROM Program Busy Indication. The NVMBUSY bit is 1 during an on-chip EEPROM Erase/Program cycle. While NVMBUSY is 1 the on-chip EEPROM cannot be accessed.',
            offset       = (49 << 2),
            bitSize      = 1, 
            bitOffset    = 2, 
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'NVMCOMMIT', 
            description  = 'EEPROM Commit to Registers. The NVMCOMMIT bit is used to initiate a transfer of the on-chip EEPROM contents to internal registers. The transfer happens automatically after reset or when NVMCOMMIT is set to 1. The NVMCOMMIT bit is automatically cleared to 0. The I2C registers cannot be read while a EEPROM Commit operation is taking place.',
            offset       = (49 << 2),
            bitSize      = 1, 
            bitOffset    = 3, 
            mode         = 'RW',
        ))  

        self.add(pr.RemoteVariable(
            name         = 'NVMAUTOCRC', 
            description  = 'EEPROM Automatic CRC. When NVMAUTOCRC is 1 then the EEPROM Stored CRC byte is automatically calculated whenever a EEPROM program takes place.',
            offset       = (49 << 2),
            bitSize      = 1, 
            bitOffset    = 4, 
            mode         = 'RW',
        ))  

        self.add(pr.RemoteVariable(
            name         = 'NVMCRCERR', 
            description  = 'EEPROM CRC Error Indication. The NVMCRCERR bit is set to 1 if a CRC Error has been detected when reading back from on-chip EEPROM during device configuration.',
            offset       = (49 << 2),
            bitSize      = 1, 
            bitOffset    = 5, 
            mode         = 'RO',
        ))  

        self.add(pr.RemoteVariable(
            name         = 'REGCOMMIT', 
            description  = 'REG Commit to EEPROM SRAM Array. The REGCOMMIT bit is used to initiate a transfer from the on-chip registers back to the corresponding location in the EEPROM SRAM Array. The REGCOMMIT bit is automatically cleared to 0 when the transfer is complete.',
            offset       = (49 << 2),
            bitSize      = 1, 
            bitOffset    = 6, 
            mode         = 'RW',
        ))          
                
        self.add(pr.RemoteVariable(
            name         = 'NVMLCRC', 
            description  = '',
            offset       = (50 << 2),
            bitSize      = 8, 
            bitOffset    = 0, 
            mode         = 'RO',
        )) 

        self.add(pr.RemoteVariable(
            name         = 'MEMADR', 
            description  = 'Memory Address. The MEMADR value determines the starting address for on-chip SRAM read/write access or on-chip EEPROM access. The internal address to access SRAM or EEPROM is automatically incremented; however the MEMADR register does not reflect the internal address in this way. When the SRAM or EEPROM arrays are accessed using the I2C interface only bits [4:0] of MEMADR are used to form the byte Wise address.',
            offset       = (51 << 2),
            bitSize      = 7, 
            bitOffset    = 0, 
            mode         = 'RW',
        ))         
        
        self.add(pr.RemoteVariable(
            name         = 'NVMDAT', 
            description  = 'EEPROM Read Data. The first time an I2C read transaction accesses the NVMDAT register address, either because it was explicitly targeted or because the address was autoincremented, the read transaction will return the EEPROM data located at the address specified by the MEMADR register. Any additional read\'s which are part of the same transaction will cause the EEPROM address to be incremented and the next EEPROM data byte will be returned. The I2C address will no longer be auto-incremented, i.e the I2C address will be locked to the NVMDAT register after the first access. Access to the NVMDAT register will terminate at the end of the current I2C transaction.',
            offset       = (52 << 2),
            bitSize      = 8, 
            bitOffset    = 0, 
            mode         = 'RO',
        ))       

        self.add(pr.RemoteVariable(
            name         = 'RAMDAT', 
            description  = 'RAM Read/Write Data. The first time an I2C read or write transaction accesses the RAMDAT register address, either because it was explicitly targeted or because the address was auto-incremented, a read transaction will return the RAM data located at the address specified by the MEMADR register and a write transaction will cause the current I2C data to be written to the address specified by the MEMADR register. Any additional accesses which are part of the same transaction will cause the RAM address to be incremented and a read or write access will take place to the next SRAM address. The I2C address will no longer be auto-incremented, i.e the I2C address will be locked to the RAMDAT register after the first access. Access to the RAMDAT register will terminate at the end of the current I2C transaction.',
            offset       = (53 << 2),
            bitSize      = 8, 
            bitOffset    = 0, 
            mode         = 'RW',
        ))   

        self.add(pr.RemoteVariable(
            name         = 'NVMUNLK', 
            description  = 'EEPROM Prog Unlock. The NVMUNLK register must be written immediately prior to setting the NVMPROG bit of register NVMCTL, otherwise the Erase/Program cycle will not be triggered. NVMUNLK must be written with a value of 0xBE.',
            offset       = (56 << 2),
            bitSize      = 8, 
            bitOffset    = 0, 
            mode         = 'RW',
        ))  

        self.add(pr.RemoteVariable(
            name         = 'CAL', 
            description  = 'Calibration Active PLL.',
            offset       = (66 << 2),
            bitSize      = 1, 
            bitOffset    = 0, 
            mode         = 'RO',
        ))  

        self.add(pr.RemoteVariable(
            name         = 'LOL', 
            description  = 'Loss of Lock PLL.',
            offset       = (66 << 2),
            bitSize      = 1, 
            bitOffset    = 1, 
            mode         = 'RO',
        ))   

        self.add(pr.RemoteVariable(
            name         = 'SWR2PLL', 
            description  = 'Software Reset PLL. Setting SWR2PLL to 1 resets the PLL calibrator and clock dividers. This bit is automatically cleared to 0.',
            offset       = (72 << 2),
            bitSize      = 1, 
            bitOffset    = 1, 
            mode         = 'RW',
        ))           
        