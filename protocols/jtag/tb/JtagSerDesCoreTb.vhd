-------------------------------------------------------------------------------
-- Title      : JTAG Support
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Test bench for JtagSerDesCore
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

entity JtagSerDesCoreTb is
end entity JtagSerDesCoreTb;

architecture JtagSerDesCoreTbImpl of JtagSerDesCoreTb is
  constant W_C : positive := 4;
  constant D_C : positive := 2;

  type TestVecArray is array (natural range 0 to 15) of natural range 0 to 15;

  signal tck : sl;
  signal clk : sl := '0';
  signal rst : sl := '1';
  signal tdi : sl;
  signal tdo : sl;
  signal tms : sl;

  signal diTdi : slv(W_C-1 downto 0);
  signal doTdo : slv(W_C-1 downto 0);

  signal nBits : natural range 0 to W_C - 1;

  signal diV   : sl := '0';
  signal diR   : sl;
  signal doV   : sl;
  signal doR   : sl := '0';

  signal run   : boolean := true;

  signal step  : integer := 0;

  signal idxi  : natural range 0 to 15;
  signal idxo  : natural range 0 to 15;

  signal testVec : TestVecArray := (
    4,6,3,11,7,8,1,9,2,12,0,14,5,13,15,10
  );

begin

   process
   begin
      if ( run ) then
         clk <= not clk;
         wait for 5 ns;
      else
         wait;
      end if;
   end process;

   tdo <= tdi;

   process (clk)
   begin
      if ( rising_edge(clk) ) then
         if ( step < 4 ) then
            if ( step = 2 ) then
               rst <= '0';
            end if;
            step <= step + 1;
         elsif ( step = 4 ) then
            nBits <= 3;
            doR   <= '1';
            diTdi <= "0101";
            diV   <= '1';
            step <= 5;
         elsif ( step = 5 ) then
            if ( diV = '1' and diR = '1' ) then
               diV  <= '0';
               step <= 6;
            end if;
         elsif ( step = 6 ) then
            if ( doV = '1' and doR = '1' ) then
               doR  <= '0';
               step <= 7;
               assert unsigned(doTdo) = 5 severity failure;
            end if;
         elsif ( step = 7 ) then
            step <= step + 1;
-- back-to-back with no wait
         elsif ( step = 8 ) then
            diTdi <= "1010";
            diV   <= '1';
            doR   <= '1';
            step <= step+1;
         elsif ( step = 9 ) then
            if ( diV = '1' and diR = '1' ) then
               diTdi <= "0011";
               step <= step+1;
            end if;
         elsif ( step = 10 ) then
            if ( diV = '1' and diR = '1' ) then
               diV <= '0';
            end if;
            if ( doV = '1' and doR = '1' ) then
               assert doTdo = "1010" severity failure;
               step <= step+1;
            end if;
         elsif ( step = 11 ) then
            if ( doV = '1' and doR = '1' ) then
               doR <= '0';
               assert doTdo = "0011" severity failure;
               step <= step+1;
            end if;
-- back-to-back with wait
         elsif ( step = 12 ) then
            diTdi <= "0110";
            diV   <= '1';
            doR   <= '0';
            step <= step+1;
         elsif ( step = 13 ) then
            if ( diV = '1' and diR = '1' ) then
            	diTdi <= "1111";
                nBits <= 0;
                step  <= step + 1;
            end if;
         elsif ( step = 14 ) then

            if ( diV = '1' and diR = '1' ) then
               diV <= '0';
            end if;

            if ( doV = '1' ) then
               step <= step+1;
            end if;
         elsif ( step = 15 ) then
            doR  <= '1';
            step <= step + 1;
         elsif ( step = 16 ) then
            if ( doV = '1' and doR = '1' ) then
               assert doTdo = "0110" severity failure;
               step <= step+1;
            end if;
         elsif ( step = 17 ) then
            if ( doV = '1' and doR = '1' ) then
               doR <= '0';
               assert doTdo(3) = '1' severity failure;
               step <= step+1;
            end if;
         elsif ( step = 18 ) then
            idxo  <= 0;
            idxi  <= 0;
            diTdi <= toSlv(testVec(0), W_C);
            diV   <= '1';
            doR   <= '1';
            nBits <= 3;
            step <= step + 1;
         elsif ( step = 19 ) then
            if ( diV = '1' and diR = '1' ) then
               if ( idxi = 15 ) then
                  diV <= '0';
               else
                  diTdi <= toSlv(testVec(idxi + 1), W_C);
                  idxi  <= idxi + 1;
               end if;
            end if;
            if ( doV = '1' and doR = '1' ) then
               assert testVec(idxo) = unsigned(doTdo) severity failure;
               if ( idxo = 15 ) then
                  doR <= '0';
                  step <= step+1;
               else
                  idxo <= idxo + 1;
               end if;
            end if;
         elsif ( step = 20 ) then
            idxo  <= 0;
            idxi  <= 0;
            diTdi <= toSlv(testVec(0), W_C);
            diV   <= '1';
            doR   <= '1';
            nBits <= 1;
            step <= step + 1;
         elsif ( step = 21 ) then
            if ( diV = '1' and diR = '1' ) then
               if ( idxi = 15 ) then
                  diV <= '0';
               else
                  diTdi <= toSlv(testVec(idxi + 1), W_C);
                  idxi  <= idxi + 1;
               end if;
            end if;
            if ( doV = '1' and doR = '1' ) then
               assert toSlv(testVec(idxo), W_C)(1 downto 0) = doTdo(3 downto 2) severity failure;
               if ( idxo = 15 ) then
                  doR <= '0';
                  step <= step+1;
               else
                  idxo <= idxo + 1;
               end if;
            end if;
         else
            run <= false;
         end if;
      end if;
   end process;


   U_DUT : entity surf.JtagSerDesCore
      generic map (
         WIDTH_G      => W_C,
         CLK_DIV2_G   => D_C
      )
      port map (
         clk          => clk,
         rst          => rst,

         numBits      => nBits,
         dataInTms    => (others => '0'),
         dataInTdi    => diTdi,
         dataInValid  => diV,
         dataInReady  => diR,

         dataOut      => doTdo,
         dataOutValid => doV,
         dataOutReady => doR,

         tck          => tck,
         tdi          => tdi,
         tms          => tms,
         tdo          => tdo
      );
end architecture JtagSerDesCoreTbImpl;
