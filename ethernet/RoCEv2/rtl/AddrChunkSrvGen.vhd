-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   AddrChunkSrv interface:
--     srvPort               : Server#(AddrChunkReq, AddrChunkResp)
--     sgePktMetaDataPipeOut : PipeOut#(PktMetaDataSGE)
--     isIdle()              : combinational status method
--
--   This is the "Gen" variant: a 4-stage FIFO-decoupled pipeline that takes ONE
--   AddrChunkReq per SGE (already tagged isFirst/isLast by the parent
--   mkDmaReadCntrl) and explodes it into PMTU-sized address chunks, tagging each
--   emitted chunk with the original SGE's first/last flags (isOrigFirst/
--   isOrigLast) and producing a side-channel PktMetaDataSGE stream.
--
--   This entity does NOT iterate over scatter-gather entries — that loop lives in
--   the parent (OQ-FSM-ACSG-01).  reqQ's depth-8 sizing (mkSizedFIFOF(MAX_SGE=8))
--   is just buffering, not internal SGE iteration.
--
--   Pipeline (all four stages decoupled; disjoint FIFO pairs, can co-fire):
--     Stage A recvReq          reqQ                -> calcChunkMetaDataQ
--     Stage B calcChunkMetaData calcChunkMetaDataQ -> calcPktMetaDataQ4SGE
--     Stage C genPktMetaDataSGE calcPktMetaDataQ4SGE
--                              -> sgePktMetaDataOutQ + calcAddrChunkRespQ
--     Stage D genResp          calcAddrChunkRespQ  -> respQ   (the real FSM)
--   Stages A/B/C are stateless pass-throughs; only stage D carries control state
--   (isFirstChunkReg) because it replays one calcAddrChunkRespQ entry across
--   multiple cycles, emitting one chunk response per cycle (peek; deq only on the
--   last chunk).
--
--   Mapping note (OQ-FSM-ACSG-01, see fsm.md §mismatch):
--     mapping.json / modules.json record fabricated rules
--     (recvSglReq/genSgeChunk/lastSge) and state (sgeIdxReg/addrReg/lenReg/
--     stateReg), miss the sgePktMetaDataPipeOut output, and list only 2 of the 6
--     FIFOs.  This file and the FSM spec are authoritative.
--
--   isIdle() (OQ-FSM-ACSG-02): no consumer at the only instantiation site, but
--     kept anyway — purely combinational, cheap, useful for verification.
--
--   FIFO clear (OQ-FSM-01 carry-forward, RESOLVED): BSV resetAndClear (guard
--     clearAll) calls .clear on ALL SIX FIFOs in one cycle.  Modelled by asserting
--     each Fifo's rst, OR'd with the structural reset:  fifoRst = rst OR clearAllI.
--     surf.FifoSync holds logically empty for the whole asserted window
--     (level-safe); no pulse generator.  Requires GEN_SYNC_FIFO_G=true,
--     RST_ASYNC_G=false, RST_POLARITY_G='1'.
--
--   SURF components instantiated (all surf.Fifo, FWFT, sync, distributed RAM;
--   source: surf/base/fifo/rtl/Fifo.vhd):
--     U_ReqQ                 DATA_WIDTH_G=101 depth 16 (AddrChunkReq;   MAX_SGE buf)
--     U_RespQ                DATA_WIDTH_G=81             (AddrChunkResp)
--     U_SgePktMetaDataOutQ   DATA_WIDTH_G=54             (PktMetaDataSGE)
--     U_CalcChunkMetaDataQ   DATA_WIDTH_G=255 (internal pipeline handoff, Stage A->B)
--     U_CalcPktMetaDataQ4SGE DATA_WIDTH_G=215 (internal pipeline handoff, Stage B->C)
--     U_CalcAddrChunkRespQ   DATA_WIDTH_G=197 (internal pipeline handoff, Stage C->D)
--     Distributed-RAM FWFT cold latency is 1 cycle (block RAM was 2) — see tb-spec §8.
--
--   Struct bit layouts (BSV deriving(Bits), first-field-at-MSB, OQ-FSM-H2DS-04):
--
--   AddrChunkReq (101 bits):
--     [100:37] startAddr[63:0]   [36:5] len[31:0]   [4:2] pmtu[2:0]
--     [1] isFirst   [0] isLast
--
--   AddrChunkResp (81 bits):
--     [80:17] chunkAddr[63:0]   [16:4] chunkLen[12:0]   [3] isFirst   [2] isLast
--     [1] isOrigFirst   [0] isOrigLast
--
--   PktMetaDataSGE (54 bits):
--     [53:41] firstPktLen[12:0]   [40:28] lastPktLen[12:0]
--     [27:3] sgePktNum[24:0]      [2:0] pmtu[2:0]
--
--   calcChunkMetaDataQ element (255 bits, internal):
--     [254:242] pmtuMask  [241:229] addrAndLenLowPartSum  [228:216] pmtuLen
--     [215:203] lenLowPart  [202:190] maxFirstPktLen  [189:165] truncatedPktNum
--     [164:101] pmtuAlignedStartAddr  [100:0] addrChunkReq
--
--   calcPktMetaDataQ4SGE element (TmpPktMetaDataSGE, 215 bits, internal):
--     [214:213] pktNumAddOne  [212:188] truncatedPktNum  [187:175] lenLowPart
--     [174:162] maxFirstPktLen  [161:149] tmpLastPktLen  [148:136] pmtuLen
--     [135:133] pmtu  [132:69] startAddr  [68:5] nextAddr  [4] notFullPkt
--     [3] hasExtraPkt  [2] hasResidue  [1] isOrigFirst  [0] isOrigLast
--
--   calcAddrChunkRespQ element (TmpChunkRespData, 197 bits, internal):
--     [196:172] sgePktNum  [171:159] firstPktLen  [158:146] pmtuLen
--     [145:133] lastPktLen  [132:130] pmtu  [129:66] startAddr  [65:2] nextAddr
--     [1] isOrigFirst  [0] isOrigLast
--
--   PMTU enum (DataTypes.bsv:407-413): IBV_MTU_256=1 .. IBV_MTU_4096=5.
--   k = log2(pmtuLen) = pmtu+7 ∈ {8,9,10,11,12};  pmtuLen = 2**k.
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

