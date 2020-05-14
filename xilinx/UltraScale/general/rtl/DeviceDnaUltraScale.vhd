-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for the UltraScale DNA_PORT
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


library surf;
use surf.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity DeviceDnaUltraScale is
   generic (
      TPD_G           : time    := 1 ns;
      USE_SLOWCLK_G   : boolean := false;
      BUFR_CLK_DIV_G  : natural := 8;
      RST_POLARITY_G  : sl      := '1';
      SIM_DNA_VALUE_G : slv     := x"000000000000000000000000");
   port (
      clk      : in  sl;
      rst      : in  sl;
      slowClk  : in  sl := '0';
      dnaValue : out slv(95 downto 0);
      dnaValid : out sl);
end DeviceDnaUltraScale;

architecture rtl of DeviceDnaUltraScale is

   constant DNA_SHIFT_LENGTH_C : natural := 96;

   type StateType is (READ_S, SHIFT_S, DONE_S);

   type RegType is record
      state    : StateType;
      bitCount : natural range 0 to DNA_SHIFT_LENGTH_C;
      dnaValue : slv(DNA_SHIFT_LENGTH_C-1 downto 0);
      dnaValid : sl;
      dnaRead  : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state    => READ_S,
      bitCount => 0,
      dnaValue => (others => '0'),
      dnaValid => '0',
      dnaRead  => '1');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dnaDout  : sl;
   signal divClk   : sl;
   signal locClk   : sl;
   signal locRst   : sl;
   signal dnaRead  : sl;

begin

   locClk <= slowClk when(USE_SLOWCLK_G) else divClk;

   BUFGCE_DIV_Inst : BUFGCE_DIV
      generic map (
         BUFGCE_DIVIDE => BUFR_CLK_DIV_G)
      port map (
         I   => clk,
         CE  => '1',
         CLR => '0',
         O   => divClk);

   RstSync_Inst : entity surf.RstSync
      generic map (
         TPD_G         => TPD_G,
         IN_POLARITY_G => RST_POLARITY_G)
      port map (
         clk      => locClk,
         asyncRst => rst,
         syncRst  => locRst);

   comb : process (dnaDout, locRst, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the strobing signals
      v.dnaRead  := '0';

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when READ_S =>
            -- Strobe the read of the DNA port
            v.dnaRead := '1';
            -- Next State
            v.state   := SHIFT_S;
         ----------------------------------------------------------------------
         when SHIFT_S =>
            -- Check the shift strobe status
            if r.dnaRead = '0' then
               -- Shift register
               v.dnaValue := dnaDout & r.dnaValue(DNA_SHIFT_LENGTH_C-1 downto 1);
               -- Increment the counter
               v.bitCount := r.bitCount + 1;
               -- Check the counter value
               if (v.bitCount = DNA_SHIFT_LENGTH_C-1) then
                  -- Next State
                  v.state := DONE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DONE_S =>
            -- Set the valid bit
            v.dnaValid := '1';
            -- The two LSBs and two MSBs have fixed values
            v.dnaValue(1 downto 0)   := "01";
            v.dnaValue(95 downto 94) := "01";
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      dnaRead  <= v.dnaRead;

      -- Synchronous Reset
      if locRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   sync : process (locClk) is
   begin
      if (rising_edge(locClk)) then
         r <= rin after TPD_G;
      end if;
   end process sync;

   DNA_PORT_I : DNA_PORTE2
      generic map (
         SIM_DNA_VALUE => SIM_DNA_VALUE_G)
      port map (
         CLK   => locClk,
         READ  => dnaRead,
         SHIFT => '1',
         DIN   => '0',
         DOUT  => dnaDout);

   SyncValid : entity surf.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 3)
      port map (
         clk     => clk,
         dataIn  => r.dnaValid,
         dataOut => dnaValid);

   SyncData : entity surf.SynchronizerVector
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 2,
         WIDTH_G  => DNA_SHIFT_LENGTH_C)
      port map (
         clk     => clk,
         dataIn  => r.dnaValue,
         dataOut => dnaValue);

end rtl;
