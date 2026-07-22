-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Pure structural interconnect. `mkDmaArbiter4QP` owns NO registered state,
--   NO rules and NO FIFOs of its own; it composes two proxy+arbiter pairs (one
--   per DMA direction) and routes their faces to the module boundary:
--
--     read  path : {dmaReadSrv4RQ , dmaReadSrv4SQ } --> U_DmaReadArb
--                    --(downstream srv)--> U_DmaReadProxy --> dmaReadClt
--     write path : {dmaWriteSrv4RQ, dmaWriteSrv4SQ} --> U_DmaWriteArb
--                    --(downstream srv)--> U_DmaWriteProxy --> dmaWriteClt
--
--   Each direction is 2 upstream Servers (RQ = port 0, SQ = port 1) arbitrated
--   onto one downstream Server (the proxy's srvPort); the proxy's cltPort is the
--   aggregated Client toward the external DMA subsystem.  All FIFO/RAM state
--   lives inside the children; this container only wires and computes the four
--   arbiter "finished" predicates (OQ-FSM-17 resolution).
--
--   Because there is no state to translate, this architecture is emitted as pure
--   structural VHDL (four component instances + port maps + a handful of
--   concurrent glue assignments) rather than the SURF two-process comb/seq
--   template.  There is no RegType / REG_INIT_C — mkDmaArbiter4QP has zero
--   mkReg/mkRegU/mkCReg fields (FSM spec §"State register": NONE).  Same
--   convention as the sibling structural container SqQueuePair.vhd
--   (OQ-EMIT-SQQP-01).
--
--   Child entity instances (each separately emitted):
--     U_DmaReadArb    : work.ServerArbiter (PORT_COUNT_G=2)  <- dmaReadSrvVec
--     U_DmaReadProxy  : work.ServerProxy                     <- dmaReadProxy
--     U_DmaWriteArb   : work.ServerArbiter (PORT_COUNT_G=2)  <- dmaWriteSrvVec
--     U_DmaWriteProxy : work.ServerProxy                     <- dmaWriteProxy
--
--   SURF components instantiated DIRECTLY by this entity: NONE.  Every surf.Fifo
--   used by the DMA arbitration lives inside a child entity.
--
--   Struct widths (traced from DataTypes.bsv; confirmed against DmaReadCntrlGen.vhd
--   lines 134/141 where DmaReadReq=176 and DmaReadResp=383 are used):
--     DmaReadReq   = 176  = DmaReqSrcType(4)+QPN(24)+WorkReqID(64)+ADDR(64)
--                            +PktLen(13)+IndexMR(7)
--     DmaReadResp  = 383  = DmaReqSrcType(4)+QPN(24)+WorkReqID(64)+Bool(1)
--                            +DataStream(290)
--     DmaWriteReq  = 419  = DmaWriteMetaData(129)+DataStream(290)
--                            [meta = DmaReqSrcType(4)+QPN(24)+ADDR(64)+PktLen(13)+PSN(24)]
--     DmaWriteResp =  53  = DmaReqSrcType(4)+QPN(24)+PSN(24)+Bool(1)
--     DataStream   = 290  = DATA(256)+ByteEn(32)+isFirst(1)+isLast(1)
--
--   Arbiter "finished" predicates (OQ-FSM-17: the parent, where the concrete type
--   is known, computes them and feeds them to the child as 1-bit inputs).  BSV
--   packs the first struct field into the MSBs, so `dataStream` (last field) sits
--   in the low bits and `isLast` (last field of DataStream) is bit 0 of the whole
--   payload (confirmed: DmaReadCntrlGen.vhd uses dmaRespIn(0) as dataStream.isLast):
--     U_DmaReadArb .reqKFinished  = isDmaReadReqLastFrag(req)  = True        -> tie '1'
--     U_DmaReadArb .srvRespFinished= isDmaReadRespLastFrag(rsp)= rsp.ds.isLast-> bit 0
--     U_DmaWriteArb.reqKFinished  = isDmaWriteReqLastFrag(req) = req.ds.isLast-> bit 0
--     U_DmaWriteArb.srvRespFinished= isDmaWriteRespLastFrag(rsp)= True        -> tie '1'
--   The two per-port request predicates are sampled at enqueue (companion carried
--   through the arbiter's input FIFO), so they are pure functions of the incoming
--   request data on that port — extracted here as bit 0 of the port's reqData.
--
--   ServerProxy caveat: it hard-codes active-HIGH synchronous reset internally
--   (RST_POLARITY_G='1', RST_ASYNC_G=false in its surf.Fifo instances) and has no
--   reset-polarity generic; the shared rst is forwarded as-is.  Keep the parent's
--   RST_POLARITY_G='1'/RST_ASYNC_G=false defaults for a consistent reset domain.
--
--   Open questions (out/04-vhdl/OPEN_QUESTIONS.md): OQ-EMIT-DMAARB-01.
--
--   NOTE: emitting does not prove equivalence — simulate this entity (cocotb)
--   against the BSV behaviour before trusting it.
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

library surf;
use surf.StdRtlPkg.all;

entity DmaArbiter4Qp is
   generic (
      TPD_G                  : time     := 1 ns;
      RST_POLARITY_G         : sl       := '1';    -- '1' for active-HIGH reset
      RST_ASYNC_G            : boolean  := false;
      DMA_READ_REQ_WIDTH_G   : positive := 176;    -- Bits#(DmaReadReq)
      DMA_READ_RESP_WIDTH_G  : positive := 383;    -- Bits#(DmaReadResp)
      DMA_WRITE_REQ_WIDTH_G  : positive := 419;    -- Bits#(DmaWriteReq)
      DMA_WRITE_RESP_WIDTH_G : positive := 53);    -- Bits#(DmaWriteResp)
   port (
      clk : in sl;
      rst : in sl := not RST_POLARITY_G;           -- FPGA async/sync reset

      -----------------------------------------------------------------------
      -- dmaReadClt : aggregated Client toward external DMA (= dmaReadProxy.cltPort)
      -----------------------------------------------------------------------
      dmaReadCltReqValid   : out sl;                                        -- request (put)
      dmaReadCltReqData    : out slv(DMA_READ_REQ_WIDTH_G-1 downto 0);      -- DmaReadReq
      dmaReadCltReqReady   : in  sl;
      dmaReadCltRespValid  : in  sl;                                        -- response (get)
      dmaReadCltRespData   : in  slv(DMA_READ_RESP_WIDTH_G-1 downto 0);     -- DmaReadResp
      dmaReadCltRespReady  : out sl;

      -----------------------------------------------------------------------
      -- dmaWriteClt : aggregated Client toward external DMA (= dmaWriteProxy.cltPort)
      -----------------------------------------------------------------------
      dmaWriteCltReqValid  : out sl;                                        -- request (put)
      dmaWriteCltReqData   : out slv(DMA_WRITE_REQ_WIDTH_G-1 downto 0);     -- DmaWriteReq
      dmaWriteCltReqReady   : in  sl;
      dmaWriteCltRespValid : in  sl;                                        -- response (get)
      dmaWriteCltRespData  : in  slv(DMA_WRITE_RESP_WIDTH_G-1 downto 0);    -- DmaWriteResp
      dmaWriteCltRespReady : out sl;

      -----------------------------------------------------------------------
      -- dmaReadSrv4RQ : Server for the RQ engine  (U_DmaReadArb port 0)
      -----------------------------------------------------------------------
      dmaReadSrv4RqReqValid   : in  sl;                                     -- request (put)
      dmaReadSrv4RqReqData    : in  slv(DMA_READ_REQ_WIDTH_G-1 downto 0);   -- DmaReadReq
      dmaReadSrv4RqReqReady   : out sl;
      dmaReadSrv4RqRespValid  : out sl;                                     -- response (get)
      dmaReadSrv4RqRespData   : out slv(DMA_READ_RESP_WIDTH_G-1 downto 0);  -- DmaReadResp
      dmaReadSrv4RqRespReady  : in  sl;

      -----------------------------------------------------------------------
      -- dmaWriteSrv4RQ : Server for the RQ engine (U_DmaWriteArb port 0)
      -----------------------------------------------------------------------
      dmaWriteSrv4RqReqValid  : in  sl;                                     -- request (put)
      dmaWriteSrv4RqReqData   : in  slv(DMA_WRITE_REQ_WIDTH_G-1 downto 0);  -- DmaWriteReq
      dmaWriteSrv4RqReqReady  : out sl;
      dmaWriteSrv4RqRespValid : out sl;                                     -- response (get)
      dmaWriteSrv4RqRespData  : out slv(DMA_WRITE_RESP_WIDTH_G-1 downto 0); -- DmaWriteResp
      dmaWriteSrv4RqRespReady : in  sl;

      -----------------------------------------------------------------------
      -- dmaReadSrv4SQ : Server for the SQ engine  (U_DmaReadArb port 1)
      -----------------------------------------------------------------------
      dmaReadSrv4SqReqValid   : in  sl;                                     -- request (put)
      dmaReadSrv4SqReqData    : in  slv(DMA_READ_REQ_WIDTH_G-1 downto 0);   -- DmaReadReq
      dmaReadSrv4SqReqReady   : out sl;
      dmaReadSrv4SqRespValid  : out sl;                                     -- response (get)
      dmaReadSrv4SqRespData   : out slv(DMA_READ_RESP_WIDTH_G-1 downto 0);  -- DmaReadResp
      dmaReadSrv4SqRespReady  : in  sl;

      -----------------------------------------------------------------------
      -- dmaWriteSrv4SQ : Server for the SQ engine (U_DmaWriteArb port 1)
      -----------------------------------------------------------------------
      dmaWriteSrv4SqReqValid  : in  sl;                                     -- request (put)
      dmaWriteSrv4SqReqData   : in  slv(DMA_WRITE_REQ_WIDTH_G-1 downto 0);  -- DmaWriteReq
      dmaWriteSrv4SqReqReady  : out sl;
      dmaWriteSrv4SqRespValid : out sl;                                     -- response (get)
      dmaWriteSrv4SqRespData  : out slv(DMA_WRITE_RESP_WIDTH_G-1 downto 0); -- DmaWriteResp
      dmaWriteSrv4SqRespReady : in  sl);
end entity DmaArbiter4Qp;

architecture rtl of DmaArbiter4Qp is

   -----------------------------------------------------------------------------
   -- Downstream srv <-> proxy srvPort nets (read direction)
   -----------------------------------------------------------------------------
   signal rdArbReqValid    : sl;                                    -- arb.srvReq -> proxy.srvReq
   signal rdArbReqData     : slv(DMA_READ_REQ_WIDTH_G-1 downto 0);
   signal rdProxyReqReady  : sl;                                    -- proxy.srvReqReady -> arb
   signal rdProxyRespValid : sl;                                    -- proxy.srvResp -> arb.srvResp
   signal rdProxyRespData  : slv(DMA_READ_RESP_WIDTH_G-1 downto 0);
   signal rdArbRespRd      : sl;                                    -- arb.srvRespRd -> proxy.srvRespReady
   signal rdSrvRespFinished : sl;                                   -- isDmaReadRespLastFrag = resp.dataStream.isLast

   -----------------------------------------------------------------------------
   -- Downstream srv <-> proxy srvPort nets (write direction)
   -----------------------------------------------------------------------------
   signal wrArbReqValid    : sl;
   signal wrArbReqData     : slv(DMA_WRITE_REQ_WIDTH_G-1 downto 0);
   signal wrProxyReqReady  : sl;
   signal wrProxyRespValid : sl;
   signal wrProxyRespData  : slv(DMA_WRITE_RESP_WIDTH_G-1 downto 0);
   signal wrArbRespRd      : sl;

begin

   -----------------------------------------------------------------------------
   -- Non-constant "finished" predicates (OQ-FSM-17).  isLast = bit 0 of the
   -- struct-packed payload (dataStream is the low field; isLast its low bit).
   -----------------------------------------------------------------------------
   rdSrvRespFinished <= rdProxyRespData(0);   -- DmaReadResp.dataStream.isLast

   -----------------------------------------------------------------------------
   -- READ direction
   -----------------------------------------------------------------------------
   -- U_DmaReadArb : dmaReadSrvVec <- mkServerArbiter(dmaReadProxy.srvPort, ...)
   --   Two upstream Server faces (RQ=port0, SQ=port1) arbitrated onto the read
   --   proxy's srvPort.  Both request predicates tie '1' (isDmaReadReqLastFrag
   --   = True); the response predicate is resp.dataStream.isLast.
   U_DmaReadArb : entity surf.ServerArbiter
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         PORT_COUNT_G      => 2,
         REQ_WIDTH_G       => DMA_READ_REQ_WIDTH_G,
         RESP_WIDTH_G      => DMA_READ_RESP_WIDTH_G,
         MEMORY_TYPE_G     => "distributed",
         FIFO_ADDR_WIDTH_G => 4)
      port map (
         clk             => clk,
         rst             => rst,
         -- port 0 = RQ
         req0Valid       => dmaReadSrv4RqReqValid,
         req0Data        => dmaReadSrv4RqReqData,
         req0Finished    => '1',                     -- isDmaReadReqLastFrag = True
         req0Ready       => dmaReadSrv4RqReqReady,
         resp0Valid      => dmaReadSrv4RqRespValid,
         resp0Data       => dmaReadSrv4RqRespData,
         resp0Rd         => dmaReadSrv4RqRespReady,
         -- port 1 = SQ
         req1Valid       => dmaReadSrv4SqReqValid,
         req1Data        => dmaReadSrv4SqReqData,
         req1Finished    => '1',                     -- isDmaReadReqLastFrag = True
         req1Ready       => dmaReadSrv4SqReqReady,
         resp1Valid      => dmaReadSrv4SqRespValid,
         resp1Data       => dmaReadSrv4SqRespData,
         resp1Rd         => dmaReadSrv4SqRespReady,
         -- downstream shared srv <-> U_DmaReadProxy.srvPort
         srvReqValid     => rdArbReqValid,
         srvReqData      => rdArbReqData,
         srvReqReady     => rdProxyReqReady,
         srvRespValid    => rdProxyRespValid,
         srvRespData     => rdProxyRespData,
         srvRespFinished => rdSrvRespFinished,
         srvRespRd       => rdArbRespRd);

   -- U_DmaReadProxy : dmaReadProxy <- mkServerProxy
   --   srvPort <-> read arbiter's downstream srv; cltPort -> external dmaReadClt.
   U_DmaReadProxy : entity surf.ServerProxy
      generic map (
         TPD_G        => TPD_G,
         REQ_WIDTH_G  => DMA_READ_REQ_WIDTH_G,
         RESP_WIDTH_G => DMA_READ_RESP_WIDTH_G)
      port map (
         clk          => clk,
         rst          => rst,
         -- srvPort <-> U_DmaReadArb downstream srv
         srvReqValid  => rdArbReqValid,
         srvReqData   => rdArbReqData,
         srvReqReady  => rdProxyReqReady,
         srvRespValid => rdProxyRespValid,
         srvRespData  => rdProxyRespData,
         srvRespReady => rdArbRespRd,
         -- cltPort -> dmaReadClt boundary
         cltReqValid  => dmaReadCltReqValid,
         cltReqData   => dmaReadCltReqData,
         cltReqReady  => dmaReadCltReqReady,
         cltRespValid => dmaReadCltRespValid,
         cltRespData  => dmaReadCltRespData,
         cltRespReady => dmaReadCltRespReady);

   -----------------------------------------------------------------------------
   -- WRITE direction
   -----------------------------------------------------------------------------
   -- U_DmaWriteArb : dmaWriteSrvVec <- mkServerArbiter(dmaWriteProxy.srvPort, ...)
   --   Request predicate = req.dataStream.isLast (bit 0 of each port's reqData);
   --   response predicate ties '1' (isDmaWriteRespLastFrag = True).
   U_DmaWriteArb : entity surf.ServerArbiter
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         PORT_COUNT_G      => 2,
         REQ_WIDTH_G       => DMA_WRITE_REQ_WIDTH_G,
         RESP_WIDTH_G      => DMA_WRITE_RESP_WIDTH_G,
         MEMORY_TYPE_G     => "distributed",
         FIFO_ADDR_WIDTH_G => 4)
      port map (
         clk             => clk,
         rst             => rst,
         -- port 0 = RQ
         req0Valid       => dmaWriteSrv4RqReqValid,
         req0Data        => dmaWriteSrv4RqReqData,
         req0Finished    => dmaWriteSrv4RqReqData(0),  -- isDmaWriteReqLastFrag = req.dataStream.isLast
         req0Ready       => dmaWriteSrv4RqReqReady,
         resp0Valid      => dmaWriteSrv4RqRespValid,
         resp0Data       => dmaWriteSrv4RqRespData,
         resp0Rd         => dmaWriteSrv4RqRespReady,
         -- port 1 = SQ
         req1Valid       => dmaWriteSrv4SqReqValid,
         req1Data        => dmaWriteSrv4SqReqData,
         req1Finished    => dmaWriteSrv4SqReqData(0),  -- isDmaWriteReqLastFrag = req.dataStream.isLast
         req1Ready       => dmaWriteSrv4SqReqReady,
         resp1Valid      => dmaWriteSrv4SqRespValid,
         resp1Data       => dmaWriteSrv4SqRespData,
         resp1Rd         => dmaWriteSrv4SqRespReady,
         -- downstream shared srv <-> U_DmaWriteProxy.srvPort
         srvReqValid     => wrArbReqValid,
         srvReqData      => wrArbReqData,
         srvReqReady     => wrProxyReqReady,
         srvRespValid    => wrProxyRespValid,
         srvRespData     => wrProxyRespData,
         srvRespFinished => '1',                       -- isDmaWriteRespLastFrag = True
         srvRespRd       => wrArbRespRd);

   -- U_DmaWriteProxy : dmaWriteProxy <- mkServerProxy
   U_DmaWriteProxy : entity surf.ServerProxy
      generic map (
         TPD_G        => TPD_G,
         REQ_WIDTH_G  => DMA_WRITE_REQ_WIDTH_G,
         RESP_WIDTH_G => DMA_WRITE_RESP_WIDTH_G)
      port map (
         clk          => clk,
         rst          => rst,
         -- srvPort <-> U_DmaWriteArb downstream srv
         srvReqValid  => wrArbReqValid,
         srvReqData   => wrArbReqData,
         srvReqReady  => wrProxyReqReady,
         srvRespValid => wrProxyRespValid,
         srvRespData  => wrProxyRespData,
         srvRespReady => wrArbRespRd,
         -- cltPort -> dmaWriteClt boundary
         cltReqValid  => dmaWriteCltReqValid,
         cltReqData   => dmaWriteCltReqData,
         cltReqReady  => dmaWriteCltReqReady,
         cltRespValid => dmaWriteCltRespValid,
         cltRespData  => dmaWriteCltRespData,
         cltRespReady => dmaWriteCltRespReady);

end architecture rtl;
