-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Five-stage dataflow pipeline (recvWQE -> recvTotalMetaData -> updatePSN ->
--   prepareHeader -> genPktHeader), all BSV (* conflict_free *) rules, so each
--   stage fires independently when its input FIFO is non-empty, its output FIFO
--   has room, and (where used) the external payloadGenerator handshake holds.
--   Handoff between stages is FIFO-carried; the only true sequential state is the
--   per-WQE packet loop in updatePSN (curPsnReg, wqeFirstPktReg).
--
--   8 pipeline FIFOs (all surf.Fifo, FWFT, sync) + 3 internal children:
--     U_HeaderGenRDMA     : work.HeaderGenRDMA        (combinational header packer,
--                            split out of mkSendQ — see ADDENDUM-HeaderGenRDMA.md;
--                            VERIFIED, out/05-verify/HeaderGenRDMA.result.md PASS)
--     U_HeaderDataStream  : work.Header2DataStream    (mkHeader2DataStream)
--     U_RdmaPktDataStream : work.PrependHeader2PipeOut (mkPrependHeader2PipeOut)
--
--   Module parameters become ports (OQ-FSM-SQ-02): clearAll -> clearAllI;
--   payloadGenerator -> an external Server + 2 PipeOut port group (NOT an instance).
--
--   resetAndClear (BSV) : while clearAllI='1' all 8 FIFOs are held cleared
--     (fifoRst = rst OR clearAllI) and wqeFirstPktReg is forced '1'.
--
--   SURF components instantiated (source: surf/base/fifo/rtl/Fifo.vhd):
--     U_ReqQ, U_RespQ, U_UdpPktInfoOutQ, U_TotalMetaDataQ, U_PsnUpdateQ,
--     U_HeaderPrepareQ, U_PendingHeaderQ, U_PktHeaderQ.
--
--   Judgment calls / open questions (see out/04-vhdl/OPEN_QUESTIONS.md):
--     OQ-EMIT-SQ-SPLIT  : header datapath moved to work.HeaderGenRDMA.
--     OQ-EMIT-SQ-SENDRESP: SendResp is 0-width; U_RespQ carries a 1-bit token.
--     Refactor: pendingHeaderQ carries the packed HeaderRDMA (from HeaderGenRDMA,
--       run in the prepareHeader stage) + a headerValid tag + hasPayload, instead
--       of the BSV Maybe#(PktHeaderInfo); genPktHeader muxes raw vs non-raw.
--
--   Composite word layouts (first-field-at-MSB, from BSV deriving(Bits)):
--     WorkQueueElem (1721): id[1720:1657] opcode[1656:1653] flags[1652:1648]
--       qpType[1647:1644] psn[1643:1620] pmtu[1619:1617] dqpIP[1616:1488]
--       macAddr[1487:1440] sgl[1439:400] totalLen[399:368] raddr[367:304]
--       rkey[303:272] sqpn[271:248] dqpn[247:224] comp[223:159] swap[158:94]
--       immDtOrInvRKey[93:60] srqn[59:35] qkey[34:2] isFirst[1] isLast[0]
--       (sgl[0] = wqe[1439:1310]: laddr[1439:1376] len[1375:1344] lkey[1343:1312]
--        isFirst[1311] isLast[1310]; Maybe# tag is the MSB of its field.)
--     HeaderGenInfo (142): remoteAddr[141:78] totalLen[77:46] curPSN[45:22]
--       pktLen[21:9] padCnt[8:7] hasPayload[6] ackReq[5] solicited[4]
--       isFirstPkt[3] isLastPkt[2] isOnlyPkt[1] isRawPkt[0]
--     PayloadGenReqSG (1228): wrID[1227:1164] sqpn[1163:1140] sgl[1139:100]
--       totalLen[99:68] raddr[67:4] pmtu[3:1] addPadding[0]
--     PayloadGenRespSG (81): raddr[80:17] pktLen[16:4] padCnt[3:2] isFirst[1] isLast[0]
--     PayloadGenTotalMetaData (27): totalPktNum[26:2] isOnlyPkt[1] isZeroPayloadLen[0]
--     PktInfo4UDP (191): macAddr[190:143] ipAddr[142:14] pktLen[13:1] isRawPkt[0]
--     HeaderRDMA (593): see HeaderGenRDMA.vhd header.
--     pendingHeaderQ (787): macAddr[786:739] ipAddr[738:610] pktLenWithPadCnt[609:597]
--       isRawPkt[596] isSendDone[595] hasPayload[594] headerValid[593] pktHeaderRdma[592:0]
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

entity SendQ is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk : in sl;
      rst : in sl;                                          -- active-high synchronous reset
      -- Software clear (BSV module parameter clearAll : Bool)
      clearAllI              : in  sl;
      -- srvPort.request : Server input, WorkQueueElem (toGPServer reqQ)
      reqReqValid            : in  sl;
      reqReqData             : in  slv(1720 downto 0);
      reqReqReady            : out sl;                      -- reqQ.notFull
      -- srvPort.response : Server output, SendResp token (toGPServer respQ)
      respValid              : out sl;                      -- respQ.notEmpty
      respData               : out slv(0 downto 0);         -- SendResp (0-width -> 1-bit token)
      respReady              : in  sl;                      -- response.get (deq)
      -- udpInfoPipeOut : PipeOut#(PktInfo4UDP)
      udpInfoValid           : out sl;
      udpInfoData            : out slv(190 downto 0);
      udpInfoRdEn            : in  sl;
      -- rdmaDataStreamPipeOut : DataStreamPipeOut (290-bit DataStream)
      rdmaDataValid          : out sl;
      rdmaDataData           : out slv(289 downto 0);
      rdmaDataRdEn           : in  sl;
      -- payloadGenerator.srvPort.request : PayloadGenReqSG (out / put)
      payloadGenReqValid     : out sl;
      payloadGenReqData      : out slv(1227 downto 0);
      payloadGenReqReady     : in  sl;
      -- payloadGenerator.srvPort.response : PayloadGenRespSG (in / get)
      payloadGenRespValid    : in  sl;
      payloadGenRespData     : in  slv(80 downto 0);
      payloadGenRespReady    : out sl;
      -- payloadGenerator.totalMetaDataPipeOut : PayloadGenTotalMetaData (in)
      payloadTotalMetaValid  : in  sl;
      payloadTotalMetaData   : in  slv(26 downto 0);
      payloadTotalMetaRdEn   : out sl;
      -- payloadGenerator.payloadDataStreamPipeOut : DataStream (in)
      payloadDataStreamValid : in  sl;
      payloadDataStreamData  : in  slv(289 downto 0);
      payloadDataStreamRdEn  : out sl;
      -- method Bool isEmpty()  (combinational)
      isEmpty                : out sl);
