-------------------------------------------------------------------------------
-- File       : Jesd32bTo16b.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Converts the 32-bit JESD interface to 16-bit interface
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

entity Jesd32bTo16b is
   generic (
      TPD_G            : time                 := 1 ns;
      RELATED_CLOCKS_G : natural range 0 to 1 := 0);
   port (
      -- 32-bit Write Interface
      wrClk     : in  sl;
      wrRst     : in  sl;
      validIn   : in  sl;
      trigIn    : in  slv(1 downto 0) := "00";
      overflow  : out sl;
      dataIn    : in  slv(31 downto 0);
      -- 16-bit Read Interface
      rdClk     : in  sl;
      rdRst     : in  sl;
      validOut  : out sl;
      trigOut   : out sl;
      underflow : out sl;
      dataOut   : out slv(15 downto 0));
end Jesd32bTo16b;

architecture rtl of Jesd32bTo16b is

   type RegType is record
      rdEn    : sl;
      wordSel : sl;
      valid   : sl;
      trig    : sl;
      data    : slv(15 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      rdEn    => '0',
      wordSel => '0',
      valid   => '0',
      trig    => '0',
      data    => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rdEn  : sl;
   signal valid : sl;
   signal trig  : slv(1 downto 0);
   signal data  : slv(31 downto 0);

   signal dummy : slv(63 downto 34);

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "TRUE";

begin

   U_FIFO : entity work.FifoXpm
      generic map (
         TPD_G            => TPD_G,
         RELATED_CLOCKS_G => RELATED_CLOCKS_G,
         ECC_MODE_G       => "en_ecc",
         MEMORY_TYPE_G    => "block",
         FWFT_EN_G        => true,
         GEN_SYNC_FIFO_G  => false,
         SYNC_STAGES_G    => 8,
         DATA_WIDTH_G     => 64,
         ADDR_WIDTH_G     => 8)
      port map (
         -- Asynchronous Reset
         rst                => wrRst,
         -- Write Ports (wr_clk domain)
         wr_clk             => wrClk,
         wr_en              => validIn,
         din(63 downto 34)  => (others => '0'),
         din(33 downto 32)  => trigIn,
         din(31 downto 0)   => dataIn,
         overflow           => overflow,
         -- Read Ports (rd_clk domain)
         rd_clk             => rdClk,
         rd_en              => rdEn,
         dout(63 downto 34) => dummy,
         dout(33 downto 32) => trig,
         dout(31 downto 0)  => data,
         underflow          => underflow,
         valid              => valid);

   comb : process (data, r, rdRst, trig, valid) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the strobes
      v.rdEn  := '0';
      v.valid := valid;

      -- Check if FIFO has data
      if r.valid = '1' then
         -- Check the 16-bit word select flag
         if r.wordSel = '0' then
            -- Set the flags and data bus
            v.wordSel := '1';
            v.data    := data(15 downto 0);
            v.trig    := trig(0);
         else
            -- Set the flags and data bus
            v.wordSel := '0';
            v.data    := data(31 downto 16);
            v.trig    := trig(1);
            -- Acknowledge the FIFO read
            v.rdEn    := '1';
         end if;
      end if;

      -- Combinatorial outputs before the reset
      rdEn <= v.rdEn;

      -- Synchronous Reset
      if (rdRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      validOut <= r.valid;
      trigOut  <= r.trig;
      dataOut  <= r.data;

   end process comb;

   seq : process (rdClk) is
   begin
      if (rising_edge(rdClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
