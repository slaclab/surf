-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SlvDelay.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-14
-- Last update: 2015-09-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Shift Register Delay module for std_logic_vectors
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

entity SlvDelay is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';  -- '1' for active HIGH reset, '0' for active LOW reset      
      DELAY_G        : natural  := 1;   --number of clock cycle delays
      WIDTH_G        : positive := 16;
      INIT_G         : slv      := "0");      
   port (
      clk  : in  sl;
      en   : in  sl := '1';             -- Optional clock enable
      rst  : in  sl := not RST_POLARITY_G;  -- Optional reset             
      din  : in  slv(WIDTH_G-1 downto 0);
      dout : out slv(WIDTH_G-1 downto 0));
end entity SlvDelay;

architecture rtl of SlvDelay is

   type VectorArray is array (DELAY_G-1 downto 0) of slv(WIDTH_G-1 downto 0);

   function FillVectorArray (INPUT : slv)
      return VectorArray is
      variable retVar : VectorArray := (others => (others => '0'));
   begin
      if INPUT = "0" then
         retVar := (others => (others => '0'));
      else
         for i in DELAY_G-1 downto 0 loop
            for j in WIDTH_G-1 downto 0 loop
               retVar(i)(j) := INIT_G(i);
            end loop;
         end loop;
      end if;
      return retVar;
   end function FillVectorArray;

   type RegType is record
      shift : VectorArray;
   end record RegType;
   constant REG_INIT_C : RegType := (
      shift => FillVectorArray(INIT_G));      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   NO_DELAY : if (DELAY_G = 0) generate
      dout <= din;
   end generate;

   DELAY : if (DELAY_G > 0) generate

      comb : process (din, en, r, rst) is
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Check for clock enable
         if en = '1' then
            -- Add new data
            v.shift(0) := din;
            -- Check for multi-stage delay
            if DELAY_G > 1 then
               -- Shift old data
               v.shift(DELAY_G-1 downto 1) := r.shift(DELAY_G-2 downto 0);
            end if;
         end if;

         -- Reset
         if (rst = RST_POLARITY_G) then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs        
         dout <= r.shift(DELAY_G-1);

      end process comb;

      seq : process (clk) is
      begin
         if rising_edge(clk) then
            r <= rin after TPD_G;
         end if;
      end process seq;
      
   end generate;

end rtl;
