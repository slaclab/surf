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

from surf.ethernet.roce._RoCEv2Dcqcn import RoCEv2Dcqcn

class RoCEv2Engine(pr.Device):
    def __init__( self,
                  dcqcn = True,
                  **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name        = 'SendMetaData',
            description = 'Trigger sending RoCE metadata to the remote peer',
            offset      = 0xF00,
            bitSize     = 1,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MetaDataTx',
            description = 'RoCE transmit metadata payload for queue pair setup',
            offset      = 0xF04,
            bitSize     = 303,
            mode        = 'RW',
        ))


        self.add(pr.RemoteVariable(
            name        = 'RecvMetaData',
            description = 'Indicates received RoCE metadata is available',
            offset      = 0xF00,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MetaDataRx',
            description = 'RoCE received metadata payload from remote peer',
            offset      = 0xF2C,
            bitSize     = 276,
            mode        = 'RO',
        ))

        self.add(pr.RemoteCommand(
            name        = 'SoftReset',
            description = 'Soft-reset the RoCE transport core to clear stale QP/PSN '
                          'state from a prior session (without disturbing the '
                          'RUDP/UDP link). Pulse before re-establishing a QP.',
            offset      = 0xF50,
            bitSize     = 1,
            bitOffset   = 0,
            function    = pr.RemoteCommand.toggle,
        ))

        if dcqcn:
            self.add(RoCEv2Dcqcn(
                name   = "Dcqcn",
                offset = 0x1000,
                expand = False,
            ))
