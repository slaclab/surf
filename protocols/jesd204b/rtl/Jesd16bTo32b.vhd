-------------------------------------------------------------------------------
-- File       : Jesd16bTo32b.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Converts the 16-bit interface to 32-bit JESD interface
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

entity Jesd16bTo32b is
   generic (
      TPD_G            : time                 := 1 ns;
      SYNC_STAGES_G    : natural range 2 to 8 := 8;
      RELATED_CLOCKS_G : natural range 0 to 1 := 0);
   port (
      -- 16-bit Write Interface
      wrClk     : in  sl;
      wrRst     : in  sl;
      validIn   : in  sl;
      trigIn    : in  sl := '0';
      overflow  : out sl;
      dataIn    : in  slv(15 downto 0);
      -- 32-bit Read Interface
      rdClk     : in  sl;
      rdRst     : in  sl;
      validOut  : out sl;
      trigOut   : out slv(1 downto 0);
      underflow : out sl;
      dataOut   : out slv(31 downto 0));
end Jesd16bTo32b;

architecture rtl of Jesd16bTo32b is

   type RegType is record
      wordSel : sl;
      wrEn    : sl;
      trig    : slv(1 downto 0);
      data    : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      wordSel => '0',
      wrEn    => '0',
      trig    => "00",
      data    => (others => '0'));

   signal r       : RegType := REG_INIT_C;
   signal rin     : RegType;
   signal s_valid : sl;

   signal dummy : slv(63 downto 34);

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "TRUE";

begin

   comb : process (dataIn, r, trigIn, validIn, wrRst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Check if data valid
      if validIn = '1' then
         if r.wordSel = '0' then
            -- Set the flags and data bus
            v.wordSel           := '1';
            v.data(15 downto 0) := dataIn;
            v.trig(0)           := trigIn;
            v.wrEn              := '0';
         else
            -- Set the flags and data bus
            v.wordSel            := '0';
            v.data(31 downto 16) := dataIn;
            v.trig(1)            := trigIn;
            v.wrEn               := '1';
         end if;
      else
         v := REG_INIT_C;
      end if;

      -- Synchronous Reset
      if (wrRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   U_FIFO : entity work.FifoXpm
      generic map (
         TPD_G            => TPD_G,
         RELATED_CLOCKS_G => RELATED_CLOCKS_G,
         ECC_MODE_G       => "en_ecc",
         MEMORY_TYPE_G    => "block",
         FWFT_EN_G        => true,
         GEN_SYNC_FIFO_G  => false,
         SYNC_STAGES_G    => SYNC_STAGES_G,
         DATA_WIDTH_G     => 64,
         ADDR_WIDTH_G     => 8)
      port map (
         -- Asynchronous Reset
         rst                => wrRst,
         -- Write Ports (wr_clk domain)
         wr_clk             => wrClk,
         wr_en              => r.wrEn,
         din(63 downto 34)  => (others => '0'),
         din(33 downto 32)  => r.trig,
         din(31 downto 0)   => r.data,
         overflow           => overflow,
         -- Read Ports (rd_clk domain)
         rd_clk             => rdClk,
         rd_en              => s_valid,
         dout(63 downto 34) => dummy,
         dout(33 downto 32) => trigOut,
         dout(31 downto 0)  => dataOut,
         underflow          => underflow,
         valid              => s_valid);

   validOut <= s_valid;

   seq : process (wrClk) is
   begin
      if (rising_edge(wrClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
