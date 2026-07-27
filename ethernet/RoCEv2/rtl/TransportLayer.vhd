-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Pure STRUCTURAL top-level of the blue-rdma transport layer. mkTransportLayer
--   owns zero state registers and zero behavioural rules (mapping.json
--   rule_count = 0): everything it does is elaboration — instantiate children,
--   wire them, and re-export faces. Accordingly this file contains NO RegType /
--   two-process FSM; only instances plus the combinational glue mandated by the
--   FSM spec (transfer strobes, the QP-status mux, and constant ties).
--
--   Child entity instances (all separately emitted and Stage-5 verified):
--     U_MetaDataPDs      : work.MetaDataPDs                     (mkMetaDataPDs)
--     U_PermCheckSrv     : work.PermCheckSrv                    (mkPermCheckSrv)
--     U_MetaDataQPs      : work.MetaDataQPs                     (mkMetaDataQPs)
--     U_MetaDataSrv      : work.MetaDataSrv                     (mkMetaDataSrv)
--     U_Dispatcher       : work.WorkReqAndRecvReqDispatcher     (mkWorkReqAndRecvReqDispatcher)
--     U_ExtractHeader    : work.ExtractHeaderFromRdmaPktPipeOut (mkExtractHeaderFromRdmaPktPipeOut)
--     U_PktBuf           : work.InputRdmaPktBufAndHeaderValidation (mkInputRdmaPktBufAndHeaderValidation)
--     GEN_QP(i).U_Qp     : work.Qp x MAX_QP_G  (mkQP, HOISTED from MetaDataQPs
--                          per RESOLVED OQ-FSM-MDQPS-01: the BSV per-QP wiring
--                          loop indexes getQueuePairByIndexQP with a
--                          compile-time constant -> for..generate here)
--     U_PermCheckCltArb  : work.PermCheckCltArbiter             (mkPermCheckCltArbiter)
--     U_DmaReadCltArb    : work.DmaReadCltArbiter               (mkDmaReadCltArbiter)
--     U_DmaWriteCltArb   : work.DmaWriteCltArbiter              (mkDmaWriteCltArbiter)
--     U_DataStreamArb    : work.PipeOutArbiter (PORT_COUNT_G=2*MAX_QP_G, 290 b)
--     U_RecvWcArb        : work.PipeOutArbiter (PORT_COUNT_G=MAX_QP_G,   222 b)
--     U_SendWcArb        : work.PipeOutArbiter (PORT_COUNT_G=MAX_QP_G,   222 b)
--
--   SURF components instantiated DIRECTLY by this entity (BSV mkFIFOF -> sync
--   FWFT surf.Fifo, 16 deep, project convention OQ-EMIT-PCS-02):
--     U_InputDataStreamQ : surf.Fifo (290 b)  <- inputDataStreamQ (TransportLayer.bsv:82)
--     U_InputWorkReqQ    : surf.Fifo (601 b)  <- inputWorkReqQ    (TransportLayer.bsv:85)
--     U_InputRecvReqQ    : surf.Fifo (216 b)  <- inputRecvReqQ    (TransportLayer.bsv:86)
--
--   Arbiter slot convention (TransportLayer.bsv:135-144): even slot k = 2i is
--   QP i's RQ/resp face, odd slot k = 2i+1 is QP i's SQ/req face.
--
--   QP-status mux (glue G5, replaces the BSV dynamic getQueuePairByQPN,
--   RESOLVED OQ-FSM-MDQPS-01 sec.2.3): statusIdx = getIndexQP(U_PktBuf.getQpQpn)
--   = truncateLSB, i.e. qpn(23 downto 24-log2(MAX_QP_G)); U_PktBuf's sq* and
--   rq* status inputs are fed from the SAME per-QP comm bundle (only TypeQP
--   differs) because Qp exports ONE shared comm* group for SQ+RQ
--   (OQ-EMIT-QP-01) — identical to the BSV, where statusSQ.comm and
--   statusRQ.comm read the same mkCntrlQP registers.
--
--   CNP (TransportLayer.bsv:146-151): U_PktBuf's per-QP CNP pipe is
--   self-dequeued (cnpRdEn <= cnpValid) and exported on the cnp output as
--   1-cycle pulses, one bit per QP, for an external DCQCN engine.
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

entity TransportLayer is
   generic (
      TPD_G    : time     := 1 ns;
      MAX_QP_G : positive := 4;         -- MAX_QP (Settings.bsv:14); any power of 2, >= 2
      -- Pruning generics (all true = full engine, identical to the verified
      -- netlist; at least one of EN_TX_G/EN_RX_G must be true):
      --  EN_TX_G=false   : no requester — SQ subtree, workReq input path and
      --                    SQ work-completion arbiter are not generated
      --                    (workReqInReady tied '0').
      --  EN_RX_G=false   : no responder — RQ subtree, recvReq input path and
      --                    RQ work-completion arbiter are not generated
      --                    (recvReqInReady tied '0'); incoming request packets
      --                    are dropped in U_PktBuf. ACK/NAK reception (SQ
      --                    side) is NOT affected.
      --  EN_READ_G=false : no RDMA READ/atomic — requester read-response
      --                    landing and responder read/atomic serving pruned.
      --                    Software contract: never post READ/atomic WRs.
      EN_TX_G   : boolean := true;
      EN_RX_G   : boolean := true;
      EN_READ_G : boolean := true;
      -- MAX_QP_WR (Settings.bsv:15; BSV default 32): max pending work requests
      -- per QP (effective in-flight window is MAX_QP_WR_G-1, one slot
      -- reserved). Must be a power of 2.
      MAX_QP_WR_G : positive := 4);
   port (
      clk : in sl;
      rst : in sl;                      -- active-high synchronous reset

      -- rdmaDataStreamInput : Put#(DataStream 290b)
      dataStreamInValid : in  sl;
      dataStreamInData  : in  slv(289 downto 0);
      dataStreamInReady : out sl;

      -- workReqInput : Put#(WorkReq 601b)
      workReqInValid : in  sl;
      workReqInData  : in  slv(600 downto 0);
      workReqInReady : out sl;

      -- recvReqInput : Put#(RecvReq 216b)
      recvReqInValid : in  sl;
      recvReqInData  : in  slv(215 downto 0);
      recvReqInReady : out sl;

      -- rdmaDataStreamPipeOut : DataStreamPipeOut (290b)
      dataStreamOutValid : out sl;
      dataStreamOutData  : out slv(289 downto 0);
      dataStreamOutRdEn  : in  sl;

      -- workCompPipeOutRQ / workCompPipeOutSQ : PipeOut#(WorkComp 222b)
      workCompRqValid : out sl;
      workCompRqData  : out slv(221 downto 0);
      workCompRqRdEn  : in  sl;
      workCompSqValid : out sl;
      workCompSqData  : out slv(221 downto 0);
      workCompSqRdEn  : in  sl;

      -- srvPortMetaData : Server#(MetaDataReq 303b, MetaDataResp 276b)
      -- (re-export of U_MetaDataSrv.srv*)
      mdSrvReqValid  : in  sl;
      mdSrvReqData   : in  slv(302 downto 0);
      mdSrvReqReady  : out sl;
      mdSrvRespValid : out sl;
      mdSrvRespData  : out slv(275 downto 0);
      mdSrvRespReady : in  sl;

      -- dmaReadClt : Client#(DmaReadReq 176b, DmaReadResp 383b)
      -- (re-export of U_DmaReadCltArb.out*)
      dmaReadReqValid  : out sl;
      dmaReadReqData   : out slv(175 downto 0);
      dmaReadReqRd     : in  sl;
      dmaReadRespValid : in  sl;
      dmaReadRespData  : in  slv(382 downto 0);
      dmaReadRespReady : out sl;

      -- dmaWriteClt : Client#(DmaWriteReq 419b, DmaWriteResp 53b)
      -- (re-export of U_DmaWriteCltArb.out*)
      dmaWriteReqValid  : out sl;
      dmaWriteReqData   : out slv(418 downto 0);
      dmaWriteReqRd     : in  sl;
      dmaWriteRespValid : in  sl;
      dmaWriteRespData  : in  slv(52 downto 0);
      dmaWriteRespReady : out sl;

      -- cnpPipeOutVec (TransportLayer.bsv:146-151): one CNP pulse per QP (1 cycle
      -- when that QP receives a congestion notification). One bit per supported QP.
      cnp               : out slv(MAX_QP_G-1 downto 0));
