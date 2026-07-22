-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   A 7-stage feed-forward pipeline of FIFO-coupled rules (all conflict_free)
--   plus a small per-packet iterator FSM living in genPayloadGenResp.  A
--   PayloadGenReqSG enters the srvPort.request; the pipeline splits the request
--   into per-packet PayloadGenRespSG descriptors (raddr / pktLen / padCnt /
--   isFirst / isLast) and re-streams the DMA-read payload (byteEn-padded on the
--   last fragment of first/last packets) out payloadDataStreamPipeOut.  A
--   PayloadGenTotalMetaData is produced per request on totalMetaDataPipeOut.
--
--   dmaReadCntrl is a MODULE PARAMETER (SendQ builds mkDmaReadCntrl and passes
--   it in), NOT a child instance — see fsm.md §Inventory/Partition Mismatch and
--   OQ-FSM-PGG-01.  It is emitted as an external port group: a Client handshake
--   (request out / response in) plus TWO input PipeOuts (sgePktMetaData*,
--   sgeMergedMetaData*) that feed the two merge children.
--
--   clearAll is the BSV module Bool parameter (→ clearAllI port): it guards
--   resetAndClear and appears as !clearAll on every worker rule, and is
--   forwarded to the four internal children.
--
--   Iterator state (genPayloadGenResp only; single writer — no inter-rule reg
--   hazard, all rules conflict_free):
--     isFirstPktReg      : sl        mkReg(True); reset '1'.  '1'=next packet is
--                                    FIRST of the current request.
--     pktRemoteAddrReg   : slv(63:0) mkRegU (NO reset) — remote addr for next pkt.
--     remainingPktNumReg : slv(24:0) mkRegU (NO reset; PktNum=25b, OQ-FSM-PGG-01,
--                                    NOT the stale 16 in modules.json) — packets
--                                    still to emit; isLast when it reaches 1.
--   pktRemoteAddrReg/remainingPktNumReg are written in the isFirstPktReg='1'
--   branch before ever being read in the '0' branch, so the missing reset is safe.
--
--   FIFO clear (OQ-FSM-01 family, RESOLVED): every FIFO reset is
--     fifoRst = rst OR clearAllI  (level-safe synchronous flush of surf.Fifo /
--     FifoSync, RST_ASYNC_G=false, RST_POLARITY_G='1').  The four children clear
--     via their own clearAllI/clearEnI inputs.
--
--   Struct bit layouts (BSV deriving(Bits), first-field-at-MSB; OQ-FSM-H2DS-04).
--   Base widths (traced): ADDR=64, Length=32, PktLen=13, PktNum=25, PMTU=3,
--   PAD=2, PktNumAddOn=2, ByteEnBitNum=6, ByteEn=32, PktFragNum=8,
--   DataStream=290, QPN=24, WorkReqID=64, LKEY=32, SGE=130, SGL=1040.
--     PayloadGenReqSG (1228): [1227:1164]wrID(64) [1163:1140]sqpn(24)
--        [1139:100]sgl(1040) [99:68]totalLen(32) [67:4]raddr(64) [3:1]pmtu(3) [0]addPadding
--     PayloadGenRespSG (81): [80:17]raddr(64) [16:4]pktLen(13) [3:2]padCnt(2)
--        [1]isFirst [0]isLast
--     PayloadGenTotalMetaData (27): [26:2]totalPktNum(25) [1]isOnlyPkt [0]isZeroPayloadLen
--     DataStream (290): [289:34]data(256) [33:2]byteEn(32) [1]isFirst [0]isLast
--     DmaReadCntrlReq (1163): [1162:123]sgl(1040) [122:91]totalLen(32)
--        [90:67]sqpn(24) [66:3]wrID(64) [2:0]pmtu(3)
--     DmaReadCntrlResp (385): [384:2]dmaReadResp(383) [1]isFirstFragInSGL
--        [0]isLastFragInSGL; within dmaReadResp: dataStream=[291:2]
--   Internal pipeline structs (packing is producer=consumer local; typedef order,
--   first-field-at-MSB): TmpPayloadGenMetaData=155, TmpAdjustFirstAndLastPktLen=247,
--   TmpAdjustTotalPayloadMetaData=229, AdjustedTotalPayloadMetaData=61,
--   TmpPayloadGenRespData=214, TmpPaddingData=66.  Tuple2 = first elem at MSB.
--
--   SURF components instantiated (source: surf/base/fifo/rtl/Fifo.vhd — 11 FIFOs):
--     10× surf.Fifo (FWFT, sync) + 1× surf.Fifo for the BRAM buffer
--     (U_PayloadBufQ: mkSizedBRAMFIFOF → surf.Fifo GEN_SYNC, block RAM,
--     ADDR_WIDTH_G=8 = DATA_STREAM_FRAG_BUF_SIZE = MIN_PKT_NUM_IN_RECV_BUF(2) *
--     PMTU_MAX_FRAG_NUM(128) = 256; read side owned by U_BramQ2PipeOut).
--   Child entities (4, from out/04-vhdl/):
--     U_SgeMergedPayload : MergePayloadEachSge
--     U_SglMergedPayload : MergePayloadAllSge
--     U_AdjustedPayload  : AdjustPayloadSegment
--     U_BramQ2PipeOut    : ConnectBramQ2PipeOutGen
--
--   Mealy (combinational) drives — MUST NOT be registered (the FIFOs latch them
--   on the clock edge): every FIFO wr_en/din/rd_en and the dmaReadCntrl
--   request/response handshake.  isFirstPktReg/pktRemoteAddrReg/remainingPktNumReg
--   are the only registered (Moore) state.  payloadNotEmpty is a Moore passthrough
--   of the child.
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

entity PayloadGeneratorGen is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk : in sl;
      rst : in sl;                                          -- active-high sync reset
      -- Software clear (BSV module Bool parameter clearAll)
      clearAllI : in sl;
      -- srvPort.request : Put#(PayloadGenReqSG)  (caller -> entity)
      reqInValid : in  sl;                                  -- caller offers a request (wr_en)
      reqInData  : in  slv(1227 downto 0);                  -- PayloadGenReqSG packed (1228b)
      reqInReady : out sl;                                  -- entity can accept (notFull)
      -- srvPort.response : Get#(PayloadGenRespSG)  (entity -> caller)
      respOutReady : in  sl;                                -- caller takes a response (rd_en)
      respOutValid : out sl;                                -- response available (notEmpty)
      respOutData  : out slv(80 downto 0);                  -- PayloadGenRespSG packed (81b)
      -- totalMetaDataPipeOut : PipeOut#(PayloadGenTotalMetaData)
      totalMetaDataDeq      : in  sl;                        -- consumer dequeues
      totalMetaDataFirst    : out slv(26 downto 0);          -- .first (27b)
      totalMetaDataNotEmpty : out sl;                        -- .notEmpty
      -- payloadDataStreamPipeOut : PipeOut#(DataStream)  (via child U_BramQ2PipeOut)
      payloadDataStreamDeq      : in  sl;                    -- consumer dequeues
      payloadDataStreamFirst    : out slv(289 downto 0);     -- .first (DataStream 290b)
      payloadDataStreamNotEmpty : out sl;                    -- .notEmpty
      -- payloadNotEmpty() method result (Moore passthrough of the child)
      payloadNotEmpty : out sl;
      -- dmaReadCntrl.srvPort.request : Put#(DmaReadCntrlReq)  (entity -> module param, CLIENT)
      dmaReadCntrlReqValid : out sl;                         -- entity offers a request (Mealy)
      dmaReadCntrlReqData  : out slv(1162 downto 0);         -- DmaReadCntrlReq packed (1163b)
      dmaReadCntrlReqReady : in  sl;                         -- module param can accept
      -- dmaReadCntrl.srvPort.response : Get#(DmaReadCntrlResp)  (module param -> entity, CLIENT)
      dmaReadCntrlRespValid : in  sl;                        -- module param offers a response
      dmaReadCntrlRespData  : in  slv(384 downto 0);         -- DmaReadCntrlResp packed (385b)
      dmaReadCntrlRespReady : out sl;                        -- entity takes the response (get)
      -- dmaReadCntrl.sgePktMetaDataPipeOut : PipeOut#(PktMetaDataSGE)  (-> U_SgeMergedPayload)
      sgePktMetaValid : in  sl;                              -- .notEmpty
      sgePktMetaData  : in  slv(53 downto 0);                -- .first (PktMetaDataSGE 54b)
      sgePktMetaRdEn  : out sl;                              -- .deq
      -- dmaReadCntrl.sgeMergedMetaDataPipeOut : PipeOut#(MergedMetaDataSGE)  (-> U_SglMergedPayload)
      sgeMergedMetaValid : in  sl;                           -- .notEmpty
      sgeMergedMetaData  : in  slv(7 downto 0);              -- .first (MergedMetaDataSGE 8b)
      sgeMergedMetaRdEn  : out sl);                          -- .deq
