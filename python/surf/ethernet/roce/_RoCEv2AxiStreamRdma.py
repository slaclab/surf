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

class RoCEv2AxiStreamRdma(pr.Device):
    def __init__( self,
                  dispatchBits=24,
                  **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name         = 'DispatchEnable',
            description  = 'Arm continuous event-driven dispatch: while set, the FW issues '
                           'one RDMA SEND-with-immediate per complete PRBS packet buffered '
                           'in the repack FIFO. Set with SsiPrbsTx.TxEn=True for a '
                           'self-sustaining stream; clear to stop',
            offset       = 0x00,
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.Bool,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MaxSize',
            description  = 'FW-constant maximum bytes per RDMA SEND (= one PMTU, the replay-slot '
                           'capacity MAX_BEATS_C*32). READ-ONLY: the actual SEND length is measured '
                           'in FW per-packet from the inbound tLast-delimited stream, so software '
                           'never programs the frame size. Observe the live frame size via MonFrameSize.',
            offset       = 0x04,
            bitSize      = 32,
            disp         = '{:d}',
            units        = 'B',
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'RKey',
            description  = 'Legacy RETH remote key — UNUSED by RDMA SEND (FW drives rKey=0); '
                           'retained for register-map stability',
            offset       = 0x08,
            bitSize      = 32,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LKey',
            description  = 'Local key for the RDMA SEND',
            offset       = 0x0C,
            bitSize      = 32,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'SQpn',
            description  = 'Source queue-pair number',
            offset       = 0x10,
            bitSize      = 24,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DQpn',
            description  = 'Destination queue-pair number (UD-datagram field). The RC '
                           'RDMA-WRITE path routes via SQpn + the QP context, so this is '
                           'normally left 0',
            offset       = 0x14,
            bitSize      = 24,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'RemAddr',
            description  = 'Legacy RETH remote address (64-bit, 0x18/0x1C) — UNUSED by RDMA '
                           'SEND (FW drives rAddr=0); retained for register-map stability',
            offset       = 0x18,
            bitSize      = 64,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'AddrWrapCount',
            description  = 'Number of immDt slot increments before wrapping back to 0 (the '
                           'free-running ring position stamped in the immediate)',
            offset       = 0x20,
            bitSize      = 32,
            mode         = 'RW',
        ))

        # Flow control is native FW<->NIC: the FW dispatches RDMA-SEND-with-immediate
        # (two-sided), so a full host recv queue makes the NIC RNR-NAK; the blue-rdma
        # SQ stalls/retries (rnr_retry=7) and backpressures the dispatcher. There is
        # NO software credit register in the real-time path (the legacy CreditWindow /
        # CreditConsumed registers at 0x24/0x28 are removed).

        # RO status block (based at 0x100, disjoint from the RW block) ---------

        self.add(pr.RemoteVariable(
            name         = 'SuccessCounter',
            description  = 'Count of successful completions',
            offset       = 0x100,
            bitSize      = dispatchBits,
            mode         = 'RO',
            pollInterval = 1,
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'UnsuccessCounter',
            description  = 'Count of unsuccessful completions',
            offset       = 0x104,
            bitSize      = dispatchBits,
            mode         = 'RO',
            pollInterval = 1,
            disp         = '{:d}',
        ))

        self.add(pr.RemoteCommand(
            name        = 'ResetCounters',
            description = 'Strobe to clear the Success/Unsuccess/Oversize counters. toggle (1->0) drives the FW level-clear one-shot',
            offset      = 0x108,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.UInt,
            function    = pr.RemoteCommand.toggle,
        ))

        self.add(pr.RemoteVariable(
            name         = 'OversizeCount',
            description  = 'Count of over-cap frames DROPPED: a frame whose length exceeded the '
                           'per-SEND cap (MaxSize) is discarded in FW (not dispatched) instead of '
                           'flagged to the engine, which would put the blue-rdma SQ into its ERROR '
                           'state. Dropping keeps the SQ healthy so the datapath self-recovers when '
                           'the frame size returns to <= MaxSize.',
            offset       = 0x10C,
            bitSize      = dispatchBits,
            mode         = 'RO',
            pollInterval = 1,
            disp         = '{:d}',
        ))

        # AxiStreamMon status (RO, based at 0x200) — throughput of the FIFO drain
        # stream (PRBS packets drained into the replay ring). Cumulative since the
        # last ResetCounters (or roceRst); rate/bandwidth refresh at 1 Hz in the FW.
        for name, off, bits, units in [
            ('MonFrameCnt',     0x200, 64, 'frames'),
            ('MonFrameRate',    0x208, 32, 'Hz'),
            ('MonFrameRateMax', 0x20C, 32, 'Hz'),
            ('MonFrameRateMin', 0x210, 32, 'Hz'),
            ('MonFrameSize',    0x22C, 32, 'B'),
            ('MonFrameSizeMax', 0x230, 32, 'B'),
            ('MonFrameSizeMin', 0x234, 32, 'B'),
        ]:
            self.add(pr.RemoteVariable(
                name         = name,
                description  = f'AxiStreamMon: {name[3:]} of the FIFO drain stream',
                offset       = off,
                bitSize      = bits,
                mode         = 'RO',
                units        = units,
                disp         = '{:d}',
                pollInterval = 1,
            ))

        # Bandwidth: the FW reports Byte/s; expose it as Gb/s (giga BITS/s) for
        # display. Keep the raw Byte/s register hidden and convert via a LinkVariable
        # (Gb/s = Byte/s * 8 / 1e9).
        for name, off in [
            ('MonBandwidth',    0x214),
            ('MonBandwidthMax', 0x21C),
            ('MonBandwidthMin', 0x224),
        ]:
            raw = pr.RemoteVariable(
                name         = f'{name}Bytes',
                description  = f'AxiStreamMon: {name[3:]} of the FIFO drain stream (raw Byte/s)',
                offset       = off,
                bitSize      = 64,
                mode         = 'RO',
                units        = 'B/s',
                disp         = '{:d}',
                hidden       = True,
                pollInterval = 1,
            )
            self.add(raw)
            self.add(pr.LinkVariable(
                name         = name,
                description  = f'AxiStreamMon: {name[3:]} of the FIFO drain stream',
                units        = 'Gb/s',
                disp         = '{:0.3f}',
                mode         = 'RO',
                dependencies = [raw],
                linkedGet    = lambda dev, var, read: var.dependencies[0].get(read=read) * 8.0 / 1.0e9,
            ))

    def countReset(self):
        # Hook the standard pyrogue count-reset (root.CountReset / GUI "Count Reset")
        # into the FW ResetCounters strobe. In the RTL monRst = roceRst or resetCounters,
        # so this clears the FW Success/Unsuccess counters AND the AxiStreamMon
        # statistics (frameCnt + all min/max) together.
        self.ResetCounters()
