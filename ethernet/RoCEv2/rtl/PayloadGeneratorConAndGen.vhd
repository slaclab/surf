-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Receives PayloadGenReq requests, issues one DmaReadCntrlReq per request to
--   the external dmaReadCntrl Server (this entity is its CLIENT), and re-streams
--   the returned DMA fragments into an output DataStream pipe, padding the last
--   fragment's byteEn when the request asked for padding.  A single mode flag
--   (isNormalStateReg) switches the issue path off after a DMA response error.
--
--   Two pipeline rules (conflict-free; may both fire the same cycle — they touch
--   disjoint FIFO endpoints and only lastFragAddPadding writes the mode flag):
--     recvPayloadGenReq  (R1) — NORMAL mode (isNonErr ∧ isNormalStateReg): deq a
--        PayloadGenReq from U_PayloadGenReqQ; compute the padded last-fragment
--        byteEn + per-PMTU fragment count; enq Tuple3(req, byteEn, fragNum) into
--        the pipeline FIFO U_PendingGenReqQ; PUT a DmaReadCntrlReq{dmaReadMetaData,
--        pmtu} to the external dmaReadCntrl.request.  (No mode-flag write.)
--     lastFragAddPadding (R2) — NORMAL or ERR mode (isNonErr ∨ isERR): GET one
--        DmaReadCntrlResp from dmaReadCntrl.response; read U_PendingGenReqQ.first;
--        on isOrigLast retire (deq) the pending entry and (if addPadding) override
--        the fragment byteEn with the precomputed padded byteEn; set
--        isNormalStateReg := NOT isRespErr; on (dataStream.isLast ∨ isRespErr) enq
--        a PayloadGenResp{addPadding, isRespErr} into U_PayloadGenRespQ; enq the
--        (possibly byteEn-patched) DataStream into the BRAM buffer U_PayloadBufQ.
--
--   The entity is a Server to its caller (srvPort: request Put PayloadGenReq into
--   U_PayloadGenReqQ / response Get PayloadGenResp from U_PayloadGenRespQ — BSV
--   toGPServer(payloadGenReqQ, payloadGenRespQ)).  Its DataStream output pipe and
--   payloadNotEmpty method are produced by the child U_BramQ2PipeOut, which owns
--   the read side of the BRAM buffer U_PayloadBufQ.
--
--   Reliability note (memory: inventory-unreliable-payloadconandgen,
--   OQ-FSM-PGCAG-01): the Stage-1/2 records for this module are WRONG (fabricated
--   rule names recvReq/bufPayload/genResp; claim 0 state regs; omit pendingGenReqQ;
--   list DmaReadCntrlConAndGen as a child).  This file follows the FSM spec / LIVE
--   BSV source: dmaReadCntrl is a MODULE PARAMETER (external Server → ports, NOT a
--   child instance); there are 4 FIFOs + 1 real child (U_BramQ2PipeOut).
--
--   State register (fsm.md §State register):
--     isNormalStateReg : sl   — NORMAL_S('1') / ERR_S('0'); reset '1'.  The only
--        LIVE state.  Read in R1's guard; written in R2 (:= NOT hasDmaRespErr).
--   Declared-but-dead regs (kept in RegType for source fidelity; assigned only by
--   the BSV resetAndClear; never read, never written by an active rule — drive
--   nothing): shouldSetFirstReg (mkReg False), isFragCntZeroReg (mkReg False),
--   pmtuFragCntReg (PktFragNum 8b, mkRegU — no reset; value irrelevant).
--
--   Mealy (combinational) drives — MUST NOT be registered (would insert a spurious
--   cycle); the FIFOs latch them internally on the clock edge:
--     U_PendingGenReqQ.din, U_PayloadGenReqQ.rd_en, dmaReadCntrlReq{Valid,Out} (R1);
--     dmaReadCntrlRespReady, U_PendingGenReqQ.rd_en, U_PayloadGenRespQ.{wr_en,din},
--     U_PayloadBufQ.{wr_en,din} (R2).  isNormalStateReg is the only registered
--     (Moore) state.
--
--   FIFO clear (OQ-FSM-01 carry-forward, RESOLVED in out/03-fsm/RESOLVED.md):
--     BSV payloadGenReqQ/payloadGenRespQ/pendingGenReqQ/payloadBufQ .clear map to
--     asserting each Fifo's rst, OR'd with the structural reset: fifoRst = rst OR
--     isReset.  surf.Fifo/FifoSync (GEN_SYNC_FIFO_G=true, RST_ASYNC_G=false,
--     RST_POLARITY_G='1') holds the FIFO logically empty for the whole asserted
--     window (level-safe; no pulse generator).  All four share fifoRst so the BSV
--     single-cycle simultaneous clear is preserved.  The child clears via clearEnI.
--
--   Helper functions (Utils.bsv) inlined below — verified against source:
--     calcPadCnt(len)              = (0 - len[1:0]) mod 4               (PAD_WIDTH=2)
--     calcLastFragValidByteNum(len)= len[4:0], or 32 if len[4:0]=0 ∧ len[31:5]≠0
--     genByteEn(n)                 = reverseBits((1<<n)-1)   (32b, n saturates ≥32)
--     calcFragNumByPMTU(pmtu)      = 1 << (pmtuLog-5): 256→8 512→16 1024→32
--                                    2048→64 4096→128
--
--   Bit layouts (BSV deriving(Bits), first-field-at-MSB; OQ-FSM-H2DS-04):
--     DmaReadMetaData (195b): [194:191]initiator(4) [190:167]sqpn(24)
--        [166:103]wrID(64) [102:39]startAddr(64) [38:7]len(32) [6:0]mrIdx(7)
--     PayloadGenReq (199b):   [198:4]dmaReadMetaData(195) [3]addPadding [2:0]pmtu(3)
--        → dmaReadMetaData.len is PayloadGenReq[42:11]
--     PayloadGenResp (2b):    [1]addPadding [0]isRespErr
--     Tuple3 pendingGenReqQ (239b): [238:40]PayloadGenReq(199)
--        [39:8]lastFragByteEnWithPadding(ByteEn,32) [7:0]pktFragNum(PktFragNum,8)
--        → PayloadGenReq.addPadding is pendingGenReqQ[43]
--     DataStream (290b):      [289:34]data(256) [33:2]byteEn(32) [1]isFirst [0]isLast
--     DmaReadResp (383b):     [382:379]initiator(4) [378:355]sqpn(24)
--        [354:291]wrID(64) [290]isRespErr [289:0]dataStream(290)
--     DmaReadCntrlReq (198b): [197:3]dmaReadMetaData(195) [2:0]pmtu(3)
--     DmaReadCntrlResp (385b):[384:2]dmaReadResp(383) [1]isOrigFirst [0]isOrigLast
--        → within it: isRespErr=[292], dataStream=[291:2]
--          (data=[291:36], byteEn=[35:4], isFirst=[3], isLast=[2]), isOrigLast=[0]
--
--   SURF components instantiated (source: surf/base/fifo/rtl/Fifo.vhd):
--     U_PayloadGenReqQ  : surf.Fifo  DATA_WIDTH_G=199, FWFT, sync, distributed RAM
--                         (BSV payloadGenReqQ <- mkFIFOF)
--     U_PayloadGenRespQ : surf.Fifo  DATA_WIDTH_G=2,   FWFT, sync, distributed RAM
--                         (BSV payloadGenRespQ <- mkFIFOF)
--     U_PendingGenReqQ  : surf.Fifo  DATA_WIDTH_G=239, FWFT, sync, distributed RAM
--                         (BSV pendingGenReqQ <- mkFIFOF — pipeline FIFO)
--     U_PayloadBufQ     : surf.Fifo  DATA_WIDTH_G=290, FWFT, sync, block RAM,
--                         ADDR_WIDTH_G=8 (depth 256 = DATA_STREAM_FRAG_BUF_SIZE =
--                         MIN_PKT_NUM_IN_RECV_BUF(2)*PMTU_MAX_FRAG_NUM(128))
--                         (BSV payloadBufQ <- mkSizedBRAMFIFOF; read side owned by
--                         the child U_BramQ2PipeOut)
--   Child entity instantiated:
--     U_BramQ2PipeOut : ConnectBramQ2PipeOutConAndGen
--                       (out/04-vhdl/ConnectBramQ2PipeOutConAndGen.vhd)
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

