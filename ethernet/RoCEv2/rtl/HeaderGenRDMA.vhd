-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   PURELY COMBINATIONAL (Mealy) datapath — no clock, no reset, no state, no
--   SURF instances.  Reproduces
--     genHeaderRDMA( genFirstOrOnlyPktHeader(...) | genMiddleOrLastPktHeader(...) )
--   for the NON-raw path.  Given the WQE-derived header fields and the per-packet
--   control (HeaderGenInfo), it emits the 593-bit packed HeaderRDMA word consumed
--   by pktHeaderQ / Header2DataStream, plus headerValid (the Maybe tag).
--
--   Packing is first-field-at-MSB; the header is left-aligned in headerData
--   (zeroExtendLSB), canonical order:  bth . xrceth? . middle? . tail?
--     middle in {RETH, DETH, AtomicEth},  tail in {LETH, ImmDt, IETH}.
--
--   Header struct byte widths (Headers.bsv): BTH 12, XRCETH 4, DETH 8, RETH 16,
--     LETH 16, AtomicEth 28, ImmDt 4, IETH 4.
--
--   HeaderRDMA output bit layout (matches Header2DataStream input [592:0]):
--     [592:81] headerData(512) | [80:17] headerByteEn(64) | [16:10] headerLen(7) |
--     [9:8] headerFragNum(2) | [7:2] lastFragValidByteNum(6) | [1] hasPayload |
--     [0] isEmptyHeader(=0)
--
--   headerValid='0' means the (opcode,qpType) combination is unsupported (Maybe
--   Invalid); the caller (SendQ.genPktHeader) must deq pendingHeaderQ WITHOUT enq.
--
--   Assumption (guaranteed by mkSendQ.recvWQE immAsserts, fsm.md): the Maybe fields
--   the packers unwrap (srqn/qkey/swap/comp/immDtOrInvRKey) are Valid whenever the
--   selected arm uses them, so their raw data ports are used directly.
--
--   OQ-FSM-HGR-01 (NON-BLOCKING): BTH.pkey is dontCareValue in BSV source; emitted
--     as 0.  If PKEY is ever populated upstream, add a pkey input port.
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

entity HeaderGenRDMA is
   generic (
      TPD_G : time := 1 ns);                -- unused (no registers); kept for SURF consistency
   port (
      -- Control (from HeaderGenInfo)
      isFirstOrOnly : in  sl;               -- '1' first/only header, '0' middle/last
      isOnlyOrLast  : in  sl;               -- isOnlyReqPkt / isLastReqPkt
      qpType        : in  slv(3 downto 0);  -- TypeQP
      opcode        : in  slv(3 downto 0);  -- WorkReqOpCode
      solicited     : in  sl;
      ackReq        : in  sl;
      psn           : in  slv(23 downto 0);
      padCnt        : in  slv(1 downto 0);
      remoteAddr    : in  slv(63 downto 0); -- RETH.va
      wqeRaddr      : in  slv(63 downto 0); -- AtomicEth.va (wqe.raddr)
      dlen          : in  slv(31 downto 0); -- RETH/LETH.dlen (Length)
      hasPayloadIn  : in  sl;
      -- WQE-derived header fields
      dqpn          : in  slv(23 downto 0); -- BTH.dqpn
      sqpn          : in  slv(23 downto 0); -- DETH.sqpn
      srqn          : in  slv(23 downto 0); -- XRCETH.srqn (unwrapped)
      qkey          : in  slv(31 downto 0); -- DETH.qkey (unwrapped)
      rkey          : in  slv(31 downto 0); -- RETH/AtomicEth.rkey
      sgeLaddr      : in  slv(63 downto 0); -- LETH.va
      sgeLkey       : in  slv(31 downto 0); -- LETH.lkey
      swapData      : in  slv(63 downto 0); -- AtomicEth.swap
      compData      : in  slv(63 downto 0); -- AtomicEth.comp
      immData       : in  slv(31 downto 0); -- ImmDt.data / IETH.rkey
      -- Outputs
      headerValid   : out sl;               -- Maybe#(PktHeaderInfo) tag
      pktHeaderRdma : out slv(592 downto 0));
end entity HeaderGenRDMA;

