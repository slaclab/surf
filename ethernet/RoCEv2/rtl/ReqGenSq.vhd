-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Nine-stage dataflow request pipeline, wrapped by a 2-state mode bit
--   (isNormalStateReg: NORMAL / ERR_FLUSH) and a per-WR packet loop
--   (isFirstOrOnlyReqPktReg + remainingPktNumReg + curPsnReg).  All 11 worker
--   rules are BSV (* conflict_free *): each fires independently when its input
--   FIFO is non-empty, its output FIFO has room, and (where used) the external
--   payloadGenerator / contextSQ handshakes hold.  Handoff between stages is
--   FIFO-carried.  Emitted as 11 parallel comb blocks (R1..R11) computing each
--   stage's FIFO drives, plus a Moore-registered mode bit / packet-loop.
--
--   13 pipeline FIFOs (all surf.Fifo, FWFT, sync) + 2 internal children:
--     U_HeaderGenReqSQ  : work.HeaderGenReqSQ       (combinational request-header
--                          packer, split out of mkReqGenSQ — see
--                          ADDENDUM-HeaderGenReqSQ.md; emit+verify before this)
--     U_RdmaReqPipeOut  : work.CombineHeaderAndPayload (mkCombineHeaderAndPayload)
--
--   Module parameters become ports (OQ-FSM-RGS-01, same pattern as SendQ):
--     contextSQ        -> status bundle (isReset/isStableRTS/isRTS/isERR/isSQD,
--                         qpType/sqpn/pmtu/pkey/dqpn/sigAll) + getNPSN in /
--                         setNPSN out (npsnIn / npsnOut+npsnWrEn : external
--                         shared next-PSN register, read-modify-write in R4).
--     payloadGenerator -> external Server (req PayloadGenReq out / resp
--                         PayloadGenResp in) + payloadDataStreamPipeOut in
--                         (the last consumed only by the child, not by a rule).
--     pendingWorkReqPipeIn / pendingWorkReqBufNotEmpty -> input ports.
--
--   resetAndClear (BSV, guard cntrlStatus.comm.isReset, fire_when_enabled): the
--     QP-status isReset is the synchronous clear (NOT the FPGA async reset).
--     While isReset='1' all 13 FIFOs are held cleared (fifoRst = rst OR isReset,
--     level clear — OQ-FSM-01/06 resolution: surf.FifoSync rst is level-safe),
--     isNormalStateReg forced '1', isFirstOrOnlyReqPktReg forced '1'.
--     (OQ-FSM-RGS-02.)
--
--   SURF components instantiated (source: surf/base/fifo/rtl/Fifo.vhd):
--     U_PendingWorkReqOutQ, U_WorkCompGenReqOutQ, U_WorkReqPayloadGenQ,
--     U_WorkReqPktNumQ, U_WorkReqPsnQ, U_WorkReqOutQ, U_WorkReqCheckQ,
--     U_ReqCountQ, U_ReqHeaderPrepareQ, U_PendingReqHeaderQ, U_ReqHeaderGenQ,
--     U_ReqHeaderOutQ, U_PsnReqOutQ.
--
--   Refactor vs BSV Maybe-carrying FIFOs (mirrors SendQ): the Maybe# tuple
--   fields are carried as an explicit tag bit + payload slv in the FIFO word;
--   R9/R10 mux on the tag bit.  genHeaderRDMA (byteEn + metaData) stays inline
--   in R9 (Utils.bsv:319); genFirstOrOnly/genMiddleOrLastReqHeader are in the
--   U_HeaderGenReqSQ child.
--
--   Composite word layouts (first-field-at-MSB, from BSV deriving(Bits);
--   widths traced in memory resphandlesq-emit-facts + DataTypes.bsv):
--     WorkReq (601): id[600:537] opcode[536:533] flags[532:528] raddr[527:464]
--       rkey[463:432] len[431:400] laddr[399:336] lkey[335:304] sqpn[303:280]
--       solicited[279] comp{tag[278],val[277:214]} swap{tag[213],val[212:149]}
--       immDt{tag[148],val[147:116]} rkey2Inv{tag[115],val[114:83]}
--       srqn{tag[82],val[81:58]} dqpn{tag[57],val[56:33]} qkey{tag[32],val[31:0]}
--       (flags bit i = 2**i : FENCE=flags(0), SIGNALED=flags(1), SOLICITED=flags(2))
--     PendingWorkReq (679): wr[678:78] startPSN{tag[77],val[76:53]}
--       endPSN{tag[52],val[51:28]} pktNum{tag[27],val[26:2]}
--       isOnlyReqPkt{tag[1],val[0]}   (wr fields above are all +78)
--     WorkReqInfo (5): isNewWorkReq[4] isZeroPmtuResidue[3] isReliableConnection[2]
--       isUnreliableDatagram[1] needDmaRead[0]
--     ReqPktHeaderInfo (705): curPSN[704:681] pendingWR[680:2] isFirstReqPkt[1]
--       isLastReqPkt[0]
--     HeaderRDMA (593): headerData[592:81] headerByteEn[80:17]
--       headerMetaData[16:0] = headerLen[16:10] headerFragNum[9:8]
--       lastFragValidByteNum[7:2] hasPayload[1] isEmptyHeader[0]
--     PayloadGenReq (199): dmaReadMetaData[198:4]{initiator[198:195] sqpn[194:171]
--       wrID[170:107] startAddr[106:43] len[42:11] mrIdx[10:4]} addPadding[3] pmtu[2:0]
--     PayloadGenResp (2): addPadding[1] isRespErr[0]
--     WorkCompGenReqSQ (633): wr[632:32] wcWaitDmaResp[31] wcReqType[30:29]
--       triggerPSN[28:5] wcStatus[4:0]
--
--   Open questions (see out/04-vhdl/OPEN_QUESTIONS.md): OQ-EMIT-RGS-SPLIT,
--   OQ-EMIT-RGS-NPSN, OQ-EMIT-RGS-PGRESP.
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

