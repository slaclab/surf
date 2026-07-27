-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Duplicates one incoming item to all VSZ_G output pipes through a binary
--   tree of doublers.  This file contains four design units corresponding to
--   the four levels needed for VSZ_G=16:
--
--     BinaryTreeFork_L0  (base case,  2 outputs,  2 FIFOs)
--     BinaryTreeFork_L1  (level 1,    4 outputs,  4 FIFOs + U_SubFork:L0)
--     BinaryTreeFork_L2  (level 2,    8 outputs,  8 FIFOs + U_SubFork:L1)
--     BinaryTreeFork     (top / L3,  16 outputs, 16 FIFOs + U_SubFork:L2)
--
--   VHDL does not support recursive entity instantiation; layered entities
--   replace the BSV recursive self-instantiation (OQ-FSM-BTF-02 resolved:
--   layered-entities option chosen).
--   BinaryTreeFork is the public name expected by CacheFifo.
--
--   clearAll semantics (OQ-FSM-BTF-04, resolved via OQ-FSM-06 RESOLVED.md):
--     forkQRst = rstNorm OR clearAll  (level-sensitive; SURF FifoSync safe).
--     No pulse generator needed.
--
--   Interface (OQ-FSM-BTF-01 resolved):
--     mapping.json listed Server#(req,resp); actual interface is
--     Vector#(vSz, PipeOut#(anytype)).  Port list follows fsm.md.
--
--   Concrete DATA_W_G values (OQ-FSM-BTF-03 partial):
--     readCacheQ  instantiation: DATA_W_G = 176 (ReadCacheItem)
--     atomicCacheQ instantiation: DATA_W_G = TBD (RdmaOpCode width unresolved)
--
--   SURF components (30 total):
--     surf.Fifo  GEN_SYNC_FIFO_G=true, FWFT_EN_G=true, RST_POLARITY_G='1'
--     source: surf/base/fifo/rtl/Fifo.vhd
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------


-- ===========================================================================
--  BinaryTreeFork_L0  (base case, VSZ_G = 2)
--  BSV rules: dupPipeIn, discardInput, resetAndClear[0..1]
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library surf;
use surf.StdRtlPkg.all;

entity BinaryTreeFork_L0 is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';
      RST_ASYNC_G       : boolean                := false;
      DATA_W_G          : positive               := 176;
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4;
      MEM_TYPE_G        : string                 := "distributed");
   port (
      clk           : in  sl;
      rst           : in  sl := not RST_POLARITY_G;
      clearAll      : in  sl;
      -- Upstream PipeIn
      pipeInValid   : in  sl;
      pipeInDout    : in  slv(DATA_W_G-1 downto 0);
      pipeInRdEn    : out sl;
      -- Output pipe 0  (resultVec[0])
      pipeOut0Valid : out sl;
      pipeOut0Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut0RdEn  : in  sl;
      -- Output pipe 1  (resultVec[1])
      pipeOut1Valid : out sl;
      pipeOut1Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut1RdEn  : in  sl);
end entity BinaryTreeFork_L0;

architecture rtl of BinaryTreeFork_L0 is

   -- No live registered state; one dummy field keeps RegType non-empty.
   type RegType is record
      dummy : sl;
   end record RegType;
   constant REG_INIT_C : RegType := (dummy => '0');
   signal r            : RegType := REG_INIT_C;
   signal rin          : RegType;

   signal rstNorm       : sl;
   signal forkQRst      : sl;
   signal forkQ0WrEn    : sl;
   signal forkQ1WrEn    : sl;
   signal forkQ0NotFull : sl;
   signal forkQ1NotFull : sl;
   signal forkQ0Valid   : sl;
   signal forkQ0Dout    : slv(DATA_W_G-1 downto 0);
   signal forkQ1Valid   : sl;
   signal forkQ1Dout    : slv(DATA_W_G-1 downto 0);

