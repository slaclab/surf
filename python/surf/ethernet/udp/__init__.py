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
from surf.ethernet.udp._UdpEngine       import *

import ipaddress

def getPortValue(var, read):
    x = var.dependencies[0].get(read=read)
    newValue = int.from_bytes(x.to_bytes(2, byteorder='big'), byteorder='little', signed=False)
    return ( newValue )

def setPortValue(var, value, write):
    newValue = int.from_bytes(value.to_bytes(2, byteorder='little'), byteorder='big', signed=False)
    var.dependencies[0].set(newValue, write=write)

def getIpValue(var, read):
    x = var.dependencies[0].get(read=read)
    return f'{(x >> 0) & 0xFF}.{(x >> 8) & 0xFF}.{(x >> 16) & 0xFF}.{(x >> 24) & 0xFF}'

def setIpValue(var, value, write):
    x = int(ipaddress.IPv4Address(value))
    newValue = int.from_bytes(x.to_bytes(4, byteorder='little'), byteorder='big', signed=False)
    var.dependencies[0].set(newValue, write=write)

def getMacValue(var, read):
    x = var.dependencies[0].get(read=read)
    return f'{(x >> 0) & 0xFF:02X}:{(x >> 8) & 0xFF:02X}:{(x >> 16) & 0xFF:02X}:{(x >> 24) & 0xFF:02X}:{(x >> 32) & 0xFF:02X}:{(x >> 40) & 0xFF:02X}'

def setMacValue(var, value, write):
    x=value.replace(":"," ").split()
    if( len(x) == 6):
        x = [int(i,16) for i in x]
        newValue = f'0x{x[5]:02x}{x[4]:02x}{x[3]:02x}{x[2]:02x}{x[1]:02x}{x[0]:02x}'
        var.dependencies[0].set(int(newValue,16), write=write)

