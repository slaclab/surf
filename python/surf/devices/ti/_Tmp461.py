#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
# Note: This implementation doesn't use LSB and rounds all variables to 1 degC
#-----------------------------------------------------------------------------

import pyrogue as pr

class Tmp461(pr.Device):
    def __init__(self,
            pollInterval = 1,
            **kwargs):
        super().__init__(**kwargs)

        ############################################################################

        def getTempReg(var):
            x    = var.dependencies[0].value()
            sign = x >> 7  # Get the sign bit
            x   &= 0x7F    # mask off sign bit
            x    = float(x)# Covert to degC
            if (sign==1):
                x *= -1.0
            return int(x)

        def setTempReg(deps):
            def setTempValues(var, value, write):
                if (value<0):
                    sign = 0x80
                else:
                    sign = 0x00
                x = int(abs(value))
                rawVal = (x&0xFF) | sign
                deps[0].set(rawVal,write)
            return setTempValues

        def addBoolPair(name,description,rdOffset,wrOffset,bitOffset):
            self.add(pr.RemoteVariable(
                name         = (name+"Read"),
                description  = description,
                offset       = rdOffset,
                bitSize      = 1,
                bitOffset    = bitOffset,
                base         = pr.Bool,
                mode         = 'RO',
                hidden       = True,
            ))
            self.add(pr.RemoteVariable(
                name         = (name+"Write"),
                description  = description,
                offset       = wrOffset,
                bitSize      = 1,
                bitOffset    = bitOffset,
                base         = pr.Bool,
                mode         = 'WO',
                hidden       = True,
            ))

            rdVar = self.variables[name+"Read"]
            wrVar = self.variables[name+"Write"]

            self.add(pr.LinkVariable(
                name         = name,
                description  = description,
                mode         = 'RW',
                linkedGet    = lambda: rdVar.value(),
                linkedSet    = lambda value, write: wrVar.set(value),
                dependencies = [rdVar],
                enum        = {
                    False: 'False',
                    True:  'True',
                },

            ))

        ############################################################################

        self.add(pr.RemoteVariable(
            name        = 'LocalTemperatureHighByte',
            description = 'Local temperature high byte (LTHB)',
            offset      = (0x00 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
            pollInterval= pollInterval,
            hidden      = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'LocalTemperature',
            description  = 'Local temperature',
            mode         = 'RO',
            units        = 'degC',
            linkedGet    = getTempReg,
            disp         = '{:d}',
            dependencies = [self.LocalTemperatureHighByte],
        ))

        ############################################################################

        self.add(pr.RemoteVariable(
            name        = 'RemoteTemperatureHighByte',
            description = 'Remote temperature high byte (RTHB)',
            offset      = (0x01 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
            pollInterval= pollInterval,
            hidden      = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'RemoteTemperature',
            description  = 'Remote Temperature',
            mode         = 'RO',
            units        = 'degC',
            linkedGet    = getTempReg,
            disp         = '{:d}',
            dependencies = [self.RemoteTemperatureHighByte],
        ))

        ############################################################################

        self.add(pr.RemoteVariable(
            name        = 'Busy',
            description = 'When logic 1, A/D is busy converting. POR state = n/a.',
            offset      = (0x02 << 2),
            bitSize     = 1,
            bitOffset   = 7,
            base        = pr.Bool,
            mode        = 'RO',
            pollInterval= pollInterval,
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Lhigh',
            description = 'When logic 1, indicates local HIGH temperature alarm. POR state = 0.',
            offset      = (0x02 << 2),
            bitSize     = 1,
            bitOffset   = 6,
            base        = pr.Bool,
            mode        = 'RO',
            pollInterval= pollInterval,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Llow',
            description = 'When logic 1, indicates a local LOW temperature alarm. POR state = 0.',
            offset      = (0x02 << 2),
            bitSize     = 1,
            bitOffset   = 5,
            base        = pr.Bool,
            mode        = 'RO',
            pollInterval= pollInterval,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Rhigh',
            description = 'When logic 1, indicates a remote diode HIGH temperature alarm. POR state = 0.',
            offset      = (0x02 << 2),
            bitSize     = 1,
            bitOffset   = 4,
            base        = pr.Bool,
            mode        = 'RO',
            pollInterval= pollInterval,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Rlow',
            description = 'When logic 1, indicates a remote diode LOW temperature alarm. POR state = 0.',
            offset      = (0x02 << 2),
            bitSize     = 1,
            bitOffset   = 3,
            base        = pr.Bool,
            mode        = 'RO',
            pollInterval= pollInterval,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Open',
            description = 'When logic 1, indicates a remote diode disconnect. POR state = 0.',
            offset      = (0x02 << 2),
            bitSize     = 1,
            bitOffset   = 2,
            base        = pr.Bool,
            mode        = 'RO',
            pollInterval= pollInterval,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Rcrit',
            description = 'When logic 1, indicates a remote diode critical temperature alarm. POR state = 0.',
            offset      = (0x02 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            base        = pr.Bool,
            mode        = 'RO',
            pollInterval= pollInterval,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Lcrit',
            description = 'When logic 1, indicates a local critical temperature alarm. POR state = 0.',
            offset      = (0x02 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.Bool,
            mode        = 'RO',
            pollInterval= pollInterval,
        ))

        ############################################################################

        addBoolPair(
            name        = 'AlertMask',
            rdOffset    = (0x03 << 2),
            wrOffset    = (0x09 << 2),
            bitOffset   = 7,
            description  = "0: ALERT enabled, 1: ALERT masked off",
        )

        addBoolPair(
            name        = 'Shutdown',
            rdOffset    = (0x03 << 2),
            wrOffset    = (0x09 << 2),
            bitOffset   = 6,
            description  = "0: Run, 1: Shutdown",
        )

        addBoolPair(
            name        = 'Range',
            rdOffset    = (0x03 << 2),
            wrOffset    = (0x09 << 2),
            bitOffset   = 2,
            description  = "0: -40degC to 127degC, 1: -64degC to 191degC",
        )

        ############################################################################

        self.add(pr.RemoteVariable(
            name        = 'ConvertRateRead',
            description = 'conversion rate read access (CR)',
            offset      = (0x04 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'ConvertRateWrite',
            description = 'conversion rate write access (CR)',
            offset      = (0x0A << 2),
            bitSize     = 4,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'WO',
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'ConvertRate',
            description  = 'Conversion rate',
            mode         = 'RW',
            linkedGet    = lambda: self.ConvertRateRead.value(),
            linkedSet    = lambda value, write: self.ConvertRateWrite.set(value),
            dependencies = [self.ConvertRateRead],
            units       = 'Hz',
            enum        = {
                0x00: '0.0625',
                0x01: '0.125',
                0x02: '0.25',
                0x03: '0.50',
                0x04: '1.0',
                0x05: '2',
                0x06: '4',
                0x07: '8',
                0x08: '16',
                0x09: '32',
            },
        ))

        ############################################################################

        self.add(pr.RemoteVariable(
            name        = 'LocalHighSetpointRead',
            description = 'local high setpoint read access (LHS)',
            offset      = (0x05 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LocalHighSetpointWrite',
            description = 'local high setpoint write access (LHS)',
            offset      = (0x0B << 2),
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'WO',
            hidden      = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'LocalHighSetpoint',
            description  = 'Local High setpoint',
            mode         = 'RW',
            linkedGet    = getTempReg,
            linkedSet    = setTempReg([self.LocalHighSetpointWrite]),
            dependencies = [self.LocalHighSetpointRead],
            units       = 'degC',
        ))

        ############################################################################

        self.add(pr.RemoteVariable(
            name        = 'LocalLowSetpointRead',
            description = 'Local Low setpoint read access (LLS)',
            offset      = (0x06 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LocalLowSetpointWrite',
            description = 'Local Low setpoint write access (LLS)',
            offset      = (0x0C << 2),
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'WO',
            hidden      = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'LocalLowSetpoint',
            description  = 'Local low setpoint',
            mode         = 'RW',
            linkedGet    = getTempReg,
            linkedSet    = setTempReg([self.LocalLowSetpointWrite]),
            dependencies = [self.LocalLowSetpointRead],
            units       = 'degC',
        ))

        ############################################################################

        self.add(pr.RemoteVariable(
            name        = 'RemoteHighSetpointHighByteRead',
            description = 'Remote high setpoint high byte read access (RHSHB)',
            offset      = (0x07 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'RemoteHighSetpointHighByteWrite',
            description = 'Remote high setpoint high byte write access (RHSHB)',
            offset      = (0x0D << 2),
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'WO',
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'RemoteHighSetpoint',
            description  = 'Remote High setpoint',
            mode         = 'RW',
            linkedGet    = getTempReg,
            linkedSet    = setTempReg([self.RemoteHighSetpointHighByteWrite]),
            dependencies = [self.RemoteHighSetpointHighByteRead],
            units       = 'degC',
        ))

        ############################################################################

        self.add(pr.RemoteVariable(
            name        = 'RemoteLowSetpointHighByteRead',
            description = 'Remote Low setpoint high byte read access (RLSHB)',
            offset      = (0x08 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'RemoteLowSetpointHighByteWrite',
            description = 'Remote Low setpoint high byte write access (RLSHB)',
            offset      = (0x0E << 2),
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'WO',
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'RemoteLowSetpoint',
            description  = 'Remote Low setpoint',
            mode         = 'RW',
            linkedGet    = getTempReg,
            linkedSet    = setTempReg([self.RemoteLowSetpointHighByteWrite]),
            dependencies = [self.RemoteLowSetpointHighByteRead],
            units       = 'degC',
        ))

    ############################################################################

        self.add(pr.RemoteVariable(
            name        = 'RemoteTcritSetpoint',
            description = 'Remote T_CRIT setpoint (RCS)',
            offset      = (0x19 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.Int,
            mode        = 'RW',
            units       = 'degC',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LocalTcritSetpoint',
            description = 'Local T_CRIT setpoint (LCS)',
            offset      = (0x20 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.Int,
            mode        = 'RW',
            units       = 'degC',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'TcritHysteresis',
            description = 'T_CRIT hysteresis (TH)',
            offset      = (0x21 << 2),
            bitSize     = 5,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
            units       = 'degC',
            disp        = '{:d}',
        ))

        ############################################################################

        self.add(pr.RemoteCommand(
            name        = 'OneShot',
            description = 'writing register initiates a one-shot conversion (One Shot)',
            offset      = (0x0F << 2),
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.UInt,
            function     = lambda cmd: cmd.set(1),
            hidden       = False,
        ))

        self.add(pr.RemoteVariable(
            name        = 'ManufacturerId',
            description = 'Read manufacturers ID (RMID) should be 0x55',
            offset      = (0xFE << 2),
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))

        ############################################################################

    def simpleView(self):
        # Hide all the variable
        self.hideVariables(hidden=True)
        # Then unhide the most interesting ones
        vars = ['enable', 'LocalTemperature', 'RemoteTemperature']
        self.hideVariables(hidden=False, variables=vars)