entity AddrChunkSrvGen is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk             : in  sl;
      rst             : in  sl;         -- active-high synchronous reset
      -- Software clear (synchronous; LEVEL-asserted while high)
      clearAllI       : in  sl;
      -- srvPort.request : Put#(AddrChunkReq)  (caller -> entity)
      reqPutValid     : in  sl;         -- caller offers a request (wr_en)
      reqPutData      : in  slv(100 downto 0);  -- AddrChunkReq packed
      reqPutReady     : out sl;         -- entity can accept (reqQ.notFull)
      -- srvPort.response : Get#(AddrChunkResp)  (entity -> caller)
      respGetReady    : in  sl;         -- caller takes a response (rd_en)
      respGetValid    : out sl;         -- response available (respQ.notEmpty)
      respGetData     : out slv(80 downto 0);   -- AddrChunkResp packed
      -- sgePktMetaDataPipeOut : PipeOut#(PktMetaDataSGE)  (entity -> caller)
      sgePktMetaRdEn  : in  sl;         -- caller deq
      sgePktMetaValid : out sl;         -- data available
      sgePktMetaData  : out slv(53 downto 0);   -- PktMetaDataSGE packed
      -- status method
      isIdle          : out sl);        -- all six FIFOs empty
end entity AddrChunkSrvGen;

