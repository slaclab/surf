-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DeviceDnaUltraScale.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-17
-- Last update: 2015-06-18
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Wrapper for the UltraScale DNA_PORT
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity DeviceDnaUltraScale is
   generic (
      TPD_G           : time    := 1 ns;
      USE_SLOWCLK_G   : boolean := false;
      RST_POLARITY_G  : sl      := '1';
      SIM_DNA_VALUE_G : slv     := X"000000000000000000000000");
   port (
      clk      : in  sl;
      rst      : in  sl;
      slowClk  : in  sl := '0';
      dnaValue : out slv(63 downto 0);
      dnaValid : out sl);
end DeviceDnaUltraScale;

architecture rtl of DeviceDnaUltraScale is
   
   constant DNA_SHIFT_LENGTH_C : natural := 64;

   type StateType is (READ_S, SHIFT_S, DONE_S);

   type RegType is record
      state    : StateType;
      bitCount : natural range 0 to DNA_SHIFT_LENGTH_C-1;
      dnaValue : slv(63 downto 0);
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

begin

   locClk <= slowClk when(USE_SLOWCLK_G) else divClk;

   BUFGCE_DIV_Inst : BUFGCE_DIV
      generic map (
         BUFGCE_DIVIDE => 8)
      port map (
         I   => clk,
         CE  => '1',
         CLR => '0',
         O   => divClk);

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
               v.dnaValue := r.dnaValue(62 downto 0) & dnaDout;
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

   sync : process (locClk) is
   begin
      if (falling_edge(locClk)) then
         r <= rin after TPD_G;
      end if;
   end process sync;

   DNA_PORT_I : DNA_PORTE2
      generic map (
         SIM_DNA_VALUE => SIM_DNA_VALUE_G)
      port map (
         CLK   => locClk,
         READ  => r.dnaRead,
         SHIFT => r.dnaShift,
         DIN   => '0',
         DOUT  => dnaDout);

   SyncFifo : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 65)
      port map (
         rst               => locRst,
         wr_clk            => locClk,
         din(64)           => r.dnaValid,
         din(63 downto 0)  => r.dnaValue,
         rd_clk            => clk,
         dout(64)          => dnaValid,
         dout(63 downto 0) => dnaValue);                

end rtl;