entity PayloadGeneratorConAndGen is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk                  : in  sl;
      rst                  : in  sl;                       -- active-high sync reset
      -- cntrlStatus (combinational status inputs from the controller)
      isReset              : in  sl;                       -- comm.isReset: sync soft clear
      isNonErr             : in  sl;                       -- comm.isNonErr
      isERR                : in  sl;                       -- comm.isERR
      -- srvPort.request : Put#(PayloadGenReq)  (caller -> entity, enq to payloadGenReqQ)
      reqInValid           : in  sl;                       -- caller offers a request (wr_en)
      reqInData            : in  slv(198 downto 0);        -- PayloadGenReq packed (199b)
      reqInReady           : out sl;                       -- entity can accept (notFull)
      -- srvPort.response : Get#(PayloadGenResp) (entity -> caller, deq from payloadGenRespQ)
      respOutReady         : in  sl;                       -- caller takes a response (rd_en)
      respOutValid         : out sl;                       -- response available (notEmpty)
      respOutData          : out slv(1 downto 0);          -- PayloadGenResp packed (2b)
      -- dmaReadCntrl.request : Put#(DmaReadCntrlReq)  (entity -> external server, CLIENT)
      dmaReadCntrlReqValid : out sl;                       -- entity offers a request (Mealy)
      dmaReadCntrlReqData  : out slv(197 downto 0);        -- DmaReadCntrlReq packed (198b)
      dmaReadCntrlReqReady : in  sl;                       -- external server can accept
      -- dmaReadCntrl.response : Get#(DmaReadCntrlResp) (external server -> entity, CLIENT)
      dmaReadCntrlRespValid : in  sl;                      -- external server offers a response
      dmaReadCntrlRespData  : in  slv(384 downto 0);       -- DmaReadCntrlResp packed (385b)
      dmaReadCntrlRespReady : out sl;                      -- entity takes the response (get)
      -- payloadDataStreamPipeOut : PipeOut#(DataStream) (entity output, via child)
      payloadDataStreamDeq      : in  sl;                  -- consumer dequeues
      payloadDataStreamFirst    : out slv(289 downto 0);   -- pipeOut.first (DataStream 290b)
      payloadDataStreamNotEmpty : out sl;                  -- pipeOut.notEmpty
      -- payloadNotEmpty() method result (Moore passthrough of the child)
      payloadNotEmpty           : out sl);
