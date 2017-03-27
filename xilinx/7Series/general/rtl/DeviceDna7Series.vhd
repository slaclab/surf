-------------------------------------------------------------------------------
-- File       : DeviceDna7Series.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-09-25
-- Last update: 2016-12-06
-------------------------------------------------------------------------------
-- Description: Wrapper for the 7 Series DNA_PORT
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

use work.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity DeviceDna7Series is
   generic (
      TPD_G           : time       := 1 ns;
      USE_SLOWCLK_G   : boolean    := false;
      BUFR_CLK_DIV_G  : string     := "8";
      RST_POLARITY_G  : sl         := '1';
      SIM_DNA_VALUE_G : bit_vector := X"000000000000000");
   port (
      clk      : in  sl;
      rst      : in  sl;
      slowClk  : in  sl := '0';
      dnaValue : out slv(55 downto 0);
      dnaValid : out sl);
end DeviceDna7Series;

architecture rtl of DeviceDna7Series is

   constant DNA_SHIFT_LENGTH_C : natural := 64;

   type StateType is (READ_S, SHIFT_S, DONE_S);

   type RegType is record
      state    : StateType;
      bitCount : natural range 0 to DNA_SHIFT_LENGTH_C-1;
      dnaValue : slv(DNA_SHIFT_LENGTH_C-1 downto 0);
      dnaValid : sl;
      dnaRead  : sl;
      dnaShift : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state    => READ_S,
      bitCount => 0,
      dnaValue => (others => '0'),
      dnaValid => '0',
      dnaRead  => '0',
      dnaShift => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dnaDout : sl;
   signal divClk  : sl;
   signal locClk  : sl;
   signal locRst  : sl;

   signal locClkInv : sl;
   signal locClkInvR : sl;

begin

   locClk <= slowClk when(USE_SLOWCLK_G) else divClk;

   locClkInv <= not locClk;

   BUFR_Inst : BUFR
      generic map (
         BUFR_DIVIDE => BUFR_CLK_DIV_G,
         SIM_DEVICE  => "7SERIES")
      port map (
         I   => clk,
         CE  => '1',
         CLR => '0',
         O   => divClk);

   DNA_CLK_INV_BUFR : BUFR
      generic map (
         BUFR_DIVIDE => "1",
         SIM_DEVICE  => "7SERIES")
      port map (
         I   => locClkInv,
         CE  => '1',
         CLR => '0',
         O   => locClkInvR);
   

   RstSync_Inst : entity work.RstSync
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
      v.dnaShift := '0';

      -- State Machine      
      case (r.state) is
         ----------------------------------------------------------------------
         when READ_S =>
            -- Check the read strobe status
            if r.dnaRead = '0' then
               -- Strobe the read of the DNA port
               v.dnaRead := '1';
               -- Next State
               v.state   := SHIFT_S;
            end if;
         ----------------------------------------------------------------------
         when SHIFT_S =>
            -- Shift the data out
            v.dnaShift := '1';
            -- Check the shift strobe status
            if r.dnaShift = '1' then
               -- Shift register
               v.dnaValue := r.dnaValue(DNA_SHIFT_LENGTH_C-2 downto 0) & dnaDout;
               -- Increment the counter
               v.bitCount := r.bitCount + 1;
               -- Check the counter value
               if (r.bitCount = DNA_SHIFT_LENGTH_C-1) then
                  -- Next State
                  v.state := DONE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DONE_S =>
            -- Set the valid bit
            v.dnaValid := '1';
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if locRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   sync : process (locClkInvR) is
   begin
      if (rising_edge(locClkInvR)) then
         r <= rin after TPD_G;
      end if;
   end process sync;

   DNA_PORT_I : DNA_PORT
      generic map (
         SIM_DNA_VALUE => SIM_DNA_VALUE_G)
      port map (
         CLK   => locClk,
         READ  => r.dnaRead,
         SHIFT => r.dnaShift,
         DIN   => '0',
         DOUT  => dnaDout);

   SyncValid : entity work.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 3)
      port map (
         clk     => clk,
         dataIn  => r.dnaValid,
         dataOut => dnaValid);

   SyncData : entity work.SynchronizerVector
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 2,
         WIDTH_G  => 56)
      port map (
         clk     => clk,
         dataIn  => r.dnaValue(63 downto 8),
         dataOut => dnaValue);

end rtl;
