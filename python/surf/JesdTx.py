#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device JesdTx
#-----------------------------------------------------------------------------
# File       : JesdTx.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-10-24
# Last update: 2016-10-24
#-----------------------------------------------------------------------------
# Description:
# Device creator for JesdTx
# Auto created from ../surf/protocols/jesd204b/yaml/JesdTx.yaml
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

def create(name, offset, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x200,
                         description='JESD TX Module')

    dev.add(pyrogue.Variable(name='Enable',
                             description='Enable mask. Example: 0x3 Enable ln0 and ln1.',
                             hidden=False, enum=None, offset=0x0, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SubClass',
                             description='Jesd204b SubClass. 0 - For designs without sysref (no fixed latency). 1 - Fixed latency.',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ReplaceEnable',
                             description='ReplaceEnable. Replace the control characters with data. (Should be 1 use 0 only for debug).',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ResetGTs',
                             description='ResetGTs. Request reset of the GT modules.',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ClearErrors',
                             description='Clear Jesd Errors and reset the status counters.',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='InvertSync',
                             description='InvertSync. Invert sync input (the AMC card schematics should be checkes if inverted). ',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TestSigEnable',
                             description='Invert Sync. Sync output has to be inverted in some systems depending on signal polarities on the PCB.',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ScrambleEnable',
                             description='ScrambleEnable. Enable data scrambling (More info in Jesd204b standard). ',
                             hidden=False, enum={0: 'Disabled', 1: 'Enabled'}, offset=0x10, bitSize=1, bitOffset=6, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RampStep',
                             description='Ramp increment step and a period of the wave in c-c',
                             hidden=False, enum=None, offset=0x14, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SquarePeriod',
                             description='Ramp increment step and a period of the wave in c-c',
                             hidden=False, enum=None, offset=0x5, bitSize=16, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='LowAmplitudeVal',
                             description='Low value of the square waveform amplitude',
                             hidden=False, enum=None, offset=0x18, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='HighAmplitudeVal',
                             description='High value of the square waveform amplitude',
                             hidden=False, enum=None, offset=0x1c, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='GTReady_0',
                             description='GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='GTReady_1',
                             description='GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='DataValid_0',
                             description='Jesd Data Valid. Goes high after the code synchronisation and ILAS sequence is complete (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='DataValid_1',
                             description='Jesd Data Valid. Goes high after the code synchronisation and ILAS sequence is complete (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='IlasActive_0',
                             description='ILA sequence Active. Only 1 for 4 multiframe clock cycles then it drops (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='IlasActive_1',
                             description='ILA sequence Active. Only 1 for 4 multiframe clock cycles then it drops (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='nSync_0',
                             description='nSync. 0 - Not synchronised. 1 - Indicades that code group synchronisation has been completed.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='nSync_1',
                             description='nSync. 0 - Not synchronised. 1 - Indicades that code group synchronisation has been completed.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='TxEnabled_0',
                             description='Tx Lane Enabled. Indicates if the lane had been enabled in configuration.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='TxEnabled_1',
                             description='Tx Lane Enabled. Indicates if the lane had been enabled in configuration.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='SysRefDetected_0',
                             description='System Reference input has been Detected.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=5, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='SysRefDetected_1',
                             description='System Reference input has been Detected.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=5, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='dataOutMux_0',
                             description='data_out_mux: Select between: b000 - Output zero, b001 - Parallel data from inside FPGA, b010 - Data from AXI stream (not used), b011 - Test data',
                             hidden=False, enum={0: 'OutputZero', 1: 'UserData', 2: 'AxiStream', 3: 'TestData'}, offset=0x80, bitSize=4, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dataOutMux_1',
                             description='data_out_mux: Select between: b000 - Output zero, b001 - Parallel data from inside FPGA, b010 - Data from AXI stream (not used), b011 - Test data',
                             hidden=False, enum={0: 'OutputZero', 1: 'UserData', 2: 'AxiStream', 3: 'TestData'}, offset=0x84, bitSize=4, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='testOutMux_0',
                             description='test_out_mux[1:0]: Select between: b000 - Saw signal increment, b001 - Saw signal decrement, b010 - Square wave,  b011 - Output zero',
                             hidden=False, enum={0: 'SawIncrement', 1: 'SawDecrement', 2: 'SquareWave', 3: 'OutputZero'}, offset=0x80, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='testOutMux_1',
                             description='test_out_mux[1:0]: Select between: b000 - Saw signal increment, b001 - Saw signal decrement, b010 - Square wave,  b011 - Output zero',
                             hidden=False, enum={0: 'SawIncrement', 1: 'SawDecrement', 2: 'SquareWave', 3: 'OutputZero'}, offset=0x84, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='StatusValidCnt_0',
                             description='StatusValidCnt[31:0]. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.',
                             hidden=False, enum=None, offset=0x100, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='StatusValidCnt_1',
                             description='StatusValidCnt[31:0]. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.',
                             hidden=False, enum=None, offset=0x104, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Command(name='ClearTxStatus',
                            description='Clear the status valid counter of TX lanes.',
                            hidden=False, base=None,
                            function="""\
                                     dev.ClearErrors.set(1)
                                     dev.ClearErrors.set(0)
                                     """

