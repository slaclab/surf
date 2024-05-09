##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
from surf.devices.transceivers._Sfp  import *
from surf.devices.transceivers._Qsfp import *

import math

# Can't use SparseString + bulk memory read if there is a AXI-Lite Proxy
# So recoded using 4 byte transactions + this get function
def parseStrArrayByte(dev, var, read):
    with dev.root.updateGroup():
        retVar = ''
        for x in range(len(var.dependencies)):
            retVar += var.dependencies[x].get(read=read)
    return retVar

# Used to decode the "dateCode" variable
def getDate(dev, var, read):
    with dev.root.updateGroup():
        year  = '20' + var.dependencies[0].get(read=read) + var.dependencies[1].get(read=read)
        month = var.dependencies[2].get(read=read) + var.dependencies[3].get(read=read)
        day   = var.dependencies[4].get(read=read) + var.dependencies[5].get(read=read)
        # Check if not empty or blank string
        if month.strip() and day.strip():
            return f'{month}/{day}/{year}'

def getTemp(dev, var, read):
    with dev.root.updateGroup():    
        msb = var.dependencies[0].get(read=read)
        lsb = var.dependencies[1].get(read=read)
        raw = (msb << 8) | lsb
        # Return value in units of degC
        return float(raw)/256.0

def getVolt(dev, var, read):
    with dev.root.updateGroup():    
        msb = var.dependencies[0].get(read=read)
        lsb = var.dependencies[1].get(read=read)
        raw = (msb << 8) | lsb
        # Return value in units of Volts
        return float(raw)*100.0E-6

def getTxBias(dev, var, read):
    with dev.root.updateGroup():    
        msb = var.dependencies[0].get(read=read)
        lsb = var.dependencies[1].get(read=read)
        raw = (msb << 8) | lsb
        # Return value in units of mA
        return float(raw)*0.002

def getOpticalPwr(dev, var, read):
    with dev.root.updateGroup():    
        msb = var.dependencies[0].get(read=read)
        lsb = var.dependencies[1].get(read=read)
        raw = (msb << 8) | lsb
        if raw == 0:
            pwr = 0.0001 # Prevent log10(zero) case
        else:
            pwr = float(raw)*0.0001 # units of mW
        # Return value in units of dBm
        return 10.0*math.log10(pwr)

def getTec(dev, var, read):
    with dev.root.updateGroup():    
        msb = var.dependencies[0].get(read=read)
        lsb = var.dependencies[1].get(read=read)
        raw = (msb << 8) | lsb
        # Return value in units of mA
        return float(raw)*0.1

##############################################################################
# Dictionaries based on SFF-8024 Rev 4.9 (24MAY2021)
# https://members.snia.org/document/dl/26423
##############################################################################
IdentifierDict = {
    0x00: 'Unspecified',
    0x01: 'GBIC',
    0x02: 'Motherboard',
    0x03: 'SFP',
    0x04: 'XBI',
    0x05: 'XENPAK',
    0x06: 'XFP',
    0x07: 'XFF',
    0x08: 'XFP-E',
    0x09: 'XPAK',
    0x0A: 'X2',
    0x0B: 'DWDM-SFP',
    0x0C: 'QSFP',
    0x0D: 'QSFP+',
    0x0E: 'CXP',
    0x0F: 'HD-4X',
    0x10: 'HD-8X',
    0x11: 'QSFP28',
    0x12: 'CXP28',
    0x13: 'CDFP-Style1/2',
    0x14: 'HD-4X-Fanout',
    0x15: 'HD-8X-Fanout',
    0x16: 'CDFP-Style3',
    0x17: 'microQSFP',
    0x18: 'QSFP-DD',
    0x19: 'OSFP',
    0x1A: 'SFP-DD',
    0x1B: 'DSFP',
    0x1C: 'MiniLinkx4',
    0x1D: 'MiniLinkx8',
    0x1E: 'QSFP+',
}

