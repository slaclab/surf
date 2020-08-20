-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Controller for the TI DP83867DP83867 ETH PHY
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

entity SgmiiDp83867Mdio is
   generic (
      TPD_G : time                            := 1 ns;
      -- half-period of MDC in clk cycles
      DIV_G : natural range 1 to natural'high := 1;
      PHY_G : natural range 0 to 15           := 3);
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
end entity SgmiiDp83867Mdio;

architecture rtl of SgmiiDp83867Mdio is

   constant P_INIT_C : MdioProgramArray := (
      mdioWriteInst(PHY_G, 16#0D#, x"001F", false),  -- Address 0x000D: Setup for extended address
      mdioWriteInst(PHY_G, 16#0E#, x"00D3", false),  -- Address 0x000E: Set extended address = 0x00D3
      mdioWriteInst(PHY_G, 16#0D#, x"401F", false),  -- Address 0x000D: Setup for extended data write
      mdioWriteInst(PHY_G, 16#0E#, x"4000", false),  -- Address 0x000E: Enable SGMII clock

      mdioWriteInst(PHY_G, 16#0D#, x"001F", false),  -- Address 0x000D: Setup for extended address
      mdioWriteInst(PHY_G, 16#0E#, x"0032", false),  -- Address 0x000E: Set extended address = 0x0032
      mdioWriteInst(PHY_G, 16#0D#, x"401F", false),  -- Address 0x000D: Setup for extended data write
      mdioWriteInst(PHY_G, 16#0E#, x"0000", false),  -- Address 0x000E: RGMII must be disabled

      mdioWriteInst(PHY_G, 16#1E#, x"0082", false),  -- Address 0x001E: INTN/PWDNN Pad is an Interrupt Output.
      mdioWriteInst(PHY_G, 16#14#, x"29C7", false),  -- Address 0x0014: Configure interrupt polarity, enable auto negotiation, Enable Speed Optimization
      mdioWriteInst(PHY_G, 16#12#, X"0c00", false),  -- Address 0x0012: Interrupt of link and autoneg changes
      mdioWriteInst(PHY_G, 16#10#, x"5868", false),  -- Address 0x0010: Enable SGMII
      -- mdioWriteInst(PHY_G, 16#09#, X"0200", false),  -- Address 0x0009: Advertise 1000   FD only
      -- mdioWriteInst(PHY_G, 16#04#, X"0140", false),  -- Address 0x0004: Advertise 10/100 FD only
      mdioWriteInst(PHY_G, 16#00#, x"1140", false),  -- Address 0x0000: Enable autoneg and full duplex

      mdioWriteInst(PHY_G, 16#1F#, x"4000", true));  -- Address 0x001F: Initiate the soft restart.

   constant REG0x13_IDX_C : natural := 0;
   constant REG0x11_IDX_C : natural := 1;

   -- IRQ Handler sequence:
   --  1) read back and clear interrupts (reading does clear them)
   --  2) obtain current link status and speed
   constant P_HDLR_C : MdioProgramArray := (
      REG0x13_IDX_C => mdioReadInst(PHY_G, 16#13#, false),  -- read/ack/clear interrupt
      REG0x11_IDX_C => mdioReadInst(PHY_G, 16#11#, true)  -- read current speed and link status
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
         NUM_HDLR_ARGS_G => NUM_READ_ARGS_C)
      port map (
         clk      => clk,
         rst      => rst,
         initDone => initDone,
         hdlrDone => hdlrDone,
         args     => args,
         mdc      => mdc,
         mdi      => mdi,
         mdo      => mdo, phyIrq => linkIrq);

   COMB : process(args, hdlrDone, r)
      variable v       : RegType;
      variable statReg : slv(15 downto 0);
   begin

      v := r;

      if (hdlrDone /= '0') then

         statReg := args(REG0x11_IDX_C);

         v.linkIsUp := statReg(10);

         if (v.linkIsUp /= '0') then
            -- link is good
            case statReg(15 downto 14) is
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
                  v.s10_100 := '0';
                  v.s100    := '0';
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
