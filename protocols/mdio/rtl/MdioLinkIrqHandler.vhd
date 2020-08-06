-------------------------------------------------------------------------------
-- Title      : MDIO Support
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--    Handle link interrupts signaled by an external PHY and determine
--    updated link status and speed. This modules uses the MdioSeqCore
--    sequencer core.
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

-- This module processes two simple sequences of MDIO commands:
--
-- 1. An initialization sequence upon startup and after reset
-- 2. A 'IRQ handler sequence' as a response to a phyIrq.
--    This handler sequence usually contains read transactions
--    which determine the new link status. The first
--    NUM_HDLR_ARGS_G replies to such read transactions are
--    stored and passed back to the user in the 'args' array for
--    further processing by the user.

entity MdioLinkIrqHandler is
   generic (
      TPD_G               : time                            := 1 ns;
      -- half-period of MDC in clk cycles
      DIV_G               : natural range 1 to natural'high := 1;
      -- initialization sequence
      PROG_INIT_G         : MdioProgramArray;
      PROG_HDLR_G         : MdioProgramArray;
      -- number of readback values the PROG_HDLR_G sequence reads.
      NUM_HDLR_ARGS_G     : natural
   );
   port (
      -- clock and reset
      clk                 : in    sl;
      rst                 : in    sl;

      -- misc
      initDone            : out   sl;
      -- interrupt handled; args array is 'valid' while this is asserted
      hdlrDone            : out   sl;

      -- readback values of the PROG_HDLR_G sequence
      args                : out   Slv16Array(0 to NUM_HDLR_ARGS_G - 1);

      -- MDIO interface
      mdc                 : out   sl;
      mdo                 : out   sl;
      mdi                 : in    sl;

      -- phy interrupt (link status change)
      phyIrq              : in    sl
   );
end entity MdioLinkIrqHandler;

architecture MdioLinkIrqHandlerImpl of MdioLinkIrqHandler is

   type StateType is (INIT, START_HDLR, HDLR_DONE, IDLE, WAIT_FOR_MDIO);

   constant PC_INIT_C : natural := 0;
   constant PC_HDLR_C : natural := PC_INIT_C + PROG_INIT_G'length;

   subtype  RbpRangeType is natural range 0 to NUM_HDLR_ARGS_G;

   type RegType is record
      state      : StateType;
      nextState  : StateType;
      pc         : natural;
      mdioData   : Slv16Array(0 to NUM_HDLR_ARGS_G - 1);
      rbp        : RbpRangeType;
      trg        : sl;
      initDone   : sl;
      hdlrDone   : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state      => INIT,
      nextState  => INIT,
      pc         => PC_INIT_C,
      mdioData   => (others => (others => '0')),
      rbp        =>  0,
      trg        => '0',
      initDone   => '0',
      hdlrDone   => '0'
   );

   constant MDIO_PROG_C : MdioProgramArray :=
      (
      PROG_INIT_G &
      PROG_HDLR_G
      );

   signal r         : RegType := REG_INIT_C;
   signal rin       : RegType;
   signal mdioRead  : sl;
   signal mdioDone  : sl;
   signal mdioData  : slv(15 downto 0);

begin

   initDone        <= r.initDone;
   hdlrDone        <= r.hdlrDone;
   args            <= r.mdioData;

   U_MdioCtrl : entity surf.MdioSeqCore
      generic map (
         TPD_G       => TPD_G,
         DIV_G       => DIV_G,
         MDIO_PROG_G => MDIO_PROG_C
      )
      port map (
         clk         => clk,
         rst         => rst,

         trg         => r.trg,
         pc          => r.pc,
         rs          => mdioRead,
         din         => mdioData,
         don         => mdioDone,

         mdc         => mdc,
         mdi         => mdi,
         mdo         => mdo
      );

   COMB : process(r, phyIrq, mdioDone, mdioRead, mdioData)
      variable v : RegType;
   begin

      v          := r;

      v.trg      := '0';
      v.hdlrDone := '0';

      case ( r.state ) is
         when INIT =>
            v.state        := WAIT_FOR_MDIO;
            v.nextState    := START_HDLR;
            v.pc           := PC_INIT_C;
            v.trg          := '1';

         when START_HDLR =>
            v.state        := WAIT_FOR_MDIO;
            v.nextState    := HDLR_DONE;
            v.pc           := PC_HDLR_C;
            v.rbp          :=  0;
            v.initDone     := '1';
            v.trg          := '1';

         when IDLE =>
            if ( phyIrq /= '0' ) then
               v.state     := START_HDLR;
            end if;

         when WAIT_FOR_MDIO =>
            if ( (mdioRead /= '0') and (r.rbp < NUM_HDLR_ARGS_G) ) then
               v.mdioData(r.rbp) := mdioData;
               v.rbp             := r.rbp + 1;
            end if;
            if ( mdioDone /= '0' ) then
               v.state    := r.nextState;
            end if;

         when HDLR_DONE =>
            v.hdlrDone := '1';
            v.state    := IDLE;

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

end architecture MdioLinkIrqHandlerImpl;
