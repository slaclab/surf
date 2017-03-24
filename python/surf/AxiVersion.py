#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI Version Module
#-----------------------------------------------------------------------------
# File       : pyrogue/devices/axi_version.py
# Created    : 2016-09-29
# Last update: 2016-09-29
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI Version Module
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
import collections

def create(name='axiVersion', offset=0, memBase=None, hidden=False, expand=True, enabled=True):
    """Create the axiVersion device"""

    # Creation. memBase is either the register bus server (srp, rce mapped memory, etc) or the device which
    # contains this object. In most cases the parent and memBase are the same but they can be 
    # different in more complex bus structures. They will also be different for the top most node.
    # The setMemBase call can be used to update the memBase for this Device. All sub-devices and local
    # blocks will be updated.
    dev = pyrogue.Device(name=name, memBase=memBase, offset=offset, hidden=hidden, expand=expand, size=0x1000,
                         description='AXI-Lite based common version block', enabled=enabled)

    #############################################
    # Create block / variable combinations
    #############################################

    # Next create a list of variables associated with this block.
    # base has two functions. If base = 'string' then the block is treated as a string (see BuildStamp)
    # otherwise the value is retrieved or set using:
    # setUInt(self.bitOffset,self.bitSize,value) or getUInt(self.bitOffset,self.bitSize)
    # otherwise base is used by a higher level interface (GUI, etc) to determine display mode
    # Allowed modes are RO, WO, RW or SL. SL indicates registers can be written but only
    # when executing commands (not accessed during writeAll and writeStale calls
    dev.add(pyrogue.Variable(name='fpgaVersion', description='FPGA Firmware Version Number',
                             offset=0x000, bitSize=32, bitOffset=0, base='hex', mode='RO'))

    # Example of using setFunction and getFunction. setFunction and getFunctions are defined in the class
    # at the bottom. getFunction is defined as a series of python calls. When using the defined
    # function the scope is relative to the location of the function defintion. A pointer to the variable
    # and passed value are provided as args. See UserConstants below for an alernative method.
    dev.add(pyrogue.Variable(name='scratchPad', description='Register to test read and writes',
                             offset=0x004, bitSize=32, bitOffset=0, base='hex', mode='RW', 
                             setFunction=setVariableExample, getFunction=getVariableExample))
                             
    dev.add(pyrogue.Variable(name='upTimeCnt', description='Number of seconds since reset', pollInterval=1,
                             offset=0x008, bitSize=32, bitOffset=0, base='uint', units="seconds", mode='RO'))
                             
    # Bool is not used locally. Access will occur just as a uint or hex. The GUI will know how to display it.
    dev.add(pyrogue.Variable(name='fpgaReloadHalt', description='Used to halt automatic reloads via AxiVersion',
                             offset=0x100, bitSize=1, bitOffset=0, base='bool', mode='RW'))
                             
    dev.add(pyrogue.Variable(name='fpgaReloadVar', description='Optional reload the FPGA from the attached PROM',
                             offset=0x104, bitSize=1, bitOffset=0, base='bool', mode='SL', hidden=True))

    dev.add(pyrogue.Variable(name='fpgaReloadAddress', description='Reload start address',
                             offset=0x108, bitSize=32, bitOffset=0, base='hex', mode='RW'))
                             
    # Here we define MasterReset as mode 'SL' this will ensure it does not get written during
    # writeAll and writeStale commands
    dev.add(pyrogue.Variable(name='masterResetVar', description='Optional User Reset',
                             offset=0x10C, bitSize=1, bitOffset=0, base='bool', mode='SL', hidden=True))
                             
    dev.add(pyrogue.Variable(name='fdValue', description='Board ID value read from DS2411 chip',
                             offset=0x300, bitSize=64, bitOffset=0, base='hex', mode='RO'))
#    for i in range(0,64):
#
#        # Example of using setFunction and getFunction passed as strings. The scope is local to 
#        # the variable object with the passed value available as 'value' in the scope.
#        # The get function must set the 'value' variable as a result of the function.
#        dev.add(pyrogue.Variable(name='userConstant_%02i'%(i), description='Optional user input values',
#                                 offset=0x400+(i*4), bitSize=32, bitOffset=0, base='hex', mode='RW',
#                                 getFunction="""\
#                                             value = self._block.getUInt(self.bitOffset,self.bitSize)
#                                             """,
#                                 setFunction="""\
#                                             self._block.setUInt(self.bitOffset,self.bitSize,value)
#                                             """))      
    dev.add(pyrogue.Variable(name='deviceId', description='Device identification',
                             offset=0x500, bitSize=32, bitOffset=0, base='hex', mode='RO'))
                             
    dev.add(pyrogue.Variable(name='gitHash', description='GIT SHA-1 Hash',
                             offset=0x600, bitSize=160, bitOffset=0, base='hex', mode='RO'))

    dev.add(pyrogue.Variable(name='deviceDna', description='Xilinx Device DNA value burned into FPGA',
                             offset=0x700, bitSize=128, bitOffset=0, base='hex', mode='RO'))
                             
    dev.add(pyrogue.Variable(name='buildStamp', description='Firmware build string',
                             offset=0x800, bitSize=256*8, bitOffset=0, base='string', mode='RO'))

    #####################################
    # Create commands
    #####################################

    # A command has an associated function. The function can be a series of
    # python commands in a string. Function calls are executed in the command scope
    # the passed arg is available as 'arg'. Use 'dev' to get to device scope.
    dev.add(pyrogue.Command(name='masterReset',description='Master Reset',
                            function='dev.masterResetVar.post(1)'))
    
    # A command can also be a call to a local function with local scope.
    # The command object and the arg are passed
    dev.add(pyrogue.Command(name='fpgaReload',description='Reload FPGA',
                            function=cmdFpgaReload))

    dev.add(pyrogue.Command(name='counterReset',description='Counter Reset',
                            function='dev.counter.post(0)'))

    # Example printing the arg and showing a larger block. The indentation will be adjusted.
    dev.add(pyrogue.Command(name='testCommand',description='Test Command',
                            function="""\
                                     print("Someone executed the %s command" % (self.name))
                                     print("The passed arg was %s" % (arg))
                                     print("My device is %s" % (dev.name))
                                     """))

    # Alternative function for CPSW compatability
    # Pass a dictionary of numbered variable, value pairs to generate a CPSW sequence
    dev.add(pyrogue.Command(name='testCpsw',description='Test CPSW',
                            function=collections.OrderedDict({ 'masterResetVar': 1,
                                                               'usleep': 100,
                                                               'counter': 1 })))

    # Overwrite reset calls with local functions
    dev.setResetFunc(resetFunc)

    # Return the created device
    return dev


def cmdFpgaReload(dev,cmd,arg):
    """Example command function"""
    dev.fpgaReload.post(1)

def setVariableExample(dev,var,value):
    """Example set variable function"""
    var._block.setUInt(var.bitOffset,var.bitSize,value)

def getVariableExample(dev,var):
    """Example get variable function"""
    return(var._block.getUInt(var.bitOffset,var.bitSize))

def resetFunc(dev,rstType):
    """Application specific reset function"""
    if rstType == 'soft':
        dev.counter.set(0)
    elif rstType == 'hard':
        dev.masterResetVar.post(1)
    elif rstType == 'count':
        print('AxiVersion countReset')
        dev.counter.set(0)

