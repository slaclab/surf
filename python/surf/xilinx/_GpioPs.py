#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
# Based on Xilinx/embeddedsw driver:
# https://github.com/Xilinx/embeddedsw/blob/master/XilinxProcessorIPLib/drivers/gpiops/src/xgpiops.c
# https://www.xilinx.com/htmldocs/registers/ug1087/mod___gpio.html
#-----------------------------------------------------------------------------

import pyrogue as pr

class GpioPs(pr.Device):
    def __init__(self,
            mioConfig = [dict(name = f'MIO_{x}', enable = False) for x in range(78)],
            **kwargs):
        super().__init__(**kwargs)

        ################################################################################

        for i in range(16):
            idx = i+0
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_DATA',
                    offset      = 0x0000000000,
                    bitOffset   = i+0,
                    bitSize     = 1,
                    mode        = 'RW',
                ))

        for i in range(10):
            idx = i+16
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_DATA',
                    offset      = 0x0000000004,
                    bitOffset   = i+0,
                    bitSize     = 1,
                    mode        = 'RW',
                ))

        for i in range(16):
            idx = i+26
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_DATA',
                    offset      = 0x0000000008,
                    bitOffset   = i+0,
                    bitSize     = 1,
                    mode        = 'RW',
                ))

        for i in range(10):
            idx = i+42
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_DATA',
                    offset      = 0x000000000C,
                    bitOffset   = i+0,
                    bitSize     = 1,
                    mode        = 'RW',
                ))

        for i in range(16):
            idx = i+52
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_DATA',
                    offset      = 0x0000000010,
                    bitOffset   = i+0,
                    bitSize     = 1,
                    mode        = 'RW',
                ))

        for i in range(10):
            idx = i+68
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_DATA',
                    offset      = 0x0000000014,
                    bitOffset   = i+0,
                    bitSize     = 1,
                    mode        = 'RW',
                ))

        ################################################################################

        for i in range(16):
            idx = i+0
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_MASK',
                    offset      = 0x0000000000,
                    bitOffset   = i+16,
                    bitSize     = 1,
                    mode        = 'WO',
                ))

        for i in range(10):
            idx = i+16
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_MASK',
                    offset      = 0x0000000004,
                    bitOffset   = i+16,
                    bitSize     = 1,
                    mode        = 'WO',
                ))

        for i in range(16):
            idx = i+26
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_MASK',
                    offset      = 0x0000000008,
                    bitOffset   = i+16,
                    bitSize     = 1,
                    mode        = 'WO',
                ))

        for i in range(10):
            idx = i+42
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_MASK',
                    offset      = 0x000000000C,
                    bitOffset   = i+16,
                    bitSize     = 1,
                    mode        = 'WO',
                ))

        for i in range(16):
            idx = i+52
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_MASK',
                    offset      = 0x0000000010,
                    bitOffset   = i+16,
                    bitSize     = 1,
                    mode        = 'WO',
                ))

        for i in range(10):
            idx = i+68
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_MASK',
                    offset      = 0x0000000014,
                    bitOffset   = i+16,
                    bitSize     = 1,
                    mode        = 'WO',
                ))

        ################################################################################

        for i in range(26):
            idx = i+0
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_OUT',
                    offset      = 0x0000000040,
                    bitOffset   = i+0,
                    bitSize     = 1,
                    mode        = 'RW',
                ))


        for i in range(26):
            idx = i+26
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_OUT',
                    offset      = 0x0000000044,
                    bitOffset   = i+0,
                    bitSize     = 1,
                    mode        = 'RW',
                ))

        for i in range(26):
            idx = i+52
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_OUT',
                    offset      = 0x0000000048,
                    bitOffset   = i+0,
                    bitSize     = 1,
                    mode        = 'RW',
                ))


        ################################################################################

        for i in range(26):
            idx = i+0
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_IN',
                    offset      = 0x0000000060,
                    bitOffset   = i+0,
                    bitSize     = 1,
                    mode        = 'RO',
                ))


        for i in range(26):
            idx = i+26
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_IN',
                    offset      = 0x0000000064,
                    bitOffset   = i+0,
                    bitSize     = 1,
                    mode        = 'RO',
                ))

        for i in range(26):
            idx = i+52
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_IN',
                    offset      = 0x0000000068,
                    bitOffset   = i+0,
                    bitSize     = 1,
                    mode        = 'RO',
                ))

        ################################################################################

        for i in range(26):
            idx = i+0
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_DIR',
                    offset      = 0x0000000204,
                    bitOffset   = i+0,
                    bitSize     = 1,
                    mode        = 'RW',
                ))


        for i in range(26):
            idx = i+26
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_DIR',
                    offset      = 0x0000000244,
                    bitOffset   = i+0,
                    bitSize     = 1,
                    mode        = 'RW',
                ))

        for i in range(26):
            idx = i+52
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_DIR',
                    offset      = 0x0000000284,
                    bitOffset   = i+0,
                    bitSize     = 1,
                    mode        = 'RW',
                ))

        ################################################################################

        for i in range(26):
            idx = i+0
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_OEN',
                    offset      = 0x0000000208,
                    bitOffset   = i+0,
                    bitSize     = 1,
                    mode        = 'RW',
                ))


        for i in range(26):
            idx = i+26
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_OEN',
                    offset      = 0x0000000248,
                    bitOffset   = i+0,
                    bitSize     = 1,
                    mode        = 'RW',
                ))

        for i in range(26):
            idx = i+52
            if mioConfig[idx]["enable"]:
                self.add(pr.RemoteVariable(
                    name        = f'{mioConfig[idx]["name"]}_OEN',
                    offset      = 0x0000000288,
                    bitOffset   = i+0,
                    bitSize     = 1,
                    mode        = 'RW',
                ))

        ################################################################################
