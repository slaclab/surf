#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

import surf.ethernet.udp as udp

import click
import datetime

class HtspAxiLCtrl(pr.Device):
    def __init__(self, writeEn=False, **kwargs):
        super().__init__(**kwargs)

        mode = 'RW' if writeEn else 'RO'

        self.add(pr.RemoteCommand(
            name        =  'CountReset',
            description =  "Status Counter Reset Command",
            offset      =  0x000,
            bitOffset   =  0,
            bitSize     =  1,
            function    =  pr.BaseCommand.toggle,
        ))

        self.add(pr.RemoteVariable(
            name        =  'WRITE_EN_G',
            description =  'Generic: write-enable configuration of this HTSP AXI-Lite core',
            offset      =  0x004,
            bitOffset   =  0,
            bitSize     =  1,
            base        =  pr.Bool,
            mode        =  'RO',
        ))

        self.add(pr.RemoteVariable(
            name        =  'NUM_VC_G',
            description =  'Generic: number of virtual channels configured for this HTSP link',
            offset      =  0x004,
            bitOffset   =  8,
            bitSize     =  8,
            disp        =  '{:d}',
            mode        =  'RO',
        ))

        self.add(pr.RemoteVariable(
            name        =  'STATUS_CNT_WIDTH_G',
            description =  'Generic: bit width of status counters in this HTSP core',
            offset      =  0x004,
            bitOffset   =  16,
            bitSize     =  8,
            disp        =  '{:d}',
            mode        =  'RO',
        ))

        self.add(pr.RemoteVariable(
            name        =  'ERROR_CNT_WIDTH_G',
            description =  'Generic: bit width of error counters in this HTSP core',
            offset      =  0x004,
            bitOffset   =  24,
            bitSize     =  8,
            disp        =  '{:d}',
            mode        =  'RO',
        ))

        self.add(pr.RemoteVariable(
            name         =  'UpTimeCnt',
            description  =  'Number of seconds since last reset',
            hidden       =  True,
            offset       =  0x00C,
            bitSize      =  32,
            mode         =  'RO',
            disp         =  '{:d}',
            units        =  'seconds',
            pollInterval =  1,
        ))

        def parseUpTime(var,read):
            seconds=var.dependencies[0].get(read=read)
            if seconds == 0xFFFFFFFF:
                click.secho(f'Invalid {var.path} detected', fg='red')
                return 'Invalid'
            else:
                return str(datetime.timedelta(seconds=seconds))

        self.add(pr.LinkVariable(
            name        =  'UpTime',
            description =  'Time since power up or last CountReset event',
            mode        =  'RO',
            disp        =  '{}',
            variable    =  self.UpTimeCnt,
            linkedGet   =  parseUpTime,
            units       =  'HH:MM:SS',
        ))

        self.add(pr.RemoteVariable(
            name         =  'HtspClkFreq',
            description  =  'Measured HTSP clock frequency',
            mode         =  'RO',
            offset       =  0x010,
            bitSize      =  32,
            disp         =  '{:d}',
            units        =  'Hz',
            pollInterval =  1,
        ))

        self.add(pr.RemoteVariable(
            name        =  'Loopback',
            description =  'GTX/GTH loopback mode select',
            mode        =  mode,
            offset      =  0x030,
            bitSize     =  3,
            bitOffset   =  0,
        ))

        self.add(pr.RemoteVariable(
            name        =  'TxDisable',
            description =  'Disable the HTSP transmitter',
            mode        =  mode,
            offset      =  0x030,
            bitSize     =  1,
            bitOffset   =  8,
        ))

        self.add(pr.RemoteVariable(
            name        =  'TxFlowCntlDis',
            description =  'Disable transmit flow control (pause frame generation)',
            mode        =  mode,
            offset      =  0x030,
            bitSize     =  1,
            bitOffset   =  9,
        ))

        self.add(pr.RemoteVariable(
            name        =  'RxReset',
            description =  'Assert to reset the HTSP receiver',
            mode        =  mode,
            offset      =  0x030,
            bitSize     =  1,
            bitOffset   =  10,
        ))

        self.add(pr.RemoteVariable(
            name        =  'RxPolarity',
            description =  'Receive lane polarity invert mask (one bit per lane)',
            mode        =  mode,
            offset      =  0x038,
            bitSize     =  4,
            bitOffset   =  0,
        ))

        self.add(pr.RemoteVariable(
            name        =  'TxPolarity',
            description =  'Transmit lane polarity invert mask (one bit per lane)',
            mode        =  mode,
            offset      =  0x038,
            bitSize     =  4,
            bitOffset   =  16,
        ))

        self.add(pr.RemoteVariable(
            name        =  'TxNullInterval',
            description =  'Number of clock cycles between transmitted null SOF words',
            mode        =  mode,
            offset      =  0x03C,
            bitSize     =  32,
            disp        =  '{:d}',
        ))

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        =  f'TxDiffCtrl[{i}]',
                description =  'Transmit differential swing control for lane {i}',
                mode        =  mode,
                offset      =  64 + (4*i),
                bitSize     =  5,
                bitOffset   =  0,
            ))

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        =  f'TxPreCursor[{i}]',
                description =  'Transmit pre-cursor emphasis control for lane {i}',
                mode        =  mode,
                offset      =  64 + (4*i),
                bitSize     =  5,
                bitOffset   =  8,
            ))

        for i in range(4):
            self.add(pr.RemoteVariable(
                name        =  f'TxPostCursor[{i}]',
                description =  'Transmit post-cursor emphasis control for lane {i}',
                mode        =  mode,
                offset      =  64 + (4*i),
                bitSize     =  5,
                bitOffset   =  16,
            ))

        self.add(pr.RemoteVariable(
            name        =  'LocalMacRaw',
            description =  'Local MAC Address (big-Endian configuration)',
            mode        =  mode,
            offset      =  0x0C0,
            bitSize     =  48,
            hidden      =  True,
        ))

        self.add(pr.LinkVariable(
            name         =  "LocalMac",
            description  =  "Local MAC Address (human readable)",
            mode         =  mode,
            linkedGet    =  udp.getMacValue,
            linkedSet    =  udp.setMacValue,
            dependencies =  [self.variables["LocalMacRaw"]],
        ))

        self.add(pr.RemoteVariable(
            name         =  'RemoteMacRaw',
            description  =  'Remote MAC Address (big-Endian configuration)',
            mode         =  'RO',
            offset       =  0x0C8,
            bitSize      =  48,
            pollInterval =  1,
            hidden       =  True,
        ))

        self.add(pr.LinkVariable(
            name         =  "RemoteMac",
            description  =  "Remote MAC Address (human readable)",
            mode         =  'RO',
            linkedGet    =  udp.getMacValue,
            dependencies =  [self.variables["RemoteMacRaw"]],
        ))

        self.add(pr.RemoteVariable(
            name        =  'BroadcastMacRaw',
            description =  'Broadcast MAC Address (big-Endian configuration)',
            mode        =  mode,
            offset      =  0x0D0,
            bitSize     =  48,
            hidden      =  True,
        ))

        self.add(pr.LinkVariable(
            name         =  "BroadcastMac",
            description  =  "Broadcast MAC Address (human readable)",
            mode         =  mode,
            linkedGet    =  udp.getMacValue,
            linkedSet    =  udp.setMacValue,
            dependencies =  [self.variables["BroadcastMacRaw"]],
        ))

        self.add(pr.RemoteVariable(
            name        =  'EtherType',
            description =  'Ethernet EtherType field used to identify HTSP frames',
            mode        =  mode,
            offset      =  0x0D8,
            bitSize     =  16,
        ))

    def countReset(self):
        self.CountReset()

