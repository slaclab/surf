-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Encode12b14b.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-10-07
-- Last update: 2016-10-19
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of <PROJECT_NAME>. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of <PROJECT_NAME>, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.StdRtlPkg.all;
use work.Code10b12bPkg.all;

entity Encoder10b12b is

   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := true;
      CLK_EN_G       : boolean := false;
      DEBUG_DISP_G   : boolean := false);
   port (
      clk     : in  sl;
      clkEn   : in  sl := '1';                 -- Optional Clock Enable
      rst     : in  sl := not RST_POLARITY_G;  -- Optional Reset
      dataIn  : in  slv(9 downto 0);
      dispIn  : in  sl;
      dataKIn : in  sl;
      dataOut : out slv(11 downto 0);
      dispOut : out sl);

end entity Encoder10b12b;

architecture rtl of Encoder10b12b is

   type RegType is record
      dispOut : sl;
      dataOut : slv(11 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      dispOut => '0',
      dataOut => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (dataIn, dataKIn, dispIn, r, rst) is
      variable v         : RegType;
      variable dispInTmp : sl;
   begin
      v := r;

      if (DEBUG_DISP_G = false) then
         dispInTmp := r.dispOut;
      else
         dispInTmp := dispIn;
      end if;

      encode10b12b(
         dataIn  => dataIn,
         dataKIn => dataKIn,
         dispIn  => dispInTmp,
         dataOut => v.dataOut,
         dispOut => v.dispOut);

      -- Synchronous reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin     <= v;
      dataOut <= r.dataOut;
      dispOut <= r.dispOut;
   end process comb;

   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif (rising_edge(clk)) then
         if (CLK_EN_G = false or clkEn = '1') then
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

end architecture rtl;