end entity SendQ;

architecture rtl of SendQ is

   -- WorkReqOpCode encodings (4 bits)
   constant WR_RDMA_WRITE_C     : slv(3 downto 0) := x"0";
   constant WR_WRITE_IMM_C      : slv(3 downto 0) := x"1";
   constant WR_SEND_C           : slv(3 downto 0) := x"2";
   constant WR_SEND_IMM_C       : slv(3 downto 0) := x"3";
   constant WR_SEND_INV_C       : slv(3 downto 0) := x"9";
   constant WR_READ_RESP_C      : slv(3 downto 0) := x"C";
   -- TypeQP RAW encoding
   constant QPT_RAW_C           : slv(3 downto 0) := x"8";

   -- FIFO element widths
   constant WQE_W_C     : integer := 1721;  -- WorkQueueElem
   constant TMD_W_C     : integer := 1723;  -- Tuple3(wqe,Bool,Bool)
   constant PSNU_W_C    : integer := 1782;  -- Tuple7(...)
   constant HPREP_W_C   : integer := 1863;  -- Tuple2(wqe,HeaderGenInfo)
   constant PEND_W_C    : integer := 787;   -- refactored pendingHeaderQ
   constant HRDMA_W_C   : integer := 593;   -- HeaderRDMA
   constant UDP_W_C     : integer := 191;   -- PktInfo4UDP
   constant DS_W_C      : integer := 290;   -- DataStream

   type RegType is record
      curPsnReg      : slv(23 downto 0);   -- mkRegU (PSN); no power-on reset
      wqeFirstPktReg : sl;                 -- mkRegU but forced '1' by resetAndClear
   end record RegType;

   -- curPsnReg is mkRegU (written before read); given '0' for a defined start.
   constant REG_INIT_C : RegType := (
      curPsnReg      => (others => '0'),
      wqeFirstPktReg => '1');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal fifoRst : sl;

   -- FIFO interconnect signals
   signal reqQDout       : slv(WQE_W_C-1 downto 0);
   signal reqQValid      : sl;
   signal reqQNotFull    : sl;
   signal reqQEmpty      : sl;
   signal reqQRdEn       : sl;

   signal tmdDin         : slv(TMD_W_C-1 downto 0);
   signal tmdWrEn        : sl;
   signal tmdDout        : slv(TMD_W_C-1 downto 0);
   signal tmdValid       : sl;
   signal tmdNotFull     : sl;
   signal tmdEmpty       : sl;
   signal tmdRdEn        : sl;

   signal psnDin         : slv(PSNU_W_C-1 downto 0);
   signal psnWrEn        : sl;
   signal psnDout        : slv(PSNU_W_C-1 downto 0);
   signal psnValid       : sl;
   signal psnNotFull     : sl;
   signal psnEmpty       : sl;
   signal psnRdEn        : sl;

   signal hprepDin       : slv(HPREP_W_C-1 downto 0);
   signal hprepWrEn      : sl;
   signal hprepDout      : slv(HPREP_W_C-1 downto 0);
   signal hprepValid     : sl;
   signal hprepNotFull   : sl;
   signal hprepEmpty     : sl;
   signal hprepRdEn      : sl;

   signal pendDin        : slv(PEND_W_C-1 downto 0);
   signal pendWrEn       : sl;
   signal pendDout       : slv(PEND_W_C-1 downto 0);
   signal pendValid      : sl;
   signal pendNotFull    : sl;
   signal pendEmpty      : sl;
   signal pendRdEn       : sl;

   signal pktHdrDin      : slv(HRDMA_W_C-1 downto 0);
   signal pktHdrWrEn     : sl;
   signal pktHdrDout     : slv(HRDMA_W_C-1 downto 0);
   signal pktHdrValid    : sl;
   signal pktHdrNotFull  : sl;
   signal pktHdrEmpty    : sl;
   signal pktHdrRdEn     : sl;

   signal udpDin         : slv(UDP_W_C-1 downto 0);
   signal udpWrEn        : sl;
   signal udpDout        : slv(UDP_W_C-1 downto 0);
   signal udpValid       : sl;
   signal udpNotFull     : sl;
   signal udpEmpty       : sl;

   signal respWrEn       : sl;
   signal respQValid     : sl;
   signal respQNotFull   : sl;
   signal respQEmpty     : sl;

   -- HeaderGenRDMA interconnect (driven from headerPrepareQ.dout)
   signal hpWqe          : slv(WQE_W_C-1 downto 0);
   signal hgrIsFirstOrOnly : sl;
   signal hgrIsOnlyOrLast  : sl;
   signal hgrSolicited     : sl;
   signal hgrAckReq        : sl;
   signal hgrPsn           : slv(23 downto 0);
   signal hgrPadCnt        : slv(1 downto 0);
   signal hgrRemoteAddr    : slv(63 downto 0);
   signal hgrDlen          : slv(31 downto 0);
   signal hgrHasPayloadIn  : sl;
   signal hgrHeaderValid   : sl;
   signal hgrPktHeaderRdma : slv(592 downto 0);

   -- Header2DataStream <-> PrependHeader2PipeOut interconnect
   signal hdrDsValid     : sl;
   signal hdrDsData      : slv(289 downto 0);
   signal hdrDsRdEn      : sl;
   signal hdrMetaValid   : sl;
   signal hdrMetaData    : slv(16 downto 0);
   signal hdrMetaRdEn    : sl;