entity ReqGenSq is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk : in sl;
      rst : in sl;                      -- active-high synchronous reset (FPGA)

      -----------------------------------------------------------------------
      -- contextSQ.statusSQ bundle (cntrlStatus)
      -----------------------------------------------------------------------
      isReset     : in  sl;                -- comm.isReset (soft clear)
      isStableRTS : in  sl;                -- comm.isStableRTS
      isRTS       : in  sl;                -- comm.isRTS
      isERR       : in  sl;                -- comm.isERR
      isSQD       : in  sl;                -- comm.isSQD
      qpType      : in  slv(3 downto 0);   -- getTypeQP
      sqpn        : in  slv(23 downto 0);  -- comm.getSQPN
      pmtu        : in  slv(2 downto 0);   -- comm.getPMTU
      pkey        : in  slv(15 downto 0);  -- comm.getPKEY
      dqpn        : in  slv(23 downto 0);  -- comm.getDQPN
      sigAll      : in  sl;                -- comm.getSigAll
      -- contextSQ next-PSN shared register (read+write same cycle in R4)
      npsnIn      : in  slv(23 downto 0);  -- contextSQ.getNPSN
      npsnOut     : out slv(23 downto 0);  -- contextSQ.setNPSN value
      npsnWrEn    : out sl;                -- contextSQ.setNPSN write-enable

      -----------------------------------------------------------------------
      -- pendingWorkReqPipeIn : PipeOut#(PendingWorkReq) (input)
      -----------------------------------------------------------------------
      pendingWorkReqInValid     : in  sl;  -- .notEmpty
      pendingWorkReqInData      : in  slv(678 downto 0);  -- .first (PendingWorkReq)
      pendingWorkReqInRdEn      : out sl;  -- .deq
      pendingWorkReqBufNotEmpty : in  sl;  -- fence fence-drain fence flag

      -----------------------------------------------------------------------
      -- payloadGenerator external Server + PipeOut
      -----------------------------------------------------------------------
      -- srvPort.request : PayloadGenReq (out / put)
      payloadGenReqValid     : out sl;
      payloadGenReqData      : out slv(198 downto 0);
      payloadGenReqReady     : in  sl;
      -- srvPort.response : PayloadGenResp (in / get)
      payloadGenRespValid    : in  sl;
      payloadGenRespData     : in  slv(1 downto 0);
      payloadGenRespReady    : out sl;
      -- payloadDataStreamPipeOut : DataStream (in) — consumed by the child only
      payloadDataStreamValid : in  sl;
      payloadDataStreamData  : in  slv(289 downto 0);
      payloadDataStreamRdEn  : out sl;

      -----------------------------------------------------------------------
      -- Outputs
      -----------------------------------------------------------------------
      -- pendingWorkReqPipeOut : PipeOut#(PendingWorkReq)
      pendingWorkReqOutValid : out sl;
      pendingWorkReqOutData  : out slv(678 downto 0);
      pendingWorkReqOutRdEn  : in  sl;
      -- workCompGenReqPipeOut : PipeOut#(WorkCompGenReqSQ)
      workCompGenReqValid    : out sl;
      workCompGenReqData     : out slv(632 downto 0);
      workCompGenReqRdEn     : in  sl;
      -- rdmaReqDataStreamPipeOut : DataStreamPipeOut (from child)
      rdmaReqDataValid       : out sl;
      rdmaReqDataData        : out slv(289 downto 0);
      rdmaReqDataRdEn        : in  sl;
      -- method Bool reqHeaderOutNotEmpty() (combinational)
      reqHeaderOutNotEmpty   : out sl);
end entity ReqGenSq;