end entity PayloadGeneratorConAndGen;

architecture rtl of PayloadGeneratorConAndGen is

   -----------------------------------------------------------------------------
   -- Width constants (traced from BSV; see header bit layouts)
   -----------------------------------------------------------------------------
   constant PAYLOAD_GEN_REQ_W_C  : positive := 199;        -- PayloadGenReq
   constant PAYLOAD_GEN_RESP_W_C : positive := 2;          -- PayloadGenResp
   constant PENDING_REQ_W_C      : positive := 239;        -- Tuple3 pipeline element
   constant DATA_STREAM_W_C      : positive := 290;        -- DataStream (OQ-FSM-H2DS-02)
   constant DMA_BYTE_WIDTH_C     : natural  := 32;         -- DATA_BUS_BYTE_WIDTH
   constant BUF_ADDR_WIDTH_C     : positive := 8;          -- depth 256 = DATA_STREAM_FRAG_BUF_SIZE

   -----------------------------------------------------------------------------
   -- Helper functions (Utils.bsv) — verified against source
   -----------------------------------------------------------------------------
   -- calcPadCnt: PAD (2b) = (1<<PAD_WIDTH) - len[1:0] truncated to 2b = (0 - len[1:0])
   function calcPadCnt (len : slv) return slv is
   begin
      return slv(to_unsigned(0, 2) - unsigned(len(1 downto 0)));
   end function calcPadCnt;

   -- calcLastFragValidByteNum: ByteEnBitNum (6b)
   function calcLastFragValidByteNum (len : slv) return slv is
      variable residue      : slv(4 downto 0);
      variable truncatedLen : slv(len'length-1 downto 5);
      variable res          : slv(5 downto 0);
   begin
      residue      := len(4 downto 0);
      truncatedLen := len(len'length-1 downto 5);
      res          := '0' & residue;                       -- zeroExtend(residue) to 6b
      if (unsigned(residue) = 0) and (unsigned(truncatedLen) /= 0) then
         res := std_logic_vector(to_unsigned(DMA_BYTE_WIDTH_C, 6));  -- 32
      end if;
      return res;
   end function calcLastFragValidByteNum;

   -- genByteEn: ByteEn (32b) = reverseBits((1<<n)-1); n saturates at >=32 -> all ones
   function genByteEn (n : slv) return slv is
      variable mask : slv(DMA_BYTE_WIDTH_C-1 downto 0) := (others => '0');
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

   -- calcFragNumByPMTU: PktFragNum (8b) = 1 << (getPmtuLogValue(pmtu) - log2(32))
   function calcFragNumByPMTU (pmtu : slv(2 downto 0)) return slv is
      variable res : slv(7 downto 0);
   begin
      case pmtu is
         when "001"  => res := std_logic_vector(to_unsigned(8,   8));  -- IBV_MTU_256
         when "010"  => res := std_logic_vector(to_unsigned(16,  8));  -- IBV_MTU_512
         when "011"  => res := std_logic_vector(to_unsigned(32,  8));  -- IBV_MTU_1024
         when "100"  => res := std_logic_vector(to_unsigned(64,  8));  -- IBV_MTU_2048
         when "101"  => res := std_logic_vector(to_unsigned(128, 8));  -- IBV_MTU_4096
         when others => res := (others => '0');
      end case;
      return res;
   end function calcFragNumByPMTU;

   -----------------------------------------------------------------------------
   -- Register record (live mode flag + dead-but-faithful regs)
   -----------------------------------------------------------------------------
   type RegType is record
      isNormalStateReg  : sl;                              -- NORMAL_S('1')/ERR_S('0'); reset '1'
      -- dead: assigned only by BSV resetAndClear; never read/written live
      shouldSetFirstReg : sl;                              -- mkReg(False)
      isFragCntZeroReg  : sl;                              -- mkReg(False)
      pmtuFragCntReg    : slv(7 downto 0);                 -- mkRegU (no reset; value irrelevant)
   end record RegType;

   constant REG_INIT_C : RegType := (
      isNormalStateReg  => '1',
      shouldSetFirstReg => '0',
      isFragCntZeroReg  => '0',
      pmtuFragCntReg    => (others => '0'));               -- mkRegU; '0' chosen, dead

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Shared FIFO clear: rst OR software clear (BSV *.clear under resetAndClear)
   signal fifoRst : sl;

   -- U_PayloadGenReqQ (PayloadGenReq, 199b)
   signal payloadGenReqQNotFull : sl;
   signal payloadGenReqQValid   : sl;                      -- = notEmpty (FWFT)
   signal payloadGenReqQDout    : slv(PAYLOAD_GEN_REQ_W_C-1 downto 0);
   signal payloadGenReqQRdEn    : sl;

   -- U_PayloadGenRespQ (PayloadGenResp, 2b)
   signal payloadGenRespQNotFull : sl;
   signal payloadGenRespQValid   : sl;
   signal payloadGenRespQDout    : slv(PAYLOAD_GEN_RESP_W_C-1 downto 0);
   signal payloadGenRespQWrEn    : sl;
   signal payloadGenRespQDin     : slv(PAYLOAD_GEN_RESP_W_C-1 downto 0);

   -- U_PendingGenReqQ (Tuple3, 239b)
   signal pendingGenReqQNotFull : sl;
   signal pendingGenReqQValid   : sl;
   signal pendingGenReqQDout    : slv(PENDING_REQ_W_C-1 downto 0);
   signal pendingGenReqQWrEn    : sl;
   signal pendingGenReqQRdEn    : sl;
   signal pendingGenReqQDin     : slv(PENDING_REQ_W_C-1 downto 0);

   -- U_PayloadBufQ (DataStream, 290b) — read side owned by U_BramQ2PipeOut
   signal payloadBufQNotFull : sl;
   signal payloadBufQValid   : sl;                         -- = notEmpty (FWFT)
   signal payloadBufQDout    : slv(DATA_STREAM_W_C-1 downto 0);
   signal payloadBufQWrEn    : sl;
   signal payloadBufQRdEn    : sl;                         -- driven by child bramQDeq
   signal payloadBufQDin     : slv(DATA_STREAM_W_C-1 downto 0);

begin

   -----------------------------------------------------------------------------
   -- Static wiring
   -----------------------------------------------------------------------------
   -- FIFO clear (OQ-FSM-01, RESOLVED): level-sensitive flush via rst.
   fifoRst <= rst or isReset;

   -- srvPort handshake passthroughs (BSV toGPServer implicit conditions)
   reqInReady   <= payloadGenReqQNotFull;                  -- request.put ready
   respOutValid <= payloadGenRespQValid;                   -- response.get valid
   respOutData  <= payloadGenRespQDout;                    -- response.get data

   -----------------------------------------------------------------------------
   -- Combinatorial FSM (two conflict-free pipeline rules + sync soft-clear)
   -----------------------------------------------------------------------------
   comb : process (r, rst, isReset, isNonErr, isERR,
                   payloadGenReqQValid, payloadGenReqQDout, pendingGenReqQNotFull,
                   dmaReadCntrlReqReady, dmaReadCntrlRespValid, dmaReadCntrlRespData,
                   pendingGenReqQValid, pendingGenReqQDout,
                   payloadBufQNotFull, payloadGenRespQNotFull) is
      variable v : RegType;
      -- recvPayloadGenReq temporaries
      variable reqDmaMeta        : slv(194 downto 0);
      variable reqPmtu           : slv(2 downto 0);
      variable totalDmaLen       : slv(31 downto 0);
      variable padCnt            : slv(1 downto 0);
      variable lastFragVByteNum  : slv(5 downto 0);
      variable lastFragVByteNumWP: slv(5 downto 0);
      variable lastFragByteEnWP  : slv(31 downto 0);
      variable pktFragNum        : slv(7 downto 0);
      variable recvFire          : sl;
      -- lastFragAddPadding temporaries
      variable pendAddPadding    : sl;
      variable pendByteEnWP      : slv(31 downto 0);
      variable hasDmaRespErr     : sl;
      variable isOrigLast        : sl;
      variable curIsLast         : sl;
      variable curByteEn         : slv(31 downto 0);
      variable curDataOut        : slv(DATA_STREAM_W_C-1 downto 0);
      variable respEnq           : sl;
      variable lastFire          : sl;
   begin
      v := r;

      -- Default combinational (Mealy) drives
      payloadGenReqQRdEn    <= '0';
      pendingGenReqQWrEn    <= '0';
      pendingGenReqQDin     <= (others => '0');
      dmaReadCntrlReqValid  <= '0';
      dmaReadCntrlReqData   <= (others => '0');
      dmaReadCntrlRespReady <= '0';
      pendingGenReqQRdEn    <= '0';
      payloadGenRespQWrEn   <= '0';
      payloadGenRespQDin    <= (others => '0');
      payloadBufQWrEn       <= '0';
      payloadBufQDin        <= (others => '0');

      -------------------------------------------------------------------------
      -- R1: recvPayloadGenReq  (NORMAL issue) — no mode-flag write
      -------------------------------------------------------------------------
      reqDmaMeta  := payloadGenReqQDout(198 downto 4);     -- dmaReadMetaData
      reqPmtu     := payloadGenReqQDout(2 downto 0);       -- pmtu
      totalDmaLen := payloadGenReqQDout(42 downto 11);     -- dmaReadMetaData.len

      padCnt             := calcPadCnt(totalDmaLen);
      lastFragVByteNum   := calcLastFragValidByteNum(totalDmaLen);
      lastFragVByteNumWP := slv(unsigned(lastFragVByteNum) + resize(unsigned(padCnt), 6));
      lastFragByteEnWP   := genByteEn(lastFragVByteNumWP);
      pktFragNum         := calcFragNumByPMTU(reqPmtu);

      recvFire := isNonErr and r.isNormalStateReg and payloadGenReqQValid
                  and pendingGenReqQNotFull and dmaReadCntrlReqReady;

      if (recvFire = '1') then
         payloadGenReqQRdEn <= '1';                        -- deq req
         -- enq Tuple3(PayloadGenReq, lastFragByteEnWithPadding, pktFragNum)
         pendingGenReqQWrEn <= '1';
         pendingGenReqQDin  <= payloadGenReqQDout & lastFragByteEnWP & pktFragNum;
         -- PUT DmaReadCntrlReq{dmaReadMetaData, pmtu}
         dmaReadCntrlReqValid <= '1';
         dmaReadCntrlReqData  <= reqDmaMeta & reqPmtu;
      end if;

      -------------------------------------------------------------------------
      -- R2: lastFragAddPadding (drain DMA resp, pad last frag, set mode flag)
      -------------------------------------------------------------------------
      -- pendingGenReqQ.first = Tuple3; PayloadGenReq=[238:40], addPadding bit=[43]
      pendAddPadding := pendingGenReqQDout(43);
      pendByteEnWP   := pendingGenReqQDout(39 downto 8);   -- lastFragByteEnWithPadding

      -- DmaReadCntrlResp fields
      hasDmaRespErr := dmaReadCntrlRespData(292);          -- dmaReadResp.isRespErr
      isOrigLast    := dmaReadCntrlRespData(0);            -- isOrigLast
      curIsLast     := dmaReadCntrlRespData(2);            -- dataStream.isLast

      -- byteEn override on the original last fragment when padding requested
      if (isOrigLast = '1') and (pendAddPadding = '1') then
         curByteEn := pendByteEnWP;
      else
         curByteEn := dmaReadCntrlRespData(35 downto 4);   -- dataStream.byteEn
      end if;
      -- recompose curData: data | byteEn | isFirst | isLast
      curDataOut := dmaReadCntrlRespData(291 downto 36)    -- data(256)
                    & curByteEn                            -- byteEn(32)
                    & dmaReadCntrlRespData(3 downto 2);    -- isFirst | isLast

      respEnq := curIsLast or hasDmaRespErr;

      -- payloadGenRespQ.notFull is an implicit condition ONLY when the enq is taken
      lastFire := (isNonErr or isERR) and dmaReadCntrlRespValid and pendingGenReqQValid
                  and payloadBufQNotFull and (payloadGenRespQNotFull or (not respEnq));

      if (lastFire = '1') then
         dmaReadCntrlRespReady <= '1';                     -- GET response
         if (isOrigLast = '1') then
            pendingGenReqQRdEn <= '1';                     -- retire pending entry
         end if;
         v.isNormalStateReg := not hasDmaRespErr;          -- registered mode flag
         if (respEnq = '1') then
            payloadGenRespQWrEn <= '1';
            -- PayloadGenResp{addPadding, isRespErr}
            payloadGenRespQDin  <= pendAddPadding & hasDmaRespErr;
         end if;
         payloadBufQWrEn <= '1';
         payloadBufQDin  <= curDataOut;
      end if;

      -------------------------------------------------------------------------
      -- resetAndClear (top priority): isReset is mutually exclusive with
      -- isNonErr/isERR, so the worker drives above are already suppressed; the
      -- register state is forced to its BSV reset.
      -------------------------------------------------------------------------
      if (rst = '1') or (isReset = '1') then
         v := REG_INIT_C;
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
   -- U_PayloadGenReqQ : surf.Fifo  (BSV payloadGenReqQ <- mkFIFOF)
   --   Write side = external srvPort.request; read side = recvPayloadGenReq.
   -----------------------------------------------------------------------------
   U_PayloadGenReqQ : entity surf.Fifo
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
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => reqInValid,
         din           => reqInData,
         full          => open,
         not_full      => payloadGenReqQNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => payloadGenReqQRdEn,
         dout          => payloadGenReqQDout,
         valid         => payloadGenReqQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   -----------------------------------------------------------------------------
   -- U_PayloadGenRespQ : surf.Fifo  (BSV payloadGenRespQ <- mkFIFOF)
   --   Write side = lastFragAddPadding; read side = external srvPort.response.
   --   2-bit element -> distributed RAM (no BRAM read-latency penalty).
   -----------------------------------------------------------------------------
   U_PayloadGenRespQ : entity surf.Fifo
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
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => payloadGenRespQWrEn,
         din           => payloadGenRespQDin,
         full          => open,
         not_full      => payloadGenRespQNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => respOutReady,
         dout          => payloadGenRespQDout,
         valid         => payloadGenRespQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   -----------------------------------------------------------------------------
   -- U_PendingGenReqQ : surf.Fifo  (BSV pendingGenReqQ <- mkFIFOF — pipeline)
   --   Write side = recvPayloadGenReq; read side = lastFragAddPadding.
   -----------------------------------------------------------------------------
   U_PendingGenReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => PENDING_REQ_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => pendingGenReqQWrEn,
         din           => pendingGenReqQDin,
         full          => open,
         not_full      => pendingGenReqQNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => pendingGenReqQRdEn,
         dout          => pendingGenReqQDout,
         valid         => pendingGenReqQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   -----------------------------------------------------------------------------
   -- U_PayloadBufQ : surf.Fifo  (BSV payloadBufQ <- mkSizedBRAMFIFOF)
   --   Write side = lastFragAddPadding; read side wired to the child
   --   U_BramQ2PipeOut (it owns the dequeue / pipeOut re-export).
   --   ADDR_WIDTH_G=8 -> depth 256 = DATA_STREAM_FRAG_BUF_SIZE.
   -----------------------------------------------------------------------------
   U_PayloadBufQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "block",
         DATA_WIDTH_G    => DATA_STREAM_W_C,
         ADDR_WIDTH_G    => BUF_ADDR_WIDTH_C)
      port map (
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => payloadBufQWrEn,
         din           => payloadBufQDin,
         full          => open,
         not_full      => payloadBufQNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => payloadBufQRdEn,
         dout          => payloadBufQDout,
         valid         => payloadBufQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   -----------------------------------------------------------------------------
   -- U_BramQ2PipeOut : ConnectBramQ2PipeOutConAndGen
   --   Pulls fragments out of U_PayloadBufQ (bramQ side) into its internal skid
   --   FIFO and re-exposes them as the entity's DataStream pipeOut + notEmpty.
   --   clear() driven by isReset (BSV bramQ2PipeOut.clear in resetAndClear).
   -----------------------------------------------------------------------------
   U_BramQ2PipeOut : entity surf.ConnectBramQ2PipeOutConAndGen
      generic map (
         TPD_G    => TPD_G,
         DATA_W_G => DATA_STREAM_W_C)
      port map (
         clk             => clk,
         rst             => rst,
         clearEnI        => isReset,
         -- upstream bramQ : Get#(DataStream) handshake on U_PayloadBufQ read side
         bramQNotEmpty   => payloadBufQValid,
         bramQDout       => payloadBufQDout,
         bramQDeq        => payloadBufQRdEn,
         -- downstream pipeOut : PipeOut#(DataStream)
         pipeOutDeq      => payloadDataStreamDeq,
         pipeOutFirst    => payloadDataStreamFirst,
         pipeOutNotEmpty => payloadDataStreamNotEmpty,
         -- notEmpty() method result
         notEmpty        => payloadNotEmpty);

end architecture rtl;