class HtspAxiLRxStatus(pr.Device):
    def __init__(self,
                 numVc           = 1,
                 statusCountBits = 12,
                 errorCountBits  = 8,
                 UpTimeCnt       = None,
                 **kwargs):
        super().__init__(**kwargs)

        # Pointer to HtspAxiLCtrl.UpTimeCnt
        self.UpTimeCnt = UpTimeCnt

        devOffset = 0x400

        def addStatusCountVar(**ecvkwargs):
            self.add(pr.RemoteVariable(
                description  =  'Status count',
                bitSize      =  statusCountBits,
                mode         =  'RO',
                disp         =  '{:d}',
                pollInterval =  1,
                **ecvkwargs))

        def addErrorCountVar(**ecvkwargs):
            self.add(pr.RemoteVariable(
                description  =  'Error count',
                bitSize      =  errorCountBits,
                mode         =  'RO',
                disp         =  '{:d}',
                pollInterval =  1,
                **ecvkwargs))

        for i in range(numVc):
            addStatusCountVar(
                name        = f'RemPauseCnt[{i}]',
                description = f'Receive pause count for virtual channel {i}',
                offset      = (0x400+(4*i)-devOffset),
            )

        addStatusCountVar(
            name        = 'FrameCnt',
            description = 'Number of received HTSP frames',
            offset      = (0x500-devOffset),
        )

        addStatusCountVar(
            name        = 'OpCodeEnCnt',
            description = 'Number of received op-code enable events',
            offset      = (0x504-devOffset),
        )

        statusList = [
            ['PhyRxActive',True],
            ['LinkReady',True],
            ['RemRxLinkReady',True],
            ['FrameError',False],
            ['LinkDown',False],
        ]

        statusDescList = [
            'PHY receive active event count',
            'Link ready transition event count',
            'Remote receive link ready event count',
            'Receive frame error event count',
            'Link down event count',
        ]

        for i in range(len(statusList)):
            addErrorCountVar(
                name        = (statusList[i][0]+'Cnt'),
                description = statusDescList[i],
                offset      = (0x600+(4*i)-devOffset),
            )

        self.add(pr.RemoteVariable(
            name         =  'FecCorrectedCodeWordCnt',
            description  =  'Number of FEC corrected code words received',
            offset       =  (0x614-devOffset),
            bitSize      =  32,
            mode         =  'RO',
            pollInterval =  1,
        ))

        self.add(pr.RemoteVariable(
            name         =  'FecUncorrectedCodeWordCnt',
            description  =  'Number of FEC uncorrected code words received',
            offset       =  (0x618-devOffset),
            bitSize      =  32,
            mode         =  'RO',
            pollInterval =  1,
        ))

        def getBitErrorRate(var,read):
            # Get the variable values from hardware
            try:
                seconds = float(var.dependencies[0].get(read=read))
                numErrBits = float(var.dependencies[1].get(read=read))
            except (TypeError, ValueError):
                return float('nan')

            # Check for the seconds=0 case
            if seconds<1:
                return float('nan')

            # For zero observed errors, IBERT (and most BERT analyzers) estimate BER
            # using a "3" to give 95% confidence that the true BER is lower than this value
            if numErrBits<3:
                numErrBits = 3.0 # Display the limit based on number of bits transmitted

            # Calculate the number of bits transmitted (assuming 4 lane x 25.78125 Gb/s = 103.125 Gb/s)
            LANE_RATE_Gbps = 25.78125
            NUM_LANES = 4.0
            totalBits = seconds * LANE_RATE_Gbps * NUM_LANES * 1e9

            # Return the bit error rate
            return (numErrBits/totalBits)

        self.add(pr.LinkVariable(
            name         =  'BitErrorRate',
            description  =  'Assumes that incrementing FecCorrectedCodeWordCnt = 1 bit error event (which is not always the case because FEC will correct for up to 70 bits)',
            mode         =  'RO',
            disp         =  '{:.3e}', # scientific notation with three decimal places
            dependencies =  [self.UpTimeCnt, self.FecCorrectedCodeWordCnt],
            linkedGet    =  getBitErrorRate,
        ))

        statusBoolDescList = [
            'PHY receive active status',
            'HTSP link ready status',
            'Remote receive link ready status',
        ]

        for i in range(len(statusList)):
            if statusList[i][1]:
                self.add(pr.RemoteVariable(
                    name         =  statusList[i][0],
                    description  =  statusBoolDescList[sum(1 for j in range(i) if statusList[j][1])],
                    offset       =  (0x710-devOffset),
                    bitOffset    =  i,
                    bitSize      =  1,
                    base         =  pr.Bool,
                    mode         =  'RO',
                    pollInterval =  1,
                ))

        self.add(pr.RemoteVariable(
            name         =  'RemLinkData',
            description  =  'Remote sideband link data word',
            offset       =  (0x720-devOffset),
            bitSize      =  128,
            mode         =  'RO',
            pollInterval =  1,
        ))

        self.add(pr.RemoteVariable(
            name         =  'RemOpCodeData',
            description  =  'Remote op-code data word received from link partner',
            offset       =  (0x730-devOffset),
            bitSize      =  128,
            mode         =  'RO',
            pollInterval =  1,
        ))

        self.add(pr.RemoteVariable(
            name         =  'RemRxPause',
            description  =  'Remote receive pause status bits (one per virtual channel)',
            offset       =  (0x740-devOffset),
            bitSize      =  numVc,
            mode         =  'RO',
            pollInterval =  1,
        ))

        self.add(pr.RemoteVariable(
            name         =  'RxMinPayloadSize',
            description  =  'Minimum received payload size observed',
            mode         =  'RO',
            offset       =  0x750,
            bitSize      =  16,
            bitOffset    =  0,
            disp         =  '{:d}',
            units        =  'Bytes',
            pollInterval =  1,
        ))

        self.add(pr.RemoteVariable(
            name         =  'RxMaxPayloadSize',
            description  =  'Maximum received payload size observed',
            mode         =  'RO',
            offset       =  0x750,
            bitSize      =  16,
            bitOffset    =  16,
            disp         =  '{:d}',
            units        =  'Bytes',
            pollInterval =  1,
        ))

