#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device AxiXadc
#-----------------------------------------------------------------------------
# File       : AxiXadc.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for AxiXadc
# Auto created from ../surf/xilinx/7Series/xadc/yaml/AxiXadc.yaml
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the rogue software platform, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue
    
# def getTemp(dev, var):
    # value   = var.dependencies[0].get(read=False)
    # fpValue = value*(503.975/4096.0)
    # fpValue -= 273.15
    # return '%0.1f'%(fpValue)    

# def getVolt(dev, var):
    # value   = var.dependencies[0].get(read=False)
    # fpValue = value*(732.0E-6)
    # return '%0.3f V'%(fpValue)

def create(name='axiXadc', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x800,
                         description='AXI-Lite XADC for Xilinx 7 Series (Refer to PG091 & PG019)')

    dev.add(pyrogue.Variable(name='SRR',
                             description='Software Reset Register',
                             hidden=True, enum=None, offset=0x0, bitSize=32, bitOffset=0, base='hex', mode='WO'))

    dev.add(pyrogue.Variable(name='SR',
                             description='Status Register',
                             hidden=True, enum=None, offset=0x4, bitSize=32, bitOffset=0, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='AOSR',
                             description='Alarm Output Status Register',
                             hidden=True, enum=None, offset=0x8, bitSize=32, bitOffset=0, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='CONVSTR',
                             description='CONVST Register',
                             hidden=True, enum=None, offset=0xc, bitSize=32, bitOffset=0, base='hex', mode='WO'))

    dev.add(pyrogue.Variable(name='SYSMONRR',
                             description='XADC Hard Macro Reset Register',
                             hidden=True, enum=None, offset=0x10, bitSize=32, bitOffset=0, base='hex', mode='WO'))

    dev.add(pyrogue.Variable(name='GIER',
                             description='Global Interrupt Enable Register',
                             hidden=True, enum=None, offset=0x5c, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='IPISR',
                             description='IP Interrupt Status Register',
                             hidden=True, enum=None, offset=0x60, bitSize=32, bitOffset=0, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='IPIER',
                             description='IP Interrupt Enable Register',
                             hidden=True, enum=None, offset=0x68, bitSize=32, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='tempVar',
                             description="""
                                         The result of the on-chip temperature sensor measurement is 
                                         stored in this location. The data is MSB justified in the 
                                         16-bit register (Read Only).  The 12 MSBs correspond to the 
                                         temperature sensor transfer function shown in Figure 2-8, 
                                         page 31 of UG480 (v1.2)
                                         """,
                             hidden=False, enum=None, offset=0x200, bitSize=12, bitOffset=4, base='hex', mode='RO'))
    # dev.add(pyrogue.Variable(name="temp", description="temperature", 
            # mode = 'RO',  base='string', units="degree C",
            # getFunction=getTemp, dependencies=[dev.tempVar]))
                             
    dev.add(pyrogue.Variable(name='vCCINT',
                             description="""
                                         The result of the on-chip VccInt supply monitor measurement 
                                         is stored at this location. The data is MSB justified in the 
                                         16-bit register (Read Only). The 12 MSBs correspond to the 
                                         supply sensor transfer function shown in Figure 2-9, 
                                         page 32 of UG480 (v1.2)     
                                         """,
                             hidden=True, enum=None, offset=0x204, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='vCCAUX',
                             description="""
                                         The result of the on-chip VccAux supply monitor measurement 
                                         is stored at this location. The data is MSB justified in the 
                                         16-bit register (Read Only). The 12 MSBs correspond to the 
                                         supply sensor transfer function shown in Figure 2-9, 
                                         page 32 of UG480 (v1.2)
                                         """,
                             hidden=True, enum=None, offset=0x208, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='vP_VN',
                             description="""
                                         The result of a conversion on the dedicated analog input 
                                         channel is stored in this register. The data is MSB justified 
                                         in the 16-bit register (Read Only). The 12 MSBs correspond to the 
                                         transfer function shown in Figure 2-5, page 29 or 
                                         Figure 2-6, page 29 of UG480 (v1.2) depending on analog input mode 
                                         settings.
                                         """,
                             hidden=True, enum=None, offset=0x20c, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='vREFP',
                             description="""
                                         The result of a conversion on the reference input VrefP is 
                                         stored in this register. The 12 MSBs correspond to the ADC 
                                         transfer function shown in Figure 2-9  of UG480 (v1.2). The data is MSB 
                                         justified in the 16-bit register (Read Only). The supply sensor is used 
                                         when measuring VrefP.
                                         """,
                             hidden=True, enum=None, offset=0x210, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='vREFN',
                             description="""
                                         The result of a conversion on the reference input VREFN is 
                                         stored in this register (Read Only). This channel is measured in bipolar 
                                         mode with a 2's complement output coding as shown in 
                                         Figure 2-2, page 25. By measuring in bipolar mode, small 
                                         positive and negative at: offset around 0V (VrefN) can be 
                                         measured. The supply sensor is also used to measure 
                                         VrefN, thus 1 LSB = 3V/4096. The data is MSB justified in 
                                         the 16-bit register.      
                                         """,
                             hidden=True, enum=None, offset=0x214, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='vBRAM',
                             description="""
                                         The result of the on-chip VccBram supply monitor measurement 
                                         is stored at this location. The data is MSB justified in the 
                                         16-bit register (Read Only). The 12 MSBs correspond to the 
                                         supply sensor transfer function shown in Figure 2-9, 
                                         page 32 of UG480 (v1.2)
                                         """,
                             hidden=True, enum=None, offset=0x218, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='supplyOffset',
                             description="""
                                         The calibration coefficient for the supply sensor at: offset 
                                         using ADC A is stored at this location (Read Only).
                                         """,
                             hidden=True, enum=None, offset=0x220, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='aDCOffset',
                             description="""
                                         The calibration coefficient for the ADC A at: offset is stored at 
                                         this location (Read Only).
                                         """,
                             hidden=True, enum=None, offset=0x224, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='gainError',
                             description="""
                                         The calibration coefficient for the ADC A gain error is 
                                         stored at this location (Read Only).
                                         """,
                             hidden=True, enum=None, offset=0x228, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='vCCPINT',
                             description="""
                                         The result of a conversion on the PS supply, VccpInt is 
                                         stored in this register. The 12 MSBs correspond to the ADC 
                                         transfer function shown in Figure 2-9, page 32 of UG480 (v1.2). The data is 
                                         MSB justified in the 16-bit register (Zynq Only and Read Only).
                                         The supply sensor is used when measuring VccpInt.
                                         """,
                             hidden=True, enum=None, offset=0x234, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='vCCPAUX',
                             description="""
                                         The result of a conversion on the PS supply, VccpAux is 
                                         stored in this register. The 12 MSBs correspond to the ADC 
                                         transfer function shown in Figure 2-9, page 32 of UG480 (v1.2). The data is 
                                         MSB justified in the 16-bit register (Zynq Only and Read Only). 
                                         The supply sensor is used when measuring VccpAux.
                                         """,
                             hidden=True, enum=None, offset=0x238, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='vCCDDRO',
                             description="""
                                         The result of a conversion on the PS supply, VccpDdr is 
                                         stored in this register. The 12 MSBs correspond to the ADC 
                                         transfer function shown in Figure 2-9, page 32 of UG480 (v1.2). The data is 
                                         MSB justified in the 16-bit register (Zynq Only and Read Only). 
                                         The supply sensor is used when measuring VccpDdr.                                        
                                         """,
                             hidden=True, enum=None, offset=0x23c, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='maxTemp',
                             description="""
                                         Maximum temperature measurement recorded since 
                                         power-up or the last AxiXadc reset (Read Only).
                                         """,
                             hidden=True, enum=None, offset=0x280, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='maxVCCINT',
                             description="""
                                         Maximum VccInt measurement recorded since power-up 
                                         or the last AxiXadc reset (Read Only).
                                         """,
                             hidden=True, enum=None, offset=0x284, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='maxVCCAUX',
                             description="""
                                         Maximum VccAux measurement recorded since power-up 
                                         or the last AxiXadc reset (Read Only).
                                         """,
                             hidden=True, enum=None, offset=0x288, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='maxVBRAM',
                             description="""
                                         Maximum VccBram measurement recorded since power-up 
                                         or the last AxiXadc reset (Read Only).
                                         """,
                             hidden=True, enum=None, offset=0x28c, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='minTemp',
                             description="""
                                         Minimum temperature measurement recorded since power-up 
                                         or the last AxiXadc reset (Read Only).
                                         """,
                             hidden=True, enum=None, offset=0x290, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='minVCCINT',
                             description="""
                                         Minimum VccInt measurement recorded since power-up 
                                         or the last AxiXadc reset (Read Only).
                                         """,
                             hidden=True, enum=None, offset=0x294, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='minVCCAUX',
                             description="""
                                         Minimum VccAux measurement recorded since power-up 
                                         or the last AxiXadc reset (Read Only).
                                         """,
                             hidden=True, enum=None, offset=0x298, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='minVBRAM',
                             description="""
                                         Minimum VccBram measurement recorded since power-up 
                                         or the last AxiXadc reset (Read Only).
                                         """,
                             hidden=True, enum=None, offset=0x29c, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='maxVCCPINT',
                             description="""
                                         Maximum VccpInt measurement recorded since power-up 
                                         or the last AxiXadc reset (Zynq Only and Read Only).
                                         """,
                             hidden=True, enum=None, offset=0x20, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='maxVCCPAUX',
                             description="""
                                         Maximum VccpAux measurement recorded since power-up 
                                         or the last AxiXadc reset (Zynq Only and Read Only).
                                         """,
                             hidden=True, enum=None, offset=0x2a4, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='maxVCCDDRO',
                             description="""
                                         Maximum VccpDdr measurement recorded since power-up 
                                         or the last AxiXadc reset (Zynq Only and Read Only).
                                         """,
                             hidden=True, enum=None, offset=0x2a8, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='minVCCPINT',
                             description="""
                                         Minimum VccpInt measurement recorded since power-up 
                                         or the last AxiXadc reset (Zynq Only and Read Only).
                                         """,
                             hidden=True, enum=None, offset=0x2b0, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='minVCCPAUX',
                             description="""
                                         Minimum VccpAux measurement recorded since power-up 
                                         or the last AxiXadc reset (Zynq Only and Read Only).
                                         """,
                             hidden=True, enum=None, offset=0x2b4, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='minVCCDDRO',
                             description="""
                                         Minimum VccpDdr measurement recorded since power-up 
                                         or the last AxiXadc reset (Zynq Only and Read Only).
                                         """,
                             hidden=True, enum=None, offset=0x2b8, bitSize=12, bitOffset=4, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='flagRegister',
                             description='This register contains general status information (Read Only). Flag Register Bits are defined in Figure 3-2 and Table 3-2 on page 37 of UG480 (v1.2)',
                             hidden=True, enum=None, offset=0x2fc, bitSize=32, bitOffset=0, base='hex', mode='RO'))

    return dev
