-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   PURELY COMBINATIONAL (Mealy) datapath — no clock, no reset, no state, no SURF
--   instances. Reproduces the SQ request-header packers
--       genFirstOrOnlyReqHeader(...)  (isFirstOrOnly = '1')
--       genMiddleOrLastReqHeader(...) (isFirstOrOnly = '0')
--   which each return Maybe#(Tuple3#(HeaderData, HeaderByteNum, Bool)). This entity
--   emits that tuple as three ports (headerData/headerByteNum/hasPayload) plus the
--   Maybe tag (headerValid). The caller (ReqGenSq.prepareReqHeaderGen, R8) enqueues
--   {headerData, headerByteNum, hasPayload} into pendingReqHeaderQ when headerValid;
--   the subsequent genHeaderRDMA (R9) turns headerData+headerByteNum into the packed
--   HeaderRDMA (byteEn + metaData) — that step stays in the integrator, matching the
--   BSV structure (this leaf = the two gen*ReqHeader functions ONLY).
--
--   Packing is first-field-at-MSB; the header is left-aligned in headerData
--   (zeroExtendLSB), canonical order:  bth . xrceth? . mid? . tail?
--     mid  in {RETH, DETH, AtomicEth},  tail in {ImmDt, IETH}.  (NO LETH on the
--     request path — RDMA_READ requests carry RETH only.)
--
--   Header struct byte widths (Headers.bsv): BTH 12, XRCETH 4, DETH 8, RETH 16,
--     AtomicEth 28, ImmDt 4, IETH 4.  HeaderData = 512 b, HeaderByteNum = 7 b.
--
--   headerValid='0' means the (opcode,qpType) combination is unsupported (Maybe
--   Invalid) — the caller must deq WITHOUT enq (genReqHeader R9 skips the enq).
--
--   Differences vs the SendQ HeaderGenRDMA leaf (same struct packing, different
--   selection): (1) BTH.solicited = wr.solicited is UNGATED here; (2) BTH.pkey is a
--   real input (cntrlStatus.comm.getPKEY), not dontCare; (3) dqpn = (qpType=UD) ?
--   wr.dqpn : comm.getDQPN; (4) middle/last supports only RC and XRC_SEND (no UC, no
--   UD); (5) RDMA_READ/ATOMIC are first/only-only and carry no payload.
--
--   Maybe-field assumption (mirrors HeaderGenRDMA / guaranteed by ReqGenSq.recvWorkReq
--   immAsserts): srqn/qkey/swap/comp/immDt/rkey2Inv/dqpn(UD) are Valid whenever the
--   selected arm uses them, so their raw data ports are consumed directly.
--
--   OQ-EMIT-HGRSQ-01 (NON-BLOCKING): genMiddleOrLastReqHeader has NO IBV_QPT_UC arm
--   for RDMA_WRITE (BSV source), so a multi-packet UC RDMA_WRITE middle/last yields
--   headerValid='0'. Reproduced faithfully; flagged in case it is a source quirk.
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

