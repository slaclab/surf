-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Shared positive-divisor, quotient-only variable divider.
--
-- Serves the measurement divisions whose denominator is itself measured: the
-- rate estimator's raw tick/phase span and each E2E calibration plane's
-- captured PHC increment. Those are the only remaining variable denominators,
-- so one instance per endpoint replaces per-client dividers.
--
-- The interface is deliberately narrower than a general signed divider. The
-- divisor is an unsigned DIVISOR_WIDTH_G-bit magnitude, zero-extended at the
-- boundary, and the remainder is discarded. Callers must reject a signed or
-- wider divisor **before** narrowing it to this port; the narrower contract is
-- not a claim that out-of-range values are handled here. Divide-by-zero
-- remains observable through resultError.
--
-- NUM_CLIENTS_G owners share one restoring core. Arbitration is round-robin
-- with a per-owner held response, so an owner whose result is still unread is
-- skipped and cannot block another owner. Cancellation is owner-local: it
-- discards that owner's active work and held response without disturbing the
-- other owners. Sharing adds one response-register cycle to the core's
-- division latency; that serialization belongs in the endpoint service bound.
--
-- All ports use clk. Input ready is combinational per owner; result valid and
-- payload are registered. A client holds inputValid and its payload until
-- ready, and both ends exclude cancel/reset edges from every transfer.
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

entity PtpVariableDivide is
   generic (
      TPD_G           : time                    := 1 ns;
      RST_POLARITY_G  : sl                      := '1';
      RST_ASYNC_G     : boolean                 := false;
      NUM_CLIENTS_G   : positive                := 2;
      -- Unsigned divisor magnitude width. The endpoint union is 78 bits: an
      -- admitted PHC increment shifted left 16, and the rate estimator's
      -- 67-bit raw span. 80 bits covers a standalone E2E leaf exposing all 64
      -- increment bits.
      DIVISOR_WIDTH_G : positive range 1 to 127 := 80);
   port (
      clk          : in  sl;
      rst          : in  sl;
      -- Owner-local cancellation, one bit per client.
      cancel       : in  slv(NUM_CLIENTS_G-1 downto 0);
      inputValid   : in  slv(NUM_CLIENTS_G-1 downto 0);
      inputReady   : out slv(NUM_CLIENTS_G-1 downto 0);
      roundNearest : in  slv(NUM_CLIENTS_G-1 downto 0);
      operandA     : in  Slv128Array(NUM_CLIENTS_G-1 downto 0);
      operandB     : in  slv(NUM_CLIENTS_G*DIVISOR_WIDTH_G-1 downto 0);
      resultValid  : out slv(NUM_CLIENTS_G-1 downto 0);
      resultReady  : in  slv(NUM_CLIENTS_G-1 downto 0);
      resultValue  : out Slv128Array(NUM_CLIENTS_G-1 downto 0);
      resultError  : out slv(NUM_CLIENTS_G-1 downto 0));
end entity PtpVariableDivide;

architecture rtl of PtpVariableDivide is

   type RegType is record
      active     : sl;
      owner      : natural range 0 to NUM_CLIENTS_G-1;
      cursor     : natural range 0 to NUM_CLIENTS_G-1;
      inputReady : slv(NUM_CLIENTS_G-1 downto 0);
      valid      : slv(NUM_CLIENTS_G-1 downto 0);
      value      : Slv128Array(NUM_CLIENTS_G-1 downto 0);
      error      : slv(NUM_CLIENTS_G-1 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      active     => '0',
      owner      => 0,
      cursor     => 0,
      inputReady => (others => '0'),
      valid      => (others => '0'),
      value      => (others => (others => '0')),
      error      => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal coreCancel      : sl;
   signal coreValid       : sl;
   signal coreReady       : sl;
   signal coreRound       : sl;
   signal coreOperandA    : slv(127 downto 0);
   signal coreOperandB    : slv(127 downto 0);
   signal coreResultValid : sl;
   signal coreResultValue : slv(127 downto 0);
   signal coreError       : sl;

begin

   -- Zero-extending the divisor at this boundary lets synthesis remove the
   -- core's negative-divisor and high-word rejection circuitry.
   U_Divider : entity surf.PtpMath
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         DIVISOR_WIDTH_G => DIVISOR_WIDTH_G)
      port map (
         clk             => clk,              -- [in]
         rst             => rst,              -- [in]
         cancel          => coreCancel,       -- [in]
         inputValid      => coreValid,        -- [in]
         inputReady      => coreReady,        -- [out]
         divide          => '1',              -- [in]
         roundNearest    => coreRound,        -- [in]
         operandA        => coreOperandA,     -- [in]
         operandB        => coreOperandB,     -- [in]
         resultValid     => coreResultValid,  -- [out]
         resultReady     => '1',              -- [in]
         resultValue     => coreResultValue,  -- [out]
         resultRemainder => open,             -- [out]
         resultError     => coreError);       -- [out]

   comb : process (all) is
      variable v         : RegType;
      variable selected  : natural range 0 to NUM_CLIENTS_G-1;
      variable eligible  : slv(NUM_CLIENTS_G-1 downto 0);
      variable cancelNow : sl;
      variable issue     : sl;
   begin
      v := r;
      v.inputReady := (others => '0');

      -- An owner holding an unread response is not eligible, so a stalled
      -- consumer cannot deny service to the other owners.
      eligible := inputValid and not r.valid and not cancel;

      -- Round-robin from the cursor, taking the first eligible owner.
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
            v.valid(i) := '0';
         end if;
      end loop;

      cancelNow := '0';
      issue := '0';

      if r.active = '1' then
         cancelNow := cancel(r.owner);

         if coreResultValid = '1' then
            v.value(r.owner) := coreResultValue;
            v.error(r.owner) := coreError;
            v.valid(r.owner) := '1';
            v.active := '0';
         end if;

         -- Owner-local cancellation discards this owner's work and response.
         if cancel(r.owner) = '1' then
            v.valid(r.owner) := '0';
            v.active := '0';
         end if;

      elsif eligible(selected) = '1' and rst /= RST_POLARITY_G then
         issue := '1';
         v.inputReady(selected) := coreReady;

         if coreReady = '1' then
            v.active := '1';
            v.owner := selected;
            v.cursor := (selected+1) mod NUM_CLIENTS_G;
         end if;
      end if;

      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
         issue := '0';
         cancelNow := '0';
      end if;

      rin <= v;

      coreValid <= issue;
      coreCancel <= cancelNow;
      coreRound <= roundNearest(selected);
      coreOperandA <= operandA(selected);
      coreOperandB <= slv(resize(unsigned(
         operandB(DIVISOR_WIDTH_G*selected+DIVISOR_WIDTH_G-1 downto DIVISOR_WIDTH_G*selected)), 128));

      inputReady <= v.inputReady;
      resultValid <= r.valid;
      resultValue <= r.value;
      resultError <= r.error;
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
