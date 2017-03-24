-------------------------------------------------------------------------------
-- File       : Encode12b14b.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-10-07
-- Last update: 2016-10-12
-------------------------------------------------------------------------------
-- Description: 12B14B Encoder Module
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
use work.Code12b14bPkg.all;
use work.Code12b14bConstPkg.all;

entity Encoder12b14b is

   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '0';
      RST_ASYNC_G    : boolean  := false;
      DEBUG_DISP_G   : boolean  := false);
   port (
      clk      : in  sl;
      clkEn    : in  sl := '1';                 -- Optional Clock Enable
      rst      : in  sl := not RST_POLARITY_G;  -- Optional Reset
      dataIn   : in  slv(11 downto 0);
      dispIn   : in  slv(1 downto 0);
      dataKIn  : in  sl;
      dataOut  : out slv(13 downto 0);
      dispOut  : out slv(1 downto 0));

end entity Encoder12b14b;

architecture rtl of Encoder12b14b is

   type RegType is record
      dispOut  : slv(1 downto 0);
      dataOut  : slv(13 downto 0);
--      invalidK : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      dispOut  => "01",
      dataOut  => (others => '0'));
--      invalidK => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (dataIn, dataKIn, dispIn, r, rst) is
      variable v          : RegType;
      variable dispInTmp  : RunDisparityType;
      variable invalidK : sl;
   begin
      v := r;

      if (DEBUG_DISP_G = false) then
         dispInTmp := r.dispOut;
      else
         dispInTmp := dispIn;
      end if;

      encode12b14b(
         CODES_C  => ENCODE_TABLE_C,
         dataIn   => dataIn,
         dataKIn  => dataKIn,
         dispIn   => dispInTmp,
         dataOut  => v.dataOut,
         dispOut  => v.dispOut,
         invalidK => invalidK);

      -- Synchronous reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin     <= v;
      dataOut <= r.dataOut;
      dispOut <= r.dispOut;
--      invalidK <= r.invalidK;
   end process comb;

   seq : process (clk, rst) is
   begin
      if (rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif (rising_edge(clk)) then
         if clkEn = '1' then
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

end architecture rtl;