architecture rtl of ReqGenSq is

   -- TypeQP encodings (4 bits)
   constant QPT_RC_C             : slv(3 downto 0) := x"2";
   constant QPT_UD_C             : slv(3 downto 0) := x"4";
   constant QPT_XRC_SEND_C       : slv(3 downto 0) := x"9";
   -- PMTU encodings (3 bits)
   constant PMTU_256_C           : slv(2 downto 0) := "001";
   constant PMTU_512_C           : slv(2 downto 0) := "010";
   constant PMTU_1024_C          : slv(2 downto 0) := "011";
   constant PMTU_2048_C          : slv(2 downto 0) := "100";
   constant PMTU_4096_C          : slv(2 downto 0) := "101";
   -- WorkReqOpCode encodings (4 bits) — DMA-read opcodes + read
   constant WR_RDMA_WRITE_C      : slv(3 downto 0) := x"0";
   constant WR_WRITE_IMM_C       : slv(3 downto 0) := x"1";
   constant WR_SEND_C            : slv(3 downto 0) := x"2";
   constant WR_SEND_IMM_C        : slv(3 downto 0) := x"3";
   constant WR_RDMA_READ_C       : slv(3 downto 0) := x"4";
   constant WR_SEND_INV_C        : slv(3 downto 0) := x"9";
   -- DmaReqSrcType.DMA_SRC_SQ_RD (4 bits)
   constant DMA_SRC_SQ_RD_C      : slv(3 downto 0) := x"5";
   -- WorkCompReqType.WC_REQ_TYPE_PARTIAL_ACK (2 bits) / WorkCompStatus.IBV_WC_LOC_QP_OP_ERR (5 bits)
   constant WC_REQ_PARTIAL_ACK_C : slv(1 downto 0) := "01";
   constant WC_LOC_QP_OP_ERR_C   : slv(4 downto 0) := "00010";

   -- Element / FIFO widths
   constant PWR_W_C        : integer := 679;  -- PendingWorkReq
   constant WCREQ_W_C      : integer := 633;  -- WorkCompGenReqSQ
   constant WRPG_W_C       : integer := 720;  -- Tuple7(PWR,PktNum,ResiduePMTU,4xBool)
   constant WRPKTNUM_W_C   : integer := 709;  -- Tuple3(PWR,PktNum,WorkReqInfo)
   constant TUP2_W_C       : integer := 684;  -- Tuple2(PWR,WorkReqInfo)
   constant REQHDRPREP_W_C : integer := 710;  -- Tuple2(ReqPktHeaderInfo,WorkReqInfo)
   constant PENDREQHDR_W_C : integer := 1229;  -- Tuple4(PWR,WRInfo,Maybe(Tup3),PSN)
   constant REQHDRGEN_W_C  : integer := 1300;  -- Tuple4(PWR,Maybe(HRDMA),Maybe(PGResp),PSN)
   constant HRDMA_W_C      : integer := 593;  -- HeaderRDMA
   constant PSN_W_C        : integer := 24;   -- PSN

   type RegType is record
      isNormalStateReg       : sl;      -- mkReg(True)
      isFirstOrOnlyReqPktReg : sl;      -- mkReg(True)
      remainingPktNumReg     : slv(24 downto 0);  -- mkRegU (loaded before use)
      curPsnReg              : slv(23 downto 0);  -- mkRegU (loaded from startPSN)
   end record RegType;

   -- remainingPktNumReg / curPsnReg are mkRegU (written before read); given '0'
   -- for a defined start (REG_INIT don't-care per FSM spec).
   constant REG_INIT_C : RegType := (
      isNormalStateReg       => '1',
      isFirstOrOnlyReqPktReg => '1',
      remainingPktNumReg     => (others => '0'),
      curPsnReg              => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal fifoRst : sl;

   -- FIFO interconnect
   signal pwrOutDin     : slv(PWR_W_C-1 downto 0);
   signal pwrOutWrEn    : sl;
   signal pwrOutNotFull : sl;

   signal wcOutDin     : slv(WCREQ_W_C-1 downto 0);
   signal wcOutWrEn    : sl;
   signal wcOutNotFull : sl;

   signal wrPgDin     : slv(WRPG_W_C-1 downto 0);
   signal wrPgWrEn    : sl;
   signal wrPgDout    : slv(WRPG_W_C-1 downto 0);
   signal wrPgValid   : sl;
   signal wrPgNotFull : sl;
   signal wrPgRdEn    : sl;

   signal wrPktNumDin     : slv(WRPKTNUM_W_C-1 downto 0);
   signal wrPktNumWrEn    : sl;
   signal wrPktNumDout    : slv(WRPKTNUM_W_C-1 downto 0);
   signal wrPktNumValid   : sl;
   signal wrPktNumNotFull : sl;
   signal wrPktNumRdEn    : sl;

   signal wrPsnDin     : slv(TUP2_W_C-1 downto 0);
   signal wrPsnWrEn    : sl;
   signal wrPsnDout    : slv(TUP2_W_C-1 downto 0);
   signal wrPsnValid   : sl;
   signal wrPsnNotFull : sl;
   signal wrPsnRdEn    : sl;

   signal wrOutDin     : slv(TUP2_W_C-1 downto 0);
   signal wrOutWrEn    : sl;
   signal wrOutDout    : slv(TUP2_W_C-1 downto 0);
   signal wrOutValid   : sl;
   signal wrOutNotFull : sl;
   signal wrOutRdEn    : sl;

   signal wrChkDin     : slv(TUP2_W_C-1 downto 0);
   signal wrChkWrEn    : sl;
   signal wrChkDout    : slv(TUP2_W_C-1 downto 0);
   signal wrChkValid   : sl;
   signal wrChkNotFull : sl;
   signal wrChkRdEn    : sl;

   signal reqCntDin     : slv(TUP2_W_C-1 downto 0);
   signal reqCntWrEn    : sl;
   signal reqCntDout    : slv(TUP2_W_C-1 downto 0);
   signal reqCntValid   : sl;
   signal reqCntNotFull : sl;
   signal reqCntRdEn    : sl;

   signal reqPrepDin     : slv(REQHDRPREP_W_C-1 downto 0);
   signal reqPrepWrEn    : sl;
   signal reqPrepDout    : slv(REQHDRPREP_W_C-1 downto 0);
   signal reqPrepValid   : sl;
   signal reqPrepNotFull : sl;
   signal reqPrepRdEn    : sl;

   signal pendHdrDin     : slv(PENDREQHDR_W_C-1 downto 0);
   signal pendHdrWrEn    : sl;
   signal pendHdrDout    : slv(PENDREQHDR_W_C-1 downto 0);
   signal pendHdrValid   : sl;
   signal pendHdrNotFull : sl;
   signal pendHdrRdEn    : sl;

   signal hdrGenDin     : slv(REQHDRGEN_W_C-1 downto 0);
   signal hdrGenWrEn    : sl;
   signal hdrGenDout    : slv(REQHDRGEN_W_C-1 downto 0);
   signal hdrGenValid   : sl;
   signal hdrGenNotFull : sl;
   signal hdrGenRdEn    : sl;

   signal reqHdrOutDin     : slv(HRDMA_W_C-1 downto 0);
   signal reqHdrOutWrEn    : sl;
   signal reqHdrOutDout    : slv(HRDMA_W_C-1 downto 0);
   signal reqHdrOutValid   : sl;
   signal reqHdrOutNotFull : sl;
   signal reqHdrOutRdEn    : sl;

   signal psnOutDin     : slv(PSN_W_C-1 downto 0);
   signal psnOutWrEn    : sl;
   signal psnOutDout    : slv(PSN_W_C-1 downto 0);
   signal psnOutValid   : sl;
   signal psnOutNotFull : sl;
   signal psnOutRdEn    : sl;

   -- U_HeaderGenReqSQ interconnect (driven from reqHeaderPrepareQ.dout)
   signal hpPwr           : slv(678 downto 0);  -- ReqPktHeaderInfo.pendingWR
   signal hgIsFirstOrOnly : sl;
   signal hgIsOnlyOrLast  : sl;
   signal hgHeaderValid   : sl;
   signal hgHeaderData    : slv(511 downto 0);
   signal hgHeaderByteNum : slv(6 downto 0);
   signal hgHasPayload    : sl;

begin

   fifoRst <= rst or isReset;

   ---------------------------------------------------------------------------
   -- 13 pipeline FIFOs (all surf.Fifo, FWFT, synchronous)
   ---------------------------------------------------------------------------
   U_PendingWorkReqOutQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => PWR_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => pwrOutWrEn,
         din      => pwrOutDin,
         not_full => pwrOutNotFull,
         rd_clk   => clk,
         rd_en    => pendingWorkReqOutRdEn,
         dout     => pendingWorkReqOutData,
         valid    => pendingWorkReqOutValid,
         empty    => open);

   U_WorkCompGenReqOutQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => WCREQ_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => wcOutWrEn,
         din      => wcOutDin,
         not_full => wcOutNotFull,
         rd_clk   => clk,
         rd_en    => workCompGenReqRdEn,
         dout     => workCompGenReqData,
         valid    => workCompGenReqValid,
         empty    => open);

   U_WorkReqPayloadGenQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => WRPG_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => wrPgWrEn,
         din      => wrPgDin,
         not_full => wrPgNotFull,
         rd_clk   => clk,
         rd_en    => wrPgRdEn,
         dout     => wrPgDout,
         valid    => wrPgValid,
         empty    => open);

   U_WorkReqPktNumQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => WRPKTNUM_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => wrPktNumWrEn,
         din      => wrPktNumDin,
         not_full => wrPktNumNotFull,
         rd_clk   => clk,
         rd_en    => wrPktNumRdEn,
         dout     => wrPktNumDout,
         valid    => wrPktNumValid,
         empty    => open);

   U_WorkReqPsnQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => TUP2_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => wrPsnWrEn,
         din      => wrPsnDin,
         not_full => wrPsnNotFull,
         rd_clk   => clk,
         rd_en    => wrPsnRdEn,
         dout     => wrPsnDout,
         valid    => wrPsnValid,
         empty    => open);

   U_WorkReqOutQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => TUP2_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => wrOutWrEn,
         din      => wrOutDin,
         not_full => wrOutNotFull,
         rd_clk   => clk,
         rd_en    => wrOutRdEn,
         dout     => wrOutDout,
         valid    => wrOutValid,
         empty    => open);

   U_WorkReqCheckQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => TUP2_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => wrChkWrEn,
         din      => wrChkDin,
         not_full => wrChkNotFull,
         rd_clk   => clk,
         rd_en    => wrChkRdEn,
         dout     => wrChkDout,
         valid    => wrChkValid,
         empty    => open);

   U_ReqCountQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => TUP2_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => reqCntWrEn,
         din      => reqCntDin,
         not_full => reqCntNotFull,
         rd_clk   => clk,
         rd_en    => reqCntRdEn,
         dout     => reqCntDout,
         valid    => reqCntValid,
         empty    => open);

   U_ReqHeaderPrepareQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => REQHDRPREP_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => reqPrepWrEn,
         din      => reqPrepDin,
         not_full => reqPrepNotFull,
         rd_clk   => clk,
         rd_en    => reqPrepRdEn,
         dout     => reqPrepDout,
         valid    => reqPrepValid,
         empty    => open);

   U_PendingReqHeaderQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => PENDREQHDR_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => pendHdrWrEn,
         din      => pendHdrDin,
         not_full => pendHdrNotFull,
         rd_clk   => clk,
         rd_en    => pendHdrRdEn,
         dout     => pendHdrDout,
         valid    => pendHdrValid,
         empty    => open);

   U_ReqHeaderGenQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => REQHDRGEN_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => hdrGenWrEn,
         din      => hdrGenDin,
         not_full => hdrGenNotFull,
         rd_clk   => clk,
         rd_en    => hdrGenRdEn,
         dout     => hdrGenDout,
         valid    => hdrGenValid,
         empty    => open);

   U_ReqHeaderOutQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => HRDMA_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => reqHdrOutWrEn,
         din      => reqHdrOutDin,
         not_full => reqHdrOutNotFull,
         rd_clk   => clk,
         rd_en    => reqHdrOutRdEn,
         dout     => reqHdrOutDout,
         valid    => reqHdrOutValid,
         empty    => open);

   U_PsnReqOutQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => PSN_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => psnOutWrEn,
         din      => psnOutDin,
         not_full => psnOutNotFull,
         rd_clk   => clk,
         rd_en    => psnOutRdEn,
         dout     => psnOutDout,
         valid    => psnOutValid,
         empty    => open);

   ---------------------------------------------------------------------------
   -- Internal children
   ---------------------------------------------------------------------------
   -- HeaderGenReqSQ is combinational; its inputs are the reqHeaderPrepareQ head
   -- (ReqPktHeaderInfo + cntrlStatus bundle).  Driven concurrently below.
   hpPwr           <= reqPrepDout(685 downto 7);  -- ReqPktHeaderInfo.pendingWR
   hgIsFirstOrOnly <= reqPrepDout(6);             -- isFirstReqPkt
   -- isOnlyOrLast = isFirstReqPkt ? isOnlyReqPkt(pendingWR val) : isLastReqPkt
   hgIsOnlyOrLast  <= reqPrepDout(7) when reqPrepDout(6) = '1' else reqPrepDout(5);

   U_HeaderGenReqSQ : entity surf.HeaderGenReqSQ
      generic map (
         TPD_G => TPD_G)
      port map (
         isFirstOrOnly => hgIsFirstOrOnly,
         isOnlyOrLast  => hgIsOnlyOrLast,
         psn           => reqPrepDout(709 downto 686),  -- ReqPktHeaderInfo.curPSN
         qpType        => qpType,
         pkey          => pkey,
         sigAll        => sigAll,
         commDqpn      => dqpn,
         sqpn          => sqpn,
         opcode        => hpPwr(614 downto 611),
         solicited     => hpPwr(357),
         sendSignaled  => hpPwr(607),   -- flags(1)=IBV_SEND_SIGNALED
         len           => hpPwr(509 downto 478),
         raddr         => hpPwr(605 downto 542),
         rkey          => hpPwr(541 downto 510),
         wrDqpn        => hpPwr(134 downto 111),  -- Maybe#(QPN) value (tag dropped)
         srqn          => hpPwr(159 downto 136),  -- Maybe#(QPN) value
         qkey          => hpPwr(109 downto 78),   -- Maybe#(QKEY) value
         swapData      => hpPwr(290 downto 227),  -- Maybe#(Long) value
         compData      => hpPwr(355 downto 292),  -- Maybe#(Long) value
         immDtData     => hpPwr(225 downto 194),  -- Maybe#(IMM) value
         invRkey       => hpPwr(192 downto 161),  -- Maybe#(RKEY) value
         headerValid   => hgHeaderValid,
         headerData    => hgHeaderData,
         headerByteNum => hgHeaderByteNum,
         hasPayload    => hgHasPayload);

   U_RdmaReqPipeOut : entity surf.CombineHeaderAndPayload
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         RST_ASYNC_G    => false)
      port map (
         clk                => clk,
         rst                => rst,
         clearAllI          => isReset,
         -- headerPipeIn <- reqHeaderOutQ
         headerPipeInValid  => reqHdrOutValid,
         headerPipeInData   => reqHdrOutDout,
         headerPipeInRdEn   => reqHdrOutRdEn,
         -- payloadPipeIn <- external payloadGenerator.payloadDataStreamPipeOut
         payloadPipeInValid => payloadDataStreamValid,
         payloadPipeInData  => payloadDataStreamData,
         payloadPipeInRdEn  => payloadDataStreamRdEn,
         -- psnPipeIn <- psnReqOutQ (value unused; handshake only)
         psnPipeInValid     => psnOutValid,
         psnPipeInData      => psnOutDout,
         psnPipeInRdEn      => psnOutRdEn,
         -- output -> rdmaReqDataStreamPipeOut
         dataStreamOutValid => rdmaReqDataValid,
         dataStreamOutData  => rdmaReqDataData,
         dataStreamOutRdEn  => rdmaReqDataRdEn);

   ---------------------------------------------------------------------------
   -- Combinational pipeline (11 conflict_free worker rules + mode/loop regs)
   ---------------------------------------------------------------------------
   comb : process (all) is
      variable v : RegType;

      variable notReset : sl;

      -- R1 recvWorkReq
      variable r1Opcode    : slv(3 downto 0);
      variable r1Len       : slv(31 downto 0);
      variable r1IsRC      : sl;
      variable r1IsUD      : sl;
      variable r1NeedDma   : sl;
      variable r1IsNew     : sl;
      variable r1Fence     : sl;
      variable r1ShouldDeq : sl;
      variable r1TmpPkt    : slv(24 downto 0);
      variable r1Residue   : slv(11 downto 0);
      variable r1Guard     : sl;
      variable r1Fire      : sl;
      variable r1Do        : sl;

      -- R2 issuePayloadGenReq
      variable r2Pwr     : slv(678 downto 0);
      variable r2NeedDma : sl;
      variable r2ZeroRes : sl;
      variable r2Wi      : slv(4 downto 0);
      variable r2Guard   : sl;
      variable r2Fire    : sl;

      -- R3 calcPktNum4NewWorkReq
      variable r3Pwr     : slv(678 downto 0);
      variable r3Wi      : slv(4 downto 0);
      variable r3IsNew   : sl;
      variable r3ZeroRes : sl;
      variable r3TmpPkt  : slv(24 downto 0);
      variable r3TotPkt  : slv(24 downto 0);
      variable r3IsOnly  : sl;
      variable r3Fire    : sl;

      -- R4 calcPktSeqNum4NewWorkReq
      variable r4Pwr       : slv(678 downto 0);
      variable r4Wi        : slv(4 downto 0);
      variable r4IsNew     : sl;
      variable r4TotPkt    : slv(24 downto 0);
      variable r4IsOnly    : sl;
      variable r4Opcode    : slv(3 downto 0);
      variable r4StartPsn  : slv(23 downto 0);
      variable r4NextPsn25 : slv(24 downto 0);
      variable r4NextPsn   : slv(23 downto 0);
      variable r4EndPsn    : slv(23 downto 0);
      variable r4HasOnly   : sl;
      variable r4Fire      : sl;

      -- R5 checkPendingWorkReq
      variable r5Pwr    : slv(678 downto 0);
      variable r5Wi     : slv(4 downto 0);
      variable r5IsOnly : sl;
      variable r5IsUD   : sl;
      variable r5Valid  : sl;
      variable r5Fire   : sl;

      -- R6 outputNewPendingWorkReq
      variable r6Pwr   : slv(678 downto 0);
      variable r6Wi    : slv(4 downto 0);
      variable r6Enq   : sl;
      variable r6Fire  : sl;
      variable r6DoEnq : sl;

      -- R7 countReqPkt (packet loop)
      variable r7Pwr        : slv(678 downto 0);
      variable r7Wi         : slv(4 downto 0);
      variable r7StartPsn   : slv(23 downto 0);
      variable r7TotPkt     : slv(24 downto 0);
      variable r7IsOnly     : sl;
      variable r7LastOrOnly : sl;
      variable r7FirstPkt   : sl;
      variable r7LastPkt    : sl;
      variable r7CurPsn     : slv(23 downto 0);
      variable r7RemPkt     : slv(24 downto 0);
      variable r7Rphi       : slv(704 downto 0);
      variable r7Fire       : sl;

      -- R8 prepareReqHeaderGen
      variable r8Fire : sl;

      -- R9 genReqHeader
      variable r9Valid     : sl;
      variable r9NeedDma   : sl;
      variable r9GetResp   : sl;
      variable r9Hlen      : slv(6 downto 0);
      variable r9HlenInt   : integer range 0 to 127;
      variable r9ByteEn    : slv(63 downto 0);
      variable r9Frag      : slv(1 downto 0);
      variable r9Last      : slv(5 downto 0);
      variable r9Res5      : slv(4 downto 0);
      variable r9Hdr       : slv(592 downto 0);
      variable r9MaybeHdr  : slv(593 downto 0);
      variable r9MaybeResp : slv(2 downto 0);
      variable r9Fire      : sl;

      -- R10 recvPayloadGenRespAndGenErrWorkComp
      variable r10HasHdr  : sl;
      variable r10HasResp : sl;
      variable r10RespErr : sl;
      variable r10Success : sl;
      variable r10Cond    : sl;
      variable r10Fire    : sl;

      -- R11 errFlushWR
      variable r11Pwr   : slv(678 downto 0);
      variable r11Enq   : sl;
      variable r11Guard : sl;
      variable r11Fire  : sl;
      variable r11DoEnq : sl;
      -- R11a-d errFlushStrandedWR (BUGFIX 2026-07-16): error-drain of the
      -- stage-2..6 intermediate FIFOs (see Stage 11 comment)
      variable errFlushMode                               : sl;
      variable r11aPwr, r11bPwr, r11cPwr, r11dPwr         : slv(678 downto 0);
      variable r11aEnq, r11bEnq, r11cEnq, r11dEnq         : sl;
      variable r11aFire, r11bFire, r11cFire, r11dFire     : sl;
      variable r11aDoEnq, r11bDoEnq, r11cDoEnq, r11dDoEnq : sl;

   begin
      v        := r;
      notReset := not isReset;

      ----------------------------------------------------------------------
      -- Stage 1 : recvWorkReq   (guard isStableRTS || isERR)
      ----------------------------------------------------------------------
      r1Opcode := pendingWorkReqInData(614 downto 611);
      r1Len    := pendingWorkReqInData(509 downto 478);
      r1IsRC   := ite(qpType = QPT_RC_C or qpType = QPT_XRC_SEND_C, '1', '0');
      r1IsUD   := ite(qpType = QPT_UD_C, '1', '0');
      r1NeedDma := ite((r1Opcode = WR_RDMA_WRITE_C or r1Opcode = WR_WRITE_IMM_C or
                        r1Opcode = WR_SEND_C or r1Opcode = WR_SEND_IMM_C or
                        r1Opcode = WR_SEND_INV_C) and r1Len /= x"00000000", '1', '0');
      r1IsNew := not pendingWorkReqInData(1);  -- !isValid(isOnlyReqPkt)
      r1Fence := pendingWorkReqInData(606);    -- wr.flags(0)=IBV_SEND_FENCE

      if (isRTS = '1' and r1Fence = '1') then
         r1ShouldDeq := not pendingWorkReqBufNotEmpty;  -- fence: wait for buffer drain
      else
         r1ShouldDeq := not isSQD;      -- SQ-drain stall
      end if;

      -- truncateLenByPMTU(len, pmtu) -> (tmpReqPktNum:25, pmtuResidue:12)
      r1TmpPkt  := (others => '0');
      r1Residue := (others => '0');
      case pmtu is
         when PMTU_256_C =>
            r1TmpPkt(23 downto 0) := r1Len(31 downto 8);
            r1Residue(7 downto 0) := r1Len(7 downto 0);
         when PMTU_512_C =>
            r1TmpPkt(22 downto 0) := r1Len(31 downto 9);
            r1Residue(8 downto 0) := r1Len(8 downto 0);
         when PMTU_1024_C =>
            r1TmpPkt(21 downto 0) := r1Len(31 downto 10);
            r1Residue(9 downto 0) := r1Len(9 downto 0);
         when PMTU_2048_C =>
            r1TmpPkt(20 downto 0)  := r1Len(31 downto 11);
            r1Residue(10 downto 0) := r1Len(10 downto 0);
         when others =>                 -- PMTU_4096_C
            r1TmpPkt(19 downto 0)  := r1Len(31 downto 12);
            r1Residue(11 downto 0) := r1Len(11 downto 0);
      end case;

      r1Guard := notReset and (isStableRTS or isERR) and pendingWorkReqInValid;
      r1Fire  := r1Guard and (not r1ShouldDeq or wrPgNotFull);
      r1Do    := r1Fire and r1ShouldDeq;

      pendingWorkReqInRdEn <= r1Do;
      wrPgWrEn             <= r1Do;
      -- Tuple7(pendingWR, tmpReqPktNum, pmtuResidue, needDmaRead, isNewWorkReq,
      --        isReliableConnection, isUnreliableDatagram)
      wrPgDin              <= pendingWorkReqInData & r1TmpPkt & r1Residue &
                 r1NeedDma & r1IsNew & r1IsRC & r1IsUD;

      ----------------------------------------------------------------------
      -- Stage 2 : issuePayloadGenReq   (guard isStableRTS && isNormalStateReg)
      ----------------------------------------------------------------------
      r2Pwr     := wrPgDout(719 downto 41);
      r2NeedDma := wrPgDout(3);
      r2ZeroRes := ite(wrPgDout(15 downto 4) = "000000000000", '1', '0');
      -- WorkReqInfo = isNew & isZeroResidue & isRC & isUD & needDma
      r2Wi      := wrPgDout(2) & r2ZeroRes & wrPgDout(1) & wrPgDout(0) & wrPgDout(3);

      r2Guard := notReset and isStableRTS and r.isNormalStateReg and
                 wrPgValid and wrPktNumNotFull;
      r2Fire := r2Guard and (not r2NeedDma or payloadGenReqReady);

      payloadGenReqValid <= r2Fire and r2NeedDma;
      -- PayloadGenReq: {initiator,sqpn,wrID,startAddr,len,mrIdx}, addPadding, pmtu
      payloadGenReqData  <= DMA_SRC_SQ_RD_C & -- initiator = DMA_SRC_SQ_RD
                           sqpn & -- cntrlStatus.comm.getSQPN
                           r2Pwr(678 downto 615) & -- wr.id (WorkReqID)
                           r2Pwr(477 downto 414) & -- wr.laddr (startAddr)
                           r2Pwr(509 downto 478) & -- wr.len
                           r2Pwr(413 downto 407) & -- key2IndexMR(wr.lkey)=lkey[31:25]
                           '1' & -- addPadding = True
                           pmtu;        -- cntrlStatus.comm.getPMTU

      wrPktNumWrEn <= r2Fire;
      -- Tuple3(pendingWR, tmpReqPktNum, workReqInfo)
      wrPktNumDin  <= r2Pwr & wrPgDout(40 downto 16) & r2Wi;

      ----------------------------------------------------------------------
      -- Stage 3 : calcPktNum4NewWorkReq   (guard isStableRTS && isNormalStateReg)
      ----------------------------------------------------------------------
      r3Pwr     := wrPktNumDout(708 downto 30);
      r3TmpPkt  := wrPktNumDout(29 downto 5);
      r3Wi      := wrPktNumDout(4 downto 0);
      r3IsNew   := r3Wi(4);
      r3ZeroRes := r3Wi(3);

      if (r3ZeroRes = '1') then
         r3TotPkt := r3TmpPkt;
      else
         r3TotPkt := slv(unsigned(r3TmpPkt) + 1);
      end if;
      r3IsOnly := ite(unsigned(r3TotPkt) <= 1, '1', '0');  -- isLessOrEqOneR

      if (r3IsNew = '1') then
         r3Pwr(27)          := '1';     -- pktNum := Valid totalPktNum
         r3Pwr(26 downto 2) := r3TotPkt;
         r3Pwr(1)           := '1';     -- isOnlyReqPkt := Valid isOnlyPkt
         r3Pwr(0)           := r3IsOnly;
      end if;

      r3Fire := notReset and isStableRTS and r.isNormalStateReg and
                wrPktNumValid and wrPsnNotFull;

      -- wrPktNumRdEn driven after Stage 11 (r3Fire or errFlush R11a)
      wrPsnWrEn <= r3Fire;
      wrPsnDin  <= r3Pwr & r3Wi;        -- Tuple2(pendingWR, workReqInfo)

      ----------------------------------------------------------------------
      -- Stage 4 : calcPktSeqNum4NewWorkReq (guard isStableRTS && isNormalStateReg)
      ----------------------------------------------------------------------
      r4Pwr      := wrPsnDout(683 downto 5);
      r4Wi       := wrPsnDout(4 downto 0);
      r4IsNew    := r4Wi(4);
      r4TotPkt   := r4Pwr(26 downto 2);  -- unwrap pktNum
      r4IsOnly   := r4Pwr(0);            -- unwrap isOnlyReqPkt
      r4Opcode   := r4Pwr(614 downto 611);
      r4StartPsn := npsnIn;              -- contextSQ.getNPSN

      -- calcNextAndEndPSN(startPSN, pktNum, isOnlyPkt, pmtu)
      if (r4IsOnly = '1') then
         r4NextPsn := slv(unsigned(r4StartPsn) + 1);
         r4EndPsn  := r4StartPsn;
      else
         r4NextPsn25 := slv(resize(unsigned(r4StartPsn), 25) + unsigned(r4TotPkt));
         r4NextPsn   := r4NextPsn25(23 downto 0);
         r4EndPsn    := slv(unsigned(r4NextPsn) - 1);
      end if;
      r4HasOnly := r4IsOnly or ite(r4Opcode = WR_RDMA_READ_C, '1', '0');

      if (r4IsNew = '1') then
         r4Pwr(77)           := '1';    -- startPSN := Valid startPSN
         r4Pwr(76 downto 53) := r4StartPsn;
         r4Pwr(52)           := '1';    -- endPSN := Valid endPSN
         r4Pwr(51 downto 28) := r4EndPsn;
         r4Pwr(1)            := '1';    -- isOnlyReqPkt := Valid hasOnlyReqPkt
         r4Pwr(0)            := r4HasOnly;
      end if;

      r4Fire := notReset and isStableRTS and r.isNormalStateReg and
                wrPsnValid and wrChkNotFull;

      npsnWrEn <= r4Fire and r4IsNew;   -- contextSQ.setNPSN
      npsnOut  <= r4NextPsn;

      -- wrPsnRdEn driven after Stage 11 (r4Fire or errFlush R11b)
      wrChkWrEn <= r4Fire;
      wrChkDin  <= r4Pwr & r4Wi;        -- Tuple2(pendingWR, workReqInfo)

      ----------------------------------------------------------------------
      -- Stage 5 : checkPendingWorkReq   (guard isStableRTS && isNormalStateReg)
      ----------------------------------------------------------------------
      r5Pwr    := wrChkDout(683 downto 5);
      r5Wi     := wrChkDout(4 downto 0);
      r5IsOnly := r5Pwr(0);
      r5IsUD   := r5Wi(1);
      r5Valid  := (not r5IsUD) or r5IsOnly;  -- isValidWorkReq

      r5Fire := notReset and isStableRTS and r.isNormalStateReg and
                wrChkValid and wrOutNotFull and (not r5Valid or reqCntNotFull);

      -- wrChkRdEn driven after Stage 11 (r5Fire or errFlush R11c)
      reqCntWrEn <= r5Fire and r5Valid;
      reqCntDin  <= r5Pwr & r5Wi;
      wrOutWrEn  <= r5Fire;
      wrOutDin   <= r5Pwr & r5Wi;

      ----------------------------------------------------------------------
      -- Stage 6 : outputNewPendingWorkReq (guard isStableRTS && isNormalStateReg)
      ----------------------------------------------------------------------
      r6Pwr := wrOutDout(683 downto 5);
      r6Wi  := wrOutDout(4 downto 0);
      r6Enq := r6Wi(4) and r6Wi(2);     -- isNewWorkReq && isReliableConnection

      r6Fire := notReset and isStableRTS and r.isNormalStateReg and
                wrOutValid and (not r6Enq or pwrOutNotFull);
      -- wrOutRdEn driven after Stage 11 (r6Fire or errFlush R11d)
      r6DoEnq := r6Fire and r6Enq;

      ----------------------------------------------------------------------
      -- Stage 7 : countReqPkt (packet loop) (guard isStableRTS && isNormalStateReg)
      ----------------------------------------------------------------------
      r7Pwr      := reqCntDout(683 downto 5);
      r7Wi       := reqCntDout(4 downto 0);
      r7StartPsn := r7Pwr(76 downto 53);  -- unwrap startPSN
      r7TotPkt   := r7Pwr(26 downto 2);   -- unwrap pktNum
      r7IsOnly   := r7Pwr(0);             -- unwrap isOnlyReqPkt

      r7LastOrOnly := r7IsOnly or
                      ((not r.isFirstOrOnlyReqPktReg) and
                       ite(unsigned(r.remainingPktNumReg) = 0, '1', '0'));
      r7FirstPkt := r.isFirstOrOnlyReqPktReg;
      r7LastPkt  := r7LastOrOnly;

      r7CurPsn := r.curPsnReg;
      r7RemPkt := r.remainingPktNumReg;
      if (r.isFirstOrOnlyReqPktReg = '1') then
         r7CurPsn := r7StartPsn;
         if (r7IsOnly = '1') then
            r7RemPkt := (others => '0');
         else
            r7RemPkt := slv(unsigned(r7TotPkt) - 2);
         end if;
      elsif (r7LastPkt = '0') then
         r7RemPkt := slv(unsigned(r.remainingPktNumReg) - 1);
      end if;

      r7Fire := notReset and isStableRTS and r.isNormalStateReg and
                reqCntValid and reqPrepNotFull;

      reqCntRdEn <= r7Fire and r7LastOrOnly;  -- deq only on last/only packet

      -- ReqPktHeaderInfo(curPSN, pendingWR, isFirstReqPkt, isLastReqPkt)
      r7Rphi      := r7CurPsn & r7Pwr & r7FirstPkt & r7LastPkt;
      reqPrepWrEn <= r7Fire;
      reqPrepDin  <= r7Rphi & r7Wi;  -- Tuple2(ReqPktHeaderInfo, workReqInfo)

      if (r7Fire = '1') then
         if (r7LastOrOnly = '1') then
            v.isFirstOrOnlyReqPktReg := '1';
         else
            v.isFirstOrOnlyReqPktReg := '0';
         end if;
         v.remainingPktNumReg := r7RemPkt;
         v.curPsnReg          := slv(unsigned(r7CurPsn) + 1);
      end if;

      ----------------------------------------------------------------------
      -- Stage 8 : prepareReqHeaderGen (drives U_HeaderGenReqSQ, enq pendingReqHeaderQ)
      ----------------------------------------------------------------------
      -- HeaderGenReqSQ combinational outputs (hgHeaderValid/Data/ByteNum/HasPayload)
      -- are wired concurrently from reqPrepDout above.
      r8Fire := notReset and isStableRTS and r.isNormalStateReg and
                reqPrepValid and pendHdrNotFull;
      reqPrepRdEn <= r8Fire;
      pendHdrWrEn <= r8Fire;
      -- Tuple4(pendingWR, workReqInfo, Maybe(Tuple3(headerData,headerByteNum,hasPayload)), curPSN)
      pendHdrDin  <= hpPwr & reqPrepDout(4 downto 0) &
                    hgHeaderValid & hgHeaderData & hgHeaderByteNum & hgHasPayload &
                    reqPrepDout(709 downto 686);

      ----------------------------------------------------------------------
      -- Stage 9 : genReqHeader   (guard isStableRTS && isNormalStateReg)
      ----------------------------------------------------------------------
      r9Valid   := pendHdrDout(544);
      r9NeedDma := pendHdrDout(545);    -- workReqInfo.needDmaRead
      r9GetResp := r9Valid and r9NeedDma;
      r9Hlen    := pendHdrDout(31 downto 25);
      r9HlenInt := to_integer(unsigned(r9Hlen));

      -- genHeaderRDMA: byteEn = headerLen ones at MSB
      for i in 0 to 63 loop
         if (i < r9HlenInt) then
            r9ByteEn(63 - i) := '1';
         else
            r9ByteEn(63 - i) := '0';
         end if;
      end loop;
      r9Res5 := r9Hlen(4 downto 0);
      if (r9Res5 /= "00000") then
         r9Frag := slv(unsigned(r9Hlen(6 downto 5)) + 1);
      else
         r9Frag := r9Hlen(6 downto 5);
      end if;
      if (r9Res5 /= "00000") then
         r9Last := "0" & r9Res5;
      elsif (r9Hlen(6 downto 5) /= "00") then
         r9Last := toSlv(32, 6);
      else
         r9Last := (others => '0');
      end if;
      -- HeaderRDMA = headerData & byteEn & headerLen & fragNum & lastValid & hasPayload & isEmptyHeader
      r9Hdr := pendHdrDout(543 downto 32) & r9ByteEn & r9Hlen & r9Frag & r9Last &
               pendHdrDout(24) & '0';
      r9MaybeHdr  := r9Valid & r9Hdr;                 -- Maybe#(HeaderRDMA)
      r9MaybeResp := r9GetResp & payloadGenRespData;  -- Maybe#(PayloadGenResp)

      r9Fire := notReset and isStableRTS and r.isNormalStateReg and
                pendHdrValid and hdrGenNotFull and (not r9GetResp or payloadGenRespValid);

      pendHdrRdEn         <= r9Fire;
      payloadGenRespReady <= r9Fire and r9GetResp;  -- response.get
      hdrGenWrEn          <= r9Fire;
      -- Tuple4(pendingWR, maybeReqHeader, maybePayloadGenResp, triggerPSN)
      hdrGenDin           <= pendHdrDout(1228 downto 550) & r9MaybeHdr & r9MaybeResp &
                   pendHdrDout(23 downto 0);

      ----------------------------------------------------------------------
      -- Stage 10 : recvPayloadGenRespAndGenErrWorkComp
      ----------------------------------------------------------------------
      r10HasHdr  := hdrGenDout(620);
      r10HasResp := hdrGenDout(26);
      r10RespErr := hdrGenDout(24);
      r10Success := r10HasHdr and (not r10HasResp or not r10RespErr);
      if (r10Success = '1') then
         r10Cond := reqHdrOutNotFull and psnOutNotFull;
      else
         r10Cond := wcOutNotFull;
      end if;
      r10Fire := notReset and isStableRTS and r.isNormalStateReg and
                 hdrGenValid and r10Cond;

      hdrGenRdEn    <= r10Fire;
      -- success -> reqHeaderOutQ + psnReqOutQ
      reqHdrOutWrEn <= r10Fire and r10Success;
      reqHdrOutDin  <= hdrGenDout(619 downto 27);     -- HeaderRDMA
      psnOutWrEn    <= r10Fire and r10Success;
      psnOutDin     <= hdrGenDout(23 downto 0);       -- triggerPSN
      -- error -> workCompGenReqOutQ + isNormalStateReg := False
      wcOutWrEn     <= r10Fire and (not r10Success);
      -- WorkCompGenReqSQ(wr, wcWaitDmaResp=False, WC_REQ_TYPE_PARTIAL_ACK, triggerPSN, IBV_WC_LOC_QP_OP_ERR)
      wcOutDin      <= hdrGenDout(1299 downto 699) & -- pendingWR.wr
                  '0' & WC_REQ_PARTIAL_ACK_C &
                  hdrGenDout(23 downto 0) & WC_LOC_QP_OP_ERR_C;
      if (r10Fire = '1' and r10Success = '0') then
         v.isNormalStateReg := '0';
      end if;

      ----------------------------------------------------------------------
      -- Stage 11 : errFlushWR (guard isERR || (isRTS && !isNormalStateReg))
      --
      -- BUGFIX 2026-07-16 (R11a-d errFlushStrandedWR): the original flush
      -- drained ONLY workReqPayloadGenQ (wrPg).  WRs admitted into the normal
      -- pipeline in the few cycles between the fatal WC (whose pendingWR pop
      -- reopens the NewPendingWorkReqPipeOut window) and the QP's isERR
      -- assertion get consumed by R2 and are then STRANDED in the frozen
      -- stage-2..6 FIFOs (wrPktNumQ / wrPsnQ / wrChkQ / wrOutQ) — their flush
      -- WCs are never generated (observed: suite tests 7/8 in the two-QP
      -- topology lose the last 3-4 WCs).  R11a-d drain those FIFOs in ERR,
      -- OLDEST FIRST (wrOut > wrChk > wrPsn > wrPktNum > wrPg, one per cycle)
      -- to keep flush-WC submission order.  Enq condition per entry is the
      -- same isNewWorkReq && isReliableConnection as R11/R6 (a stranded retry
      -- REPLAY is deq'd without enq — its pending entry lives in ScanFifoF
      -- and is flushed by RespHandleSq).  The stage-5 fork duplicate in
      -- reqCntQ stays inert (stage 7 is frozen in ERR; cleared on isReset).
      -- The stage rules R3-R6 are frozen in both err-flush guard arms
      -- (isStableRTS=0 resp. isNormalStateReg=0), so the rdEn ORs below never
      -- double-fire.
      ----------------------------------------------------------------------
      errFlushMode := notReset and (isERR or (isRTS and not r.isNormalStateReg));

      -- R11d : wrOutQ (stage-6 input; oldest)
      r11dPwr   := wrOutDout(683 downto 5);
      r11dEnq   := wrOutDout(4) and wrOutDout(2);  -- wi: isNewWorkReq && isRC
      r11dFire  := errFlushMode and wrOutValid and (not r11dEnq or pwrOutNotFull);
      r11dDoEnq := r11dFire and r11dEnq;

      -- R11c : wrChkQ (stage-5 input)
      r11cPwr  := wrChkDout(683 downto 5);
      r11cEnq  := wrChkDout(4) and wrChkDout(2);
      r11cFire := errFlushMode and (not wrOutValid) and wrChkValid and
                  (not r11cEnq or pwrOutNotFull);
      r11cDoEnq := r11cFire and r11cEnq;

      -- R11b : wrPsnQ (stage-4 input)
      r11bPwr  := wrPsnDout(683 downto 5);
      r11bEnq  := wrPsnDout(4) and wrPsnDout(2);
      r11bFire := errFlushMode and (not wrOutValid) and (not wrChkValid) and
                  wrPsnValid and (not r11bEnq or pwrOutNotFull);
      r11bDoEnq := r11bFire and r11bEnq;

      -- R11a : wrPktNumQ (stage-3 input)
      r11aPwr  := wrPktNumDout(708 downto 30);
      r11aEnq  := wrPktNumDout(4) and wrPktNumDout(2);
      r11aFire := errFlushMode and (not wrOutValid) and (not wrChkValid) and
                  (not wrPsnValid) and wrPktNumValid and
                  (not r11aEnq or pwrOutNotFull);
      r11aDoEnq := r11aFire and r11aEnq;

      -- R11 : wrPg (stage-2 input; youngest)
      r11Pwr   := wrPgDout(719 downto 41);
      r11Enq   := wrPgDout(2) and wrPgDout(1);  -- isNewWorkReq && isReliableConnection
      r11Guard := errFlushMode and (not wrOutValid) and (not wrChkValid) and
                  (not wrPsnValid) and (not wrPktNumValid) and wrPgValid;
      r11Fire  := r11Guard and (not r11Enq or pwrOutNotFull);
      r11DoEnq := r11Fire and r11Enq;

      -- Stage FIFOs dequeued by their normal stage rule (R2-R6) or the
      -- err-flush rules (R11/R11a-d) — mutually exclusive on the QP status.
      wrPgRdEn     <= r2Fire or r11Fire;
      wrPktNumRdEn <= r3Fire or r11aFire;
      wrPsnRdEn    <= r4Fire or r11bFire;
      wrChkRdEn    <= r5Fire or r11cFire;
      wrOutRdEn    <= r6Fire or r11dFire;

      -- pendingWorkReqOutQ enqueued by R6 (normal) or R11/R11a-d (err-flush) —
      -- mutually exclusive on the mode bit; the R11* branches are one-hot by
      -- the oldest-first priority chain above.
      if (r6DoEnq = '1') then
         pwrOutWrEn <= '1';
         pwrOutDin  <= r6Pwr;
      elsif (r11dDoEnq = '1') then
         pwrOutWrEn <= '1';
         pwrOutDin  <= r11dPwr;
      elsif (r11cDoEnq = '1') then
         pwrOutWrEn <= '1';
         pwrOutDin  <= r11cPwr;
      elsif (r11bDoEnq = '1') then
         pwrOutWrEn <= '1';
         pwrOutDin  <= r11bPwr;
      elsif (r11aDoEnq = '1') then
         pwrOutWrEn <= '1';
         pwrOutDin  <= r11aPwr;
      elsif (r11DoEnq = '1') then
         pwrOutWrEn <= '1';
         pwrOutDin  <= r11Pwr;
      else
         pwrOutWrEn <= '0';
         pwrOutDin  <= (others => '0');
      end if;

      ----------------------------------------------------------------------
      -- resetAndClear : while isReset asserted force mode/loop bits
      ----------------------------------------------------------------------
      if (isReset = '1') then
         v.isNormalStateReg       := '1';
         v.isFirstOrOnlyReqPktReg := '1';
      end if;

      -- synchronous FPGA reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      ----------------------------------------------------------------------
      -- Combinational method output
      ----------------------------------------------------------------------
      reqHeaderOutNotEmpty <= psnOutValid;  -- psnReqOutQ.notEmpty

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin;
      end if;
   end process seq;

end architecture rtl;