end entity TransportLayer;

architecture rtl of TransportLayer is

   -- Payload widths, traced from the emitted child entities (FSM spec table)
   constant DATA_STREAM_W_C  : positive := 290;  -- DataStream
   constant WORK_REQ_W_C     : positive := 601;  -- WorkReq
   constant RECV_REQ_W_C     : positive := 216;  -- RecvReq
   constant WORK_COMP_W_C    : positive := 222;  -- WorkComp
   constant PKT_META_W_C     : positive := 649;  -- RdmaPktMetaData
   constant RESP_QP_W_C      : positive := 274;  -- RespQP
   constant PERM_REQ_W_C     : positive := 267;  -- PermCheckReq
   constant DMA_RD_REQ_W_C   : positive := 176;  -- DmaReadReq
   constant DMA_RD_RESP_W_C  : positive := 383;  -- DmaReadResp
   constant DMA_WR_REQ_W_C   : positive := 419;  -- DmaWriteReq
   constant DMA_WR_RESP_W_C  : positive := 53;   -- DmaWriteResp

   -- MAX_PD (Settings.bsv:20); BSV proviso MAX_QP >= MAX_PD (MetaData.bsv:679-682)
   -- forces MAX_PD = 1 at MAX_QP_G = 1
   constant MAX_PD_C       : positive := ite(MAX_QP_G < 2, 1, 2);
   constant QP_IDX_WIDTH_C : positive := log2(MAX_QP_G); -- IndexQP width

   -- isWorkCompFinished = constant True in BSV (TransportLayer.bsv:164-166)
   constant WC_FINISHED_C : slv(MAX_QP_G-1 downto 0) := (others => '1');

   -- G1: input FIFO faces (surf.Fifo x3)
   signal dataStreamQWrEn    : sl;
   signal dataStreamQNotFull : sl;
   signal dataStreamQValid   : sl;
   signal dataStreamQDout    : slv(DATA_STREAM_W_C-1 downto 0);
   signal dataStreamQRdEn    : sl;
   signal workReqQWrEn       : sl;
   signal workReqQNotFull    : sl;
   signal workReqQValid      : sl;
   signal workReqQDout       : slv(WORK_REQ_W_C-1 downto 0);
   signal workReqQRdEn       : sl;
   signal recvReqQWrEn       : sl;
   signal recvReqQNotFull    : sl;
   signal recvReqQValid      : sl;
   signal recvReqQDout       : slv(RECV_REQ_W_C-1 downto 0);
   signal recvReqQRdEn       : sl;

   -- W2: dispatcher per-QP read faces -> Qp Put faces (G2 strobes)
   signal dispWorkReqOutValid : slv(MAX_QP_G-1 downto 0);
   signal dispWorkReqOutData  : slv(MAX_QP_G*WORK_REQ_W_C-1 downto 0);
   signal dispRecvReqOutValid : slv(MAX_QP_G-1 downto 0);
   signal dispRecvReqOutData  : slv(MAX_QP_G*RECV_REQ_W_C-1 downto 0);
   signal workReqXfer         : slv(MAX_QP_G-1 downto 0);
   signal recvReqXfer         : slv(MAX_QP_G-1 downto 0);
   signal qpWorkReqInReady    : slv(MAX_QP_G-1 downto 0);
   signal qpRecvReqInReady    : slv(MAX_QP_G-1 downto 0);

   -- W3: header extraction -> packet buffer (1:1)
   signal extHeaderDataStreamValid : sl;
   signal extHeaderDataStreamData  : slv(DATA_STREAM_W_C-1 downto 0);
   signal extHeaderDataStreamRdEn  : sl;
   signal extHeaderMetaDataValid   : sl;
   signal extHeaderMetaDataData    : slv(16 downto 0);
   signal extHeaderMetaDataRdEn    : sl;
   signal extPayloadValid          : sl;
   signal extPayloadData           : slv(DATA_STREAM_W_C-1 downto 0);
   signal extPayloadRdEn           : sl;

   -- W4: packet buffer per-QP pipes -> Qp pkt Put faces (G2 strobes)
   signal pktBufReqPktMetaValid   : slv(MAX_QP_G-1 downto 0);
   signal pktBufReqPktMetaDout    : slv(MAX_QP_G*PKT_META_W_C-1 downto 0);
   signal pktBufReqPayloadValid   : slv(MAX_QP_G-1 downto 0);
   signal pktBufReqPayloadDout    : slv(MAX_QP_G*DATA_STREAM_W_C-1 downto 0);
   signal pktBufRespPktMetaValid  : slv(MAX_QP_G-1 downto 0);
   signal pktBufRespPktMetaDout   : slv(MAX_QP_G*PKT_META_W_C-1 downto 0);
   signal pktBufRespPayloadValid  : slv(MAX_QP_G-1 downto 0);
   signal pktBufRespPayloadDout   : slv(MAX_QP_G*DATA_STREAM_W_C-1 downto 0);
   signal reqPktMetaXfer          : slv(MAX_QP_G-1 downto 0);
   signal reqPktPayloadXfer       : slv(MAX_QP_G-1 downto 0);
   signal respPktMetaXfer         : slv(MAX_QP_G-1 downto 0);
   signal respPktPayloadXfer      : slv(MAX_QP_G-1 downto 0);
   signal qpReqPktMetaReady       : slv(MAX_QP_G-1 downto 0);
   signal qpReqPktPayloadReady    : slv(MAX_QP_G-1 downto 0);
   signal qpRespPktMetaReady      : slv(MAX_QP_G-1 downto 0);
   signal qpRespPktPayloadReady   : slv(MAX_QP_G-1 downto 0);
   signal cnpValid                : slv(MAX_QP_G-1 downto 0);

   -- W5: RDMA DataStream output arbiter (even slot 2i = resp/RQ, odd = req/SQ)
   signal dataStreamArbInValid    : slv(2*MAX_QP_G-1 downto 0);
   signal dataStreamArbInDout     : slv(2*MAX_QP_G*DATA_STREAM_W_C-1 downto 0);
   signal dataStreamArbInFinished : slv(2*MAX_QP_G-1 downto 0);
   signal dataStreamArbInRd       : slv(2*MAX_QP_G-1 downto 0);

   -- W6: work-completion arbiters
   signal recvWcArbInValid : slv(MAX_QP_G-1 downto 0);
   signal recvWcArbInDout  : slv(MAX_QP_G*WORK_COMP_W_C-1 downto 0);
   signal recvWcArbInRd    : slv(MAX_QP_G-1 downto 0);
   signal sendWcArbInValid : slv(MAX_QP_G-1 downto 0);
   signal sendWcArbInDout  : slv(MAX_QP_G*WORK_COMP_W_C-1 downto 0);
   signal sendWcArbInRd    : slv(MAX_QP_G-1 downto 0);

   -- W7: MetaData cluster (MetaDataSrv <-> MetaDataPDs / MetaDataQPs / PermCheckSrv)
   signal mdSrvPdReqValid       : sl;
   signal mdSrvPdReqData        : slv(63 downto 0);   -- ReqPD
   signal mdSrvPdReqReady       : sl;
   signal mdSrvPdRespValid      : sl;
   signal mdSrvPdRespData       : slv(63 downto 0);   -- RespPD
   signal mdSrvPdRespReady      : sl;
   signal mdSrvIsValidPdHandler : slv(31 downto 0);
   signal mdSrvIsValidPd        : sl;
   signal mrSrvPdHandler        : slv(31 downto 0);
   signal mrSrvPdValid          : sl;
   signal mrSrvReqValid         : sl;
   signal mrSrvReqData          : slv(251 downto 0);  -- ReqMR
   signal mrSrvReqReady         : sl;
   signal mrSrvRespValid        : sl;
   signal mrSrvRespData         : slv(250 downto 0);  -- RespMR
   signal mrSrvRespReady        : sl;
   -- mdSrvQp* naming is MANDATED (RESOLVED OQ-FSM-MDSRV-01 sec.5) to avoid
   -- colliding with MetaDataQPs' own per-QP qpReq*/qpResp* bundle (W8 below).
   signal mdSrvQpReqValid       : sl;
   signal mdSrvQpReqData        : slv(300 downto 0);  -- ReqQP
   signal mdSrvQpReqReady       : sl;
   signal mdSrvQpRespValid      : sl;
   signal mdSrvQpRespData       : slv(273 downto 0);  -- RespQP
   signal mdSrvQpRespReady      : sl;
   signal mrLkupPdHandler       : slv(31 downto 0);
   signal mrLkupKey             : slv(31 downto 0);
   signal mrLkupByLocal         : sl;
   signal mrLkupReqValid        : sl;
   signal mrLkupValid           : sl;
   signal mrLkupData            : slv(185 downto 0);  -- MemRegion

   -- W8: MetaDataQPs per-QP srvPortQP client bundle -> GEN_QP(i).U_Qp.srvPort*
   signal qpCtrlReqValid  : slv(MAX_QP_G-1 downto 0);  -- one-hot request put
   signal qpCtrlReqData   : slv(300 downto 0);          -- shared ReqQP payload
   signal qpCtrlReqReady  : slv(MAX_QP_G-1 downto 0);
   signal qpCtrlRespValid : slv(MAX_QP_G-1 downto 0);
   signal qpCtrlRespData  : slv(MAX_QP_G*RESP_QP_W_C-1 downto 0);
   signal qpCtrlRespReady : slv(MAX_QP_G-1 downto 0);

   -- W9: getPD(qpn) combinational lookup (U_PktBuf -> U_MetaDataQPs)
   signal pktBufGetPdQpn        : slv(23 downto 0);
   signal pktBufGetPdMaybeValid : sl;
   signal pktBufGetPdHandler    : slv(31 downto 0);

   -- W10: PermCheck arbitration (2*MAX_QP_G client slots + downstream server)
   signal permSrvReqValid  : slv(2*MAX_QP_G-1 downto 0);
   signal permSrvReqData   : slv(2*MAX_QP_G*PERM_REQ_W_C-1 downto 0);
   signal permSrvReqGet    : slv(2*MAX_QP_G-1 downto 0);
   signal permSrvRespValid : slv(2*MAX_QP_G-1 downto 0);
   signal permSrvRespData  : slv(2*MAX_QP_G-1 downto 0);  -- PERM_RESP_WIDTH_G = 1
   signal permSrvRespReady : slv(2*MAX_QP_G-1 downto 0);
   signal permCltReqValid  : sl;
   signal permCltReqData   : slv(PERM_REQ_W_C-1 downto 0);
   signal permCltReqRd     : sl;
   signal permCltRespValid : sl;
   signal permCltRespData  : slv(0 downto 0);
   signal permCltRespReady : sl;
   signal permReqPutReady  : sl;
   signal permRespGetValid : sl;
   signal permRespGetData  : sl;
   signal permRespGetRdEn  : sl;

   -- W11: DMA read/write arbitration (2*MAX_QP_G client slots each)
   signal dmaRdCltReqValid  : slv(2*MAX_QP_G-1 downto 0);
   signal dmaRdCltReqData   : slv(2*MAX_QP_G*DMA_RD_REQ_W_C-1 downto 0);
   signal dmaRdCltReqGet    : slv(2*MAX_QP_G-1 downto 0);
   signal dmaRdCltRespValid : slv(2*MAX_QP_G-1 downto 0);
   signal dmaRdCltRespData  : slv(2*MAX_QP_G*DMA_RD_RESP_W_C-1 downto 0);
   signal dmaRdCltRespReady : slv(2*MAX_QP_G-1 downto 0);
   signal dmaWrCltReqValid  : slv(2*MAX_QP_G-1 downto 0);
   signal dmaWrCltReqData   : slv(2*MAX_QP_G*DMA_WR_REQ_W_C-1 downto 0);
   signal dmaWrCltReqGet    : slv(2*MAX_QP_G-1 downto 0);
   signal dmaWrCltRespValid : slv(2*MAX_QP_G-1 downto 0);
   signal dmaWrCltRespData  : slv(2*MAX_QP_G*DMA_WR_RESP_W_C-1 downto 0);
   signal dmaWrCltRespReady : slv(2*MAX_QP_G-1 downto 0);

   -- W12 / G5: per-QP status bundles + the getQueuePairByQPN replacement mux
   signal qpStatusTypeSq  : Slv4Array(MAX_QP_G-1 downto 0);
   signal qpStatusTypeRq  : Slv4Array(MAX_QP_G-1 downto 0);
   signal qpCommIsErr     : slv(MAX_QP_G-1 downto 0);
   signal qpCommIsRts     : slv(MAX_QP_G-1 downto 0);
   signal qpCommIsNonErr  : slv(MAX_QP_G-1 downto 0);
   signal qpCommQkey      : Slv32Array(MAX_QP_G-1 downto 0);
   signal qpCommPmtu      : Slv3Array(MAX_QP_G-1 downto 0);
   signal pktBufGetQpQpn  : slv(23 downto 0);
   signal statusIdx       : natural range 0 to MAX_QP_G-1;
   signal statusTypeSqMux : slv(3 downto 0);
   signal statusTypeRqMux : slv(3 downto 0);
   signal statusIsErrMux  : sl;
   signal statusIsRtsMux  : sl;
   signal statusIsNonErrMux : sl;
   signal statusQkeyMux   : slv(31 downto 0);
   signal statusPmtuMux   : slv(2 downto 0);

