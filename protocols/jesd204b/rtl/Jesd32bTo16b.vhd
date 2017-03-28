-------------------------------------------------------------------------------
-- File       : Jesd32bTo16b.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-02-24
-- Last update: 2016-02-24
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
      TPD_G : time := 1 ns);
   port (
      -- 32-bit Write Interface
      wrClk    : in  sl;
      wrRst    : in  sl;
      validIn  : in  sl;
      overflow : out sl;
      dataIn   : in  slv(31 downto 0);
      -- 16-bit Read Interface
      rdClk    : in  sl;
      rdRst    : in  sl;
      validOut : out sl;
      underflow: out sl;
      dataOut  : out slv(15 downto 0));     
end Jesd32bTo16b;

architecture rtl of Jesd32bTo16b is

   type RegType is record
      rdEn    : sl;
      wordSel : sl;
      valid   : sl;
      data    : slv(15 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      rdEn    => '0',
      wordSel => '0',
      valid   => '0',
      data    => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rdEn  : sl;
   signal valid : sl;
   signal data  : slv(31 downto 0);

   -- attribute dont_touch               : string;
   -- attribute dont_touch of r          : signal is "TRUE";
   
begin

   U_FIFO : entity work.FifoAsync
      generic map (
         TPD_G         => TPD_G,
         BRAM_EN_G     => false,
         FWFT_EN_G     => true,
         ALTERA_SYN_G  => false,
         SYNC_STAGES_G => 3,
         DATA_WIDTH_G  => 32,
         ADDR_WIDTH_G  => 5)
      port map (
         -- Asynchronous Reset
         rst    => wrRst,
         -- Write Ports (wr_clk domain)
         wr_clk => wrClk,
         wr_en  => validIn,
         din    => dataIn,
         overflow => overflow,
         -- Read Ports (rd_clk domain)
         rd_clk => rdClk,
         rd_en  => rdEn,
         dout   => data,
         underflow => underflow,
         valid  => valid);

   comb : process (data, r, rdRst, valid) is
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
         else
            -- Set the flags and data bus
            v.wordSel := '0';
            v.data    := data(31 downto 16);
            -- Acknowledge the FIFO read
            v.rdEn    := '1';
         end if;
      end if;

      -- Synchronous Reset
      if (rdRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      rdEn     <= v.rdEn;
      validOut <= r.valid;
      dataOut  <= r.data;
      
   end process comb;

   seq : process (rdClk) is
   begin
      if (rising_edge(rdClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
