-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Reduces VSZ_G Maybe#(anytype) input pipes to one output using
--   left-priority pairwise comparison at each tree level.
--   Structural complement to BinaryTreeFork.
--
--   Five design units (layered to replace BSV recursive self-instantiation;
--   OQ-FSM-RS-02 resolved — same approach as OQ-FSM-BTF-02):
--
--     RecursiveSearch_L0  (base, VSZ=1,  1 searchQ FIFO, popOut rule)
--     RecursiveSearch_L1  (VSZ=2,   1 pairCmp,  1 FIFO + U_SubSearch:L0)
--     RecursiveSearch_L2  (VSZ=4,   2 pairCmp,  2 FIFOs + U_SubSearch:L1)
--     RecursiveSearch_L3  (VSZ=8,   4 pairCmp,  4 FIFOs + U_SubSearch:L2)
--     RecursiveSearch     (top,VSZ=16, 8 pairCmp, 8 FIFOs + U_SubSearch:L3)
--
--   Interface correction (OQ-FSM-RS-01 resolved):
--     mapping.json listed Server#(SearchReq,SearchResp) — WRONG.
--     Port list follows RecursiveSearch.fsm.md.
--     Ports: clearAll, inputVec_i_{valid,dout,rdEn} (i=0..VSZ_G-1),
--            resultValid, resultDout, resultRdEn.
--
--   Maybe#(anytype) valid-tag (OQ-FSM-RS-05 resolved, RESOLVED.md):
--     BSV deriving(Bits) packs tag as MSB → bit[ITEM_W_G].
--     winner = left when left(ITEM_W_G)='1' else right.
--
--   clearAll semantics (OQ-FSM-RS-04 resolved via OQ-FSM-06/BTF-04):
--     nextLayerQRst = rstNorm OR clearAll  (level-sensitive; FifoSync safe).
--     No pulse generator required.
--
--   ITEM_W_G is the bit width of anytype (not including the valid tag).
--   All FIFO DATA_WIDTH_G = ITEM_W_G+1  (the packed Maybe#(anytype) word).
--   Concrete values: readCacheQ = 176; atomicCacheQ = TBD (OQ-FSM-RS-03).
--
--   SURF components (16 total for VSZ_G=16):
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
--  RecursiveSearch_L0  (base case, VSZ=1)
--  BSV rules: popOut, discardInput[0], resetAndClear
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library surf;
use surf.StdRtlPkg.all;

entity RecursiveSearch_L0 is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';
      RST_ASYNC_G       : boolean                := false;
      ITEM_W_G          : positive               := 176;
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4;
      MEM_TYPE_G        : string                 := "distributed");
   port (
      clk              : in  sl;
      rst              : in  sl := not RST_POLARITY_G;
      clearAll         : in  sl;
      -- Single input lane (inputVec[0])
      inputVec_0_valid : in  sl;
      inputVec_0_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_0_rdEn  : out sl;
      -- Result output
      resultValid      : out sl;
      resultDout       : out slv(ITEM_W_G downto 0);
      resultRdEn       : in  sl);
end entity RecursiveSearch_L0;

architecture rtl of RecursiveSearch_L0 is

   -- No live registered state; dummy field keeps RegType non-empty.
   type RegType is record
      dummy : sl;
   end record RegType;
   constant REG_INIT_C : RegType := (dummy => '0');
   signal r            : RegType := REG_INIT_C;
   signal rin          : RegType;

   signal rstNorm        : sl;
   signal searchQRst     : sl;
   signal searchQWrEn    : sl;
   signal searchQNotFull : sl;

