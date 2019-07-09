-------------------------------------------------------------------------------
-- File       : iq32bTo16b.vhd
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

entity iq32bTo16b is
   generic (
      TPD_G            : time                 := 1 ns;
      SYNC_STAGES_G    : natural range 2 to 8 := 8);
   port (
      -- 32-bit Write Interface
      wrClk     : in  sl;
      wrRst     : in  sl;
      validIn   : in  sl;
      overflow  : out sl;
      dataInI   : in  slv(31 downto 0);
      dataInQ   : in  slv(31 downto 0);
      -- 16-bit Read Interface
      rdClk     : in  sl;
      rdRst     : in  sl;
      validOut  : out sl;
      underflow : out sl;
      dataOutI  : out slv(15 downto 0);
      dataOutQ  : out slv(15 downto 0));
end iq32bTo16b;

architecture rtl of iq32bTo16b is

   type RegType is record
      rdEn    : sl;
      wordSel : sl;
      valid   : sl;
      dataI   : slv(15 downto 0);
      dataQ   : slv(15 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      rdEn    => '0',
      wordSel => '0',
      valid   => '0',
      dataI   => (others => '0'),
      dataQ   => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rdEn  : sl;
   signal valid : sl;
   signal dataI : slv(31 downto 0);
   signal dataQ : slv(31 downto 0);

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "TRUE";

begin

   U_FIFO : entity work.FifoAsync
      generic map (
         TPD_G            => TPD_G,
         BRAM_EN_G        => true,
         FWFT_EN_G        => true,
         SYNC_STAGES_G    => SYNC_STAGES_G,
         DATA_WIDTH_G     => 64,
         ADDR_WIDTH_G     => 8)
      port map (
         -- Asynchronous Reset
         rst                => wrRst,
         -- Write Ports (wr_clk domain)
         wr_clk             => wrClk,
         wr_en              => validIn,
         din(63 downto 32)  => dataInI,
         din(31 downto 0)   => dataInQ,
         overflow           => overflow,
         -- Read Ports (rd_clk domain)
         rd_clk             => rdClk,
         rd_en              => rdEn,
         dout(63 downto 32) => dataI,
         dout(31 downto 0)  => dataQ,
         underflow          => underflow,
         valid              => valid);

   comb : process (dataI, dataQ, r, rdRst, valid) is
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
            v.dataI   := dataI(15 downto 0);
            v.dataQ   := dataQ(15 downto 0);
         else
            -- Set the flags and data bus
            v.wordSel := '0';
            v.dataI   := dataI(31 downto 16);
            v.dataQ   := dataQ(31 downto 16);
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
      dataOutI <= r.dataI;
      dataOutQ <= r.dataQ;

   end process comb;

   seq : process (rdClk) is
   begin
      if (rising_edge(rdClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
