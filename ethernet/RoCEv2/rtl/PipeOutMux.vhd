-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Combinatorially selects one of two upstream PipeOut sources and forwards its
--   head element into an output FIFO (U_PipeMuxOutQ), whose read side is the
--   entity's own PipeOut interface.
--
--   BSV has two mutually-exclusive rules driven by the Boolean argument `sel`:
--     outputPipeIn1 if (sel)   : enq(pipeIn1.first); pipeIn1.deq
--     outputPipeIn2 if (!sel)  : enq(pipeIn2.first); pipeIn2.deq
--   Each rule additionally carries the implicit conditions of the FIFO methods:
--   the chosen source must be notEmpty (Valid) and the output FIFO notFull.
--   The two guards (`sel` / `!sel`) are complements, so at most one fires per
--   cycle — a plain if/else in the comb process suffices (no priority needed).
--
--   No local registered state: mkPipeOutMux has zero mkReg/mkRegU. The only
--   persistent element is pipeMuxOutQ, a SURF Fifo. The two-process skeleton is
--   retained for uniformity; the RegType record carries a single dummy field so
--   the VHDL compiles without an empty record. All datapath outputs are Mealy
--   (combinatorial from `sel` and the *Valid/*Dout/notFull inputs).
--
--   SURF components instantiated:
--     U_PipeMuxOutQ : surf.Fifo  (DATA_WIDTH_G=679, FWFT, sync, distributed RAM)
--       source: surf/base/fifo/rtl/Fifo.vhd
--
--   DATA_WIDTH_G (OQ resolved at emit):
--     BSV `anytype` = PendingWorkReq at the QueuePair.bsv:176 instantiation
--     (pipeIn1 = scanPipeOut, pipeIn2 = newPendingWorkReqPiptOut, both
--     PipeOut#(PendingWorkReq)).  sizeof(PendingWorkReq) = 679 bits, matching the
--     output width of sibling entity NewPendingWorkReqPipeOut (outQDout_o).
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

entity PipeOutMux is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';
      RST_ASYNC_G       : boolean                := false;
      DATA_WIDTH_G      : positive               := 679;  -- sizeof(PendingWorkReq)
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4);  -- U_PipeMuxOutQ depth = 2**G
   port (
      clk          : in  sl;
      rst          : in  sl := not RST_POLARITY_G;
      -- Select: BSV module argument `sel` (Bool). '1' -> pipeIn1, '0' -> pipeIn2
      sel          : in  sl;
      -- Upstream PipeOut #1 (pipeIn1)
      pipeIn1Valid : in  sl;            -- pipeIn1.notEmpty
      pipeIn1Dout  : in  slv(DATA_WIDTH_G-1 downto 0);   -- pipeIn1.first
      pipeIn1RdEn  : out sl;            -- pipeIn1.deq
      -- Upstream PipeOut #2 (pipeIn2)
      pipeIn2Valid : in  sl;            -- pipeIn2.notEmpty
      pipeIn2Dout  : in  slv(DATA_WIDTH_G-1 downto 0);   -- pipeIn2.first
      pipeIn2RdEn  : out sl;            -- pipeIn2.deq
      -- Output PipeOut (toPipeOut(pipeMuxOutQ) exposed via U_PipeMuxOutQ read side)
      pipeOutValid : out sl;            -- pipeMuxOutQ.notEmpty
      pipeOutDout  : out slv(DATA_WIDTH_G-1 downto 0);   -- pipeMuxOutQ.first
      pipeOutRdEn  : in  sl);           -- pipeMuxOutQ.deq (downstream)
end PipeOutMux;

architecture rtl of PipeOutMux is

   -- No local FSM state: all state lives in U_PipeMuxOutQ.
   -- One dummy bit keeps the RegType record syntactically non-empty.
   type RegType is record
      dummy : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (dummy => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- U_PipeMuxOutQ (SURF Fifo) signals
   signal muxOutQRst     : sl;
   signal muxOutQWrEn    : sl;
   signal muxOutQDin     : slv(DATA_WIDTH_G-1 downto 0);
   signal muxOutQNotFull : sl;

   -- Global reset normalised to active-high (for FIFO rst port)
   signal rstActiveHigh : sl;

begin

   -- Normalise global rst to active-high for the SURF Fifo rst port
   rstActiveHigh <= rst when (RST_POLARITY_G = '1') else not rst;
   muxOutQRst    <= rstActiveHigh;

   --------------------------------------------------------------------------
   -- U_PipeMuxOutQ : pipeMuxOutQ
   --   BSV: FIFOF#(anytype), instantiated as mkFIFOF (depth 2, FWFT)
   --   SURF: surf.Fifo, GEN_SYNC_FIFO_G=true, FWFT_EN_G=true
   --   Width: DATA_WIDTH_G = 679 bits (PendingWorkReq)
   --------------------------------------------------------------------------
   U_PipeMuxOutQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => RST_ASYNC_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => DATA_WIDTH_G,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G)
      port map (
         rst      => muxOutQRst,
         wr_clk   => clk,
         wr_en    => muxOutQWrEn,
         din      => muxOutQDin,
         not_full => muxOutQNotFull,
         rd_clk   => clk,
         rd_en    => pipeOutRdEn,
         dout     => pipeOutDout,
         valid    => pipeOutValid);

   --------------------------------------------------------------------------
   -- Combinatorial: per-cycle rule evaluation (all outputs Mealy)
   --   outputPipeIn1 (sel='1') and outputPipeIn2 (sel='0') are mutually
   --   exclusive by guard complement — a plain if/else, no priority ordering.
   --------------------------------------------------------------------------
   comb : process (r, rst, sel, pipeIn1Valid, pipeIn1Dout, pipeIn2Valid,
                   pipeIn2Dout, muxOutQNotFull) is
      variable v        : RegType;
      variable in1RdEnV : sl;
      variable in2RdEnV : sl;
      variable wrEnV    : sl;
      variable dinV     : slv(DATA_WIDTH_G-1 downto 0);
   begin
      v := r;

      -- Default all Mealy outputs to inactive
      in1RdEnV := '0';
      in2RdEnV := '0';
      wrEnV    := '0';
      dinV     := (others => '0');

      if (sel = '1') then
         -- Rule outputPipeIn1: forward pipeIn1 head into the output FIFO
         if (pipeIn1Valid = '1') and (muxOutQNotFull = '1') then
            wrEnV    := '1';
            dinV     := pipeIn1Dout;
            in1RdEnV := '1';
         end if;
      else
         -- Rule outputPipeIn2: forward pipeIn2 head into the output FIFO
         if (pipeIn2Valid = '1') and (muxOutQNotFull = '1') then
            wrEnV    := '1';
            dinV     := pipeIn2Dout;
            in2RdEnV := '1';
         end if;
      end if;

      -- Synchronous reset (dummy field only; no live state to restore)
      if (RST_ASYNC_G = false) and (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- Drive outputs
      pipeIn1RdEn <= in1RdEnV;
      pipeIn2RdEn <= in2RdEnV;
      muxOutQWrEn <= wrEnV;
      muxOutQDin  <= dinV;

   end process comb;

   --------------------------------------------------------------------------
   -- Sequential: register update (skeleton only; no live registered fields)
   --------------------------------------------------------------------------
   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G) and (rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