architecture rtl of HeaderGenRDMA is

   -- TypeQP encoding (4 bits, explicit BSV values; DataTypes.bsv:388)
   constant QPT_RC_C       : slv(3 downto 0) := x"2";
   constant QPT_UC_C       : slv(3 downto 0) := x"3";
   constant QPT_UD_C       : slv(3 downto 0) := x"4";
   constant QPT_RAW_C      : slv(3 downto 0) := x"8";
   constant QPT_XRC_SEND_C : slv(3 downto 0) := x"9";
   constant QPT_XRC_RECV_C : slv(3 downto 0) := x"A";

   -- WorkReqOpCode encoding (4 bits; DataTypes.bsv:510)
   constant WR_RDMA_WRITE_C          : slv(3 downto 0) := x"0";
   constant WR_RDMA_WRITE_WITH_IMM_C : slv(3 downto 0) := x"1";
   constant WR_SEND_C                : slv(3 downto 0) := x"2";
   constant WR_SEND_WITH_IMM_C       : slv(3 downto 0) := x"3";
   constant WR_RDMA_READ_C           : slv(3 downto 0) := x"4";
   constant WR_ATOMIC_CMP_AND_SWP_C  : slv(3 downto 0) := x"5";
   constant WR_ATOMIC_FETCH_ADD_C    : slv(3 downto 0) := x"6";
   constant WR_SEND_WITH_INV_C       : slv(3 downto 0) := x"9";
   constant WR_RDMA_READ_RESP_C      : slv(3 downto 0) := x"C";

   -- TransType encoding (3 bits; Headers.bsv:96)
   constant TRANS_RC_C  : slv(2 downto 0) := "000";
   constant TRANS_UC_C  : slv(2 downto 0) := "001";
   constant TRANS_UD_C  : slv(2 downto 0) := "011";
   constant TRANS_XRC_C : slv(2 downto 0) := "101";

   -- RdmaOpCode encoding (5 bits; Headers.bsv:125)  [hex value in comment]
   constant OP_SEND_FIRST_C          : slv(4 downto 0) := "00000";  -- 0x00
   constant OP_SEND_MIDDLE_C         : slv(4 downto 0) := "00001";  -- 0x01
   constant OP_SEND_LAST_C           : slv(4 downto 0) := "00010";  -- 0x02
   constant OP_SEND_LAST_IMM_C       : slv(4 downto 0) := "00011";  -- 0x03
   constant OP_SEND_ONLY_C           : slv(4 downto 0) := "00100";  -- 0x04
   constant OP_SEND_ONLY_IMM_C       : slv(4 downto 0) := "00101";  -- 0x05
   constant OP_WRITE_FIRST_C         : slv(4 downto 0) := "00110";  -- 0x06
   constant OP_WRITE_MIDDLE_C        : slv(4 downto 0) := "00111";  -- 0x07
   constant OP_WRITE_LAST_C          : slv(4 downto 0) := "01000";  -- 0x08
   constant OP_WRITE_LAST_IMM_C      : slv(4 downto 0) := "01001";  -- 0x09
   constant OP_WRITE_ONLY_C          : slv(4 downto 0) := "01010";  -- 0x0a
   constant OP_WRITE_ONLY_IMM_C      : slv(4 downto 0) := "01011";  -- 0x0b
   constant OP_READ_REQUEST_C        : slv(4 downto 0) := "01100";  -- 0x0c
   constant OP_READ_RESP_FIRST_C     : slv(4 downto 0) := "01101";  -- 0x0d
   constant OP_READ_RESP_LAST_C      : slv(4 downto 0) := "01111";  -- 0x0f
   constant OP_READ_RESP_ONLY_C      : slv(4 downto 0) := "10000";  -- 0x10
   constant OP_COMPARE_SWAP_C        : slv(4 downto 0) := "10011";  -- 0x13
   constant OP_FETCH_ADD_C           : slv(4 downto 0) := "10100";  -- 0x14
   constant OP_SEND_LAST_INV_C       : slv(4 downto 0) := "10110";  -- 0x16
   constant OP_SEND_ONLY_INV_C       : slv(4 downto 0) := "10111";  -- 0x17

   -- Extension-header slot selectors
   type MiddleType is (MID_NONE, MID_RETH, MID_DETH, MID_ATOMIC);
   type TailType   is (TAIL_NONE, TAIL_LETH, TAIL_IMM, TAIL_IETH);

