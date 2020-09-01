#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class AxiRateGen(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name         = 'WriteEnable',
            offset       = 0x00,
            bitSize      = 1,
            base         = pr.Bool,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ReadEnable',
            offset       = 0x04,
            bitSize      = 1,
            base         = pr.Bool,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'WriteSize',
            description  = 'Number of bytes for transaction (zero inclusive)',
            offset       = 0x10,
            bitSize      = 12,
            mode         = 'RW',
            units        = 'Bytes',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ReadSize',
            description  = 'Number of bytes for transaction (zero inclusive)',
            offset       = 0x14,
            bitSize      = 12,
            mode         = 'RW',
            units        = 'Bytes',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'WriteTimerConfig',
            description  = 'Minimum number clock cycles between transaction (zero inclusive)',
            offset       = 0x20,
            bitSize      = 32,
            mode         = 'RW',
            units        = 'Clock Cycles',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ReadTimerConfig',
            description  = 'Minimum number clock cycles between transaction (zero inclusive)',
            offset       = 0x24,
            bitSize      = 32,
            mode         = 'RW',
            units        = 'Clock Cycles',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'awburst',
            offset       = 0x30,
            bitSize      = 2,
            mode         = 'RW',
            enum         = {
                0 : "FIXED",
                1 : "INCR",
                2 : "WRAP",
                3 : "Reserved",
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'arburst',
            offset       = 0x34,
            bitSize      = 2,
            mode         = 'RW',
            enum         = {
                0 : "FIXED",
                1 : "INCR",
                2 : "WRAP",
                3 : "Reserved",
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'awcache',
            offset       = 0x40,
            bitSize      = 4,
            mode         = 'RW',
            enum         = {
                0b0000 : "Device_Non-bufferable",
                0b0001 : "Device_Bufferable",
                0b0010 : "Normal_Non-cacheable_Non-bufferable",
                0b0011 : "Normal_Non-cacheable_Bufferable",
                0b0110 : "Write-through_Read-allocate",
                0b1010 : "Write-through_Write-allocate",
                0b1110 : "Write-through_Read_and_Write-allocate",
                0b0111 : "Write-back_Read-allocate",
                0b1011 : "Write-back_Write-allocate",
                0b1111 : "Write-back_Read_and_Write-allocate",
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'arcache',
            offset       = 0x44,
            bitSize      = 4,
            mode         = 'RW',
            enum         = {
                0b0000 : "Device_Non-bufferable",
                0b0001 : "Device_Bufferable",
                0b0010 : "Normal_Non-cacheable_Non-bufferable",
                0b0011 : "Normal_Non-cacheable_Bufferable",
                0b0110 : "Write-through_Read-allocate",
                0b1010 : "Write-through_Write-allocate",
                0b1110 : "Write-through_Read_and_Write-allocate",
                0b0111 : "Write-back_Read-allocate",
                0b1011 : "Write-back_Write-allocate",
                0b1111 : "Write-back_Read_and_Write-allocate",
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'ADDR_WIDTH_C',
            description  = 'AXI_CONFIG_G.ADDR_WIDTH_C',
            offset       = 0x80,
            bitSize      = 8,
            bitOffset    = 0,
            mode         = 'RO',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DATA_BYTES_C',
            description  = 'AXI_CONFIG_G.DATA_BYTES_C',
            offset       = 0x80,
            bitSize      = 8,
            bitOffset    = 8,
            mode         = 'RO',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ID_BITS_C',
            description  = 'AXI_CONFIG_G.ID_BITS_C',
            offset       = 0x80,
            bitSize      = 8,
            bitOffset    = 16,
            mode         = 'RO',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LEN_BITS_C',
            description  = 'AXI_CONFIG_G.LEN_BITS_C',
            offset       = 0x80,
            bitSize      = 8,
            bitOffset    = 24,
            mode         = 'RO',
            disp         = '{:d}',
        ))
