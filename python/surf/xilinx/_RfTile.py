#-----------------------------------------------------------------------------
# Title      : Xilinx RFSoC RF data converter tile
#-----------------------------------------------------------------------------
# Description:
# Xilinx RFSoC RF data converter tile
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

class RfTile(pr.Device):
    def __init__(
            self,
            gen3        = True, # True if using RFSoC GEN3 Hardware
            description = "RFSoC data converter tile registers",
            **kwargs):
        super().__init__(description=description, **kwargs)

        powerOnSequenceSteps = {
            0:  "Device_Power-up_and_Configuration[0]",
            1:  "Device_Power-up_and_Configuration[1]",
            2:  "Device_Power-up_and_Configuration[2]",
            3:  "Power_Supply_Adjustment[0]",
            4:  "Power_Supply_Adjustment[1]",
            5:  "Power_Supply_Adjustment[2]",
            6:  "Clock_Configuration[0]",
            7:  "Clock_Configuration[1]",
            8:  "Clock_Configuration[2]",
            9:  "Clock_Configuration[3]",
            10: "Clock_Configuration[4]",
            11: "Converter_Calibration[0]",
            12: "Converter_Calibration[1]",
            13: "Converter_Calibration[2]",
            14: "Wait_for_deassertion_of_AXI4-Stream_reset",
            15: "Done",
        }
        ##############################
        # Variables
        ##############################
        self.add(pr.RemoteVariable(
            name         = "RestartSM",
            description  = "Write 1 to start power-on state machine.  Auto-clear.  SM stops at stages programmed in RestartState",
            offset       =  0x0004,
            bitSize      =  1,
            bitOffset    =  0,
            mode         = "WO",
        ))

        self.add(pr.RemoteVariable(
            name         = "RestartStateEnd",
            description  = "End state for power-on sequence",
            offset       =  0x0008,
            bitSize      =  8,
            bitOffset    =  0,
            mode         = "RW",
            enum         = powerOnSequenceSteps,
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "RestartStateStart",
            description  = "Start state for power-on sequence",
            offset       =  0x0008,
            bitSize      =  8,
            bitOffset    =  8,
            mode         = "RW",
            enum         = powerOnSequenceSteps,
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "CurrentState",
            description  = "Current state register",
            offset       =  0x000C,
            bitSize      =  8,
            bitOffset    =  0,
            mode         = "RO",
            pollInterval = 1,
            enum         = powerOnSequenceSteps,
        ))

        self.add(pr.RemoteVariable(
            name         = "ResetCount",
            description  = "reset count register",
            offset       =  0x0038,
            bitSize      =  8,
            bitOffset    =  0,
            mode         = "RO",
            hidden       = True,
        ))

        if gen3:
            self.add(pr.RemoteVariable(
                name         = "ClockDetector",
                description  = "Clock detector status. Asserted High when the tile clock detector has detected a valid clock on its local clock input.",
                offset       =  0x0084,
                bitSize      =  1,
                bitOffset    =  0,
                mode         = "RO",
                pollInterval = 1,
            ))

        self.add(pr.RemoteVariable(
            name         = "InterruptStatus",
            description  = "interrupt status register",
            offset       =  0x0200,
            bitSize      =  4,
            bitOffset    =  0,
            mode         = "RW",
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "InterruptEnable",
            description  = "interrupt status register",
            offset       =  0x0204,
            bitSize      =  5,
            bitOffset    =  0,
            mode         = "RW",
            hidden       = True,
        ))

        for i in range(4):
            self.add(pr.RemoteVariable(
                name         = f'InterruptCh[{i}]',
                description  = f'Converter {i} interrupt enable',
                offset       =  0x0208 + 8*i,
                bitSize      =  32,
                mode         = "RW",
                hidden       = True,
            ))

            self.add(pr.RemoteVariable(
                name         = f'InterruptEnableCh[{i}]',
                description  = f'Converter {i} interrupt register',
                offset       =  0x020C + 8*i,
                bitSize      =  32,
                mode         = "RW",
                hidden       = True,
            ))

        self.add(pr.RemoteVariable(
            name         = "clockPresent",
            description  = "Clock present: Asserted when the reference clock for the tile is present.",
            offset       =  0x0228,
            bitSize      =  1,
            bitOffset    =  0,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "supplyStable",
            description  = "Supplies up: Asserted when the external supplies to the tile are stable.",
            offset       =  0x0228,
            bitSize      =  1,
            bitOffset    =  1,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "poweredUp",
            description  = "Power-up state: Asserted when the tile is in operation.",
            offset       =  0x0228,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "pllLocked",
            description  = "PLL locked: Asserted when the tile PLL has achieved lock.",
            offset       =  0x0228,
            bitSize      =  1,
            bitOffset    =  3,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "fifoDisable",
            description  = "Disable the interface FIFO for converter",
            offset       =  0x0230,
            bitSize      =  1,
            bitOffset    =  0,
            mode         = "RW",
            hidden       = True,
        ))