begin

   -- Static generic legality check (kept outside the translate pragmas: it
   -- must also fail synthesis elaboration on an all-disabled configuration).
   assert (EN_TX_G or EN_RX_G)
      report "TransportLayer: at least one of EN_TX_G / EN_RX_G must be true"
      severity failure;

   -- pragma translate_off
   assert isPowerOf2(MAX_QP_G)
      report "MAX_QP_G must be a power of 2, >= 1 @ TransportLayer"
      severity failure;
   assert (MAX_QP_G mod MAX_PD_C = 0)
      report "MAX_QP_G must be divisible by MAX_PD_G (BSV proviso, MetaData.bsv) @ TransportLayer"
      severity failure;
   -- pragma translate_on

   -----------------------------------------------------------------------------
   -- G1 — Input FIFOs (BSV inputDataStreamQ / inputWorkReqQ / inputRecvReqQ,
   -- TransportLayer.bsv:82-86). Put face: ready = not_full, wr_en = valid&ready.
   -----------------------------------------------------------------------------
   dataStreamInReady <= dataStreamQNotFull;
   dataStreamQWrEn   <= dataStreamInValid and dataStreamQNotFull;

   U_InputDataStreamQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => DATA_STREAM_W_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => rst,
         wr_clk        => clk,
         wr_en         => dataStreamQWrEn,
         din           => dataStreamInData,
         wr_data_count => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         full          => open,
         not_full      => dataStreamQNotFull,
         rd_clk        => clk,
         rd_en         => dataStreamQRdEn,
         dout          => dataStreamQDout,
         rd_data_count => open,
         valid         => dataStreamQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open);

   -- workReq input path: pruned when EN_TX_G=false (input refused).
   GEN_NO_WORKREQ_Q : if not EN_TX_G generate
      workReqInReady <= '0';
      workReqQValid  <= '0';
      workReqQDout   <= (others => '0');
   end generate GEN_NO_WORKREQ_Q;

   GEN_WORKREQ_Q : if EN_TX_G generate
      workReqInReady <= workReqQNotFull;
      workReqQWrEn   <= workReqInValid and workReqQNotFull;

      U_InputWorkReqQ : entity surf.Fifo
         generic map (
            TPD_G           => TPD_G,
            GEN_SYNC_FIFO_G => true,
            FWFT_EN_G       => true,
            MEMORY_TYPE_G   => "distributed",
            DATA_WIDTH_G    => WORK_REQ_W_C,
            ADDR_WIDTH_G    => 4)
         port map (
            rst           => rst,
            wr_clk        => clk,
            wr_en         => workReqQWrEn,
            din           => workReqInData,
            wr_data_count => open,
            wr_ack        => open,
            overflow      => open,
            prog_full     => open,
            almost_full   => open,
            full          => open,
            not_full      => workReqQNotFull,
            rd_clk        => clk,
            rd_en         => workReqQRdEn,
            dout          => workReqQDout,
            rd_data_count => open,
            valid         => workReqQValid,
            underflow     => open,
            prog_empty    => open,
            almost_empty  => open,
            empty         => open);
   end generate GEN_WORKREQ_Q;

   -- recvReq input path: pruned when EN_RX_G=false (input refused).
   GEN_NO_RECVREQ_Q : if not EN_RX_G generate
      recvReqInReady <= '0';
      recvReqQValid  <= '0';
      recvReqQDout   <= (others => '0');
   end generate GEN_NO_RECVREQ_Q;

   GEN_RECVREQ_Q : if EN_RX_G generate
      recvReqInReady <= recvReqQNotFull;
      recvReqQWrEn   <= recvReqInValid and recvReqQNotFull;

      U_InputRecvReqQ : entity surf.Fifo
         generic map (
            TPD_G           => TPD_G,
            GEN_SYNC_FIFO_G => true,
            FWFT_EN_G       => true,
            MEMORY_TYPE_G   => "distributed",
            DATA_WIDTH_G    => RECV_REQ_W_C,
            ADDR_WIDTH_G    => 4)
         port map (
            rst           => rst,
            wr_clk        => clk,
            wr_en         => recvReqQWrEn,
            din           => recvReqInData,
            wr_data_count => open,
            wr_ack        => open,
            overflow      => open,
            prog_full     => open,
            almost_full   => open,
            full          => open,
            not_full      => recvReqQNotFull,
            rd_clk        => clk,
            rd_en         => recvReqQRdEn,
            dout          => recvReqQDout,
            rd_data_count => open,
            valid         => recvReqQValid,
            underflow     => open,
            prog_empty    => open,
            almost_empty  => open,
            empty         => open);
   end generate GEN_RECVREQ_Q;

   -----------------------------------------------------------------------------
   -- W1/W2 — Work-request / receive-request dispatcher (TransportLayer.bsv:93-94)
   -- G2 strobes: WrEn/Valid to the Qp Put face AND RdEn back to the source are
   -- BOTH valid&ready (NOT valid alone — would overflow under back-pressure).
   -----------------------------------------------------------------------------
   workReqXfer <= dispWorkReqOutValid and qpWorkReqInReady;
   recvReqXfer <= dispRecvReqOutValid and qpRecvReqInReady;

   U_Dispatcher : entity surf.WorkReqAndRecvReqDispatcher
      generic map (
         TPD_G    => TPD_G,
         MAX_QP_G => MAX_QP_G,
         EN_TX_G  => EN_TX_G,
         EN_RX_G  => EN_RX_G)
      port map (
         clk               => clk,
         rst               => rst,
         workReqValid_i    => workReqQValid,
         workReqData_i     => workReqQDout,
         workReqDeq_o      => workReqQRdEn,
         recvReqValid_i    => recvReqQValid,
         recvReqData_i     => recvReqQDout,
         recvReqDeq_o      => recvReqQRdEn,
         workReqOutValid_o => dispWorkReqOutValid,
         workReqOutData_o  => dispWorkReqOutData,
         workReqOutRdEn_i  => workReqXfer,
         recvReqOutValid_o => dispRecvReqOutValid,
         recvReqOutData_o  => dispRecvReqOutData,
         recvReqOutRdEn_i  => recvReqXfer);

   -----------------------------------------------------------------------------
   -- W3 — Header extraction (TransportLayer.bsv:100-105); all three output
   -- pipes feed U_PktBuf 1:1 (same names).
   -----------------------------------------------------------------------------
   U_ExtractHeader : entity surf.ExtractHeaderFromRdmaPktPipeOut
      generic map (
         TPD_G => TPD_G)
      port map (
         clk                   => clk,
         rst                   => rst,
         rdmaPktPipeInValid    => dataStreamQValid,
         rdmaPktPipeInData     => dataStreamQDout,
         rdmaPktPipeInRdEn     => dataStreamQRdEn,
         headerDataStreamValid => extHeaderDataStreamValid,
         headerDataStreamData  => extHeaderDataStreamData,
         headerDataStreamRdEn  => extHeaderDataStreamRdEn,
         headerMetaDataValid   => extHeaderMetaDataValid,
         headerMetaDataData    => extHeaderMetaDataData,
         headerMetaDataRdEn    => extHeaderMetaDataRdEn,
         payloadValid          => extPayloadValid,
         payloadData           => extPayloadData,
         payloadRdEn           => extPayloadRdEn);

   -----------------------------------------------------------------------------
   -- W4/W9/W12 — Input packet buffer + header validation
   -- (TransportLayer.bsv:103-105, 122-129). sq*/rq* status inputs share the
   -- same muxed comm bundle (OQ-EMIT-QP-01); G5 mux below.
   -----------------------------------------------------------------------------
   reqPktMetaXfer     <= pktBufReqPktMetaValid and qpReqPktMetaReady;
   reqPktPayloadXfer  <= pktBufReqPayloadValid and qpReqPktPayloadReady;
   respPktMetaXfer    <= pktBufRespPktMetaValid and qpRespPktMetaReady;
   respPktPayloadXfer <= pktBufRespPayloadValid and qpRespPktPayloadReady;

   U_PktBuf : entity surf.InputRdmaPktBufAndHeaderValidation
      generic map (
         TPD_G    => TPD_G,
         MAX_QP_G => MAX_QP_G,
         EN_TX_G  => EN_TX_G,
         EN_RX_G  => EN_RX_G)
      port map (
         clk                   => clk,
         rst                   => rst,
         payloadPipeInValid    => extPayloadValid,
         payloadPipeInData     => extPayloadData,
         payloadPipeInRdEn     => extPayloadRdEn,
         headerDataStreamValid => extHeaderDataStreamValid,
         headerDataStreamData  => extHeaderDataStreamData,
         headerDataStreamRdEn  => extHeaderDataStreamRdEn,
         headerMetaDataValid   => extHeaderMetaDataValid,
         headerMetaDataData    => extHeaderMetaDataData,
         headerMetaDataRdEn    => extHeaderMetaDataRdEn,
         getPdQpn              => pktBufGetPdQpn,
         getPdMaybeValid       => pktBufGetPdMaybeValid,
         getPdHandler          => pktBufGetPdHandler,
         getQpQpn              => pktBufGetQpQpn,
         sqTypeQP              => statusTypeSqMux,
         sqIsERR               => statusIsErrMux,
         sqIsRTS               => statusIsRtsMux,
         sqIsNonErr            => statusIsNonErrMux,
         sqQKEY                => statusQkeyMux,
         sqPMTU                => statusPmtuMux,
         rqTypeQP              => statusTypeRqMux,
         rqIsERR               => statusIsErrMux,
         rqIsRTS               => statusIsRtsMux,
         rqIsNonErr            => statusIsNonErrMux,
         rqQKEY                => statusQkeyMux,
         reqPktMetaDataValid   => pktBufReqPktMetaValid,
         reqPktMetaDataDout    => pktBufReqPktMetaDout,
         reqPktMetaDataRdEn    => reqPktMetaXfer,
         reqPayloadValid       => pktBufReqPayloadValid,
         reqPayloadDout        => pktBufReqPayloadDout,
         reqPayloadRdEn        => reqPktPayloadXfer,
         respPktMetaDataValid  => pktBufRespPktMetaValid,
         respPktMetaDataDout   => pktBufRespPktMetaDout,
         respPktMetaDataRdEn   => respPktMetaXfer,
         respPayloadValid      => pktBufRespPayloadValid,
         respPayloadDout       => pktBufRespPayloadDout,
         respPayloadRdEn       => respPktPayloadXfer,
         cnpValid              => cnpValid,
         cnpDout               => open,
         cnpRdEn               => cnpValid);   -- self-dequeue -> 1-cycle pulse per CNP

   -----------------------------------------------------------------------------
   -- G5 — QP-status mux (replaces BSV getQueuePairByQPN, RESOLVED
   -- OQ-FSM-MDQPS-01 sec.2.3): index = getIndexQP(dqpn) = truncateLSB(qpn).
   -- At MAX_QP_G=1 the BSV index is 0 bits wide, i.e. the constant 0
   -- (MetaData.bsv:349) - force 0 instead of reading a live QPN bit.
   -----------------------------------------------------------------------------
   statusIdx <= ite(MAX_QP_G > 1,
                    to_integer(unsigned(pktBufGetQpQpn(23 downto 24-QP_IDX_WIDTH_C))),
                    0);

   statusTypeSqMux   <= qpStatusTypeSq(statusIdx);
   statusTypeRqMux   <= qpStatusTypeRq(statusIdx);
   statusIsErrMux    <= qpCommIsErr(statusIdx);
   statusIsRtsMux    <= qpCommIsRts(statusIdx);
   statusIsNonErrMux <= qpCommIsNonErr(statusIdx);
   statusQkeyMux     <= qpCommQkey(statusIdx);
   statusPmtuMux     <= qpCommPmtu(statusIdx);

   -----------------------------------------------------------------------------
   -- GEN_QP — the MAX_QP_G queue pairs (BSV qpVec, HOISTED here per RESOLVED
   -- OQ-FSM-MDQPS-01; per-QP wiring loop TransportLayer.bsv:116-152).
   -- Arbiter slots: even 2i = RQ/resp face, odd 2i+1 = SQ/req face.
   -----------------------------------------------------------------------------
   GEN_QP : for i in 0 to MAX_QP_G-1 generate
      U_Qp : entity surf.Qp
         generic map (
            TPD_G       => TPD_G,
            EN_TX_G     => EN_TX_G,
            EN_RX_G     => EN_RX_G,
            EN_READ_G   => EN_READ_G,
            MAX_QP_WR_G => MAX_QP_WR_G)
         port map (
            clk                     => clk,
            rst                     => rst,
            -- W8: srvPortQP <- MetaDataQPs per-QP client bundle
            srvPortReqValid         => qpCtrlReqValid(i),
            srvPortReqData          => qpCtrlReqData,
            srvPortReqReady         => qpCtrlReqReady(i),
            srvPortRespValid        => qpCtrlRespValid(i),
            srvPortRespData         => qpCtrlRespData((i+1)*RESP_QP_W_C-1 downto i*RESP_QP_W_C),
            srvPortRespReady        => qpCtrlRespReady(i),
            -- W2: dispatcher per-QP outputs (G2 qualified strobes)
            recvReqInValid          => recvReqXfer(i),
            recvReqInData           => dispRecvReqOutData((i+1)*RECV_REQ_W_C-1 downto i*RECV_REQ_W_C),
            recvReqInReady          => qpRecvReqInReady(i),
            workReqInValid          => workReqXfer(i),
            workReqInData           => dispWorkReqOutData((i+1)*WORK_REQ_W_C-1 downto i*WORK_REQ_W_C),
            workReqInReady          => qpWorkReqInReady(i),
            -- W11: DMA read/write clients -> arbiter slots 2i (RQ) / 2i+1 (SQ)
            dmaReadClt4RqReqValid   => dmaRdCltReqValid(2*i),
            dmaReadClt4RqReqData    => dmaRdCltReqData((2*i+1)*DMA_RD_REQ_W_C-1 downto (2*i)*DMA_RD_REQ_W_C),
            dmaReadClt4RqReqReady   => dmaRdCltReqGet(2*i),
            dmaReadClt4RqRespValid  => dmaRdCltRespValid(2*i),
            dmaReadClt4RqRespData   => dmaRdCltRespData((2*i+1)*DMA_RD_RESP_W_C-1 downto (2*i)*DMA_RD_RESP_W_C),
            dmaReadClt4RqRespReady  => dmaRdCltRespReady(2*i),
            dmaWriteClt4RqReqValid  => dmaWrCltReqValid(2*i),
            dmaWriteClt4RqReqData   => dmaWrCltReqData((2*i+1)*DMA_WR_REQ_W_C-1 downto (2*i)*DMA_WR_REQ_W_C),
            dmaWriteClt4RqReqReady  => dmaWrCltReqGet(2*i),
            dmaWriteClt4RqRespValid => dmaWrCltRespValid(2*i),
            dmaWriteClt4RqRespData  => dmaWrCltRespData((2*i+1)*DMA_WR_RESP_W_C-1 downto (2*i)*DMA_WR_RESP_W_C),
            dmaWriteClt4RqRespReady => dmaWrCltRespReady(2*i),
            dmaReadClt4SqReqValid   => dmaRdCltReqValid(2*i+1),
            dmaReadClt4SqReqData    => dmaRdCltReqData((2*i+2)*DMA_RD_REQ_W_C-1 downto (2*i+1)*DMA_RD_REQ_W_C),
            dmaReadClt4SqReqReady   => dmaRdCltReqGet(2*i+1),
            dmaReadClt4SqRespValid  => dmaRdCltRespValid(2*i+1),
            dmaReadClt4SqRespData   => dmaRdCltRespData((2*i+2)*DMA_RD_RESP_W_C-1 downto (2*i+1)*DMA_RD_RESP_W_C),
            dmaReadClt4SqRespReady  => dmaRdCltRespReady(2*i+1),
            dmaWriteClt4SqReqValid  => dmaWrCltReqValid(2*i+1),
            dmaWriteClt4SqReqData   => dmaWrCltReqData((2*i+2)*DMA_WR_REQ_W_C-1 downto (2*i+1)*DMA_WR_REQ_W_C),
            dmaWriteClt4SqReqReady  => dmaWrCltReqGet(2*i+1),
            dmaWriteClt4SqRespValid => dmaWrCltRespValid(2*i+1),
            dmaWriteClt4SqRespData  => dmaWrCltRespData((2*i+2)*DMA_WR_RESP_W_C-1 downto (2*i+1)*DMA_WR_RESP_W_C),
            dmaWriteClt4SqRespReady => dmaWrCltRespReady(2*i+1),
            -- W10: PermCheck clients -> arbiter slots 2i (RQ) / 2i+1 (SQ)
            permCheckClt4RqReqValid  => permSrvReqValid(2*i),
            permCheckClt4RqReqData   => permSrvReqData((2*i+1)*PERM_REQ_W_C-1 downto (2*i)*PERM_REQ_W_C),
            permCheckClt4RqReqReady  => permSrvReqGet(2*i),
            permCheckClt4RqRespValid => permSrvRespValid(2*i),
            permCheckClt4RqRespData  => permSrvRespData(2*i),
            permCheckClt4RqRespReady => permSrvRespReady(2*i),
            permCheckClt4SqReqValid  => permSrvReqValid(2*i+1),
            permCheckClt4SqReqData   => permSrvReqData((2*i+2)*PERM_REQ_W_C-1 downto (2*i+1)*PERM_REQ_W_C),
            permCheckClt4SqReqReady  => permSrvReqGet(2*i+1),
            permCheckClt4SqRespValid => permSrvRespValid(2*i+1),
            permCheckClt4SqRespData  => permSrvRespData(2*i+1),
            permCheckClt4SqRespReady => permSrvRespReady(2*i+1),
            -- W4: packet buffer per-QP pipes (G2 qualified strobes)
            reqPktMetaWrEn      => reqPktMetaXfer(i),
            reqPktMetaData      => pktBufReqPktMetaDout((i+1)*PKT_META_W_C-1 downto i*PKT_META_W_C),
            reqPktMetaReady     => qpReqPktMetaReady(i),
            reqPktPayloadWrEn   => reqPktPayloadXfer(i),
            reqPktPayloadData   => pktBufReqPayloadDout((i+1)*DATA_STREAM_W_C-1 downto i*DATA_STREAM_W_C),
            reqPktPayloadReady  => qpReqPktPayloadReady(i),
            respPktMetaWrEn     => respPktMetaXfer(i),
            respPktMetaData     => pktBufRespPktMetaDout((i+1)*PKT_META_W_C-1 downto i*PKT_META_W_C),
            respPktMetaReady    => qpRespPktMetaReady(i),
            respPktPayloadWrEn  => respPktPayloadXfer(i),
            respPktPayloadData  => pktBufRespPayloadDout((i+1)*DATA_STREAM_W_C-1 downto i*DATA_STREAM_W_C),
            respPktPayloadReady => qpRespPktPayloadReady(i),
            -- W12: status bundle (only the members read by validateHeader are
            -- used; the rest of the shared comm* group is left open)
            commIsCreate                       => open,
            commIsErr                          => qpCommIsErr(i),
            commIsInit                         => open,
            commIsNonErr                       => qpCommIsNonErr(i),
            commIsReset                        => open,
            commIsRTR                          => open,
            commIsRTS                          => qpCommIsRts(i),
            commIsSQD                          => open,
            commIsUnknown                      => open,
            commIsRTR2RTS                      => open,
            commIsStableRTS                    => open,
            commGetAccessFlags                 => open,
            commGetMaxRnrCnt                   => open,
            commGetMaxRetryCnt                 => open,
            commGetMinRnrTimer                 => open,
            commGetMaxTimeOut                  => open,
            commGetPendingWorkReqNum           => open,
            commGetPendingRecvReqNum           => open,
            commGetPendingReadAtomicReqNum     => open,
            commGetPendingDestReadAtomicReqNum => open,
            commGetSigAll                      => open,
            commGetSQPN                        => open,
            commGetDQPN                        => open,
            commGetPKEY                        => open,
            commGetQKEY                        => qpCommQkey(i),
            commGetPMTU                        => qpCommPmtu(i),
            statusGetTypeSq                    => qpStatusTypeSq(i),
            statusGetTypeRq                    => qpStatusTypeRq(i),
            statusSqIsSQ                       => open,
            statusRqIsSQ                       => open,
            -- W5: RDMA output streams -> U_DataStreamArb slots 2i (resp) / 2i+1 (req)
            rdmaReqValid    => dataStreamArbInValid(2*i+1),
            rdmaReqData     => dataStreamArbInDout((2*i+2)*DATA_STREAM_W_C-1 downto (2*i+1)*DATA_STREAM_W_C),
            rdmaReqRdEn     => dataStreamArbInRd(2*i+1),
            rdmaRespValid   => dataStreamArbInValid(2*i),
            rdmaRespData    => dataStreamArbInDout((2*i+1)*DATA_STREAM_W_C-1 downto (2*i)*DATA_STREAM_W_C),
            rdmaRespRdEn    => dataStreamArbInRd(2*i),
            -- W6: work completions -> WC arbiters slot i
            workCompRqValid => recvWcArbInValid(i),
            workCompRqData  => recvWcArbInDout((i+1)*WORK_COMP_W_C-1 downto i*WORK_COMP_W_C),
            workCompRqRdEn  => recvWcArbInRd(i),
            workCompSqValid => sendWcArbInValid(i),
            workCompSqData  => sendWcArbInDout((i+1)*WORK_COMP_W_C-1 downto i*WORK_COMP_W_C),
            workCompSqRdEn  => sendWcArbInRd(i));
   end generate GEN_QP;

   -----------------------------------------------------------------------------
   -- W5 — RDMA DataStream output arbiter (TransportLayer.bsv:135-138,160-162).
   -- inFinished(k) = head isLast bit (isDataStreamFinished), = bit 0 of slice k.
   -----------------------------------------------------------------------------
   GEN_DS_FINISHED : for k in 0 to 2*MAX_QP_G-1 generate
      dataStreamArbInFinished(k) <= dataStreamArbInDout(k*DATA_STREAM_W_C);
   end generate GEN_DS_FINISHED;

   U_DataStreamArb : entity surf.PipeOutArbiter
      generic map (
         TPD_G        => TPD_G,
         PORT_COUNT_G => 2*MAX_QP_G,
         DATA_WIDTH_G => DATA_STREAM_W_C)
      port map (
         clk         => clk,
         rst         => rst,
         inValid     => dataStreamArbInValid,
         inDout      => dataStreamArbInDout,
         inFinished  => dataStreamArbInFinished,
         inRd        => dataStreamArbInRd,
         outNotEmpty => dataStreamOutValid,
         outDout     => dataStreamOutData,
         outFinished => open,
         outDeq      => dataStreamOutRdEn);

   -----------------------------------------------------------------------------
   -- W6 — Work-completion arbiters (TransportLayer.bsv:164-166,176-177);
   -- isWorkCompFinished = constant True -> inFinished tied all-ones.
   -----------------------------------------------------------------------------
   -- RQ work-completion arbiter: pruned when EN_RX_G=false (the per-QP
   -- workCompRq faces are tied invalid inside Qp).
   GEN_NO_RECV_WC : if not EN_RX_G generate
      workCompRqValid <= '0';
      workCompRqData  <= (others => '0');
      recvWcArbInRd   <= (others => '0');
   end generate GEN_NO_RECV_WC;

   GEN_RECV_WC : if EN_RX_G generate
      U_RecvWcArb : entity surf.PipeOutArbiter
         generic map (
            TPD_G        => TPD_G,
            PORT_COUNT_G => MAX_QP_G,
            DATA_WIDTH_G => WORK_COMP_W_C)
         port map (
            clk         => clk,
            rst         => rst,
            inValid     => recvWcArbInValid,
            inDout      => recvWcArbInDout,
            inFinished  => WC_FINISHED_C,
            inRd        => recvWcArbInRd,
            outNotEmpty => workCompRqValid,
            outDout     => workCompRqData,
            outFinished => open,
            outDeq      => workCompRqRdEn);
   end generate GEN_RECV_WC;

   -- SQ work-completion arbiter: pruned when EN_TX_G=false.
   GEN_NO_SEND_WC : if not EN_TX_G generate
      workCompSqValid <= '0';
      workCompSqData  <= (others => '0');
      sendWcArbInRd   <= (others => '0');
   end generate GEN_NO_SEND_WC;

   GEN_SEND_WC : if EN_TX_G generate
      U_SendWcArb : entity surf.PipeOutArbiter
         generic map (
            TPD_G        => TPD_G,
            PORT_COUNT_G => MAX_QP_G,
            DATA_WIDTH_G => WORK_COMP_W_C)
         port map (
            clk         => clk,
            rst         => rst,
            inValid     => sendWcArbInValid,
            inDout      => sendWcArbInDout,
            inFinished  => WC_FINISHED_C,
            inRd        => sendWcArbInRd,
            outNotEmpty => workCompSqValid,
            outDout     => workCompSqData,
            outFinished => open,
            outDeq      => workCompSqRdEn);
   end generate GEN_SEND_WC;

   -----------------------------------------------------------------------------
   -- W7 — MetaData cluster (TransportLayer.bsv:88-91,179). srv* face is the
   -- top-level re-export; qp-side nets are mdSrvQp* (RESOLVED MDSRV-01 sec.5).
   -----------------------------------------------------------------------------
   U_MetaDataSrv : entity surf.MetaDataSrv
      generic map (
         TPD_G => TPD_G)
      port map (
         clk              => clk,
         rst              => rst,
         srvReqValid      => mdSrvReqValid,
         srvReqData       => mdSrvReqData,
         srvReqReady      => mdSrvReqReady,
         srvRespValid     => mdSrvRespValid,
         srvRespData      => mdSrvRespData,
         srvRespReady     => mdSrvRespReady,
         pdReqValid       => mdSrvPdReqValid,
         pdReqData        => mdSrvPdReqData,
         pdReqReady       => mdSrvPdReqReady,
         pdRespValid      => mdSrvPdRespValid,
         pdRespData       => mdSrvPdRespData,
         pdRespReady      => mdSrvPdRespReady,
         isValidPdHandler => mdSrvIsValidPdHandler,
         isValidPd        => mdSrvIsValidPd,
         mrSrvPdHandler   => mrSrvPdHandler,
         mrSrvPdValid     => mrSrvPdValid,
         mrSrvReqValid    => mrSrvReqValid,
         mrSrvReqData     => mrSrvReqData,
         mrSrvReqReady    => mrSrvReqReady,
         mrSrvRespValid   => mrSrvRespValid,
         mrSrvRespData    => mrSrvRespData,
         mrSrvRespReady   => mrSrvRespReady,
         qpReqValid       => mdSrvQpReqValid,
         qpReqData        => mdSrvQpReqData,
         qpReqReady       => mdSrvQpReqReady,
         qpRespValid      => mdSrvQpRespValid,
         qpRespData       => mdSrvQpRespData,
         qpRespReady      => mdSrvQpRespReady);

   U_MetaDataPDs : entity surf.MetaDataPDs
      generic map (
         TPD_G    => TPD_G,
         MAX_PD_G => MAX_PD_C)
      port map (
         clk              => clk,
         rst              => rst,
         srvReqValid      => mdSrvPdReqValid,
         srvReqData       => mdSrvPdReqData,
         srvReqReady      => mdSrvPdReqReady,
         srvRespValid     => mdSrvPdRespValid,
         srvRespData      => mdSrvPdRespData,
         srvRespReady     => mdSrvPdRespReady,
         isValidPdHandler => mdSrvIsValidPdHandler,
         isValidPd        => mdSrvIsValidPd,
         mrLkupPdHandler  => mrLkupPdHandler,
         mrLkupKey        => mrLkupKey,
         mrLkupByLocal    => mrLkupByLocal,
         mrLkupReqValid   => mrLkupReqValid,
         mrLkupValid      => mrLkupValid,
         mrLkupData       => mrLkupData,
         mrSrvPdHandler   => mrSrvPdHandler,
         mrSrvPdValid     => mrSrvPdValid,
         mrSrvReqValid    => mrSrvReqValid,
         mrSrvReqData     => mrSrvReqData,
         mrSrvReqReady    => mrSrvReqReady,
         mrSrvRespValid   => mrSrvRespValid,
         mrSrvRespData    => mrSrvRespData,
         mrSrvRespReady   => mrSrvRespReady,
         clearEn          => '0',       -- no clear() caller in mkTransportLayer
         notEmpty         => open,
         notFull          => open);

   U_MetaDataQPs : entity surf.MetaDataQPs
      generic map (
         TPD_G    => TPD_G,
         MAX_QP_G => MAX_QP_G)
      port map (
         clk             => clk,
         rst             => rst,
         srvReqValid     => mdSrvQpReqValid,
         srvReqData      => mdSrvQpReqData,
         srvReqReady     => mdSrvQpReqReady,
         srvRespValid    => mdSrvQpRespValid,
         srvRespData     => mdSrvQpRespData,
         srvRespReady    => mdSrvQpRespReady,
         qpReqValid      => qpCtrlReqValid,
         qpReqData       => qpCtrlReqData,
         qpReqReady      => qpCtrlReqReady,
         qpRespValid     => qpCtrlRespValid,
         qpRespData      => qpCtrlRespData,
         qpRespReady     => qpCtrlRespReady,
         getPdQpn        => pktBufGetPdQpn,
         getPdMaybeValid => pktBufGetPdMaybeValid,
         getPdHandler    => pktBufGetPdHandler,
         notEmpty        => open,
         notFull         => open);

   -----------------------------------------------------------------------------
   -- W10/G4 — PermCheck arbitration + downstream server (TransportLayer.bsv:
   -- 139-140,154,158). G4 = mkConnection(arbitratedPermCheckClt, permCheckSrv).
   -----------------------------------------------------------------------------
   U_PermCheckCltArb : entity surf.PermCheckCltArbiter
      generic map (
         TPD_G    => TPD_G,
         MAX_QP_G => MAX_QP_G)
      port map (
         clk              => clk,
         rst              => rst,
         permSrvReqValid  => permSrvReqValid,
         permSrvReqData   => permSrvReqData,
         permSrvReqGet    => permSrvReqGet,
         permSrvRespValid => permSrvRespValid,
         permSrvRespData  => permSrvRespData,
         permSrvRespReady => permSrvRespReady,
         permCltReqValid  => permCltReqValid,
         permCltReqData   => permCltReqData,
         permCltReqRd     => permCltReqRd,
         permCltRespValid => permCltRespValid,
         permCltRespData  => permCltRespData,
         permCltRespReady => permCltRespReady);

   U_PermCheckSrv : entity surf.PermCheckSrv
      generic map (
         TPD_G => TPD_G)
      port map (
         clk             => clk,
         rst             => rst,
         reqPutValid     => permCltReqValid,
         reqPutData      => permCltReqData,
         reqPutReady     => permReqPutReady,
         respGetValid    => permRespGetValid,
         respGetData     => permRespGetData,
         respGetRdEn     => permRespGetRdEn,
         mrLkupPdHandler => mrLkupPdHandler,
         mrLkupKey       => mrLkupKey,
         mrLkupByLocal   => mrLkupByLocal,
         mrLkupReqValid  => mrLkupReqValid,
         mrLkupValid     => mrLkupValid,
         mrLkupData      => mrLkupData);

   -- G4 Get<->Put transfer strobes
   permCltReqRd       <= permCltReqValid and permReqPutReady;
   permCltRespValid   <= permRespGetValid and permCltRespReady;
   permCltRespData(0) <= permRespGetData;
   permRespGetRdEn    <= permRespGetValid and permCltRespReady;

   -----------------------------------------------------------------------------
   -- W11 — DMA read/write client arbitration (TransportLayer.bsv:141-144,
   -- 155-156); downstream faces re-exported on the top-level (180-181).
   -----------------------------------------------------------------------------
   U_DmaReadCltArb : entity surf.DmaReadCltArbiter
      generic map (
         TPD_G    => TPD_G,
         MAX_QP_G => MAX_QP_G)
      port map (
         clk          => clk,
         rst          => rst,
         cltReqValid  => dmaRdCltReqValid,
         cltReqData   => dmaRdCltReqData,
         cltReqGet    => dmaRdCltReqGet,
         cltRespValid => dmaRdCltRespValid,
         cltRespData  => dmaRdCltRespData,
         cltRespReady => dmaRdCltRespReady,
         outReqValid  => dmaReadReqValid,
         outReqData   => dmaReadReqData,
         outReqRd     => dmaReadReqRd,
         outRespValid => dmaReadRespValid,
         outRespData  => dmaReadRespData,
         outRespReady => dmaReadRespReady);

   U_DmaWriteCltArb : entity surf.DmaWriteCltArbiter
      generic map (
         TPD_G    => TPD_G,
         MAX_QP_G => MAX_QP_G)
      port map (
         clk          => clk,
         rst          => rst,
         cltReqValid  => dmaWrCltReqValid,
         cltReqData   => dmaWrCltReqData,
         cltReqGet    => dmaWrCltReqGet,
         cltRespValid => dmaWrCltRespValid,
         cltRespData  => dmaWrCltRespData,
         cltRespReady => dmaWrCltRespReady,
         outReqValid  => dmaWriteReqValid,
         outReqData   => dmaWriteReqData,
         outReqRd     => dmaWriteReqRd,
         outRespValid => dmaWriteRespValid,
         outRespData  => dmaWriteRespData,
         outRespReady => dmaWriteRespReady);

   -----------------------------------------------------------------------------
   -- CNP output (TransportLayer.bsv:146-151): forward the per-QP CNP pipe to the
   -- DCQCN engine (in the RoCEv2AxiStreamRdma wrapper). Self-dequeued above.
   -----------------------------------------------------------------------------
   cnp <= cnpValid;

end architecture rtl;
