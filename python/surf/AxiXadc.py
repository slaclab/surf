#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device AxiXadc
#-----------------------------------------------------------------------------
# File       : AxiXadc.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-10-24
# Last update: 2016-10-24
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

def create(name='axiXadc', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x800,
                         description='AXI-Lite XADC for Xilinx 7 Series (Refer to PG091 & PG019)')

    dev.add(pyrogue.Variable(name='sRR',
                             description='Software Reset Register',
                             hidden=False, enum=None, offset=0x0, bitSize=32, bitOffset=0, base='uint', mode='WO'))

    dev.add(pyrogue.Variable(name='sR',
                             description='Status Register',
                             hidden=False, enum=None, offset=0x4, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='aOSR',
                             description='Alarm Output Status Register',
                             hidden=False, enum=None, offset=0x8, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='cONVSTR',
                             description='CONVST Register',
                             hidden=False, enum=None, offset=0xc, bitSize=32, bitOffset=0, base='uint', mode='WO'))

    dev.add(pyrogue.Variable(name='sYSMONRR',
                             description='XADC Hard Macro Reset Register',
                             hidden=False, enum=None, offset=0x10, bitSize=32, bitOffset=0, base='uint', mode='WO'))

    dev.add(pyrogue.Variable(name='gIER',
                             description='Global Interrupt Enable Register',
                             hidden=False, enum=None, offset=0x5c, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='iPISR',
                             description='IP Interrupt Status Register',
                             hidden=False, enum=None, offset=0x60, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='iPIER',
                             description='IP Interrupt Enable Register',
                             hidden=False, enum=None, offset=0x68, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='temperature',
                             description='The result of the on-chip temperature sensor measurement is 
stored in this location. The data is MSB justified in the 
16-bit register (Read Only).  The 12 MSBs correspond to the 
temperature sensor transfer function shown in Figure 2-8, 
page 31 of UG480 (v1.2)
',
                             hidden=False, enum=None, offset=0x200, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='vCCINT',
                             description='The result of the on-chip VccInt supply monitor measurement 
is stored at this location. The data is MSB justified in the 
16-bit register (Read Only). The 12 MSBs correspond to the 
supply sensor transfer function shown in Figure 2-9, 
page 32 of UG480 (v1.2)     
',
                             hidden=False, enum=None, offset=0x204, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='vCCAUX',
                             description='The result of the on-chip VccAux supply monitor measurement 
is stored at this location. The data is MSB justified in the 
16-bit register (Read Only). The 12 MSBs correspond to the 
supply sensor transfer function shown in Figure 2-9, 
page 32 of UG480 (v1.2)
',
                             hidden=False, enum=None, offset=0x208, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='vP_VN',
                             description='The result of a conversion on the dedicated analog input 
channel is stored in this register. The data is MSB justified 
in the 16-bit register (Read Only). The 12 MSBs correspond to the 
transfer function shown in Figure 2-5, page 29 or 
Figure 2-6, page 29 of UG480 (v1.2) depending on analog input mode 
settings.
',
                             hidden=False, enum=None, offset=0x20c, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='vREFP',
                             description='The result of a conversion on the reference input VrefP is 
stored in this register. The 12 MSBs correspond to the ADC 
transfer function shown in Figure 2-9  of UG480 (v1.2). The data is MSB 
justified in the 16-bit register (Read Only). The supply sensor is used 
when measuring VrefP.
',
                             hidden=False, enum=None, offset=0x210, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='vREFN',
                             description='The result of a conversion on the reference input VREFN is 
stored in this register (Read Only). This channel is measured in bipolar 
mode with a 2's complement output coding as shown in 
Figure 2-2, page 25. By measuring in bipolar mode, small 
positive and negative at: offset around 0V (VrefN) can be 
measured. The supply sensor is also used to measure 
VrefN, thus 1 LSB = 3V/4096. The data is MSB justified in 
the 16-bit register.      
',
                             hidden=False, enum=None, offset=0x214, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='vBRAM',
                             description='The result of the on-chip VccBram supply monitor measurement 
is stored at this location. The data is MSB justified in the 
16-bit register (Read Only). The 12 MSBs correspond to the 
supply sensor transfer function shown in Figure 2-9, 
page 32 of UG480 (v1.2)
',
                             hidden=False, enum=None, offset=0x218, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='supplyOffset',
                             description='The calibration coefficient for the supply sensor at: offset 
using ADC A is stored at this location (Read Only).
',
                             hidden=False, enum=None, offset=0x220, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='aDCOffset',
                             description='The calibration coefficient for the ADC A at: offset is stored at 
this location (Read Only).
',
                             hidden=False, enum=None, offset=0x224, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='gainError',
                             description='The calibration coefficient for the ADC A gain error is 
stored at this location (Read Only).
',
                             hidden=False, enum=None, offset=0x228, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='vCCPINT',
                             description='The result of a conversion on the PS supply, VccpInt is 
stored in this register. The 12 MSBs correspond to the ADC 
transfer function shown in Figure 2-9, page 32 of UG480 (v1.2). The data is 
MSB justified in the 16-bit register (Zynq Only and Read Only).
The supply sensor is used when measuring VccpInt.
',
                             hidden=False, enum=None, offset=0x234, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='vCCPAUX',
                             description='The result of a conversion on the PS supply, VccpAux is 
stored in this register. The 12 MSBs correspond to the ADC 
transfer function shown in Figure 2-9, page 32 of UG480 (v1.2). The data is 
MSB justified in the 16-bit register (Zynq Only and Read Only). 
The supply sensor is used when measuring VccpAux.
',
                             hidden=False, enum=None, offset=0x238, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='vCCDDRO',
                             description='The result of a conversion on the PS supply, VccpDdr is 
stored in this register. The 12 MSBs correspond to the ADC 
transfer function shown in Figure 2-9, page 32 of UG480 (v1.2). The data is 
MSB justified in the 16-bit register (Zynq Only and Read Only). 
The supply sensor is used when measuring VccpDdr.
',
                             hidden=False, enum=None, offset=0x23c, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='vAUXP_VAUXN',
                             description='The results of the conversions on auxiliary analog input 
channels are stored in this register. The data is MSB 
justified in the 16-bit register (Read Only). The 12 MSBs correspond to 
the transfer function shown in Figure 2-1, page 24 or 
Figure 2-2, page 25 of UG480 (v1.2) depending on analog input mode 
settings.
',
                             hidden=False, enum=None, offset=0x240, bitSize=192, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='maxTemp',
                             description='Maximum temperature measurement recorded since 
power-up or the last AxiXadc reset (Read Only).
',
                             hidden=False, enum=None, offset=0x280, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='maxVCCINT',
                             description='Maximum VccInt measurement recorded since power-up 
or the last AxiXadc reset (Read Only).
',
                             hidden=False, enum=None, offset=0x284, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='maxVCCAUX',
                             description='Maximum VccAux measurement recorded since power-up 
or the last AxiXadc reset (Read Only).
',
                             hidden=False, enum=None, offset=0x288, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='maxVBRAM',
                             description='Maximum VccBram measurement recorded since power-up 
or the last AxiXadc reset (Read Only).
',
                             hidden=False, enum=None, offset=0x28c, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='minTemp',
                             description='Minimum temperature measurement recorded since power-up 
or the last AxiXadc reset (Read Only).
',
                             hidden=False, enum=None, offset=0x290, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='minVCCINT',
                             description='Minimum VccInt measurement recorded since power-up 
or the last AxiXadc reset (Read Only).
',
                             hidden=False, enum=None, offset=0x294, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='minVCCAUX',
                             description='Minimum VccAux measurement recorded since power-up 
or the last AxiXadc reset (Read Only).
',
                             hidden=False, enum=None, offset=0x298, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='minVBRAM',
                             description='Minimum VccBram measurement recorded since power-up 
or the last AxiXadc reset (Read Only).
',
                             hidden=False, enum=None, offset=0x29c, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='maxVCCPINT',
                             description='Maximum VccpInt measurement recorded since power-up 
or the last AxiXadc reset (Zynq Only and Read Only).
',
                             hidden=False, enum=None, offset=0x20, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='maxVCCPAUX',
                             description='Maximum VccpAux measurement recorded since power-up 
or the last AxiXadc reset (Zynq Only and Read Only).
',
                             hidden=False, enum=None, offset=0x2a4, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='maxVCCDDRO',
                             description='Maximum VccpDdr measurement recorded since power-up 
or the last AxiXadc reset (Zynq Only and Read Only).
',
                             hidden=False, enum=None, offset=0x2a8, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='minVCCPINT',
                             description='Minimum VccpInt measurement recorded since power-up 
or the last AxiXadc reset (Zynq Only and Read Only).
',
                             hidden=False, enum=None, offset=0x2b0, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='minVCCPAUX',
                             description='Minimum VccpAux measurement recorded since power-up 
or the last AxiXadc reset (Zynq Only and Read Only).
',
                             hidden=False, enum=None, offset=0x2b4, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='minVCCDDRO',
                             description='Minimum VccpDdr measurement recorded since power-up 
or the last AxiXadc reset (Zynq Only and Read Only).
',
                             hidden=False, enum=None, offset=0x2b8, bitSize=12, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='flagRegister',
                             description='This register contains general status information (Read Only). Flag Register Bits are defined in Figure 3-2 and Table 3-2 on page 37 of UG480 (v1.2)',
                             hidden=False, enum=None, offset=0x2fc, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='configurationRegister',
                             description='These are AxiXadc configuration registers (see Configuration Registers (40hto 42h)) on page 39 of UG480 (v1.2)',
                             hidden=False, enum=None, offset=0x300, bitSize=96, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='sequenceReg',
                             description='These registers are used to program the channel sequencer function (see Chapter 4, AxiXadc Operating Modes) of UG480 (v1.2)',
                             hidden=False, enum=None, offset=0x320, bitSize=256, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='alarmThreshold',
                             description='These are the alarm threshold registers for the AxiXadc alarm function (see Automatic Alarms, page 59) of UG480 (v1.2)',
                             hidden=False, enum=None, offset=0x340, bitSize=512, bitOffset=0, base='uint', mode='RW'))

    return dev