architecture rtl of AddrChunkSrvGen is

   -- genResp control state (maps BSV isFirstChunkReg:
   --   True  -> NEWCHUNK_S  (ready to start a fresh calcAddrChunkRespQ entry)
   --   False -> CONTCHUNK_S (mid-entry, replaying further chunks))
   type StateType is (NEWCHUNK_S, CONTCHUNK_S);

   type RegType is record
      state              : StateType;   -- isFirstChunkReg (mkReg(True))
      remainingPktNumReg : slv(24 downto 0);  -- mkRegU — chunks left for in-flight entry
      nextChunkAddrReg   : slv(63 downto 0);  -- mkRegU — address of chunk about to emit
   end record RegType;

   -- isFirstChunkReg resets to '1' (NEWCHUNK_S), matching BSV mkReg(True).
   -- The two mkRegU fields are set to '0': on the first-ever genResp firing,
   -- state=NEWCHUNK_S forces the override branch (remaining:=sgePktNum,
   -- nextChunkAddr:=nextAddr, chunkAddr:=startAddr) strictly before either is
   -- read, so the reset value is never observed (fsm.md §Reset behavior).
   constant REG_INIT_C : RegType := (
      state              => NEWCHUNK_S,
      remainingPktNumReg => (others => '0'),
      nextChunkAddrReg   => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- FIFO reset line: level = rst OR clearAllI (drives all six U_*Q.rst)
   signal fifoRst : sl;

   -- U_ReqQ
   signal reqQFull  : sl;
   signal reqQValid : sl;
   signal reqQDout  : slv(100 downto 0);
   signal reqQRdEn  : sl;

   -- U_RespQ
   signal respQFull  : sl;
   signal respQValid : sl;
   signal respQWrEn  : sl;
   signal respQDin   : slv(80 downto 0);

   -- U_SgePktMetaDataOutQ
   signal sgeQFull  : sl;
   signal sgeQValid : sl;
   signal sgeQWrEn  : sl;
   signal sgeQDin   : slv(53 downto 0);

   -- U_CalcChunkMetaDataQ (Stage A -> B, internal)
   signal ccmdQFull  : sl;
   signal ccmdQValid : sl;
   signal ccmdQDout  : slv(254 downto 0);
   signal ccmdQWrEn  : sl;
   signal ccmdQDin   : slv(254 downto 0);
   signal ccmdQRdEn  : sl;

   -- U_CalcPktMetaDataQ4SGE (Stage B -> C, internal)
   signal cpmdQFull  : sl;
   signal cpmdQValid : sl;
   signal cpmdQDout  : slv(214 downto 0);
   signal cpmdQWrEn  : sl;
   signal cpmdQDin   : slv(214 downto 0);
   signal cpmdQRdEn  : sl;

   -- U_CalcAddrChunkRespQ (Stage C -> D, internal)
   signal cacrQFull  : sl;
   signal cacrQValid : sl;
   signal cacrQDout  : slv(196 downto 0);
   signal cacrQWrEn  : sl;
   signal cacrQDin   : slv(196 downto 0);
   signal cacrQRdEn  : sl;

begin

   -- FIFO reset: level-sensitive clear (OQ-FSM-01 carry-forward, all six FIFOs)
   fifoRst <= rst or clearAllI;

   -- Boundary pass-throughs (not FSM-gated)
   reqPutReady     <= not reqQFull;     -- reqQ.notFull readiness to caller
   respGetValid    <= respQValid;       -- respQ.notEmpty
   sgePktMetaValid <= sgeQValid;        -- sgePktMetaDataOutQ.notEmpty

   -- isIdle() method: !(any of the six FIFOs notEmpty)  (PayloadGen.bsv:652-659)
   isIdle <= '1' when (reqQValid = '0' and respQValid = '0' and ccmdQValid = '0' and
                       cpmdQValid = '0' and cacrQValid = '0' and sgeQValid = '0') else
             '0';

   ---------------------------------------------------------------------------
   -- U_ReqQ : surf.Fifo  (AddrChunkReq inbound; depth MAX_SGE=8 -> ADDR_WIDTH 4)
   --   wr side = caller srvPort.request.put (pass-through); rd side = recvReq.
   ---------------------------------------------------------------------------
   U_ReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 101,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => reqPutValid,  -- pass-through (caller drives)
         din           => reqPutData,   -- pass-through (caller drives)
         full          => reqQFull,
         not_full      => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => reqQRdEn,     -- Stage A (recvReq)
         dout          => reqQDout,
         valid         => reqQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_CalcChunkMetaDataQ : surf.Fifo  (Stage A -> Stage B, internal handoff)
   ---------------------------------------------------------------------------
   U_CalcChunkMetaDataQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 255,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => ccmdQWrEn,    -- Stage A
         din           => ccmdQDin,     -- Stage A
         full          => ccmdQFull,
         not_full      => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => ccmdQRdEn,    -- Stage B
         dout          => ccmdQDout,
         valid         => ccmdQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_CalcPktMetaDataQ4SGE : surf.Fifo  (Stage B -> Stage C, internal handoff)
   ---------------------------------------------------------------------------
   U_CalcPktMetaDataQ4SGE : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 215,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => cpmdQWrEn,    -- Stage B
         din           => cpmdQDin,     -- Stage B
         full          => cpmdQFull,
         not_full      => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => cpmdQRdEn,    -- Stage C
         dout          => cpmdQDout,
         valid         => cpmdQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_CalcAddrChunkRespQ : surf.Fifo  (Stage C -> Stage D, internal handoff)
   --   Peeked (dout/valid) by genResp every firing; deq only on the last chunk.
   ---------------------------------------------------------------------------
   U_CalcAddrChunkRespQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 197,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => cacrQWrEn,    -- Stage C
         din           => cacrQDin,     -- Stage C
         full          => cacrQFull,
         not_full      => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => cacrQRdEn,    -- Stage D (only on isLastChunk)
         dout          => cacrQDout,
         valid         => cacrQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_SgePktMetaDataOutQ : surf.Fifo  (PktMetaDataSGE side-channel out)
   --   wr side = Stage C; rd side = caller sgePktMetaDataPipeOut (pass-through).
   ---------------------------------------------------------------------------
   U_SgePktMetaDataOutQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 54,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => sgeQWrEn,        -- Stage C
         din           => sgeQDin,         -- Stage C
         full          => sgeQFull,
         not_full      => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => sgePktMetaRdEn,  -- pass-through (caller drives)
         dout          => sgePktMetaData,  -- pass-through to caller
         valid         => sgeQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_RespQ : surf.Fifo  (AddrChunkResp outbound)
   --   wr side = Stage D (genResp); rd side = caller srvPort.response.get.
   ---------------------------------------------------------------------------
   U_RespQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 81,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => respQWrEn,     -- Stage D
         din           => respQDin,      -- Stage D
         full          => respQFull,
         not_full      => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => respGetReady,  -- pass-through (caller drives)
         dout          => respGetData,   -- pass-through to caller
         valid         => respQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- Combinatorial process
   --   Four independent stage blocks (A/B/C stateless, D is the FSM) plus the
   --   resetAndClear branch.  Within !clearAllI the four stages are non-conflict
   --   (disjoint FIFO pairs) and each is its own implicit-condition-gated block.
   ---------------------------------------------------------------------------
   comb : process (r, rst, clearAllI,
                   reqQValid, reqQDout,
                   ccmdQValid, ccmdQDout, ccmdQFull,
                   cpmdQValid, cpmdQDout, cpmdQFull,
                   cacrQValid, cacrQDout, cacrQFull,
                   sgeQFull, respQFull) is
      variable v : RegType;

      -- Stage A (recvReq) temporaries
      variable aStartAddr : slv(63 downto 0);
      variable aLen       : slv(31 downto 0);
      variable aPmtu      : slv(2 downto 0);
      variable aPmtuMask  : slv(12 downto 0);
      variable aAddrLow   : slv(12 downto 0);
      variable aLenLow    : slv(12 downto 0);
      variable aTruncPN   : slv(24 downto 0);
      variable aAligned   : slv(63 downto 0);
      variable aPmtuLen   : slv(12 downto 0);
      variable aMaxFirst  : slv(12 downto 0);
      variable aSum       : slv(12 downto 0);

      -- Stage B (calcChunkMetaData) temporaries
      variable bPmtuMask  : slv(12 downto 0);
      variable bSum       : slv(12 downto 0);
      variable bPmtuLen   : slv(12 downto 0);
      variable bLenLow    : slv(12 downto 0);
      variable bMaxFirst  : slv(12 downto 0);
      variable bTruncPN   : slv(24 downto 0);
      variable bAligned   : slv(63 downto 0);
      variable bStartAddr : slv(63 downto 0);
      variable bPmtu      : slv(2 downto 0);
      variable bIsFirst   : sl;
      variable bIsLast    : sl;
      variable bSecond    : slv(63 downto 0);
      variable bResMasked : slv(12 downto 0);
      variable bTmpLast   : slv(12 downto 0);
      variable bInvMask   : slv(12 downto 0);
      variable bNotFull   : sl;
      variable bHasRes    : sl;
      variable bHasExtra  : sl;
      variable bAddOne    : slv(1 downto 0);

      -- Stage C (genPktMetaDataSGE) temporaries
      variable cAddOne    : slv(1 downto 0);
      variable cTruncPN   : slv(24 downto 0);
      variable cLenLow    : slv(12 downto 0);
      variable cMaxFirst  : slv(12 downto 0);
      variable cTmpLast   : slv(12 downto 0);
      variable cPmtuLen   : slv(12 downto 0);
      variable cPmtu      : slv(2 downto 0);
      variable cStartAddr : slv(63 downto 0);
      variable cNextAddr  : slv(63 downto 0);
      variable cNotFull   : sl;
      variable cHasExtra  : sl;
      variable cHasRes    : sl;
      variable cOrigFirst : sl;
      variable cOrigLast  : sl;
      variable cTotalPN   : slv(24 downto 0);
      variable cFirst     : slv(12 downto 0);
      variable cLast      : slv(12 downto 0);

      -- Stage D (genResp) temporaries
      variable dSgePktNum : slv(24 downto 0);
      variable dFirst     : slv(12 downto 0);
      variable dPmtuLen   : slv(12 downto 0);
      variable dLast      : slv(12 downto 0);
      variable dStartAddr : slv(63 downto 0);
      variable dNextAddr  : slv(63 downto 0);
      variable dOrigFirst : sl;
      variable dOrigLast  : sl;
      variable dRemaining : slv(24 downto 0);
      variable dNextChunk : slv(63 downto 0);
      variable dIsLast    : sl;
      variable dChunkAddr : slv(63 downto 0);
      variable dChunkLen  : slv(12 downto 0);
      variable dIsFirst   : sl;
   begin
      v := r;

      -- Default Mealy outputs (deasserted; overridden per firing stage)
      reqQRdEn  <= '0';
      ccmdQWrEn <= '0';
      ccmdQDin  <= (others => '0');
      ccmdQRdEn <= '0';
      cpmdQWrEn <= '0';
      cpmdQDin  <= (others => '0');
      cpmdQRdEn <= '0';
      sgeQWrEn  <= '0';
      sgeQDin   <= (others => '0');
      cacrQWrEn <= '0';
      cacrQDin  <= (others => '0');
      cacrQRdEn <= '0';
      respQWrEn <= '0';
      respQDin  <= (others => '0');

      if clearAllI = '1' then
         -- resetAndClear: FIFOs flushed via fifoRst pins; force power-on state.
         -- remainingPktNumReg / nextChunkAddrReg untouched (BSV never assigns
         -- them here; overwritten by the next NEWCHUNK genResp before any read).
         v.state := NEWCHUNK_S;

      else
         -------------------------------------------------------------------
         -- Stage A : recvReq  (reqQ -> calcChunkMetaDataQ)
         --   impl. cond: reqQValid='1' AND calcChunkMetaDataQ not full
         -------------------------------------------------------------------
         if (reqQValid = '1' and ccmdQFull = '0') then
            aStartAddr := reqQDout(100 downto 37);
            aLen       := reqQDout(36 downto 5);
            aPmtu      := reqQDout(4 downto 2);

            case aPmtu is
               when "001" =>            -- IBV_MTU_256  (k=8)
                  aPmtuMask := slv(to_unsigned(255, 13));
                  aAddrLow  := "00000" & aStartAddr(7 downto 0);
                  aLenLow   := "00000" & aLen(7 downto 0);
                  aTruncPN  := "0" & aLen(31 downto 8);
                  aAligned  := aStartAddr(63 downto 8) & "00000000";
                  aPmtuLen  := slv(to_unsigned(256, 13));
               when "010" =>            -- IBV_MTU_512  (k=9)
                  aPmtuMask := slv(to_unsigned(511, 13));
                  aAddrLow  := "0000" & aStartAddr(8 downto 0);
                  aLenLow   := "0000" & aLen(8 downto 0);
                  aTruncPN  := "00" & aLen(31 downto 9);
                  aAligned  := aStartAddr(63 downto 9) & "000000000";
                  aPmtuLen  := slv(to_unsigned(512, 13));
               when "011" =>            -- IBV_MTU_1024 (k=10)
                  aPmtuMask := slv(to_unsigned(1023, 13));
                  aAddrLow  := "000" & aStartAddr(9 downto 0);
                  aLenLow   := "000" & aLen(9 downto 0);
                  aTruncPN  := "000" & aLen(31 downto 10);
                  aAligned  := aStartAddr(63 downto 10) & "0000000000";
                  aPmtuLen  := slv(to_unsigned(1024, 13));
               when "100" =>            -- IBV_MTU_2048 (k=11)
                  aPmtuMask := slv(to_unsigned(2047, 13));
                  aAddrLow  := "00" & aStartAddr(10 downto 0);
                  aLenLow   := "00" & aLen(10 downto 0);
                  aTruncPN  := "0000" & aLen(31 downto 11);
                  aAligned  := aStartAddr(63 downto 11) & "00000000000";
                  aPmtuLen  := slv(to_unsigned(2048, 13));
               when "101" =>            -- IBV_MTU_4096 (k=12)
                  aPmtuMask := slv(to_unsigned(4095, 13));
                  aAddrLow  := "0" & aStartAddr(11 downto 0);
                  aLenLow   := "0" & aLen(11 downto 0);
                  aTruncPN  := "00000" & aLen(31 downto 12);
                  aAligned  := aStartAddr(63 downto 12) & "000000000000";
                  aPmtuLen  := slv(to_unsigned(4096, 13));
               when others =>           -- invalid PMTU (should not occur)
                  aPmtuMask := (others => '0');
                  aAddrLow  := (others => '0');
                  aLenLow   := (others => '0');
                  aTruncPN  := (others => '0');
                  aAligned  := (others => '0');
                  aPmtuLen  := (others => '0');
            end case;

            aMaxFirst := slv(unsigned(aPmtuLen) - unsigned(aAddrLow));
            aSum      := slv(unsigned(aAddrLow) + unsigned(aLenLow));

            reqQRdEn  <= '1';           -- reqQ.deq
            ccmdQWrEn <= '1';           -- calcChunkMetaDataQ.enq
            ccmdQDin  <= aPmtuMask & aSum & aPmtuLen & aLenLow & aMaxFirst &
                        aTruncPN & aAligned & reqQDout;
         end if;

         -------------------------------------------------------------------
         -- Stage B : calcChunkMetaData  (calcChunkMetaDataQ -> calcPktMetaDataQ4SGE)
         --   impl. cond: calcChunkMetaDataQValid='1' AND calcPktMetaDataQ4SGE not full
         -------------------------------------------------------------------
         if (ccmdQValid = '1' and cpmdQFull = '0') then
            bPmtuMask  := ccmdQDout(254 downto 242);
            bSum       := ccmdQDout(241 downto 229);
            bPmtuLen   := ccmdQDout(228 downto 216);
            bLenLow    := ccmdQDout(215 downto 203);
            bMaxFirst  := ccmdQDout(202 downto 190);
            bTruncPN   := ccmdQDout(189 downto 165);
            bAligned   := ccmdQDout(164 downto 101);
            bStartAddr := ccmdQDout(100 downto 37);  -- addrChunkReq.startAddr
            bPmtu      := ccmdQDout(4 downto 2);     -- addrChunkReq.pmtu
            bIsFirst   := ccmdQDout(1);              -- addrChunkReq.isFirst
            bIsLast    := ccmdQDout(0);              -- addrChunkReq.isLast

            -- secondChunkStartAddr = addrAddPsnMultiplyPMTU(aligned,1,pmtu)
            --                      = pmtuAlignedStartAddr + pmtuLen
            bSecond := slv(unsigned(bAligned) + resize(unsigned(bPmtuLen), 64));

            -- residue = low-k bits of addrAndLenLowPartSum (= mask AND sum);
            -- tmpLastPktLen = zeroExtend(residue) (already 13-bit)
            bResMasked := bPmtuMask and bSum;
            bTmpLast   := bResMasked;
            bInvMask   := not bPmtuMask;

            if (unsigned(bResMasked) = 0) then bHasRes          := '0'; else bHasRes := '1'; end if;
            if (unsigned(bInvMask and bSum) = 0) then bHasExtra := '0'; else bHasExtra := '1'; end if;
            if (unsigned(bTruncPN) = 0) then bNotFull           := '1'; else bNotFull := '0'; end if;

            -- pktNumAddOne = zeroExtend(hasResidue) + zeroExtend(hasExtraPkt) (0..2)
            bAddOne := slv(unsigned'("0" & bHasRes) + unsigned'("0" & bHasExtra));

            ccmdQRdEn <= '1';           -- calcChunkMetaDataQ.deq
            cpmdQWrEn <= '1';           -- calcPktMetaDataQ4SGE.enq
            cpmdQDin  <= bAddOne & bTruncPN & bLenLow & bMaxFirst & bTmpLast &
                        bPmtuLen & bPmtu & bStartAddr & bSecond &
                        bNotFull & bHasExtra & bHasRes & bIsFirst & bIsLast;
         end if;

         -------------------------------------------------------------------
         -- Stage C : genPktMetaDataSGE
         --   (calcPktMetaDataQ4SGE -> sgePktMetaDataOutQ + calcAddrChunkRespQ)
         --   impl. cond: cpmdQValid='1' AND sgePktMetaDataOutQ not full
         --                                AND calcAddrChunkRespQ not full
         -------------------------------------------------------------------
         if (cpmdQValid = '1' and sgeQFull = '0' and cacrQFull = '0') then
            cAddOne    := cpmdQDout(214 downto 213);
            cTruncPN   := cpmdQDout(212 downto 188);
            cLenLow    := cpmdQDout(187 downto 175);
            cMaxFirst  := cpmdQDout(174 downto 162);
            cTmpLast   := cpmdQDout(161 downto 149);
            cPmtuLen   := cpmdQDout(148 downto 136);
            cPmtu      := cpmdQDout(135 downto 133);
            cStartAddr := cpmdQDout(132 downto 69);
            cNextAddr  := cpmdQDout(68 downto 5);
            cNotFull   := cpmdQDout(4);
            cHasExtra  := cpmdQDout(3);
            cHasRes    := cpmdQDout(2);
            cOrigFirst := cpmdQDout(1);
            cOrigLast  := cpmdQDout(0);

            cTotalPN := slv(unsigned(cTruncPN) + resize(unsigned(cAddOne), 25));

            if (cNotFull = '1' and cHasExtra = '0') then
               cFirst := cLenLow;
            else
               cFirst := cMaxFirst;
            end if;

            if (cHasRes = '1') then
               cLast := cTmpLast;
            elsif (cNotFull = '1') then
               cLast := cLenLow;
            else
               cLast := cPmtuLen;
            end if;

            cpmdQRdEn <= '1';           -- calcPktMetaDataQ4SGE.deq
            -- PktMetaDataSGE = firstPktLen & lastPktLen & sgePktNum & pmtu
            sgeQWrEn  <= '1';
            sgeQDin   <= cFirst & cLast & cTotalPN & cPmtu;
            -- TmpChunkRespData
            cacrQWrEn <= '1';
            cacrQDin  <= cTotalPN & cFirst & cPmtuLen & cLast & cPmtu &
                        cStartAddr & cNextAddr & cOrigFirst & cOrigLast;
         end if;

         -------------------------------------------------------------------
         -- Stage D : genResp  (calcAddrChunkRespQ -> respQ)  — the real FSM
         --   impl. cond: cacrQValid='1' AND respQ not full
         --   Mealy: chunkAddr/chunkLen/isFirst read the CURRENT (pre-update) r.
         -------------------------------------------------------------------
         if (cacrQValid = '1' and respQFull = '0') then
            dSgePktNum := cacrQDout(196 downto 172);
            dFirst     := cacrQDout(171 downto 159);
            dPmtuLen   := cacrQDout(158 downto 146);
            dLast      := cacrQDout(145 downto 133);
            -- pmtu (132:130) unused: addr increment uses precomputed pmtuLen
            dStartAddr := cacrQDout(129 downto 66);
            dNextAddr  := cacrQDout(65 downto 2);
            dOrigFirst := cacrQDout(1);
            dOrigLast  := cacrQDout(0);

            -- next-chunk address & remaining-count candidates
            if (r.state = NEWCHUNK_S) then
               dNextChunk := dNextAddr;  -- precomputed 2nd-chunk addr
               dRemaining := dSgePktNum;
            else
               -- addrAddPsnMultiplyPMTU(nextChunkAddrReg,1,pmtu) = +pmtuLen
               dNextChunk := slv(unsigned(r.nextChunkAddrReg) + resize(unsigned(dPmtuLen), 64));
               dRemaining := r.remainingPktNumReg;
            end if;

            if (unsigned(dRemaining) = 1) then dIsLast := '1'; else dIsLast := '0'; end if;

            -- response fields read the PRE-update register values (Mealy on r)
            if (r.state = NEWCHUNK_S) then
               dIsFirst   := '1';
               dChunkAddr := dStartAddr;
               dChunkLen  := dFirst;
            else
               dIsFirst   := '0';
               dChunkAddr := r.nextChunkAddrReg;
               if (dIsLast = '1') then
                  dChunkLen := dLast;
               else
                  dChunkLen := dPmtuLen;
               end if;
            end if;

            -- AddrChunkResp = chunkAddr & chunkLen & isFirst & isLast & isOrigFirst & isOrigLast
            respQWrEn <= '1';
            respQDin  <= dChunkAddr & dChunkLen & dIsFirst & dIsLast & dOrigFirst & dOrigLast;

            -- register / FIFO updates
            if (dIsLast = '1') then
               cacrQRdEn <= '1';        -- deq (done with entry)
            else
               v.remainingPktNumReg := slv(unsigned(dRemaining) - 1);
            end if;
            v.nextChunkAddrReg := dNextChunk;
            if (dIsLast = '1') then
               v.state := NEWCHUNK_S;   -- isFirstChunkReg <= True
            else
               v.state := CONTCHUNK_S;  -- isFirstChunkReg <= False
            end if;
         end if;
      end if;

      -- Synchronous reset (overrides FSM; matches BSV mkReg(True) for state)
      if (rst = '1') then
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

   ---------------------------------------------------------------------------
   -- Simulation-only assertion (no synthesizable effect): addrChunkReq.len /= 0
   -- (BSV immAssert in recvReq, fsm.md §recvReq; cf. OQ-FSM-DS2H-04 treatment).
   ---------------------------------------------------------------------------
   -- pragma translate_off
   chk : process (clk) is
   begin
      if rising_edge(clk) then
         if (rst = '0' and clearAllI = '0' and reqQValid = '1' and ccmdQFull = '0') then
            assert unsigned(reqQDout(36 downto 5)) /= 0
               report "AddrChunkSrvGen: addrChunkReq.len must not be zero"
               severity error;
         end if;
      end if;
   end process chk;
   -- pragma translate_on

end architecture rtl;
