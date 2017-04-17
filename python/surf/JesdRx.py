#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device JesdRx
#-----------------------------------------------------------------------------
# File       : JesdRx.py
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for JesdRx
# Auto created from ../surf/protocols/jesd204b/yaml/JesdRx.yaml
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

def create(name='jesdRx', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x200,
                         description='JESD RX Module')

    dev.add(pyrogue.Variable(name='enable',
                             description='Enable mask. Example: 0x3F Enable ln0 to ln5.',
                             hidden=False, enum=None, offset=0x0, bitSize=6, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='sysrefDelay',
                             description='Sets the system reference delay in clock cycles. Use if you want to reduce the latency (The latency is indicated by ElBuffLatency status). ',
                             hidden=False, enum=None, offset=0x4, bitSize=5, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='subClass',
                             description='Jesd204b SubClass. 0 - For designs without sysref (no fixed latency). 1 - Fixed latency.',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='replaceEnable',
                             description='ReplaceEnable. Replace the control characters with data. (Should be 1 use 0 only for debug).',
                             hidden=False, enum={0: 'Disabled', 1: 'Enabled'}, offset=0x10, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='resetGTs',
                             description='ResetGTs. Request reset of the GT modules.',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='clearErrors',
                             description='Clear Jesd Errors and reset the status counters.',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='invertSync',
                             description='Invert Sync. Sync output has to be inverted in some systems depending on signal polarities on the PCB.',
                             hidden=False, enum={0: 'Regular', 1: 'Inverted'}, offset=0x10, bitSize=1, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='scrambleEnable',
                             description='ScrambleEnable. Enable data scrambling (More info in Jesd204b standard).',
                             hidden=False, enum={0: 'Disabled', 1: 'Enabled'}, offset=0x10, bitSize=1, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='gTReady_0',
                             description='GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='gTReady_1',
                             description='GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='gTReady_2',
                             description='GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data.',
                             hidden=False, enum=None, offset=0x48, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='gTReady_3',
                             description='GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data.',
                             hidden=False, enum=None, offset=0x4c, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='gTReady_4',
                             description='GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data.',
                             hidden=False, enum=None, offset=0x50, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='gTReady_5',
                             description='GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data.',
                             hidden=False, enum=None, offset=0x54, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='dataValid_0',
                             description='Jesd Data Valid. Goes high after the code synchronisation and ILAS sequence is complete (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='dataValid_1',
                             description='Jesd Data Valid. Goes high after the code synchronisation and ILAS sequence is complete (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='dataValid_2',
                             description='Jesd Data Valid. Goes high after the code synchronisation and ILAS sequence is complete (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x48, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='dataValid_3',
                             description='Jesd Data Valid. Goes high after the code synchronisation and ILAS sequence is complete (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x4c, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='dataValid_4',
                             description='Jesd Data Valid. Goes high after the code synchronisation and ILAS sequence is complete (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x50, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='dataValid_5',
                             description='Jesd Data Valid. Goes high after the code synchronisation and ILAS sequence is complete (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x54, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='alignErr_0',
                             description='Jesd Character Alignment Error. The control characters in the data are missaligned. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='alignErr_1',
                             description='Jesd Character Alignment Error. The control characters in the data are missaligned. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='alignErr_2',
                             description='Jesd Character Alignment Error. The control characters in the data are missaligned. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x48, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='alignErr_3',
                             description='Jesd Character Alignment Error. The control characters in the data are missaligned. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x4c, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='alignErr_4',
                             description='Jesd Character Alignment Error. The control characters in the data are missaligned. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x50, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='alignErr_5',
                             description='Jesd Character Alignment Error. The control characters in the data are missaligned. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x54, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='nSync_0',
                             description='Synchronisation request. 0 - Not synchronised. 1 - Indicades that code group synchronisation has been completed.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='nSync_1',
                             description='Synchronisation request. 0 - Not synchronised. 1 - Indicades that code group synchronisation has been completed.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='nSync_2',
                             description='Synchronisation request. 0 - Not synchronised. 1 - Indicades that code group synchronisation has been completed.',
                             hidden=False, enum=None, offset=0x48, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='nSync_3',
                             description='Synchronisation request. 0 - Not synchronised. 1 - Indicades that code group synchronisation has been completed.',
                             hidden=False, enum=None, offset=0x4c, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='nSync_4',
                             description='Synchronisation request. 0 - Not synchronised. 1 - Indicades that code group synchronisation has been completed.',
                             hidden=False, enum=None, offset=0x50, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='nSync_5',
                             description='Synchronisation request. 0 - Not synchronised. 1 - Indicades that code group synchronisation has been completed.',
                             hidden=False, enum=None, offset=0x54, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxBuffUfl_0',
                             description='Jesd sync fifo buffer undeflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxBuffUfl_1',
                             description='Jesd sync fifo buffer undeflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxBuffUfl_2',
                             description='Jesd sync fifo buffer undeflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x48, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxBuffUfl_3',
                             description='Jesd sync fifo buffer undeflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x4c, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxBuffUfl_4',
                             description='Jesd sync fifo buffer undeflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x50, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxBuffUfl_5',
                             description='Jesd sync fifo buffer undeflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x54, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxBuffOfl_0',
                             description='Jesd elastic buffer overflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=5, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxBuffOfl_1',
                             description='Jesd elastic buffer overflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=5, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxBuffOfl_2',
                             description='Jesd elastic buffer overflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x48, bitSize=1, bitOffset=5, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxBuffOfl_3',
                             description='Jesd elastic buffer overflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x4c, bitSize=1, bitOffset=5, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxBuffOfl_4',
                             description='Jesd elastic buffer overflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x50, bitSize=1, bitOffset=5, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxBuffOfl_5',
                             description='Jesd elastic buffer overflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x54, bitSize=1, bitOffset=5, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='positionErr_0',
                             description='The position of K28.5 character during code group synchronisation is wrong. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='positionErr_1',
                             description='The position of K28.5 character during code group synchronisation is wrong. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='positionErr_2',
                             description='The position of K28.5 character during code group synchronisation is wrong. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x48, bitSize=1, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='positionErr_3',
                             description='The position of K28.5 character during code group synchronisation is wrong. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x4c, bitSize=1, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='positionErr_4',
                             description='The position of K28.5 character during code group synchronisation is wrong. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x50, bitSize=1, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='positionErr_5',
                             description='The position of K28.5 character during code group synchronisation is wrong. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x54, bitSize=1, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxEnabled_0',
                             description='Rx Lane Enabled. Indicates if the lane had been enabled in configuration.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=7, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxEnabled_1',
                             description='Rx Lane Enabled. Indicates if the lane had been enabled in configuration.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=7, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxEnabled_2',
                             description='Rx Lane Enabled. Indicates if the lane had been enabled in configuration.',
                             hidden=False, enum=None, offset=0x48, bitSize=1, bitOffset=7, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxEnabled_3',
                             description='Rx Lane Enabled. Indicates if the lane had been enabled in configuration.',
                             hidden=False, enum=None, offset=0x4c, bitSize=1, bitOffset=7, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxEnabled_4',
                             description='Rx Lane Enabled. Indicates if the lane had been enabled in configuration.',
                             hidden=False, enum=None, offset=0x50, bitSize=1, bitOffset=7, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxEnabled_5',
                             description='Rx Lane Enabled. Indicates if the lane had been enabled in configuration.',
                             hidden=False, enum=None, offset=0x54, bitSize=1, bitOffset=7, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='sysRefDetected_0',
                             description='System Reference input has been Detected.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=8, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='sysRefDetected_1',
                             description='System Reference input has been Detected.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=8, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='sysRefDetected_2',
                             description='System Reference input has been Detected.',
                             hidden=False, enum=None, offset=0x48, bitSize=1, bitOffset=8, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='sysRefDetected_3',
                             description='System Reference input has been Detected.',
                             hidden=False, enum=None, offset=0x4c, bitSize=1, bitOffset=8, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='sysRefDetected_4',
                             description='System Reference input has been Detected.',
                             hidden=False, enum=None, offset=0x50, bitSize=1, bitOffset=8, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='sysRefDetected_5',
                             description='System Reference input has been Detected.',
                             hidden=False, enum=None, offset=0x54, bitSize=1, bitOffset=8, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='commaDetected_0',
                             description='The K28.5 characters detected in the serial stream. ',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=9, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='commaDetected_1',
                             description='The K28.5 characters detected in the serial stream. ',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=9, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='commaDetected_2',
                             description='The K28.5 characters detected in the serial stream. ',
                             hidden=False, enum=None, offset=0x48, bitSize=1, bitOffset=9, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='commaDetected_3',
                             description='The K28.5 characters detected in the serial stream. ',
                             hidden=False, enum=None, offset=0x4c, bitSize=1, bitOffset=9, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='commaDetected_4',
                             description='The K28.5 characters detected in the serial stream. ',
                             hidden=False, enum=None, offset=0x50, bitSize=1, bitOffset=9, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='commaDetected_5',
                             description='The K28.5 characters detected in the serial stream. ',
                             hidden=False, enum=None, offset=0x54, bitSize=1, bitOffset=9, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='disparityErr_0',
                             description='Latched High when the data byte on RXDATA arrives with the wrong disparity. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x40, bitSize=4, bitOffset=10, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='disparityErr_1',
                             description='Latched High when the data byte on RXDATA arrives with the wrong disparity. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x44, bitSize=4, bitOffset=10, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='disparityErr_2',
                             description='Latched High when the data byte on RXDATA arrives with the wrong disparity. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x48, bitSize=4, bitOffset=10, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='disparityErr_3',
                             description='Latched High when the data byte on RXDATA arrives with the wrong disparity. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x4c, bitSize=4, bitOffset=10, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='disparityErr_4',
                             description='Latched High when the data byte on RXDATA arrives with the wrong disparity. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x50, bitSize=4, bitOffset=10, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='disparityErr_5',
                             description='Latched High when the data byte on RXDATA arrives with the wrong disparity. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x54, bitSize=4, bitOffset=10, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='notInTableErr_0',
                             description='NotInTableErr. When GT decoder received s 10-bit character that cannot be mapped into a valid 8B/10B character. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x40, bitSize=4, bitOffset=14, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='notInTableErr_1',
                             description='NotInTableErr. When GT decoder received s 10-bit character that cannot be mapped into a valid 8B/10B character. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x44, bitSize=4, bitOffset=14, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='notInTableErr_2',
                             description='NotInTableErr. When GT decoder received s 10-bit character that cannot be mapped into a valid 8B/10B character. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x48, bitSize=4, bitOffset=14, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='notInTableErr_3',
                             description='NotInTableErr. When GT decoder received s 10-bit character that cannot be mapped into a valid 8B/10B character. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x4c, bitSize=4, bitOffset=14, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='notInTableErr_4',
                             description='NotInTableErr. When GT decoder received s 10-bit character that cannot be mapped into a valid 8B/10B character. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x50, bitSize=4, bitOffset=14, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='notInTableErr_5',
                             description='NotInTableErr. When GT decoder received s 10-bit character that cannot be mapped into a valid 8B/10B character. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x54, bitSize=4, bitOffset=14, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='elBuffLatency_0',
                             description='Jesd204b elastic buffer latency in c-c. Can be adjusted by Sysref delay.',
                             hidden=False, enum=None, offset=0x40, bitSize=4, bitOffset=18, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='elBuffLatency_1',
                             description='Jesd204b elastic buffer latency in c-c. Can be adjusted by Sysref delay.',
                             hidden=False, enum=None, offset=0x44, bitSize=4, bitOffset=18, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='elBuffLatency_2',
                             description='Jesd204b elastic buffer latency in c-c. Can be adjusted by Sysref delay.',
                             hidden=False, enum=None, offset=0x48, bitSize=4, bitOffset=18, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='elBuffLatency_3',
                             description='Jesd204b elastic buffer latency in c-c. Can be adjusted by Sysref delay.',
                             hidden=False, enum=None, offset=0x4c, bitSize=4, bitOffset=18, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='elBuffLatency_4',
                             description='Jesd204b elastic buffer latency in c-c. Can be adjusted by Sysref delay.',
                             hidden=False, enum=None, offset=0x50, bitSize=4, bitOffset=18, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='elBuffLatency_5',
                             description='Jesd204b elastic buffer latency in c-c. Can be adjusted by Sysref delay.',
                             hidden=False, enum=None, offset=0x54, bitSize=4, bitOffset=18, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='thresholdLow_0',
                             description='Threshold_Low. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0xc0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='thresholdLow_1',
                             description='Threshold_Low. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0xc4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='thresholdLow_2',
                             description='Threshold_Low. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0xc8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='thresholdLow_3',
                             description='Threshold_Low. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0xcc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='thresholdLow_4',
                             description='Threshold_Low. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0xd0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='thresholdLow_5',
                             description='Threshold_Low. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0xd4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='thresholdHigh_0',
                             description='Threshold_High. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0xc0, bitSize=16, bitOffset=16, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='thresholdHigh_1',
                             description='Threshold_High. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0xc4, bitSize=16, bitOffset=16, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='thresholdHigh_2',
                             description='Threshold_High. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0xc8, bitSize=16, bitOffset=16, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='thresholdHigh_3',
                             description='Threshold_High. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0xcc, bitSize=16, bitOffset=16, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='thresholdHigh_4',
                             description='Threshold_High. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0xd0, bitSize=16, bitOffset=16, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='thresholdHigh_5',
                             description='Threshold_High. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0xd4, bitSize=16, bitOffset=16, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='statusValidCnt_0',
                             description='StatusValidCnt. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.',
                             hidden=False, enum=None, offset=0x100, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='statusValidCnt_1',
                             description='StatusValidCnt. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.',
                             hidden=False, enum=None, offset=0x104, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='statusValidCnt_2',
                             description='StatusValidCnt. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.',
                             hidden=False, enum=None, offset=0x108, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='statusValidCnt_3',
                             description='StatusValidCnt. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.',
                             hidden=False, enum=None, offset=0x10c, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='statusValidCnt_4',
                             description='StatusValidCnt. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.',
                             hidden=False, enum=None, offset=0x110, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='statusValidCnt_5',
                             description='StatusValidCnt. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.',
                             hidden=False, enum=None, offset=0x114, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Command(name='clearRxErrors',
                            description='Clear the registered errors of all RX lanes',
                            hidden=False, base='None',
                            function="""\
                                     dev.clearErrors.set(1)
                                     dev.clearErrors.set(0)
                                     """))

    dev.add(pyrogue.Command(name='resetRxGTs',
                            description='Toggle the reset of all RX MGTs',
                            hidden=False, base='None',
                            function="""\
                                     dev.resetGTs.set(1)
                                     dev.resetGTs.set(0)
                                     """))

    return dev
