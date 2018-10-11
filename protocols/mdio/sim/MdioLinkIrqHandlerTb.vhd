-------------------------------------------------------------------------------
-- Title      : MDIO Support
-------------------------------------------------------------------------------
-- File       : MdioLinkIrqHandlerTb.vhd
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

entity MdioLinkIrqHandlerTb is
end entity MdioLinkIrqHandlerTb;

architecture a of MdioLinkIrqHandlerTb is

   signal mdo     : sl;
   signal mdi     : sl := 'X';
   signal mdiLoc  : sl;
   signal mdc     : sl;
   signal clk     : sl := '0';

   constant PHY_C : natural := 7;

   constant REG_IE: natural := 18;
   constant REG_IS: natural := 19;

   constant REG_LS: natural := 17;

   constant PROG_INIT_C: MdioProgramArray :=
   (
      0 => mdioWriteInst(PHY_C, REG_IE, x"0100", true)
   );


   constant PROG_HDLR_C: MdioProgramArray :=
   (
      0 => mdioWriteInst(PHY_C, REG_IS, x"0000"),
      1 => mdioReadInst (PHY_C, REG_LS, true)
   );

   constant LS_RB_IDX : natural := 0;


   constant NUM_HDLR_ARGS_C : natural := mdioProgNumReadTransactions(PROG_HDLR_C);


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

   signal fini    : natural := 512;

   constant N_RB_C: natural := NUM_HDLR_ARGS_C;
   signal rbdata  : Slv16Array(0 to N_RB_C-1) := (others => (others => 'X'));

   signal rbidx   : natural := 0;

   signal initDone : sl;
   signal initDoneR: sl := '0';
   signal hdlrDone : sl;

   signal irq      : sl;

   signal trg      : sl := '0';
   signal trgr     : sl := '0';

   signal stri     : sl;
   signal strd     : sl := '0';
   signal str      : sl;

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
              when 3 =>
                 rst <= '0';
              when others =>
            end case;
         end if;
      end if;
   end process P_INI;

   P_REGS : process(clk)
   begin
      if ( rising_edge( clk ) ) then
         if ( rst = '0' ) then
            if (str /= '0' and opR = '0' ) then
               regs(to_integer(unsigned(reg))) <= dataOut;
            elsif ( initDone /= '0' and initDoneR = '0' ) then
               initDoneR       <= '1';
               regs(REG_IS)(8) <= '1';
               regs(REG_LS)    <= x"AAAA";
            elsif ( trg /= trgr ) then
               trg             <= trgr;
               regs(REG_IS)(8) <= '1';
               regs(REG_LS)    <= toSlv(test, 16);
            end if;
         else
            regs(REG_IE)  <= X"0000";
            regs(REG_IS)  <= X"0000";
            regs(REG_LS)  <= X"0000";
         end if;
      end if;
   end process P_REGS;

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

   U_DUT : entity work.MdioLinkIrqHandler
      generic map (
         DIV_G           => 3,
         PROG_INIT_G     => PROG_INIT_C,
         PROG_HDLR_G     => PROG_HDLR_C,
         NUM_HDLR_ARGS_G => NUM_HDLR_ARGS_C
      )
      port map (
         clk          => clk,
         rst          => rst,

         initDone     => initDone,
         hdlrDone     => hdlrDone,

         args         => rbdata,

         mdi          => mdi,
         mdo          => mdo,
         mdc          => mdc,

         phyIrq       => irq
      );

   irq <= regs(REG_IE)(8) and regs(REG_IS)(8);

   P_CHECKER : process(clk)
   begin
      if ( rising_edge( clk ) ) then
         if ( hdlrDone /= '0' ) then
            case test is
               when 0 =>
                  assert( rbdata(LS_RB_IDX) = x"AAAA" ) severity failure;
                  trgr <= not trgr;

               when 1 | 2 | 3 =>
                  assert unsigned(rbdata(LS_RB_IDX)) = test severity failure;
                  trgr <= not trgr;

               when others =>
                  print("Test FAILED -- unexpected test stage");
                  assert false severity failure;
            end case;

            test <= test + 1;
         end if;

         -- run for a while - no further interrupts should happen
         if ( test = 4 ) then
            if ( fini > 0 ) then
               fini <= fini - 1;
            else
               print("Test SUCCESSFUL");
               running <= false;
            end if; 
         end if;
      end if;
   end process P_CHECKER;
end architecture a;