class HtspAxiLTxStatus(pr.Device):
    def __init__(self,
                 numVc           = 1,
                 statusCountBits = 12,
                 errorCountBits  = 8,
                 **kwargs):
        super().__init__(**kwargs)

        devOffset = 0x800

        def addStatusCountVar(**ecvkwargs):
            self.add(pr.RemoteVariable(
                description  =  'Status count',
                bitSize      =  statusCountBits,
                mode         =  'RO',
                disp         =  '{:d}',
                pollInterval =  1,
                **ecvkwargs))

        def addErrorCountVar(**ecvkwargs):
            self.add(pr.RemoteVariable(
                description  =  'Error count',
                bitSize      =  errorCountBits,
                mode         =  'RO',
                disp         =  '{:d}',
                pollInterval =  1,
                **ecvkwargs))

        for i in range(numVc):
            addStatusCountVar(
                name        = f'LocPauseCnt[{i}]',
                description = f'Local transmit pause count for virtual channel {i}',
                offset      = (0x800+(4*i)-devOffset),
            )

        for i in range(numVc):
            addErrorCountVar(
                name        = f'LocOverflowCnt[{i}]',
                description = f'Local transmit overflow error count for virtual channel {i}',
                offset      = (0x840+(4*i)-devOffset),
            )

        addStatusCountVar(
            name        = 'FrameCnt',
            description = 'Number of transmitted HTSP frames',
            offset      = (0x900-devOffset),
        )

        addStatusCountVar(
            name        = 'OpCodeEnCnt',
            description = 'Number of transmitted op-code enable events',
            offset      = (0x904-devOffset),
        )

        statusList = [
            ['phyTxActive',True],
            ['LinkReady',True],
            ['FrameError',False],
        ]

        txStatusDescList = [
            'PHY transmit active event count',
            'Transmit link ready transition event count',
            'Transmit frame error event count',
        ]

        for i in range(len(statusList)):
            addErrorCountVar(
                name        = (statusList[i][0]+'Cnt'),
                description = txStatusDescList[i],
                offset      = (0xA00+(4*i)-devOffset),
            )

        txStatusBoolDescList = [
            'PHY transmit active status',
            'HTSP transmit link ready status',
        ]

        for i in range(len(statusList)):
            if statusList[i][1]:
                self.add(pr.RemoteVariable(
                    name         =  statusList[i][0],
                    description  =  txStatusBoolDescList[sum(1 for j in range(i) if statusList[j][1])],
                    offset       =  (0xB10-devOffset),
                    bitOffset    =  i,
                    bitSize      =  1,
                    base         =  pr.Bool,
                    mode         =  'RO',
                    pollInterval =  1,
                ))

        self.add(pr.RemoteVariable(
            name         =  'LocLinkData',
            description  =  'Local sideband link data word transmitted to link partner',
            offset       =  (0xB20-devOffset),
            bitSize      =  128,
            mode         =  'RO',
            pollInterval =  1,
        ))

        self.add(pr.RemoteVariable(
            name         =  'LocOpCodeData',
            description  =  'Local op-code data word transmitted to link partner',
            offset       =  (0xB30-devOffset),
            bitSize      =  128,
            mode         =  'RO',
            pollInterval =  1,
        ))

        self.add(pr.RemoteVariable(
            name         =  'LocTxPause',
            description  =  'Local transmit pause status bits (one per virtual channel)',
            offset       =  (0xB40-devOffset),
            bitSize      =  numVc,
            mode         =  'RO',
            pollInterval =  1,
        ))

        self.add(pr.RemoteVariable(
            name         =  'TxMinPayloadSize',
            description  =  'Minimum transmitted payload size observed',
            mode         =  'RO',
            offset       =  0xB50,
            bitSize      =  16,
            bitOffset    =  0,
            disp         =  '{:d}',
            units        =  'Bytes',
            pollInterval =  1,
        ))

        self.add(pr.RemoteVariable(
            name         =  'TxMaxPayloadSize',
            description  =  'Maximum transmitted payload size observed',
            mode         =  'RO',
            offset       =  0xB50,
            bitSize      =  16,
            bitOffset    =  16,
            disp         =  '{:d}',
            units        =  'Bytes',
            pollInterval =  1,
        ))

class HtspAxiL(pr.Device):
    def __init__(self,
                 numVc           = 1,
                 statusCountBits = 12,
                 errorCountBits  = 8,
                 writeEn         = False,
                 **kwargs):
        super().__init__(**kwargs)

        self.add(HtspAxiLCtrl(
            name    = 'Ctrl',
            offset  = 0x000,
            writeEn = writeEn,
        ))

        self.add(HtspAxiLRxStatus(
            name            = 'RxStatus',
            offset          = 0x400,
            numVc           = numVc,
            statusCountBits = statusCountBits,
            errorCountBits  = errorCountBits,
            UpTimeCnt       = self.Ctrl.UpTimeCnt,
        ))

        self.add(HtspAxiLTxStatus(
            name            = 'TxStatus',
            offset          = 0x800,
            numVc           = numVc,
            statusCountBits = statusCountBits,
            errorCountBits  = errorCountBits,
        ))
