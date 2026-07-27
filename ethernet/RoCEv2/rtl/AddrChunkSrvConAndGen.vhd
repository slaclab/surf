-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Server#(AddrChunkReq, AddrChunkResp) plus a combinational isIdle() method.
--   Accepts a single AddrChunkReq (startAddr, totalLen, pmtu) into U_ReqQ and,
--   while busy, emits one AddrChunkResp per PMTU-sized chunk into U_RespQ:
--   walking the address forward by one PMTU each beat and shrinking the
--   remaining-chunk count, flagging the first and last chunk and using the
--   residue length on the final chunk when totalLen is not an exact multiple
--   of the PMTU.
--
--   FSM states (mapped from BSV busyReg):
--     IDLE_S ('0') — waiting for a request (recvReq fires here)
--     BUSY_S ('1') — emitting chunk responses (genResp fires here)
--
--   BSV rules implemented:
--     resetAndClear — guard clearAllI='1'; clears both FIFOs via rst, forces
--                     IDLE_S and isFirstReg='0'.  LEVEL-asserted.
--     recvReq       — guard !clearAllI AND !busyReg (IDLE_S); implicit cond
--                     reqQValid='1'.  Latches the request context, computes
--                     residue / pmtuLen / chunk count, advances to BUSY_S.
--     genResp       — guard !clearAllI AND busyReg (BUSY_S); implicit cond
--                     respQFull='0'.  Emits one AddrChunkResp, decrements the
--                     count, advances the address; returns to IDLE_S on the
--                     last chunk.
--
--   Mapping note (OQ-FSM-ACSCAG-01, see fsm.md §mismatch):
--     mapping.json / modules.json record fabricated rule names
--     (genChunk/lastChunk) and wrong state/ports for this entity; this file
--     and the FSM spec are authoritative.
--
--   isSQ module parameter (OQ-FSM-ACSCAG-02, RESOLVED): functionally dead —
--     referenced only inside a fully commented-out debug rule.  Per the
--     resolution the isSQI port is OMITTED from this entity.
--
--   FIFO clear (OQ-FSM-01 carry-forward, RESOLVED in RESOLVED.md):
--     BSV reqQ.clear / respQ.clear map to asserting each Fifo's rst, OR'd with
--     the structural reset:  fifoRst = rst OR clearAllI.  surf.FifoSync holds
--     logically empty for the whole asserted window (level-safe); no pulse
--     generator needed.  Requires GEN_SYNC_FIFO_G=true, RST_ASYNC_G=false,
--     RST_POLARITY_G='1'.
--
--   SURF components instantiated:
--     U_ReqQ  : surf.Fifo  DATA_WIDTH_G=99, FWFT, sync, distributed RAM
--               (AddrChunkReq;  source: surf/base/fifo/rtl/Fifo.vhd)
--     U_RespQ : surf.Fifo  DATA_WIDTH_G=79, FWFT, sync, distributed RAM
--               (AddrChunkResp; source: surf/base/fifo/rtl/Fifo.vhd)
--     Distributed-RAM FWFT cold latency is 1 cycle (block RAM was 2) — see tb-spec §8.
--
--   AddrChunkReq bit layout (BSV deriving(Bits), first-field-at-MSB):
--     [98:35] startAddr[63:0]  (64 bits)
--     [34:3]  totalLen[31:0]   (32 bits)
--     [2:0]   pmtu[2:0]        (3 bits)
--
--   AddrChunkResp bit layout (BSV deriving(Bits), first-field-at-MSB):
--     [78:15] chunkAddr[63:0]  (64 bits)
--     [14:2]  chunkLen[12:0]   (13 bits)
--     [1]     isFirst
--     [0]     isLast
--
--   PMTU enum (DataTypes.bsv:407-413): IBV_MTU_256=1 .. IBV_MTU_4096=5.
--   Byte length = 2**(pmtu+7): 256, 512, 1024, 2048, 4096.
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

