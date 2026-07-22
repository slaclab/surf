-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Pure structural wiring entity: wires three child entities
--   (DmaReadCntrlGen -> PayloadGeneratorGen -> SendQ, BSV module-parameter
--   chain) and two DMA-read FIFOs (the dmaReadClt boundary) together. The only
--   local sequential behavior is a one-cycle clearReg pulse (BSV rule
--   resetAndClear), broadcast as `clear` to all three children's clear input.
--
--   Module-parameter chaining (all BSV constructor args, NOT method calls):
--     dmaReadSrv = toGPServer(dmaReadReqQ, dmaReadRespQ)        -- U_DmaReadCntrl's external server
--     dmaReadCntrl      <- mkDmaReadCntrl(clearReg, dmaReadSrv)  -- U_DmaReadCntrl
--     payloadGenerator  <- mkPayloadGenerator(clearReg, dmaReadCntrl) -- U_PayloadGenerator
--     sq                <- mkSendQ(clearReg, payloadGenerator)   -- U_SendQ
--
--   U_DmaReadCntrl.cancelEn is never driven at this level: mkSQ does not call
--   dmaReadCntrl.cancel() (grep-verified against PayloadGen.bsv/SendQ.bsv), and
--   SQ's top-level interface exposes no cancel method. Tied to '0' (judgment
--   call, see out/04-vhdl/OPEN_QUESTIONS.md OQ-EMIT-SQSQ-01).
--   U_DmaReadCntrl.isIdle and U_PayloadGenerator.payloadNotEmpty are likewise
--   never read by mkPayloadGenerator/mkSendQ (grep-verified) and are not part
--   of the SQ interface; left open, mirroring DmaReadCntrlGen.vhd's own
--   U_AddrChunkSrv.isIdle => open precedent.
--
--   SQ interface (BSV) -> ports:
--     dmaReadClt (Client#(DmaReadReq,DmaReadResp), via toGPClient(dmaReadReqQ,
--       dmaReadRespQ)): request is a Get (external side dequeues the FIFO) ->
--       dmaReadReq{Valid,Data,RdEn}; response is a Put (external side enqueues
--       the FIFO) -> dmaReadResp{Valid,Data,Ready}.
--     sendQ (SendQ interface, re-exported straight from U_SendQ): srvPort ->
--       wqeReq{Valid,Data,Ready} / sendResp{Valid,Data,Ready}; udpInfoPipeOut ->
--       udpInfo{Valid,Data,RdEn}; rdmaDataStreamPipeOut -> rdmaData{Valid,Data,
--       RdEn}; isEmpty -> isEmpty (fsm.md's Notes section omitted this method;
--       it is a real part of the SQ.sendQ sub-interface so it is exposed here,
--       see OQ-EMIT-SQSQ-02).
--     clearAll() Action method -> clearAllEn (in) / clearAllReady (out, =
--       !clearReg, the method's implicit condition).
--
--   SURF components instantiated (source: surf/base/fifo/rtl/Fifo.vhd):
--     U_DmaReadReqQ  : surf.Fifo DATA_WIDTH_G=176 (DmaReadReq)
--     U_DmaReadRespQ : surf.Fifo DATA_WIDTH_G=383 (DmaReadResp)
--   Both are pure plumbing between U_DmaReadCntrl and the external dmaReadClt
--   port (not driven by the local clearReg FSM; their rst is the global reset
--   only per fsm.md, since the BSV resetAndClear rule body has no .clear()).
--
--   Child entities instantiated (out/04-vhdl/):
--     U_DmaReadCntrl    : DmaReadCntrlGen    (from mkDmaReadCntrl_Gen)
--     U_PayloadGenerator: PayloadGeneratorGen (from mkPayloadGenerator_Gen)
--     U_SendQ           : SendQ              (from mkSendQ)
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

entity SqSendQ is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk : in sl;
      rst : in sl;                                    -- active-high synchronous reset

      -- clearAll() Action method (guard !clearReg)
      clearAllEn    : in  sl;
      clearAllReady : out sl;                          -- = not clearReg (implicit condition)

      -- sendQ.srvPort : Server#(WorkQueueElem, SendResp)  (re-exported from U_SendQ)
      wqeReqValid  : in  sl;
      wqeReqData   : in  slv(1720 downto 0);           -- WorkQueueElem packed
      wqeReqReady  : out sl;
      sendRespValid : out sl;
      sendRespData  : out slv(0 downto 0);             -- SendResp (0-width -> 1-bit token)
      sendRespReady : in  sl;

      -- sendQ.udpInfoPipeOut : PipeOut#(PktInfo4UDP)  (re-exported from U_SendQ)
      udpInfoValid : out sl;
      udpInfoData  : out slv(190 downto 0);
      udpInfoRdEn  : in  sl;

      -- sendQ.rdmaDataStreamPipeOut : DataStreamPipeOut  (re-exported from U_SendQ)
      rdmaDataValid : out sl;
      rdmaDataData  : out slv(289 downto 0);
      rdmaDataRdEn  : in  sl;

      -- sendQ.isEmpty() method result (re-exported from U_SendQ)
      isEmpty : out sl;

      -- dmaReadClt : Client#(DmaReadReq, DmaReadResp)  (via toGPClient(U_DmaReadReqQ, U_DmaReadRespQ))
      -- request side is a Get: external consumer dequeues U_DmaReadReqQ
      dmaReadReqValid : out sl;
      dmaReadReqData  : out slv(175 downto 0);         -- DmaReadReq packed
      dmaReadReqRdEn  : in  sl;
      -- response side is a Put: external producer enqueues U_DmaReadRespQ
      dmaReadRespValid : in  sl;
      dmaReadRespData  : in  slv(382 downto 0);        -- DmaReadResp packed
      dmaReadRespReady : out sl);
