-------------------------------------------------------------------------------
-- Title      : MDIO Support
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--    Execute sequence(s) of MDIO transaction(s). A list (array) of all possible
--    transaction sequences is passed in the MDIO_PROG_G generic. Individual (sub-)
--    sequences are separated by the asserted 'theLast' flag in the last instruction
--    of each individual sequence.
--
--    A typical MDIO_PROG_G is a concatenation of sequences:
--
--    constant MDIO_PROG_C : MdioProgramArray := ( SEQ_1_C & SEQ_2_C & SEQ_3_C );
--
--    where each sequence (SEQ_1_C, SEQ_2_C, ...) is itself a MdioProgramArray and
--    has in its last instruction the 'last' flag set. E.g.,:
--
--    constant SEQ_1_C : MdioProgramArray := (
--       mdioWriteInst( PHY, REG_0, DATA_0 );
--       mdioWriteInst( PHY, REG_1, DATA_2 );
--       mdioReadInst ( PHY, REG_2,        true);
--    );
--
--
--    The user would then trigger execution of a particular sequence by
--
--    1)  setting 'pc' to the index of the starting position of the first instruction of
--     the desired sequence.
--    2)  asserting 'trg' high for one clock cycle.
--
--    The sequencer then executes all instructions up to (and including) the last one
--    of a sequence.
--    When done, 'don' is asserted for a single clk cycle.
--    When any read transaction completes 'rs' is asserted for one cycle and readback
--    data is presented at 'din' (valid while 'don' is asserted).
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
use surf.MdioPkg.all;

entity MdioSeqCore is
   generic (
      TPD_G               : time                            := 1 ns;
      -- half-period of MDC in clk cycles
      DIV_G               : natural range 1 to natural'high := 1;
      -- see above...
      MDIO_PROG_G         : MdioProgramArray
   );
   port (
      -- clock and reset
      clk                 : in    sl;
      rst                 : in    sl;

      -- programming interface;
      trg                 : in    sl;               -- assert trg for ONE clock
      pc                  : in    natural;
      rs                  : out   sl;               -- read back data valid
      din                 : out   slv(15 downto 0); -- read back data - valid during 'rs'
      don                 : out   sl;               -- program completed

      -- MDIO interface
      mdc                 : out   sl;
      mdo                 : out   sl;
      mdi                 : in    sl
   );
end entity MdioSeqCore;

architecture MdioSeqCoreImpl of MdioSeqCore is

   type StateType is ( IDLE, TRIG, PROG );

   type RegType is record
      state   : StateType;
      inst    : MdioInstType;
      pc      : natural;
      trg     : sl;
   end record;

   constant REG_INIT_C : RegType := (
      state   => IDLE,
      inst    => mdioReadInst(0,0,true),
      pc      =>  0,
      trg     => '0'
   );

   signal r       : RegType := REG_INIT_C;
   signal rin     : RegType;

   signal oneDone : sl;

begin

   don    <= oneDone and r.inst.lst;
   rs     <= oneDone and r.inst.cmd.rdNotWr;

   U_MdioCore : entity surf.MdioCore
      generic map (
         TPD_G      => TPD_G,
         DIV_G      => DIV_G
      )
      port map (
         clk        => clk,
         rst        => rst,

         trg        => r.trg,
         cmd        => r.inst.cmd,
         din        => din,
         don        => oneDone,

         mdc        => mdc,
         mdi        => mdi,
         mdo        => mdo
      );

   COMB : process(r, trg, pc, oneDone)
      variable v : RegType;
   begin
      v        := r;

      case (r.state) is

         when IDLE =>
            if ( trg /= '0' ) then
               v.state := TRIG;
               v.pc    := pc;
            end if;

         when TRIG =>
            v.trg   := '1';
            v.inst  := MDIO_PROG_G( r.pc );
            v.state := PROG;

         when PROG =>
            if ( oneDone /= '0' ) then
               if ( r.inst.lst /= '0' ) then
                  v.state := IDLE;
               else
                  v.pc    := r.pc + 1;
                  v.state := TRIG;
               end if;
            end if;
            v.trg := '0';

      end case;

      rin <= v;

   end process COMB;

   SEQ  : process( clk )
   begin
      if ( rising_edge( clk ) ) then
         if ( rst /= '0' ) then
            r <= REG_INIT_C;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process SEQ;

end architecture MdioSeqCoreImpl;
