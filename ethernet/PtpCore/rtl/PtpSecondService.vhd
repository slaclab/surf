-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Shared conversion between a Q16-nanosecond scalar and seconds.
--
-- Divides by one decimal second in Q16 nanoseconds. Two owners need this
-- conversion and neither needs it often: manual PHC phase preparation and the
-- servo's rate command and phase normalization. One shared converter with
-- per-owner held responses costs less than two private instances.
--
-- Both quotient and the exact truncation remainder are published at the full
-- converter width, so a consumer applies its own fit check rather than
-- inheriting a truncation here. The truncating owners consume both outputs:
-- the quotient becomes whole seconds and the remainder becomes the subsecond
-- fraction. The rounding owner consumes the quotient only.
--
-- Arbitration is round-robin with a per-owner held response, so an owner whose
-- result is unread is skipped and cannot block the other. Cancellation is
-- owner-local. Sharing adds one response-register cycle to the converter
-- latency and serializes concurrent requests; both belong in the endpoint
-- service bound.
--
-- All ports use clk. Input ready is combinational per owner; result valid and
-- payload are registered. Clients hold valid and payload until ready and
-- exclude cancel/reset edges from transfers.
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
use surf.PtpMathPkg.all;
use surf.PtpPkg.all;

entity PtpSecondService is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      NUM_CLIENTS_G  : positive := 2;
      -- Signed dividend width. The servo's phase path retains signed128
      -- because its forward/offset storage has signed128 contracts; manual
      -- PHASE narrows to signed96 at admission but shares this instance.
      WIDTH_G : positive := 128);
   port (
      clk : in  sl;
      rst : in  sl;
      -- Owner-local cancellation, one bit per client.
      cancel      : in  slv(NUM_CLIENTS_G-1 downto 0);
      requests    : in  PtpConstDivideRequestArray(NUM_CLIENTS_G-1 downto 0)(operand(WIDTH_G-1 downto 0));
      inputReady  : out slv(NUM_CLIENTS_G-1 downto 0);
      results     : out PtpConstDivideResultArray(NUM_CLIENTS_G-1 downto 0)(value(WIDTH_G-1 downto 0), remainder(WIDTH_G-1 downto 0));
      resultReady : in  slv(NUM_CLIENTS_G-1 downto 0));
end entity PtpSecondService;

architecture rtl of PtpSecondService is

   type RegType is record
      active     : sl;
      owner      : natural range 0 to NUM_CLIENTS_G-1;
      cursor     : natural range 0 to NUM_CLIENTS_G-1;
      inputReady : slv(NUM_CLIENTS_G-1 downto 0);
      results    : PtpConstDivideResultArray(NUM_CLIENTS_G-1 downto 0)(value(WIDTH_G-1 downto 0), remainder(WIDTH_G-1 downto 0));
   end record;

   constant REG_INIT_C : RegType := (
      active     => '0',
      owner      => 0,
      cursor     => 0,
      inputReady => (others => '0'),
      results    => (others => ptpConstDivideResultInit(WIDTH_G)));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal coreCancel  : sl;
   signal coreValid   : sl;
   signal coreReady   : sl;
   signal coreRound   : sl;
   signal coreOperand : slv(WIDTH_G-1 downto 0);

   signal secondRequest : PtpConstDivideRequestType(operand((WIDTH_G)-1 downto 0));
   signal secondResult  : PtpConstDivideResultType(value((WIDTH_G)-1 downto 0), remainder((WIDTH_G)-1 downto 0));

begin

   secondRequest <=
   (
      valid        => coreValid,
      roundNearest => coreRound,
      operand      => coreOperand
   );

   U_Second : entity surf.PtpConstDivide
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         WIDTH_G        => WIDTH_G,
         DIVISOR_G      => PTP_SECOND_Q16_DIVISOR_C)
      port map (
         clk         => clk,            -- [in]
         rst         => rst,            -- [in]
         cancel      => coreCancel,     -- [in]
         request     => secondRequest,  -- [in]
         inputReady  => coreReady,      -- [out]
         result      => secondResult,   -- [out]
         resultReady => '1');           -- [in]

   comb : process (all) is
      variable v         : RegType;
      variable selected  : natural range 0 to NUM_CLIENTS_G-1;
      variable eligible  : slv(NUM_CLIENTS_G-1 downto 0);
      variable cancelNow : sl;
      variable issue     : sl;
   begin
      v            := r;
      v.inputReady := (others => '0');

      -- An owner holding an unread response is not eligible.
      for i in 0 to NUM_CLIENTS_G-1 loop
         eligible(i) := requests(i).valid and not r.results(i).valid and not cancel(i);
      end loop;

      selected := r.cursor;
      for i in 0 to NUM_CLIENTS_G-1 loop
         if eligible((r.cursor+i) mod NUM_CLIENTS_G) = '1' then
            selected := (r.cursor+i) mod NUM_CLIENTS_G;
            exit;
         end if;
      end loop;

      -- Release consumed or cancelled responses before admitting new work.
      for i in 0 to NUM_CLIENTS_G-1 loop
         if resultReady(i) = '1' or cancel(i) = '1' then
            v.results(i).valid := '0';
         end if;
      end loop;

      cancelNow := '0';
      issue     := '0';

      if r.active = '1' then
         cancelNow := cancel(r.owner);

         if secondResult.valid = '1' then
            v.results(r.owner).value := secondResult.value;
            v.results(r.owner).remainder := secondResult.remainder;
            v.results(r.owner).valid := '1';
            v.active := '0';
         end if;

         if cancel(r.owner) = '1' then
            v.results(r.owner).valid := '0';
            v.active := '0';
         end if;

      elsif eligible(selected) = '1' then
         issue := '1';
         v.inputReady(selected) := coreReady;

         if coreReady = '1' then
            v.active := '1';
            v.owner  := selected;
            v.cursor := (selected+1) mod NUM_CLIENTS_G;
         end if;
      end if;

      -- Combinatorial outputs before the reset. Admission describes this
      -- edge's capacity; the shared reset domain excludes transfers.
      coreValid   <= issue;
      coreCancel  <= cancelNow;
      coreRound   <= requests(selected).roundNearest;
      coreOperand <= requests(selected).operand;

      inputReady <= v.inputReady;

      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin     <= v;
      results <= r.results;
   end process comb;

   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
