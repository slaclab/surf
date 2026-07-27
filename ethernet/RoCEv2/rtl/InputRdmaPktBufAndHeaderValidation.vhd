-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   12-stage concurrent dataflow pipeline. Each BSV rule is one stage; stages
--   are joined by FIFO pairs — one rdmaHeader*Q carrying the per-packet header
--   tuple (advanced once per packet, on isFirst/isLast), one payload*Q carrying
--   each DataStream fragment (advanced once per fragment). All 12 stage rules
--   are BSV `conflict_free`: emitted as independent `if (guard) then ...` blocks
--   in the comb process — NO elsif precedence between stages. Every stage's
--   guard is "input FIFO(s) notEmpty AND output FIFO(s) notFull" (conditional
--   FIFO writes contribute their notFull only on the path that writes them —
--   BSV conditional implicit conditions).
--
--   Genuine sequential control (only two pieces):
--     1. pktBufState (2-state FSM, PRE_CHECK_FRAG_S / DISCARD_FRAG_S) —
--        owned by preCheckHeader (→ DISCARD) and discardInvalidFrag (→ PRE_CHECK);
--        drains the payload fragments of a packet whose header failed pre-check.
--     2. Per-packet accumulator regs (isValidPkt, bthPadCnt, pktFragNum, pktLen,
--        pktValid): set on isFirst, carried across mid frags, consumed on isLast.
--        All BSV mkRegU (no reset) — given defined REG_INIT_C=0 here (re-armed on
--        each packet's isFirst fragment; see "Reset behaviour" below).
--
--   RESOLVED open questions applied:
--     - OQ-FSM-IRPB-01: Stage-1 inventory / Stage-2 mapping.json rows for this
--       entity describe a DIFFERENT module (wrong rules/FIFOs/state/children).
--       The .fsm.md (derived from BSV source, authoritative per CLAUDE.md) is the
--       sole basis for this emit. mapping.json was NOT consulted for structure.
--     - OQ-FSM-IRPB-02 (user-confirmed 2026-07-01; REVISED after Stage-5 TC-08):
--       recvPktFrag and discardInvalidFrag both deq the single payloadPipeIn in
--       BSV under `conflict_free`. The first emit gated recvPktFrag on
--       PRE_CHECK_FRAG_S; that RACED at the PRE_CHECK→DISCARD boundary — on the
--       cycle preCheckHeader set DISCARD, r.pktBufState was still PRE_CHECK, so
--       recvPktFrag also fired and pulled the fragment after isFirst into
--       payloadRecvQ before the gate engaged, desynchronizing the header/payload
--       queues and DROPPING valid packets that followed a discarded multi-frag
--       packet (Stage-5 TC-08 fail).  FIX: recvPktFrag is the SOLE payloadPipeIn
--       consumer and ALWAYS runs (matches the fsm.md "recvPktFrag keeps
--       running"); the invalid-fragment drain is moved off payloadPipeIn onto
--       payloadRecvQ, so discardInvalidFrag drains payloadRecvQ (downstream of
--       recvPktFrag) while in DISCARD_FRAG_S.  No two rules ever deq
--       payloadPipeIn → the race is eliminated and every fragment of an invalid
--       multi-fragment packet is dropped in order (f0 by preCheckHeader, the
--       rest by discardInvalidFrag), with subsequent packets processed cleanly.
--     - OQ-FSM-IRPB-03: qpMetaData (MetaDataQPs) combinational lookups modelled
--       as explicit request/response ports (CntrlQp method-explosion precedent):
--         getPD(dqpn)            → getPdQpn out; getPdMaybeValid + getPdHandler in
--         getQueuePairByQPN(dqpn)→ getQpQpn out; sq*/rq* CntrlStatus fields in
--       (only the subset validateHeader + the pmtu read touch). Request qpns are
--       driven combinationally from the pipeline FIFO heads; the provider
--       mkMetaDataQPs / parent TransportLayer must match this contract at emit.
--     - OQ-FSM-H2DS-02: DataStream = 290 bits.  OQ-FSM-H2DS-04: BSV deriving(Bits)
--       is first-field-at-MSB (all struct/tuple slicing below follows it).
--
--   Widths traced (Headers.bsv / DataTypes.bsv / Settings.bsv):
--     HeaderRDMA 593, DataStream 290, BTH 96, AETH 32, DETH 64, XRCETH 32,
--     QPN/PSN 24, QKEY/HandlerPD 32, PAD 2, PktFragNum 8, PktLen 13,
--     ByteEnBitNum 6, TransType 3, RdmaOpCode 5, PMTU 3, TypeQP 4,
--     IndexQP log2(MAX_QP_G) (getIndexQP = truncateLSB(qpn): top log2(MAX_QP_G)
--     bits of the 24-bit QPN, i.e. qpn(23 downto 24-log2(MAX_QP_G));
--     2 bits at the default MAX_QP_G=4), PktVeriStatus 1.
--     RdmaPktMetaData 649, HeaderValidateInfo 94, ValidHeaderInfo 65,
--     PktLenCheckInfo 710.
--
--   Bit layouts (first-field-at-MSB):
--     DataStream(290) : [289:34]data [33:2]byteEn [1]isFirst [0]isLast
--     HeaderRDMA(593) : [592:81]headerData(512) [80:17]headerByteEn(64)
--                       [16:10]headerLen [9:8]headerFragNum
--                       [7:2]lastFragValidByteNum [1]hasPayload [0]isEmptyHeader
--     BTH(96)         : [95:93]trans [92:88]opcode [87]solicited [86]migReq
--                       [85:84]padCnt [83:80]tver [79:64]pkey [63]fecn [62]becn
--                       [61:56]resv6 [55:32]dqpn [31]ackReq [30:24]resv7 [23:0]psn
--       (bth = headerData top 96 = rdmaHeader[592:497])
--     AETH(32) rel.   : [31]rsvd [30:29]code [28:24]value [23:0]msn
--       (aeth = headerData[415:384] = rdmaHeader[496:465];
--        aethCode = rdmaHeader[495:494], aethValue = rdmaHeader[493:489])
--     DETH.qkey = rdmaHeader[496:465]   XRCETH.srqn = rdmaHeader[488:465]
--
--   SURF components instantiated (all surf.Fifo, FWFT + sync + RST_POLARITY_G='1',
--   RST_ASYNC_G=false — source surf/base/fifo/rtl/Fifo.vhd):
--     18 internal scalar pipeline FIFOs (U_RdmaHeaderRecvQ … U_PayloadOutputQ),
--     5 output FIFO vectors x MAX_QP_G (U_CnpOutVec, U_ReqPayloadOutVec,
--       U_ReqPktMetaDataOutVec, U_RespPayloadOutVec, U_RespPktMetaDataOutVec),
--     U_PayloadPipeIn (BSV mkBuffer = mkPipelineFIFOF, 1-deep skid on the payload
--       input; precedent ExtractHeaderFromRdmaPktPipeOut U_HeaderMetaDataBuf).
--   Child entity (NOT SURF):
--     U_RdmaHeaderPipeOut : entity work.DataStream2Header
--       (BSV mkDataStream2Header) — re-accumulates HeaderRDMA per packet from the
--       header DataStream + HeaderMetaData input pipes.
--
--   Reset behaviour: pktBufState → PRE_CHECK_FRAG_S (BSV mkReg). Accumulators are
--   BSV mkRegU (no reset) — set to 0 in REG_INIT_C; functionally re-armed on each
--   packet's isFirst fragment. All surf.Fifo reset via rst (empty).
--
--   NOTE: emitting does not prove equivalence. This entity MUST be simulated
--   (Stage 5) before it is trusted.
--
--   DEVIATION-IRPB-04 (2026-07-21): strip RoCE pad bytes from the last payload
--   fragment before forwarding it to the QP payload pipe.  The packet-length
--   accumulator already subtracted BTH.padCnt, but the original DataStream
--   byteEn (which includes the 0..3 wire pad bytes) was forwarded unchanged.
--   Consequently a 1-byte SEND produced a 4-byte DMA write.  Rule 8 now
--   regenerates the last fragment's byteEn from fragLenNoPad; data bits stay
--   unchanged because disabled lanes are don't-care.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;

entity InputRdmaPktBufAndHeaderValidation is
   generic (
      TPD_G    : time     := 1 ns;
      MAX_QP_G : positive := 4;  -- any power of 2, >= 2 (IndexQP = log2(MAX_QP_G) bits)
      EN_TX_G  : boolean  := true;  -- false = no requester: skip resp-stream output FIFOs
      EN_RX_G  : boolean  := true);  -- false = no responder: skip req-stream output FIFOs
                                      -- (skipped direction: notFull tied '1' => packets drop here)
   port (
      clk : in sl;
      rst : in sl;                      -- active-high synchronous reset

      -- Input: payload DataStream pipe (pipeIn.payload) → U_PayloadPipeIn buffer
      payloadPipeInValid : in  sl;
      payloadPipeInData  : in  slv(289 downto 0);
      payloadPipeInRdEn  : out sl;

      -- Input: header DataStream pipe (pipeIn.headerAndMetaData.headerDataStream)
      --        → child U_RdmaHeaderPipeOut.dataPipeIn
      headerDataStreamValid : in  sl;
      headerDataStreamData  : in  slv(289 downto 0);
      headerDataStreamRdEn  : out sl;

      -- Input: header metadata pipe (pipeIn.headerAndMetaData.headerMetaData)
      --        → child U_RdmaHeaderPipeOut.hdrMetaDataPipeIn
      headerMetaDataValid : in  sl;
      headerMetaDataData  : in  slv(16 downto 0);
      headerMetaDataRdEn  : out sl;

      -- qpMetaData combinational lookup: getPD(dqpn)  (prepareValidation)
      getPdQpn        : out slv(23 downto 0);
      getPdMaybeValid : in  sl;
      getPdHandler    : in  slv(31 downto 0);

      -- qpMetaData combinational lookup: getQueuePairByQPN(dqpn) (checkMetaDataQP)
      getQpQpn   : out slv(23 downto 0);
      sqTypeQP   : in  slv(3 downto 0);
      sqIsERR    : in  sl;
      sqIsRTS    : in  sl;
      sqIsNonErr : in  sl;
      sqQKEY     : in  slv(31 downto 0);
      sqPMTU     : in  slv(2 downto 0);
      rqTypeQP   : in  slv(3 downto 0);
      rqIsERR    : in  sl;
      rqIsRTS    : in  sl;
      rqIsNonErr : in  sl;
      rqQKEY     : in  slv(31 downto 0);

      -- Output vectors (x MAX_QP_G), flattened. Each PipeOut: Valid out/Dout out/RdEn in
      reqPktMetaDataValid  : out slv(MAX_QP_G-1 downto 0);
      reqPktMetaDataDout   : out slv(MAX_QP_G*649-1 downto 0);
      reqPktMetaDataRdEn   : in  slv(MAX_QP_G-1 downto 0);
      reqPayloadValid      : out slv(MAX_QP_G-1 downto 0);
      reqPayloadDout       : out slv(MAX_QP_G*290-1 downto 0);
      reqPayloadRdEn       : in  slv(MAX_QP_G-1 downto 0);
      respPktMetaDataValid : out slv(MAX_QP_G-1 downto 0);
      respPktMetaDataDout  : out slv(MAX_QP_G*649-1 downto 0);
      respPktMetaDataRdEn  : in  slv(MAX_QP_G-1 downto 0);
      respPayloadValid     : out slv(MAX_QP_G-1 downto 0);
      respPayloadDout      : out slv(MAX_QP_G*290-1 downto 0);
      respPayloadRdEn      : in  slv(MAX_QP_G-1 downto 0);
      cnpValid             : out slv(MAX_QP_G-1 downto 0);
      cnpDout              : out slv(MAX_QP_G*96-1 downto 0);
      cnpRdEn              : in  slv(MAX_QP_G-1 downto 0));
end entity InputRdmaPktBufAndHeaderValidation;

architecture rtl of InputRdmaPktBufAndHeaderValidation is

   ---------------------------------------------------------------------------
   -- Width constants
   ---------------------------------------------------------------------------
   constant HDR_W_C       : integer          := 593;  -- HeaderRDMA
   constant DS_W_C        : integer          := 290;  -- DataStream
   constant BTH_W_C       : integer          := 96;   -- BTH
   constant HVI_W_C       : integer          := 94;   -- HeaderValidateInfo
   constant VHI_W_C       : integer          := 65;   -- ValidHeaderInfo
   constant PLCI_W_C      : integer          := 710;  -- PktLenCheckInfo
   constant META_W_C      : integer          := 649;  -- RdmaPktMetaData
   constant ADDR_W_C      : integer          := 4;  -- FIFO depth 2**4 = 16 (mkFIFOF skid)
   constant QP_IDX_W_C    : positive         := log2(MAX_QP_G);  -- IndexQP = TLog#(MAX_QP) (2 at MAX_QP_G=4)
   constant BYTEEN_ONES_C : slv(31 downto 0) := (others => '1');  -- isAllOnesR(byteEn)

   -- Tuple / element widths
   constant RECV_W_C   : integer := HDR_W_C + BTH_W_C + 3;  -- 692 rdmaHeaderRecvQ
   constant PRECHK_W_C : integer := HDR_W_C + BTH_W_C;  -- 689 rdmaHeaderPreCheckQ
   constant VALID_W_C  : integer := HDR_W_C + BTH_W_C + HVI_W_C;  -- 783 rdmaHeaderValidationQ
   constant FILT_W_C   : integer := HDR_W_C + BTH_W_C + VHI_W_C;  -- 754 filter/fragLen/pktLenCalc header Qs
   constant PLC_W_C    : integer := DS_W_C + 6 + 6 + 2;  -- 304 payloadPktLenCalcQ
   constant PCHK4_W_C  : integer := PLCI_W_C + 3;  -- 713 rdmaHeaderPktLenCheckQ
   constant PL3_W_C    : integer := DS_W_C + QP_IDX_W_C + 1;  -- 293 @MAX_QP_G=4; payload {frag,qpIndex,isRespPkt}
   constant HDROUT_W_C : integer := META_W_C + QP_IDX_W_C + 1;  -- 652 @MAX_QP_G=4; rdmaHeaderOutputQ {meta,qpIndex,isRespPkt}

   ---------------------------------------------------------------------------
   -- RdmaOpCode (5-bit) constants
   ---------------------------------------------------------------------------
   constant SEND_FIRST_C                     : slv(4 downto 0) := "00000";
   constant SEND_MIDDLE_C                    : slv(4 downto 0) := "00001";
   constant SEND_LAST_C                      : slv(4 downto 0) := "00010";
   constant SEND_LAST_WITH_IMMEDIATE_C       : slv(4 downto 0) := "00011";
   constant SEND_ONLY_C                      : slv(4 downto 0) := "00100";
   constant SEND_ONLY_WITH_IMMEDIATE_C       : slv(4 downto 0) := "00101";
   constant RDMA_WRITE_FIRST_C               : slv(4 downto 0) := "00110";
   constant RDMA_WRITE_MIDDLE_C              : slv(4 downto 0) := "00111";
   constant RDMA_WRITE_LAST_C                : slv(4 downto 0) := "01000";
   constant RDMA_WRITE_LAST_WITH_IMMEDIATE_C : slv(4 downto 0) := "01001";
   constant RDMA_WRITE_ONLY_C                : slv(4 downto 0) := "01010";
   constant RDMA_WRITE_ONLY_WITH_IMMEDIATE_C : slv(4 downto 0) := "01011";
   constant RDMA_READ_REQUEST_C              : slv(4 downto 0) := "01100";
   constant RDMA_READ_RESPONSE_FIRST_C       : slv(4 downto 0) := "01101";
   constant RDMA_READ_RESPONSE_MIDDLE_C      : slv(4 downto 0) := "01110";
   constant RDMA_READ_RESPONSE_LAST_C        : slv(4 downto 0) := "01111";
   constant RDMA_READ_RESPONSE_ONLY_C        : slv(4 downto 0) := "10000";
   constant ACKNOWLEDGE_C                    : slv(4 downto 0) := "10001";
   constant ATOMIC_ACKNOWLEDGE_C             : slv(4 downto 0) := "10010";
   constant COMPARE_SWAP_C                   : slv(4 downto 0) := "10011";
   constant FETCH_ADD_C                      : slv(4 downto 0) := "10100";
   constant SEND_LAST_WITH_INVALIDATE_C      : slv(4 downto 0) := "10110";
   constant SEND_ONLY_WITH_INVALIDATE_C      : slv(4 downto 0) := "10111";

   -- TransType (3-bit)
   constant TRANS_TYPE_RC_C  : slv(2 downto 0) := "000";
   constant TRANS_TYPE_UC_C  : slv(2 downto 0) := "001";
   constant TRANS_TYPE_UD_C  : slv(2 downto 0) := "011";
   constant TRANS_TYPE_CNP_C : slv(2 downto 0) := "100";
   constant TRANS_TYPE_XRC_C : slv(2 downto 0) := "101";

   -- TypeQP (4-bit, deriving(Bits) integer encodings)
   constant IBV_QPT_RC_C       : slv(3 downto 0) := x"2";
   constant IBV_QPT_UC_C       : slv(3 downto 0) := x"3";
   constant IBV_QPT_UD_C       : slv(3 downto 0) := x"4";
   constant IBV_QPT_XRC_SEND_C : slv(3 downto 0) := x"9";
   constant IBV_QPT_XRC_RECV_C : slv(3 downto 0) := x"A";

   -- PMTU (3-bit)
   constant IBV_MTU_256_C  : slv(2 downto 0) := "001";
   constant IBV_MTU_512_C  : slv(2 downto 0) := "010";
   constant IBV_MTU_1024_C : slv(2 downto 0) := "011";
   constant IBV_MTU_2048_C : slv(2 downto 0) := "100";
   constant IBV_MTU_4096_C : slv(2 downto 0) := "101";

   -- AETH code (2-bit) / NAK value (5-bit)
   constant AETH_CODE_ACK_C    : slv(1 downto 0) := "00";
   constant AETH_CODE_RNR_C    : slv(1 downto 0) := "01";
   constant AETH_CODE_NAK_C    : slv(1 downto 0) := "11";
   constant AETH_NAK_SEQ_ERR_C : slv(4 downto 0) := "00000";
   constant AETH_NAK_INV_REQ_C : slv(4 downto 0) := "00001";
   constant AETH_NAK_RMT_ACC_C : slv(4 downto 0) := "00010";
   constant AETH_NAK_RMT_OP_C  : slv(4 downto 0) := "00011";
   constant AETH_NAK_INV_RD_C  : slv(4 downto 0) := "00100";

   -- {trans,opcode} congestion-notification marker (ROCE_CNP = 8'h81)
   constant ROCE_CNP_C : slv(7 downto 0) := x"81";

   -- PktVeriStatus (1-bit): PKT_ST_VALID=0, PKT_ST_LEN_ERR=1
   constant PKT_ST_VALID_C   : sl := '0';
   constant PKT_ST_LEN_ERR_C : sl := '1';

   ---------------------------------------------------------------------------
   -- Helper functions (faithful to Utils.bsv / Headers.bsv / InputPktHandle.bsv)
   ---------------------------------------------------------------------------
   type FragByteNumType is record
      valid : sl;
      num   : slv(5 downto 0);          -- ByteEnBitNum
   end record;

   function isFirstOp (op : slv(4 downto 0)) return boolean is
   begin
      case op is
         when SEND_FIRST_C | RDMA_WRITE_FIRST_C | RDMA_READ_RESPONSE_FIRST_C => return true;
         when others                                                         => return false;
      end case;
   end function;

   function isMiddleOp (op : slv(4 downto 0)) return boolean is
   begin
      case op is
         when SEND_MIDDLE_C | RDMA_WRITE_MIDDLE_C | RDMA_READ_RESPONSE_MIDDLE_C => return true;
         when others                                                            => return false;
      end case;
   end function;

   function isLastOp (op : slv(4 downto 0)) return boolean is
   begin
      case op is
         when SEND_LAST_C | SEND_LAST_WITH_IMMEDIATE_C | SEND_LAST_WITH_INVALIDATE_C |
              RDMA_WRITE_LAST_C | RDMA_WRITE_LAST_WITH_IMMEDIATE_C |
              RDMA_READ_RESPONSE_LAST_C => return true;
         when others => return false;
      end case;
   end function;

   function isOnlyOp (op : slv(4 downto 0)) return boolean is
   begin
      case op is
         when SEND_ONLY_C | SEND_ONLY_WITH_IMMEDIATE_C | SEND_ONLY_WITH_INVALIDATE_C |
              RDMA_WRITE_ONLY_C | RDMA_WRITE_ONLY_WITH_IMMEDIATE_C |
              RDMA_READ_REQUEST_C | COMPARE_SWAP_C | FETCH_ADD_C |
              RDMA_READ_RESPONSE_ONLY_C | ACKNOWLEDGE_C | ATOMIC_ACKNOWLEDGE_C => return true;
         when others => return false;
      end case;
   end function;

   function isFirstOrMidOp (op : slv(4 downto 0)) return boolean is
   begin return isFirstOp(op) or isMiddleOp(op); end function;

   function isLastOrOnlyOp (op : slv(4 downto 0)) return boolean is
   begin return isLastOp(op) or isOnlyOp(op); end function;

   function isRdmaRespOp (op : slv(4 downto 0)) return boolean is
   begin
      case op is
         when RDMA_READ_RESPONSE_FIRST_C | RDMA_READ_RESPONSE_MIDDLE_C |
              RDMA_READ_RESPONSE_LAST_C | RDMA_READ_RESPONSE_ONLY_C |
              ACKNOWLEDGE_C | ATOMIC_ACKNOWLEDGE_C => return true;
         when others => return false;
      end case;
   end function;

   -- checkZeroFields4BTH: tver, fecn, becn, resv6, resv7 all zero (migReq NOT checked)
   function checkZeroFields4BTH (bth : slv(95 downto 0)) return boolean is
      variable ecnOk : boolean;
   begin
      -- FECN/BECN must be clear except on a CNP ({trans,op} = ROCE_CNP 0x81),
      -- which carries BECN=1 by definition (RoCEv2 Annex A17.9.3); requiring
      -- becn=0 there would discard every CNP before the CNP fork in Rule 6.
      if bth(95 downto 88) = ROCE_CNP_C then
         ecnOk := true;
      else
         ecnOk := (bth(63) = '0')              -- fecn
                  and (bth(62) = '0');         -- becn
      end if;
      return (bth(83 downto 80) = "0000")      -- tver
         and ecnOk
         and (bth(61 downto 56) = "000000")    -- resv6
         and (bth(30 downto 24) = "0000000");  -- resv7
   end function;

   -- padCntCheckReqHeader(bth): opcode/padCnt LUT
   function padCntCheckReqHeader (op : slv(4 downto 0); padCnt : slv(1 downto 0)) return boolean is
      variable zeroPad : boolean;
   begin
      zeroPad := (padCnt = "00");
      case op is
         when SEND_FIRST_C | SEND_MIDDLE_C => return zeroPad;
         when SEND_LAST_C | SEND_ONLY_C |
              SEND_LAST_WITH_IMMEDIATE_C | SEND_ONLY_WITH_IMMEDIATE_C |
              SEND_LAST_WITH_INVALIDATE_C | SEND_ONLY_WITH_INVALIDATE_C => return true;
         when RDMA_WRITE_FIRST_C | RDMA_WRITE_MIDDLE_C => return zeroPad;
         when RDMA_WRITE_LAST_C | RDMA_WRITE_ONLY_C |
              RDMA_WRITE_LAST_WITH_IMMEDIATE_C | RDMA_WRITE_ONLY_WITH_IMMEDIATE_C => return true;
         when RDMA_READ_REQUEST_C | COMPARE_SWAP_C | FETCH_ADD_C => return zeroPad;
         when others                                             => return false;
      end case;
   end function;

   -- padCntCheckRespHeader(bth, aeth): opcode + AETH code/value LUT
   function padCntCheckRespHeader (op       : slv(4 downto 0);
                                   padCnt   : slv(1 downto 0);
                                   aethCode : slv(1 downto 0);
                                   aethVal  : slv(4 downto 0)) return boolean is
      variable zeroPad : boolean;
   begin
      zeroPad := (padCnt = "00");
      case op is
         when RDMA_READ_RESPONSE_MIDDLE_C =>
            return zeroPad;
         when RDMA_READ_RESPONSE_LAST_C | RDMA_READ_RESPONSE_ONLY_C =>
            return (aethCode = AETH_CODE_ACK_C);
         when RDMA_READ_RESPONSE_FIRST_C | ATOMIC_ACKNOWLEDGE_C =>
            return (aethCode = AETH_CODE_ACK_C) and zeroPad;
         when ACKNOWLEDGE_C =>
            if (aethCode = AETH_CODE_ACK_C) or (aethCode = AETH_CODE_RNR_C) then
               return zeroPad;
            elsif (aethCode = AETH_CODE_NAK_C) then
               case aethVal is
                  when AETH_NAK_SEQ_ERR_C | AETH_NAK_INV_REQ_C | AETH_NAK_RMT_ACC_C |
                       AETH_NAK_RMT_OP_C | AETH_NAK_INV_RD_C => return zeroPad;
                  when others => return false;
               end case;
            else
               return false;            -- AETH_CODE_RSVD / others
            end if;
         when others => return false;
      end case;
   end function;

   -- isCongestionNotificationPkt(bth) = {trans,opcode} == ROCE_CNP
   function isCnp (trans : slv(2 downto 0); op : slv(4 downto 0)) return boolean is
   begin
      return ((trans & op) = ROCE_CNP_C);
   end function;

   -- transTypeMatchQpType(tt, qpt, isRecvSide)
   function transTypeMatchQpType (tt         : slv(2 downto 0); qpt : slv(3 downto 0);
                                  isRecvSide : sl) return boolean is
   begin
      case tt is
         when TRANS_TYPE_CNP_C => return true;
         when TRANS_TYPE_RC_C  => return (qpt = IBV_QPT_RC_C);
         when TRANS_TYPE_UC_C  => return (qpt = IBV_QPT_UC_C);
         when TRANS_TYPE_UD_C  => return (qpt = IBV_QPT_UD_C);
         when TRANS_TYPE_XRC_C =>
            return ((isRecvSide = '0') and (qpt = IBV_QPT_XRC_RECV_C))
               or ((isRecvSide = '1') and (qpt = IBV_QPT_XRC_SEND_C));
         when others => return false;
      end case;
   end function;

   -- validateHeader(transType, qkey, cntrlStatus, isRespPkt)
   function validateHeader (transType                                : slv(2 downto 0);
                            qkey                                     : slv(31 downto 0);
                            qpType                                   : slv(3 downto 0);
                            statusIsERR, statusIsRTS, statusIsNonErr : sl;
                            statusQKEY                               : slv(31 downto 0);
                            isRespPkt                                : sl) return boolean is
      variable transTypeMatch, qpStateMatch, qKeyMatch : boolean;
   begin
      transTypeMatch := transTypeMatchQpType(transType, qpType, isRespPkt);
      if statusIsERR = '1' then
         qpStateMatch := true;
      elsif isRespPkt = '1' then
         qpStateMatch := (statusIsRTS = '1');
      else
         qpStateMatch := (statusIsNonErr = '1');
      end if;
      if transType = TRANS_TYPE_UD_C then
         qKeyMatch := (qkey = statusQKEY);
      else
         qKeyMatch := true;
      end if;
      return transTypeMatch and qpStateMatch and qKeyMatch;
   end function;

   -- calcFragByteNumFromByteEn(byteEn): reverse, find idx in {0,4,..,32} where
   -- reversed == (1<<idx)-1.  Returns Valid idx (largest match) else Invalid.
   function calcFragByteNum (byteEn : slv(31 downto 0)) return FragByteNumType is
      variable rev : slv(31 downto 0);
      variable m   : unsigned(32 downto 0);
      variable cmp : slv(31 downto 0);
      variable res : FragByteNumType;
      variable idx : integer;
   begin
      for i in 0 to 31 loop
         rev(i) := byteEn(31 - i);
      end loop;
      res.valid := '0';
      res.num   := (others => '0');
      for k in 0 to 8 loop  -- idx = k*4 = 0,4,...,32 (step FRAG_MIN_VALID_BYTE_NUM=4)
         idx := k * 4;
         m   := shift_left(to_unsigned(1, 33), idx) - 1;  -- idx ones (idx=0 → 0)
         cmp := slv(m(31 downto 0));
         if rev = cmp then
            res.valid := '1';
            res.num   := slv(to_unsigned(idx, 6));
         end if;
      end loop;
      return res;
   end function;

   -- genByteEn(n): n valid bytes, MSB/first-byte aligned.  The incoming RoCE
   -- stream marks pad bytes valid on the wire; Rule 8 uses this helper with
   -- fragLenNoPad to prevent those lanes reaching the DMA-write consumer.
   function genByteEn (validByteNum : slv(5 downto 0)) return slv is
      variable res : slv(31 downto 0) := (others => '0');
      variable cnt : natural range 0 to 63;
   begin
      cnt := to_integer(unsigned(validByteNum));
      for i in 0 to 31 loop
         if i < cnt then
            res(31 - i) := '1';
         end if;
      end loop;
      return res;
   end function;

   -- isZeroByteEn(byteEn) = isZero({msb,lsb})  (only MSB and LSB tested, per source)
   function isZeroByteEn (byteEn : slv(31 downto 0)) return boolean is
   begin
      return (byteEn(31) = '0') and (byteEn(0) = '0');
   end function;

   -- pktLenEqPMTU: pktLen == 2**log2(pmtu)  (clear bit idx, rest must be zero)
   function pktLenEqPMTU (pktLen : slv(12 downto 0); pmtu : slv(2 downto 0)) return boolean is
      variable tmp : slv(12 downto 0);
      variable idx : integer;
   begin
      case pmtu is
         when IBV_MTU_256_C  => idx := 8;
         when IBV_MTU_512_C  => idx := 9;
         when IBV_MTU_1024_C => idx := 10;
         when IBV_MTU_2048_C => idx := 11;
         when others         => idx := 12;  -- IBV_MTU_4096
      end case;
      tmp      := pktLen;
      tmp(idx) := '0';
      return (unsigned(tmp) = 0);
   end function;

   -- pktLenGtPMTU: pktLen(idx)='1' AND lower idx bits nonzero
   function pktLenGtPMTU (pktLen : slv(12 downto 0); pmtu : slv(2 downto 0)) return boolean is
   begin
      case pmtu is
         when IBV_MTU_256_C  => return (pktLen(8) = '1') and (unsigned(pktLen(7 downto 0)) /= 0);
         when IBV_MTU_512_C  => return (pktLen(9) = '1') and (unsigned(pktLen(8 downto 0)) /= 0);
         when IBV_MTU_1024_C => return (pktLen(10) = '1') and (unsigned(pktLen(9 downto 0)) /= 0);
         when IBV_MTU_2048_C => return (pktLen(11) = '1') and (unsigned(pktLen(10 downto 0)) /= 0);
         when others         => return (pktLen(12) = '1') and (unsigned(pktLen(11 downto 0)) /= 0);
      end case;
   end function;

   -- pktLenAddBusByteWidth: {(pktLen[12:5]+1), pktLen[4:0]}
   function pktLenAddBusByteWidth (pktLen : slv(12 downto 0)) return slv is
      variable r : slv(12 downto 0);
   begin
      r(12 downto 5) := slv(unsigned(pktLen(12 downto 5)) + 1);
      r(4 downto 0)  := pktLen(4 downto 0);
      return r;
   end function;

   -- pktLenAddFragLen: fragLen==32 ? addBusByteWidth : {pktLen[12:5], fragLen[4:0]}
   function pktLenAddFragLen (pktLen : slv(12 downto 0); fragLen : slv(5 downto 0)) return slv is
      variable tmp : slv(5 downto 0);
   begin
      tmp    := fragLen;
      tmp(5) := '0';
      if unsigned(tmp) = 0 then  -- fragLenEqBusByteWidth (fragLen == 32)
         return pktLenAddBusByteWidth(pktLen);
      else
         return pktLen(12 downto 5) & fragLen(4 downto 0);
      end if;
   end function;

   ---------------------------------------------------------------------------
   -- Control-FSM state + accumulators (RegType)
   ---------------------------------------------------------------------------
   type RdmaPktBufStateType is (PRE_CHECK_FRAG_S, DISCARD_FRAG_S);

   type RegType is record
      pktBufState : RdmaPktBufStateType;  -- mkReg(PRE_CHECK_FRAG_S)
      isValidPkt  : sl;                   -- mkRegU (0 in init)
      bthPadCnt   : slv(1 downto 0);      -- mkRegU
      pktFragNum  : slv(7 downto 0);      -- mkRegU
      pktLen      : slv(12 downto 0);     -- mkRegU
      pktValid    : sl;                   -- mkRegU
   end record RegType;

   constant REG_INIT_C : RegType := (
      pktBufState => PRE_CHECK_FRAG_S,
      isValidPkt  => '0',
      bthPadCnt   => (others => '0'),
      pktFragNum  => (others => '0'),
      pktLen      => (others => '0'),
      pktValid    => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   ---------------------------------------------------------------------------
   -- FIFO / child interconnect signals
   ---------------------------------------------------------------------------
   -- U_PayloadPipeIn (mkBuffer skid on payload input)
   signal payloadBufWrEn    : sl;
   signal payloadBufNotFull : sl;
   signal payloadBufValid   : sl;
   signal payloadBufDout    : slv(DS_W_C-1 downto 0);
   signal payloadBufRdEn    : sl;

   -- U_RdmaHeaderPipeOut (child DataStream2Header) output = rdmaHeaderPipeOut
   signal rdmaHdrValid : sl;
   signal rdmaHdrDout  : slv(HDR_W_C-1 downto 0);
   signal rdmaHdrRdEn  : sl;

   -- 18 internal pipeline FIFOs: <name>{Din,WrEn,NotFull,Valid,Dout,RdEn}
   signal rdmaHeaderRecvQDin                                                                     : slv(RECV_W_C-1 downto 0);
   signal rdmaHeaderRecvQWrEn : sl;
   signal rdmaHeaderRecvQNotFull : sl;
   signal rdmaHeaderRecvQValid : sl;
   signal rdmaHeaderRecvQRdEn : sl;
   signal rdmaHeaderRecvQDout                                                                    : slv(RECV_W_C-1 downto 0);

   signal payloadRecvQDin                                                            : slv(DS_W_C-1 downto 0);
   signal payloadRecvQWrEn : sl;
   signal payloadRecvQNotFull : sl;
   signal payloadRecvQValid : sl;
   signal payloadRecvQRdEn : sl;
   signal payloadRecvQDout                                                           : slv(DS_W_C-1 downto 0);

   signal rdmaHeaderPreCheckQDin                                                                                 : slv(PRECHK_W_C-1 downto 0);
   signal rdmaHeaderPreCheckQWrEn : sl;
   signal rdmaHeaderPreCheckQNotFull : sl;
   signal rdmaHeaderPreCheckQValid : sl;
   signal rdmaHeaderPreCheckQRdEn : sl;
   signal rdmaHeaderPreCheckQDout                                                                                : slv(PRECHK_W_C-1 downto 0);

   signal payloadPreCheckQDin                                                                        : slv(DS_W_C-1 downto 0);
   signal payloadPreCheckQWrEn : sl;
   signal payloadPreCheckQNotFull : sl;
   signal payloadPreCheckQValid : sl;
   signal payloadPreCheckQRdEn : sl;
   signal payloadPreCheckQDout                                                                       : slv(DS_W_C-1 downto 0);

   signal rdmaHeaderValidationQDin                                                                                       : slv(VALID_W_C-1 downto 0);
   signal rdmaHeaderValidationQWrEn : sl;
   signal rdmaHeaderValidationQNotFull : sl;
   signal rdmaHeaderValidationQValid : sl;
   signal rdmaHeaderValidationQRdEn : sl;
   signal rdmaHeaderValidationQDout                                                                                      : slv(VALID_W_C-1 downto 0);

   signal payloadValidationQDin                                                                              : slv(DS_W_C-1 downto 0);
   signal payloadValidationQWrEn : sl;
   signal payloadValidationQNotFull : sl;
   signal payloadValidationQValid : sl;
   signal payloadValidationQRdEn : sl;
   signal payloadValidationQDout                                                                             : slv(DS_W_C-1 downto 0);

   signal rdmaHeaderFilterQDin                                                                           : slv(FILT_W_C-1 downto 0);
   signal rdmaHeaderFilterQWrEn : sl;
   signal rdmaHeaderFilterQNotFull : sl;
   signal rdmaHeaderFilterQValid : sl;
   signal rdmaHeaderFilterQRdEn : sl;
   signal rdmaHeaderFilterQDout                                                                          : slv(FILT_W_C-1 downto 0);

   signal payloadFilterQDin                                                                  : slv(DS_W_C-1 downto 0);
   signal payloadFilterQWrEn : sl;
   signal payloadFilterQNotFull : sl;
   signal payloadFilterQValid : sl;
   signal payloadFilterQRdEn : sl;
   signal payloadFilterQDout                                                                 : slv(DS_W_C-1 downto 0);

   signal rdmaHeaderFragLenCalcQDin                                                                                          : slv(FILT_W_C-1 downto 0);
   signal rdmaHeaderFragLenCalcQWrEn : sl;
   signal rdmaHeaderFragLenCalcQNotFull : sl;
   signal rdmaHeaderFragLenCalcQValid : sl;
   signal rdmaHeaderFragLenCalcQRdEn : sl;
   signal rdmaHeaderFragLenCalcQDout                                                                                         : slv(FILT_W_C-1 downto 0);

   signal payloadFragLenCalcQDin                                                                                 : slv(DS_W_C-1 downto 0);
   signal payloadFragLenCalcQWrEn : sl;
   signal payloadFragLenCalcQNotFull : sl;
   signal payloadFragLenCalcQValid : sl;
   signal payloadFragLenCalcQRdEn : sl;
   signal payloadFragLenCalcQDout                                                                                : slv(DS_W_C-1 downto 0);

   signal rdmaHeaderPktLenCalcQDin                                                                                       : slv(FILT_W_C-1 downto 0);
   signal rdmaHeaderPktLenCalcQWrEn : sl;
   signal rdmaHeaderPktLenCalcQNotFull : sl;
   signal rdmaHeaderPktLenCalcQValid : sl;
   signal rdmaHeaderPktLenCalcQRdEn : sl;
   signal rdmaHeaderPktLenCalcQDout                                                                                      : slv(FILT_W_C-1 downto 0);

   signal payloadPktLenCalcQDin                                                                              : slv(PLC_W_C-1 downto 0);
   signal payloadPktLenCalcQWrEn : sl;
   signal payloadPktLenCalcQNotFull : sl;
   signal payloadPktLenCalcQValid : sl;
   signal payloadPktLenCalcQRdEn : sl;
   signal payloadPktLenCalcQDout                                                                             : slv(PLC_W_C-1 downto 0);

   signal rdmaHeaderPktLenPreCheckQDin                                                                                                   : slv(PLCI_W_C-1 downto 0);
   signal rdmaHeaderPktLenPreCheckQWrEn : sl;
   signal rdmaHeaderPktLenPreCheckQNotFull : sl;
   signal rdmaHeaderPktLenPreCheckQValid : sl;
   signal rdmaHeaderPktLenPreCheckQRdEn : sl;
   signal rdmaHeaderPktLenPreCheckQDout                                                                                                  : slv(PLCI_W_C-1 downto 0);

   signal payloadPktLenPreCheckQDin                                                                                          : slv(PL3_W_C-1 downto 0);
   signal payloadPktLenPreCheckQWrEn : sl;
   signal payloadPktLenPreCheckQNotFull : sl;
   signal payloadPktLenPreCheckQValid : sl;
   signal payloadPktLenPreCheckQRdEn : sl;
   signal payloadPktLenPreCheckQDout                                                                                         : slv(PL3_W_C-1 downto 0);

   signal rdmaHeaderPktLenCheckQDin                                                                                          : slv(PCHK4_W_C-1 downto 0);
   signal rdmaHeaderPktLenCheckQWrEn : sl;
   signal rdmaHeaderPktLenCheckQNotFull : sl;
   signal rdmaHeaderPktLenCheckQValid : sl;
   signal rdmaHeaderPktLenCheckQRdEn : sl;
   signal rdmaHeaderPktLenCheckQDout                                                                                         : slv(PCHK4_W_C-1 downto 0);

   signal payloadPktLenCheckQDin                                                                                 : slv(PL3_W_C-1 downto 0);
   signal payloadPktLenCheckQWrEn : sl;
   signal payloadPktLenCheckQNotFull : sl;
   signal payloadPktLenCheckQValid : sl;
   signal payloadPktLenCheckQRdEn : sl;
   signal payloadPktLenCheckQDout                                                                                : slv(PL3_W_C-1 downto 0);

   signal rdmaHeaderOutputQDin                                                                           : slv(HDROUT_W_C-1 downto 0);
   signal rdmaHeaderOutputQWrEn : sl;
   signal rdmaHeaderOutputQNotFull : sl;
   signal rdmaHeaderOutputQValid : sl;
   signal rdmaHeaderOutputQRdEn : sl;
   signal rdmaHeaderOutputQDout                                                                          : slv(HDROUT_W_C-1 downto 0);

   signal payloadOutputQDin                                                                  : slv(PL3_W_C-1 downto 0);
   signal payloadOutputQWrEn : sl;
   signal payloadOutputQNotFull : sl;
   signal payloadOutputQValid : sl;
   signal payloadOutputQRdEn : sl;
   signal payloadOutputQDout                                                                 : slv(PL3_W_C-1 downto 0);

   ---------------------------------------------------------------------------
   -- Output FIFO vectors (internal arrays; flattened to ports in the generate)
   ---------------------------------------------------------------------------
   type MetaArray is array (natural range <>) of slv(META_W_C-1 downto 0);
   type DsArray is array (natural range <>) of slv(DS_W_C-1 downto 0);
   type BthArray is array (natural range <>) of slv(BTH_W_C-1 downto 0);

   signal cnpDinA,         cnpDoutA                : BthArray(0 to MAX_QP_G-1);
   signal cnpWrEnA : slv(MAX_QP_G-1 downto 0);
   signal cnpNotFullA : slv(MAX_QP_G-1 downto 0);
   signal cnpValidA : slv(MAX_QP_G-1 downto 0);

   signal reqPayloadDinA,  reqPayloadDoutA                          : DsArray(0 to MAX_QP_G-1);
   signal reqPayloadWrEnA    : slv(MAX_QP_G-1 downto 0);
   signal reqPayloadNotFullA    : slv(MAX_QP_G-1 downto 0);
   signal reqPayloadValidA    : slv(MAX_QP_G-1 downto 0);
   signal respPayloadDinA, respPayloadDoutA                        : DsArray(0 to MAX_QP_G-1);
   signal respPayloadWrEnA : slv(MAX_QP_G-1 downto 0);
   signal respPayloadNotFullA : slv(MAX_QP_G-1 downto 0);
   signal respPayloadValidA : slv(MAX_QP_G-1 downto 0);

   signal reqMetaDinA,     reqMetaDoutA                       : MetaArray(0 to MAX_QP_G-1);
   signal reqMetaWrEnA    : slv(MAX_QP_G-1 downto 0);
   signal reqMetaNotFullA    : slv(MAX_QP_G-1 downto 0);
   signal reqMetaValidA    : slv(MAX_QP_G-1 downto 0);
   signal respMetaDinA,    respMetaDoutA                     : MetaArray(0 to MAX_QP_G-1);
   signal respMetaWrEnA : slv(MAX_QP_G-1 downto 0);
   signal respMetaNotFullA : slv(MAX_QP_G-1 downto 0);
   signal respMetaValidA : slv(MAX_QP_G-1 downto 0);

begin

   assert isPowerOf2(MAX_QP_G)
      report "InputRdmaPktBufAndHeaderValidation: MAX_QP_G must be a power of 2, >= 1 " &
      "(getIndexQP = truncateLSB of the 24-bit QPN to log2(MAX_QP_G) bits; " &
      "at MAX_QP_G=1 the index is forced to 0, MetaData.bsv:349)."
      severity failure;

   ---------------------------------------------------------------------------
   -- U_PayloadPipeIn : surf.Fifo  (BSV mkBuffer(pipeIn.payload) = mkPipelineFIFOF)
   --   Write side fed by the payload input pipe; read side (payloadBuf*) consumed
   --   by recvPktFrag / discardInvalidFrag.
   ---------------------------------------------------------------------------
   payloadBufWrEn    <= payloadPipeInValid and payloadBufNotFull;
   payloadPipeInRdEn <= payloadPipeInValid and payloadBufNotFull;

   U_PayloadPipeIn : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => DS_W_C,
         ADDR_WIDTH_G    => ADDR_W_C)
      port map (
         rst          => rst,
         wr_clk => clk,
         wr_en => payloadBufWrEn,
         din => payloadPipeInData,
         not_full     => payloadBufNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full    => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk       => clk,
         rd_en => payloadBufRdEn,
         dout => payloadBufDout,
         valid        => payloadBufValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_RdmaHeaderPipeOut : entity work.DataStream2Header (child, mkDataStream2Header)
   --   Consumes the header DataStream + HeaderMetaData input pipes; emits a
   --   593-bit HeaderRDMA per packet (rdmaHdr*), consumed by recvPktFrag.
   ---------------------------------------------------------------------------
   U_RdmaHeaderPipeOut : entity work.DataStream2Header
      generic map (
         TPD_G => TPD_G)
      port map (
         clk                    => clk,
         rst => rst,
         dataPipeInValid        => headerDataStreamValid,
         dataPipeInData         => headerDataStreamData,
         dataPipeInRdEn         => headerDataStreamRdEn,
         hdrMetaDataPipeInValid => headerMetaDataValid,
         hdrMetaDataPipeInData  => headerMetaDataData,
         hdrMetaDataPipeInRdEn  => headerMetaDataRdEn,
         headerOutQValid        => rdmaHdrValid,
         headerOutQDout         => rdmaHdrDout,
         headerOutQRdEn         => rdmaHdrRdEn);

   ---------------------------------------------------------------------------
   -- 18 internal pipeline FIFOs (all surf.Fifo, FWFT, sync)
   ---------------------------------------------------------------------------
   U_RdmaHeaderRecvQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G    => RECV_W_C, ADDR_WIDTH_G => ADDR_W_C)
      port map (
         rst          => rst,
         wr_clk => clk,
         wr_en => rdmaHeaderRecvQWrEn,
         din => rdmaHeaderRecvQDin,
         not_full     => rdmaHeaderRecvQNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full    => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk       => clk,
         rd_en => rdmaHeaderRecvQRdEn,
         dout => rdmaHeaderRecvQDout,
         valid        => rdmaHeaderRecvQValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_PayloadRecvQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G    => DS_W_C, ADDR_WIDTH_G => ADDR_W_C)
      port map (
         rst          => rst,
         wr_clk => clk,
         wr_en => payloadRecvQWrEn,
         din => payloadRecvQDin,
         not_full     => payloadRecvQNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full    => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk       => clk,
         rd_en => payloadRecvQRdEn,
         dout => payloadRecvQDout,
         valid        => payloadRecvQValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_RdmaHeaderPreCheckQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G    => PRECHK_W_C, ADDR_WIDTH_G => ADDR_W_C)
      port map (
         rst          => rst,
         wr_clk => clk,
         wr_en => rdmaHeaderPreCheckQWrEn,
         din => rdmaHeaderPreCheckQDin,
         not_full     => rdmaHeaderPreCheckQNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full    => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk       => clk,
         rd_en => rdmaHeaderPreCheckQRdEn,
         dout => rdmaHeaderPreCheckQDout,
         valid        => rdmaHeaderPreCheckQValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_PayloadPreCheckQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G    => DS_W_C, ADDR_WIDTH_G => ADDR_W_C)
      port map (
         rst          => rst,
         wr_clk => clk,
         wr_en => payloadPreCheckQWrEn,
         din => payloadPreCheckQDin,
         not_full     => payloadPreCheckQNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full    => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk       => clk,
         rd_en => payloadPreCheckQRdEn,
         dout => payloadPreCheckQDout,
         valid        => payloadPreCheckQValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_RdmaHeaderValidationQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G    => VALID_W_C, ADDR_WIDTH_G => ADDR_W_C)
      port map (
         rst          => rst,
         wr_clk => clk,
         wr_en => rdmaHeaderValidationQWrEn,
         din => rdmaHeaderValidationQDin,
         not_full     => rdmaHeaderValidationQNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full    => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk       => clk,
         rd_en => rdmaHeaderValidationQRdEn,
         dout => rdmaHeaderValidationQDout,
         valid        => rdmaHeaderValidationQValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_PayloadValidationQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G    => DS_W_C, ADDR_WIDTH_G => ADDR_W_C)
      port map (
         rst          => rst,
         wr_clk => clk,
         wr_en => payloadValidationQWrEn,
         din => payloadValidationQDin,
         not_full     => payloadValidationQNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full    => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk       => clk,
         rd_en => payloadValidationQRdEn,
         dout => payloadValidationQDout,
         valid        => payloadValidationQValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_RdmaHeaderFilterQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G    => FILT_W_C, ADDR_WIDTH_G => ADDR_W_C)
      port map (
         rst          => rst,
         wr_clk => clk,
         wr_en => rdmaHeaderFilterQWrEn,
         din => rdmaHeaderFilterQDin,
         not_full     => rdmaHeaderFilterQNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full    => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk       => clk,
         rd_en => rdmaHeaderFilterQRdEn,
         dout => rdmaHeaderFilterQDout,
         valid        => rdmaHeaderFilterQValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_PayloadFilterQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G    => DS_W_C, ADDR_WIDTH_G => ADDR_W_C)
      port map (
         rst          => rst,
         wr_clk => clk,
         wr_en => payloadFilterQWrEn,
         din => payloadFilterQDin,
         not_full     => payloadFilterQNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full    => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk       => clk,
         rd_en => payloadFilterQRdEn,
         dout => payloadFilterQDout,
         valid        => payloadFilterQValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_RdmaHeaderFragLenCalcQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G    => FILT_W_C, ADDR_WIDTH_G => ADDR_W_C)
      port map (
         rst          => rst,
         wr_clk => clk,
         wr_en => rdmaHeaderFragLenCalcQWrEn,
         din => rdmaHeaderFragLenCalcQDin,
         not_full     => rdmaHeaderFragLenCalcQNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full    => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk       => clk,
         rd_en => rdmaHeaderFragLenCalcQRdEn,
         dout => rdmaHeaderFragLenCalcQDout,
         valid        => rdmaHeaderFragLenCalcQValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_PayloadFragLenCalcQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G    => DS_W_C, ADDR_WIDTH_G => ADDR_W_C)
      port map (
         rst          => rst,
         wr_clk => clk,
         wr_en => payloadFragLenCalcQWrEn,
         din => payloadFragLenCalcQDin,
         not_full     => payloadFragLenCalcQNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full    => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk       => clk,
         rd_en => payloadFragLenCalcQRdEn,
         dout => payloadFragLenCalcQDout,
         valid        => payloadFragLenCalcQValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_RdmaHeaderPktLenCalcQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G    => FILT_W_C, ADDR_WIDTH_G => ADDR_W_C)
      port map (
         rst          => rst,
         wr_clk => clk,
         wr_en => rdmaHeaderPktLenCalcQWrEn,
         din => rdmaHeaderPktLenCalcQDin,
         not_full     => rdmaHeaderPktLenCalcQNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full    => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk       => clk,
         rd_en => rdmaHeaderPktLenCalcQRdEn,
         dout => rdmaHeaderPktLenCalcQDout,
         valid        => rdmaHeaderPktLenCalcQValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_PayloadPktLenCalcQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G    => PLC_W_C, ADDR_WIDTH_G => ADDR_W_C)
      port map (
         rst          => rst,
         wr_clk => clk,
         wr_en => payloadPktLenCalcQWrEn,
         din => payloadPktLenCalcQDin,
         not_full     => payloadPktLenCalcQNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full    => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk       => clk,
         rd_en => payloadPktLenCalcQRdEn,
         dout => payloadPktLenCalcQDout,
         valid        => payloadPktLenCalcQValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_RdmaHeaderPktLenPreCheckQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G    => PLCI_W_C, ADDR_WIDTH_G => ADDR_W_C)
      port map (
         rst          => rst,
         wr_clk => clk,
         wr_en => rdmaHeaderPktLenPreCheckQWrEn,
         din => rdmaHeaderPktLenPreCheckQDin,
         not_full     => rdmaHeaderPktLenPreCheckQNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full    => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk       => clk,
         rd_en => rdmaHeaderPktLenPreCheckQRdEn,
         dout => rdmaHeaderPktLenPreCheckQDout,
         valid        => rdmaHeaderPktLenPreCheckQValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_PayloadPktLenPreCheckQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G    => PL3_W_C, ADDR_WIDTH_G => ADDR_W_C)
      port map (
         rst          => rst,
         wr_clk => clk,
         wr_en => payloadPktLenPreCheckQWrEn,
         din => payloadPktLenPreCheckQDin,
         not_full     => payloadPktLenPreCheckQNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full    => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk       => clk,
         rd_en => payloadPktLenPreCheckQRdEn,
         dout => payloadPktLenPreCheckQDout,
         valid        => payloadPktLenPreCheckQValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_RdmaHeaderPktLenCheckQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G    => PCHK4_W_C, ADDR_WIDTH_G => ADDR_W_C)
      port map (
         rst          => rst,
         wr_clk => clk,
         wr_en => rdmaHeaderPktLenCheckQWrEn,
         din => rdmaHeaderPktLenCheckQDin,
         not_full     => rdmaHeaderPktLenCheckQNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full    => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk       => clk,
         rd_en => rdmaHeaderPktLenCheckQRdEn,
         dout => rdmaHeaderPktLenCheckQDout,
         valid        => rdmaHeaderPktLenCheckQValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_PayloadPktLenCheckQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G    => PL3_W_C, ADDR_WIDTH_G => ADDR_W_C)
      port map (
         rst          => rst,
         wr_clk => clk,
         wr_en => payloadPktLenCheckQWrEn,
         din => payloadPktLenCheckQDin,
         not_full     => payloadPktLenCheckQNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full    => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk       => clk,
         rd_en => payloadPktLenCheckQRdEn,
         dout => payloadPktLenCheckQDout,
         valid        => payloadPktLenCheckQValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_RdmaHeaderOutputQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G    => HDROUT_W_C, ADDR_WIDTH_G => ADDR_W_C)
      port map (
         rst          => rst,
         wr_clk => clk,
         wr_en => rdmaHeaderOutputQWrEn,
         din => rdmaHeaderOutputQDin,
         not_full     => rdmaHeaderOutputQNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full    => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk       => clk,
         rd_en => rdmaHeaderOutputQRdEn,
         dout => rdmaHeaderOutputQDout,
         valid        => rdmaHeaderOutputQValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   U_PayloadOutputQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G    => PL3_W_C, ADDR_WIDTH_G => ADDR_W_C)
      port map (
         rst          => rst,
         wr_clk => clk,
         wr_en => payloadOutputQWrEn,
         din => payloadOutputQDin,
         not_full     => payloadOutputQNotFull,
         full => open,
         wr_ack => open,
         overflow => open,
         prog_full    => open,
         almost_full => open,
         wr_data_count => open,
         rd_clk       => clk,
         rd_en => payloadOutputQRdEn,
         dout => payloadOutputQDout,
         valid        => payloadOutputQValid,
         underflow => open,
         prog_empty => open,
         almost_empty => open,
         empty => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- Output FIFO vectors (x MAX_QP_G): 5 groups, one surf.Fifo per QP index.
   --   Read side is the entity's returned PipeOut vector (flattened ports).
   ---------------------------------------------------------------------------
   GEN_OUT_VEC : for i in 0 to MAX_QP_G-1 generate
      -- flatten read side to the entity ports
      cnpValid(i)                     <= cnpValidA(i);
      cnpDout((i+1)*96-1 downto i*96) <= cnpDoutA(i);

      reqPayloadValid(i)                            <= reqPayloadValidA(i);
      reqPayloadDout((i+1)*290-1 downto i*290)      <= reqPayloadDoutA(i);
      respPayloadValid(i)                           <= respPayloadValidA(i);
      respPayloadDout((i+1)*290-1 downto i*290)     <= respPayloadDoutA(i);
      reqPktMetaDataValid(i)                        <= reqMetaValidA(i);
      reqPktMetaDataDout((i+1)*649-1 downto i*649)  <= reqMetaDoutA(i);
      respPktMetaDataValid(i)                       <= respMetaValidA(i);
      respPktMetaDataDout((i+1)*649-1 downto i*649) <= respMetaDoutA(i);

      U_CnpOutVec : entity surf.Fifo
         generic map (
            TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
            GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
            DATA_WIDTH_G    => BTH_W_C, ADDR_WIDTH_G => ADDR_W_C)
         port map (
            rst          => rst,
            wr_clk => clk,
            wr_en => cnpWrEnA(i),
            din => cnpDinA(i),
            not_full     => cnpNotFullA(i),
            full => open,
            wr_ack => open,
            overflow => open,
            prog_full    => open,
            almost_full => open,
            wr_data_count => open,
            rd_clk       => clk,
            rd_en => cnpRdEn(i),
            dout => cnpDoutA(i),
            valid        => cnpValidA(i),
            underflow => open,
            prog_empty => open,
            almost_empty => open,
            empty => open,
            rd_data_count => open);

      -- Req-stream (-> responder/RQ) output FIFOs: pruned when EN_RX_G=false.
      -- notFull tied '1' makes the output stages fire-and-drop request packets
      -- here (authoritative drain for the disabled responder).
      GEN_NO_REQ_FIFOS : if not EN_RX_G generate
         reqPayloadNotFullA(i) <= '1';
         reqPayloadValidA(i)   <= '0';
         reqPayloadDoutA(i)    <= (others => '0');
         reqMetaNotFullA(i)    <= '1';
         reqMetaValidA(i)      <= '0';
         reqMetaDoutA(i)       <= (others => '0');
      end generate GEN_NO_REQ_FIFOS;

      GEN_REQ_FIFOS : if EN_RX_G generate
         U_ReqPayloadOutVec : entity surf.Fifo
            generic map (
               TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
               GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
               DATA_WIDTH_G    => DS_W_C, ADDR_WIDTH_G => ADDR_W_C)
            port map (
               rst          => rst,
               wr_clk => clk,
               wr_en => reqPayloadWrEnA(i),
               din => reqPayloadDinA(i),
               not_full     => reqPayloadNotFullA(i),
               full => open,
               wr_ack => open,
               overflow => open,
               prog_full    => open,
               almost_full => open,
               wr_data_count => open,
               rd_clk       => clk,
               rd_en => reqPayloadRdEn(i),
               dout => reqPayloadDoutA(i),
               valid        => reqPayloadValidA(i),
               underflow => open,
               prog_empty => open,
               almost_empty => open,
               empty => open,
               rd_data_count => open);

         U_ReqPktMetaDataOutVec : entity surf.Fifo
            generic map (
               TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
               GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
               DATA_WIDTH_G    => META_W_C, ADDR_WIDTH_G => ADDR_W_C)
            port map (
               rst          => rst,
               wr_clk => clk,
               wr_en => reqMetaWrEnA(i),
               din => reqMetaDinA(i),
               not_full     => reqMetaNotFullA(i),
               full => open,
               wr_ack => open,
               overflow => open,
               prog_full    => open,
               almost_full => open,
               wr_data_count => open,
               rd_clk       => clk,
               rd_en => reqPktMetaDataRdEn(i),
               dout => reqMetaDoutA(i),
               valid        => reqMetaValidA(i),
               underflow => open,
               prog_empty => open,
               almost_empty => open,
               empty => open,
               rd_data_count => open);
      end generate GEN_REQ_FIFOS;

      -- Resp-stream (-> requester/SQ) output FIFOs: pruned when EN_TX_G=false
      -- (a pure responder never sees ACK/read-response packets addressed to it;
      -- any that arrive drop here).
      GEN_NO_RESP_FIFOS : if not EN_TX_G generate
         respPayloadNotFullA(i) <= '1';
         respPayloadValidA(i)   <= '0';
         respPayloadDoutA(i)    <= (others => '0');
         respMetaNotFullA(i)    <= '1';
         respMetaValidA(i)      <= '0';
         respMetaDoutA(i)       <= (others => '0');
      end generate GEN_NO_RESP_FIFOS;

      GEN_RESP_FIFOS : if EN_TX_G generate
         U_RespPayloadOutVec : entity surf.Fifo
            generic map (
               TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
               GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
               DATA_WIDTH_G    => DS_W_C, ADDR_WIDTH_G => ADDR_W_C)
            port map (
               rst          => rst,
               wr_clk => clk,
               wr_en => respPayloadWrEnA(i),
               din => respPayloadDinA(i),
               not_full     => respPayloadNotFullA(i),
               full => open,
               wr_ack => open,
               overflow => open,
               prog_full    => open,
               almost_full => open,
               wr_data_count => open,
               rd_clk       => clk,
               rd_en => respPayloadRdEn(i),
               dout => respPayloadDoutA(i),
               valid        => respPayloadValidA(i),
               underflow => open,
               prog_empty => open,
               almost_empty => open,
               empty => open,
               rd_data_count => open);

         U_RespPktMetaDataOutVec : entity surf.Fifo
            generic map (
               TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
               GEN_SYNC_FIFO_G => true, FWFT_EN_G => true, MEMORY_TYPE_G => "distributed",
               DATA_WIDTH_G    => META_W_C, ADDR_WIDTH_G => ADDR_W_C)
            port map (
               rst          => rst,
               wr_clk => clk,
               wr_en => respMetaWrEnA(i),
               din => respMetaDinA(i),
               not_full     => respMetaNotFullA(i),
               full => open,
               wr_ack => open,
               overflow => open,
               prog_full    => open,
               almost_full => open,
               wr_data_count => open,
               rd_clk       => clk,
               rd_en => respPktMetaDataRdEn(i),
               dout => respMetaDoutA(i),
               valid        => respMetaValidA(i),
               underflow => open,
               prog_empty => open,
               almost_empty => open,
               empty => open,
               rd_data_count => open);
      end generate GEN_RESP_FIFOS;
   end generate GEN_OUT_VEC;

   ---------------------------------------------------------------------------
   -- Combinatorial process — 12 concurrent stage rules (no elsif precedence),
   -- pktBufState control FSM, per-packet accumulators.
   ---------------------------------------------------------------------------
   comb : process (all) is
      variable v : RegType;

      -- shared per-rule temporaries
      variable frag    : slv(DS_W_C-1 downto 0);
      variable isFirst : sl;
      variable isLast  : sl;
      variable canFire : boolean;

      -- recvPktFrag
      variable rHdr     : slv(HDR_W_C-1 downto 0);
      variable rBth     : slv(BTH_W_C-1 downto 0);
      variable aethCode : slv(1 downto 0);
      variable aethVal  : slv(4 downto 0);
      variable bthChk   : sl;
      variable hdrChk   : sl;
      variable nonPayOk : sl;

      -- prepareValidation
      variable pcHdr       : slv(HDR_W_C-1 downto 0);
      variable pcBth       : slv(BTH_W_C-1 downto 0);
      variable pcTrans     : slv(2 downto 0);
      variable pcOp        : slv(4 downto 0);
      variable pcIsCnp     : boolean;
      variable pcIsResp    : boolean;
      variable pcRespOrCnp : boolean;
      variable pcDqpn      : slv(23 downto 0);
      variable pcQkey      : slv(31 downto 0);
      variable pcSrqn      : slv(23 downto 0);
      variable hvi         : slv(HVI_W_C-1 downto 0);

      -- checkMetaDataQP
      variable vHdr                      : slv(HDR_W_C-1 downto 0);
      variable vBth                      : slv(BTH_W_C-1 downto 0);
      variable vHvi                      : slv(HVI_W_C-1 downto 0);
      variable vIsCnp                    : sl;
      variable vIsResp                   : sl;
      variable vResp                     : sl;  -- isRespPkt || isCNP
      variable vMaybe                    : sl;
      variable vDqpn                     : slv(23 downto 0);
      variable vQkey                     : slv(31 downto 0);
      variable selTypeQP                 : slv(3 downto 0);
      variable selErr, selRts, selNonErr : sl;
      variable selQkey                   : slv(31 downto 0);
      variable isValidHdr                : sl;
      variable pdHandler                 : slv(31 downto 0);
      variable vhInfo                    : slv(VHI_W_C-1 downto 0);

      -- discardInvalidHeaderPkt
      variable fHdr                       : slv(HDR_W_C-1 downto 0);
      variable fBth                       : slv(BTH_W_C-1 downto 0);
      variable fVhi                       : slv(VHI_W_C-1 downto 0);
      variable fIsValidHdr                : sl;
      variable fIsCnp                     : sl;
      variable isValidEff                 : sl;
      variable cnpIdx                     : integer range 0 to MAX_QP_G-1;
      variable needFrag, needCnp, needPay : boolean;
      variable fragOk, cnpOk, payOk       : boolean;

      -- calcFraglen
      variable clHdr        : slv(HDR_W_C-1 downto 0);
      variable clBth        : slv(BTH_W_C-1 downto 0);
      variable clVhi        : slv(VHI_W_C-1 downto 0);
      variable clPadCnt     : slv(1 downto 0);
      variable fbn          : FragByteNumType;
      variable fragLen      : slv(5 downto 0);
      variable fragLenNoPad : slv(5 downto 0);
      variable byteEnNZ     : sl;
      variable byteEnAll    : sl;

      -- calcPktLen
      variable pHdr                                                 : slv(HDR_W_C-1 downto 0);
      variable pBth                                                 : slv(BTH_W_C-1 downto 0);
      variable pVhi                                                 : slv(VHI_W_C-1 downto 0);
      variable pFrag                                                : slv(DS_W_C-1 downto 0);
      variable pFragNoPad                                           : slv(DS_W_C-1 downto 0);
      variable pFragLen                                             : slv(5 downto 0);
      variable pFragLenNoPad                                        : slv(5 downto 0);
      variable pByteEnNZ                                            : sl;
      variable pByteEnAll                                           : sl;
      variable pIsFirst, pIsLast                                    : sl;
      variable pIsRespPkt, pIsLastPkt, pIsFirstOrMid, pIsLastOrOnly : sl;
      variable pQpIdx                                               : integer range 0 to MAX_QP_G-1;
      variable newPktLen                                            : slv(12 downto 0);
      variable newFragNum                                           : slv(7 downto 0);
      variable newValid                                             : sl;
      variable plci                                                 : slv(PLCI_W_C-1 downto 0);

      -- preCheckPktLen
      variable preFrag   : slv(DS_W_C-1 downto 0);
      variable preQpIdx  : slv(QP_IDX_W_C-1 downto 0);
      variable preIsResp : sl;
      variable preIsLast : sl;
      variable prePlci   : slv(PLCI_W_C-1 downto 0);
      variable isZeroLen : sl;
      variable isEqPmtu  : sl;
      variable isGtPmtu  : sl;

      -- checkPktLen
      variable ckFrag    : slv(DS_W_C-1 downto 0);
      variable ckQpIdx   : slv(QP_IDX_W_C-1 downto 0);
      variable ckIsResp  : sl;
      variable ckIsLast  : sl;
      variable ckPlci    : slv(PLCI_W_C-1 downto 0);
      variable ckZeroLen : sl;
      variable ckEqPmtu  : sl;
      variable ckGtPmtu  : sl;
      variable ckValid   : sl;
      variable ckStatus  : sl;
      variable meta      : slv(META_W_C-1 downto 0);

      -- output stages
      variable oQpIdx  : integer range 0 to MAX_QP_G-1;
      variable oIsResp : sl;
   begin
      v := r;

      -- default all comb-driven controls (no latches)
      rdmaHdrRdEn    <= '0';
      payloadBufRdEn <= '0';

      rdmaHeaderRecvQWrEn           <= '0'; rdmaHeaderRecvQRdEn <= '0'; rdmaHeaderRecvQDin <= (others                     => '0');
      payloadRecvQWrEn              <= '0'; payloadRecvQRdEn <= '0'; payloadRecvQDin <= (others                           => '0');
      rdmaHeaderPreCheckQWrEn       <= '0'; rdmaHeaderPreCheckQRdEn <= '0'; rdmaHeaderPreCheckQDin <= (others             => '0');
      payloadPreCheckQWrEn          <= '0'; payloadPreCheckQRdEn <= '0'; payloadPreCheckQDin <= (others                   => '0');
      rdmaHeaderValidationQWrEn     <= '0'; rdmaHeaderValidationQRdEn <= '0'; rdmaHeaderValidationQDin <= (others         => '0');
      payloadValidationQWrEn        <= '0'; payloadValidationQRdEn <= '0'; payloadValidationQDin <= (others               => '0');
      rdmaHeaderFilterQWrEn         <= '0'; rdmaHeaderFilterQRdEn <= '0'; rdmaHeaderFilterQDin <= (others                 => '0');
      payloadFilterQWrEn            <= '0'; payloadFilterQRdEn <= '0'; payloadFilterQDin <= (others                       => '0');
      rdmaHeaderFragLenCalcQWrEn    <= '0'; rdmaHeaderFragLenCalcQRdEn <= '0'; rdmaHeaderFragLenCalcQDin <= (others       => '0');
      payloadFragLenCalcQWrEn       <= '0'; payloadFragLenCalcQRdEn <= '0'; payloadFragLenCalcQDin <= (others             => '0');
      rdmaHeaderPktLenCalcQWrEn     <= '0'; rdmaHeaderPktLenCalcQRdEn <= '0'; rdmaHeaderPktLenCalcQDin <= (others         => '0');
      payloadPktLenCalcQWrEn        <= '0'; payloadPktLenCalcQRdEn <= '0'; payloadPktLenCalcQDin <= (others               => '0');
      rdmaHeaderPktLenPreCheckQWrEn <= '0'; rdmaHeaderPktLenPreCheckQRdEn <= '0'; rdmaHeaderPktLenPreCheckQDin <= (others => '0');
      payloadPktLenPreCheckQWrEn    <= '0'; payloadPktLenPreCheckQRdEn <= '0'; payloadPktLenPreCheckQDin <= (others       => '0');
      rdmaHeaderPktLenCheckQWrEn    <= '0'; rdmaHeaderPktLenCheckQRdEn <= '0'; rdmaHeaderPktLenCheckQDin <= (others       => '0');
      payloadPktLenCheckQWrEn       <= '0'; payloadPktLenCheckQRdEn <= '0'; payloadPktLenCheckQDin <= (others             => '0');
      rdmaHeaderOutputQWrEn         <= '0'; rdmaHeaderOutputQRdEn <= '0'; rdmaHeaderOutputQDin <= (others                 => '0');
      payloadOutputQWrEn            <= '0'; payloadOutputQRdEn <= '0'; payloadOutputQDin <= (others                       => '0');

      for i in 0 to MAX_QP_G-1 loop
         cnpWrEnA(i)         <= '0'; cnpDinA(i) <= (others         => '0');
         reqPayloadWrEnA(i)  <= '0'; reqPayloadDinA(i) <= (others  => '0');
         respPayloadWrEnA(i) <= '0'; respPayloadDinA(i) <= (others => '0');
         reqMetaWrEnA(i)     <= '0'; reqMetaDinA(i) <= (others     => '0');
         respMetaWrEnA(i)    <= '0'; respMetaDinA(i) <= (others    => '0');
      end loop;

      --------------------------------------------------------------------
      -- qpMetaData combinational lookup requests (driven from FIFO heads)
      --------------------------------------------------------------------
      -- getPD(dqpn) : dqpn computed from rdmaHeaderPreCheckQ head (prepareValidation)
      pcHdr       := rdmaHeaderPreCheckQDout(PRECHK_W_C-1 downto BTH_W_C);
      pcBth       := rdmaHeaderPreCheckQDout(BTH_W_C-1 downto 0);
      pcTrans     := pcBth(95 downto 93);
      pcOp        := pcBth(92 downto 88);
      pcIsCnp     := isCnp(pcTrans, pcOp);
      pcIsResp    := isRdmaRespOp(pcOp);
      pcRespOrCnp := pcIsResp or pcIsCnp;
      pcSrqn      := pcHdr(488 downto 465);  -- xrceth.srqn
      pcQkey      := pcHdr(496 downto 465);  -- deth.qkey
      if (pcTrans = TRANS_TYPE_XRC_C) and (not pcRespOrCnp) then
         pcDqpn := pcSrqn;
      else
         pcDqpn := pcBth(55 downto 32);      -- bth.dqpn
      end if;
      getPdQpn <= pcDqpn;

      -- getQueuePairByQPN(dqpn) : dqpn from rdmaHeaderValidationQ head (checkMetaDataQP)
      getQpQpn <= rdmaHeaderValidationQDout(60 downto 37);  -- headerValidateInfo.dqpn

      --------------------------------------------------------------------
      -- Rule 1: recvPktFrag  (table B row1)
      --   SOLE consumer of payloadPipeIn; ALWAYS runs (fsm.md "keeps running").
      --   Invalid multi-fragment packets are drained downstream from payloadRecvQ
      --   by discardInvalidFrag, NOT from payloadPipeIn (OQ-FSM-IRPB-02 fix — see
      --   the file header).  No pktBufState gate here: only one rule ever deqs
      --   payloadPipeIn, so the PRE_CHECK→DISCARD race cannot occur.
      --------------------------------------------------------------------
      frag     := payloadBufDout;
      isFirst  := payloadBufDout(1);
      isLast   := payloadBufDout(0);
      rHdr     := rdmaHdrDout;
      rBth     := rHdr(592 downto 497);  -- extractBTH(headerData)
      aethCode := rHdr(495 downto 494);
      aethVal  := rHdr(493 downto 489);
      bthChk   := ite(checkZeroFields4BTH(rBth), '1', '0');
      hdrChk := ite(padCntCheckReqHeader(rBth(92 downto 88), rBth(85 downto 84))
                    or padCntCheckRespHeader(rBth(92 downto 88), rBth(85 downto 84), aethCode, aethVal),
                    '1', '0');
      -- nonPayloadHeaderShouldHaveNoPayload
      if rHdr(1) = '1' then              -- headerMetaData.hasPayload
         nonPayOk := '1';
      elsif (isFirst = '1' and isLast = '1' and isZeroByteEn(frag(33 downto 2))) then
         nonPayOk := '1';
      else
         nonPayOk := '0';
      end if;

      -- canFire: buffer notEmpty AND payloadRecvQ notFull; on isFirst also header
      -- pipe notEmpty AND rdmaHeaderRecvQ notFull.
      canFire := (payloadBufValid = '1') and (payloadRecvQNotFull = '1');
      if isFirst = '1' then
         canFire := canFire and (rdmaHdrValid = '1') and (rdmaHeaderRecvQNotFull = '1');
      end if;
      if canFire then
         payloadBufRdEn   <= '1';
         payloadRecvQWrEn <= '1';
         payloadRecvQDin  <= frag;
         if isFirst = '1' then
            rdmaHdrRdEn         <= '1';
            rdmaHeaderRecvQWrEn <= '1';
            rdmaHeaderRecvQDin  <= rHdr & rBth & bthChk & hdrChk & nonPayOk;
         end if;
      end if;

      --------------------------------------------------------------------
      -- Rule 2: preCheckHeader  (table A rows 1-4; writes pktBufState → DISCARD)
      --   guard pktBufState = PRE_CHECK_FRAG_S
      --------------------------------------------------------------------
      if r.pktBufState = PRE_CHECK_FRAG_S then
         frag    := payloadRecvQDout;
         isFirst := payloadRecvQDout(1);
         isLast  := payloadRecvQDout(0);
         if isFirst = '1' then
            -- needs rdmaHeaderRecvQ head; header-valid → forward, else discard
            rHdr     := rdmaHeaderRecvQDout(RECV_W_C-1 downto RECV_W_C-HDR_W_C);  -- [691:99]
            rBth     := rdmaHeaderRecvQDout(98 downto 3);
            bthChk   := rdmaHeaderRecvQDout(2);
            hdrChk   := rdmaHeaderRecvQDout(1);
            nonPayOk := rdmaHeaderRecvQDout(0);
            if (bthChk = '1' and hdrChk = '1' and nonPayOk = '1') then
               -- valid header: forward to preCheck queues (needs both notFull)
               canFire := (payloadRecvQValid = '1') and (rdmaHeaderRecvQValid = '1')
                          and (rdmaHeaderPreCheckQNotFull = '1') and (payloadPreCheckQNotFull = '1');
               if canFire then
                  payloadRecvQRdEn        <= '1';
                  rdmaHeaderRecvQRdEn     <= '1';
                  rdmaHeaderPreCheckQWrEn <= '1';
                  rdmaHeaderPreCheckQDin  <= rHdr & rBth;
                  payloadPreCheckQWrEn    <= '1';
                  payloadPreCheckQDin     <= frag;
               end if;
            else
               -- invalid header: drop header+frag; multi-frag → enter DISCARD
               canFire := (payloadRecvQValid = '1') and (rdmaHeaderRecvQValid = '1');
               if canFire then
                  payloadRecvQRdEn    <= '1';
                  rdmaHeaderRecvQRdEn <= '1';
                  if isLast = '0' then
                     v.pktBufState := DISCARD_FRAG_S;
                  end if;
               end if;
            end if;
         else
            -- non-first fragment: forward payload only
            canFire := (payloadRecvQValid = '1') and (payloadPreCheckQNotFull = '1');
            if canFire then
               payloadRecvQRdEn     <= '1';
               payloadPreCheckQWrEn <= '1';
               payloadPreCheckQDin  <= frag;
            end if;
         end if;
      end if;

      --------------------------------------------------------------------
      -- Rule 3: discardInvalidFrag  (table A rows 5-6)
      --   guard pktBufState = DISCARD_FRAG_S.  Drains the invalid packet's
      --   remaining fragments from payloadRecvQ (recvPktFrag already moved them
      --   off payloadPipeIn).  Mutually exclusive with preCheckHeader, which
      --   reads payloadRecvQ only in PRE_CHECK_FRAG_S → a single payloadRecvQ
      --   reader per state.  OQ-FSM-IRPB-02 fix (was draining payloadPipeIn and
      --   racing recvPktFrag on it).
      --------------------------------------------------------------------
      if r.pktBufState = DISCARD_FRAG_S then
         if payloadRecvQValid = '1' then
            payloadRecvQRdEn <= '1';           -- drop fragment
            if payloadRecvQDout(0) = '1' then  -- isLast
               v.pktBufState := PRE_CHECK_FRAG_S;
            end if;
         end if;
      end if;

      --------------------------------------------------------------------
      -- Rule 4: prepareValidation  (table B row2)
      --------------------------------------------------------------------
      frag    := payloadPreCheckQDout;
      isFirst := payloadPreCheckQDout(1);
      if isFirst = '1' then
         canFire := (payloadPreCheckQValid = '1') and (rdmaHeaderPreCheckQValid = '1')
                    and (rdmaHeaderValidationQNotFull = '1') and (payloadValidationQNotFull = '1');
         if canFire then
            -- headerValidateInfo built from pcHdr/pcBth (computed above for getPD)
            hvi := (getPdMaybeValid & getPdHandler)  -- maybePdHandler [93:61]
                   & pcDqpn             -- dqpn [60:37]
                   & pcQkey             -- qkeyDETH [36:5]
                   & ite(pcIsCnp, '1', '0')          -- isCNP [4]
                   & ite(pcIsResp, '1', '0')         -- isRespPkt [3]
                   & ite(isLastOp(pcOp), '1', '0')   -- isLastPkt [2]
                   & ite(isFirstOrMidOp(pcOp), '1', '0')  -- isFirstOrMidPkt [1]
                   & ite(isLastOrOnlyOp(pcOp), '1', '0');  -- isLastOrOnlyPkt [0]
            payloadPreCheckQRdEn      <= '1';
            rdmaHeaderPreCheckQRdEn   <= '1';
            rdmaHeaderValidationQWrEn <= '1';
            rdmaHeaderValidationQDin  <= pcHdr & pcBth & hvi;
            payloadValidationQWrEn    <= '1';
            payloadValidationQDin     <= frag;
         end if;
      else
         canFire := (payloadPreCheckQValid = '1') and (payloadValidationQNotFull = '1');
         if canFire then
            payloadPreCheckQRdEn   <= '1';
            payloadValidationQWrEn <= '1';
            payloadValidationQDin  <= frag;
         end if;
      end if;

      --------------------------------------------------------------------
      -- Rule 5: checkMetaDataQP  (table B row3)
      --------------------------------------------------------------------
      frag      := payloadValidationQDout;
      isFirst   := payloadValidationQDout(1);
      vHdr      := rdmaHeaderValidationQDout(VALID_W_C-1 downto VALID_W_C-HDR_W_C);  -- [782:190]
      vBth      := rdmaHeaderValidationQDout(189 downto 94);
      vHvi      := rdmaHeaderValidationQDout(93 downto 0);
      vMaybe    := vHvi(93);
      pdHandler := vHvi(92 downto 61);
      vDqpn     := vHvi(60 downto 37);
      vQkey     := vHvi(36 downto 5);
      vIsCnp    := vHvi(4);
      vIsResp   := vHvi(3);
      vResp     := vIsResp or vIsCnp;
      if vResp = '1' then
         selTypeQP := sqTypeQP; selErr := sqIsERR; selRts := sqIsRTS;
         selNonErr := sqIsNonErr; selQkey := sqQKEY;
      else
         selTypeQP := rqTypeQP; selErr := rqIsERR; selRts := rqIsRTS;
         selNonErr := rqIsNonErr; selQkey := rqQKEY;
      end if;
      if vMaybe = '1' then
         isValidHdr := ite(validateHeader(vBth(95 downto 93), vQkey, selTypeQP,
                                          selErr, selRts, selNonErr, selQkey, vResp), '1', '0');
      else
         isValidHdr := '0';
         pdHandler  := (others => '0');  -- dontCareValue
      end if;
      if isFirst = '1' then
         canFire := (payloadValidationQValid = '1') and (rdmaHeaderValidationQValid = '1')
                    and (rdmaHeaderFilterQNotFull = '1') and (payloadFilterQNotFull = '1');
         if canFire then
            vhInfo := pdHandler         -- pdHandler [64:33]
                      & vDqpn           -- dqpn [32:9]
                      & sqPMTU          -- pmtu (always from SQ) [8:6]
                      & isValidHdr      -- isValidHeader [5]
                      & vIsCnp          -- isCNP [4]
                      & vIsResp         -- isRespPkt [3]
                      & vHvi(2)         -- isLastPkt [2]
                      & vHvi(1)         -- isFirstOrMidPkt [1]
                      & vHvi(0);        -- isLastOrOnlyPkt [0]
            payloadValidationQRdEn    <= '1';
            rdmaHeaderValidationQRdEn <= '1';
            rdmaHeaderFilterQWrEn     <= '1';
            rdmaHeaderFilterQDin      <= vHdr & vBth & vhInfo;
            payloadFilterQWrEn        <= '1';
            payloadFilterQDin         <= frag;
         end if;
      else
         canFire := (payloadValidationQValid = '1') and (payloadFilterQNotFull = '1');
         if canFire then
            payloadValidationQRdEn <= '1';
            payloadFilterQWrEn     <= '1';
            payloadFilterQDin      <= frag;
         end if;
      end if;

      --------------------------------------------------------------------
      -- Rule 6: discardInvalidHeaderPkt  (table B row4; writes isValidPktReg; CNP fork)
      --------------------------------------------------------------------
      frag        := payloadFilterQDout;
      isFirst     := payloadFilterQDout(1);
      fHdr        := rdmaHeaderFilterQDout(FILT_W_C-1 downto FILT_W_C-HDR_W_C);  -- [753:161]
      fBth        := rdmaHeaderFilterQDout(160 downto 65);
      fVhi        := rdmaHeaderFilterQDout(64 downto 0);
      fIsValidHdr := fVhi(5);
      fIsCnp      := fVhi(4);
      cnpIdx      := ite(MAX_QP_G > 1, to_integer(unsigned(fBth(55 downto 56-QP_IDX_W_C))), 0);  -- getIndexQP(bth.dqpn): dqpn=[55:32], top log2(MAX_QP_G) bits; constant 0 at MAX_QP_G=1
      if isFirst = '1' then
         isValidEff := fIsValidHdr and (not fIsCnp);
      else
         isValidEff := r.isValidPkt;
      end if;
      needFrag := (isFirst = '1') and (fIsValidHdr = '1') and (fIsCnp = '0');
      needCnp  := (isFirst = '1') and (fIsValidHdr = '1') and (fIsCnp = '1');
      needPay  := (isValidEff = '1');
      fragOk   := (not needFrag) or (rdmaHeaderFragLenCalcQNotFull = '1');
      cnpOk    := (not needCnp) or (cnpNotFullA(cnpIdx) = '1');
      payOk    := (not needPay) or (payloadFragLenCalcQNotFull = '1');
      canFire  := (payloadFilterQValid = '1') and fragOk and cnpOk and payOk;
      if isFirst = '1' then
         canFire := canFire and (rdmaHeaderFilterQValid = '1');
      end if;
      if canFire then
         payloadFilterQRdEn <= '1';
         if isFirst = '1' then
            rdmaHeaderFilterQRdEn <= '1';
            v.isValidPkt          := isValidEff;
            if needFrag then
               rdmaHeaderFragLenCalcQWrEn <= '1';
               rdmaHeaderFragLenCalcQDin  <= fHdr & fBth & fVhi;
            elsif needCnp then
               cnpWrEnA(cnpIdx) <= '1';
               cnpDinA(cnpIdx)  <= fBth;
            end if;
         end if;
         if needPay then
            payloadFragLenCalcQWrEn <= '1';
            payloadFragLenCalcQDin  <= frag;
         end if;
      end if;

      --------------------------------------------------------------------
      -- Rule 7: calcFraglen  (table B row5; writes bthPadCntReg)
      --------------------------------------------------------------------
      frag    := payloadFragLenCalcQDout;
      isFirst := payloadFragLenCalcQDout(1);
      clHdr   := rdmaHeaderFragLenCalcQDout(FILT_W_C-1 downto FILT_W_C-HDR_W_C);
      clBth   := rdmaHeaderFragLenCalcQDout(160 downto 65);
      clVhi   := rdmaHeaderFragLenCalcQDout(64 downto 0);
      if isFirst = '1' then
         clPadCnt := clBth(85 downto 84);
      else
         clPadCnt := r.bthPadCnt;
      end if;
      fbn          := calcFragByteNum(frag(33 downto 2));
      fragLen      := fbn.num;
      byteEnNZ     := ite(not isZeroByteEn(frag(33 downto 2)), '1', '0');
      byteEnAll    := ite(frag(33 downto 2) = BYTEEN_ONES_C, '1', '0');
      fragLenNoPad := slv(unsigned(fragLen) - resize(unsigned(clPadCnt), 6));  -- fragLen - zeroExt(bthPadCnt)
      canFire      := (payloadFragLenCalcQValid = '1') and (payloadPktLenCalcQNotFull = '1');
      if isFirst = '1' then
         canFire := canFire and (rdmaHeaderFragLenCalcQValid = '1') and (rdmaHeaderPktLenCalcQNotFull = '1');
      end if;
      if canFire then
         payloadFragLenCalcQRdEn <= '1';
         if isFirst = '1' then
            rdmaHeaderFragLenCalcQRdEn <= '1';
            v.bthPadCnt                := clPadCnt;
            rdmaHeaderPktLenCalcQWrEn  <= '1';
            rdmaHeaderPktLenCalcQDin   <= clHdr & clBth & clVhi;
         end if;
         payloadPktLenCalcQWrEn <= '1';
         payloadPktLenCalcQDin  <= frag & fragLen & fragLenNoPad & byteEnNZ & byteEnAll;
      end if;

      --------------------------------------------------------------------
      -- Rule 8: calcPktLen  (table B row6 + datapath sub-table)
      --   reads rdmaHeaderPktLenCalcQ head every fire; deq only on isLast.
      --------------------------------------------------------------------
      pFrag         := payloadPktLenCalcQDout(PLC_W_C-1 downto PLC_W_C-DS_W_C);  -- [303:14]
      pFragLen      := payloadPktLenCalcQDout(13 downto 8);
      pFragLenNoPad := payloadPktLenCalcQDout(7 downto 2);
      pByteEnNZ     := payloadPktLenCalcQDout(1);
      pByteEnAll    := payloadPktLenCalcQDout(0);
      pIsFirst      := pFrag(1);
      pIsLast       := pFrag(0);
      pFragNoPad    := pFrag;
      if pIsLast = '1' then
         pFragNoPad(33 downto 2) := genByteEn(pFragLenNoPad);
      end if;
      pHdr          := rdmaHeaderPktLenCalcQDout(FILT_W_C-1 downto FILT_W_C-HDR_W_C);
      pBth          := rdmaHeaderPktLenCalcQDout(160 downto 65);
      pVhi          := rdmaHeaderPktLenCalcQDout(64 downto 0);
      pIsRespPkt    := pVhi(3);
      pIsLastPkt    := pVhi(2);
      pIsFirstOrMid := pVhi(1);
      pIsLastOrOnly := pVhi(0);
      pQpIdx        := ite(MAX_QP_G > 1, to_integer(unsigned(pVhi(32 downto 33-QP_IDX_W_C))), 0);  -- getIndexQP(vhi.dqpn): dqpn=[32:9], top log2(MAX_QP_G) bits; constant 0 at MAX_QP_G=1
      -- {isFirst,isLast} case
      if (pIsFirst = '1') and (pIsLast = '1') then
         newPktLen  := slv(resize(unsigned(pFragLenNoPad), 13));
         newFragNum := slv(to_unsigned(1, 8));
         if pIsFirstOrMid = '1' then
            newValid := '0';
         elsif pIsLastPkt = '1' then
            newValid := pByteEnNZ;
         else
            newValid := '1';
         end if;
      elsif (pIsFirst = '1') and (pIsLast = '0') then
         newPktLen  := slv(to_unsigned(32, 13));  -- DATA_BUS_BYTE_WIDTH
         newFragNum := slv(to_unsigned(1, 8));
         newValid   := pByteEnAll;
      elsif (pIsFirst = '0') and (pIsLast = '1') then
         newPktLen  := pktLenAddFragLen(r.pktLen, pFragLenNoPad);
         newFragNum := slv(unsigned(r.pktFragNum) + 1);
         newValid   := r.pktValid;
      else
         newPktLen  := pktLenAddBusByteWidth(r.pktLen);
         newFragNum := slv(unsigned(r.pktFragNum) + 1);
         newValid   := r.pktValid and pByteEnAll;
      end if;
      canFire := (payloadPktLenCalcQValid = '1') and (rdmaHeaderPktLenCalcQValid = '1')
                 and (payloadPktLenPreCheckQNotFull = '1');
      if pIsLast = '1' then
         canFire := canFire and (rdmaHeaderPktLenPreCheckQNotFull = '1');
      end if;
      if canFire then
         payloadPktLenCalcQRdEn <= '1';
         v.pktLen               := newPktLen;
         v.pktValid             := newValid;
         v.pktFragNum           := newFragNum;
         if pIsLast = '1' then
            rdmaHeaderPktLenCalcQRdEn <= '1';
            plci                      := pBth(95 downto 93)  -- trans
                    & pBth(92 downto 88)          -- opcode
                    & pBth(85 downto 84)          -- padCnt
                    & pBth(23 downto 0)           -- psn
                    & pVhi(32 downto 9)           -- dqpn
                    & pHdr              -- rdmaHeader
                    & pVhi(64 downto 33)          -- pdHandler
                    & newFragNum        -- pktFragNum
                    & newPktLen         -- pktLen
                    & pVhi(8 downto 6)  -- pmtu
                    & newValid          -- pktValid
                    & pIsFirstOrMid     -- isFirstOrMidPkt
                    & pIsLastOrOnly;    -- isLastOrOnlyPkt
            rdmaHeaderPktLenPreCheckQWrEn <= '1';
            rdmaHeaderPktLenPreCheckQDin  <= plci;
         end if;
         payloadPktLenPreCheckQWrEn <= '1';
         -- qpIdx field: constant 0 at MAX_QP_G=1 (getIndexQP of a 0-bit index)
         payloadPktLenPreCheckQDin  <= pFragNoPad & ite(MAX_QP_G > 1, pVhi(32 downto 33-QP_IDX_W_C), "0") & pIsRespPkt;
      end if;

      --------------------------------------------------------------------
      -- Rule 9: preCheckPktLen  (table B row7)
      --------------------------------------------------------------------
      preFrag   := payloadPktLenPreCheckQDout(PL3_W_C-1 downto QP_IDX_W_C+1);
      preQpIdx  := payloadPktLenPreCheckQDout(QP_IDX_W_C downto 1);
      preIsResp := payloadPktLenPreCheckQDout(0);
      preIsLast := preFrag(0);
      prePlci   := rdmaHeaderPktLenPreCheckQDout;
      isZeroLen := ite(unsigned(prePlci(18 downto 6)) = 0, '1', '0');  -- isZeroR(pktLen)
      isEqPmtu  := ite(pktLenEqPMTU(prePlci(18 downto 6), prePlci(5 downto 3)), '1', '0');
      isGtPmtu  := ite(pktLenGtPMTU(prePlci(18 downto 6), prePlci(5 downto 3)), '1', '0');
      canFire   := (payloadPktLenPreCheckQValid = '1') and (payloadPktLenCheckQNotFull = '1');
      if preIsLast = '1' then
         canFire := canFire and (rdmaHeaderPktLenPreCheckQValid = '1') and (rdmaHeaderPktLenCheckQNotFull = '1');
      end if;
      if canFire then
         payloadPktLenPreCheckQRdEn <= '1';
         if preIsLast = '1' then
            rdmaHeaderPktLenPreCheckQRdEn <= '1';
            rdmaHeaderPktLenCheckQWrEn    <= '1';
            rdmaHeaderPktLenCheckQDin     <= prePlci & isZeroLen & isEqPmtu & isGtPmtu;
         end if;
         payloadPktLenCheckQWrEn <= '1';
         payloadPktLenCheckQDin  <= preFrag & preQpIdx & preIsResp;
      end if;

      --------------------------------------------------------------------
      -- Rule 10: checkPktLen  (table B row8; builds RdmaPktMetaData, PMTU verdict)
      --------------------------------------------------------------------
      ckFrag    := payloadPktLenCheckQDout(PL3_W_C-1 downto QP_IDX_W_C+1);
      ckQpIdx   := payloadPktLenCheckQDout(QP_IDX_W_C downto 1);
      ckIsResp  := payloadPktLenCheckQDout(0);
      ckIsLast  := ckFrag(0);
      ckPlci    := rdmaHeaderPktLenCheckQDout(PCHK4_W_C-1 downto 3);
      ckZeroLen := rdmaHeaderPktLenCheckQDout(2);
      ckEqPmtu  := rdmaHeaderPktLenCheckQDout(1);
      ckGtPmtu  := rdmaHeaderPktLenCheckQDout(0);
      -- pktValid recompute (only meaningful when plci.pktValid; else stays false)
      if ckPlci(2) = '1' then
         ckValid := ite(((ckPlci(1) = '1') and (ckEqPmtu = '1'))
                        or ((ckPlci(0) = '1') and (ckGtPmtu = '0')), '1', '0');
      else
         ckValid := '0';
      end if;
      ckStatus := ite(ckValid = '1', PKT_ST_VALID_C, PKT_ST_LEN_ERR_C);
      -- RdmaPktMetaData
      meta     := ckPlci(18 downto 6)   -- pktPayloadLen (pktLen)
              & ite(ckZeroLen = '1', slv(to_unsigned(0, 8)), ckPlci(26 downto 19))  -- pktFragNum
              & ckZeroLen               -- isZeroPayloadLen
              & ckPlci(651 downto 59)   -- pktHeader (rdmaHeader)
              & ckPlci(58 downto 27)    -- pdHandler
              & ckValid                 -- pktValid
              & ckStatus;               -- pktStatus
      if ckIsLast = '1' then
         -- enq rdmaHeaderOutputQ always; enq payloadOutputQ only if !isZeroPayloadLen
         canFire := (payloadPktLenCheckQValid = '1') and (rdmaHeaderPktLenCheckQValid = '1')
                    and (rdmaHeaderOutputQNotFull = '1');
         if ckZeroLen = '0' then
            canFire := canFire and (payloadOutputQNotFull = '1');
         end if;
         if canFire then
            payloadPktLenCheckQRdEn    <= '1';
            rdmaHeaderPktLenCheckQRdEn <= '1';
            rdmaHeaderOutputQWrEn      <= '1';
            rdmaHeaderOutputQDin       <= meta & ckQpIdx & ckIsResp;
            if ckZeroLen = '0' then
               payloadOutputQWrEn <= '1';
               payloadOutputQDin  <= ckFrag & ckQpIdx & ckIsResp;
            end if;
         end if;
      else
         canFire := (payloadPktLenCheckQValid = '1') and (payloadOutputQNotFull = '1');
         if canFire then
            payloadPktLenCheckQRdEn <= '1';
            payloadOutputQWrEn      <= '1';
            payloadOutputQDin       <= ckFrag & ckQpIdx & ckIsResp;
         end if;
      end if;

      --------------------------------------------------------------------
      -- Rule 11: outputPayload  (table B row9)
      --------------------------------------------------------------------
      oQpIdx  := to_integer(unsigned(payloadOutputQDout(QP_IDX_W_C downto 1)));
      oIsResp := payloadOutputQDout(0);
      if payloadOutputQValid = '1' then
         if oIsResp = '1' then
            if respPayloadNotFullA(oQpIdx) = '1' then
               payloadOutputQRdEn       <= '1';
               respPayloadWrEnA(oQpIdx) <= '1';
               respPayloadDinA(oQpIdx)  <= payloadOutputQDout(PL3_W_C-1 downto QP_IDX_W_C+1);
            end if;
         else
            if reqPayloadNotFullA(oQpIdx) = '1' then
               payloadOutputQRdEn      <= '1';
               reqPayloadWrEnA(oQpIdx) <= '1';
               reqPayloadDinA(oQpIdx)  <= payloadOutputQDout(PL3_W_C-1 downto QP_IDX_W_C+1);
            end if;
         end if;
      end if;

      --------------------------------------------------------------------
      -- Rule 12: outputHeaderMetaData  (table B row10)
      --------------------------------------------------------------------
      oQpIdx  := to_integer(unsigned(rdmaHeaderOutputQDout(QP_IDX_W_C downto 1)));
      oIsResp := rdmaHeaderOutputQDout(0);
      if rdmaHeaderOutputQValid = '1' then
         if oIsResp = '1' then
            if respMetaNotFullA(oQpIdx) = '1' then
               rdmaHeaderOutputQRdEn <= '1';
               respMetaWrEnA(oQpIdx) <= '1';
               respMetaDinA(oQpIdx)  <= rdmaHeaderOutputQDout(HDROUT_W_C-1 downto QP_IDX_W_C+1);
            end if;
         else
            if reqMetaNotFullA(oQpIdx) = '1' then
               rdmaHeaderOutputQRdEn <= '1';
               reqMetaWrEnA(oQpIdx)  <= '1';
               reqMetaDinA(oQpIdx)   <= rdmaHeaderOutputQDout(HDROUT_W_C-1 downto QP_IDX_W_C+1);
            end if;
         end if;
      end if;

      -- synchronous reset
      if rst = '1' then
         v := REG_INIT_C;
      end if;

      rin <= v;
   end process comb;

   ---------------------------------------------------------------------------
   -- Sequential process
   ---------------------------------------------------------------------------
   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin;
      end if;
   end process seq;

end architecture rtl;
