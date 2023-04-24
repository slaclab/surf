-------------------------------------------------------------------------------
-- Title      : PGPv3: https://confluence.slac.stanford.edu/x/OndODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Aligns a GT RX gearbox.
-- After reset, require GOOD_COUNT_C consecutive valid headers to lock.
-- Once locked, require BAD_COUNT_C invalid headers withing GOOD_COUNT_C
-- total headers to break the lock.
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;

entity Pgp3RxGearboxAligner is
   generic (
      TPD_G        : time    := 1 ns;
      RST_ASYNC_G  : boolean := false;
      SLIP_WAIT_G  : integer := 32);
   port (
      clk           : in  sl;
      rst           : in  sl;
      rxHeader      : in  slv(1 downto 0);
      rxHeaderValid : in  sl;
      slip          : out sl;
      locked        : out sl);
end entity Pgp3RxGearboxAligner;

architecture rtl of Pgp3RxGearboxAligner is

   constant GOOD_COUNT_C : integer := 128;
   constant BAD_COUNT_C  : integer := 16;

   constant GOOD_COUNT_WIDTH_C : integer := log2(maximum(GOOD_COUNT_C, SLIP_WAIT_G));

   type StateType is (UNLOCKED_S, SLIP_WAIT_S, LOCKED_S);

   type RegType is record
      state     : StateType;
      goodCount : slv(GOOD_COUNT_WIDTH_C-1 downto 0);
      badCount  : slv(log2(BAD_COUNT_C)-1 downto 0);
      slip      : sl;
      locked    : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state     => UNLOCKED_S,
      goodCount => (others => '0'),
      badCount  => (others => '0'),
      slip      => '0',
      locked    => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (r, rst, rxHeader, rxHeaderValid) is
      variable v : RegType;
   begin
      v := r;

      v.slip := '0';

      case r.state is
         when UNLOCKED_S =>
            if (rxHeaderValid = '1') then
               if (rxHeader = "01" or rxHeader = "10") then
                  v.goodCount := r.goodCount + 1;
               else
                  v.goodCount := (others => '0');
                  v.slip      := '1';
                  v.state     := SLIP_WAIT_S;
               end if;
            end if;
            if (r.goodCount = GOOD_COUNT_C-1) then
               v.state     := LOCKED_S;
               v.locked    := '1';
               v.goodCount := (others => '0');
            end if;

         when SLIP_WAIT_S =>
            v.goodCount := r.goodCount + 1;
            if (r.goodCount = SLIP_WAIT_G-1) then
               v.goodCount := (others => '0');
               v.state     := UNLOCKED_S;
            end if;

         when LOCKED_S =>
            v.locked := '1';
            if (rxHeaderValid = '1') then
               v.goodCount := r.goodCount + 1;
               if (rxHeader = "00" or rxHeader = "11") then
                  v.badCount := r.badCount + 1;
               end if;
            end if;
            if (r.goodCount = GOOD_COUNT_C-1) then
               v.goodCount := (others => '0');
               v.badCount  := (others => '0');
               if (r.badCount >= BAD_COUNT_C-1) then
                  v.locked := '0';
                  v.state  := UNLOCKED_S;
               end if;
            end if;

         when others => null;
      end case;

      if (RST_ASYNC_G = false and rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      locked <= r.locked;
      slip <= r.slip;

   end process comb;

   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G) and (rst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
