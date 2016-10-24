#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device JesdRx
#-----------------------------------------------------------------------------
# File       : JesdRx.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-10-24
# Last update: 2016-10-24
#-----------------------------------------------------------------------------
# Description:
# Device creator for JesdRx
# Auto created from ../surf/protocols/jesd204b/yaml/JesdRx.yaml
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
                         description='JESD RX Module')

    dev.add(pyrogue.Variable(name='Enable',
                             description='Enable mask. Example: 0x3F Enable ln0 to ln5.',
                             hidden=False, enum=None, offset=0x0, bitSize=6, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SysrefDelay',
                             description='Sets the system reference delay in clock cycles. Use if you want to reduce the latency (The latency is indicated by ElBuffLatency status). ',
                             hidden=False, enum=None, offset=0x4, bitSize=5, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SubClass',
                             description='Jesd204b SubClass. 0 - For designs without sysref (no fixed latency). 1 - Fixed latency.',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ReplaceEnable',
                             description='ReplaceEnable. Replace the control characters with data. (Should be 1 use 0 only for debug).',
                             hidden=False, enum={0: 'Disabled', 1: 'Enabled'}, offset=0x10, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ResetGTs',
                             description='ResetGTs. Request reset of the GT modules.',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ClearErrors',
                             description='Clear Jesd Errors and reset the status counters.',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='InvertSync',
                             description='Invert Sync. Sync output has to be inverted in some systems depending on signal polarities on the PCB.',
                             hidden=False, enum={0: 'Regular', 1: 'Inverted'}, offset=0x10, bitSize=1, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ScrambleEnable',
                             description='ScrambleEnable. Enable data scrambling (More info in Jesd204b standard).',
                             hidden=False, enum={0: 'Disabled', 1: 'Enabled'}, offset=0x10, bitSize=1, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='GTReady_0',
                             description='GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='GTReady_1',
                             description='GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='GTReady_2',
                             description='GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data.',
                             hidden=False, enum=None, offset=0x48, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='GTReady_3',
                             description='GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data.',
                             hidden=False, enum=None, offset=0x4c, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='GTReady_4',
                             description='GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data.',
                             hidden=False, enum=None, offset=0x50, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='GTReady_5',
                             description='GT Ready. Jesd clock ok PLLs are locked and GT is ready to receive data.',
                             hidden=False, enum=None, offset=0x54, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='DataValid_0',
                             description='Jesd Data Valid. Goes high after the code synchronisation and ILAS sequence is complete (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='DataValid_1',
                             description='Jesd Data Valid. Goes high after the code synchronisation and ILAS sequence is complete (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='DataValid_2',
                             description='Jesd Data Valid. Goes high after the code synchronisation and ILAS sequence is complete (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x48, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='DataValid_3',
                             description='Jesd Data Valid. Goes high after the code synchronisation and ILAS sequence is complete (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x4c, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='DataValid_4',
                             description='Jesd Data Valid. Goes high after the code synchronisation and ILAS sequence is complete (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x50, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='DataValid_5',
                             description='Jesd Data Valid. Goes high after the code synchronisation and ILAS sequence is complete (More info in Jesd204b standard).',
                             hidden=False, enum=None, offset=0x54, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='AlignErr_0',
                             description='Jesd Character Alignment Error. The control characters in the data are missaligned. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='AlignErr_1',
                             description='Jesd Character Alignment Error. The control characters in the data are missaligned. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='AlignErr_2',
                             description='Jesd Character Alignment Error. The control characters in the data are missaligned. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x48, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='AlignErr_3',
                             description='Jesd Character Alignment Error. The control characters in the data are missaligned. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x4c, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='AlignErr_4',
                             description='Jesd Character Alignment Error. The control characters in the data are missaligned. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x50, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='AlignErr_5',
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

    dev.add(pyrogue.Variable(name='RxBuffUfl_0',
                             description='Jesd sync fifo buffer undeflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RxBuffUfl_1',
                             description='Jesd sync fifo buffer undeflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RxBuffUfl_2',
                             description='Jesd sync fifo buffer undeflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x48, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RxBuffUfl_3',
                             description='Jesd sync fifo buffer undeflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x4c, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RxBuffUfl_4',
                             description='Jesd sync fifo buffer undeflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x50, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RxBuffUfl_5',
                             description='Jesd sync fifo buffer undeflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x54, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RxBuffOfl_0',
                             description='Jesd elastic buffer overflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=5, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RxBuffOfl_1',
                             description='Jesd elastic buffer overflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=5, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RxBuffOfl_2',
                             description='Jesd elastic buffer overflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x48, bitSize=1, bitOffset=5, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RxBuffOfl_3',
                             description='Jesd elastic buffer overflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x4c, bitSize=1, bitOffset=5, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RxBuffOfl_4',
                             description='Jesd elastic buffer overflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x50, bitSize=1, bitOffset=5, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RxBuffOfl_5',
                             description='Jesd elastic buffer overflow. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x54, bitSize=1, bitOffset=5, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='PositionErr_0',
                             description='The position of K28.5 character during code group synchronisation is wrong. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='PositionErr_1',
                             description='The position of K28.5 character during code group synchronisation is wrong. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='PositionErr_2',
                             description='The position of K28.5 character during code group synchronisation is wrong. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x48, bitSize=1, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='PositionErr_3',
                             description='The position of K28.5 character during code group synchronisation is wrong. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x4c, bitSize=1, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='PositionErr_4',
                             description='The position of K28.5 character during code group synchronisation is wrong. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x50, bitSize=1, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='PositionErr_5',
                             description='The position of K28.5 character during code group synchronisation is wrong. This error will trigger JESD re-synchronisation.',
                             hidden=False, enum=None, offset=0x54, bitSize=1, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RxEnabled_0',
                             description='Rx Lane Enabled. Indicates if the lane had been enabled in configuration.',
                             hidden=False, enum=None, offset=0x40, bitSize=1, bitOffset=7, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RxEnabled_1',
                             description='Rx Lane Enabled. Indicates if the lane had been enabled in configuration.',
                             hidden=False, enum=None, offset=0x44, bitSize=1, bitOffset=7, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RxEnabled_2',
                             description='Rx Lane Enabled. Indicates if the lane had been enabled in configuration.',
                             hidden=False, enum=None, offset=0x48, bitSize=1, bitOffset=7, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RxEnabled_3',
                             description='Rx Lane Enabled. Indicates if the lane had been enabled in configuration.',
                             hidden=False, enum=None, offset=0x4c, bitSize=1, bitOffset=7, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RxEnabled_4',
                             description='Rx Lane Enabled. Indicates if the lane had been enabled in configuration.',
                             hidden=False, enum=None, offset=0x50, bitSize=1, bitOffset=7, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RxEnabled_5',
                             description='Rx Lane Enabled. Indicates if the lane had been enabled in configuration.',
                             hidden=False, enum=None, offset=0x54, bitSize=1, bitOffset=7, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='SysRefDetected_0',
                             description='System Reference input has been Detected.',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='SysRefDetected_1',
                             description='System Reference input has been Detected.',
                             hidden=False, enum=None, offset=0x14, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='SysRefDetected_2',
                             description='System Reference input has been Detected.',
                             hidden=False, enum=None, offset=0x18, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='SysRefDetected_3',
                             description='System Reference input has been Detected.',
                             hidden=False, enum=None, offset=0x1c, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='SysRefDetected_4',
                             description='System Reference input has been Detected.',
                             hidden=False, enum=None, offset=0x20, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='SysRefDetected_5',
                             description='System Reference input has been Detected.',
                             hidden=False, enum=None, offset=0x24, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='CommaDetected_0',
                             description='The K28.5 characters detected in the serial stream. ',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='CommaDetected_1',
                             description='The K28.5 characters detected in the serial stream. ',
                             hidden=False, enum=None, offset=0x14, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='CommaDetected_2',
                             description='The K28.5 characters detected in the serial stream. ',
                             hidden=False, enum=None, offset=0x18, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='CommaDetected_3',
                             description='The K28.5 characters detected in the serial stream. ',
                             hidden=False, enum=None, offset=0x1c, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='CommaDetected_4',
                             description='The K28.5 characters detected in the serial stream. ',
                             hidden=False, enum=None, offset=0x20, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='CommaDetected_5',
                             description='The K28.5 characters detected in the serial stream. ',
                             hidden=False, enum=None, offset=0x24, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='DisparityErr_0',
                             description='Latched High when the data byte on RXDATA arrives with the wrong disparity. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x10, bitSize=4, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='DisparityErr_1',
                             description='Latched High when the data byte on RXDATA arrives with the wrong disparity. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x14, bitSize=4, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='DisparityErr_2',
                             description='Latched High when the data byte on RXDATA arrives with the wrong disparity. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x18, bitSize=4, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='DisparityErr_3',
                             description='Latched High when the data byte on RXDATA arrives with the wrong disparity. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x1c, bitSize=4, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='DisparityErr_4',
                             description='Latched High when the data byte on RXDATA arrives with the wrong disparity. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x20, bitSize=4, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='DisparityErr_5',
                             description='Latched High when the data byte on RXDATA arrives with the wrong disparity. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x24, bitSize=4, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='NotInTableErr_0',
                             description='NotInTableErr. When GT decoder received s 10-bit character that cannot be mapped into a valid 8B/10B character. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x10, bitSize=4, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='NotInTableErr_1',
                             description='NotInTableErr. When GT decoder received s 10-bit character that cannot be mapped into a valid 8B/10B character. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x14, bitSize=4, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='NotInTableErr_2',
                             description='NotInTableErr. When GT decoder received s 10-bit character that cannot be mapped into a valid 8B/10B character. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x18, bitSize=4, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='NotInTableErr_3',
                             description='NotInTableErr. When GT decoder received s 10-bit character that cannot be mapped into a valid 8B/10B character. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x1c, bitSize=4, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='NotInTableErr_4',
                             description='NotInTableErr. When GT decoder received s 10-bit character that cannot be mapped into a valid 8B/10B character. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x20, bitSize=4, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='NotInTableErr_5',
                             description='NotInTableErr. When GT decoder received s 10-bit character that cannot be mapped into a valid 8B/10B character. Indicates bad serial connection (Check HW).',
                             hidden=False, enum=None, offset=0x24, bitSize=4, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ElBuffLatency_0',
                             description='Jesd204b elastic buffer latency in c-c. Can be adjusted by Sysref delay.',
                             hidden=False, enum=None, offset=0x10, bitSize=4, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ElBuffLatency_1',
                             description='Jesd204b elastic buffer latency in c-c. Can be adjusted by Sysref delay.',
                             hidden=False, enum=None, offset=0x14, bitSize=4, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ElBuffLatency_2',
                             description='Jesd204b elastic buffer latency in c-c. Can be adjusted by Sysref delay.',
                             hidden=False, enum=None, offset=0x18, bitSize=4, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ElBuffLatency_3',
                             description='Jesd204b elastic buffer latency in c-c. Can be adjusted by Sysref delay.',
                             hidden=False, enum=None, offset=0x1c, bitSize=4, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ElBuffLatency_4',
                             description='Jesd204b elastic buffer latency in c-c. Can be adjusted by Sysref delay.',
                             hidden=False, enum=None, offset=0x20, bitSize=4, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ElBuffLatency_5',
                             description='Jesd204b elastic buffer latency in c-c. Can be adjusted by Sysref delay.',
                             hidden=False, enum=None, offset=0x24, bitSize=4, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ThresholdLow_0',
                             description='Threshold_Low. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0xc0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ThresholdLow_1',
                             description='Threshold_Low. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0xc4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ThresholdLow_2',
                             description='Threshold_Low. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0xc8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ThresholdLow_3',
                             description='Threshold_Low. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0xcc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ThresholdLow_4',
                             description='Threshold_Low. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0xd0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ThresholdLow_5',
                             description='Threshold_Low. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0xd4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ThresholdHigh_0',
                             description='Threshold_High. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0x30, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ThresholdHigh_1',
                             description='Threshold_High. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0x34, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ThresholdHigh_2',
                             description='Threshold_High. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0x38, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ThresholdHigh_3',
                             description='Threshold_High. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0x3c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ThresholdHigh_4',
                             description='Threshold_High. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0x40, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ThresholdHigh_5',
                             description='Threshold_High. Debug funtionality. Threshold for generating a digital signal from the ADC data.',
                             hidden=False, enum=None, offset=0x44, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='StatusValidCnt_0',
                             description='StatusValidCnt. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.',
                             hidden=False, enum=None, offset=0x100, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='StatusValidCnt_1',
                             description='StatusValidCnt. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.',
                             hidden=False, enum=None, offset=0x104, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='StatusValidCnt_2',
                             description='StatusValidCnt. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.',
                             hidden=False, enum=None, offset=0x108, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='StatusValidCnt_3',
                             description='StatusValidCnt. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.',
                             hidden=False, enum=None, offset=0x10c, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='StatusValidCnt_4',
                             description='StatusValidCnt. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.',
                             hidden=False, enum=None, offset=0x110, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='StatusValidCnt_5',
                             description='StatusValidCnt. Shows stability of JESD lanes. Counts number of JESD re-syncronisations.',
                             hidden=False, enum=None, offset=0x114, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Command(name='ClearRxErrors',
                            description='Clear the registered errors of all RX lanes',
                            hidden=False, base=None,
                            function="""\
                                     dev.ClearErrors.set(1)
                                     dev.ClearErrors.set(0)
                                     """

    dev.add(pyrogue.Command(name='ResetRxGTs',
                            description='Toggle the reset of all RX MGTs',
                            hidden=False, base=None,
                            function="""\
                                     dev.ResetGTs.set(1)
                                     dev.ResetGTs.set(0)
                                     """