entity AddrChunkSrvConAndGen is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk          : in  sl;
      rst          : in  sl;            -- active-high synchronous reset
      -- Software clear (synchronous; LEVEL-asserted while high)
      clearAllI    : in  sl;
      -- srvPort.request : Put#(AddrChunkReq)  (caller -> entity)
      reqPutValid  : in  sl;            -- caller offers a request (wr_en)
      reqPutData   : in  slv(98 downto 0);  -- AddrChunkReq packed
      reqPutReady  : out sl;            -- entity can accept (reqQ.notFull)
      -- srvPort.response : Get#(AddrChunkResp) (entity -> caller)
      respGetReady : in  sl;            -- caller takes a response (rd_en)
      respGetValid : out sl;            -- response available (respQ.notEmpty)
      respGetData  : out slv(78 downto 0);  -- AddrChunkResp packed
      -- status method
      isIdle       : out sl);  -- !busyReg AND reqQ empty AND respQ empty
end entity AddrChunkSrvConAndGen;

architecture rtl of AddrChunkSrvConAndGen is

   -- FSM state type (maps BSV busyReg: False->IDLE_S, True->BUSY_S)
   type StateType is (IDLE_S, BUSY_S);

   type RegType is record
      state            : StateType;     -- busyReg
      isFirstReg       : sl;            -- mkReg(False)
      fullPktLenReg    : slv(12 downto 0);  -- mkRegU — full (non-residue) chunk length
      residueReg       : slv(11 downto 0);  -- mkRegU — leftover bytes of final chunk
      isZeroResidueReg : sl;  -- mkRegU — totalLen is exact PMTU multiple
      pktNumReg        : slv(24 downto 0);  -- mkRegU — remaining chunk count (down-counter)
      chunkAddrReg     : slv(63 downto 0);  -- mkRegU — address of next chunk
      pmtuReg          : slv(2 downto 0);   -- mkRegU — latched PMTU
   end record RegType;

   -- mkRegU fields set to '0' in REG_INIT_C: recvReq writes every one of them
   -- unconditionally on IDLE_S->BUSY_S, strictly before genResp (the only
   -- reader) can fire.  No correctness risk (fsm.md §State register).
   constant REG_INIT_C : RegType := (
      state            => IDLE_S,
      isFirstReg       => '0',
      fullPktLenReg    => (others => '0'),
      residueReg       => (others => '0'),
      isZeroResidueReg => '0',
      pktNumReg        => (others => '0'),
      chunkAddrReg     => (others => '0'),
      pmtuReg          => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- U_ReqQ interface signals
   signal reqQFull  : sl;
   signal reqQValid : sl;
   signal reqQDout  : slv(98 downto 0);
   signal reqQRdEn  : sl;

   -- U_RespQ interface signals
   signal respQFull  : sl;
   signal respQValid : sl;
   signal respQWrEn  : sl;
   signal respQDin   : slv(78 downto 0);

   -- FIFO reset line: level = rst OR clearAllI (see FIFO clear note above)
   signal fifoRst : sl;

begin

   -- FIFO reset: level-sensitive clear (OQ-FSM-01 carry-forward, RESOLVED)
   fifoRst <= rst or clearAllI;

   -- srvPort.request boundary wiring (pass-through; not FSM-gated)
   reqPutReady <= not reqQFull;         -- reqQ.notFull readiness to caller

   -- isIdle() method (combinational / Mealy):
   --   !busyReg AND !reqQ.notEmpty AND !respQ.notEmpty
   isIdle <= '1' when (r.state = IDLE_S and reqQValid = '0' and respQValid = '0') else
             '0';

   ---------------------------------------------------------------------------
   -- U_ReqQ : surf.Fifo
   --   Inbound AddrChunkReq queue (BSV mkFIFOF reqQ).  wr side is the caller's
   --   srvPort.request.put (pass-through); rd side is consumed by recvReq.
   ---------------------------------------------------------------------------
   U_ReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 99,
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
         rd_en         => reqQRdEn,     -- FSM (recvReq)
         dout          => reqQDout,
         valid         => reqQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   ---------------------------------------------------------------------------
   -- U_RespQ : surf.Fifo
   --   Outbound AddrChunkResp queue (BSV mkFIFOF respQ).  wr side is driven by
   --   genResp; rd side is the caller's srvPort.response.get (pass-through).
   ---------------------------------------------------------------------------
   U_RespQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 79,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => fifoRst,
         wr_clk        => clk,
         wr_en         => respQWrEn,     -- FSM (genResp)
         din           => respQDin,      -- FSM (genResp)
         full          => respQFull,
         not_full      => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         wr_data_count => open,
         rd_clk        => clk,
         rd_en         => respGetReady,  -- pass-through (caller drives)
         dout          => respGetData,
         valid         => respQValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open,
         rd_data_count => open);

   respGetValid <= respQValid;          -- pass-through to caller

   ---------------------------------------------------------------------------
   -- Combinatorial process
   ---------------------------------------------------------------------------
   comb : process (r, rst, clearAllI, reqQValid, reqQDout, respQFull) is
      variable v : RegType;
      -- recvReq datapath temporaries (from reqQDout, AddrChunkReq layout)
      variable startAddr     : slv(63 downto 0);
      variable totalLen      : slv(31 downto 0);
      variable pmtu          : slv(2 downto 0);
      variable residue       : slv(11 downto 0);
      variable tmpPktNum     : slv(24 downto 0);
      variable pmtuLen       : slv(12 downto 0);
      variable isZeroResidue : sl;
      variable totalPktNum   : slv(24 downto 0);
      -- genResp datapath temporaries (from r)
      variable isLast        : sl;
      variable chunkLen      : slv(12 downto 0);
      variable nextChunkAddr : slv(63 downto 0);
   begin
      v := r;

      -- default Mealy outputs (deasserted; overridden below per transition)
      reqQRdEn  <= '0';
      respQWrEn <= '0';
      respQDin  <= (others => '0');

      ----------------------------------------------------------------------
      -- recvReq datapath (combinational; valid only when reqQDout holds a
      -- request, but harmless to compute every cycle)
      --   startAddr = reqQDout[98:35], totalLen = reqQDout[34:3],
      --   pmtu      = reqQDout[2:0]
      --   residue   = totalLen low (pmtu+7) bits, zero-extended to 12b
      --   tmpPktNum = totalLen high bits, zero-extended to 25b
      --   pmtuLen   = 2**(pmtu+7) = chunk byte length
      ----------------------------------------------------------------------
      startAddr := reqQDout(98 downto 35);
      totalLen  := reqQDout(34 downto 3);
      pmtu      := reqQDout(2 downto 0);

      case pmtu is
         when "001" =>                  -- IBV_MTU_256  (k=8)
            residue   := "0000" & totalLen(7 downto 0);
            tmpPktNum := "0" & totalLen(31 downto 8);
            pmtuLen   := slv(to_unsigned(256, 13));
         when "010" =>                  -- IBV_MTU_512  (k=9)
            residue   := "000" & totalLen(8 downto 0);
            tmpPktNum := "00" & totalLen(31 downto 9);
            pmtuLen   := slv(to_unsigned(512, 13));
         when "011" =>                  -- IBV_MTU_1024 (k=10)
            residue   := "00" & totalLen(9 downto 0);
            tmpPktNum := "000" & totalLen(31 downto 10);
            pmtuLen   := slv(to_unsigned(1024, 13));
         when "100" =>                  -- IBV_MTU_2048 (k=11)
            residue   := "0" & totalLen(10 downto 0);
            tmpPktNum := "0000" & totalLen(31 downto 11);
            pmtuLen   := slv(to_unsigned(2048, 13));
         when "101" =>                  -- IBV_MTU_4096 (k=12)
            residue   := totalLen(11 downto 0);
            tmpPktNum := "00000" & totalLen(31 downto 12);
            pmtuLen   := slv(to_unsigned(4096, 13));
         when others =>                 -- invalid PMTU (should not occur)
            residue   := (others => '0');
            tmpPktNum := (others => '0');
            pmtuLen   := (others => '0');
      end case;

      if (unsigned(residue) = 0) then
         isZeroResidue := '1';
         totalPktNum   := tmpPktNum;
      else
         isZeroResidue := '0';
         totalPktNum   := slv(unsigned(tmpPktNum) + 1);
      end if;

      ----------------------------------------------------------------------
      -- genResp datapath (combinational; reads current r)
      --   isLast        = (pktNumReg <= 1)
      --   nextChunkAddr = chunkAddrReg + pmtuLen  (= addrAddPsnMultiplyPMTU,
      --                   psn=1; equals chunkAddrReg + 2**(pmtu+7))
      --   chunkLen      = (isLast AND !isZeroResidueReg) ? residue : fullPktLen
      ----------------------------------------------------------------------
      if (unsigned(r.pktNumReg) <= 1) then
         isLast := '1';
      else
         isLast := '0';
      end if;

      nextChunkAddr := slv(unsigned(r.chunkAddrReg) +
                           resize(unsigned(r.fullPktLenReg), 64));

      if (isLast = '1' and r.isZeroResidueReg = '0') then
         chunkLen := "0" & r.residueReg;  -- zeroExtend(residueReg) to 13b
      else
         chunkLen := r.fullPktLenReg;
      end if;

      ----------------------------------------------------------------------
      -- Rule scheduling: clearAllI first (resetAndClear), else case on state.
      -- Guards are pairwise mutually exclusive (fsm.md §scheduling).
      ----------------------------------------------------------------------
      if clearAllI = '1' then
         -- resetAndClear: FIFOs cleared via fifoRst pins; force power-on state
         v.state      := IDLE_S;
         v.isFirstReg := '0';

      else
         case r.state is

            -- ---------------------------------------------------------------
            -- IDLE_S: recvReq (implicit condition reqQValid='1')
            -- ---------------------------------------------------------------
            when IDLE_S =>
               if reqQValid = '1' then
                  reqQRdEn           <= '1';  -- reqQ.deq
                  v.fullPktLenReg    := pmtuLen;
                  v.residueReg       := residue;
                  v.isZeroResidueReg := isZeroResidue;
                  v.pktNumReg        := totalPktNum;
                  v.chunkAddrReg     := startAddr;
                  v.pmtuReg          := pmtu;
                  v.isFirstReg       := '1';
                  v.state            := BUSY_S;
               end if;

            -- ---------------------------------------------------------------
            -- BUSY_S: genResp (implicit condition respQFull='0')
            -- ---------------------------------------------------------------
            when BUSY_S =>
               -- AddrChunkResp = chunkAddr[63:0] & chunkLen[12:0] & isFirst & isLast
               respQDin <= r.chunkAddrReg & chunkLen & r.isFirstReg & isLast;
               if respQFull = '0' then
                  respQWrEn      <= '1';  -- respQ.enq
                  v.pktNumReg    := slv(unsigned(r.pktNumReg) - 1);
                  v.chunkAddrReg := nextChunkAddr;
                  v.isFirstReg   := '0';
                  if isLast = '1' then
                     v.state := IDLE_S;   -- busyReg <= False
                  end if;
               end if;
               -- respQFull='1' -> whole rule stalls; all registers hold.

         end case;
      end if;

      -- Synchronous reset (overrides FSM; matches BSV mkReg(False) state)
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

   ---------------------------------------------------------------------------
   -- Simulation-only assertion (no synthesizable effect): totalLen /= 0
   -- (BSV immAssert in recvReq, fsm.md §recvReq; cf. OQ-FSM-DS2H-04 treatment).
   ---------------------------------------------------------------------------
   -- pragma translate_off
   chk : process (clk) is
   begin
      if rising_edge(clk) then
         if (rst = '0' and clearAllI = '0' and r.state = IDLE_S and
             reqQValid = '1') then
            assert unsigned(reqQDout(34 downto 3)) /= 0
               report "AddrChunkSrvConAndGen: totalLen must not be zero"
               severity error;
         end if;
      end if;
   end process chk;
   -- pragma translate_on

end architecture rtl;
