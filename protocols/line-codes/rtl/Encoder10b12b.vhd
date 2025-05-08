-------------------------------------------------------------------------------
-- Title      : Line Code 10B12B: https://confluence.slac.stanford.edu/x/QndODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 10B12B Encoder Module
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

library surf;
use surf.StdRtlPkg.all;
use surf.Code10b12bPkg.all;

entity Encoder10b12b is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '0';
      RST_ASYNC_G    : boolean := true;
      USE_CLK_EN_G   : boolean := false;
      FLOW_CTRL_EN_G : boolean := false);
   port (
      clk      : in  sl;
      clkEn    : in  sl := '1';                 -- Optional Clock Enable
      rst      : in  sl := not RST_POLARITY_G;  -- Optional Reset
      validIn  : in  sl := '1';
      readyIn  : out sl;
      dataIn   : in  slv(9 downto 0);
      dataKIn  : in  sl;
      validOut : out sl;
      readyOut : in  sl := '1';
      dataOut  : out slv(11 downto 0);
      dispOut  : out sl);
end entity Encoder10b12b;

architecture rtl of Encoder10b12b is

   type RegType is record
      validOut : sl;
      readyIn  : sl;
      dispOut  : sl;
      dataOut  : slv(11 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      validOut => toSl(not FLOW_CTRL_EN_G),
      readyIn  => '0',
      dispOut  => '0',
      dataOut  => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (dataIn, dataKIn, r, readyOut, rst, validIn) is
      variable v : RegType;
   begin
      v := r;

      v.readyIn := readyOut;
      if (readyOut = '1' and FLOW_CTRL_EN_G) then
         v.validOut := '0';
      end if;

      if ((v.validOut = '0') and (validIn = '1')) or (FLOW_CTRL_EN_G = false) then
         v.validOut := '1';
         encode10b12b(
            dataIn  => dataIn,
            dataKIn => dataKIn,
            dispIn  => r.dispOut,
            dataOut => v.dataOut,
            dispOut => v.dispOut);
      end if;

      -- Combinatorial outputs before the reset
      readyIn <= v.readyIn;

      -- Synchronous reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin      <= v;
      dataOut  <= r.dataOut;
      dispOut  <= r.dispOut;
      validOut <= r.validOut;
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