end entity SqSendQ;

architecture rtl of SqSendQ is

   -- Local FSM state: the entire clearReg pulse (mkReg(False))
   type RegType is record
      clearReg : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      clearReg => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Registered clear broadcast to all three children (Moore; fsm.md §Output style)
   signal clear : sl;

   -- U_DmaReadReqQ (DmaReadReq, 176b): wr = U_DmaReadCntrl (client Put), rd = external dmaReadClt.request (Get)
   signal dmaReadReqQWrEn   : sl;
   signal dmaReadReqQDin    : slv(175 downto 0);
   signal dmaReadReqQNotFull : sl;
   signal dmaReadReqQValid  : sl;
   signal dmaReadReqQDout   : slv(175 downto 0);

   -- U_DmaReadRespQ (DmaReadResp, 383b): wr = external dmaReadClt.response (Put), rd = U_DmaReadCntrl (client Get)
   signal dmaReadRespQNotFull : sl;
   signal dmaReadRespQValid   : sl;
   signal dmaReadRespQDout    : slv(382 downto 0);
   signal dmaReadRespQRdEn    : sl;

   -- U_DmaReadCntrl <-> U_PayloadGenerator (dmaReadCntrl module parameter)
   signal dmaCntrlReqValid   : sl;
   signal dmaCntrlReqData    : slv(1162 downto 0);
   signal dmaCntrlReqReady   : sl;
   signal dmaCntrlRespValid  : sl;
   signal dmaCntrlRespData   : slv(384 downto 0);
   signal dmaCntrlRespReady  : sl;
   signal sgePktMetaValid    : sl;
   signal sgePktMetaData     : slv(53 downto 0);
   signal sgePktMetaRdEn     : sl;
   signal sgeMergedValid     : sl;
   signal sgeMergedData      : slv(7 downto 0);
   signal sgeMergedRdEn      : sl;

   -- U_PayloadGenerator <-> U_SendQ (payloadGenerator module parameter)
   signal payloadGenReqValid  : sl;
   signal payloadGenReqData   : slv(1227 downto 0);
   signal payloadGenReqReady  : sl;
   signal payloadGenRespValid : sl;
   signal payloadGenRespData  : slv(80 downto 0);
   signal payloadGenRespReady : sl;
   signal payloadTotalMetaValid : sl;
   signal payloadTotalMetaData  : slv(26 downto 0);
   signal payloadTotalMetaRdEn  : sl;
   signal payloadDataStreamValid : sl;
   signal payloadDataStreamData  : slv(289 downto 0);
   signal payloadDataStreamRdEn  : sl;