begin

   rstNorm    <= rst when (RST_POLARITY_G = '1') else not rst;
   searchQRst <= rstNorm or clearAll;

   -- U_SearchQ: resultQ in BSV source
   U_SearchQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => ITEM_W_G+1,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => searchQRst,
         wr_clk   => clk,
         wr_en    => searchQWrEn,
         din      => inputVec_0_dout,
         not_full => searchQNotFull,
         rd_clk   => clk,
         rd_en    => resultRdEn,
         dout     => resultDout,
         valid    => resultValid);

   -- popOut / discardInput
   comb : process (r, rst, clearAll, inputVec_0_valid, searchQNotFull) is
      variable v     : RegType;
      variable rdEnV : sl;
      variable wrEnV : sl;
   begin
      v     := r;
      rdEnV := '0';
      wrEnV := '0';

      if clearAll = '1' then
         -- discardInput[0]: drain upstream (searchQRst clears FIFO via level)
         rdEnV := inputVec_0_valid;
      else
         -- popOut: forward input to resultQ
         if inputVec_0_valid = '1' and searchQNotFull = '1' then
            rdEnV := '1';
            wrEnV := '1';
         end if;
      end if;

      if (RST_ASYNC_G = false) and (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin             <= v;
      inputVec_0_rdEn <= rdEnV;
      searchQWrEn     <= wrEnV;
   end process comb;

   seq : process (clk, rst) is
   begin
      if RST_ASYNC_G and (rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;


-- ===========================================================================
--  RecursiveSearch_L1  (VSZ=2, 1 pairCmp rule)
--  BSV rules: pairCmp[0], discardInput[0..1], resetAndClear[0]
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library surf;
use surf.StdRtlPkg.all;

entity RecursiveSearch_L1 is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';
      RST_ASYNC_G       : boolean                := false;
      ITEM_W_G          : positive               := 176;
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4;
      MEM_TYPE_G        : string                 := "distributed");
   port (
      clk              : in  sl;
      rst              : in  sl := not RST_POLARITY_G;
      clearAll         : in  sl;
      inputVec_0_valid : in  sl;
      inputVec_0_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_0_rdEn  : out sl;
      inputVec_1_valid : in  sl;
      inputVec_1_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_1_rdEn  : out sl;
      resultValid      : out sl;
      resultDout       : out slv(ITEM_W_G downto 0);
      resultRdEn       : in  sl);
end entity RecursiveSearch_L1;

architecture rtl of RecursiveSearch_L1 is

   type RegType is record
      dummy : sl;
   end record RegType;
   constant REG_INIT_C : RegType := (dummy => '0');
   signal r            : RegType := REG_INIT_C;
   signal rin          : RegType;

   signal rstNorm       : sl;
   signal nextLayerQRst : sl;
   -- U_NextLayerQ_0
   signal nlqDin0       : slv(ITEM_W_G downto 0);
   signal nlqWrEn0      : sl;
   signal nlq0NotFull   : sl;
   signal nlq0Valid     : sl;
   signal nlq0Dout      : slv(ITEM_W_G downto 0);
   signal nlq0RdEn      : sl;

begin

   rstNorm       <= rst when (RST_POLARITY_G = '1') else not rst;
   nextLayerQRst <= rstNorm or clearAll;

   -- Winner-select: left(ITEM_W_G)=valid tag (MSB); left has priority
   nlqDin0 <= inputVec_0_dout when inputVec_0_dout(ITEM_W_G) = '1' else
              inputVec_1_dout;

   U_NextLayerQ_0 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => ITEM_W_G+1,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => nextLayerQRst,
         wr_clk   => clk,
         wr_en    => nlqWrEn0,
         din      => nlqDin0,
         not_full => nlq0NotFull,
         rd_clk   => clk,
         rd_en    => nlq0RdEn,
         dout     => nlq0Dout,
         valid    => nlq0Valid);

   -- Sub-search (L0) consumes U_NextLayerQ_0 output
   U_SubSearch : entity surf.RecursiveSearch_L0
      generic map (
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         ITEM_W_G          => ITEM_W_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEM_TYPE_G        => MEM_TYPE_G)
      port map (
         clk              => clk,
         rst              => rst,
         clearAll         => clearAll,
         inputVec_0_valid => nlq0Valid,
         inputVec_0_dout  => nlq0Dout,
         inputVec_0_rdEn  => nlq0RdEn,
         resultValid      => resultValid,
         resultDout       => resultDout,
         resultRdEn       => resultRdEn);

   -- pairCmp[0] / discardInput[0..1]
   comb : process (r, rst, clearAll,
                   inputVec_0_valid, inputVec_1_valid,
                   nlq0NotFull) is
      variable v      : RegType;
      variable rdEn0V : sl;
      variable rdEn1V : sl;
      variable wrEn0V : sl;
   begin
      v      := r;
      rdEn0V := '0';
      rdEn1V := '0';
      wrEn0V := '0';

      if clearAll = '1' then
         rdEn0V := inputVec_0_valid;
         rdEn1V := inputVec_1_valid;
      else
         -- pairCmp[0]: both must be valid; winner selected by concurrent mux
         if inputVec_0_valid = '1' and inputVec_1_valid = '1' and nlq0NotFull = '1' then
            rdEn0V := '1';
            rdEn1V := '1';
            wrEn0V := '1';
         end if;
      end if;

      if (RST_ASYNC_G = false) and (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin             <= v;
      inputVec_0_rdEn <= rdEn0V;
      inputVec_1_rdEn <= rdEn1V;
      nlqWrEn0        <= wrEn0V;
   end process comb;

   seq : process (clk, rst) is
   begin
      if RST_ASYNC_G and (rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;


-- ===========================================================================
--  RecursiveSearch_L2  (VSZ=4, 2 pairCmp rules)
--  BSV rules: pairCmp[0..1], discardInput[0..3], resetAndClear[0..1]
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library surf;
use surf.StdRtlPkg.all;

entity RecursiveSearch_L2 is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';
      RST_ASYNC_G       : boolean                := false;
      ITEM_W_G          : positive               := 176;
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4;
      MEM_TYPE_G        : string                 := "distributed");
   port (
      clk              : in  sl;
      rst              : in  sl := not RST_POLARITY_G;
      clearAll         : in  sl;
      inputVec_0_valid : in  sl;
      inputVec_0_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_0_rdEn  : out sl;
      inputVec_1_valid : in  sl;
      inputVec_1_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_1_rdEn  : out sl;
      inputVec_2_valid : in  sl;
      inputVec_2_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_2_rdEn  : out sl;
      inputVec_3_valid : in  sl;
      inputVec_3_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_3_rdEn  : out sl;
      resultValid      : out sl;
      resultDout       : out slv(ITEM_W_G downto 0);
      resultRdEn       : in  sl);
end entity RecursiveSearch_L2;

architecture rtl of RecursiveSearch_L2 is

   type RegType is record
      dummy : sl;
   end record RegType;
   constant REG_INIT_C : RegType := (dummy => '0');
   signal r            : RegType := REG_INIT_C;
   signal rin          : RegType;

   signal rstNorm       : sl;
   signal nextLayerQRst : sl;
   signal nlqDin0       : slv(ITEM_W_G downto 0);
   signal nlqDin1       : slv(ITEM_W_G downto 0);
   signal nlqWrEn0      : sl;
   signal nlqWrEn1      : sl;
   signal nlq0NotFull   : sl;
   signal nlq1NotFull   : sl;
   signal nlq0Valid     : sl;
   signal nlq1Valid     : sl;
   signal nlq0Dout      : slv(ITEM_W_G downto 0);
   signal nlq1Dout      : slv(ITEM_W_G downto 0);
   signal nlq0RdEn      : sl;
   signal nlq1RdEn      : sl;

begin

   rstNorm       <= rst when (RST_POLARITY_G = '1') else not rst;
   nextLayerQRst <= rstNorm or clearAll;

   nlqDin0 <= inputVec_0_dout when inputVec_0_dout(ITEM_W_G) = '1' else inputVec_1_dout;
   nlqDin1 <= inputVec_2_dout when inputVec_2_dout(ITEM_W_G) = '1' else inputVec_3_dout;

   U_NextLayerQ_0 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => ITEM_W_G+1, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => nextLayerQRst,
         wr_clk => clk,
         wr_en => nlqWrEn0,
         din => nlqDin0,
         not_full => nlq0NotFull,
         rd_clk => clk,
         rd_en => nlq0RdEn,
         dout     => nlq0Dout,
         valid => nlq0Valid);

   U_NextLayerQ_1 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => ITEM_W_G+1, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => nextLayerQRst,
         wr_clk => clk,
         wr_en => nlqWrEn1,
         din => nlqDin1,
         not_full => nlq1NotFull,
         rd_clk => clk,
         rd_en => nlq1RdEn,
         dout     => nlq1Dout,
         valid => nlq1Valid);

   U_SubSearch : entity surf.RecursiveSearch_L1
      generic map (
         TPD_G             => TPD_G, RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G, ITEM_W_G => ITEM_W_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G, MEM_TYPE_G => MEM_TYPE_G)
      port map (
         clk              => clk,
         rst              => rst,
         clearAll         => clearAll,
         inputVec_0_valid => nlq0Valid,
         inputVec_0_dout  => nlq0Dout,
         inputVec_0_rdEn  => nlq0RdEn,
         inputVec_1_valid => nlq1Valid,
         inputVec_1_dout  => nlq1Dout,
         inputVec_1_rdEn  => nlq1RdEn,
         resultValid      => resultValid,
         resultDout       => resultDout,
         resultRdEn       => resultRdEn);

   comb : process (r, rst, clearAll,
                   inputVec_0_valid, inputVec_1_valid,
                   inputVec_2_valid, inputVec_3_valid,
                   nlq0NotFull, nlq1NotFull) is
      variable v      : RegType;
      variable rdEn0V : sl;
      variable rdEn1V : sl;
      variable rdEn2V : sl;
      variable rdEn3V : sl;
      variable wrEn0V : sl;
      variable wrEn1V : sl;
   begin
      v      := r;
      rdEn0V := '0'; rdEn1V := '0'; rdEn2V := '0'; rdEn3V := '0';
      wrEn0V := '0'; wrEn1V := '0';

      if clearAll = '1' then
         rdEn0V := inputVec_0_valid;
         rdEn1V := inputVec_1_valid;
         rdEn2V := inputVec_2_valid;
         rdEn3V := inputVec_3_valid;
      else
         -- pairCmp[0]: pair (0,1) → U_NextLayerQ_0
         if inputVec_0_valid = '1' and inputVec_1_valid = '1' and nlq0NotFull = '1' then
            rdEn0V := '1'; rdEn1V := '1'; wrEn0V := '1';
         end if;
         -- pairCmp[1]: pair (2,3) → U_NextLayerQ_1
         if inputVec_2_valid = '1' and inputVec_3_valid = '1' and nlq1NotFull = '1' then
            rdEn2V := '1'; rdEn3V := '1'; wrEn1V := '1';
         end if;
      end if;

      if (RST_ASYNC_G = false) and (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin             <= v;
      inputVec_0_rdEn <= rdEn0V;
      inputVec_1_rdEn <= rdEn1V;
      inputVec_2_rdEn <= rdEn2V;
      inputVec_3_rdEn <= rdEn3V;
      nlqWrEn0        <= wrEn0V;
      nlqWrEn1        <= wrEn1V;
   end process comb;

   seq : process (clk, rst) is
   begin
      if RST_ASYNC_G and (rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;


-- ===========================================================================
--  RecursiveSearch_L3  (VSZ=8, 4 pairCmp rules)
--  BSV rules: pairCmp[0..3], discardInput[0..7], resetAndClear[0..3]
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library surf;
use surf.StdRtlPkg.all;

entity RecursiveSearch_L3 is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';
      RST_ASYNC_G       : boolean                := false;
      ITEM_W_G          : positive               := 176;
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4;
      MEM_TYPE_G        : string                 := "distributed");
   port (
      clk              : in  sl;
      rst              : in  sl := not RST_POLARITY_G;
      clearAll         : in  sl;
      inputVec_0_valid : in  sl;
      inputVec_0_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_0_rdEn  : out sl;
      inputVec_1_valid : in  sl;
      inputVec_1_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_1_rdEn  : out sl;
      inputVec_2_valid : in  sl;
      inputVec_2_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_2_rdEn  : out sl;
      inputVec_3_valid : in  sl;
      inputVec_3_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_3_rdEn  : out sl;
      inputVec_4_valid : in  sl;
      inputVec_4_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_4_rdEn  : out sl;
      inputVec_5_valid : in  sl;
      inputVec_5_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_5_rdEn  : out sl;
      inputVec_6_valid : in  sl;
      inputVec_6_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_6_rdEn  : out sl;
      inputVec_7_valid : in  sl;
      inputVec_7_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_7_rdEn  : out sl;
      resultValid      : out sl;
      resultDout       : out slv(ITEM_W_G downto 0);
      resultRdEn       : in  sl);
end entity RecursiveSearch_L3;

architecture rtl of RecursiveSearch_L3 is

   type RegType is record
      dummy : sl;
   end record RegType;
   constant REG_INIT_C : RegType := (dummy => '0');
   signal r            : RegType := REG_INIT_C;
   signal rin          : RegType;

   signal rstNorm       : sl;
   signal nextLayerQRst : sl;
   signal nlqDin0       : slv(ITEM_W_G downto 0);
   signal nlqDin1       : slv(ITEM_W_G downto 0);
   signal nlqDin2       : slv(ITEM_W_G downto 0);
   signal nlqDin3       : slv(ITEM_W_G downto 0);
   signal nlqWrEn0      : sl;
   signal nlqWrEn1      : sl;
   signal nlqWrEn2      : sl;
   signal nlqWrEn3      : sl;
   signal nlq0NotFull   : sl;
   signal nlq1NotFull   : sl;
   signal nlq2NotFull   : sl;
   signal nlq3NotFull   : sl;
   signal nlq0Valid     : sl;
   signal nlq1Valid     : sl;
   signal nlq2Valid     : sl;
   signal nlq3Valid     : sl;
   signal nlq0Dout      : slv(ITEM_W_G downto 0);
   signal nlq1Dout      : slv(ITEM_W_G downto 0);
   signal nlq2Dout      : slv(ITEM_W_G downto 0);
   signal nlq3Dout      : slv(ITEM_W_G downto 0);
   signal nlq0RdEn      : sl;
   signal nlq1RdEn      : sl;
   signal nlq2RdEn      : sl;
   signal nlq3RdEn      : sl;

begin

   rstNorm       <= rst when (RST_POLARITY_G = '1') else not rst;
   nextLayerQRst <= rstNorm or clearAll;

   nlqDin0 <= inputVec_0_dout when inputVec_0_dout(ITEM_W_G) = '1' else inputVec_1_dout;
   nlqDin1 <= inputVec_2_dout when inputVec_2_dout(ITEM_W_G) = '1' else inputVec_3_dout;
   nlqDin2 <= inputVec_4_dout when inputVec_4_dout(ITEM_W_G) = '1' else inputVec_5_dout;
   nlqDin3 <= inputVec_6_dout when inputVec_6_dout(ITEM_W_G) = '1' else inputVec_7_dout;

   U_NextLayerQ_0 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => ITEM_W_G+1, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => nextLayerQRst,
         wr_clk => clk,
         wr_en => nlqWrEn0,
         din => nlqDin0,
         not_full => nlq0NotFull,
         rd_clk => clk,
         rd_en => nlq0RdEn,
         dout     => nlq0Dout,
         valid => nlq0Valid);

   U_NextLayerQ_1 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => ITEM_W_G+1, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => nextLayerQRst,
         wr_clk => clk,
         wr_en => nlqWrEn1,
         din => nlqDin1,
         not_full => nlq1NotFull,
         rd_clk => clk,
         rd_en => nlq1RdEn,
         dout     => nlq1Dout,
         valid => nlq1Valid);

   U_NextLayerQ_2 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => ITEM_W_G+1, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => nextLayerQRst,
         wr_clk => clk,
         wr_en => nlqWrEn2,
         din => nlqDin2,
         not_full => nlq2NotFull,
         rd_clk => clk,
         rd_en => nlq2RdEn,
         dout     => nlq2Dout,
         valid => nlq2Valid);

   U_NextLayerQ_3 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => ITEM_W_G+1, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => nextLayerQRst,
         wr_clk => clk,
         wr_en => nlqWrEn3,
         din => nlqDin3,
         not_full => nlq3NotFull,
         rd_clk => clk,
         rd_en => nlq3RdEn,
         dout     => nlq3Dout,
         valid => nlq3Valid);

   U_SubSearch : entity surf.RecursiveSearch_L2
      generic map (
         TPD_G             => TPD_G, RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G, ITEM_W_G => ITEM_W_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G, MEM_TYPE_G => MEM_TYPE_G)
      port map (
         clk              => clk,
         rst => rst,
         clearAll => clearAll,
         inputVec_0_valid => nlq0Valid,
         inputVec_0_dout => nlq0Dout,
         inputVec_0_rdEn => nlq0RdEn,
         inputVec_1_valid => nlq1Valid,
         inputVec_1_dout => nlq1Dout,
         inputVec_1_rdEn => nlq1RdEn,
         inputVec_2_valid => nlq2Valid,
         inputVec_2_dout => nlq2Dout,
         inputVec_2_rdEn => nlq2RdEn,
         inputVec_3_valid => nlq3Valid,
         inputVec_3_dout => nlq3Dout,
         inputVec_3_rdEn => nlq3RdEn,
         resultValid      => resultValid,
         resultDout       => resultDout,
         resultRdEn       => resultRdEn);

   comb : process (r, rst, clearAll,
                   inputVec_0_valid, inputVec_1_valid,
                   inputVec_2_valid, inputVec_3_valid,
                   inputVec_4_valid, inputVec_5_valid,
                   inputVec_6_valid, inputVec_7_valid,
                   nlq0NotFull, nlq1NotFull, nlq2NotFull, nlq3NotFull) is
      variable v      : RegType;
      variable rdEn0V : sl; variable rdEn1V : sl;
      variable rdEn2V : sl; variable rdEn3V : sl;
      variable rdEn4V : sl; variable rdEn5V : sl;
      variable rdEn6V : sl; variable rdEn7V : sl;
      variable wrEn0V : sl; variable wrEn1V : sl;
      variable wrEn2V : sl; variable wrEn3V : sl;
   begin
      v      := r;
      rdEn0V := '0'; rdEn1V := '0'; rdEn2V := '0'; rdEn3V := '0';
      rdEn4V := '0'; rdEn5V := '0'; rdEn6V := '0'; rdEn7V := '0';
      wrEn0V := '0'; wrEn1V := '0'; wrEn2V := '0'; wrEn3V := '0';

      if clearAll = '1' then
         rdEn0V := inputVec_0_valid; rdEn1V := inputVec_1_valid;
         rdEn2V := inputVec_2_valid; rdEn3V := inputVec_3_valid;
         rdEn4V := inputVec_4_valid; rdEn5V := inputVec_5_valid;
         rdEn6V := inputVec_6_valid; rdEn7V := inputVec_7_valid;
      else
         if inputVec_0_valid = '1' and inputVec_1_valid = '1' and nlq0NotFull = '1' then
            rdEn0V := '1'; rdEn1V := '1'; wrEn0V := '1';
         end if;
         if inputVec_2_valid = '1' and inputVec_3_valid = '1' and nlq1NotFull = '1' then
            rdEn2V := '1'; rdEn3V := '1'; wrEn1V := '1';
         end if;
         if inputVec_4_valid = '1' and inputVec_5_valid = '1' and nlq2NotFull = '1' then
            rdEn4V := '1'; rdEn5V := '1'; wrEn2V := '1';
         end if;
         if inputVec_6_valid = '1' and inputVec_7_valid = '1' and nlq3NotFull = '1' then
            rdEn6V := '1'; rdEn7V := '1'; wrEn3V := '1';
         end if;
      end if;

      if (RST_ASYNC_G = false) and (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin             <= v;
      inputVec_0_rdEn <= rdEn0V; inputVec_1_rdEn <= rdEn1V;
      inputVec_2_rdEn <= rdEn2V; inputVec_3_rdEn <= rdEn3V;
      inputVec_4_rdEn <= rdEn4V; inputVec_5_rdEn <= rdEn5V;
      inputVec_6_rdEn <= rdEn6V; inputVec_7_rdEn <= rdEn7V;
      nlqWrEn0        <= wrEn0V; nlqWrEn1 <= wrEn1V;
      nlqWrEn2        <= wrEn2V; nlqWrEn3 <= wrEn3V;
   end process comb;

   seq : process (clk, rst) is
   begin
      if RST_ASYNC_G and (rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;


-- ===========================================================================
--  RecursiveSearch  (top / VSZ=16, 8 pairCmp rules)
--  Public entity name consumed by CacheFifo.
--  BSV rules: pairCmp[0..7], discardInput[0..15], resetAndClear[0..7]
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library surf;
use surf.StdRtlPkg.all;

entity RecursiveSearch is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';
      RST_ASYNC_G       : boolean                := false;
      ITEM_W_G          : positive               := 176;
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4;
      MEM_TYPE_G        : string                 := "distributed");
   port (
      clk               : in  sl;
      rst               : in  sl := not RST_POLARITY_G;
      clearAll          : in  sl;
      -- 16 input lanes
      inputVec_0_valid  : in  sl;
      inputVec_0_dout   : in  slv(ITEM_W_G downto 0);
      inputVec_0_rdEn   : out sl;
      inputVec_1_valid  : in  sl;
      inputVec_1_dout   : in  slv(ITEM_W_G downto 0);
      inputVec_1_rdEn   : out sl;
      inputVec_2_valid  : in  sl;
      inputVec_2_dout   : in  slv(ITEM_W_G downto 0);
      inputVec_2_rdEn   : out sl;
      inputVec_3_valid  : in  sl;
      inputVec_3_dout   : in  slv(ITEM_W_G downto 0);
      inputVec_3_rdEn   : out sl;
      inputVec_4_valid  : in  sl;
      inputVec_4_dout   : in  slv(ITEM_W_G downto 0);
      inputVec_4_rdEn   : out sl;
      inputVec_5_valid  : in  sl;
      inputVec_5_dout   : in  slv(ITEM_W_G downto 0);
      inputVec_5_rdEn   : out sl;
      inputVec_6_valid  : in  sl;
      inputVec_6_dout   : in  slv(ITEM_W_G downto 0);
      inputVec_6_rdEn   : out sl;
      inputVec_7_valid  : in  sl;
      inputVec_7_dout   : in  slv(ITEM_W_G downto 0);
      inputVec_7_rdEn   : out sl;
      inputVec_8_valid  : in  sl;
      inputVec_8_dout   : in  slv(ITEM_W_G downto 0);
      inputVec_8_rdEn   : out sl;
      inputVec_9_valid  : in  sl;
      inputVec_9_dout   : in  slv(ITEM_W_G downto 0);
      inputVec_9_rdEn   : out sl;
      inputVec_10_valid : in  sl;
      inputVec_10_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_10_rdEn  : out sl;
      inputVec_11_valid : in  sl;
      inputVec_11_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_11_rdEn  : out sl;
      inputVec_12_valid : in  sl;
      inputVec_12_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_12_rdEn  : out sl;
      inputVec_13_valid : in  sl;
      inputVec_13_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_13_rdEn  : out sl;
      inputVec_14_valid : in  sl;
      inputVec_14_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_14_rdEn  : out sl;
      inputVec_15_valid : in  sl;
      inputVec_15_dout  : in  slv(ITEM_W_G downto 0);
      inputVec_15_rdEn  : out sl;
      -- Result output
      resultValid       : out sl;
      resultDout        : out slv(ITEM_W_G downto 0);
      resultRdEn        : in  sl);
end entity RecursiveSearch;

architecture rtl of RecursiveSearch is

   type RegType is record
      dummy : sl;
   end record RegType;
   constant REG_INIT_C : RegType := (dummy => '0');
   signal r            : RegType := REG_INIT_C;
   signal rin          : RegType;

   signal rstNorm       : sl;
   signal nextLayerQRst : sl;
   -- Winner-select FIFO din
   signal nlqDin0       : slv(ITEM_W_G downto 0);
   signal nlqDin1       : slv(ITEM_W_G downto 0);
   signal nlqDin2       : slv(ITEM_W_G downto 0);
   signal nlqDin3       : slv(ITEM_W_G downto 0);
   signal nlqDin4       : slv(ITEM_W_G downto 0);
   signal nlqDin5       : slv(ITEM_W_G downto 0);
   signal nlqDin6       : slv(ITEM_W_G downto 0);
   signal nlqDin7       : slv(ITEM_W_G downto 0);
   -- FIFO write enables
   signal nlqWrEn0      : sl;
   signal nlqWrEn1      : sl;
   signal nlqWrEn2      : sl;
   signal nlqWrEn3      : sl;
   signal nlqWrEn4      : sl;
   signal nlqWrEn5      : sl;
   signal nlqWrEn6      : sl;
   signal nlqWrEn7      : sl;
   -- FIFO not_full feedback
   signal nlq0NotFull   : sl;
   signal nlq1NotFull   : sl;
   signal nlq2NotFull   : sl;
   signal nlq3NotFull   : sl;
   signal nlq4NotFull   : sl;
   signal nlq5NotFull   : sl;
   signal nlq6NotFull   : sl;
   signal nlq7NotFull   : sl;
   -- FIFO valid / dout
   signal nlq0Valid     : sl; signal nlq0Dout : slv(ITEM_W_G downto 0);
   signal nlq1Valid     : sl; signal nlq1Dout : slv(ITEM_W_G downto 0);
   signal nlq2Valid     : sl; signal nlq2Dout : slv(ITEM_W_G downto 0);
   signal nlq3Valid     : sl; signal nlq3Dout : slv(ITEM_W_G downto 0);
   signal nlq4Valid     : sl; signal nlq4Dout : slv(ITEM_W_G downto 0);
   signal nlq5Valid     : sl; signal nlq5Dout : slv(ITEM_W_G downto 0);
   signal nlq6Valid     : sl; signal nlq6Dout : slv(ITEM_W_G downto 0);
   signal nlq7Valid     : sl; signal nlq7Dout : slv(ITEM_W_G downto 0);
   -- FIFO read enables (driven by U_SubSearch)
   signal nlq0RdEn      : sl;
   signal nlq1RdEn      : sl;
   signal nlq2RdEn      : sl;
   signal nlq3RdEn      : sl;
   signal nlq4RdEn      : sl;
   signal nlq5RdEn      : sl;
   signal nlq6RdEn      : sl;
   signal nlq7RdEn      : sl;

begin

   rstNorm       <= rst when (RST_POLARITY_G = '1') else not rst;
   nextLayerQRst <= rstNorm or clearAll;

   -- 8 concurrent winner-select muxes (one per pairCmp instance)
   nlqDin0 <= inputVec_0_dout  when inputVec_0_dout(ITEM_W_G) = '1'  else inputVec_1_dout;
   nlqDin1 <= inputVec_2_dout  when inputVec_2_dout(ITEM_W_G) = '1'  else inputVec_3_dout;
   nlqDin2 <= inputVec_4_dout  when inputVec_4_dout(ITEM_W_G) = '1'  else inputVec_5_dout;
   nlqDin3 <= inputVec_6_dout  when inputVec_6_dout(ITEM_W_G) = '1'  else inputVec_7_dout;
   nlqDin4 <= inputVec_8_dout  when inputVec_8_dout(ITEM_W_G) = '1'  else inputVec_9_dout;
   nlqDin5 <= inputVec_10_dout when inputVec_10_dout(ITEM_W_G) = '1' else inputVec_11_dout;
   nlqDin6 <= inputVec_12_dout when inputVec_12_dout(ITEM_W_G) = '1' else inputVec_13_dout;
   nlqDin7 <= inputVec_14_dout when inputVec_14_dout(ITEM_W_G) = '1' else inputVec_15_dout;

   U_NextLayerQ_0 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => ITEM_W_G+1, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => nextLayerQRst,
         wr_clk => clk,
         wr_en => nlqWrEn0,
         din => nlqDin0,
         not_full => nlq0NotFull,
         rd_clk => clk,
         rd_en => nlq0RdEn,
         dout     => nlq0Dout,
         valid => nlq0Valid);

   U_NextLayerQ_1 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => ITEM_W_G+1, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => nextLayerQRst,
         wr_clk => clk,
         wr_en => nlqWrEn1,
         din => nlqDin1,
         not_full => nlq1NotFull,
         rd_clk => clk,
         rd_en => nlq1RdEn,
         dout     => nlq1Dout,
         valid => nlq1Valid);

   U_NextLayerQ_2 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => ITEM_W_G+1, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => nextLayerQRst,
         wr_clk => clk,
         wr_en => nlqWrEn2,
         din => nlqDin2,
         not_full => nlq2NotFull,
         rd_clk => clk,
         rd_en => nlq2RdEn,
         dout     => nlq2Dout,
         valid => nlq2Valid);

   U_NextLayerQ_3 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => ITEM_W_G+1, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => nextLayerQRst,
         wr_clk => clk,
         wr_en => nlqWrEn3,
         din => nlqDin3,
         not_full => nlq3NotFull,
         rd_clk => clk,
         rd_en => nlq3RdEn,
         dout     => nlq3Dout,
         valid => nlq3Valid);

   U_NextLayerQ_4 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => ITEM_W_G+1, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => nextLayerQRst,
         wr_clk => clk,
         wr_en => nlqWrEn4,
         din => nlqDin4,
         not_full => nlq4NotFull,
         rd_clk => clk,
         rd_en => nlq4RdEn,
         dout     => nlq4Dout,
         valid => nlq4Valid);

   U_NextLayerQ_5 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => ITEM_W_G+1, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => nextLayerQRst,
         wr_clk => clk,
         wr_en => nlqWrEn5,
         din => nlqDin5,
         not_full => nlq5NotFull,
         rd_clk => clk,
         rd_en => nlq5RdEn,
         dout     => nlq5Dout,
         valid => nlq5Valid);

   U_NextLayerQ_6 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => ITEM_W_G+1, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => nextLayerQRst,
         wr_clk => clk,
         wr_en => nlqWrEn6,
         din => nlqDin6,
         not_full => nlq6NotFull,
         rd_clk => clk,
         rd_en => nlq6RdEn,
         dout     => nlq6Dout,
         valid => nlq6Valid);

   U_NextLayerQ_7 : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G, RST_POLARITY_G => '1', RST_ASYNC_G => false,
         GEN_SYNC_FIFO_G => true, FWFT_EN_G => true,
         DATA_WIDTH_G    => ITEM_W_G+1, ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         MEMORY_TYPE_G   => MEM_TYPE_G)
      port map (
         rst      => nextLayerQRst,
         wr_clk => clk,
         wr_en => nlqWrEn7,
         din => nlqDin7,
         not_full => nlq7NotFull,
         rd_clk => clk,
         rd_en => nlq7RdEn,
         dout     => nlq7Dout,
         valid => nlq7Valid);

   U_SubSearch : entity surf.RecursiveSearch_L3
      generic map (
         TPD_G             => TPD_G, RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G       => RST_ASYNC_G, ITEM_W_G => ITEM_W_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G, MEM_TYPE_G => MEM_TYPE_G)
      port map (
         clk              => clk,
         rst => rst,
         clearAll => clearAll,
         inputVec_0_valid => nlq0Valid,
         inputVec_0_dout => nlq0Dout,
         inputVec_0_rdEn => nlq0RdEn,
         inputVec_1_valid => nlq1Valid,
         inputVec_1_dout => nlq1Dout,
         inputVec_1_rdEn => nlq1RdEn,
         inputVec_2_valid => nlq2Valid,
         inputVec_2_dout => nlq2Dout,
         inputVec_2_rdEn => nlq2RdEn,
         inputVec_3_valid => nlq3Valid,
         inputVec_3_dout => nlq3Dout,
         inputVec_3_rdEn => nlq3RdEn,
         inputVec_4_valid => nlq4Valid,
         inputVec_4_dout => nlq4Dout,
         inputVec_4_rdEn => nlq4RdEn,
         inputVec_5_valid => nlq5Valid,
         inputVec_5_dout => nlq5Dout,
         inputVec_5_rdEn => nlq5RdEn,
         inputVec_6_valid => nlq6Valid,
         inputVec_6_dout => nlq6Dout,
         inputVec_6_rdEn => nlq6RdEn,
         inputVec_7_valid => nlq7Valid,
         inputVec_7_dout => nlq7Dout,
         inputVec_7_rdEn => nlq7RdEn,
         resultValid      => resultValid,
         resultDout       => resultDout,
         resultRdEn       => resultRdEn);

   -- 8 concurrent pairCmp rules + discardInput[0..15]
   comb : process (r, rst, clearAll,
                   inputVec_0_valid, inputVec_1_valid,
                   inputVec_2_valid, inputVec_3_valid,
                   inputVec_4_valid, inputVec_5_valid,
                   inputVec_6_valid, inputVec_7_valid,
                   inputVec_8_valid, inputVec_9_valid,
                   inputVec_10_valid, inputVec_11_valid,
                   inputVec_12_valid, inputVec_13_valid,
                   inputVec_14_valid, inputVec_15_valid,
                   nlq0NotFull, nlq1NotFull, nlq2NotFull, nlq3NotFull,
                   nlq4NotFull, nlq5NotFull, nlq6NotFull, nlq7NotFull) is
      variable v       : RegType;
      variable rdEn0V  : sl; variable rdEn1V : sl;
      variable rdEn2V  : sl; variable rdEn3V : sl;
      variable rdEn4V  : sl; variable rdEn5V : sl;
      variable rdEn6V  : sl; variable rdEn7V : sl;
      variable rdEn8V  : sl; variable rdEn9V : sl;
      variable rdEn10V : sl; variable rdEn11V : sl;
      variable rdEn12V : sl; variable rdEn13V : sl;
      variable rdEn14V : sl; variable rdEn15V : sl;
      variable wrEn0V  : sl; variable wrEn1V : sl;
      variable wrEn2V  : sl; variable wrEn3V : sl;
      variable wrEn4V  : sl; variable wrEn5V : sl;
      variable wrEn6V  : sl; variable wrEn7V : sl;
   begin
      v       := r;
      rdEn0V  := '0'; rdEn1V := '0'; rdEn2V := '0'; rdEn3V := '0';
      rdEn4V  := '0'; rdEn5V := '0'; rdEn6V := '0'; rdEn7V := '0';
      rdEn8V  := '0'; rdEn9V := '0'; rdEn10V := '0'; rdEn11V := '0';
      rdEn12V := '0'; rdEn13V := '0'; rdEn14V := '0'; rdEn15V := '0';
      wrEn0V  := '0'; wrEn1V := '0'; wrEn2V := '0'; wrEn3V := '0';
      wrEn4V  := '0'; wrEn5V := '0'; wrEn6V := '0'; wrEn7V := '0';

      if clearAll = '1' then
         -- discardInput[j] for j=0..15: drain all input lanes
         rdEn0V  := inputVec_0_valid; rdEn1V := inputVec_1_valid;
         rdEn2V  := inputVec_2_valid; rdEn3V := inputVec_3_valid;
         rdEn4V  := inputVec_4_valid; rdEn5V := inputVec_5_valid;
         rdEn6V  := inputVec_6_valid; rdEn7V := inputVec_7_valid;
         rdEn8V  := inputVec_8_valid; rdEn9V := inputVec_9_valid;
         rdEn10V := inputVec_10_valid; rdEn11V := inputVec_11_valid;
         rdEn12V := inputVec_12_valid; rdEn13V := inputVec_13_valid;
         rdEn14V := inputVec_14_valid; rdEn15V := inputVec_15_valid;
      else
         -- pairCmp[0]: pair (0,1)  → U_NextLayerQ_0
         if inputVec_0_valid = '1' and inputVec_1_valid = '1' and nlq0NotFull = '1' then
            rdEn0V := '1'; rdEn1V := '1'; wrEn0V := '1';
         end if;
         -- pairCmp[1]: pair (2,3)  → U_NextLayerQ_1
         if inputVec_2_valid = '1' and inputVec_3_valid = '1' and nlq1NotFull = '1' then
            rdEn2V := '1'; rdEn3V := '1'; wrEn1V := '1';
         end if;
         -- pairCmp[2]: pair (4,5)  → U_NextLayerQ_2
         if inputVec_4_valid = '1' and inputVec_5_valid = '1' and nlq2NotFull = '1' then
            rdEn4V := '1'; rdEn5V := '1'; wrEn2V := '1';
         end if;
         -- pairCmp[3]: pair (6,7)  → U_NextLayerQ_3
         if inputVec_6_valid = '1' and inputVec_7_valid = '1' and nlq3NotFull = '1' then
            rdEn6V := '1'; rdEn7V := '1'; wrEn3V := '1';
         end if;
         -- pairCmp[4]: pair (8,9)  → U_NextLayerQ_4
         if inputVec_8_valid = '1' and inputVec_9_valid = '1' and nlq4NotFull = '1' then
            rdEn8V := '1'; rdEn9V := '1'; wrEn4V := '1';
         end if;
         -- pairCmp[5]: pair (10,11) → U_NextLayerQ_5
         if inputVec_10_valid = '1' and inputVec_11_valid = '1' and nlq5NotFull = '1' then
            rdEn10V := '1'; rdEn11V := '1'; wrEn5V := '1';
         end if;
         -- pairCmp[6]: pair (12,13) → U_NextLayerQ_6
         if inputVec_12_valid = '1' and inputVec_13_valid = '1' and nlq6NotFull = '1' then
            rdEn12V := '1'; rdEn13V := '1'; wrEn6V := '1';
         end if;
         -- pairCmp[7]: pair (14,15) → U_NextLayerQ_7
         if inputVec_14_valid = '1' and inputVec_15_valid = '1' and nlq7NotFull = '1' then
            rdEn14V := '1'; rdEn15V := '1'; wrEn7V := '1';
         end if;
      end if;

      if (RST_ASYNC_G = false) and (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin              <= v;
      inputVec_0_rdEn  <= rdEn0V; inputVec_1_rdEn <= rdEn1V;
      inputVec_2_rdEn  <= rdEn2V; inputVec_3_rdEn <= rdEn3V;
      inputVec_4_rdEn  <= rdEn4V; inputVec_5_rdEn <= rdEn5V;
      inputVec_6_rdEn  <= rdEn6V; inputVec_7_rdEn <= rdEn7V;
      inputVec_8_rdEn  <= rdEn8V; inputVec_9_rdEn <= rdEn9V;
      inputVec_10_rdEn <= rdEn10V; inputVec_11_rdEn <= rdEn11V;
      inputVec_12_rdEn <= rdEn12V; inputVec_13_rdEn <= rdEn13V;
      inputVec_14_rdEn <= rdEn14V; inputVec_15_rdEn <= rdEn15V;
      nlqWrEn0         <= wrEn0V; nlqWrEn1 <= wrEn1V;
      nlqWrEn2         <= wrEn2V; nlqWrEn3 <= wrEn3V;
      nlqWrEn4         <= wrEn4V; nlqWrEn5 <= wrEn5V;
      nlqWrEn6         <= wrEn6V; nlqWrEn7 <= wrEn7V;
   end process comb;

   seq : process (clk, rst) is
   begin
      if RST_ASYNC_G and (rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
