#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue CameraLink module
#-----------------------------------------------------------------------------
# File       : _UartPiranha4.py
# Created    : 2017-11-21
#-----------------------------------------------------------------------------
# Description:
# PyRogue CameraLink module
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
import rogue.interfaces.stream

import surf.protocols.clink as clink
               
class UartPiranha4(pr.Device):
    def __init__(   self,       
            name        = 'UartPiranha4',
            description = 'Uart Opal000 channel access',
            serial      = None,
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        # Attach the serial devices
        self._rx = clink.ClinkSerialRx()
        pr.streamConnect(serial,self._rx)

        self._tx = clink.ClinkSerialTx()
        pr.streamConnect(self._tx,serial)
        
        @self.command(value='', name='SendString', description='Send a command string')
        def sendString(arg):
            if self._tx is not None:
                self._tx.sendString(arg)

        ##############################
        # Variables
        ##############################        
        
        self.add(pr.LocalVariable(    
            name         = 'CCF',
            description  = 'Calibrate user FPN dark flat field coefficients',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'ccf {value}') if value!='' else ''
        ))
        
        self.add(pr.LocalVariable(    
            name         = 'CLS',
            description  = 'Camera Link clock frequency',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'cls {value}') if value!='' else ''
        )) 

        self.add(pr.LocalVariable(    
            name         = 'CLM',
            description  = 'Camera Link Mode',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'clm {value}') if value!='' else ''
        )) 

        self.add(pr.LocalVariable(    
            name         = 'CPA[0]',
            description  = 'Calibrate user PRNU flat field coefficients: Algorithm Argument',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'cpa {self.CPA[0].get()} {self.CPA[1].get()} {self.CPA[2].get()}') if (self.CPA[0].get()!='' and self.CPA[1].get()!='' and self.CPA[2].get()!='') else ''
        ))          
        
        self.add(pr.LocalVariable(    
            name         = 'CPA[1]',
            description  = 'Calibrate user PRNU flat field coefficients: \# of lines to average Argument',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'cpa {self.CPA[0].get()} {self.CPA[1].get()} {self.CPA[2].get()}') if (self.CPA[0].get()!='' and self.CPA[1].get()!='' and self.CPA[2].get()!='') else ''
        )) 

        self.add(pr.LocalVariable(    
            name         = 'CPA[2]',
            description  = 'Calibrate user PRNU flat field coefficients: Target Argument',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'cpa {self.CPA[0].get()} {self.CPA[1].get()} {self.CPA[2].get()}') if (self.CPA[0].get()!='' and self.CPA[1].get()!='' and self.CPA[2].get()!='') else ''
        ))             

        self.add(pr.LocalVariable(    
            name         = 'DST',
            description  = 'Use this command to switch between Area and Single Line modes.',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'dst {value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(    
            name         = 'FFM',
            description  = 'Set flat field mode',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'ffm {value}') if value!='' else ''
        )) 

        self.add(pr.LocalVariable(    
            name         = 'FRS',
            description  = 'Set scan direction controlled reverse set',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'frs {value}') if value!='' else ''
        ))

        self.add(pr.BaseCommand(    
            name         = 'GCP',
            description  = 'Display current value of camera configuration parameters',
            function     = lambda cmd: self._tx.sendString('gcp')
        ))            

        self.add(pr.LocalVariable(    
            name         = 'GET',
            description  = 'The /"get/" command displays the current value(s) of the feature specified in the string parameter. Note that the parameter is preceded by a single quote \"\". Using this command will be easier for control software than parsing the output from the \"gcp\" command.',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'get {value}') if value!='' else ''
        ))            
        
        self.add(pr.BaseCommand(    
            name         = 'H',
            description  = 'Display list of three letter commands',
            function     = lambda cmd: self._tx.sendString('h')
        ))             
        
        self.add(pr.LocalVariable(    
            name         = 'LPC',
            description  = 'Load user set',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'lpc {value}') if value!='' else ''
        ))            
        
        self.add(pr.BaseCommand(    
            name         = 'RC',
            description  = 'Resets the camera to the saved user default settings. These settings are saved using the usd command.',
            function     = lambda cmd: self._tx.sendString('rc')
        ))            
        
        self.add(pr.LocalVariable(    
            name         = 'ROI[0]',
            description  = 'Flat field region of interest: First pixel Argument',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'roi {self.ROI[0].get()} {self.ROI[1].get()}') if (self.ROI[0].get()!='' and self.ROI[1].get()!='') else ''
        ))          
        
        self.add(pr.LocalVariable(    
            name         = 'ROI[1]',
            description  = 'Flat field region of interest: Last pixel Argument',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'roi {self.ROI[0].get()} {self.ROI[1].get()}') if (self.ROI[0].get()!='' and self.ROI[1].get()!='') else ''
        )) 
        
        self.add(pr.BaseCommand(    
            name         = 'RPC',
            description  = 'Reset all user FPN values to zero and all user PRNU coefficients to one',
            function     = lambda cmd: self._tx.sendString('rpc')
        ))               
        
        self.add(pr.LocalVariable(    
            name         = 'SAC',
            description  = 'Set AOI Counter',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'sac {value}') if value!='' else ''
        ))             
        
        self.add(pr.LocalVariable(    
            name         = 'SAD[0]',
            description  = 'Define an AOI: Selector Argument',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'sad {self.SAD[0].get()} {self.SAD[1].get()} {self.SAD[2].get()}') if (self.SAD[0].get()!='' and self.SAD[1].get()!='' and self.SAD[2].get()!='') else ''
        ))          
        
        self.add(pr.LocalVariable(    
            name         = 'SAD[1]',
            description  = 'Define an AOI: Offset Argument',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'sad {self.SAD[0].get()} {self.SAD[1].get()} {self.SAD[2].get()}') if (self.SAD[0].get()!='' and self.SAD[1].get()!='' and self.SAD[2].get()!='') else ''
        )) 

        self.add(pr.LocalVariable(    
            name         = 'SAD[2]',
            description  = 'Define an AOI: Width Argument',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'sad {self.SAD[0].get()} {self.SAD[1].get()} {self.SAD[2].get()}') if (self.SAD[0].get()!='' and self.SAD[1].get()!='' and self.SAD[2].get()!='') else ''
        ))              
        
        self.add(pr.LocalVariable(    
            name         = 'SAM',
            description  = 'Set AOI mode',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'sam {value}') if value!='' else ''
        )) 

        self.add(pr.LocalVariable(    
            name         = 'SBH',
            description  = 'Set horizontal binning',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'sbh {value}') if value!='' else ''
        ))  

        self.add(pr.LocalVariable(    
            name         = 'SBR',
            description  = 'Set baud rate',
            mode         = 'RW', 
            value        = '',
            units        = 'bps',
            localSet     = lambda value: self._tx.sendString(f'sbr {value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(    
            name         = 'SBV',
            description  = 'Set vertical binning',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'sbv {value}') if value!='' else ''
        )) 

        self.add(pr.LocalVariable(    
            name         = 'SCD',
            description  = 'Set sensor scan direction',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'scd {value}') if value!='' else ''
        ))  

        self.add(pr.LocalVariable(    
            name         = 'SEM',
            description  = 'Set exposure time mode',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'sem {value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(    
            name         = 'SET',
            description  = 'Set internal exposure time in nanoseconds (25 ns resolution)',
            mode         = 'RW', 
            value        = '',
            units        = '25ns',
            localSet     = lambda value: self._tx.sendString(f'set {value}') if value!='' else ''
        ))            

        self.add(pr.LocalVariable(    
            name         = 'SMM',
            description  = 'Set mirroring mode',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'smm {value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(    
            name         = 'SPF',
            description  = 'Set pixel format',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'spf {value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(    
            name         = 'SSB',
            description  = 'Set contrast offset - single value added to all pixels after PRNU/flat field coefficients (before gain).',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'ssb {value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(    
            name         = 'SSF',
            description  = 'Set internal line rate in Hz',
            mode         = 'RW', 
            value        = '',
            units        = 'Hz',
            localSet     = lambda value: self._tx.sendString(f'ssf {value}') if value!='' else ''
        ))            
        
        self.add(pr.LocalVariable(    
            name         = 'SSG',
            description  = 'Set gain as a single value multiplied by all pixels.',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'ssg {value}') if value!='' else ''
        ))   

        self.add(pr.LocalVariable(    
            name         = 'STG',
            description  = 'Set TDI Stages',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'stg {value}') if value!='' else ''
        ))  

        self.add(pr.LocalVariable(    
            name         = 'STM',
            description  = 'Set trigger mode',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'stm {value}') if value!='' else ''
        )) 

        self.add(pr.LocalVariable(    
            name         = 'SVM',
            description  = 'Select test pattern',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'svm {value}') if value!='' else ''
        ))  

        self.add(pr.LocalVariable(    
            name         = 'USD',
            description  = 'Select user set to load when camera is reset',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'usd {value}') if value!='' else ''
        )) 

        self.add(pr.LocalVariable(    
            name         = 'USL',
            description  = 'Load user set',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'usl {value}') if value!='' else ''
        )) 

        self.add(pr.LocalVariable(    
            name         = 'USS',
            description  = 'Save user set',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'uss {value}') if value!='' else ''
        ))  

        self.add(pr.BaseCommand(    
            name         = 'VT',
            description  = 'Display internal temperature in degrees Celsius',
            function     = lambda cmd: self._tx.sendString('vt'),
        ))

        self.add(pr.BaseCommand(    
            name         = 'VV',
            description  = 'Display supply voltage',
            function     = lambda cmd: self._tx.sendString('vv'),
        ))  

        self.add(pr.BaseCommand(    
            name         = 'SendEscape',
            description  = 'Send the Escape Char',
            function     = lambda cmd: self._tx.sendEscape()
        ))              