begin

   rstNorm  <= rst when (RST_POLARITY_G = '1') else not rst;
   forkQRst <= rstNorm or clearAll;

   -- U_ForkQ_0 : resultVec[0]
   U_ForkQ_0 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => DATA_W_G,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk   => clk,
         wr_en    => forkQ0WrEn,
         din      => pipeInDout,
         not_full => forkQ0NotFull,
         rd_clk   => clk,
         rd_en    => pipeOut0RdEn,
         dout     => forkQ0Dout,
         valid    => forkQ0Valid);

   -- U_ForkQ_1 : resultVec[1]
   U_ForkQ_1 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => DATA_W_G,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk   => clk,
         wr_en    => forkQ1WrEn,
         din      => pipeInDout,
         not_full => forkQ1NotFull,
         rd_clk   => clk,
         rd_en    => pipeOut1RdEn,
         dout     => forkQ1Dout,
         valid    => forkQ1Valid);

   pipeOut0Valid <= forkQ0Valid;
   pipeOut0Dout  <= forkQ0Dout;
   pipeOut1Valid <= forkQ1Valid;
   pipeOut1Dout  <= forkQ1Dout;

   -- Combinatorial: dupPipeIn + discardInput
   comb : process(r, rst, clearAll, pipeInValid,
                  forkQ0NotFull, forkQ1NotFull) is
      variable v      : RegType;
      variable rdEnV  : sl;
      variable fq0WrV : sl;
      variable fq1WrV : sl;
   begin
      v      := r;
      rdEnV  := '0';
      fq0WrV := '0';
      fq1WrV := '0';

      if clearAll = '1' then
         -- discardInput: drain upstream while FIFOs are being cleared
         rdEnV := pipeInValid;
      else
         -- dupPipeIn: atomically dequeue from pipeIn, enqueue to both FIFOs
         if pipeInValid = '1' and forkQ0NotFull = '1' and forkQ1NotFull = '1' then
            rdEnV  := '1';
            fq0WrV := '1';
            fq1WrV := '1';
         end if;
      end if;

      if (RST_ASYNC_G = false) and (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin        <= v;
      pipeInRdEn <= rdEnV;
      forkQ0WrEn <= fq0WrV;
      forkQ1WrEn <= fq1WrV;
   end process comb;

   seq : process(clk, rst) is
   begin
      if RST_ASYNC_G and (rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;


-- ===========================================================================
--  BinaryTreeFork_L1  (level 1, VSZ_G = 4)
--  BSV rules: dupPipeOut[0..1], resetAndClear[0..3]
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library surf;
use surf.StdRtlPkg.all;

entity BinaryTreeFork_L1 is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';
      RST_ASYNC_G       : boolean                := false;
      DATA_W_G          : positive               := 176;
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4;
      MEM_TYPE_G        : string                 := "distributed");
   port (
      clk           : in  sl;
      rst           : in  sl := not RST_POLARITY_G;
      clearAll      : in  sl;
      pipeInValid   : in  sl;
      pipeInDout    : in  slv(DATA_W_G-1 downto 0);
      pipeInRdEn    : out sl;
      pipeOut0Valid : out sl;
      pipeOut0Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut0RdEn  : in  sl;
      pipeOut1Valid : out sl;
      pipeOut1Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut1RdEn  : in  sl;
      pipeOut2Valid : out sl;
      pipeOut2Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut2RdEn  : in  sl;
      pipeOut3Valid : out sl;
      pipeOut3Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut3RdEn  : in  sl);
end entity BinaryTreeFork_L1;

architecture rtl of BinaryTreeFork_L1 is

   type RegType is record
      dummy : sl;
   end record RegType;
   constant REG_INIT_C : RegType := (dummy => '0');
   signal r            : RegType := REG_INIT_C;
   signal rin          : RegType;

   signal rstNorm       : sl;
   signal forkQRst      : sl;
   -- Sub-fork (L0) interface
   signal sfPipeInRdEn  : sl;
   signal sf0Valid      : sl;
   signal sf0Dout       : slv(DATA_W_G-1 downto 0);
   signal sf0RdEn       : sl;
   signal sf1Valid      : sl;
   signal sf1Dout       : slv(DATA_W_G-1 downto 0);
   signal sf1RdEn       : sl;
   -- ForkQ control / feedback
   signal forkQ0WrEn    : sl;
   signal forkQ1WrEn    : sl;
   signal forkQ2WrEn    : sl;
   signal forkQ3WrEn    : sl;
   signal forkQ0NotFull : sl;
   signal forkQ1NotFull : sl;
   signal forkQ2NotFull : sl;
   signal forkQ3NotFull : sl;
   signal forkQ0Valid   : sl;
   signal forkQ0Dout    : slv(DATA_W_G-1 downto 0);
   signal forkQ1Valid   : sl;
   signal forkQ1Dout    : slv(DATA_W_G-1 downto 0);
   signal forkQ2Valid   : sl;
   signal forkQ2Dout    : slv(DATA_W_G-1 downto 0);
   signal forkQ3Valid   : sl;
   signal forkQ3Dout    : slv(DATA_W_G-1 downto 0);

begin

   rstNorm    <= rst when (RST_POLARITY_G = '1') else not rst;
   forkQRst   <= rstNorm or clearAll;
   pipeInRdEn <= sfPipeInRdEn;

   -- U_SubFork : halfSzFork (VSZ_G/2 = 2 outputs)
   U_SubFork : entity surf.BinaryTreeFork_L0
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         DATA_W_G          => DATA_W_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEM_TYPE_G        => MEM_TYPE_G)
      port map (
         clk           => clk,
         rst           => rst,
         clearAll      => clearAll,
         pipeInValid   => pipeInValid,
         pipeInDout    => pipeInDout,
         pipeInRdEn    => sfPipeInRdEn,
         pipeOut0Valid => sf0Valid,
         pipeOut0Dout  => sf0Dout,
         pipeOut0RdEn  => sf0RdEn,
         pipeOut1Valid => sf1Valid,
         pipeOut1Dout  => sf1Dout,
         pipeOut1RdEn  => sf1RdEn);

   -- resultVec[0] ← halfSzPipeOutVec[0]
   U_ForkQ_0 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ0WrEn,
         din => sf0Dout,
         not_full => forkQ0NotFull,
         rd_clk => clk,
         rd_en => pipeOut0RdEn,
         dout     => forkQ0Dout,
         valid => forkQ0Valid);

   -- resultVec[1] ← halfSzPipeOutVec[0]
   U_ForkQ_1 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ1WrEn,
         din => sf0Dout,
         not_full => forkQ1NotFull,
         rd_clk => clk,
         rd_en => pipeOut1RdEn,
         dout     => forkQ1Dout,
         valid => forkQ1Valid);

   -- resultVec[2] ← halfSzPipeOutVec[1]
   U_ForkQ_2 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ2WrEn,
         din => sf1Dout,
         not_full => forkQ2NotFull,
         rd_clk => clk,
         rd_en => pipeOut2RdEn,
         dout     => forkQ2Dout,
         valid => forkQ2Valid);

   -- resultVec[3] ← halfSzPipeOutVec[1]
   U_ForkQ_3 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ3WrEn,
         din => sf1Dout,
         not_full => forkQ3NotFull,
         rd_clk => clk,
         rd_en => pipeOut3RdEn,
         dout     => forkQ3Dout,
         valid => forkQ3Valid);

   pipeOut0Valid <= forkQ0Valid; pipeOut0Dout <= forkQ0Dout;
   pipeOut1Valid <= forkQ1Valid; pipeOut1Dout <= forkQ1Dout;
   pipeOut2Valid <= forkQ2Valid; pipeOut2Dout <= forkQ2Dout;
   pipeOut3Valid <= forkQ3Valid; pipeOut3Dout <= forkQ3Dout;

   -- Combinatorial: dupPipeOut[0..1]
   comb : process(r, rst, clearAll,
                  sf0Valid, sf1Valid,
                  forkQ0NotFull, forkQ1NotFull,
                  forkQ2NotFull, forkQ3NotFull) is
      variable v      : RegType;
      variable fq0WrV : sl;
      variable fq1WrV : sl;
      variable fq2WrV : sl;
      variable fq3WrV : sl;
      variable sf0RdV : sl;
      variable sf1RdV : sl;
   begin
      v      := r;
      fq0WrV := '0'; fq1WrV := '0';
      fq2WrV := '0'; fq3WrV := '0';
      sf0RdV := '0'; sf1RdV := '0';

      if clearAll = '0' then
         -- dupPipeOut[0]: halfSzPipeOutVec[0] → resultVec[0], resultVec[1]
         if sf0Valid = '1' and forkQ0NotFull = '1' and forkQ1NotFull = '1' then
            sf0RdV := '1';
            fq0WrV := '1';
            fq1WrV := '1';
         end if;
         -- dupPipeOut[1]: halfSzPipeOutVec[1] → resultVec[2], resultVec[3]
         if sf1Valid = '1' and forkQ2NotFull = '1' and forkQ3NotFull = '1' then
            sf1RdV := '1';
            fq2WrV := '1';
            fq3WrV := '1';
         end if;
      end if;

      if (RST_ASYNC_G = false) and (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin        <= v;
      forkQ0WrEn <= fq0WrV; forkQ1WrEn <= fq1WrV;
      forkQ2WrEn <= fq2WrV; forkQ3WrEn <= fq3WrV;
      sf0RdEn    <= sf0RdV; sf1RdEn <= sf1RdV;
   end process comb;

   seq : process(clk, rst) is
   begin
      if RST_ASYNC_G and (rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;


-- ===========================================================================
--  BinaryTreeFork_L2  (level 2, VSZ_G = 8)
--  BSV rules: dupPipeOut[0..3], resetAndClear[0..7]
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library surf;
use surf.StdRtlPkg.all;

entity BinaryTreeFork_L2 is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';
      RST_ASYNC_G       : boolean                := false;
      DATA_W_G          : positive               := 176;
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4;
      MEM_TYPE_G        : string                 := "distributed");
   port (
      clk           : in  sl;
      rst           : in  sl := not RST_POLARITY_G;
      clearAll      : in  sl;
      pipeInValid   : in  sl;
      pipeInDout    : in  slv(DATA_W_G-1 downto 0);
      pipeInRdEn    : out sl;
      pipeOut0Valid : out sl;
      pipeOut0Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut0RdEn  : in  sl;
      pipeOut1Valid : out sl;
      pipeOut1Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut1RdEn  : in  sl;
      pipeOut2Valid : out sl;
      pipeOut2Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut2RdEn  : in  sl;
      pipeOut3Valid : out sl;
      pipeOut3Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut3RdEn  : in  sl;
      pipeOut4Valid : out sl;
      pipeOut4Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut4RdEn  : in  sl;
      pipeOut5Valid : out sl;
      pipeOut5Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut5RdEn  : in  sl;
      pipeOut6Valid : out sl;
      pipeOut6Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut6RdEn  : in  sl;
      pipeOut7Valid : out sl;
      pipeOut7Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut7RdEn  : in  sl);
end entity BinaryTreeFork_L2;

architecture rtl of BinaryTreeFork_L2 is

   type RegType is record
      dummy : sl;
   end record RegType;
   constant REG_INIT_C : RegType := (dummy => '0');
   signal r            : RegType := REG_INIT_C;
   signal rin          : RegType;

   signal rstNorm       : sl;
   signal forkQRst      : sl;
   -- Sub-fork (L1) interface — 4 outputs
   signal sfPipeInRdEn  : sl;
   signal sf0Valid      : sl;
   signal sf0Dout       : slv(DATA_W_G-1 downto 0);
   signal sf0RdEn       : sl;
   signal sf1Valid      : sl;
   signal sf1Dout       : slv(DATA_W_G-1 downto 0);
   signal sf1RdEn       : sl;
   signal sf2Valid      : sl;
   signal sf2Dout       : slv(DATA_W_G-1 downto 0);
   signal sf2RdEn       : sl;
   signal sf3Valid      : sl;
   signal sf3Dout       : slv(DATA_W_G-1 downto 0);
   signal sf3RdEn       : sl;
   -- ForkQ control / feedback
   signal forkQ0WrEn    : sl;
   signal forkQ1WrEn    : sl;
   signal forkQ2WrEn    : sl;
   signal forkQ3WrEn    : sl;
   signal forkQ4WrEn    : sl;
   signal forkQ5WrEn    : sl;
   signal forkQ6WrEn    : sl;
   signal forkQ7WrEn    : sl;
   signal forkQ0NotFull : sl;
   signal forkQ1NotFull : sl;
   signal forkQ2NotFull : sl;
   signal forkQ3NotFull : sl;
   signal forkQ4NotFull : sl;
   signal forkQ5NotFull : sl;
   signal forkQ6NotFull : sl;
   signal forkQ7NotFull : sl;
   signal forkQ0Valid   : sl;
   signal forkQ0Dout    : slv(DATA_W_G-1 downto 0);
   signal forkQ1Valid   : sl;
   signal forkQ1Dout    : slv(DATA_W_G-1 downto 0);
   signal forkQ2Valid   : sl;
   signal forkQ2Dout    : slv(DATA_W_G-1 downto 0);
   signal forkQ3Valid   : sl;
   signal forkQ3Dout    : slv(DATA_W_G-1 downto 0);
   signal forkQ4Valid   : sl;
   signal forkQ4Dout    : slv(DATA_W_G-1 downto 0);
   signal forkQ5Valid   : sl;
   signal forkQ5Dout    : slv(DATA_W_G-1 downto 0);
   signal forkQ6Valid   : sl;
   signal forkQ6Dout    : slv(DATA_W_G-1 downto 0);
   signal forkQ7Valid   : sl;
   signal forkQ7Dout    : slv(DATA_W_G-1 downto 0);

begin

   rstNorm    <= rst when (RST_POLARITY_G = '1') else not rst;
   forkQRst   <= rstNorm or clearAll;
   pipeInRdEn <= sfPipeInRdEn;

   -- U_SubFork : halfSzFork (VSZ_G/2 = 4 outputs)
   U_SubFork : entity surf.BinaryTreeFork_L1
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         DATA_W_G          => DATA_W_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEM_TYPE_G        => MEM_TYPE_G)
      port map (
         clk           => clk,
         rst           => rst,
         clearAll      => clearAll,
         pipeInValid   => pipeInValid,
         pipeInDout    => pipeInDout,
         pipeInRdEn    => sfPipeInRdEn,
         pipeOut0Valid => sf0Valid,
         pipeOut0Dout  => sf0Dout,
         pipeOut0RdEn  => sf0RdEn,
         pipeOut1Valid => sf1Valid,
         pipeOut1Dout  => sf1Dout,
         pipeOut1RdEn  => sf1RdEn,
         pipeOut2Valid => sf2Valid,
         pipeOut2Dout  => sf2Dout,
         pipeOut2RdEn  => sf2RdEn,
         pipeOut3Valid => sf3Valid,
         pipeOut3Dout  => sf3Dout,
         pipeOut3RdEn  => sf3RdEn);

   U_ForkQ_0 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ0WrEn,
         din => sf0Dout,
         not_full => forkQ0NotFull,
         rd_clk => clk,
         rd_en => pipeOut0RdEn,
         dout     => forkQ0Dout,
         valid => forkQ0Valid);

   U_ForkQ_1 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ1WrEn,
         din => sf0Dout,
         not_full => forkQ1NotFull,
         rd_clk => clk,
         rd_en => pipeOut1RdEn,
         dout     => forkQ1Dout,
         valid => forkQ1Valid);

   U_ForkQ_2 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ2WrEn,
         din => sf1Dout,
         not_full => forkQ2NotFull,
         rd_clk => clk,
         rd_en => pipeOut2RdEn,
         dout     => forkQ2Dout,
         valid => forkQ2Valid);

   U_ForkQ_3 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ3WrEn,
         din => sf1Dout,
         not_full => forkQ3NotFull,
         rd_clk => clk,
         rd_en => pipeOut3RdEn,
         dout     => forkQ3Dout,
         valid => forkQ3Valid);

   U_ForkQ_4 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ4WrEn,
         din => sf2Dout,
         not_full => forkQ4NotFull,
         rd_clk => clk,
         rd_en => pipeOut4RdEn,
         dout     => forkQ4Dout,
         valid => forkQ4Valid);

   U_ForkQ_5 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ5WrEn,
         din => sf2Dout,
         not_full => forkQ5NotFull,
         rd_clk => clk,
         rd_en => pipeOut5RdEn,
         dout     => forkQ5Dout,
         valid => forkQ5Valid);

   U_ForkQ_6 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ6WrEn,
         din => sf3Dout,
         not_full => forkQ6NotFull,
         rd_clk => clk,
         rd_en => pipeOut6RdEn,
         dout     => forkQ6Dout,
         valid => forkQ6Valid);

   U_ForkQ_7 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ7WrEn,
         din => sf3Dout,
         not_full => forkQ7NotFull,
         rd_clk => clk,
         rd_en => pipeOut7RdEn,
         dout     => forkQ7Dout,
         valid => forkQ7Valid);

   pipeOut0Valid <= forkQ0Valid; pipeOut0Dout <= forkQ0Dout;
   pipeOut1Valid <= forkQ1Valid; pipeOut1Dout <= forkQ1Dout;
   pipeOut2Valid <= forkQ2Valid; pipeOut2Dout <= forkQ2Dout;
   pipeOut3Valid <= forkQ3Valid; pipeOut3Dout <= forkQ3Dout;
   pipeOut4Valid <= forkQ4Valid; pipeOut4Dout <= forkQ4Dout;
   pipeOut5Valid <= forkQ5Valid; pipeOut5Dout <= forkQ5Dout;
   pipeOut6Valid <= forkQ6Valid; pipeOut6Dout <= forkQ6Dout;
   pipeOut7Valid <= forkQ7Valid; pipeOut7Dout <= forkQ7Dout;

   -- Combinatorial: dupPipeOut[0..3]
   comb : process(r, rst, clearAll,
                  sf0Valid, sf1Valid, sf2Valid, sf3Valid,
                  forkQ0NotFull, forkQ1NotFull,
                  forkQ2NotFull, forkQ3NotFull,
                  forkQ4NotFull, forkQ5NotFull,
                  forkQ6NotFull, forkQ7NotFull) is
      variable v      : RegType;
      variable fq0WrV : sl; variable fq1WrV : sl;
      variable fq2WrV : sl; variable fq3WrV : sl;
      variable fq4WrV : sl; variable fq5WrV : sl;
      variable fq6WrV : sl; variable fq7WrV : sl;
      variable sf0RdV : sl; variable sf1RdV : sl;
      variable sf2RdV : sl; variable sf3RdV : sl;
   begin
      v      := r;
      fq0WrV := '0'; fq1WrV := '0'; fq2WrV := '0'; fq3WrV := '0';
      fq4WrV := '0'; fq5WrV := '0'; fq6WrV := '0'; fq7WrV := '0';
      sf0RdV := '0'; sf1RdV := '0'; sf2RdV := '0'; sf3RdV := '0';

      if clearAll = '0' then
         if sf0Valid = '1' and forkQ0NotFull = '1' and forkQ1NotFull = '1' then
            sf0RdV := '1'; fq0WrV := '1'; fq1WrV := '1';
         end if;
         if sf1Valid = '1' and forkQ2NotFull = '1' and forkQ3NotFull = '1' then
            sf1RdV := '1'; fq2WrV := '1'; fq3WrV := '1';
         end if;
         if sf2Valid = '1' and forkQ4NotFull = '1' and forkQ5NotFull = '1' then
            sf2RdV := '1'; fq4WrV := '1'; fq5WrV := '1';
         end if;
         if sf3Valid = '1' and forkQ6NotFull = '1' and forkQ7NotFull = '1' then
            sf3RdV := '1'; fq6WrV := '1'; fq7WrV := '1';
         end if;
      end if;

      if (RST_ASYNC_G = false) and (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin        <= v;
      forkQ0WrEn <= fq0WrV; forkQ1WrEn <= fq1WrV;
      forkQ2WrEn <= fq2WrV; forkQ3WrEn <= fq3WrV;
      forkQ4WrEn <= fq4WrV; forkQ5WrEn <= fq5WrV;
      forkQ6WrEn <= fq6WrV; forkQ7WrEn <= fq7WrV;
      sf0RdEn    <= sf0RdV; sf1RdEn <= sf1RdV;
      sf2RdEn    <= sf2RdV; sf3RdEn <= sf3RdV;
   end process comb;

   seq : process(clk, rst) is
   begin
      if RST_ASYNC_G and (rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;


-- ===========================================================================
--  BinaryTreeFork  (top / level 3, VSZ_G = 16)
--  BSV rules: dupPipeOut[0..7], resetAndClear[0..15]
--  Public entity name consumed by CacheFifo.
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library surf;
use surf.StdRtlPkg.all;

entity BinaryTreeFork is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';
      RST_ASYNC_G       : boolean                := false;
      DATA_W_G          : positive               := 176;
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4;
      MEM_TYPE_G        : string                 := "distributed");
   port (
      clk            : in  sl;
      rst            : in  sl := not RST_POLARITY_G;
      clearAll       : in  sl;
      pipeInValid    : in  sl;
      pipeInDout     : in  slv(DATA_W_G-1 downto 0);
      pipeInRdEn     : out sl;
      pipeOut0Valid  : out sl;
      pipeOut0Dout   : out slv(DATA_W_G-1 downto 0);
      pipeOut0RdEn   : in  sl;
      pipeOut1Valid  : out sl;
      pipeOut1Dout   : out slv(DATA_W_G-1 downto 0);
      pipeOut1RdEn   : in  sl;
      pipeOut2Valid  : out sl;
      pipeOut2Dout   : out slv(DATA_W_G-1 downto 0);
      pipeOut2RdEn   : in  sl;
      pipeOut3Valid  : out sl;
      pipeOut3Dout   : out slv(DATA_W_G-1 downto 0);
      pipeOut3RdEn   : in  sl;
      pipeOut4Valid  : out sl;
      pipeOut4Dout   : out slv(DATA_W_G-1 downto 0);
      pipeOut4RdEn   : in  sl;
      pipeOut5Valid  : out sl;
      pipeOut5Dout   : out slv(DATA_W_G-1 downto 0);
      pipeOut5RdEn   : in  sl;
      pipeOut6Valid  : out sl;
      pipeOut6Dout   : out slv(DATA_W_G-1 downto 0);
      pipeOut6RdEn   : in  sl;
      pipeOut7Valid  : out sl;
      pipeOut7Dout   : out slv(DATA_W_G-1 downto 0);
      pipeOut7RdEn   : in  sl;
      pipeOut8Valid  : out sl;
      pipeOut8Dout   : out slv(DATA_W_G-1 downto 0);
      pipeOut8RdEn   : in  sl;
      pipeOut9Valid  : out sl;
      pipeOut9Dout   : out slv(DATA_W_G-1 downto 0);
      pipeOut9RdEn   : in  sl;
      pipeOut10Valid : out sl;
      pipeOut10Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut10RdEn  : in  sl;
      pipeOut11Valid : out sl;
      pipeOut11Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut11RdEn  : in  sl;
      pipeOut12Valid : out sl;
      pipeOut12Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut12RdEn  : in  sl;
      pipeOut13Valid : out sl;
      pipeOut13Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut13RdEn  : in  sl;
      pipeOut14Valid : out sl;
      pipeOut14Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut14RdEn  : in  sl;
      pipeOut15Valid : out sl;
      pipeOut15Dout  : out slv(DATA_W_G-1 downto 0);
      pipeOut15RdEn  : in  sl);
end entity BinaryTreeFork;

architecture rtl of BinaryTreeFork is

   type RegType is record
      dummy : sl;
   end record RegType;
   constant REG_INIT_C : RegType := (dummy => '0');
   signal r            : RegType := REG_INIT_C;
   signal rin          : RegType;

   signal rstNorm        : sl;
   signal forkQRst       : sl;
   -- Sub-fork (L2) interface — 8 outputs
   signal sfPipeInRdEn   : sl;
   signal sf0Valid       : sl;
   signal sf0Dout        : slv(DATA_W_G-1 downto 0);
   signal sf0RdEn        : sl;
   signal sf1Valid       : sl;
   signal sf1Dout        : slv(DATA_W_G-1 downto 0);
   signal sf1RdEn        : sl;
   signal sf2Valid       : sl;
   signal sf2Dout        : slv(DATA_W_G-1 downto 0);
   signal sf2RdEn        : sl;
   signal sf3Valid       : sl;
   signal sf3Dout        : slv(DATA_W_G-1 downto 0);
   signal sf3RdEn        : sl;
   signal sf4Valid       : sl;
   signal sf4Dout        : slv(DATA_W_G-1 downto 0);
   signal sf4RdEn        : sl;
   signal sf5Valid       : sl;
   signal sf5Dout        : slv(DATA_W_G-1 downto 0);
   signal sf5RdEn        : sl;
   signal sf6Valid       : sl;
   signal sf6Dout        : slv(DATA_W_G-1 downto 0);
   signal sf6RdEn        : sl;
   signal sf7Valid       : sl;
   signal sf7Dout        : slv(DATA_W_G-1 downto 0);
   signal sf7RdEn        : sl;
   -- ForkQ write enables
   signal forkQ0WrEn     : sl;
   signal forkQ1WrEn     : sl;
   signal forkQ2WrEn     : sl;
   signal forkQ3WrEn     : sl;
   signal forkQ4WrEn     : sl;
   signal forkQ5WrEn     : sl;
   signal forkQ6WrEn     : sl;
   signal forkQ7WrEn     : sl;
   signal forkQ8WrEn     : sl;
   signal forkQ9WrEn     : sl;
   signal forkQ10WrEn    : sl;
   signal forkQ11WrEn    : sl;
   signal forkQ12WrEn    : sl;
   signal forkQ13WrEn    : sl;
   signal forkQ14WrEn    : sl;
   signal forkQ15WrEn    : sl;
   -- ForkQ not_full feedback
   signal forkQ0NotFull  : sl;
   signal forkQ1NotFull  : sl;
   signal forkQ2NotFull  : sl;
   signal forkQ3NotFull  : sl;
   signal forkQ4NotFull  : sl;
   signal forkQ5NotFull  : sl;
   signal forkQ6NotFull  : sl;
   signal forkQ7NotFull  : sl;
   signal forkQ8NotFull  : sl;
   signal forkQ9NotFull  : sl;
   signal forkQ10NotFull : sl;
   signal forkQ11NotFull : sl;
   signal forkQ12NotFull : sl;
   signal forkQ13NotFull : sl;
   signal forkQ14NotFull : sl;
   signal forkQ15NotFull : sl;
   -- ForkQ valid / dout
   signal forkQ0Valid    : sl; signal forkQ0Dout : slv(DATA_W_G-1 downto 0);
   signal forkQ1Valid    : sl; signal forkQ1Dout : slv(DATA_W_G-1 downto 0);
   signal forkQ2Valid    : sl; signal forkQ2Dout : slv(DATA_W_G-1 downto 0);
   signal forkQ3Valid    : sl; signal forkQ3Dout : slv(DATA_W_G-1 downto 0);
   signal forkQ4Valid    : sl; signal forkQ4Dout : slv(DATA_W_G-1 downto 0);
   signal forkQ5Valid    : sl; signal forkQ5Dout : slv(DATA_W_G-1 downto 0);
   signal forkQ6Valid    : sl; signal forkQ6Dout : slv(DATA_W_G-1 downto 0);
   signal forkQ7Valid    : sl; signal forkQ7Dout : slv(DATA_W_G-1 downto 0);
   signal forkQ8Valid    : sl; signal forkQ8Dout : slv(DATA_W_G-1 downto 0);
   signal forkQ9Valid    : sl; signal forkQ9Dout : slv(DATA_W_G-1 downto 0);
   signal forkQ10Valid   : sl; signal forkQ10Dout : slv(DATA_W_G-1 downto 0);
   signal forkQ11Valid   : sl; signal forkQ11Dout : slv(DATA_W_G-1 downto 0);
   signal forkQ12Valid   : sl; signal forkQ12Dout : slv(DATA_W_G-1 downto 0);
   signal forkQ13Valid   : sl; signal forkQ13Dout : slv(DATA_W_G-1 downto 0);
   signal forkQ14Valid   : sl; signal forkQ14Dout : slv(DATA_W_G-1 downto 0);
   signal forkQ15Valid   : sl; signal forkQ15Dout : slv(DATA_W_G-1 downto 0);

begin

   rstNorm    <= rst when (RST_POLARITY_G = '1') else not rst;
   forkQRst   <= rstNorm or clearAll;
   pipeInRdEn <= sfPipeInRdEn;

   -- U_SubFork : halfSzFork (VSZ_G/2 = 8 outputs)
   U_SubFork : entity surf.BinaryTreeFork_L2
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         DATA_W_G          => DATA_W_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEM_TYPE_G        => MEM_TYPE_G)
      port map (
         clk           => clk,
         rst           => rst,
         clearAll      => clearAll,
         pipeInValid   => pipeInValid,
         pipeInDout    => pipeInDout,
         pipeInRdEn    => sfPipeInRdEn,
         pipeOut0Valid => sf0Valid,
         pipeOut0Dout => sf0Dout,
         pipeOut0RdEn => sf0RdEn,
         pipeOut1Valid => sf1Valid,
         pipeOut1Dout => sf1Dout,
         pipeOut1RdEn => sf1RdEn,
         pipeOut2Valid => sf2Valid,
         pipeOut2Dout => sf2Dout,
         pipeOut2RdEn => sf2RdEn,
         pipeOut3Valid => sf3Valid,
         pipeOut3Dout => sf3Dout,
         pipeOut3RdEn => sf3RdEn,
         pipeOut4Valid => sf4Valid,
         pipeOut4Dout => sf4Dout,
         pipeOut4RdEn => sf4RdEn,
         pipeOut5Valid => sf5Valid,
         pipeOut5Dout => sf5Dout,
         pipeOut5RdEn => sf5RdEn,
         pipeOut6Valid => sf6Valid,
         pipeOut6Dout => sf6Dout,
         pipeOut6RdEn => sf6RdEn,
         pipeOut7Valid => sf7Valid,
         pipeOut7Dout => sf7Dout,
         pipeOut7RdEn => sf7RdEn);

   U_ForkQ_0 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ0WrEn,
         din => sf0Dout,
         not_full => forkQ0NotFull,
         rd_clk => clk,
         rd_en => pipeOut0RdEn,
         dout     => forkQ0Dout,
         valid => forkQ0Valid);

   U_ForkQ_1 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ1WrEn,
         din => sf0Dout,
         not_full => forkQ1NotFull,
         rd_clk => clk,
         rd_en => pipeOut1RdEn,
         dout     => forkQ1Dout,
         valid => forkQ1Valid);

   U_ForkQ_2 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ2WrEn,
         din => sf1Dout,
         not_full => forkQ2NotFull,
         rd_clk => clk,
         rd_en => pipeOut2RdEn,
         dout     => forkQ2Dout,
         valid => forkQ2Valid);

   U_ForkQ_3 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ3WrEn,
         din => sf1Dout,
         not_full => forkQ3NotFull,
         rd_clk => clk,
         rd_en => pipeOut3RdEn,
         dout     => forkQ3Dout,
         valid => forkQ3Valid);

   U_ForkQ_4 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ4WrEn,
         din => sf2Dout,
         not_full => forkQ4NotFull,
         rd_clk => clk,
         rd_en => pipeOut4RdEn,
         dout     => forkQ4Dout,
         valid => forkQ4Valid);

   U_ForkQ_5 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ5WrEn,
         din => sf2Dout,
         not_full => forkQ5NotFull,
         rd_clk => clk,
         rd_en => pipeOut5RdEn,
         dout     => forkQ5Dout,
         valid => forkQ5Valid);

   U_ForkQ_6 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ6WrEn,
         din => sf3Dout,
         not_full => forkQ6NotFull,
         rd_clk => clk,
         rd_en => pipeOut6RdEn,
         dout     => forkQ6Dout,
         valid => forkQ6Valid);

   U_ForkQ_7 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ7WrEn,
         din => sf3Dout,
         not_full => forkQ7NotFull,
         rd_clk => clk,
         rd_en => pipeOut7RdEn,
         dout     => forkQ7Dout,
         valid => forkQ7Valid);

   U_ForkQ_8 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ8WrEn,
         din => sf4Dout,
         not_full => forkQ8NotFull,
         rd_clk => clk,
         rd_en => pipeOut8RdEn,
         dout     => forkQ8Dout,
         valid => forkQ8Valid);

   U_ForkQ_9 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ9WrEn,
         din => sf4Dout,
         not_full => forkQ9NotFull,
         rd_clk => clk,
         rd_en => pipeOut9RdEn,
         dout     => forkQ9Dout,
         valid => forkQ9Valid);

   U_ForkQ_10 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ10WrEn,
         din => sf5Dout,
         not_full => forkQ10NotFull,
         rd_clk => clk,
         rd_en => pipeOut10RdEn,
         dout     => forkQ10Dout,
         valid => forkQ10Valid);

   U_ForkQ_11 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ11WrEn,
         din => sf5Dout,
         not_full => forkQ11NotFull,
         rd_clk => clk,
         rd_en => pipeOut11RdEn,
         dout     => forkQ11Dout,
         valid => forkQ11Valid);

   U_ForkQ_12 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ12WrEn,
         din => sf6Dout,
         not_full => forkQ12NotFull,
         rd_clk => clk,
         rd_en => pipeOut12RdEn,
         dout     => forkQ12Dout,
         valid => forkQ12Valid);

   U_ForkQ_13 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ13WrEn,
         din => sf6Dout,
         not_full => forkQ13NotFull,
         rd_clk => clk,
         rd_en => pipeOut13RdEn,
         dout     => forkQ13Dout,
         valid => forkQ13Valid);

   U_ForkQ_14 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ14WrEn,
         din => sf7Dout,
         not_full => forkQ14NotFull,
         rd_clk => clk,
         rd_en => pipeOut14RdEn,
         dout     => forkQ14Dout,
         valid => forkQ14Valid);

   U_ForkQ_15 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => DATA_W_G, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => forkQRst,
         wr_clk => clk,
         wr_en => forkQ15WrEn,
         din => sf7Dout,
         not_full => forkQ15NotFull,
         rd_clk => clk,
         rd_en => pipeOut15RdEn,
         dout     => forkQ15Dout,
         valid => forkQ15Valid);

   pipeOut0Valid  <= forkQ0Valid; pipeOut0Dout <= forkQ0Dout;
   pipeOut1Valid  <= forkQ1Valid; pipeOut1Dout <= forkQ1Dout;
   pipeOut2Valid  <= forkQ2Valid; pipeOut2Dout <= forkQ2Dout;
   pipeOut3Valid  <= forkQ3Valid; pipeOut3Dout <= forkQ3Dout;
   pipeOut4Valid  <= forkQ4Valid; pipeOut4Dout <= forkQ4Dout;
   pipeOut5Valid  <= forkQ5Valid; pipeOut5Dout <= forkQ5Dout;
   pipeOut6Valid  <= forkQ6Valid; pipeOut6Dout <= forkQ6Dout;
   pipeOut7Valid  <= forkQ7Valid; pipeOut7Dout <= forkQ7Dout;
   pipeOut8Valid  <= forkQ8Valid; pipeOut8Dout <= forkQ8Dout;
   pipeOut9Valid  <= forkQ9Valid; pipeOut9Dout <= forkQ9Dout;
   pipeOut10Valid <= forkQ10Valid; pipeOut10Dout <= forkQ10Dout;
   pipeOut11Valid <= forkQ11Valid; pipeOut11Dout <= forkQ11Dout;
   pipeOut12Valid <= forkQ12Valid; pipeOut12Dout <= forkQ12Dout;
   pipeOut13Valid <= forkQ13Valid; pipeOut13Dout <= forkQ13Dout;
   pipeOut14Valid <= forkQ14Valid; pipeOut14Dout <= forkQ14Dout;
   pipeOut15Valid <= forkQ15Valid; pipeOut15Dout <= forkQ15Dout;

   -- Combinatorial: dupPipeOut[0..7]
   comb : process(r, rst, clearAll,
                  sf0Valid, sf1Valid, sf2Valid, sf3Valid,
                  sf4Valid, sf5Valid, sf6Valid, sf7Valid,
                  forkQ0NotFull, forkQ1NotFull,
                  forkQ2NotFull, forkQ3NotFull,
                  forkQ4NotFull, forkQ5NotFull,
                  forkQ6NotFull, forkQ7NotFull,
                  forkQ8NotFull, forkQ9NotFull,
                  forkQ10NotFull, forkQ11NotFull,
                  forkQ12NotFull, forkQ13NotFull,
                  forkQ14NotFull, forkQ15NotFull) is
      variable v       : RegType;
      variable fq0WrV  : sl; variable fq1WrV : sl;
      variable fq2WrV  : sl; variable fq3WrV : sl;
      variable fq4WrV  : sl; variable fq5WrV : sl;
      variable fq6WrV  : sl; variable fq7WrV : sl;
      variable fq8WrV  : sl; variable fq9WrV : sl;
      variable fq10WrV : sl; variable fq11WrV : sl;
      variable fq12WrV : sl; variable fq13WrV : sl;
      variable fq14WrV : sl; variable fq15WrV : sl;
      variable sf0RdV  : sl; variable sf1RdV : sl;
      variable sf2RdV  : sl; variable sf3RdV : sl;
      variable sf4RdV  : sl; variable sf5RdV : sl;
      variable sf6RdV  : sl; variable sf7RdV : sl;
   begin
      v       := r;
      fq0WrV  := '0'; fq1WrV := '0'; fq2WrV := '0'; fq3WrV := '0';
      fq4WrV  := '0'; fq5WrV := '0'; fq6WrV := '0'; fq7WrV := '0';
      fq8WrV  := '0'; fq9WrV := '0'; fq10WrV := '0'; fq11WrV := '0';
      fq12WrV := '0'; fq13WrV := '0'; fq14WrV := '0'; fq15WrV := '0';
      sf0RdV  := '0'; sf1RdV := '0'; sf2RdV := '0'; sf3RdV := '0';
      sf4RdV  := '0'; sf5RdV := '0'; sf6RdV := '0'; sf7RdV := '0';

      if clearAll = '0' then
         if sf0Valid = '1' and forkQ0NotFull = '1' and forkQ1NotFull = '1' then
            sf0RdV := '1'; fq0WrV := '1'; fq1WrV := '1';
         end if;
         if sf1Valid = '1' and forkQ2NotFull = '1' and forkQ3NotFull = '1' then
            sf1RdV := '1'; fq2WrV := '1'; fq3WrV := '1';
         end if;
         if sf2Valid = '1' and forkQ4NotFull = '1' and forkQ5NotFull = '1' then
            sf2RdV := '1'; fq4WrV := '1'; fq5WrV := '1';
         end if;
         if sf3Valid = '1' and forkQ6NotFull = '1' and forkQ7NotFull = '1' then
            sf3RdV := '1'; fq6WrV := '1'; fq7WrV := '1';
         end if;
         if sf4Valid = '1' and forkQ8NotFull = '1' and forkQ9NotFull = '1' then
            sf4RdV := '1'; fq8WrV := '1'; fq9WrV := '1';
         end if;
         if sf5Valid = '1' and forkQ10NotFull = '1' and forkQ11NotFull = '1' then
            sf5RdV := '1'; fq10WrV := '1'; fq11WrV := '1';
         end if;
         if sf6Valid = '1' and forkQ12NotFull = '1' and forkQ13NotFull = '1' then
            sf6RdV := '1'; fq12WrV := '1'; fq13WrV := '1';
         end if;
         if sf7Valid = '1' and forkQ14NotFull = '1' and forkQ15NotFull = '1' then
            sf7RdV := '1'; fq14WrV := '1'; fq15WrV := '1';
         end if;
      end if;

      if (RST_ASYNC_G = false) and (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin         <= v;
      forkQ0WrEn  <= fq0WrV; forkQ1WrEn <= fq1WrV;
      forkQ2WrEn  <= fq2WrV; forkQ3WrEn <= fq3WrV;
      forkQ4WrEn  <= fq4WrV; forkQ5WrEn <= fq5WrV;
      forkQ6WrEn  <= fq6WrV; forkQ7WrEn <= fq7WrV;
      forkQ8WrEn  <= fq8WrV; forkQ9WrEn <= fq9WrV;
      forkQ10WrEn <= fq10WrV; forkQ11WrEn <= fq11WrV;
      forkQ12WrEn <= fq12WrV; forkQ13WrEn <= fq13WrV;
      forkQ14WrEn <= fq14WrV; forkQ15WrEn <= fq15WrV;
      sf0RdEn     <= sf0RdV; sf1RdEn <= sf1RdV;
      sf2RdEn     <= sf2RdV; sf3RdEn <= sf3RdV;
      sf4RdEn     <= sf4RdV; sf5RdEn <= sf5RdV;
      sf6RdEn     <= sf6RdV; sf7RdEn <= sf7RdV;
   end process comb;

   seq : process(clk, rst) is
   begin
      if RST_ASYNC_G and (rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
