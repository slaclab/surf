-------------------------------------------------------------------------------
-- Title      : MDIO Support
-------------------------------------------------------------------------------
-- File       : MdioSeqCoreTb.vhd
-- Author     : Till Straumann <strauman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
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

use work.StdRtlPkg.all;
use work.TextUtilPkg.all;

use work.MdioPkg.all;

entity MdioSeqCoreTb is
end entity MdioSeqCoreTb;

architecture a of MdioSeqCoreTb is
   signal mdo     : sl;
   signal mdi     : sl := 'X';
   signal mdiLoc  : sl;
   signal mdc     : sl;
   signal trg     : sl := '0';
   signal clk     : sl := '0';
   signal stri    : sl;
   signal str     : sl;
   signal strd    : sl := '0';

   constant PHY_C : natural := 7;
   constant PROG_C: MdioProgramArray :=
   (
      0 => mdioWriteInst(PHY_C, 0, x"1111"),
      1 => mdioReadInst (PHY_C,  9),
      2 => mdioReadInst (PHY_C, 14),
      3 => mdioWriteInst(PHY_C, 1, x"2222"),
      4 => mdioWriteInst(PHY_C, 1, x"3333", true)
   );

   signal dataIn  : slv(15 downto 0);
   signal rst     : sl := '1';

   signal rbd     : slv(15 downto 0);
   signal phy     : slv(4 downto 0);
   signal reg     : slv(4 downto 0);
   signal opR     : sl;

   signal ini     : natural := 8;

   signal regs    : Slv16Array(0 to 31) := (others => (others => 'X'));

   signal test    : natural := 0;

   signal rs      : sl;
   signal dataOut : slv(15 downto 0);
   signal seqDone : sl;

   signal running : boolean := true;

   constant N_RB_C: natural := 2;
   signal rbdata  : Slv16Array(0 to N_RB_C-1) := (others => (others => 'X'));

   signal rbidx   : natural := 0;

begin

   process
   begin
     if (running) then
        clk <= ite( clk = '1', '0', '1' );
        wait for 5000 ns;
     else
        wait;
     end if;
   end process;

   P_INI : process(clk)
   begin
      if ( rising_edge( clk ) ) then
         strd <= stri;
         if ( ini > 0 ) then
            ini <= ini - 1;
            case (ini) is
              when 4 =>
                 regs(9)  <= X"DEAD";
                 regs(14) <= X"BEEF";
              when 3 =>
                 rst <= '0';
              when 1 =>
                 trg <= '1';
              when others =>
            end case;
         else
            trg <= '0';
         end if;
      end if;
   end process P_INI;

   U_SLV : entity work.MdioSlv
      port map (
         mdc => mdc,
         mdi => mdiLoc,
         mdo => mdo,
         reg => reg,
         phy => phy,
         opR => opR,
         rbd => rbd,
         dat => dataOut,
         don => stri
      );

   str <= stri and not strd and not rst;

   rbd <= regs(to_integer(unsigned(reg))) when opR = '1' else (others => 'X');

   mdi <= mdiLoc and mdo;

   U_DUT : entity work.MdioSeqCore
      generic map (
         DIV_G        => 3,
         MDIO_PROG_G  => PROG_C
      )
      port map (
         clk          => clk,
         rst          => rst,

         trg          => trg, 

         pc           => 0,
         rs           => rs,
         din          => dataIn,
         don          => seqDone,

         mdi          => mdi,
         mdo          => mdo,
         mdc          => mdc
      );

   P_READER : process(clk)
   begin
      if ( rising_edge( clk ) ) then
         if ( rst /= '0' ) then
            rbidx <= 0;
         elsif ( rs /= '0' ) then
            assert rbidx < N_RB_C severity failure;
            rbdata(rbidx) <= dataIn;
            rbidx         <= rbidx + 1;
         end if;
      end if;
   end process P_READER;

   P_CHECKER : process(clk)
   begin
      if ( rising_edge( clk ) ) then
         if ( str /= '0' ) then
            case test is
               when 0 =>
                  assert (dataOut = X"1111" and reg = "00000" and to_integer(unsigned(phy)) = PHY_C) severity failure;

               when 1 | 2 =>

               when 3 =>
                  assert (dataOut = X"2222" and reg = "00001" and to_integer(unsigned(phy)) = PHY_C) severity failure;

               when 4 =>
                  assert (dataOut = X"3333" and reg = "00001" and to_integer(unsigned(phy)) = PHY_C) severity failure;

                  assert (rbdata(0) = X"DEAD" and rbdata(1) = X"BEEF") severity failure;
                  report "Test SUCCESSFUL";
                  running <= false;

               when others =>
                  print("Test FAILED -- unexpected test stage");
                  assert false severity failure;
            end case;

            test <= test + 1;
         end if;
      end if;
   end process P_CHECKER;
end architecture a;