begin

   comb : process (isFirstOrOnly, isOnlyOrLast, qpType, opcode, solicited, ackReq,
                   psn, padCnt, remoteAddr, wqeRaddr, dlen, hasPayloadIn, dqpn,
                   sqpn, srqn, qkey, rkey, sgeLaddr, sgeLkey, swapData, compData,
                   immData) is
      variable trans      : slv(2 downto 0);
      variable transValid : sl;
      variable opc5       : slv(4 downto 0);
      variable solicE     : sl;
      variable ackReqE    : sl;
      variable bthBits    : slv(95 downto 0);
      variable rethBits   : slv(127 downto 0);
      variable lethBits   : slv(127 downto 0);
      variable atomicBits : slv(223 downto 0);
      variable xrcethBits : slv(31 downto 0);
      variable dethBits   : slv(63 downto 0);
      variable immOrIeth  : slv(31 downto 0);
      variable useXrceth  : sl;
      variable midSel     : MiddleType;
      variable tailSel    : TailType;
      variable armValid   : sl;
      variable incTail    : sl;               -- immDt / ieth appended only on only/last
      variable hasPl      : sl;
      variable isReadAtom : sl;
      variable slvHeader  : slv(511 downto 0);
      variable hlen       : integer range 0 to 63;
      variable hlenSlv    : slv(6 downto 0);
      variable byteEn     : slv(63 downto 0);
      variable fragNum    : slv(1 downto 0);
      variable lastValid  : slv(5 downto 0);
      variable residue    : slv(4 downto 0);
      variable pos        : integer range 0 to 512;
   begin

      -----------------------------------------------------------------------
      -- 1. TransType = qpType2TransType(qpType)  (Utils.bsv:741)
      -----------------------------------------------------------------------
      transValid := '1';
      case qpType is
         when QPT_RC_C                    => trans := TRANS_RC_C;
         when QPT_UC_C                    => trans := TRANS_UC_C;
         when QPT_UD_C                    => trans := TRANS_UD_C;
         when QPT_XRC_SEND_C | QPT_XRC_RECV_C => trans := TRANS_XRC_C;
         when others                      => trans := (others => '0'); transValid := '0';
      end case;

      -----------------------------------------------------------------------
      -- 2. RdmaOpCode = gen{FirstOrOnly|MiddleOrLast}RdmaOpCode  (SendQ.bsv:49-74)
      -----------------------------------------------------------------------
      opc5    := (others => '0');
      incTail := isOnlyOrLast;
      if (isFirstOrOnly = '1') then
         case opcode is
            when WR_RDMA_WRITE_C          => opc5 := ite(isOnlyOrLast = '1', OP_WRITE_ONLY_C,      OP_WRITE_FIRST_C);
            when WR_RDMA_WRITE_WITH_IMM_C => opc5 := ite(isOnlyOrLast = '1', OP_WRITE_ONLY_IMM_C,  OP_WRITE_FIRST_C);
            when WR_SEND_C                => opc5 := ite(isOnlyOrLast = '1', OP_SEND_ONLY_C,       OP_SEND_FIRST_C);
            when WR_SEND_WITH_IMM_C       => opc5 := ite(isOnlyOrLast = '1', OP_SEND_ONLY_IMM_C,   OP_SEND_FIRST_C);
            when WR_SEND_WITH_INV_C       => opc5 := ite(isOnlyOrLast = '1', OP_SEND_ONLY_INV_C,   OP_SEND_FIRST_C);
            when WR_RDMA_READ_RESP_C      => opc5 := ite(isOnlyOrLast = '1', OP_READ_RESP_ONLY_C,  OP_READ_RESP_FIRST_C);
            when WR_RDMA_READ_C           => opc5 := OP_READ_REQUEST_C;
            when WR_ATOMIC_CMP_AND_SWP_C  => opc5 := OP_COMPARE_SWAP_C;
            when WR_ATOMIC_FETCH_ADD_C    => opc5 := OP_FETCH_ADD_C;
            when others                   => opc5 := (others => '0');
         end case;
      else
         case opcode is
            when WR_RDMA_WRITE_C          => opc5 := ite(isOnlyOrLast = '1', OP_WRITE_LAST_C,     OP_WRITE_MIDDLE_C);
            when WR_RDMA_WRITE_WITH_IMM_C => opc5 := ite(isOnlyOrLast = '1', OP_WRITE_LAST_IMM_C, OP_WRITE_MIDDLE_C);
            when WR_SEND_C                => opc5 := ite(isOnlyOrLast = '1', OP_SEND_LAST_C,      OP_SEND_MIDDLE_C);
            when WR_SEND_WITH_IMM_C       => opc5 := ite(isOnlyOrLast = '1', OP_SEND_LAST_IMM_C,  OP_SEND_MIDDLE_C);
            when WR_SEND_WITH_INV_C       => opc5 := ite(isOnlyOrLast = '1', OP_SEND_LAST_INV_C,  OP_SEND_MIDDLE_C);
            when WR_RDMA_READ_RESP_C      => opc5 := ite(isOnlyOrLast = '1', OP_READ_RESP_LAST_C, OP_READ_RESP_FIRST_C);
            when others                   => opc5 := (others => '0');
         end case;
      end if;

      -----------------------------------------------------------------------
      -- 3. BTH assembly (first-field-at-MSB, 96 bits; Headers.bsv:153-168)
      --    pkey = dontCareValue -> 0 (OQ-FSM-HGR-01)
      -----------------------------------------------------------------------
      solicE  := isOnlyOrLast and solicited;
      ackReqE := isOnlyOrLast and ackReq;
      bthBits := trans                      -- [95:93] trans
                 & opc5                     -- [92:88] opcode
                 & solicE                   -- [87]    solicited
                 & '0'                      -- [86]    migReq
                 & padCnt                   -- [85:84] padCnt
                 & "0000"                   -- [83:80] tver
                 & x"0000"                  -- [79:64] pkey (dontCare -> 0)
                 & '0'                      -- [63]    fecn
                 & '0'                      -- [62]    becn
                 & "000000"                 -- [61:56] resv6
                 & dqpn                     -- [55:32] dqpn
                 & ackReqE                  -- [31]    ackReq
                 & "0000000"                -- [30:24] resv7
                 & psn;                     -- [23:0]  psn

      -----------------------------------------------------------------------
      -- 4. Extension sub-headers (first-field-at-MSB)
      -----------------------------------------------------------------------
      rethBits   := remoteAddr & rkey & dlen;                 -- RETH  128
      lethBits   := sgeLaddr   & sgeLkey & dlen;              -- LETH  128
      atomicBits := wqeRaddr & rkey & swapData & compData;    -- Atomic 224
      xrcethBits := x"00" & srqn;                             -- XRCETH 32
      dethBits   := qkey & x"00" & sqpn;                      -- DETH   64
      immOrIeth  := immData;                                  -- ImmDt / IETH 32

      -----------------------------------------------------------------------
      -- 5. Slot selection per (opcode, qpType)  (SendQ.bsv:216-374 / 417-533)
      -----------------------------------------------------------------------
      useXrceth  := '0';
      midSel     := MID_NONE;
      tailSel    := TAIL_NONE;
      armValid   := '0';
      isReadAtom := '0';

      case opcode is
         when WR_RDMA_WRITE_C =>
            case qpType is
               when QPT_RC_C | QPT_UC_C => midSel := MID_RETH; armValid := '1';
               when QPT_XRC_SEND_C      => useXrceth := '1'; midSel := MID_RETH; armValid := '1';
               when others              => null;
            end case;

         when WR_RDMA_WRITE_WITH_IMM_C =>
            case qpType is
               when QPT_RC_C | QPT_UC_C =>
                  midSel := MID_RETH;
                  if (incTail = '1') then tailSel := TAIL_IMM; end if;
                  armValid := '1';
               when QPT_XRC_SEND_C =>
                  useXrceth := '1'; midSel := MID_RETH;
                  if (incTail = '1') then tailSel := TAIL_IMM; end if;
                  armValid := '1';
               when others => null;
            end case;

         when WR_SEND_C =>
            case qpType is
               when QPT_RC_C | QPT_UC_C => armValid := '1';                       -- bth only
               when QPT_UD_C            => midSel := MID_DETH; armValid := '1';
               when QPT_XRC_SEND_C      => useXrceth := '1'; armValid := '1';
               when others              => null;
            end case;

         when WR_SEND_WITH_IMM_C =>
            case qpType is
               when QPT_RC_C | QPT_UC_C =>
                  if (incTail = '1') then tailSel := TAIL_IMM; end if;
                  armValid := '1';
               when QPT_UD_C =>
                  midSel := MID_DETH; tailSel := TAIL_IMM; armValid := '1';       -- UD always only-pkt
               when QPT_XRC_SEND_C =>
                  useXrceth := '1';
                  if (incTail = '1') then tailSel := TAIL_IMM; end if;
                  armValid := '1';
               when others => null;
            end case;

         when WR_SEND_WITH_INV_C =>
            case qpType is
               when QPT_RC_C =>
                  if (incTail = '1') then tailSel := TAIL_IETH; end if;
                  armValid := '1';
               when QPT_XRC_SEND_C =>
                  useXrceth := '1';
                  if (incTail = '1') then tailSel := TAIL_IETH; end if;
                  armValid := '1';
               when others => null;
            end case;

         when WR_RDMA_READ_C =>                                                   -- first/only only
            if (isFirstOrOnly = '1') then
               isReadAtom := '1';
               case qpType is
                  when QPT_RC_C       => midSel := MID_RETH; tailSel := TAIL_LETH; armValid := '1';
                  when QPT_XRC_SEND_C => useXrceth := '1'; midSel := MID_RETH; tailSel := TAIL_LETH; armValid := '1';
                  when others         => null;
               end case;
            end if;

         when WR_ATOMIC_CMP_AND_SWP_C | WR_ATOMIC_FETCH_ADD_C =>                  -- first/only only
            if (isFirstOrOnly = '1') then
               isReadAtom := '1';
               case qpType is
                  when QPT_RC_C       => midSel := MID_ATOMIC; armValid := '1';
                  when QPT_XRC_SEND_C => useXrceth := '1'; midSel := MID_ATOMIC; armValid := '1';
                  when others         => null;
               end case;
            end if;

         when WR_RDMA_READ_RESP_C =>
            case qpType is
               when QPT_RC_C | QPT_XRC_SEND_C | QPT_XRC_RECV_C =>
                  midSel := MID_RETH; armValid := '1';
               when others => null;
            end case;

         when others => null;
      end case;

      -----------------------------------------------------------------------
      -- 6. Effective hasPayload  (SendQ.bsv per-case)
      -----------------------------------------------------------------------
      if (isFirstOrOnly = '0') then
         hasPl := '1';                       -- middle/last always has payload
      elsif (isReadAtom = '1') then
         hasPl := '0';                       -- read/atomic requests carry no payload
      else
         hasPl := hasPayloadIn;
      end if;

      -----------------------------------------------------------------------
      -- 7. Assemble headerData (left-aligned, zeroExtendLSB) + headerLen
      -----------------------------------------------------------------------
      slvHeader := (others => '0');
      slvHeader(511 downto 416) := bthBits;
      hlen := 12;
      pos  := 416;
      if (useXrceth = '1') then
         slvHeader(pos-1 downto pos-32) := xrcethBits;
         pos  := pos - 32;
         hlen := hlen + 4;
      end if;
      case midSel is
         when MID_RETH =>
            slvHeader(pos-1 downto pos-128) := rethBits;   pos := pos - 128; hlen := hlen + 16;
         when MID_DETH =>
            slvHeader(pos-1 downto pos-64)  := dethBits;   pos := pos - 64;  hlen := hlen + 8;
         when MID_ATOMIC =>
            slvHeader(pos-1 downto pos-224) := atomicBits; pos := pos - 224; hlen := hlen + 28;
         when MID_NONE => null;
      end case;
      case tailSel is
         when TAIL_LETH =>
            slvHeader(pos-1 downto pos-128) := lethBits;   hlen := hlen + 16;
         when TAIL_IMM =>
            slvHeader(pos-1 downto pos-32)  := immOrIeth;  hlen := hlen + 4;
         when TAIL_IETH =>
            slvHeader(pos-1 downto pos-32)  := immOrIeth;  hlen := hlen + 4;
         when TAIL_NONE => null;
      end case;
      hlenSlv := toSlv(hlen, 7);

      -----------------------------------------------------------------------
      -- 8. genHeaderRDMA: byteEn + metaData  (Utils.bsv:165-345)
      -----------------------------------------------------------------------
      -- byteEn = reverseBits((1<<headerLen)-1) : headerLen ones at the MSB
      for i in 0 to 63 loop
         if (i < hlen) then
            byteEn(63 - i) := '1';
         else
            byteEn(63 - i) := '0';
         end if;
      end loop;

      -- headerFragNum = headerLen[6:5] + (headerLen[4:0] /= 0 ? 1 : 0)
      residue := hlenSlv(4 downto 0);
      if (residue /= "00000") then
         fragNum := slv(unsigned(hlenSlv(6 downto 5)) + 1);
      else
         fragNum := hlenSlv(6 downto 5);
      end if;

      -- lastFragValidByteNum
      if (residue /= "00000") then
         lastValid := "0" & residue;                          -- zeroExtend(residue)
      elsif (hlenSlv(6 downto 5) /= "00") then
         lastValid := toSlv(32, 6);                           -- full fragment
      else
         lastValid := (others => '0');
      end if;

      -----------------------------------------------------------------------
      -- 9. Drive outputs
      -----------------------------------------------------------------------
      headerValid   <= transValid and armValid;
      pktHeaderRdma <= slvHeader & byteEn & hlenSlv & fragNum & lastValid & hasPl & '0';

   end process comb;

end architecture rtl;