entity HeaderGenReqSQ is
   generic (
      TPD_G : time := 1 ns);  -- unused (no registers); kept for SURF consistency
   port (
      -- Per-packet control (from ReqPktHeaderInfo / countReqPkt)
      isFirstOrOnly : in  sl;  -- '1' genFirstOrOnlyReqHeader, '0' genMiddleOrLastReqHeader
      isOnlyOrLast  : in  sl;  -- isOnlyReqPkt (first) / isLastReqPkt (middle/last)
      psn           : in  slv(23 downto 0);  -- BTH.psn (curPSN)
      -- cntrlStatus fields
      qpType        : in  slv(3 downto 0);   -- getTypeQP
      pkey          : in  slv(15 downto 0);  -- comm.getPKEY -> BTH.pkey
      sigAll        : in  sl;           -- comm.getSigAll
      commDqpn      : in  slv(23 downto 0);  -- comm.getDQPN (RC/UC/XRC dest QPN)
      sqpn          : in  slv(23 downto 0);  -- comm.getSQPN -> DETH.sqpn
      -- WorkReq-derived fields
      opcode        : in  slv(3 downto 0);   -- WorkReqOpCode
      solicited     : in  sl;           -- wr.solicited (ungated)
      sendSignaled  : in  sl;  -- wr.flags contains IBV_SEND_SIGNALED (workReqHasAckReq)
      len           : in  slv(31 downto 0);  -- wr.len (Length) -> RETH.dlen, calcPadCnt, hasPayload
      raddr         : in  slv(63 downto 0);  -- wr.raddr -> RETH.va / AtomicEth.va
      rkey          : in  slv(31 downto 0);  -- wr.rkey  -> RETH.rkey / AtomicEth.rkey
      wrDqpn        : in  slv(23 downto 0);  -- wr.dqpn unwrapped (UD dest QPN)
      srqn          : in  slv(23 downto 0);  -- wr.srqn unwrapped -> XRCETH.srqn
      qkey          : in  slv(31 downto 0);  -- wr.qkey unwrapped -> DETH.qkey
      swapData      : in  slv(63 downto 0);  -- wr.swap unwrapped -> AtomicEth.swap
      compData      : in  slv(63 downto 0);  -- wr.comp unwrapped -> AtomicEth.comp
      immDtData     : in  slv(31 downto 0);  -- wr.immDt unwrapped -> ImmDt.data
      invRkey       : in  slv(31 downto 0);  -- wr.rkey2Inv unwrapped -> IETH.rkey
      -- Outputs (the Maybe#(Tuple3#(HeaderData, HeaderByteNum, Bool)))
      headerValid   : out sl;           -- Maybe tag
      headerData    : out slv(511 downto 0);  -- HeaderData (left-aligned)
      headerByteNum : out slv(6 downto 0);   -- HeaderByteNum (byte length)
      hasPayload    : out sl);          -- the tuple's Bool
end entity HeaderGenReqSQ;

architecture rtl of HeaderGenReqSQ is

   -- TypeQP encoding (4 bits; DataTypes.bsv:388)
   constant QPT_RC_C       : slv(3 downto 0) := x"2";
   constant QPT_UC_C       : slv(3 downto 0) := x"3";
   constant QPT_UD_C       : slv(3 downto 0) := x"4";
   constant QPT_XRC_SEND_C : slv(3 downto 0) := x"9";
   constant QPT_XRC_RECV_C : slv(3 downto 0) := x"A";

   -- WorkReqOpCode encoding (4 bits; DataTypes.bsv:490-510)
   constant WR_RDMA_WRITE_C          : slv(3 downto 0) := x"0";
   constant WR_RDMA_WRITE_WITH_IMM_C : slv(3 downto 0) := x"1";
   constant WR_SEND_C                : slv(3 downto 0) := x"2";
   constant WR_SEND_WITH_IMM_C       : slv(3 downto 0) := x"3";
   constant WR_RDMA_READ_C           : slv(3 downto 0) := x"4";
   constant WR_ATOMIC_CMP_AND_SWP_C  : slv(3 downto 0) := x"5";
   constant WR_ATOMIC_FETCH_ADD_C    : slv(3 downto 0) := x"6";
   constant WR_SEND_WITH_INV_C       : slv(3 downto 0) := x"9";

   -- TransType encoding (3 bits; Headers.bsv:96)
   constant TRANS_RC_C  : slv(2 downto 0) := "000";
   constant TRANS_UC_C  : slv(2 downto 0) := "001";
   constant TRANS_UD_C  : slv(2 downto 0) := "011";
   constant TRANS_XRC_C : slv(2 downto 0) := "101";

   -- RdmaOpCode encoding (5 bits; Headers.bsv:125)
   constant OP_SEND_FIRST_C     : slv(4 downto 0) := "00000";  -- 0x00
   constant OP_SEND_MIDDLE_C    : slv(4 downto 0) := "00001";  -- 0x01
   constant OP_SEND_LAST_C      : slv(4 downto 0) := "00010";  -- 0x02
   constant OP_SEND_LAST_IMM_C  : slv(4 downto 0) := "00011";  -- 0x03
   constant OP_SEND_ONLY_C      : slv(4 downto 0) := "00100";  -- 0x04
   constant OP_SEND_ONLY_IMM_C  : slv(4 downto 0) := "00101";  -- 0x05
   constant OP_WRITE_FIRST_C    : slv(4 downto 0) := "00110";  -- 0x06
   constant OP_WRITE_MIDDLE_C   : slv(4 downto 0) := "00111";  -- 0x07
   constant OP_WRITE_LAST_C     : slv(4 downto 0) := "01000";  -- 0x08
   constant OP_WRITE_LAST_IMM_C : slv(4 downto 0) := "01001";  -- 0x09
   constant OP_WRITE_ONLY_C     : slv(4 downto 0) := "01010";  -- 0x0a
   constant OP_WRITE_ONLY_IMM_C : slv(4 downto 0) := "01011";  -- 0x0b
   constant OP_READ_REQUEST_C   : slv(4 downto 0) := "01100";  -- 0x0c
   constant OP_COMPARE_SWAP_C   : slv(4 downto 0) := "10011";  -- 0x13
   constant OP_FETCH_ADD_C      : slv(4 downto 0) := "10100";  -- 0x14
   constant OP_SEND_LAST_INV_C  : slv(4 downto 0) := "10110";  -- 0x16
   constant OP_SEND_ONLY_INV_C  : slv(4 downto 0) := "10111";  -- 0x17

   -- Extension-header slot selectors (request path: no LETH)
   type MiddleType is (MID_NONE, MID_RETH, MID_DETH, MID_ATOMIC);
   type TailType is (TAIL_NONE, TAIL_IMM, TAIL_IETH);

begin

   comb : process (isFirstOrOnly, isOnlyOrLast, psn, qpType, pkey, sigAll,
                   commDqpn, sqpn, opcode, solicited, sendSignaled, len, raddr,
                   rkey, wrDqpn, srqn, qkey, swapData, compData, immDtData, invRkey) is
      variable trans      : slv(2 downto 0);
      variable transValid : sl;
      variable opc5       : slv(4 downto 0);
      variable opcValid   : sl;
      variable dqpnSel    : slv(23 downto 0);
      variable isReadAtom : sl;
      variable lenNonZero : sl;
      variable incTail    : sl;
      variable padRaw     : unsigned(3 downto 0);
      variable padCnt     : slv(1 downto 0);
      variable padGate    : sl;
      variable padEff     : slv(1 downto 0);
      variable ackReq     : sl;
      variable bthBits    : slv(95 downto 0);
      variable rethBits   : slv(127 downto 0);
      variable atomicBits : slv(223 downto 0);
      variable xrcethBits : slv(31 downto 0);
      variable dethBits   : slv(63 downto 0);
      variable immBits    : slv(31 downto 0);
      variable iethBits   : slv(31 downto 0);
      variable useXrceth  : sl;
      variable midSel     : MiddleType;
      variable tailSel    : TailType;
      variable armValid   : sl;
      variable hasPl      : sl;
      variable slvHeader  : slv(511 downto 0);
      variable hlen       : integer range 0 to 63;
      variable pos        : integer range 0 to 512;
   begin

      -----------------------------------------------------------------------
      -- 1. TransType = qpType2TransType(qpType)  (Utils.bsv:741)
      -----------------------------------------------------------------------
      transValid := '1';
      case qpType is
         when QPT_RC_C                        => trans := TRANS_RC_C;
         when QPT_UC_C                        => trans := TRANS_UC_C;
         when QPT_UD_C                        => trans := TRANS_UD_C;
         when QPT_XRC_SEND_C | QPT_XRC_RECV_C => trans := TRANS_XRC_C;
         when others                          => trans := (others => '0'); transValid := '0';
      end case;

      -----------------------------------------------------------------------
      -- 2. RdmaOpCode = gen{FirstOrOnly|MiddleOrLast}ReqRdmaOpCode (ReqGenSQ.bsv:24-47)
      -----------------------------------------------------------------------
      opc5     := (others => '0');
      opcValid := '1';
      if (isFirstOrOnly = '1') then
         case opcode is
            when WR_RDMA_WRITE_C          => opc5 := ite(isOnlyOrLast = '1', OP_WRITE_ONLY_C, OP_WRITE_FIRST_C);
            when WR_RDMA_WRITE_WITH_IMM_C => opc5 := ite(isOnlyOrLast = '1', OP_WRITE_ONLY_IMM_C, OP_WRITE_FIRST_C);
            when WR_SEND_C                => opc5 := ite(isOnlyOrLast = '1', OP_SEND_ONLY_C, OP_SEND_FIRST_C);
            when WR_SEND_WITH_IMM_C       => opc5 := ite(isOnlyOrLast = '1', OP_SEND_ONLY_IMM_C, OP_SEND_FIRST_C);
            when WR_SEND_WITH_INV_C       => opc5 := ite(isOnlyOrLast = '1', OP_SEND_ONLY_INV_C, OP_SEND_FIRST_C);
            when WR_RDMA_READ_C           => opc5 := OP_READ_REQUEST_C;
            when WR_ATOMIC_CMP_AND_SWP_C  => opc5 := OP_COMPARE_SWAP_C;
            when WR_ATOMIC_FETCH_ADD_C    => opc5 := OP_FETCH_ADD_C;
            when others                   => opc5 := (others => '0'); opcValid := '0';
         end case;
      else
         case opcode is
            when WR_RDMA_WRITE_C          => opc5 := ite(isOnlyOrLast = '1', OP_WRITE_LAST_C, OP_WRITE_MIDDLE_C);
            when WR_RDMA_WRITE_WITH_IMM_C => opc5 := ite(isOnlyOrLast = '1', OP_WRITE_LAST_IMM_C, OP_WRITE_MIDDLE_C);
            when WR_SEND_C                => opc5 := ite(isOnlyOrLast = '1', OP_SEND_LAST_C, OP_SEND_MIDDLE_C);
            when WR_SEND_WITH_IMM_C       => opc5 := ite(isOnlyOrLast = '1', OP_SEND_LAST_IMM_C, OP_SEND_MIDDLE_C);
            when WR_SEND_WITH_INV_C       => opc5 := ite(isOnlyOrLast = '1', OP_SEND_LAST_INV_C, OP_SEND_MIDDLE_C);
            when others                   => opc5 := (others => '0'); opcValid := '0';
         end case;
      end if;

      -----------------------------------------------------------------------
      -- 3. dqpn = getMaybeDestQpnSQ : UD -> wr.dqpn ; RC/UC/XRC_SEND -> comm.getDQPN
      -----------------------------------------------------------------------
      dqpnSel := ite(qpType = QPT_UD_C, wrDqpn, commDqpn);

      -- isReadOrAtomicWorkReq(opcode) ; workReqHasPayload uses !isZero(len)
      case opcode is
         when WR_RDMA_READ_C | WR_ATOMIC_CMP_AND_SWP_C | WR_ATOMIC_FETCH_ADD_C =>
            isReadAtom := '1';
         when others =>
            isReadAtom := '0';
      end case;
      lenNonZero := toSl(unsigned(len) /= 0);
      incTail    := isOnlyOrLast;

      -----------------------------------------------------------------------
      -- 4. padCnt = calcPadCnt(len) = (1<<PAD_WIDTH) - len[1:0]  (2 bits)
      --    gated: first/only -> isOnly && !readAtomic ; middle/last -> isLast
      -----------------------------------------------------------------------
      padRaw := to_unsigned(4, 4) - resize(unsigned(len(1 downto 0)), 4);
      padCnt := slv(padRaw(1 downto 0));
      if (isFirstOrOnly = '1') then
         padGate := isOnlyOrLast and (not isReadAtom);
      else
         padGate := isOnlyOrLast;
      end if;
      padEff := ite(padGate = '1', padCnt, "00");

      -- ackReq = getSigAll || (isOnlyOrLast && workReqRequireAck)
      --   workReqRequireAck = workReqHasAckReq(signaled) || isReadOrAtomic
      ackReq := sigAll or (isOnlyOrLast and (sendSignaled or isReadAtom));

      -----------------------------------------------------------------------
      -- 5. BTH assembly (first-field-at-MSB, 96 bits; Headers.bsv:153-168)
      --    solicited UNGATED; pkey is a real input.
      -----------------------------------------------------------------------
      bthBits := trans                  -- [95:93] trans
                 & opc5                 -- [92:88] opcode
                 & solicited            -- [87]    solicited (ungated)
                 & '0'                  -- [86]    migReq
                 & padEff               -- [85:84] padCnt
                 & "0000"               -- [83:80] tver
                 & pkey                 -- [79:64] pkey
                 & '0'                  -- [63]    fecn
                 & '0'                  -- [62]    becn
                 & "000000"             -- [61:56] resv6
                 & dqpnSel              -- [55:32] dqpn
                 & ackReq               -- [31]    ackReq
                 & "0000000"            -- [30:24] resv7
                 & psn;                 -- [23:0]  psn

      -----------------------------------------------------------------------
      -- 6. Extension sub-headers (first-field-at-MSB)
      -----------------------------------------------------------------------
      rethBits   := raddr & rkey & len;   -- RETH   128 (va,rkey,dlen)
      atomicBits := raddr & rkey & swapData & compData;  -- Atomic 224 (va,rkey,swap,comp)
      xrcethBits := x"00" & srqn;       -- XRCETH  32 (rsvd,srqn)
      dethBits   := qkey & x"00" & sqpn;  -- DETH    64 (qkey,rsvd,sqpn)
      immBits    := immDtData;          -- ImmDt   32 (data)
      iethBits   := invRkey;            -- IETH    32 (rkey)

      -----------------------------------------------------------------------
      -- 7. Slot selection per (isFirstOrOnly, opcode, qpType) (ReqGenSQ.bsv:159-306 / 347-448)
      -----------------------------------------------------------------------
      useXrceth := '0';
      midSel    := MID_NONE;
      tailSel   := TAIL_NONE;
      armValid  := '0';

      if (isFirstOrOnly = '1') then
         -- genFirstOrOnlyReqHeader
         case opcode is
            when WR_RDMA_WRITE_C =>
               case qpType is
                  when QPT_RC_C | QPT_UC_C => midSel    := MID_RETH; armValid := '1';
                  when QPT_XRC_SEND_C      => useXrceth := '1'; midSel := MID_RETH; armValid := '1';
                  when others              => null;
               end case;

            when WR_RDMA_WRITE_WITH_IMM_C =>
               case qpType is
                  when QPT_RC_C | QPT_UC_C =>
                     midSel                          := MID_RETH;
                     if (incTail = '1') then tailSel := TAIL_IMM; end if;
                     armValid                        := '1';
                  when QPT_XRC_SEND_C =>
                     useXrceth                       := '1'; midSel := MID_RETH;
                     if (incTail = '1') then tailSel := TAIL_IMM; end if;
                     armValid                        := '1';
                  when others => null;
               end case;

            when WR_SEND_C =>
               case qpType is
                  when QPT_RC_C | QPT_UC_C => armValid  := '1';  -- bth only
                  when QPT_UD_C            => midSel    := MID_DETH; armValid := '1';
                  when QPT_XRC_SEND_C      => useXrceth := '1'; armValid := '1';
                  when others              => null;
               end case;

            when WR_SEND_WITH_IMM_C =>
               case qpType is
                  when QPT_RC_C | QPT_UC_C =>
                     if (incTail = '1') then tailSel := TAIL_IMM; end if;
                     armValid                        := '1';
                  when QPT_UD_C =>
                     midSel := MID_DETH; tailSel := TAIL_IMM; armValid := '1';  -- UD always only
                  when QPT_XRC_SEND_C =>
                     useXrceth                       := '1';
                     if (incTail = '1') then tailSel := TAIL_IMM; end if;
                     armValid                        := '1';
                  when others => null;
               end case;

            when WR_SEND_WITH_INV_C =>
               case qpType is
                  when QPT_RC_C =>
                     if (incTail = '1') then tailSel := TAIL_IETH; end if;
                     armValid                        := '1';
                  when QPT_XRC_SEND_C =>
                     useXrceth                       := '1';
                     if (incTail = '1') then tailSel := TAIL_IETH; end if;
                     armValid                        := '1';
                  when others => null;
               end case;

            when WR_RDMA_READ_C =>
               case qpType is
                  when QPT_RC_C       => midSel    := MID_RETH; armValid := '1';
                  when QPT_XRC_SEND_C => useXrceth := '1'; midSel := MID_RETH; armValid := '1';
                  when others         => null;
               end case;

            when WR_ATOMIC_CMP_AND_SWP_C | WR_ATOMIC_FETCH_ADD_C =>
               case qpType is
                  when QPT_RC_C       => midSel    := MID_ATOMIC; armValid := '1';
                  when QPT_XRC_SEND_C => useXrceth := '1'; midSel := MID_ATOMIC; armValid := '1';
                  when others         => null;
               end case;

            when others => null;
         end case;

      else
         -- genMiddleOrLastReqHeader (RC / XRC_SEND only; no UC, no UD; hasPayload=True)
         case opcode is
            when WR_RDMA_WRITE_C =>
               case qpType is
                  when QPT_RC_C       => armValid  := '1';  -- bth only
                  when QPT_XRC_SEND_C => useXrceth := '1'; armValid := '1';
                  when others         => null;
               end case;

            when WR_RDMA_WRITE_WITH_IMM_C =>
               case qpType is
                  when QPT_RC_C =>
                     if (incTail = '1') then tailSel := TAIL_IMM; end if;
                     armValid                        := '1';
                  when QPT_XRC_SEND_C =>
                     useXrceth                       := '1';
                     if (incTail = '1') then tailSel := TAIL_IMM; end if;
                     armValid                        := '1';
                  when others => null;
               end case;

            when WR_SEND_C =>
               case qpType is
                  when QPT_RC_C       => armValid  := '1';
                  when QPT_XRC_SEND_C => useXrceth := '1'; armValid := '1';
                  when others         => null;
               end case;

            when WR_SEND_WITH_IMM_C =>
               case qpType is
                  when QPT_RC_C =>
                     if (incTail = '1') then tailSel := TAIL_IMM; end if;
                     armValid                        := '1';
                  when QPT_XRC_SEND_C =>
                     useXrceth                       := '1';
                     if (incTail = '1') then tailSel := TAIL_IMM; end if;
                     armValid                        := '1';
                  when others => null;
               end case;

            when WR_SEND_WITH_INV_C =>
               case qpType is
                  when QPT_RC_C =>
                     if (incTail = '1') then tailSel := TAIL_IETH; end if;
                     armValid                        := '1';
                  when QPT_XRC_SEND_C =>
                     useXrceth                       := '1';
                     if (incTail = '1') then tailSel := TAIL_IETH; end if;
                     armValid                        := '1';
                  when others => null;
               end case;

            when others => null;
         end case;
      end if;

      -----------------------------------------------------------------------
      -- 8. hasPayload : middle/last -> True ; first/only -> workReqHasPayload
      --    (= !(isZero(len) || isReadOrAtomic)); read/atomic arms -> False
      -----------------------------------------------------------------------
      if (isFirstOrOnly = '0') then
         hasPl := '1';
      else
         hasPl := (not isReadAtom) and lenNonZero;
      end if;

      -----------------------------------------------------------------------
      -- 9. Assemble headerData (left-aligned, zeroExtendLSB) + headerByteNum
      -----------------------------------------------------------------------
      slvHeader                 := (others => '0');
      slvHeader(511 downto 416) := bthBits;
      hlen                      := 12;
      pos                       := 416;
      if (useXrceth = '1') then
         slvHeader(pos-1 downto pos-32) := xrcethBits;
         pos                            := pos - 32;
         hlen                           := hlen + 4;
      end if;
      case midSel is
         when MID_RETH =>
            slvHeader(pos-1 downto pos-128) := rethBits; pos := pos - 128; hlen := hlen + 16;
         when MID_DETH =>
            slvHeader(pos-1 downto pos-64) := dethBits; pos := pos - 64; hlen := hlen + 8;
         when MID_ATOMIC =>
            slvHeader(pos-1 downto pos-224) := atomicBits; pos := pos - 224; hlen := hlen + 28;
         when MID_NONE => null;
      end case;
      case tailSel is
         when TAIL_IMM =>
            slvHeader(pos-1 downto pos-32) := immBits; hlen := hlen + 4;
         when TAIL_IETH =>
            slvHeader(pos-1 downto pos-32) := iethBits; hlen := hlen + 4;
         when TAIL_NONE => null;
      end case;

      -----------------------------------------------------------------------
      -- 10. Drive outputs
      -----------------------------------------------------------------------
      headerValid   <= transValid and opcValid and armValid;
      headerData    <= slvHeader;
      headerByteNum <= toSlv(hlen, 7);
      hasPayload    <= hasPl;

   end process comb;

end architecture rtl;
