-------------------------------------------------------------------------------
-- File       : DspCounter.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-12
-- Last update: 2013-08-02
-------------------------------------------------------------------------------
-- Description: Example of Counter that infers a DSP48 via "use_dsp48" attribute
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

entity DspCounter is
   generic (
      TPD_G          : time                  := 1 ns;
      RST_POLARITY_G : sl                    := '1';  -- '1' for active high rst, '0' for active low
      RST_ASYNC_G    : boolean               := false;
      DATA_WIDTH_G   : integer range 1 to 48 := 16;
      INCREMENT_G    : integer range 1 to 48 := 1);
   port (
      clk : in  sl := '0';
      rst : in  sl := '0';
      en  : in  sl := '1';
      cnt : out slv(DATA_WIDTH_G-1 downto 0));
end DspCounter;

architecture rtl of DspCounter is
   -- Constants
   constant INCREMENT_C : slv(DATA_WIDTH_G-1 downto 0) := conv_std_logic_vector(INCREMENT_G, DATA_WIDTH_G);

   -- Signals
   signal counter : slv(DATA_WIDTH_G-1 downto 0) := (others => '0');

   -- Attribute for XST
   attribute use_dsp48            : string;
   attribute use_dsp48 of counter : signal is "yes";
   
begin

   -- INCREMENT_G range check
   assert (INCREMENT_G <= ((2**DATA_WIDTH_G)-1))
      report "INCREMENT_G must be <= ((2**DATA_WIDTH_G)-1)"
      severity failure;

   cnt <= counter;

   process(clk, rst)
   begin
      --asychronous reset
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         counter <= (others => '0') after TPD_G;
      elsif rising_edge(clk) then
         --sychronous reset
         if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
            counter <= (others => '0') after TPD_G;
         else
            if en = '1' then
               counter <= counter + INCREMENT_C after TPD_G;
            end if;
         end if;
      end if;
   end process;
   
end rtl;