begin

   fifoRst <= rst or clearAllI;

   ---------------------------------------------------------------------------
   -- 8 pipeline FIFOs (all surf.Fifo, FWFT, synchronous)
   ---------------------------------------------------------------------------
   U_ReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => WQE_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => reqReqValid,
         din      => reqReqData,
         not_full => reqQNotFull,
         rd_clk   => clk,
         rd_en    => reqQRdEn,
         dout     => reqQDout,
         valid    => reqQValid,
         empty    => reqQEmpty);

   U_TotalMetaDataQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => TMD_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => tmdWrEn,
         din      => tmdDin,
         not_full => tmdNotFull,
         rd_clk   => clk,
         rd_en    => tmdRdEn,
         dout     => tmdDout,
         valid    => tmdValid,
         empty    => tmdEmpty);

   U_PsnUpdateQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => PSNU_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => psnWrEn,
         din      => psnDin,
         not_full => psnNotFull,
         rd_clk   => clk,
         rd_en    => psnRdEn,
         dout     => psnDout,
         valid    => psnValid,
         empty    => psnEmpty);

   U_HeaderPrepareQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => HPREP_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => hprepWrEn,
         din      => hprepDin,
         not_full => hprepNotFull,
         rd_clk   => clk,
         rd_en    => hprepRdEn,
         dout     => hprepDout,
         valid    => hprepValid,
         empty    => hprepEmpty);

   U_PendingHeaderQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => PEND_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => pendWrEn,
         din      => pendDin,
         not_full => pendNotFull,
         rd_clk   => clk,
         rd_en    => pendRdEn,
         dout     => pendDout,
         valid    => pendValid,
         empty    => pendEmpty);

   U_PktHeaderQ : entity surf.Fifo
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
         wr_en    => pktHdrWrEn,
         din      => pktHdrDin,
         not_full => pktHdrNotFull,
         rd_clk   => clk,
         rd_en    => pktHdrRdEn,
         dout     => pktHdrDout,
         valid    => pktHdrValid,
         empty    => pktHdrEmpty);

   U_UdpPktInfoOutQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => UDP_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => udpWrEn,
         din      => udpDin,
         not_full => udpNotFull,
         rd_clk   => clk,
         rd_en    => udpInfoRdEn,
         dout     => udpDout,
         valid    => udpValid,
         empty    => udpEmpty);

   U_RespQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 1,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => respWrEn,
         din      => "0",
         not_full => respQNotFull,
         rd_clk   => clk,
         rd_en    => respReady,
         dout     => respData,
         valid    => respQValid,
         empty    => respQEmpty);

   ---------------------------------------------------------------------------
   -- Internal children
   ---------------------------------------------------------------------------
   -- HeaderGenRDMA is combinational; its inputs are the headerPrepareQ head
   -- (wqe + HeaderGenInfo).  Driven concurrently below.
   hpWqe <= hprepDout(HPREP_W_C-1 downto 142);          -- WorkQueueElem slice

   hgrIsFirstOrOnly <= hprepDout(3);                    -- HeaderGenInfo.isFirstPkt
   hgrIsOnlyOrLast  <= ite(hprepDout(3) = '1', hprepDout(1), hprepDout(2));  -- isFirst?isOnly:isLast
   hgrSolicited     <= hprepDout(4);
   hgrAckReq        <= hprepDout(5);
   hgrPsn           <= hprepDout(45 downto 22);         -- HeaderGenInfo.curPSN
   hgrPadCnt        <= hprepDout(8 downto 7);
   hgrRemoteAddr    <= hprepDout(141 downto 78);        -- HeaderGenInfo.remoteAddr
   hgrDlen          <= hprepDout(77 downto 46) when hprepDout(3) = '1' else  -- first: totalLen
                       (31 downto 13 => '0') & hprepDout(21 downto 9);  -- last: zeroExt(pktLen)
   hgrHasPayloadIn  <= hprepDout(6);

   U_HeaderGenRDMA : entity surf.HeaderGenRDMA
      port map (
         isFirstOrOnly => hgrIsFirstOrOnly,
         isOnlyOrLast  => hgrIsOnlyOrLast,
         qpType        => hpWqe(1647 downto 1644),
         opcode        => hpWqe(1656 downto 1653),
         solicited     => hgrSolicited,
         ackReq        => hgrAckReq,
         psn           => hgrPsn,
         padCnt        => hgrPadCnt,
         remoteAddr    => hgrRemoteAddr,
         wqeRaddr      => hpWqe(367 downto 304),
         dlen          => hgrDlen,
         hasPayloadIn  => hgrHasPayloadIn,
         dqpn          => hpWqe(247 downto 224),
         sqpn          => hpWqe(271 downto 248),
         srqn          => hpWqe(58 downto 35),           -- Maybe#(QPN) value (tag=MSB dropped)
         qkey          => hpWqe(33 downto 2),            -- Maybe#(QKEY) value
         rkey          => hpWqe(303 downto 272),
         sgeLaddr      => hpWqe(1439 downto 1376),        -- sgl[0].laddr
         sgeLkey       => hpWqe(1343 downto 1312),        -- sgl[0].lkey
         swapData      => hpWqe(157 downto 94),           -- Maybe#(Long) value
         compData      => hpWqe(222 downto 159),          -- Maybe#(Long) value
         immData       => hpWqe(91 downto 60),            -- Maybe#(ImmOrRKey) value
         headerValid   => hgrHeaderValid,
         pktHeaderRdma => hgrPktHeaderRdma);

   U_HeaderDataStream : entity surf.Header2DataStream
      generic map (
         TPD_G => TPD_G)
      port map (
         clk                => clk,
         rst                => rst,
         clearAllI          => clearAllI,
         hdrPipeInValid     => pktHdrValid,
         hdrPipeInData      => pktHdrDout,
         hdrPipeInRdEn      => pktHdrRdEn,
         hdrDataStreamValid => hdrDsValid,
         hdrDataStreamDout  => hdrDsData,
         hdrDataStreamRdEn  => hdrDsRdEn,
         hdrMetaDataValid   => hdrMetaValid,
         hdrMetaDataDout    => hdrMetaData,
         hdrMetaDataRdEn    => hdrMetaRdEn);

   U_RdmaPktDataStream : entity surf.PrependHeader2PipeOut
      generic map (
         TPD_G => TPD_G)
      port map (
         clk                   => clk,
         rst                   => rst,
         clearAllI             => clearAllI,
         headerMetaPipeInValid => hdrMetaValid,
         headerMetaPipeInData  => hdrMetaData,
         headerMetaPipeInRdEn  => hdrMetaRdEn,
         headerPipeInValid     => hdrDsValid,
         headerPipeInData      => hdrDsData,
         headerPipeInRdEn      => hdrDsRdEn,
         dataPipeInValid       => payloadDataStreamValid,
         dataPipeInData        => payloadDataStreamData,
         dataPipeInRdEn        => payloadDataStreamRdEn,
         dataStreamOutValid    => rdmaDataValid,
         dataStreamOutData     => rdmaDataData,
         dataStreamOutRdEn     => rdmaDataRdEn);

   ---------------------------------------------------------------------------
   -- Combinational pipeline (5 conflict_free stages + isEmpty)
   ---------------------------------------------------------------------------
   comb : process (all) is
      variable v : RegType;

      -- stage-local variables
      variable notClear : sl;
      -- recvWQE
      variable rwOpcode  : slv(3 downto 0);
      variable rwQpType  : slv(3 downto 0);
      variable rwIsRaw   : sl;
      variable rwAddPad  : sl;
      variable rwIsSend  : sl;
      variable rwNeedGen : sl;
      variable rwGenPl   : sl;
      variable rwRemote  : slv(63 downto 0);
      variable rwFire    : sl;
      -- recvTotalMetaData
      variable rtGenPl  : sl;
      variable rtIsRaw  : sl;
      variable rtHasPl  : sl;
      variable rtIsOnly : sl;
      variable rtTotPkt : slv(24 downto 0);
      variable rtFire   : sl;
      -- updatePSN
      variable upWqe       : slv(WQE_W_C-1 downto 0);
      variable upGenPl     : sl;
      variable upHasPl     : sl;
      variable upIsOnly    : sl;
      variable upIsRaw     : sl;
      variable upTotLen    : slv(31 downto 0);
      variable upTotPkt    : slv(24 downto 0);
      variable upCurPsn    : slv(23 downto 0);
      variable upRemote    : slv(63 downto 0);
      variable upPktLen    : slv(12 downto 0);
      variable upPadCnt    : slv(1 downto 0);
      variable upLastPkt   : sl;
      variable upFirstPkt  : sl;
      variable upIsLastPkt : sl;
      variable upAckReq    : sl;
      variable upSolicited : sl;
      variable upHgi       : slv(141 downto 0);
      variable upFire      : sl;
      -- prepareHeader
      variable phRaw       : sl;
      variable phHasPl     : sl;
      variable phPktLenPad : slv(12 downto 0);
      variable phSendDone  : sl;
      variable phFire      : sl;
      -- genPktHeader
      variable gpRaw        : sl;
      variable gpHasPl      : sl;
      variable gpHdrValid   : sl;
      variable gpValidEntry : sl;
      variable gpHeaderLen  : slv(6 downto 0);
      variable gpEmptyHdr   : slv(592 downto 0);
      variable gpPktHdr     : slv(592 downto 0);
      variable gpUdpPktLen  : slv(12 downto 0);
      variable gpSendDone   : sl;
      variable gpFire       : sl;
   begin
      v := r;
      notClear := not clearAllI;

      ----------------------------------------------------------------------
      -- Stage 1 : recvWQE
      ----------------------------------------------------------------------
      rwOpcode := reqQDout(1656 downto 1653);
      rwQpType := reqQDout(1647 downto 1644);
      rwIsRaw  := ite(rwQpType = QPT_RAW_C, '1', '0');
      rwAddPad := not rwIsRaw;
      rwIsSend := ite(rwOpcode = WR_SEND_C or rwOpcode = WR_SEND_IMM_C or
                      rwOpcode = WR_SEND_INV_C, '1', '0');
      rwNeedGen := ite(rwOpcode = WR_RDMA_WRITE_C or rwOpcode = WR_WRITE_IMM_C or
                       rwOpcode = WR_SEND_C or rwOpcode = WR_SEND_IMM_C or
                       rwOpcode = WR_SEND_INV_C or rwOpcode = WR_READ_RESP_C, '1', '0');
      rwGenPl  := rwIsRaw or rwNeedGen;
      if (rwIsRaw = '1' or rwIsSend = '1') then
         rwRemote := (others => '0');
      else
         rwRemote := reqQDout(367 downto 304);          -- wqe.raddr
      end if;

      rwFire := notClear and reqQValid and tmdNotFull and
                (not rwGenPl or payloadGenReqReady);

      reqQRdEn <= rwFire;
      tmdWrEn  <= rwFire;
      tmdDin   <= reqQDout & rwIsRaw & rwGenPl;          -- Tuple3(wqe,isRawPkt,shouldGenPayload)
      payloadGenReqValid <= rwFire and rwGenPl;
      -- PayloadGenReqSG: wrID & sqpn & sgl & totalLen & raddr & pmtu & addPadding
      payloadGenReqData <= reqQDout(1720 downto 1657) & -- wrID (=wqe.id)
                           reqQDout(271 downto 248) & -- sqpn
                           reqQDout(1439 downto 400) & -- sgl
                           reqQDout(399 downto 368) & -- totalLen
                           rwRemote & -- raddr (remoteAddr)
                           reqQDout(1619 downto 1617) & -- pmtu
                           rwAddPad;                      -- addPadding

      ----------------------------------------------------------------------
      -- Stage 2 : recvTotalMetaData
      ----------------------------------------------------------------------
      -- tmdDout = wqe[1722:2] & isRawPkt[1] & shouldGenPayload[0]
      rtGenPl := tmdDout(0);
      rtIsRaw := tmdDout(1);
      if (rtGenPl = '1') then
         -- PayloadGenTotalMetaData: totalPktNum[26:2] isOnlyPkt[1] isZeroPayloadLen[0]
         rtHasPl  := not payloadTotalMetaData(0);
         rtIsOnly := payloadTotalMetaData(1);
         rtTotPkt := payloadTotalMetaData(26 downto 2);
      else
         rtHasPl  := rtGenPl;                            -- = '0'
         rtIsOnly := not rtGenPl;                        -- = '1'
         rtTotPkt := std_logic_vector(to_unsigned(1, 25));
      end if;

      rtFire := notClear and tmdValid and psnNotFull and
                (not rtGenPl or payloadTotalMetaValid);

      tmdRdEn <= rtFire;
      payloadTotalMetaRdEn <= rtFire and rtGenPl;
      psnWrEn <= rtFire;
      -- Tuple7(wqe, totalLen, totalPktNum, shouldGenPayload, hasPayload, isOnlyPkt, isRawPkt)
      psnDin <= tmdDout(TMD_W_C-1 downto 2) & -- wqe
                tmdDout(399+2 downto 368+2) & -- wqe.totalLen (offset +2 in tmdDout)
                rtTotPkt & rtGenPl & rtHasPl & rtIsOnly & rtIsRaw;

      ----------------------------------------------------------------------
      -- Stage 3 : updatePSN  (per-WQE packet loop; the only stateful stage)
      ----------------------------------------------------------------------
      -- psnDout : wqe[1781:61] totalLen[60:29] totalPktNum[28:4]
      --           shouldGenPayload[3] hasPayload[2] isOnlyPkt[1] isRawPkt[0]
      upWqe    := psnDout(PSNU_W_C-1 downto 61);
      upTotLen := psnDout(60 downto 29);
      upTotPkt := psnDout(28 downto 4);
      upGenPl  := psnDout(3);
      upHasPl  := psnDout(2);
      upIsOnly := psnDout(1);
      upIsRaw  := psnDout(0);

      if (r.wqeFirstPktReg = '1') then
         upCurPsn := upWqe(1643 downto 1620);            -- wqe.psn
      else
         upCurPsn := r.curPsnReg;
      end if;

      upRemote := upWqe(367 downto 304);                 -- wqe.raddr (default)
      upPktLen := (others => '0');
      upPadCnt := (others => '0');
      upLastPkt := upIsOnly;
      if (upGenPl = '1') then
         -- PayloadGenRespSG: raddr[80:17] pktLen[16:4] padCnt[3:2] isFirst[1] isLast[0]
         upRemote  := payloadGenRespData(80 downto 17);
         upPktLen  := payloadGenRespData(16 downto 4);
         upPadCnt  := payloadGenRespData(3 downto 2);
         upLastPkt := payloadGenRespData(0);
      end if;

      upFirstPkt  := r.wqeFirstPktReg and upWqe(1);      -- wqe.isFirst
      upIsLastPkt := upLastPkt and upWqe(0);             -- wqe.isLast
      upAckReq    := upWqe(1649);                        -- flags(1)=IBV_SEND_SIGNALED
      upSolicited := upWqe(1650);                        -- flags(2)=IBV_SEND_SOLICITED

      upFire := notClear and psnValid and hprepNotFull and
                (not upGenPl or payloadGenRespValid);

      -- HeaderGenInfo: remoteAddr totalLen curPSN pktLen padCnt hasPayload
      --                ackReq solicited isFirstPkt isLastPkt isOnlyPkt isRawPkt
      upHgi := upRemote & upTotLen & upCurPsn & upPktLen & upPadCnt & upHasPl &
               upAckReq & upSolicited & upFirstPkt & upIsLastPkt & upIsOnly & upIsRaw;

      psnRdEn <= upFire and upLastPkt;
      hprepWrEn <= upFire;
      hprepDin  <= upWqe & upHgi;
      payloadGenRespReady <= upFire and upGenPl;

      -- register updates (only this stage writes curPsnReg / wqeFirstPktReg)
      if (upFire = '1') then
         v.curPsnReg      := slv(unsigned(upCurPsn) + 1);
         v.wqeFirstPktReg := upLastPkt;
      end if;

      ----------------------------------------------------------------------
      -- Stage 4 : prepareHeader  (drives U_HeaderGenRDMA, enq pendingHeaderQ)
      ----------------------------------------------------------------------
      phRaw       := hprepDout(0);                       -- HeaderGenInfo.isRawPkt
      phHasPl     := hprepDout(6);                       -- HeaderGenInfo.hasPayload
      phPktLenPad := slv(unsigned(hprepDout(21 downto 9)) +
                         resize(unsigned(hprepDout(8 downto 7)), 13));  -- pktLen + padCnt
      phSendDone  := hprepDout(1) or hprepDout(2);       -- isOnlyPkt or isLastPkt

      phFire := notClear and hprepValid and pendNotFull;

      hprepRdEn <= phFire;
      pendWrEn  <= phFire;
      -- pendingHeaderQ: macAddr ipAddr pktLenWithPadCnt isRawPkt isSendDone
      --                 hasPayload headerValid pktHeaderRdma
      pendDin <= hpWqe(1487 downto 1440) & -- macAddr
                 hpWqe(1616 downto 1488) & -- dqpIP
                 phPktLenPad & phRaw & phSendDone & phHasPl &
                 hgrHeaderValid & hgrPktHeaderRdma;

      ----------------------------------------------------------------------
      -- Stage 5 : genPktHeader
      ----------------------------------------------------------------------
      gpRaw      := pendDout(596);
      gpSendDone := pendDout(595);
      gpHasPl    := pendDout(594);
      gpHdrValid := pendDout(593);
      gpValidEntry := gpRaw or gpHdrValid;               -- Maybe Valid

      -- genEmptyHeaderRDMA(hasPayload): all zero except hasPayload + isEmptyHeader
      gpEmptyHdr := (others => '0');
      gpEmptyHdr(1) := gpHasPl;
      gpEmptyHdr(0) := '1';                              -- isEmptyHeader

      if (gpRaw = '1') then
         gpPktHdr    := gpEmptyHdr;
         gpHeaderLen := (others => '0');
      else
         gpPktHdr    := pendDout(592 downto 0);
         gpHeaderLen := pendDout(16 downto 10);          -- HeaderRDMA.headerMetaData.headerLen
      end if;

      gpUdpPktLen := slv(unsigned(pendDout(609 downto 597)) +
                         resize(unsigned(gpHeaderLen), 13));

      gpFire := notClear and pendValid and pktHdrNotFull and udpNotFull and
                (not gpSendDone or respQNotFull);

      pendRdEn   <= gpFire;
      pktHdrWrEn <= gpFire and gpValidEntry;
      pktHdrDin  <= gpPktHdr;
      udpWrEn    <= gpFire and gpValidEntry;
      -- PktInfo4UDP: macAddr ipAddr pktLen isRawPkt
      udpDin     <= pendDout(786 downto 739) & pendDout(738 downto 610) &
                    gpUdpPktLen & gpRaw;
      respWrEn   <= gpFire and gpValidEntry and gpSendDone;

      ----------------------------------------------------------------------
      -- resetAndClear : force wqeFirstPktReg = '1' while clearAllI asserted
      ----------------------------------------------------------------------
      if (clearAllI = '1') then
         v.wqeFirstPktReg := '1';
      end if;

      -- synchronous reset (curPsnReg is mkRegU: not forced; wqeFirstPktReg -> '1')
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      ----------------------------------------------------------------------
      -- External interface outputs
      ----------------------------------------------------------------------
      reqReqReady  <= reqQNotFull;
      respValid    <= respQValid;
      udpInfoValid <= udpValid;
      udpInfoData  <= udpDout;

      isEmpty <= reqQEmpty and respQEmpty and udpEmpty and tmdEmpty and
                 psnEmpty and hprepEmpty and pendEmpty and pktHdrEmpty;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin;
      end if;
   end process seq;

end architecture rtl;
