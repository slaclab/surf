#-----------------------------------------------------------------------------
# Title      : PyRogue RoceMetaDataAxil
#-----------------------------------------------------------------------------
# Description:
# PyRogue register map for out/04-vhdl/RoceMetaDataAxil.vhd — the AXI-Lite
# bridge to the RoCEv2 TransportLayer MetaData server (also instanced inside
# out/04-vhdl/TransportLayerAxi.vhd on its axil* ports).
#
# BSV struct refs: src-bsv/MetaData.bsv (MetaDataReq/Resp, ReqPD/RespPD,
# ReqMR/RespMR), src-bsv/Controller.bsv (ReqQP/RespQP), src-bsv/DataTypes.bsv
# (AttrQP, QpCapacity, QpInitAttr).
#
# Protocol: program the request bank selected by Control.ReqType, then issue
# Go (single write to CONTROL; GO self-clears). Busy rises until the response
# is captured; Done then rises (cleared on the next accepted Go) and
# mdDoneIrq pulses one clock. Go while Busy is ignored and sets the sticky
# Err bit (cleared on the next accepted Go). Poll Done, then check
# RespSuccess and read the Resp* bank.
#-----------------------------------------------------------------------------

import pyrogue as pr


class RoceMetaDataAxil(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        ##############################
        # Control / status (0x000)
        ##############################

        self.add(pr.RemoteVariable(
            name        = 'ReqType',
            description = 'Request bank issued by Go (CONTROL[2:1])',
            offset      = 0x000,
            bitSize     = 2,
            bitOffset   = 1,
            base        = pr.UInt,
            mode        = 'RW',
            enum        = {
                0: 'PD',
                1: 'MR',
                2: 'QP',
            },
        ))

        self.add(pr.RemoteCommand(
            name        = 'Go',
            description = 'Issue the request selected by ReqType (CONTROL[0], self-clearing strobe)',
            offset      = 0x000,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.UInt,
            # toggle (1 then 0), NOT touchOne: GO shares the CONTROL word with
            # ReqType. touchOne leaves the staged block bit at 1, so any later
            # ReqType.set() block write would re-fire GO with the stale bank
            # (double-issues every request; the duplicate QP CREATE then fails
            # at MAX_QP_G=1). toggle stages the bit back to 0 after the strobe.
            function    = pr.RemoteCommand.toggle,
        ))

        self.add(pr.RemoteVariable(
            name         = 'Done',
            description  = 'Response captured (cleared on the next accepted Go)',
            offset       = 0x004,
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.Bool,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'Busy',
            description  = 'Request in flight',
            offset       = 0x004,
            bitSize      = 1,
            bitOffset    = 1,
            base         = pr.Bool,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'Err',
            description  = 'Sticky: Go was issued while Busy (that Go was ignored)',
            offset       = 0x004,
            bitSize      = 1,
            bitOffset    = 2,
            base         = pr.Bool,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name        = 'RespTag',
            description = 'Tag of the captured response (STATUS[4:3])',
            offset      = 0x004,
            bitSize     = 2,
            bitOffset   = 3,
            base        = pr.UInt,
            mode        = 'RO',
            enum        = {
                0: 'PD',
                1: 'MR',
                2: 'QP',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'RespSuccess',
            description = 'Captured response success flag (STATUS[5])',
            offset      = 0x004,
            bitSize     = 1,
            bitOffset   = 5,
            base        = pr.Bool,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Version',
            description = 'Bridge version (VERSION[7:0])',
            offset      = 0x008,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxQp',
            description = 'MAX_QP_G generic readback (VERSION[15:8])',
            offset      = 0x008,
            bitSize     = 8,
            bitOffset   = 8,
            base        = pr.UInt,
            mode        = 'RO',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Scratch',
            description = 'Scratchpad register',
            offset      = 0x00C,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        ##############################
        # PD request bank (ReqPD, 0x100)
        ##############################

        self.add(pr.RemoteVariable(
            name        = 'PdAllocOrNot',
            description = 'ReqPD.allocOrNot: 1 = allocate PD, 0 = deallocate',
            offset      = 0x100,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.Bool,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'PdKey',
            description = 'ReqPD.pdKey',
            offset      = 0x104,
            bitSize     = 31,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'PdHandler',
            description = 'ReqPD.pdHandler (for deallocate)',
            offset      = 0x108,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        ##############################
        # MR request bank (ReqMR, 0x200)
        ##############################

        self.add(pr.RemoteVariable(
            name        = 'MrAllocOrNot',
            description = 'ReqMR.allocOrNot: 1 = register MR, 0 = deregister',
            offset      = 0x200,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.Bool,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MrLkeyOrNot',
            description = 'ReqMR.lkeyOrNot',
            offset      = 0x200,
            bitSize     = 1,
            bitOffset   = 1,
            base        = pr.Bool,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MrLAddr',
            description = 'ReqMR.laddr (64-bit, spans 0x204 LO / 0x208 HI)',
            offset      = 0x204,
            bitSize     = 64,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MrLen',
            description = 'ReqMR.len',
            offset      = 0x20C,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MrAccFlags',
            description = 'ReqMR.accFlags (IBV access flags)',
            offset      = 0x210,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MrPdHandler',
            description = 'ReqMR.pdHandler',
            offset      = 0x214,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MrLkeyPart',
            description = 'ReqMR.lkeyPart (key material for the allocated lkey)',
            offset      = 0x218,
            bitSize     = 25,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MrRkeyPart',
            description = 'ReqMR.rkeyPart (key material for the allocated rkey)',
            offset      = 0x21C,
            bitSize     = 25,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MrLkey',
            description = 'ReqMR.lkey (for deregister)',
            offset      = 0x220,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MrRkey',
            description = 'ReqMR.rkey (for deregister)',
            offset      = 0x224,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        ##############################
        # QP request bank (ReqQP, 0x300)
        ##############################

        self.add(pr.RemoteVariable(
            name        = 'QpReqType',
            description = 'ReqQP.qpReqType (QP_CTRL[1:0])',
            offset      = 0x300,
            bitSize     = 2,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
            enum        = {
                0: 'Create',
                1: 'Destroy',
                2: 'Modify',
                3: 'Query',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpState',
            description = 'AttrQP.qpState, target state for MODIFY (IBV encoding; QP_CTRL[5:2])',
            offset      = 0x300,
            bitSize     = 4,
            bitOffset   = 2,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpPmtu',
            description = 'AttrQP.pmtu (IBV encoding; QP_CTRL[8:6])',
            offset      = 0x300,
            bitSize     = 3,
            bitOffset   = 6,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpType',
            description = 'QpInitAttr.qpType (IBV encoding, RC=2; QP_CTRL[12:9])',
            offset      = 0x300,
            bitSize     = 4,
            bitOffset   = 9,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpSqSigAll',
            description = 'QpInitAttr.sqSigAll (QP_CTRL[13])',
            offset      = 0x300,
            bitSize     = 1,
            bitOffset   = 13,
            base        = pr.Bool,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpPdHandler',
            description = 'ReqQP.pdHandler',
            offset      = 0x304,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpQpn',
            description = 'ReqQP.qpn (queue pair number to operate on)',
            offset      = 0x308,
            bitSize     = 24,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpAttrMask',
            description = 'ReqQP.qpAttrMask (IBV attribute mask for MODIFY)',
            offset      = 0x30C,
            bitSize     = 26,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpQkey',
            description = 'AttrQP.qkey',
            offset      = 0x310,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpRqPsn',
            description = 'AttrQP.rqPSN (expected receive PSN)',
            offset      = 0x314,
            bitSize     = 24,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpSqPsn',
            description = 'AttrQP.sqPSN (send queue PSN)',
            offset      = 0x318,
            bitSize     = 24,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpDqpn',
            description = 'AttrQP.dqpn (destination QPN)',
            offset      = 0x31C,
            bitSize     = 24,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpAccessFlags',
            description = 'AttrQP.qpAccessFlags (IBV access flags)',
            offset      = 0x320,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpPkeyIndex',
            description = 'AttrQP.pkeyIndex',
            offset      = 0x324,
            bitSize     = 16,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpMaxRdAtomic',
            description = 'AttrQP.maxReadAtomic (outstanding as requester)',
            offset      = 0x328,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpMaxDestRdAtomic',
            description = 'AttrQP.maxDestReadAtomic (outstanding as responder)',
            offset      = 0x32C,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpMinRnrTimer',
            description = 'AttrQP.minRnrTimer (IBV RNR NAK timer encoding)',
            offset      = 0x330,
            bitSize     = 5,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpTimeout',
            description = 'AttrQP.timeout (IBV local ACK timeout encoding)',
            offset      = 0x334,
            bitSize     = 5,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpRetryCnt',
            description = 'AttrQP.retryCnt (transport retry count)',
            offset      = 0x338,
            bitSize     = 3,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpRnrRetry',
            description = 'AttrQP.rnrRetry (RNR retry count, 7 = infinite)',
            offset      = 0x33C,
            bitSize     = 3,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpCurState',
            description = 'AttrQP.curQpState (current state hint for MODIFY)',
            offset      = 0x340,
            bitSize     = 4,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpMaxSendWr',
            description = 'QpCapacity.maxSendWR',
            offset      = 0x344,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpMaxRecvWr',
            description = 'QpCapacity.maxRecvWR',
            offset      = 0x348,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpMaxSendSge',
            description = 'QpCapacity.maxSendSGE',
            offset      = 0x34C,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpMaxRecvSge',
            description = 'QpCapacity.maxRecvSGE',
            offset      = 0x350,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpMaxInlineData',
            description = 'QpCapacity.maxInlineData',
            offset      = 0x354,
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'QpSqDraining',
            description = 'AttrQP.sqDraining',
            offset      = 0x358,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.Bool,
            mode        = 'RW',
        ))

        ##############################
        # Response bank (RO, 0x400; captured on completion)
        ##############################

        self.add(pr.RemoteVariable(
            name        = 'RespStatusSuccess',
            description = 'Captured response success (mirrors STATUS[5])',
            offset      = 0x400,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.Bool,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RespStatusTag',
            description = 'Captured response tag (mirrors STATUS[4:3])',
            offset      = 0x400,
            bitSize     = 2,
            bitOffset   = 1,
            base        = pr.UInt,
            mode        = 'RO',
            enum        = {
                0: 'PD',
                1: 'MR',
                2: 'QP',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'RespPdHandler',
            description = 'RespPD.pdHandler (allocated PD handle)',
            offset      = 0x404,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RespPdKey',
            description = 'RespPD.pdKey echo',
            offset      = 0x408,
            bitSize     = 31,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RespMrLkey',
            description = 'RespMR.lkey (allocated local key)',
            offset      = 0x40C,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RespMrRkey',
            description = 'RespMR.rkey (allocated remote key)',
            offset      = 0x410,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'RespQpQpn',
            description = 'RespQP.qpn (created queue pair number)',
            offset      = 0x414,
            bitSize     = 24,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))