end entity PayloadGeneratorGen;

architecture rtl of PayloadGeneratorGen is

   -----------------------------------------------------------------------------
   -- Width constants (traced from BSV; see header)
   -----------------------------------------------------------------------------
   constant ADDR_W_C        : positive := 64;
   constant LEN_W_C         : positive := 32;
   constant PKTLEN_W_C      : positive := 13;
   constant PKTNUM_W_C      : positive := 25;
   constant PMTU_W_C        : positive := 3;
   constant PAD_W_C         : positive := 2;
   constant ADDON_W_C       : positive := 2;   -- PktNumAddOn
   constant BEBN_W_C        : positive := 6;   -- ByteEnBitNum
   constant BYTEEN_W_C      : positive := 32;
   constant FRAGNUM_W_C     : positive := 8;   -- PktFragNum
   constant DS_W_C          : positive := 290; -- DataStream (OQ-FSM-H2DS-02)
   constant SGL_W_C         : positive := 1040;
   constant QPN_W_C         : positive := 24;
   constant WRID_W_C        : positive := 64;
   constant DMA_BYTE_WIDTH_C : natural := 32;  -- DATA_BUS_BYTE_WIDTH

   constant PAYLOAD_GEN_REQ_W_C  : positive := 1228;
   constant PAYLOAD_GEN_RESP_W_C : positive := 81;
   constant TOTAL_META_W_C       : positive := 27;
   constant DMA_REQ_W_C          : positive := 1163;
   constant DMA_RESP_W_C         : positive := 385;

   constant TMP_META_W_C     : positive := 155;  -- TmpPayloadGenMetaData
   constant ADJ_REQ_Q_W_C    : positive := PAYLOAD_GEN_REQ_W_C + TMP_META_W_C;  -- 1383
   constant TMP_FL_W_C       : positive := 247;  -- TmpAdjustFirstAndLastPktLen
   constant TMP_TOTAL_W_C    : positive := 229;  -- TmpAdjustTotalPayloadMetaData
   constant ADJ_TOTAL_W_C    : positive := 61;   -- AdjustedTotalPayloadMetaData
   constant TMP_RESP_W_C     : positive := 214;  -- TmpPayloadGenRespData
   constant TMP_PAD_W_C      : positive := 66;   -- TmpPaddingData
   constant ADD_PAD_Q_W_C    : positive := PAYLOAD_GEN_RESP_W_C + TMP_PAD_W_C;  -- 147

   constant BUF_ADDR_WIDTH_C : positive := 8;    -- DATA_STREAM_FRAG_BUF_SIZE = 256

   -- PMTU enum encodings (PMTU deriving(Bits): IBV_MTU_256=1 .. IBV_MTU_4096=5)
   constant IBV_MTU_256_C  : slv(2 downto 0) := "001";
   constant IBV_MTU_512_C  : slv(2 downto 0) := "010";
   constant IBV_MTU_1024_C : slv(2 downto 0) := "011";
   constant IBV_MTU_2048_C : slv(2 downto 0) := "100";
   constant IBV_MTU_4096_C : slv(2 downto 0) := "101";

   -----------------------------------------------------------------------------
   -- Helper functions (Utils.bsv / PrimUtils.bsv) — verified against source
   -----------------------------------------------------------------------------
   -- calcPmtuLen: PktLen (13b) size in bytes of one PMTU packet
   function calcPmtuLen (pmtu : slv(2 downto 0)) return slv is
   begin
      case pmtu is
         when IBV_MTU_256_C  => return std_logic_vector(to_unsigned(256,  PKTLEN_W_C));
         when IBV_MTU_512_C  => return std_logic_vector(to_unsigned(512,  PKTLEN_W_C));
         when IBV_MTU_1024_C => return std_logic_vector(to_unsigned(1024, PKTLEN_W_C));
         when IBV_MTU_2048_C => return std_logic_vector(to_unsigned(2048, PKTLEN_W_C));
         when IBV_MTU_4096_C => return std_logic_vector(to_unsigned(4096, PKTLEN_W_C));
         when others         => return (PKTLEN_W_C-1 downto 0 => '0');
      end case;
   end function calcPmtuLen;

   -- alignAddrByPMTU: clear the low log2(pmtu) address bits
   function alignAddrByPMTU (addr : slv; pmtu : slv(2 downto 0)) return slv is
      variable res : slv(ADDR_W_C-1 downto 0);
   begin
      res := addr(ADDR_W_C-1 downto 0);
      case pmtu is
         when IBV_MTU_256_C  => res(7  downto 0) := (others => '0');
         when IBV_MTU_512_C  => res(8  downto 0) := (others => '0');
         when IBV_MTU_1024_C => res(9  downto 0) := (others => '0');
         when IBV_MTU_2048_C => res(10 downto 0) := (others => '0');
         when IBV_MTU_4096_C => res(11 downto 0) := (others => '0');
         when others         => null;
      end case;
      return res;
   end function alignAddrByPMTU;

   -- addrAddPsnMultiplyPMTU with psn=1: { addr[63:k]+1, addr[k-1:0] } (adds one PMTU)
   function addrAddOnePMTU (addr : slv; pmtu : slv(2 downto 0)) return slv is
      variable a   : slv(ADDR_W_C-1 downto 0);
      variable res : slv(ADDR_W_C-1 downto 0);
   begin
      a   := addr(ADDR_W_C-1 downto 0);
      res := a;
      case pmtu is
         when IBV_MTU_256_C  => res := slv(unsigned(a(63 downto 8))  + 1) & a(7  downto 0);
         when IBV_MTU_512_C  => res := slv(unsigned(a(63 downto 9))  + 1) & a(8  downto 0);
         when IBV_MTU_1024_C => res := slv(unsigned(a(63 downto 10)) + 1) & a(9  downto 0);
         when IBV_MTU_2048_C => res := slv(unsigned(a(63 downto 11)) + 1) & a(10 downto 0);
         when IBV_MTU_4096_C => res := slv(unsigned(a(63 downto 12)) + 1) & a(11 downto 0);
         when others         => null;
      end case;
      return res;
   end function addrAddOnePMTU;

   -- truncateByPMTU: ResiduePMTU (12b) = zeroExtend(bits[k-1:0])
   function truncateByPMTU (bits : slv; pmtu : slv(2 downto 0)) return slv is
      variable res : slv(11 downto 0) := (others => '0');
   begin
      res := (others => '0');
      case pmtu is
         when IBV_MTU_256_C  => res(7  downto 0) := bits(7  downto 0);
         when IBV_MTU_512_C  => res(8  downto 0) := bits(8  downto 0);
         when IBV_MTU_1024_C => res(9  downto 0) := bits(9  downto 0);
         when IBV_MTU_2048_C => res(10 downto 0) := bits(10 downto 0);
         when IBV_MTU_4096_C => res(11 downto 0) := bits(11 downto 0);
         when others         => null;
      end case;
      return res;
   end function truncateByPMTU;

   -- stepOne pieces (per-PMTU slices of raddr/totalLen) -----------------------
   -- pmtuMask: PktLen (13b) with low k bits set
   function pmtuMaskF (pmtu : slv(2 downto 0)) return slv is
      variable res : slv(PKTLEN_W_C-1 downto 0) := (others => '0');
   begin
      res := (others => '0');
      case pmtu is
         when IBV_MTU_256_C  => res(7  downto 0) := (others => '1');
         when IBV_MTU_512_C  => res(8  downto 0) := (others => '1');
         when IBV_MTU_1024_C => res(9  downto 0) := (others => '1');
         when IBV_MTU_2048_C => res(10 downto 0) := (others => '1');
         when IBV_MTU_4096_C => res(11 downto 0) := (others => '1');
         when others         => null;
      end case;
      return res;
   end function pmtuMaskF;

   -- addrLowPart: PktLen (13b) zeroExtend of addr[k-1:0]
   function addrLowPartF (addr : slv; pmtu : slv(2 downto 0)) return slv is
      variable res : slv(PKTLEN_W_C-1 downto 0) := (others => '0');
   begin
      res := (others => '0');
      case pmtu is
         when IBV_MTU_256_C  => res(7  downto 0) := addr(7  downto 0);
         when IBV_MTU_512_C  => res(8  downto 0) := addr(8  downto 0);
         when IBV_MTU_1024_C => res(9  downto 0) := addr(9  downto 0);
         when IBV_MTU_2048_C => res(10 downto 0) := addr(10 downto 0);
         when IBV_MTU_4096_C => res(11 downto 0) := addr(11 downto 0);
         when others         => null;
      end case;
      return res;
   end function addrLowPartF;

   -- lenLowPart: PktLen (13b) zeroExtend of len[k-1:0]
   function lenLowPartF (len : slv; pmtu : slv(2 downto 0)) return slv is
      variable res : slv(PKTLEN_W_C-1 downto 0) := (others => '0');
   begin
      res := (others => '0');
      case pmtu is
         when IBV_MTU_256_C  => res(7  downto 0) := len(7  downto 0);
         when IBV_MTU_512_C  => res(8  downto 0) := len(8  downto 0);
         when IBV_MTU_1024_C => res(9  downto 0) := len(9  downto 0);
         when IBV_MTU_2048_C => res(10 downto 0) := len(10 downto 0);
         when IBV_MTU_4096_C => res(11 downto 0) := len(11 downto 0);
         when others         => null;
      end case;
      return res;
   end function lenLowPartF;

   -- truncatedPktNum: PktNum (25b) zeroExtend of len[31:k] (truncateLSB)
   function truncatedPktNumF (len : slv; pmtu : slv(2 downto 0)) return slv is
      variable res : slv(PKTNUM_W_C-1 downto 0) := (others => '0');
   begin
      res := (others => '0');
      case pmtu is
         when IBV_MTU_256_C  => res(23 downto 0) := len(31 downto 8);
         when IBV_MTU_512_C  => res(22 downto 0) := len(31 downto 9);
         when IBV_MTU_1024_C => res(21 downto 0) := len(31 downto 10);
         when IBV_MTU_2048_C => res(20 downto 0) := len(31 downto 11);
         when IBV_MTU_4096_C => res(19 downto 0) := len(31 downto 12);
         when others         => null;
      end case;
      return res;
   end function truncatedPktNumF;

   -- calcLastFragValidByteNum: ByteEnBitNum (6b); len[4:0], or 32 if [4:0]=0 and [.:5]/=0
   function calcLastFragValidByteNum (len : slv) return slv is
      variable residue      : slv(4 downto 0);
      variable truncatedLen : slv(len'length-1 downto 5);
      variable res          : slv(BEBN_W_C-1 downto 0);
   begin
      residue      := len(4 downto 0);
      truncatedLen := len(len'length-1 downto 5);
      res          := '0' & residue;                       -- zeroExtend(residue) to 6b
      if (unsigned(residue) = 0) and (unsigned(truncatedLen) /= 0) then
         res := std_logic_vector(to_unsigned(DMA_BYTE_WIDTH_C, BEBN_W_C));  -- 32
      end if;
      return res;
   end function calcLastFragValidByteNum;

   -- calcFragNumByPktLen: PktFragNum (8b) = pktLen[12:5] + (pktLen[4:0]/=0 ? 1 : 0)
   function calcFragNumByPktLen (pktLen : slv) return slv is
      variable residue      : slv(4 downto 0);
      variable truncatedLen : slv(FRAGNUM_W_C-1 downto 0);
      variable res          : unsigned(FRAGNUM_W_C-1 downto 0);
   begin
      residue      := pktLen(4 downto 0);
      truncatedLen := pktLen(12 downto 5);
      res          := unsigned(truncatedLen);
      if (unsigned(residue) /= 0) then
         res := res + 1;
      end if;
      return std_logic_vector(res);
   end function calcFragNumByPktLen;

   -- calcPadCnt: PAD (2b) = (1<<PAD_WIDTH) - len[1:0] = (0 - len[1:0]) truncated to 2b
   function calcPadCnt (len : slv) return slv is
   begin
      return slv(to_unsigned(0, PAD_W_C) - unsigned(len(1 downto 0)));
   end function calcPadCnt;

   -- genByteEn: ByteEn (32b) = reverseBits((1<<n)-1); n saturates >=32 -> all ones
   function genByteEn (n : slv) return slv is
      variable mask : slv(BYTEEN_W_C-1 downto 0) := (others => '0');
      variable cnt  : integer;
   begin
      cnt := to_integer(unsigned(n));
      for i in mask'range loop
         if (i < cnt) then
            mask(i) := '1';
         end if;
      end loop;
      return bitReverse(mask);
   end function genByteEn;

   -----------------------------------------------------------------------------
   -- Register record (iterator state only — genPayloadGenResp)
   -----------------------------------------------------------------------------
   type RegType is record
      isFirstPktReg      : sl;                              -- mkReg(True); reset '1'
      pktRemoteAddrReg   : slv(ADDR_W_C-1 downto 0);        -- mkRegU (no reset)
      remainingPktNumReg : slv(PKTNUM_W_C-1 downto 0);      -- mkRegU (no reset)
   end record RegType;

   constant REG_INIT_C : RegType := (
      isFirstPktReg      => '1',
      pktRemoteAddrReg   => (others => '0'),                -- mkRegU; placeholder, not reset
      remainingPktNumReg => (others => '0'));               -- mkRegU; placeholder, not reset

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Shared FIFO clear (rst OR software clear)
   signal fifoRst : sl;

   -- U_PayloadGenReqQ (PayloadGenReqSG, 1228b)
   signal payloadGenReqQNotFull : sl;
   signal payloadGenReqQValid   : sl;
   signal payloadGenReqQDout    : slv(PAYLOAD_GEN_REQ_W_C-1 downto 0);
   signal payloadGenReqQRdEn    : sl;

   -- U_AdjustReqPktLenQ (Tuple2(PayloadGenReqSG,TmpPayloadGenMetaData), 1383b)
   signal adjustReqPktLenQNotFull : sl;
   signal adjustReqPktLenQValid   : sl;
   signal adjustReqPktLenQDout    : slv(ADJ_REQ_Q_W_C-1 downto 0);
   signal adjustReqPktLenQWrEn    : sl;
   signal adjustReqPktLenQRdEn    : sl;
   signal adjustReqPktLenQDin     : slv(ADJ_REQ_Q_W_C-1 downto 0);

   -- U_AdjustFirstAndLastPktLenQ (TmpAdjustFirstAndLastPktLen, 247b)
   signal adjustFirstLastQNotFull : sl;
   signal adjustFirstLastQValid   : sl;
   signal adjustFirstLastQDout    : slv(TMP_FL_W_C-1 downto 0);
   signal adjustFirstLastQWrEn    : sl;
   signal adjustFirstLastQRdEn    : sl;
   signal adjustFirstLastQDin     : slv(TMP_FL_W_C-1 downto 0);

   -- U_AdjustTotalPayloadMetaDataQ (TmpAdjustTotalPayloadMetaData, 229b)
   signal adjustTotalQNotFull : sl;
   signal adjustTotalQValid   : sl;
   signal adjustTotalQDout    : slv(TMP_TOTAL_W_C-1 downto 0);
   signal adjustTotalQWrEn    : sl;
   signal adjustTotalQRdEn    : sl;
   signal adjustTotalQDin     : slv(TMP_TOTAL_W_C-1 downto 0);

   -- U_AdjustedTotalPayloadMetaDataQ (AdjustedTotalPayloadMetaData, 61b) — read by child
   signal adjustedTotalQNotFull : sl;
   signal adjustedTotalQValid   : sl;
   signal adjustedTotalQDout    : slv(ADJ_TOTAL_W_C-1 downto 0);
   signal adjustedTotalQWrEn    : sl;
   signal adjustedTotalQRdEn    : sl;
   signal adjustedTotalQDin     : slv(ADJ_TOTAL_W_C-1 downto 0);

   -- U_GenPayloadRespQ (TmpPayloadGenRespData, 214b)
   signal genPayloadRespQNotFull : sl;
   signal genPayloadRespQValid   : sl;
   signal genPayloadRespQDout    : slv(TMP_RESP_W_C-1 downto 0);
   signal genPayloadRespQWrEn    : sl;
   signal genPayloadRespQRdEn    : sl;
   signal genPayloadRespQDin     : slv(TMP_RESP_W_C-1 downto 0);

   -- U_TotalMetaDataOutQ (PayloadGenTotalMetaData, 27b) — read by external pipe
   signal totalMetaDataOutQNotFull : sl;
   signal totalMetaDataOutQValid   : sl;
   signal totalMetaDataOutQDout    : slv(TOTAL_META_W_C-1 downto 0);
   signal totalMetaDataOutQWrEn    : sl;
   signal totalMetaDataOutQDin     : slv(TOTAL_META_W_C-1 downto 0);

   -- U_AddPaddingDataQ (Tuple2(PayloadGenRespSG,TmpPaddingData), 147b)
   signal addPaddingDataQNotFull : sl;
   signal addPaddingDataQValid   : sl;
   signal addPaddingDataQDout    : slv(ADD_PAD_Q_W_C-1 downto 0);
   signal addPaddingDataQWrEn    : sl;
   signal addPaddingDataQRdEn    : sl;
   signal addPaddingDataQDin     : slv(ADD_PAD_Q_W_C-1 downto 0);

   -- U_PayloadGenRespQ (PayloadGenRespSG, 81b) — read by external srvPort.response
   signal payloadGenRespQNotFull : sl;
   signal payloadGenRespQValid   : sl;
   signal payloadGenRespQDout    : slv(PAYLOAD_GEN_RESP_W_C-1 downto 0);
   signal payloadGenRespQWrEn    : sl;
   signal payloadGenRespQDin     : slv(PAYLOAD_GEN_RESP_W_C-1 downto 0);

   -- U_SgePayloadOutQ (DataStream, 290b) — read by child U_SgeMergedPayload
   signal sgePayloadOutQNotFull : sl;
   signal sgePayloadOutQValid   : sl;
   signal sgePayloadOutQDout    : slv(DS_W_C-1 downto 0);
   signal sgePayloadOutQWrEn    : sl;
   signal sgePayloadOutQRdEn    : sl;
   signal sgePayloadOutQDin     : slv(DS_W_C-1 downto 0);

   -- U_PayloadBufQ (DataStream, 290b, BRAM depth 256) — read by child U_BramQ2PipeOut
   signal payloadBufQNotFull : sl;
   signal payloadBufQValid   : sl;
   signal payloadBufQDout    : slv(DS_W_C-1 downto 0);
   signal payloadBufQWrEn    : sl;
   signal payloadBufQRdEn    : sl;
   signal payloadBufQDin     : slv(DS_W_C-1 downto 0);

   -- Internal child-to-child PipeOut(DataStream) links
   signal sgeMergedPayloadValid : sl;
   signal sgeMergedPayloadData  : slv(DS_W_C-1 downto 0);
   signal sgeMergedPayloadRdEn  : sl;

   signal sglMergedPayloadValid : sl;
   signal sglMergedPayloadData  : slv(DS_W_C-1 downto 0);
   signal sglMergedPayloadRdEn  : sl;

   signal adjustedPayloadValid : sl;
   signal adjustedPayloadData  : slv(DS_W_C-1 downto 0);
   signal adjustedPayloadRdEn  : sl;

begin

   -----------------------------------------------------------------------------
   -- Static wiring
   -----------------------------------------------------------------------------
   fifoRst <= rst or clearAllI;                             -- shared FIFO soft clear

   -- srvPort handshake passthroughs (BSV toGPServer implicit conditions)
   reqInReady   <= payloadGenReqQNotFull;
   respOutValid <= payloadGenRespQValid;
   respOutData  <= payloadGenRespQDout;

   -- totalMetaDataPipeOut passthrough (toPipeOut(totalMetaDataOutQ))
   totalMetaDataNotEmpty <= totalMetaDataOutQValid;
   totalMetaDataFirst    <= totalMetaDataOutQDout;

   -----------------------------------------------------------------------------
   -- Combinatorial FSM: 7 conflict_free workers + iterator + reset
   -----------------------------------------------------------------------------
   comb : process (r, rst, clearAllI,
                   payloadGenReqQValid, payloadGenReqQDout, adjustReqPktLenQNotFull,
                   dmaReadCntrlRespValid, dmaReadCntrlRespData, sgePayloadOutQNotFull,
                   adjustReqPktLenQValid, adjustReqPktLenQDout, adjustFirstLastQNotFull,
                   dmaReadCntrlReqReady,
                   adjustFirstLastQValid, adjustFirstLastQDout, adjustTotalQNotFull,
                   adjustTotalQValid, adjustTotalQDout, adjustedTotalQNotFull,
                   genPayloadRespQNotFull, totalMetaDataOutQNotFull,
                   genPayloadRespQValid, genPayloadRespQDout, addPaddingDataQNotFull,
                   addPaddingDataQValid, addPaddingDataQDout,
                   adjustedPayloadValid, adjustedPayloadData, payloadBufQNotFull,
                   payloadGenRespQNotFull) is
      variable v : RegType;

      -- recvReq temporaries
      variable reqRaddr      : slv(ADDR_W_C-1 downto 0);
      variable reqTotalLen   : slv(LEN_W_C-1 downto 0);
      variable reqPmtu       : slv(PMTU_W_C-1 downto 0);
      variable reqZeroLen    : sl;
      variable soAlignAddr   : slv(ADDR_W_C-1 downto 0);
      variable soPmtuLen     : slv(PKTLEN_W_C-1 downto 0);
      variable soAddrLow     : slv(PKTLEN_W_C-1 downto 0);
      variable soLenLow      : slv(PKTLEN_W_C-1 downto 0);
      variable soPmtuMask    : slv(PKTLEN_W_C-1 downto 0);
      variable soTruncPktNum : slv(PKTNUM_W_C-1 downto 0);
      variable soMaxFirst    : slv(PKTLEN_W_C-1 downto 0);
      variable soAddrLenSum  : slv(PKTLEN_W_C-1 downto 0);
      variable metaVec       : slv(TMP_META_W_C-1 downto 0);

      -- issueDmaReadCntrlReq temporaries
      variable reqV          : slv(PAYLOAD_GEN_REQ_W_C-1 downto 0);
      variable metaV         : slv(TMP_META_W_C-1 downto 0);
      variable stPmtuMask    : slv(PKTLEN_W_C-1 downto 0);
      variable stAddrLenSum  : slv(PKTLEN_W_C-1 downto 0);
      variable stPmtuLen     : slv(PKTLEN_W_C-1 downto 0);
      variable stLenLow      : slv(PKTLEN_W_C-1 downto 0);
      variable stMaxFirst    : slv(PKTLEN_W_C-1 downto 0);
      variable stTruncPktNum : slv(PKTNUM_W_C-1 downto 0);
      variable stAlignAddr   : slv(ADDR_W_C-1 downto 0);
      variable stZeroLen     : sl;
      variable stRaddr       : slv(ADDR_W_C-1 downto 0);
      variable stPmtu        : slv(PMTU_W_C-1 downto 0);
      variable stAddPadding  : sl;
      variable secondAddr    : slv(ADDR_W_C-1 downto 0);
      variable tmpLastPktLen : slv(PKTLEN_W_C-1 downto 0);
      variable pmtuInvMask   : slv(PKTLEN_W_C-1 downto 0);
      variable hasResidue    : sl;
      variable hasExtraPkt   : sl;
      variable notFullPkt    : sl;
      variable pktNumAddOne  : slv(ADDON_W_C-1 downto 0);
      variable resBit        : slv(ADDON_W_C-1 downto 0);
      variable extBit        : slv(ADDON_W_C-1 downto 0);

      -- adjustFirstAndLastPktLen temporaries
      variable aOrigAddr     : slv(ADDR_W_C-1 downto 0);
      variable aSecondAddr   : slv(ADDR_W_C-1 downto 0);
      variable aTotalLen     : slv(LEN_W_C-1 downto 0);
      variable aTruncPktNum  : slv(PKTNUM_W_C-1 downto 0);
      variable aPktNumAddOne : slv(ADDON_W_C-1 downto 0);
      variable aLenLow       : slv(PKTLEN_W_C-1 downto 0);
      variable aMaxFirst     : slv(PKTLEN_W_C-1 downto 0);
      variable aTmpLast      : slv(PKTLEN_W_C-1 downto 0);
      variable aPmtuLen      : slv(PKTLEN_W_C-1 downto 0);
      variable aPmtu         : slv(PMTU_W_C-1 downto 0);
      variable aNotFullPkt   : sl;
      variable aHasExtraPkt  : sl;
      variable aHasResidue   : sl;
      variable aZeroLen      : sl;
      variable aAddPadding   : sl;
      variable aTotalPktNum  : slv(PKTNUM_W_C-1 downto 0);
      variable aFirstPktLen  : slv(PKTLEN_W_C-1 downto 0);
      variable aLastPktLen   : slv(PKTLEN_W_C-1 downto 0);

      -- calcAdjustedTotalPayloadMetaData temporaries
      variable cFirstAddr    : slv(ADDR_W_C-1 downto 0);
      variable cSecondAddr   : slv(ADDR_W_C-1 downto 0);
      variable cTotalLen     : slv(LEN_W_C-1 downto 0);
      variable cTotalPktNum  : slv(PKTNUM_W_C-1 downto 0);
      variable cFirstPktLen  : slv(PKTLEN_W_C-1 downto 0);
      variable cLastPktLen   : slv(PKTLEN_W_C-1 downto 0);
      variable cPmtuLen      : slv(PKTLEN_W_C-1 downto 0);
      variable cPmtu         : slv(PMTU_W_C-1 downto 0);
      variable cZeroLen      : sl;
      variable cAddPadding   : sl;
      variable cOrigLastVBN  : slv(BEBN_W_C-1 downto 0);
      variable cFirstLastVBN : slv(BEBN_W_C-1 downto 0);
      variable cLastLastVBN  : slv(BEBN_W_C-1 downto 0);
      variable cFirstFragNum : slv(FRAGNUM_W_C-1 downto 0);
      variable cFirstPad     : slv(PAD_W_C-1 downto 0);
      variable cLastPad      : slv(PAD_W_C-1 downto 0);
      variable cIsOnlyPkt    : sl;
      variable cFirstLastVBNwp : slv(BEBN_W_C-1 downto 0);
      variable cLastLastVBNwp  : slv(BEBN_W_C-1 downto 0);

      -- genPayloadGenResp temporaries
      variable gFirstAddr    : slv(ADDR_W_C-1 downto 0);
      variable gSecondAddr   : slv(ADDR_W_C-1 downto 0);
      variable gFirstPktLen  : slv(PKTLEN_W_C-1 downto 0);
      variable gLastPktLen   : slv(PKTLEN_W_C-1 downto 0);
      variable gPmtuLen      : slv(PKTLEN_W_C-1 downto 0);
      variable gFirstLastVBNwp : slv(BEBN_W_C-1 downto 0);
      variable gLastLastVBNwp  : slv(BEBN_W_C-1 downto 0);
      variable gFirstPad     : slv(PAD_W_C-1 downto 0);
      variable gLastPad      : slv(PAD_W_C-1 downto 0);
      variable gTotalPktNum  : slv(PKTNUM_W_C-1 downto 0);
      variable gPmtu         : slv(PMTU_W_C-1 downto 0);
      variable gIsOnlyPkt    : sl;
      variable gZeroLen      : sl;
      variable gAddPadding   : sl;
      variable gRemoteAddr   : slv(ADDR_W_C-1 downto 0);
      variable gNextAddr     : slv(ADDR_W_C-1 downto 0);
      variable gRemainPktNum : slv(PKTNUM_W_C-1 downto 0);
      variable gIsFirstPkt   : sl;
      variable gIsLastPkt    : sl;
      variable gPktLen       : slv(PKTLEN_W_C-1 downto 0);
      variable gPadCnt       : slv(PAD_W_C-1 downto 0);
      variable gFirstByteEn  : slv(BYTEEN_W_C-1 downto 0);
      variable gLastByteEn   : slv(BYTEEN_W_C-1 downto 0);
      variable gResp         : slv(PAYLOAD_GEN_RESP_W_C-1 downto 0);
      variable gPad          : slv(TMP_PAD_W_C-1 downto 0);

      -- outputAndAddPadding temporaries
      variable oResp         : slv(PAYLOAD_GEN_RESP_W_C-1 downto 0);
      variable oPad          : slv(TMP_PAD_W_C-1 downto 0);
      variable oRespIsFirst  : sl;
      variable oRespIsLast   : sl;
      variable oZeroLen      : sl;
      variable oAddPadding   : sl;
      variable oFirstByteEn  : slv(BYTEEN_W_C-1 downto 0);
      variable oLastByteEn   : slv(BYTEEN_W_C-1 downto 0);
      variable oFrag         : slv(DS_W_C-1 downto 0);
      variable oFragIsLast   : sl;
      variable oByteEn       : slv(BYTEEN_W_C-1 downto 0);
   begin
      v := r;

      -- Default Mealy drives (all deasserted)
      payloadGenReqQRdEn    <= '0';
      adjustReqPktLenQWrEn  <= '0';
      adjustReqPktLenQDin   <= (others => '0');
      adjustReqPktLenQRdEn  <= '0';
      dmaReadCntrlRespReady <= '0';
      sgePayloadOutQWrEn    <= '0';
      sgePayloadOutQDin     <= (others => '0');
      dmaReadCntrlReqValid  <= '0';
      dmaReadCntrlReqData   <= (others => '0');
      adjustFirstLastQWrEn  <= '0';
      adjustFirstLastQDin   <= (others => '0');
      adjustFirstLastQRdEn  <= '0';
      adjustTotalQWrEn      <= '0';
      adjustTotalQDin       <= (others => '0');
      adjustTotalQRdEn      <= '0';
      adjustedTotalQWrEn    <= '0';
      adjustedTotalQDin     <= (others => '0');
      genPayloadRespQWrEn   <= '0';
      genPayloadRespQDin    <= (others => '0');
      genPayloadRespQRdEn   <= '0';
      totalMetaDataOutQWrEn <= '0';
      totalMetaDataOutQDin  <= (others => '0');
      addPaddingDataQWrEn   <= '0';
      addPaddingDataQDin    <= (others => '0');
      addPaddingDataQRdEn   <= '0';
      payloadGenRespQWrEn   <= '0';
      payloadGenRespQDin    <= (others => '0');
      payloadBufQWrEn       <= '0';
      payloadBufQDin        <= (others => '0');
      adjustedPayloadRdEn   <= '0';

      -------------------------------------------------------------------------
      -- recvReq (stepOne): split PayloadGenReqSG head, enq adjustReqPktLenQ
      -------------------------------------------------------------------------
      reqRaddr    := payloadGenReqQDout(67 downto 4);
      reqTotalLen := payloadGenReqQDout(99 downto 68);
      reqPmtu     := payloadGenReqQDout(3 downto 1);
      if (unsigned(reqTotalLen) = 0) then reqZeroLen := '1'; else reqZeroLen := '0'; end if;

      soAlignAddr   := alignAddrByPMTU(reqRaddr, reqPmtu);
      soPmtuLen     := calcPmtuLen(reqPmtu);
      soAddrLow     := addrLowPartF(reqRaddr, reqPmtu);
      soLenLow      := lenLowPartF(reqTotalLen, reqPmtu);
      soPmtuMask    := pmtuMaskF(reqPmtu);
      soTruncPktNum := truncatedPktNumF(reqTotalLen, reqPmtu);
      soMaxFirst    := slv(unsigned(soPmtuLen) - unsigned(soAddrLow));
      soAddrLenSum  := slv(unsigned(soAddrLow) + unsigned(soLenLow));

      -- TmpPayloadGenMetaData (155b): pmtuMask, addrAndLenLowPartSum, pmtuLen,
      -- lenLowPart, maxFirstPktLen, truncatedPktNum, pmtuAlignedStartAddr, isZeroPayloadLen
      metaVec := soPmtuMask & soAddrLenSum & soPmtuLen & soLenLow & soMaxFirst &
                 soTruncPktNum & soAlignAddr & reqZeroLen;

      if (clearAllI = '0') and (payloadGenReqQValid = '1') and (adjustReqPktLenQNotFull = '1') then
         payloadGenReqQRdEn   <= '1';
         adjustReqPktLenQWrEn <= '1';
         adjustReqPktLenQDin  <= payloadGenReqQDout & metaVec;   -- Tuple2 (req at MSB)
      end if;

      -------------------------------------------------------------------------
      -- recvDmaReadCntrlResp: get DmaReadCntrlResp, enq its DataStream to sgePayloadOutQ
      -------------------------------------------------------------------------
      if (clearAllI = '0') and (dmaReadCntrlRespValid = '1') and (sgePayloadOutQNotFull = '1') then
         dmaReadCntrlRespReady <= '1';
         sgePayloadOutQWrEn    <= '1';
         sgePayloadOutQDin     <= dmaReadCntrlRespData(291 downto 2);  -- dmaReadResp.dataStream
      end if;

      -------------------------------------------------------------------------
      -- issueDmaReadCntrlReq (stepTwo): optional DMA request + enq adjustFirstAndLastPktLenQ
      -------------------------------------------------------------------------
      reqV  := adjustReqPktLenQDout(ADJ_REQ_Q_W_C-1 downto TMP_META_W_C);  -- PayloadGenReqSG (1228)
      metaV := adjustReqPktLenQDout(TMP_META_W_C-1 downto 0);              -- TmpPayloadGenMetaData (155)

      stPmtuMask    := metaV(154 downto 142);
      stAddrLenSum  := metaV(141 downto 129);
      stPmtuLen     := metaV(128 downto 116);
      stLenLow      := metaV(115 downto 103);
      stMaxFirst    := metaV(102 downto 90);
      stTruncPktNum := metaV(89 downto 65);
      stAlignAddr   := metaV(64 downto 1);
      stZeroLen     := metaV(0);
      stRaddr       := reqV(67 downto 4);
      stPmtu        := reqV(3 downto 1);
      stAddPadding  := reqV(0);

      secondAddr    := addrAddOnePMTU(stAlignAddr, stPmtu);
      tmpLastPktLen := '0' & truncateByPMTU(stAddrLenSum, stPmtu);        -- zeroExtend 12b->13b
      pmtuInvMask   := not stPmtuMask;
      if (unsigned(stPmtuMask and stAddrLenSum) = 0) then hasResidue := '0'; else hasResidue := '1'; end if;
      if (unsigned(pmtuInvMask and stAddrLenSum) = 0) then hasExtraPkt := '0'; else hasExtraPkt := '1'; end if;
      if (unsigned(stTruncPktNum) = 0) then notFullPkt := '1'; else notFullPkt := '0'; end if;
      resBit := '0' & hasResidue;
      extBit := '0' & hasExtraPkt;
      pktNumAddOne := slv(unsigned(resBit) + unsigned(extBit));

      -- TmpAdjustFirstAndLastPktLen (247b): origRemoteAddr, secondChunkStartAddr,
      -- totalLen, truncatedPktNum, pktNumAddOne, lenLowPart, maxFirstPktLen,
      -- tmpLastPktLen, pmtuLen, pmtu, notFullPkt, hasExtraPkt, hasResidue,
      -- isZeroPayloadLen, shouldAddPadding
      adjustFirstLastQDin <= stRaddr & secondAddr & reqV(99 downto 68) & stTruncPktNum &
                             pktNumAddOne & stLenLow & stMaxFirst & tmpLastPktLen & stPmtuLen &
                             stPmtu & notFullPkt & hasExtraPkt & hasResidue & stZeroLen & stAddPadding;

      if (clearAllI = '0') and (adjustReqPktLenQValid = '1') and (adjustFirstLastQNotFull = '1')
         and ((stZeroLen = '1') or (dmaReadCntrlReqReady = '1')) then
         adjustReqPktLenQRdEn <= '1';
         adjustFirstLastQWrEn <= '1';
         if (stZeroLen = '0') then
            dmaReadCntrlReqValid <= '1';
            -- DmaReadCntrlReq (1163b): sgl, totalLen, sqpn, wrID, pmtu
            dmaReadCntrlReqData <= reqV(1139 downto 100) &     -- sgl (1040)
                                   reqV(99 downto 68) &        -- totalLen (32)
                                   reqV(1163 downto 1140) &    -- sqpn (24)
                                   reqV(1227 downto 1164) &    -- wrID (64)
                                   reqV(3 downto 1);           -- pmtu (3)
         end if;
      end if;

      -------------------------------------------------------------------------
      -- adjustFirstAndLastPktLen (stepThree): enq adjustTotalPayloadMetaDataQ
      -------------------------------------------------------------------------
      aOrigAddr     := adjustFirstLastQDout(246 downto 183);
      aSecondAddr   := adjustFirstLastQDout(182 downto 119);
      aTotalLen     := adjustFirstLastQDout(118 downto 87);
      aTruncPktNum  := adjustFirstLastQDout(86 downto 62);
      aPktNumAddOne := adjustFirstLastQDout(61 downto 60);
      aLenLow       := adjustFirstLastQDout(59 downto 47);
      aMaxFirst     := adjustFirstLastQDout(46 downto 34);
      aTmpLast      := adjustFirstLastQDout(33 downto 21);
      aPmtuLen      := adjustFirstLastQDout(20 downto 8);
      aPmtu         := adjustFirstLastQDout(7 downto 5);
      aNotFullPkt   := adjustFirstLastQDout(4);
      aHasExtraPkt  := adjustFirstLastQDout(3);
      aHasResidue   := adjustFirstLastQDout(2);
      aZeroLen      := adjustFirstLastQDout(1);
      aAddPadding   := adjustFirstLastQDout(0);

      aTotalPktNum := slv(unsigned(aTruncPktNum) + resize(unsigned(aPktNumAddOne), PKTNUM_W_C));
      if (aNotFullPkt = '1') and (aHasExtraPkt = '0') then
         aFirstPktLen := aLenLow;
      else
         aFirstPktLen := aMaxFirst;
      end if;
      if (aHasResidue = '1') then
         aLastPktLen := aTmpLast;
      elsif (aNotFullPkt = '1') then
         aLastPktLen := aLenLow;
      else
         aLastPktLen := aPmtuLen;
      end if;

      -- TmpAdjustTotalPayloadMetaData (229b): firstRemoteAddr, secondRemoteAddr,
      -- totalLen, totalPktNum, firstPktLen, lastPktLen, pmtuLen, pmtu,
      -- isZeroPayloadLen, shouldAddPadding
      adjustTotalQDin <= aOrigAddr & aSecondAddr & aTotalLen & aTotalPktNum &
                         aFirstPktLen & aLastPktLen & aPmtuLen & aPmtu & aZeroLen & aAddPadding;

      if (clearAllI = '0') and (adjustFirstLastQValid = '1') and (adjustTotalQNotFull = '1') then
         adjustFirstLastQRdEn <= '1';
         adjustTotalQWrEn     <= '1';
      end if;

      -------------------------------------------------------------------------
      -- calcAdjustedTotalPayloadMetaData: enq adjustedTotalQ (opt), genPayloadRespQ, totalMetaDataOutQ
      -------------------------------------------------------------------------
      cFirstAddr   := adjustTotalQDout(228 downto 165);
      cSecondAddr  := adjustTotalQDout(164 downto 101);
      cTotalLen    := adjustTotalQDout(100 downto 69);
      cTotalPktNum := adjustTotalQDout(68 downto 44);
      cFirstPktLen := adjustTotalQDout(43 downto 31);
      cLastPktLen  := adjustTotalQDout(30 downto 18);
      cPmtuLen     := adjustTotalQDout(17 downto 5);
      cPmtu        := adjustTotalQDout(4 downto 2);
      cZeroLen     := adjustTotalQDout(1);
      cAddPadding  := adjustTotalQDout(0);

      cOrigLastVBN  := calcLastFragValidByteNum(cTotalLen);
      cFirstLastVBN := calcLastFragValidByteNum(cFirstPktLen);
      cLastLastVBN  := calcLastFragValidByteNum(cLastPktLen);
      cFirstFragNum := calcFragNumByPktLen(cFirstPktLen);
      cFirstPad     := calcPadCnt(cFirstPktLen);
      cLastPad      := calcPadCnt(cLastPktLen);
      if (unsigned(cTotalPktNum(PKTNUM_W_C-1 downto 1)) = 0) then cIsOnlyPkt := '1'; else cIsOnlyPkt := '0'; end if;
      cFirstLastVBNwp := slv(unsigned(cFirstLastVBN) + resize(unsigned(cFirstPad), BEBN_W_C));
      cLastLastVBNwp  := slv(unsigned(cLastLastVBN)  + resize(unsigned(cLastPad),  BEBN_W_C));

      -- AdjustedTotalPayloadMetaData (61b): firstPktLen, firstPktFragNum,
      -- firstPktLastFragValidByteNum, origLastFragValidByteNum, adjustedPktNum, pmtu
      adjustedTotalQDin <= cFirstPktLen & cFirstFragNum & cFirstLastVBN &
                           cOrigLastVBN & cTotalPktNum & cPmtu;

      -- TmpPayloadGenRespData (214b): firstRemoteAddr, secondRemoteAddr, firstPktLen,
      -- lastPktLen, pmtuLen, firstPktLastFragValidByteNumWithPadding,
      -- lastPktLastFragValidByteNumWithPadding, firstPktPadCnt, lastPktPadCnt,
      -- totalPktNum, pmtu, isOnlyPkt, isZeroPayloadLen, shouldAddPadding
      genPayloadRespQDin <= cFirstAddr & cSecondAddr & cFirstPktLen & cLastPktLen & cPmtuLen &
                            cFirstLastVBNwp & cLastLastVBNwp & cFirstPad & cLastPad &
                            cTotalPktNum & cPmtu & cIsOnlyPkt & cZeroLen & cAddPadding;

      -- PayloadGenTotalMetaData (27b): totalPktNum, isOnlyPkt, isZeroPayloadLen
      totalMetaDataOutQDin <= cTotalPktNum & cIsOnlyPkt & cZeroLen;

      if (clearAllI = '0') and (adjustTotalQValid = '1') and (genPayloadRespQNotFull = '1')
         and (totalMetaDataOutQNotFull = '1')
         and ((cZeroLen = '1') or (adjustedTotalQNotFull = '1')) then
         adjustTotalQRdEn      <= '1';
         genPayloadRespQWrEn   <= '1';
         totalMetaDataOutQWrEn <= '1';
         if (cZeroLen = '0') then
            adjustedTotalQWrEn <= '1';
         end if;
      end if;

      -------------------------------------------------------------------------
      -- genPayloadGenResp (iterator): 2-phase Mealy on isFirstPktReg
      -------------------------------------------------------------------------
      gFirstAddr      := genPayloadRespQDout(213 downto 150);
      gSecondAddr     := genPayloadRespQDout(149 downto 86);
      gFirstPktLen    := genPayloadRespQDout(85 downto 73);
      gLastPktLen     := genPayloadRespQDout(72 downto 60);
      gPmtuLen        := genPayloadRespQDout(59 downto 47);
      gFirstLastVBNwp := genPayloadRespQDout(46 downto 41);
      gLastLastVBNwp  := genPayloadRespQDout(40 downto 35);
      gFirstPad       := genPayloadRespQDout(34 downto 33);
      gLastPad        := genPayloadRespQDout(32 downto 31);
      gTotalPktNum    := genPayloadRespQDout(30 downto 6);
      gPmtu           := genPayloadRespQDout(5 downto 3);
      gIsOnlyPkt      := genPayloadRespQDout(2);
      gZeroLen        := genPayloadRespQDout(1);
      gAddPadding     := genPayloadRespQDout(0);

      if (r.isFirstPktReg = '1') then
         gRemoteAddr := gFirstAddr;
         gNextAddr   := gSecondAddr;
         if (gIsOnlyPkt = '1') then
            gRemainPktNum := std_logic_vector(to_unsigned(1, PKTNUM_W_C));
         else
            gRemainPktNum := slv(unsigned(gTotalPktNum) - 1);
         end if;
      else
         gRemoteAddr   := r.pktRemoteAddrReg;
         gNextAddr     := addrAddOnePMTU(r.pktRemoteAddrReg, gPmtu);
         gRemainPktNum := slv(unsigned(r.remainingPktNumReg) - 1);
      end if;

      gIsFirstPkt := r.isFirstPktReg;
      -- isLastPkt = isOnlyPkt or (!isFirstPktReg and isOne(remainingPktNumReg))
      gIsLastPkt := '0';
      if (gIsOnlyPkt = '1') then
         gIsLastPkt := '1';
      elsif (r.isFirstPktReg = '0') and (unsigned(r.remainingPktNumReg(PKTNUM_W_C-1 downto 1)) = 0)
            and (r.remainingPktNumReg(0) = '1') then
         gIsLastPkt := '1';
      end if;

      if (gIsFirstPkt = '1') then
         gPktLen := gFirstPktLen;
         gPadCnt := gFirstPad;
      elsif (gIsLastPkt = '1') then
         gPktLen := gLastPktLen;
         gPadCnt := gLastPad;
      else
         gPktLen := gPmtuLen;
         gPadCnt := (others => '0');
      end if;

      gFirstByteEn := genByteEn(gFirstLastVBNwp);
      gLastByteEn  := genByteEn(gLastLastVBNwp);

      -- PayloadGenRespSG (81b): raddr, pktLen, padCnt, isFirst, isLast
      gResp := gRemoteAddr & gPktLen & gPadCnt & gIsFirstPkt & gIsLastPkt;
      -- TmpPaddingData (66b): firstPktLastFragByteEnWithPadding,
      -- lastPktLastFragByteEnWithPadding, isZeroPayloadLen, shouldAddPadding
      gPad := gFirstByteEn & gLastByteEn & gZeroLen & gAddPadding;

      -- Tuple2(PayloadGenRespSG, TmpPaddingData) (147b, resp at MSB)
      addPaddingDataQDin <= gResp & gPad;

      if (clearAllI = '0') and (genPayloadRespQValid = '1') and (addPaddingDataQNotFull = '1') then
         addPaddingDataQWrEn <= '1';
         v.isFirstPktReg      := gIsLastPkt;
         v.pktRemoteAddrReg   := gNextAddr;
         v.remainingPktNumReg := gRemainPktNum;
         if (gIsLastPkt = '1') then
            genPayloadRespQRdEn <= '1';
         end if;
      end if;

      -------------------------------------------------------------------------
      -- outputAndAddPadding: zero-payload / data(non-last frag) / data(last frag)
      -------------------------------------------------------------------------
      oResp        := addPaddingDataQDout(ADD_PAD_Q_W_C-1 downto TMP_PAD_W_C);  -- PayloadGenRespSG (81)
      oPad         := addPaddingDataQDout(TMP_PAD_W_C-1 downto 0);              -- TmpPaddingData (66)
      oRespIsFirst := oResp(1);
      oRespIsLast  := oResp(0);
      oFirstByteEn := oPad(65 downto 34);
      oLastByteEn  := oPad(33 downto 2);
      oZeroLen     := oPad(1);
      oAddPadding  := oPad(0);

      oFrag       := adjustedPayloadData;
      oFragIsLast := adjustedPayloadData(0);            -- DataStream.isLast

      -- last-fragment byteEn override (only when shouldAddPadding on the orig last frag)
      oByteEn := oFrag(33 downto 2);
      if (oAddPadding = '1') then
         if (oRespIsFirst = '1') then
            oByteEn := oFirstByteEn;
         elsif (oRespIsLast = '1') then
            oByteEn := oLastByteEn;
         end if;
      end if;

      if (clearAllI = '0') then
         if (oZeroLen = '1') then
            -- zero-payload path: emit response only, no BRAM write
            if (addPaddingDataQValid = '1') and (payloadGenRespQNotFull = '1') then
               addPaddingDataQRdEn <= '1';
               payloadGenRespQWrEn <= '1';
               payloadGenRespQDin  <= oResp;
            end if;
         else
            -- data path
            if (addPaddingDataQValid = '1') and (adjustedPayloadValid = '1') and (payloadBufQNotFull = '1') then
               if (oFragIsLast = '0') then
                  -- non-last fragment: forward frag, keep pending pad entry
                  adjustedPayloadRdEn <= '1';
                  payloadBufQWrEn     <= '1';
                  payloadBufQDin      <= oFrag;
               elsif (payloadGenRespQNotFull = '1') then
                  -- last fragment: (opt) pad byteEn, retire pad entry, emit response
                  adjustedPayloadRdEn <= '1';
                  addPaddingDataQRdEn <= '1';
                  payloadGenRespQWrEn <= '1';
                  payloadGenRespQDin  <= oResp;
                  payloadBufQWrEn     <= '1';
                  payloadBufQDin      <= oFrag(DS_W_C-1 downto 34) & oByteEn & oFrag(1 downto 0);
               end if;
            end if;
         end if;
      end if;

      -------------------------------------------------------------------------
      -- resetAndClear (top priority): force isFirstPktReg; mkRegU regs unreset
      -------------------------------------------------------------------------
      if (rst = '1') or (clearAllI = '1') then
         v.isFirstPktReg := '1';                          -- BSV: isFirstPktReg <= True
         -- pktRemoteAddrReg / remainingPktNumReg are mkRegU: NOT reset
      end if;

      rin <= v;
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin;
      end if;
   end process seq;

   -----------------------------------------------------------------------------
   -- SURF FIFOs (source: surf/base/fifo/rtl/Fifo.vhd)
   -----------------------------------------------------------------------------
   U_PayloadGenReqQ : entity surf.Fifo         -- payloadGenReqQ <- mkFIFOF
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => PAYLOAD_GEN_REQ_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst => fifoRst, wr_clk => clk, wr_en => reqInValid, din => reqInData,
         not_full => payloadGenReqQNotFull, full => open, wr_ack => open, overflow => open,
         prog_full => open, almost_full => open, wr_data_count => open,
         rd_clk => clk, rd_en => payloadGenReqQRdEn, dout => payloadGenReqQDout,
         valid => payloadGenReqQValid, underflow => open, prog_empty => open,
         almost_empty => open, empty => open, rd_data_count => open);

   U_AdjustReqPktLenQ : entity surf.Fifo       -- adjustReqPktLenQ <- mkFIFOF (Tuple2)
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => ADJ_REQ_Q_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst => fifoRst, wr_clk => clk, wr_en => adjustReqPktLenQWrEn, din => adjustReqPktLenQDin,
         not_full => adjustReqPktLenQNotFull, full => open, wr_ack => open, overflow => open,
         prog_full => open, almost_full => open, wr_data_count => open,
         rd_clk => clk, rd_en => adjustReqPktLenQRdEn, dout => adjustReqPktLenQDout,
         valid => adjustReqPktLenQValid, underflow => open, prog_empty => open,
         almost_empty => open, empty => open, rd_data_count => open);

   U_AdjustFirstAndLastPktLenQ : entity surf.Fifo  -- adjustFirstAndLastPktLenQ <- mkFIFOF
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => TMP_FL_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst => fifoRst, wr_clk => clk, wr_en => adjustFirstLastQWrEn, din => adjustFirstLastQDin,
         not_full => adjustFirstLastQNotFull, full => open, wr_ack => open, overflow => open,
         prog_full => open, almost_full => open, wr_data_count => open,
         rd_clk => clk, rd_en => adjustFirstLastQRdEn, dout => adjustFirstLastQDout,
         valid => adjustFirstLastQValid, underflow => open, prog_empty => open,
         almost_empty => open, empty => open, rd_data_count => open);

   U_AdjustTotalPayloadMetaDataQ : entity surf.Fifo  -- adjustTotalPayloadMetaDataQ <- mkFIFOF
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => TMP_TOTAL_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst => fifoRst, wr_clk => clk, wr_en => adjustTotalQWrEn, din => adjustTotalQDin,
         not_full => adjustTotalQNotFull, full => open, wr_ack => open, overflow => open,
         prog_full => open, almost_full => open, wr_data_count => open,
         rd_clk => clk, rd_en => adjustTotalQRdEn, dout => adjustTotalQDout,
         valid => adjustTotalQValid, underflow => open, prog_empty => open,
         almost_empty => open, empty => open, rd_data_count => open);

   U_AdjustedTotalPayloadMetaDataQ : entity surf.Fifo  -- adjustedTotalPayloadMetaDataQ <- mkFIFOF
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => ADJ_TOTAL_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst => fifoRst, wr_clk => clk, wr_en => adjustedTotalQWrEn, din => adjustedTotalQDin,
         not_full => adjustedTotalQNotFull, full => open, wr_ack => open, overflow => open,
         prog_full => open, almost_full => open, wr_data_count => open,
         rd_clk => clk, rd_en => adjustedTotalQRdEn, dout => adjustedTotalQDout,
         valid => adjustedTotalQValid, underflow => open, prog_empty => open,
         almost_empty => open, empty => open, rd_data_count => open);

   U_GenPayloadRespQ : entity surf.Fifo        -- genPayloadRespQ <- mkFIFOF
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => TMP_RESP_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst => fifoRst, wr_clk => clk, wr_en => genPayloadRespQWrEn, din => genPayloadRespQDin,
         not_full => genPayloadRespQNotFull, full => open, wr_ack => open, overflow => open,
         prog_full => open, almost_full => open, wr_data_count => open,
         rd_clk => clk, rd_en => genPayloadRespQRdEn, dout => genPayloadRespQDout,
         valid => genPayloadRespQValid, underflow => open, prog_empty => open,
         almost_empty => open, empty => open, rd_data_count => open);

   U_TotalMetaDataOutQ : entity surf.Fifo      -- totalMetaDataOutQ <- mkFIFOF
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => TOTAL_META_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst => fifoRst, wr_clk => clk, wr_en => totalMetaDataOutQWrEn, din => totalMetaDataOutQDin,
         not_full => totalMetaDataOutQNotFull, full => open, wr_ack => open, overflow => open,
         prog_full => open, almost_full => open, wr_data_count => open,
         rd_clk => clk, rd_en => totalMetaDataDeq, dout => totalMetaDataOutQDout,
         valid => totalMetaDataOutQValid, underflow => open, prog_empty => open,
         almost_empty => open, empty => open, rd_data_count => open);

   U_AddPaddingDataQ : entity surf.Fifo        -- addPaddingDataQ <- mkFIFOF (Tuple2)
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => ADD_PAD_Q_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst => fifoRst, wr_clk => clk, wr_en => addPaddingDataQWrEn, din => addPaddingDataQDin,
         not_full => addPaddingDataQNotFull, full => open, wr_ack => open, overflow => open,
         prog_full => open, almost_full => open, wr_data_count => open,
         rd_clk => clk, rd_en => addPaddingDataQRdEn, dout => addPaddingDataQDout,
         valid => addPaddingDataQValid, underflow => open, prog_empty => open,
         almost_empty => open, empty => open, rd_data_count => open);

   U_PayloadGenRespQ : entity surf.Fifo        -- payloadGenRespQ <- mkFIFOF
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => PAYLOAD_GEN_RESP_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst => fifoRst, wr_clk => clk, wr_en => payloadGenRespQWrEn, din => payloadGenRespQDin,
         not_full => payloadGenRespQNotFull, full => open, wr_ack => open, overflow => open,
         prog_full => open, almost_full => open, wr_data_count => open,
         rd_clk => clk, rd_en => respOutReady, dout => payloadGenRespQDout,
         valid => payloadGenRespQValid, underflow => open, prog_empty => open,
         almost_empty => open, empty => open, rd_data_count => open);

   U_SgePayloadOutQ : entity surf.Fifo         -- sgePayloadOutQ <- mkFIFOF (pipeline)
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => DS_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst => fifoRst, wr_clk => clk, wr_en => sgePayloadOutQWrEn, din => sgePayloadOutQDin,
         not_full => sgePayloadOutQNotFull, full => open, wr_ack => open, overflow => open,
         prog_full => open, almost_full => open, wr_data_count => open,
         rd_clk => clk, rd_en => sgePayloadOutQRdEn, dout => sgePayloadOutQDout,
         valid => sgePayloadOutQValid, underflow => open, prog_empty => open,
         almost_empty => open, empty => open, rd_data_count => open);

   U_PayloadBufQ : entity surf.Fifo            -- payloadBufQ <- mkSizedBRAMFIFOF (depth 256)
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "block",
         DATA_WIDTH_G    => DS_W_C,
         ADDR_WIDTH_G    => BUF_ADDR_WIDTH_C)
      port map (
         rst => fifoRst, wr_clk => clk, wr_en => payloadBufQWrEn, din => payloadBufQDin,
         not_full => payloadBufQNotFull, full => open, wr_ack => open, overflow => open,
         prog_full => open, almost_full => open, wr_data_count => open,
         rd_clk => clk, rd_en => payloadBufQRdEn, dout => payloadBufQDout,
         valid => payloadBufQValid, underflow => open, prog_empty => open,
         almost_empty => open, empty => open, rd_data_count => open);

   -----------------------------------------------------------------------------
   -- Child entities
   -----------------------------------------------------------------------------
   -- U_SgeMergedPayload : merges per-SGE payload (dmaReadCntrl.sgePktMetaDataPipeOut
   -- + sgePayloadOutQ) -> sgeMergedPayloadPipeOut
   U_SgeMergedPayload : entity surf.MergePayloadEachSge
      generic map (
         TPD_G => TPD_G)
      port map (
         clk => clk, rst => rst, clearAllI => clearAllI,
         sgePktMetaDataPipeInValid => sgePktMetaValid,
         sgePktMetaDataPipeInData  => sgePktMetaData,
         sgePktMetaDataPipeInRdEn  => sgePktMetaRdEn,
         sgePayloadPipeInValid     => sgePayloadOutQValid,
         sgePayloadPipeInData      => sgePayloadOutQDout,
         sgePayloadPipeInRdEn      => sgePayloadOutQRdEn,
         pktPayloadOutValid        => sgeMergedPayloadValid,
         pktPayloadOutData         => sgeMergedPayloadData,
         pktPayloadOutRdEn         => sgeMergedPayloadRdEn);

   -- U_SglMergedPayload : merges all-SGE payload (dmaReadCntrl.sgeMergedMetaDataPipeOut
   -- + sgeMergedPayloadPipeOut) -> sglMergedPayloadPipeOut
   U_SglMergedPayload : entity surf.MergePayloadAllSge
      generic map (
         TPD_G => TPD_G)
      port map (
         clk => clk, rst => rst, clearAllI => clearAllI,
         sgeMergedMetaDataPipeInValid => sgeMergedMetaValid,
         sgeMergedMetaDataPipeInData  => sgeMergedMetaData,
         sgeMergedMetaDataPipeInRdEn  => sgeMergedMetaRdEn,
         sgeMergedPayloadPipeInValid  => sgeMergedPayloadValid,
         sgeMergedPayloadPipeInData   => sgeMergedPayloadData,
         sgeMergedPayloadPipeInRdEn   => sgeMergedPayloadRdEn,
         pktPayloadOutValid           => sglMergedPayloadValid,
         pktPayloadOutData            => sglMergedPayloadData,
         pktPayloadOutRdEn            => sglMergedPayloadRdEn);

   -- U_AdjustedPayload : re-segments payload by adjustedTotalPayloadMetaDataQ ->
   -- adjustedPayloadPipeOut (consumed by outputAndAddPadding)
   U_AdjustedPayload : entity surf.AdjustPayloadSegment
      generic map (
         TPD_G => TPD_G)
      port map (
         clk => clk, rst => rst, clearAllI => clearAllI,
         adjustedMetaPipeInValid  => adjustedTotalQValid,
         adjustedMetaPipeInData   => adjustedTotalQDout,
         adjustedMetaPipeInRdEn   => adjustedTotalQRdEn,
         sglAllPayloadPipeInValid => sglMergedPayloadValid,
         sglAllPayloadPipeInData  => sglMergedPayloadData,
         sglAllPayloadPipeInRdEn  => sglMergedPayloadRdEn,
         pktPayloadOutValid       => adjustedPayloadValid,
         pktPayloadOutData        => adjustedPayloadData,
         pktPayloadOutRdEn        => adjustedPayloadRdEn);

   -- U_BramQ2PipeOut : drains payloadBufQ into the entity's DataStream pipeOut
   U_BramQ2PipeOut : entity surf.ConnectBramQ2PipeOutGen
      generic map (
         TPD_G    => TPD_G,
         DATA_W_G => DS_W_C)
      port map (
         clk => clk, rst => rst, clearEnI => clearAllI,
         bramQNotEmpty   => payloadBufQValid,
         bramQDout       => payloadBufQDout,
         bramQDeq        => payloadBufQRdEn,
         pipeOutDeq      => payloadDataStreamDeq,
         pipeOutFirst    => payloadDataStreamFirst,
         pipeOutNotEmpty => payloadDataStreamNotEmpty,
         notEmpty        => payloadNotEmpty);

end architecture rtl;
