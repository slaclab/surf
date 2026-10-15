-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Shared word-serial age/distance comparison for the two Sync tables.
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
use surf.PtpPkg.all;
use surf.PtpSyncPkg.all;

entity PtpTableScan is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false);
   port (
      clk                : in sl;
      rst                : in sl;
      cancel             : in sl;
      associationTimeout : in slv(63 downto 0);
      maxExchange        : in slv(63 downto 0);
      pairRequest        : in PtpScanRequestType;
      historyRequest     : in PtpScanRequestType;
      pairResult         : out PtpScanResultType;
      historyResult      : out PtpScanResultType);
end entity PtpTableScan;

architecture rtl of PtpTableScan is

   type ScanStateType is (
      SCAN_IDLE_S,
      SCAN_AGE_S,
      SCAN_AGE_LIMIT_S,
      SCAN_DISTANCE_S,
      SCAN_ABS_S,
      SCAN_LIMIT_S,
      SCAN_BEST_S,
      SCAN_DONE_S);

   type RegType is record
      scanState   : ScanStateType;
      scanHistory : sl;
      scanTurn    : sl;
      scanWord    : natural range 0 to 2;
      scanValue   : slv(67 downto 0);
      scanCarry   : sl;
      scanZero    : sl;
      scanExpired : sl;
      scanBetter  : sl;
   end record;

   constant REG_INIT_C : RegType := (
      scanState   => SCAN_IDLE_S,
      scanHistory => '0',
      scanTurn    => '1',
      scanWord    => 0,
      scanValue   => (others => '0'),
      scanCarry   => '1',
      scanZero    => '1',
      scanExpired => '0',
      scanBetter  => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   pairResult.valid <= toSl(r.scanState = SCAN_DONE_S) and not r.scanHistory;
   historyResult.valid <= toSl(r.scanState = SCAN_DONE_S) and r.scanHistory;
   pairResult.expired <= r.scanExpired;
   historyResult.expired <= r.scanExpired;
   pairResult.better <= r.scanBetter;
   historyResult.better <= r.scanBetter;
   pairResult.distance <= r.scanValue;
   historyResult.distance <= r.scanValue;

   comb : process (all) is
      variable v           : RegType;
      variable scanA       : slv(95 downto 0);
      variable scanB       : slv(95 downto 0);
      variable scanLeft    : unsigned(31 downto 0);
      variable scanRight   : unsigned(31 downto 0);
      variable scanCarryIn : unsigned(32 downto 0);
      variable scanAlu     : unsigned(32 downto 0);
      variable scanLast    : natural range 1 to 2;
   begin
      v := r;
      -- Subtract with carry=1 (inverse borrow); ages wrap modulo 64 bits.
      -- The signed Q3 distance retains all 68 bits before absolute value.
      scanA := (others => '0');
      scanB := (others => '0');
      scanLast := 1;
      case r.scanState is
         when SCAN_AGE_S =>
            scanA(63 downto 0) := pairRequest.ticks;
            scanB(63 downto 0) := pairRequest.rowTicks;
            if r.scanHistory = '1' then
               scanA(63 downto 0) := historyRequest.ticks;
               scanB(63 downto 0) := historyRequest.rowTicks;
            end if;
         when SCAN_AGE_LIMIT_S =>
            scanA(63 downto 0) := r.scanValue(63 downto 0);
            scanB(63 downto 0) := associationTimeout;
         when SCAN_DISTANCE_S =>
            scanA(66 downto 0) := historyRequest.targetTicks & historyRequest.targetPhase;
            scanB(66 downto 0) := historyRequest.rowTicks & historyRequest.rowPhase;
            scanLast := 2;
         when SCAN_ABS_S =>
            scanB(67 downto 0) := r.scanValue;
            scanLast := 2;
         when SCAN_LIMIT_S =>
            scanA(67 downto 0) := r.scanValue;
            scanB(66 downto 0) := maxExchange & toSlv(0,PTP_TICK_PHASE_BITS_C);
            scanLast := 2;
         when SCAN_BEST_S =>
            scanA(63 downto 0) := pairRequest.rowTicks;
            scanB(63 downto 0) := pairRequest.best(63 downto 0);
            if r.scanHistory = '1' then
               scanA(67 downto 0) := r.scanValue;
               scanB(67 downto 0) := historyRequest.best;
               scanLast := 2;
            end if;
         when others =>
            null;
      end case;

      -- Static word slices avoid a variable shift. There is one word ALU for
      -- subtraction, negation and comparison across both table owners.
      scanLeft := (others => '0');
      scanRight := (others => '0');
      for i in 0 to 2 loop
         if r.scanWord = i then
            scanLeft := unsigned(scanA(32*i+31 downto 32*i));
            scanRight := unsigned(scanB(32*i+31 downto 32*i));
         end if;
      end loop;
      scanCarryIn := (others => '0');
      scanCarryIn(0) := r.scanCarry;
      scanAlu := ('0' & scanLeft) + ('0' & not scanRight) + scanCarryIn;

      case r.scanState is
         when SCAN_IDLE_S =>

            if pairRequest.valid = '1' or historyRequest.valid = '1' then
               v.scanHistory := '0';
               if historyRequest.valid = '1' and
                  (pairRequest.valid = '0' or r.scanTurn = '1') then
                  v.scanHistory := '1';
               end if;
               v.scanTurn := not v.scanHistory;
               v.scanState := SCAN_AGE_S;
               v.scanWord := 0;
               v.scanCarry := '1';
               v.scanZero := '1';
               v.scanValue := (others => '0');
               v.scanExpired := '0';
            end if;

         when SCAN_DONE_S =>
            v.scanState := SCAN_IDLE_S;

         when others =>
            v.scanCarry := scanAlu(32);
            v.scanZero := r.scanZero and toSl(scanAlu(31 downto 0) = 0);
            if r.scanState = SCAN_AGE_S or r.scanState = SCAN_DISTANCE_S or r.scanState = SCAN_ABS_S then
               case r.scanWord is
                  when 0 =>
                     v.scanValue(31 downto 0) := slv(scanAlu(31 downto 0));
                  when 1 =>
                     v.scanValue(63 downto 32) := slv(scanAlu(31 downto 0));
                  when 2 =>
                     v.scanValue(67 downto 64) := slv(scanAlu(3 downto 0));
               end case;
            end if;

            if r.scanWord /= scanLast then
               v.scanWord := r.scanWord+1;
            else
               case r.scanState is
                  when SCAN_AGE_S =>
                     v.scanState := SCAN_AGE_LIMIT_S;
                  when SCAN_AGE_LIMIT_S =>
                     v.scanExpired := scanAlu(32) and not v.scanZero;
                     v.scanState := SCAN_BEST_S;
                     if r.scanHistory = '1' then
                        v.scanState := SCAN_DISTANCE_S;
                     end if;
                  when SCAN_DISTANCE_S =>
                     v.scanState := SCAN_LIMIT_S;
                     if scanAlu(32) = '0' then
                        v.scanState := SCAN_ABS_S;
                     end if;
                  when SCAN_ABS_S =>
                     v.scanState := SCAN_LIMIT_S;
                  when SCAN_LIMIT_S =>
                     v.scanExpired := r.scanExpired or (scanAlu(32) and not v.scanZero);
                     v.scanState := SCAN_BEST_S;
                  when SCAN_BEST_S =>
                     v.scanBetter := not scanAlu(32);
                     v.scanState := SCAN_DONE_S;
                  when others =>
                     null;
               end case;
               v.scanWord := 0;
               v.scanCarry := '1';
               v.scanZero := '1';
            end if;
      end case;

      if cancel = '1' then
         v.scanState := SCAN_IDLE_S;
         v.scanTurn := '1';
      end if;
      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;
      rin <= v;
   end process comb;

   seq : process (clk, rst) is
   begin

      if RST_ASYNC_G and rst = RST_POLARITY_G then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;

   end process seq;

end architecture rtl;
