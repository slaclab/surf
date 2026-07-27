-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Server#(PermCheckReq, Bool) that validates a memory-region permission
--   request and returns a single Bool (granted='1' / denied='0'). It is a
--   3-stage dataflow pipeline (rules recvReq → checkReqStepOne → checkReqStepTwo)
--   with NO explicit state register: every rule deqs one FIFO, does a purely
--   combinational compute, and enqs the next FIFO, all in one atomic BSV firing.
--   All sequential storage lives in the four surf.Fifo instances, so this entity
--   has NO RegType and NO seq process (same stateless-pipeline shape as
--   CombineHeaderAndPayload) — the three stages are concurrent combinational
--   FIFO handshakes, each gated only by its own input notEmpty and output
--   notFull. The rules are conflict-free (disjoint FIFO read/write sets) and may
--   all fire in the same cycle (full-throughput pipeline).
--
--   The BSV `immAssert(!isZeroDmaLen)` in recvReq is simulation-only and is NOT
--   emitted (synthesis drops it).
--
--   External pdMetaData MR lookup (OQ-FSM-PCS-01):
--     `mkPermCheckSrv#(MetaDataPDs pdMetaData)` — pdMetaData is a MODULE ARGUMENT,
--     not an internal child (mapping.json child_entity_instances=[]). recvReq's MR
--     lookup is therefore exposed as an external combinational port group that the
--     PARENT wires to the flattened MetaDataPDs lookup ports; this entity does NOT
--     instantiate a MetaDataPDs/MetaDataMRs. The lookup address is presented from
--     the U_ReqInQ head and its result {mrLkupValid,mrLkupData} is captured into
--     the checkStepOneQ write word the SAME cycle recvReq fires. Confirm the exact
--     MetaDataPDs lookup-port names against that entity when it is emitted.
--
--   Widths (traced — see out/03-fsm/PermCheckSrv.fsm.md, confirmed vs BSV):
--     PermCheckReq        = 267 b   (DataTypes.bsv:244-254)
--     MemRegion           = 186 b   (MetaData.bsv:155-162)
--     Maybe#(MemRegion)   = 187 b   ([186]=Valid tag, [185:0]=MemRegion)
--     checkStepOneQ elem  = 455 b   (PermCheckReq, Bool, Maybe#(MemRegion))
--     checkStepTwoQ elem  = 455 b   (PermCheckReq, Maybe#(MemRegion), Bool)
--     respOutQ elem       =   1 b   (Bool)
--
--   Bit packing (BSV deriving(Bits), first-field-at-MSB; project convention):
--     PermCheckReq [266:0]:
--       [266:202]=wrID(65)  [201:170]=lkey(32)  [169:138]=rkey(32)
--       [137]=localOrRmtKey  [136:73]=reqAddr(64)  [72:41]=totalLen(32)
--       [40:9]=pdHandler(32)  [8]=isZeroDmaLen  [7:0]=accFlags(8)
--     MemRegion [185:0]:
--       [185:122]=laddr(64)  [121:90]=len(32)  [89:82]=accFlags(8)
--       [81:50]=pdHandler(32)  [49:25]=lkeyPart(25)  [24:0]=rkeyPart(25)
--     Tuple3 first-field-at-MSB:
--       checkStepOneQ: [454:188]=req  [187]=isZeroDmaLen  [186:0]=maybeMR
--       checkStepTwoQ: [454:188]=req  [187:1]=maybeMR      [0]=stepOneResult
--
--   Datapath (faithful to MetaData.bsv / Utils.bsv / PrimUtils.bsv):
--     recvReq         : deq reqInQ; isZeroDmaLen=isZero(totalLen);
--                       maybeMR = pdMetaData lookup by (localOrRmtKey?lkey:rkey);
--                       enq checkStepOneQ (req, isZeroDmaLen, maybeMR).
--     checkReqStepOne : stepOneResult=isZeroDmaLen; if !isZeroDmaLen & MR.Valid:
--                       keyMatch = truncate(key)==keyPart  (low 25 bits);
--                       accTypeMatch = compareAccessTypeFlags(mr.accFlags,accFlags)
--                                    = containFlags = (mr.accFlags & accFlags)==accFlags;
--                       stepOneResult = keyMatch & accTypeMatch.
--                       enq checkStepTwoQ (req, maybeMR, stepOneResult).
--     checkReqStepTwo : stepTwoResult=stepOneResult; if stepOneResult & MR.Valid:
--                       stepTwoResult = checkAddrAndLenWithinRange(reqAddr,totalLen,
--                                                                  mr.laddr,mr.len);
--                       enq respOutQ (stepTwoResult).
--     checkAddrAndLenWithinRange(laddr,dlen,raddr,rlen)  (Utils.bsv:717-739):
--       hi[63:32], lo[31:0]; addrHighPartEq=(laddr.hi==raddr.hi);
--       addrLowPartMatch=(laddr.lo >= raddr.lo) [unsigned];
--       lSum={0,laddr.lo}+{0,dlen}; rSum={0,raddr.lo}+{0,rlen} [33-bit];
--       addrLenMatch=(rSum >= lSum); result = all three.  (l=request, r=MR)
--
--   SURF components instantiated (read at emit from surf/base/fifo/rtl/Fifo.vhd):
--     U_ReqInQ       : surf.Fifo  DATA_WIDTH_G=267, FWFT, sync, block
--     U_CheckStepOneQ: surf.Fifo  DATA_WIDTH_G=455, FWFT, sync, block
--     U_CheckStepTwoQ: surf.Fifo  DATA_WIDTH_G=455, FWFT, sync, block
--     U_RespOutQ     : surf.Fifo  DATA_WIDTH_G=1,   FWFT, sync, distributed
--   All four are BSV mkFIFOF (2-deep). Emitted at ADDR_WIDTH_G=4 (16-deep) — the
--   SURF Fifo minimum; extra depth is behaviour-preserving for the notFull/
--   notEmpty handshake (see OQ-EMIT-PCS-02).
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

entity PermCheckSrv is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk             : in  sl;
      rst             : in  sl;         -- active-high synchronous reset
      -----------------------------------------------------------------------
      -- Server request : request.put -> reqInQ.enq   (PermCheckReq, 267 b)
      -----------------------------------------------------------------------
      reqPutValid     : in  sl;         -- upstream has a request
      reqPutData      : in  slv(266 downto 0);   -- PermCheckReq
      reqPutReady     : out sl;         -- = reqInQ.notFull
      -----------------------------------------------------------------------
      -- Server response : respOutQ -> response.get   (Bool)
      -----------------------------------------------------------------------
      respGetValid    : out sl;         -- = respOutQ.notEmpty
      respGetData     : out sl;         -- granted(1)/denied(0)
      respGetRdEn     : in  sl;         -- response.get (deq respOutQ)
      -----------------------------------------------------------------------
      -- External pdMetaData MR lookup (module arg; combinational) — OQ-FSM-PCS-01
      -----------------------------------------------------------------------
      mrLkupPdHandler : out slv(31 downto 0);    -- req.pdHandler
      mrLkupKey       : out slv(31 downto 0);    -- localOrRmtKey ? lkey : rkey
      mrLkupByLocal   : out sl;         -- localOrRmtKey (LKEY vs RKEY)
      mrLkupReqValid  : out sl;         -- recvReq fire (head is live)
      mrLkupValid     : in  sl;         -- returned Maybe tag
      mrLkupData      : in  slv(185 downto 0));  -- returned MemRegion (186 b)
end entity PermCheckSrv;

architecture rtl of PermCheckSrv is

   ---------------------------------------------------------------------------
   -- Element widths
   ---------------------------------------------------------------------------
   constant REQ_WIDTH_C      : natural := 267;  -- PermCheckReq
   constant MR_WIDTH_C       : natural := 186;  -- MemRegion
   constant MAYBE_MR_WIDTH_C : natural := 187;  -- Maybe#(MemRegion)
   constant STEP_WIDTH_C     : natural := 455;  -- checkStepOne/TwoQ element

   ---------------------------------------------------------------------------
   -- U_ReqInQ (267 b) : request.put write side / recvReq read side
   ---------------------------------------------------------------------------
   signal reqInQWrEn    : sl;
   signal reqInQDin     : slv(REQ_WIDTH_C-1 downto 0);
   signal reqInQNotFull : sl;
   signal reqInQRdEn    : sl;
   signal reqInQValid   : sl;
   signal reqInQDout    : slv(REQ_WIDTH_C-1 downto 0);

   ---------------------------------------------------------------------------
   -- U_CheckStepOneQ (455 b) : recvReq write side / checkReqStepOne read side
   ---------------------------------------------------------------------------
   signal stepOneQWrEn    : sl;
   signal stepOneQDin     : slv(STEP_WIDTH_C-1 downto 0);
   signal stepOneQNotFull : sl;
   signal stepOneQRdEn    : sl;
   signal stepOneQValid   : sl;
   signal stepOneQDout    : slv(STEP_WIDTH_C-1 downto 0);

   ---------------------------------------------------------------------------
   -- U_CheckStepTwoQ (455 b) : checkReqStepOne write side / checkReqStepTwo read
   ---------------------------------------------------------------------------
   signal stepTwoQWrEn    : sl;
   signal stepTwoQDin     : slv(STEP_WIDTH_C-1 downto 0);
   signal stepTwoQNotFull : sl;
   signal stepTwoQRdEn    : sl;
   signal stepTwoQValid   : sl;
   signal stepTwoQDout    : slv(STEP_WIDTH_C-1 downto 0);

   ---------------------------------------------------------------------------
   -- U_RespOutQ (1 b) : checkReqStepTwo write side / response.get read side
   ---------------------------------------------------------------------------
   signal respOutQWrEn    : sl;
   signal respOutQDin     : slv(0 downto 0);
   signal respOutQNotFull : sl;
   signal respOutQRdEn    : sl;
   signal respOutQValid   : sl;
   signal respOutQDout    : slv(0 downto 0);

begin

   ---------------------------------------------------------------------------
   -- Server request-side wiring (request.put -> U_ReqInQ.enq)
   --   ready = notFull ; enq on valid & ready (FIFO ignores writes when full).
   ---------------------------------------------------------------------------
   reqPutReady <= reqInQNotFull;
   reqInQWrEn  <= reqPutValid and reqInQNotFull;
   reqInQDin   <= reqPutData;

   ---------------------------------------------------------------------------
   -- Server response-side wiring (U_RespOutQ.first/deq -> response.get)
   ---------------------------------------------------------------------------
   respGetValid <= respOutQValid;
   respGetData  <= respOutQDout(0);
   respOutQRdEn <= respGetRdEn;

   ---------------------------------------------------------------------------
   -- U_ReqInQ : surf.Fifo  (BSV: reqInQ <- mkFIFOF, PermCheckReq = 267 b)
   ---------------------------------------------------------------------------
   U_ReqInQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => REQ_WIDTH_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => rst,
         wr_clk        => clk,
         wr_en         => reqInQWrEn,
         din           => reqInQDin,
         not_full      => reqInQNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         full          => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => reqInQRdEn,
         dout          => reqInQDout,
         valid         => reqInQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_CheckStepOneQ : surf.Fifo  (BSV: checkStepOneQ <- mkFIFOF, 455 b)
   ---------------------------------------------------------------------------
   U_CheckStepOneQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => STEP_WIDTH_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => rst,
         wr_clk        => clk,
         wr_en         => stepOneQWrEn,
         din           => stepOneQDin,
         not_full      => stepOneQNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         full          => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => stepOneQRdEn,
         dout          => stepOneQDout,
         valid         => stepOneQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_CheckStepTwoQ : surf.Fifo  (BSV: checkStepTwoQ <- mkFIFOF, 455 b)
   ---------------------------------------------------------------------------
   U_CheckStepTwoQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => STEP_WIDTH_C,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => rst,
         wr_clk        => clk,
         wr_en         => stepTwoQWrEn,
         din           => stepTwoQDin,
         not_full      => stepTwoQNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         full          => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => stepTwoQRdEn,
         dout          => stepTwoQDout,
         valid         => stepTwoQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_RespOutQ : surf.Fifo  (BSV: respOutQ <- mkFIFOF, Bool = 1 b)
   ---------------------------------------------------------------------------
   U_RespOutQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 1,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => rst,
         wr_clk        => clk,
         wr_en         => respOutQWrEn,
         din           => respOutQDin,
         not_full      => respOutQNotFull,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         full          => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => respOutQRdEn,
         dout          => respOutQDout,
         valid         => respOutQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- Combinatorial pipeline : the three conflict-free BSV rules, each a
   -- single-cycle deq + combinational compute + enq. No registered state
   -- (all state is in the four FIFOs) so there is no seq process / RegType.
   ---------------------------------------------------------------------------
   comb : process (reqInQValid, reqInQDout, stepOneQNotFull,
                   stepOneQValid, stepOneQDout, stepTwoQNotFull,
                   stepTwoQValid, stepTwoQDout, respOutQNotFull,
                   mrLkupValid, mrLkupData) is
      -- fire conditions
      variable recvFire : sl;
      variable s1Fire   : sl;
      variable s2Fire   : sl;
      -- recvReq
      variable req0      : slv(REQ_WIDTH_C-1 downto 0);
      variable localKey0 : sl;
      variable zeroLen0  : sl;
      variable maybeMR0  : slv(MAYBE_MR_WIDTH_C-1 downto 0);
      -- checkReqStepOne
      variable req1     : slv(REQ_WIDTH_C-1 downto 0);
      variable zeroLen1 : sl;
      variable mrValid1 : sl;
      variable mr1      : slv(MR_WIDTH_C-1 downto 0);
      variable local1   : sl;
      variable keyLow1  : slv(24 downto 0);
      variable keyPart1 : slv(24 downto 0);
      variable accReq1  : slv(7 downto 0);
      variable accMr1   : slv(7 downto 0);
      variable keyMatch : sl;
      variable accMatch : sl;
      variable s1Result : sl;
      -- checkReqStepTwo
      variable req2      : slv(REQ_WIDTH_C-1 downto 0);
      variable mrValid2  : sl;
      variable mr2       : slv(MR_WIDTH_C-1 downto 0);
      variable s1In2     : sl;
      variable reqAddr2  : slv(63 downto 0);
      variable totalLen2 : slv(31 downto 0);
      variable mrLaddr2  : slv(63 downto 0);
      variable mrLen2    : slv(31 downto 0);
      variable hiEq      : sl;
      variable loGe      : sl;
      variable lSum      : unsigned(32 downto 0);
      variable rSum      : unsigned(32 downto 0);
      variable lenOk     : sl;
      variable rangeOk   : sl;
      variable s2Result  : sl;
   begin
      -- Defaults (all drives deasserted)
      reqInQRdEn      <= '0';
      stepOneQWrEn    <= '0';
      stepOneQDin     <= (others => '0');
      stepOneQRdEn    <= '0';
      stepTwoQWrEn    <= '0';
      stepTwoQDin     <= (others => '0');
      stepTwoQRdEn    <= '0';
      respOutQWrEn    <= '0';
      respOutQDin     <= (others => '0');
      mrLkupPdHandler <= (others => '0');
      mrLkupKey       <= (others => '0');
      mrLkupByLocal   <= '0';
      mrLkupReqValid  <= '0';

      -----------------------------------------------------------------------
      -- recvReq : deq reqInQ; combinational MR lookup via pdMetaData;
      --           enq checkStepOneQ (req, isZeroDmaLen, maybeMR).
      -----------------------------------------------------------------------
      recvFire  := reqInQValid and stepOneQNotFull;
      req0      := reqInQDout;
      localKey0 := req0(137);                               -- localOrRmtKey
      zeroLen0  := toSl(unsigned(req0(72 downto 41)) = 0);  -- isZero(totalLen)

      -- Present the lookup address from the U_ReqInQ head (combinational)
      mrLkupPdHandler <= req0(40 downto 9);  -- pdHandler
      mrLkupKey       <= ite(localKey0 = '1', req0(201 downto 170), req0(169 downto 138));
      mrLkupByLocal   <= localKey0;
      mrLkupReqValid  <= recvFire;

      -- Capture the returned Maybe#(MemRegion) this same cycle
      maybeMR0 := mrLkupValid & mrLkupData;  -- [186]=tag [185:0]=MR

      if recvFire = '1' then
         reqInQRdEn   <= '1';                         -- reqInQ.deq
         stepOneQWrEn <= '1';                         -- checkStepOneQ.enq
         stepOneQDin  <= req0 & zeroLen0 & maybeMR0;  -- 267+1+187 = 455
      end if;

      -----------------------------------------------------------------------
      -- checkReqStepOne : deq checkStepOneQ; key + access-flag match;
      --                   enq checkStepTwoQ (req, maybeMR, stepOneResult).
      -----------------------------------------------------------------------
      s1Fire   := stepOneQValid and stepTwoQNotFull;
      req1     := stepOneQDout(454 downto 188);
      zeroLen1 := stepOneQDout(187);
      mrValid1 := stepOneQDout(186);                     -- Maybe tag
      mr1      := stepOneQDout(185 downto 0);            -- MemRegion
      local1   := req1(137);
      accReq1  := req1(7 downto 0);                      -- req.accFlags
      accMr1   := mr1(89 downto 82);                     -- mr.accFlags
      -- truncate(key) keeps low 25 bits (KeyPartMR); keyPart per local/remote
      keyLow1  := ite(local1 = '1', req1(194 downto 170), req1(162 downto 138));
      keyPart1 := ite(local1 = '1', mr1(49 downto 25), mr1(24 downto 0));
      keyMatch := toSl(keyLow1 = keyPart1);
      accMatch := toSl((accMr1 and accReq1) = accReq1);  -- containFlags

      s1Result := zeroLen1;             -- default
      if (zeroLen1 = '0') and (mrValid1 = '1') then
         s1Result := keyMatch and accMatch;
      end if;

      if s1Fire = '1' then
         stepOneQRdEn <= '1';           -- checkStepOneQ.deq
         stepTwoQWrEn <= '1';           -- checkStepTwoQ.enq
         stepTwoQDin  <= req1 & (mrValid1 & mr1) & s1Result;  -- 267+187+1 = 455
      end if;

      -----------------------------------------------------------------------
      -- checkReqStepTwo : deq checkStepTwoQ; address/length-in-range check;
      --                   enq respOutQ (stepTwoResult).
      -----------------------------------------------------------------------
      s2Fire    := stepTwoQValid and respOutQNotFull;
      req2      := stepTwoQDout(454 downto 188);
      mrValid2  := stepTwoQDout(187);           -- Maybe tag
      mr2       := stepTwoQDout(186 downto 1);  -- MemRegion
      s1In2     := stepTwoQDout(0);             -- stepOneResult
      reqAddr2  := req2(136 downto 73);         -- req.reqAddr
      totalLen2 := req2(72 downto 41);          -- req.totalLen  (dlen)
      mrLaddr2  := mr2(185 downto 122);         -- mr.laddr
      mrLen2    := mr2(121 downto 90);          -- mr.len        (rlen)

      -- checkAddrAndLenWithinRange (l=request, r=MR)
      hiEq    := toSl(reqAddr2(63 downto 32) = mrLaddr2(63 downto 32));
      loGe    := toSl(unsigned(reqAddr2(31 downto 0)) >= unsigned(mrLaddr2(31 downto 0)));
      lSum    := ('0' & unsigned(reqAddr2(31 downto 0))) + ('0' & unsigned(totalLen2));
      rSum    := ('0' & unsigned(mrLaddr2(31 downto 0))) + ('0' & unsigned(mrLen2));
      lenOk   := toSl(rSum >= lSum);
      rangeOk := hiEq and loGe and lenOk;

      s2Result := s1In2;                -- default
      if (s1In2 = '1') and (mrValid2 = '1') then
         s2Result := rangeOk;
      end if;

      if s2Fire = '1' then
         stepTwoQRdEn <= '1';                   -- checkStepTwoQ.deq
         respOutQWrEn <= '1';                   -- respOutQ.enq
         respOutQDin  <= (others => s2Result);  -- Bool (1 b)
      end if;

   end process comb;

end architecture rtl;
