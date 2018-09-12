#!/usr/bin/env python
##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

from surf.ethernet.udp._UdpEngineClient import *
from surf.ethernet.udp._UdpEngineServer import *

import ipaddress

def getPortValue(var):
    x = var.dependencies[0].value()
    newValue = int.from_bytes(x.to_bytes(2, byteorder='big'), byteorder='little', signed=False)
    return ( newValue ) 

def setPortValue(var, value, write):
    newValue = int.from_bytes(value.to_bytes(2, byteorder='little'), byteorder='big', signed=False)
    var.dependencies[0].set(newValue,write)

def getIpValue(var):
    x = var.dependencies[0].value()
    return ( '%d.%d.%d.%d' % ( ((x>>0)&0xFF),((x>>8)&0xFF),((x>>16)&0xFF),((x>>24)&0xFF) ) )
    
def setIpValue(var, value, write):
    x = int(ipaddress.IPv4Address(value))
    newValue = int.from_bytes(x.to_bytes(4, byteorder='little'), byteorder='big', signed=False)
    var.dependencies[0].set(newValue,write)

def getMacValue(var):
    x = var.dependencies[0].value()
    return ( '%02X:%02X:%02X:%02X:%02X:%02X' % ( ((x>>0)&0xFF),((x>>8)&0xFF),((x>>16)&0xFF),((x>>24)&0xFF),((x>>32)&0xFF),((x>>40)&0xFF) ) )

def setMacValue(var, value, write):
    x=value.replace(":"," ").split()
    if( len(x) == 6):
        x = [int(i,16) for i in x]
        newValue = ( '0x%02x%02x%02x%02x%02x%02x' % (x[5],x[4],x[3],x[2],x[1],x[0]) )
        var.dependencies[0].set(int(newValue,16),write)
        