ExtIdentifierDict = {
    0x00: 'Unspecified',
    0x01: '100G AOC (Active Optical Cable) or 25GAUI C2M AOC',
    0x02: '100GBASE-SR4 or 25GBASE-SR',
    0x03: '100GBASE-LR4 or 25GBASE-LR',
    0x04: '100GBASE-ER4 or 25GBASE-ER',
    0x05: '100GBASE-SR10',
    0x06: '100G CWDM4',
    0x07: '100G PSM4 Parallel SMF',
    0x08: '100G ACC (Active Copper Cable) or 25GAUI C2M ACC',
    0x09: 'Obsolete (assigned before 100G CWDM4 MSA required FEC)',
    0x0A: 'Reserved_0x0A',
    0x0B: '100GBASE-CR4, 25GBASE-CR CA-25G-L or 50GBASE-CR2 with RS (Clause91) FEC',
    0x0C: '25GBASE-CR CA-25G-S or 50GBASE-CR2 with BASE-R (Clause 74 Fire code) FEC',
    0x0D: '25GBASE-CR CA-25G-N or 50GBASE-CR2 with no FEC',
    0x0E: '10 Mb/s Single Pair Ethernet',
    0x0F: 'Reserved_0x0F',
    0x10: '40GBASE-ER4',
    0x11: '4 x 10GBASE-SR',
    0x12: '40G PSM4 Parallel SMF',
    0x13: 'G959.1 profile P1I1-2D1',
    0x14: 'G959.1 profile P1S1-2D2',
    0x15: 'G959.1 profile P1L1-2D2',
    0x16: '10GBASE-T with SFI electrical interface',
    0x17: '100G CLR4',
    0x18: '100G AOC or 25GAUI C2M AOC',
    0x19: '100G ACC or 25GAUI C2M ACC',
    0x1A: '100GE-DWDM2',
    0x1B: '100G 1550nm WDM (4 wavelengths)',
    0x1C: '10GBASE-T Short Reach',
    0x1D: '5GBASE-T',
    0x1E: '2.5GBASE-T',
    0x1F: '40G SWDM4',
    0x20: '100G SWDM4',
    0x21: '100G PAM4 BiDi',
    0x22: '4WDM-10 MSA',
    0x23: '4WDM-20 MSA',
    0x24: '4WDM-40 MSA',
    0x25: '100GBASE-DR',
    0x26: '100G-FR or 100GBASE-FR1 (Clause 140), CAUI-4 (no FEC)',
    0x27: '100G-LR or 100GBASE-LR1 (Clause 140), CAUI-4 (no FEC)',
    0x28: '100G-SR1 (P802.3db, Clause tbd), CAUI-4 (no FEC)',
    0x29: '100GBASE-SR1, 200GBASE-SR2 or 400GBASE-SR4',
    0x2A: '100GBASE-FR1',
    0x2B: '100GBASE-LR1',
    0x30: 'Active Copper Cable with 50GAUI, 100GAUI-2 or 200GAUI-4 C2M',
    0x31: 'Active Optical Cable with 50GAUI, 100GAUI-2 or 200GAUI-4 C2M',
    0x32: 'Active Copper Cable with 50GAUI, 100GAUI-2 or 200GAUI-4 C2M',
    0x33: 'Active Optical Cable with 50GAUI, 100GAUI-2 or 200GAUI-4 C2M',
    0x3F: '100GBASE-CR1, 200GBASE-CR2 or 400GBASE-CR4',
    0x40: '50GBASE-CR, 100GBASE-CR2, or 200GBASE-CR4',
    0x41: '50GBASE-SR, 100GBASE-SR2, or 200GBASE-SR4',
    0x42: '50GBASE-FR or 200GBASE-DR4',
    0x43: '200GBASE-FR4',
    0x44: '200G 1550 nm PSM4',
    0x45: '50GBASE-LR',
    0x46: '200GBASE-LR4',
    0x47: '400GBASE-DR4',
    0x48: '400GBASE-FR4',
    0x49: '400GBASE-LR4-6',
    0x7f: '256GFC-SW4',
    0x80: 'Capable of 64GFC',
    0x81: 'Capable of 128GFC',
}

ConnectorDict = {
    0x00: 'Unspecified',
    0x01: 'SC',
    0x02: 'Fibre Channel Style 1 copper connector',
    0x03: 'Fibre Channel Style 2 copper connector',
    0x04: 'BNC/TNC',
    0x05: 'Fibre Channel coaxial headers',
    0x06: 'Fiber Jack',
    0x07: 'LC',
    0x08: 'MT-RJ',
    0x09: 'MU',
    0x0A: 'SG',
    0x0B: 'Optical pigtail',
    0x0C: 'MPO 1x12',
    0x0D: 'MPO 2x16',
    0x20: 'HSSDC II',
    0x21: 'Copper Pigtail',
    0x22: 'RJ45',
    0x23: 'No separable connector',
    0x24: 'MXC 2x16',
    0x25: 'CS optical connector',
    0x26: 'SN',
    0x27: 'MPO 2x12',
    0x28: 'MPO 1x16',
}

EncodingDict = {
    0x0: 'Unspecified',
    0x1: '8B10B',
    0x2: '4B5B',
    0x3: 'NRZ',
    0x4: 'Manchester',
    0x5: 'SONET Scrambled',
    0x6: '64B/66B',
}

RateIdDict = {
    0x0: 'Unspecified',
    0x1: 'SFF-8079 (4/2/1G Rate Select and AS0/AS1)',
    0x2: 'SFF-8431 (8/4/2G RX Rate Select Only)',
    0x3: 'Unspecified',
    0x4: 'SFF-8431 (8/4/2G TX Rate Select Only)',
    0x5: 'Unspecified',
    0x6: 'SFF-8431 (8/4/2G Independent TX and RX Rate Select)',
    0x7: 'Unspecified',
    0x8: 'FC-PI-5 (16/8/4G RX Rate Select Only) High=16G, Low=8/4G',
    0x9: 'Unspecified',
    0xA: 'FC-PI-5 (16/8/4G Independent TX and RX Rate Select) High=16G, Low=8/4G',
},
