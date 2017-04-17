-------------------------------------------------------------------------------
-- File       : Jesd16bTo32b.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-02-24
-- Last update: 2016-02-24
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
      TPD_G : time := 1 ns);
   port (
      -- 16-bit Write Interface
      wrClk    : in  sl;
      wrRst    : in  sl;
      validIn  : in  sl;
      overflow : out sl;
      dataIn   : in  slv(15 downto 0);
      -- 32-bit Read Interface
      rdClk    : in  sl;
      rdRst    : in  sl;
      validOut : out sl;
      underflow: out sl;
      dataOut  : out slv(31 downto 0));    
end Jesd16bTo32b;

architecture rtl of Jesd16bTo32b is

   type RegType is record
      wordSel : sl;
      wrEn    : sl;
      data    : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      wordSel => '0',
      wrEn    => '0',
      data    => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   signal s_valid  : sl;
   
begin

   comb : process (r, wrRst, validIn, dataIn) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;
      
      -- Check if data valid
      if validIn = '1' then
         if r.wordSel = '0' then
            -- Set the flags and data bus
            v.wordSel := '1';
            v.data(15 downto 0)    := dataIn;
            v.wrEn := '0';
         else
            -- Set the flags and data bus
            v.wordSel := '0';
            v.data(31 downto 16)    := dataIn;
            v.wrEn := '1';
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
      wr_en  => r.wrEn,
      din    => r.data,
      overflow => overflow,
      -- Read Ports (rd_clk domain)
      rd_clk => rdClk,
      rd_en  => s_valid,
      dout   => dataOut,
      underflow => underflow,
      valid  => s_valid);

   validOut <= s_valid;

   seq : process (wrClk) is
   begin
      if (rising_edge(wrClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