begin

   -- clearAll() method's implicit condition (combinational from r, not v)
   clearAllReady <= not r.clearReg;

   -- Registered clear broadcast (Moore) to all three children's clear input
   clear <= r.clearReg;

   ---------------------------------------------------------------------------
   -- U_DmaReadReqQ : surf.Fifo
   --   Plumbing between U_DmaReadCntrl (producer) and the external dmaReadClt
   --   request Get (consumer). NOT cleared by clearReg (fsm.md: rule body has
   --   no .clear()); rst is the global reset only.
   ---------------------------------------------------------------------------
   U_DmaReadReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 176,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => rst,
         wr_clk   => clk,
         wr_en    => dmaReadReqQWrEn,        -- U_DmaReadCntrl client Put
         din      => dmaReadReqQDin,
         not_full => dmaReadReqQNotFull,
         rd_clk   => clk,
         rd_en    => dmaReadReqRdEn,         -- external dmaReadClt.request Get
         dout     => dmaReadReqQDout,
         valid    => dmaReadReqQValid);

   dmaReadReqValid <= dmaReadReqQValid;
   dmaReadReqData  <= dmaReadReqQDout;

   ---------------------------------------------------------------------------
   -- U_DmaReadRespQ : surf.Fifo
   --   Plumbing between the external dmaReadClt response Put (producer) and
   --   U_DmaReadCntrl (consumer). NOT cleared by clearReg; rst is the global
   --   reset only.
   ---------------------------------------------------------------------------
   U_DmaReadRespQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 383,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => rst,
         wr_clk   => clk,
         wr_en    => dmaReadRespValid,       -- external dmaReadClt.response Put
         din      => dmaReadRespData,
         not_full => dmaReadRespQNotFull,
         rd_clk   => clk,
         rd_en    => dmaReadRespQRdEn,       -- U_DmaReadCntrl client Get
         dout     => dmaReadRespQDout,
         valid    => dmaReadRespQValid);

   dmaReadRespReady <= dmaReadRespQNotFull;

   ---------------------------------------------------------------------------
   -- U_DmaReadCntrl : DmaReadCntrlGen (child entity, not SURF)
   --   BSV: dmaReadCntrl <- mkDmaReadCntrl(clearReg, dmaReadSrv). clearAll port
   --   takes the registered clearReg broadcast. cancelEn tied '0' (never called
   --   at this level, OQ-EMIT-SQSQ-01); isIdle left open (never read).
   ---------------------------------------------------------------------------
   U_DmaReadCntrl : entity surf.DmaReadCntrlGen
      generic map (
         TPD_G => TPD_G)
      port map (
         clk          => clk,
         rst          => rst,
         clearAll     => clear,
         cancelEn     => '0',
         reqInValid   => dmaCntrlReqValid,       -- from U_PayloadGenerator
         reqInData    => dmaCntrlReqData,
         reqInReady   => dmaCntrlReqReady,
         respOutReady => dmaCntrlRespReady,      -- from U_PayloadGenerator
         respOutValid => dmaCntrlRespValid,
         respOutData  => dmaCntrlRespData,
         sgeMergedRdEn  => sgeMergedRdEn,        -- from U_PayloadGenerator
         sgeMergedValid => sgeMergedValid,
         sgeMergedData  => sgeMergedData,
         sgePktMetaRdEn  => sgePktMetaRdEn,      -- from U_PayloadGenerator
         sgePktMetaValid => sgePktMetaValid,
         sgePktMetaData  => sgePktMetaData,
         dmaReqValid  => dmaReadReqQWrEn,        -- to U_DmaReadReqQ
         dmaReqOut    => dmaReadReqQDin,
         dmaReqReady  => dmaReadReqQNotFull,
         dmaRespValid => dmaReadRespQValid,      -- from U_DmaReadRespQ
         dmaRespIn    => dmaReadRespQDout,
         dmaRespReady => dmaReadRespQRdEn,
         isIdle       => open);

   ---------------------------------------------------------------------------
   -- U_PayloadGenerator : PayloadGeneratorGen (child entity, not SURF)
   --   BSV: payloadGenerator <- mkPayloadGenerator(clearReg, dmaReadCntrl).
   --   clearAllI port takes the registered clearReg broadcast. dmaReadCntrl
   --   module parameter fully wired to U_DmaReadCntrl above. payloadNotEmpty
   --   left open (never read by mkSendQ, OQ-EMIT-SQSQ-01).
   ---------------------------------------------------------------------------
   U_PayloadGenerator : entity surf.PayloadGeneratorGen
      generic map (
         TPD_G => TPD_G)
      port map (
         clk       => clk,
         rst       => rst,
         clearAllI => clear,
         reqInValid   => payloadGenReqValid,     -- from U_SendQ
         reqInData    => payloadGenReqData,
         reqInReady   => payloadGenReqReady,
         respOutReady => payloadGenRespReady,    -- from U_SendQ
         respOutValid => payloadGenRespValid,
         respOutData  => payloadGenRespData,
         totalMetaDataDeq      => payloadTotalMetaRdEn,   -- from U_SendQ
         totalMetaDataFirst    => payloadTotalMetaData,
         totalMetaDataNotEmpty => payloadTotalMetaValid,
         payloadDataStreamDeq      => payloadDataStreamRdEn,  -- from U_SendQ
         payloadDataStreamFirst    => payloadDataStreamData,
         payloadDataStreamNotEmpty => payloadDataStreamValid,
         payloadNotEmpty => open,
         dmaReadCntrlReqValid  => dmaCntrlReqValid,   -- to U_DmaReadCntrl
         dmaReadCntrlReqData   => dmaCntrlReqData,
         dmaReadCntrlReqReady  => dmaCntrlReqReady,
         dmaReadCntrlRespValid => dmaCntrlRespValid,  -- from U_DmaReadCntrl
         dmaReadCntrlRespData  => dmaCntrlRespData,
         dmaReadCntrlRespReady => dmaCntrlRespReady,
         sgePktMetaValid => sgePktMetaValid,          -- from U_DmaReadCntrl
         sgePktMetaData  => sgePktMetaData,
         sgePktMetaRdEn  => sgePktMetaRdEn,
         sgeMergedMetaValid => sgeMergedValid,        -- from U_DmaReadCntrl
         sgeMergedMetaData  => sgeMergedData,
         sgeMergedMetaRdEn  => sgeMergedRdEn);

   ---------------------------------------------------------------------------
   -- U_SendQ : SendQ (child entity, not SURF)
   --   BSV: sq <- mkSendQ(clearReg, payloadGenerator). clearAllI port takes the
   --   registered clearReg broadcast. payloadGenerator module parameter fully
   --   wired to U_PayloadGenerator above. srvPort/udpInfoPipeOut/
   --   rdmaDataStreamPipeOut/isEmpty are re-exported straight to this entity's
   --   top-level ports.
   ---------------------------------------------------------------------------
   U_SendQ : entity surf.SendQ
      generic map (
         TPD_G => TPD_G)
      port map (
         clk         => clk,
         rst         => rst,
         clearAllI   => clear,
         reqReqValid => wqeReqValid,           -- re-export: srvPort.request
         reqReqData  => wqeReqData,
         reqReqReady => wqeReqReady,
         respValid   => sendRespValid,         -- re-export: srvPort.response
         respData    => sendRespData,
         respReady   => sendRespReady,
         udpInfoValid => udpInfoValid,         -- re-export: udpInfoPipeOut
         udpInfoData  => udpInfoData,
         udpInfoRdEn  => udpInfoRdEn,
         rdmaDataValid => rdmaDataValid,       -- re-export: rdmaDataStreamPipeOut
         rdmaDataData  => rdmaDataData,
         rdmaDataRdEn  => rdmaDataRdEn,
         payloadGenReqValid  => payloadGenReqValid,   -- to U_PayloadGenerator
         payloadGenReqData   => payloadGenReqData,
         payloadGenReqReady  => payloadGenReqReady,
         payloadGenRespValid => payloadGenRespValid,  -- from U_PayloadGenerator
         payloadGenRespData  => payloadGenRespData,
         payloadGenRespReady => payloadGenRespReady,
         payloadTotalMetaValid => payloadTotalMetaValid,  -- from U_PayloadGenerator
         payloadTotalMetaData  => payloadTotalMetaData,
         payloadTotalMetaRdEn  => payloadTotalMetaRdEn,
         payloadDataStreamValid => payloadDataStreamValid, -- from U_PayloadGenerator
         payloadDataStreamData  => payloadDataStreamData,
         payloadDataStreamRdEn  => payloadDataStreamRdEn,
         isEmpty => isEmpty);                  -- re-export: sendQ.isEmpty()

   ---------------------------------------------------------------------------
   -- Combinatorial process: the entire local FSM is the clearReg pulse.
   ---------------------------------------------------------------------------
   comb : process (r, rst, clearAllEn) is
      variable v : RegType;
   begin
      v := r;

      -- resetAndClear (fire_when_enabled, no_implicit_conditions) dominates;
      -- clearAll() method write is mutually exclusive by guard (fsm.md
      -- §Conflicts/scheduling) so the if/elsif order is redundant-safe.
      if r.clearReg = '1' then
         v.clearReg := '0';                    -- rule resetAndClear
      elsif clearAllEn = '1' then
         v.clearReg := '1';                    -- clearAll() method (guard !clearReg)
      end if;

      -- Synchronous reset (matches BSV mkReg(False))
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
