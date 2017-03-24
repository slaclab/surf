#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device JesdTx
#-----------------------------------------------------------------------------
# File       : JesdTx.py
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for JesdTx
# Auto created from ../surf/protocols/jesd204b/yaml/JesdTx.yaml
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the 
# top-level directory of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of 'SLAC Firmware Standard Library', including this file, 
# may be copied, modified, propagated, or distributed except according to 
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue

def create(name='jesdTx', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x200,
                         description='JESD TX Module')

    dev.add(pyrogue.Variable(name='enable',
                             description='Enable mask. Example: 0x3 Enable ln0 and ln1.',
                             hidden=False, enum=None, offset=0x0, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='subClass',
                             description='Jesd204b SubClass. 0 - For designs without sysref (no fixed latency). 1 - Fixed latency.',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='replaceEnable',
                             description='ReplaceEnable. Replace the control characters with data. (Should be 1 use 0 only for debug).',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='resetGTs',
                             description='ResetGTs. Request reset of the GT modules.',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='clearErrors',
                             description='Clear Jesd Errors and reset the status counters.',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='invertSync',
                             description='InvertSync. Invert sync input (the AMC card schematics should be checkes if inverted). ',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='testSigEnable',
                             description='Invert Sync. Sync output has to be inverted in some systems depending on signal polarities on the PCB.',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='scrambleEnable',
                             description='ScrambleEnable. Enable data scrambling (More info in Jesd204b standard). ',
                             hidden=False, enum={0: 'Disabled', 1: 'Enabled'}, offset=0x10, bitSize=1, bitOffset=6, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rampStep',
                             description='Ramp increment step and a period of the wave in c-c',
                             hidden=False, enum=None, offset=0x14, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='squarePeriod',
                             description='Ramp increment step and a period of the wave in c-c',
                             hidden=False, enum=None, offset=0x14, bitSize=16, bitOffset=16, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lowAmplitudeVal',
                             description='Low value of the square waveform amplitude',
                             hidden=False, enum=None, offset=0x18, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='highAmplitudeVal',
                             description='High value of the square waveform amplitude',
                             hidden=False, enum=None, offset=0x1c, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='gTReady_0',
                             description='GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='gTReady_1',
                             description='GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='dataValid_0',
                             description='Jesd Data Valid. Goes high after the code synchronisation and ILAS sequence is complete (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='dataValid_1',
                             description='Jesd Data Valid. Goes high after the code synchronisation and ILAS sequence is complete (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ilasActive_0',
                             description='ILA sequence Active. Only 1 for 4 multiframe clock cycles then it drops (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ilasActive_1',
                             description='ILA sequence Active. Only 1 for 4 multiframe clock cycles then it drops (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='nSync_0',
                             description='nSync. 0 - Not synchronised. 1 - Indicades that code group synchronisation has been completed.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='nSync_1',
                             description='nSync. 0 - Not synchronised. 1 - Indicades that code group synchronisation has been completed.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='txEnabled_0',
                             description='Tx Lane Enabled. Indicates if the lane had been enabled in configuration.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='txEnabled_1',
                             description='Tx Lane Enabled. Indicates if the lane had been enabled in configuration.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='sysRefDetected_0',
                             description='System Reference input has been Detected.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=5, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='sysRefDetected_1',
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

    dev.add(pyrogue.Variable(name='statusValidCnt_0',
                             description='StatusValidCnt[31:0]. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.',
                             hidden=False, enum=None, offset=0x100, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='statusValidCnt_1',
                             description='StatusValidCnt[31:0]. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.',
                             hidden=False, enum=None, offset=0x104, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Command(name='clearTxStatus',
                            description='Clear the status valid counter of TX lanes.',
                            hidden=False, base='None',
                            function="""\
                                     dev.clearErrors.set(1)
                                     dev.clearErrors.set(0)
                                     """))

    return dev
