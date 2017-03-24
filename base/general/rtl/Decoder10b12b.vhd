-------------------------------------------------------------------------------
-- File       : Decoder10b12b.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-10-07
-- Last update: 2016-10-26
-------------------------------------------------------------------------------
-- Description: 10B12B Decoder Module
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
use work.StdRtlPkg.all;
use work.Code10b12bPkg.all;

entity Decoder10b12b is

   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '0';
      RST_ASYNC_G    : boolean := true;
      USE_CLK_EN_G   : boolean := false);
   port (
      clk       : in  sl;
      clkEn     : in  sl := '1';                 -- Optional Clock Enable
      rst       : in  sl := not RST_POLARITY_G;  -- Optional Reset
      dataIn    : in  slv(11 downto 0);
      dataOut   : out slv(9 downto 0);
      dataKOut  : out sl;
      dispOut   : out sl;
      codeError : out sl;
      dispError : out sl);

end entity Decoder10b12b;

architecture rtl of Decoder10b12b is

   type RegType is record
      dispOut   : sl;
      dataOut   : slv(9 downto 0);
      dataKOut  : sl;
      codeError : sl;
      dispError : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      dispOut   => '0',
      dataOut   => (others => '0'),
      dataKOut  => '0',
      codeError => '0',
      dispError => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (dataIn, r, rst) is
      variable v         : RegType;
   begin
      v := r;

      decode10b12b(
         dataIn    => dataIn,
         dispIn    => r.dispOut,
         dataOut   => v.dataOut,
         dataKOut  => v.dataKOut,
         dispOut   => v.dispOut,
         codeError => v.codeError,
         dispError => v.dispError);

      -- Synchronous reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin       <= v;
      dataOut   <= r.dataOut;
      dataKOut  <= r.dataKOut;
      dispOut   <= r.dispOut;
      codeError <= r.codeError;
      dispError <= r.dispError;
   end process comb;

   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif (rising_edge(clk)) then
         if (USE_CLK_EN_G = false or clkEn = '1') then
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

end architecture rtl;
