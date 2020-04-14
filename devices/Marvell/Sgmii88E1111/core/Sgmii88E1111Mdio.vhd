-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Controller for the Marvell 88E1111 PHY
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

entity Sgmii88E1111Mdio is
   generic (
      TPD_G : time                            := 1 ns;
      -- half-period of MDC in clk cycles
      DIV_G : natural range 1 to natural'high := 1;
      PHY_G : natural range 0 to 31           := 7);
   port (
      -- clock and reset
      clk             : in  sl;
      rst             : in  sl;
      -- misc
      initDone        : out sl;
      speed_is_10_100 : out sl;
      speed_is_100    : out sl;
      linkIsUp        : out sl;
      -- MDIO interface
      mdc             : out sl;
      mdo             : out sl;
      mdi             : in  sl;
      -- link status change interrupt
      linkIrq         : in  sl);
end entity Sgmii88E1111Mdio;

architecture rtl of Sgmii88E1111Mdio is

   -- the initialization sequence:
   -- 1) sets up advertisement for supported ANEG modes on the copper-side of the PHY
   --    (all speeds, FD only - the SURF Ethernet mac doesn't support HD, AFAIK).
   -- 2) disables auto-negotiation on the SGMII side (since there is no support in the
   --    FW.
   -- 3) enables link status change interrupts.
   --
   -- This module monitors link-status changes and obtains updated link status and
   -- speed from the PHY so that the user may switch the MAC to the correct speed.

   constant P_INIT_C : MdioProgramArray :=
      (
         mdioWriteInst(PHY_G, 22, X"0001", false),  -- select page 1
         mdioWriteInst(PHY_G, 0, X"0140", false),  -- disable ANEG on SMII side
         mdioWriteInst(PHY_G, 22, X"0000", false),  -- select page 0
         mdioWriteInst(PHY_G, 4, X"0140", false),  -- advertise 10/100 FD only
         mdioWriteInst(PHY_G, 9, X"0200", false),  -- advertise 1000   FD only
         mdioWriteInst(PHY_G, 18, X"0c00", false),  -- enable link status and ANEG IRQ
         mdioWriteInst(PHY_G, 0, X"1340", true)    -- restart copper ANEG
         );

   constant REG19_IDX_C : natural := 0;
   constant REG17_IDX_C : natural := 1;

   -- IRQ Handler sequence:
   --  1) read back and clear interrupts (reading does clear them)
   --  2) obtain current link status and speed
   constant P_HDLR_C : MdioProgramArray :=
      (
         REG19_IDX_C => mdioReadInst(PHY_G, 19, false),  -- read/ack/clear interrupt
         REG17_IDX_C => mdioReadInst(PHY_G, 17, true)  -- read current speed and link status
         );

   constant NUM_READ_ARGS_C : natural := mdioProgNumReadTransactions(P_HDLR_C);

   type RegType is record
      s10_100  : sl;
      s100     : sl;
      linkIsUp : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      s10_100  => '0',
      s100     => '0',
      linkIsUp => '0'
      );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal hdlrDone : sl;
   signal args     : Slv16Array(0 to NUM_READ_ARGS_C - 1);

begin

   speed_is_10_100 <= r.s10_100;
   speed_is_100    <= r.s100;
   linkIsUp        <= r.linkIsUp;

   U_MdioLinkIrqHandler : entity surf.MdioLinkIrqHandler
      generic map (
         TPD_G           => TPD_G,
         DIV_G           => DIV_G,
         PROG_INIT_G     => P_INIT_C,
         PROG_HDLR_G     => P_HDLR_C,
         NUM_HDLR_ARGS_G => NUM_READ_ARGS_C
         )
      port map (
         clk => clk,
         rst => rst,

         initDone => initDone,
         hdlrDone => hdlrDone,
         args     => args,

         mdc => mdc,
         mdi => mdi,
         mdo => mdo,

         phyIrq => linkIrq
         );

   COMB : process(args, hdlrDone, r)
      variable v   : RegType;
      variable r17 : slv(15 downto 0);
   begin

      v := r;

      if (hdlrDone /= '0') then

         r17 := args(REG17_IDX_C);

         v.linkIsUp := r17(11);

         if (v.linkIsUp /= '0') then
            -- link is good
            case r17(15 downto 14) is
               when "10" =>             -- 1000Mbps
                  v.s10_100 := '0';
                  v.s100    := '0';
               when "01" =>             -- 100Mbps
                  v.s10_100 := '1';
                  v.s100    := '1';
               when "00" =>             -- 10Mbps
                  v.s10_100 := '1';
                  v.s100    := '0';
               when others =>           -- reserved; should not happen
            end case;
         end if;

      end if;

      rin <= v;

   end process COMB;

   SEQ : process(clk)
   begin
      if (rising_edge(clk)) then
         if (rst /= '0') then
            r <= REG_INIT_C;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process SEQ;

end rtl;

