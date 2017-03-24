-------------------------------------------------------------------------------
-- File       : SlvDelay.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-14
-- Last update: 2016-06-03
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
      RST_POLARITY_G : sl       := '1';    -- '1' for active HIGH reset, '0' for active LOW reset
      SRL_EN_G       : boolean  := false;  -- Allow an SRL to be inferred. Disables reset.
      DELAY_G        : natural  := 1;  --number of clock cycle delays. MAX delay stages when using
                                        --delay input
      REG_OUTPUT_G : boolean := false;  -- For use with Dynamic SRLs, adds extra delay register on output
      WIDTH_G        : positive := 1;
      INIT_G         : slv      := "0");
   port (
      clk   : in  sl;
      rst   : in  sl                            := not RST_POLARITY_G;  -- Optional reset
      en    : in  sl                            := '1';                 -- Optional clock enable
      delay : in  slv(log2(DELAY_G)-1 downto 0) := toSlv(DELAY_G-1, log2(DELAY_G));
      din   : in  slv(WIDTH_G-1 downto 0);
      dout  : out slv(WIDTH_G-1 downto 0));
end entity SlvDelay;

architecture rtl of SlvDelay is

   constant INIT_C : slv(WIDTH_G-1 downto 0) := ite(INIT_G = "0", slvZero(WIDTH_G), INIT_G);

   type VectorArray is array (DELAY_G-1 downto 0) of slv(WIDTH_G-1 downto 0);

   type RegType is record
      shift : VectorArray;
   end record RegType;
   constant REG_INIT_C : RegType := (
      shift => (others => INIT_C));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal iDelay : natural;
   signal iDout : slv(WIDTH_G-1 downto 0);

   constant SRL_C               : string := ite(SRL_EN_G, "YES", "NO");
   attribute shreg_extract      : string;
   attribute shreg_extract of r : signal is SRL_C;

begin

   NO_DELAY : if (DELAY_G = 0) generate
      dout <= din;
   end generate NO_DELAY;

   YES_DELAY : if (DELAY_G > 0) generate

      iDelay <= conv_integer(delay);

      comb : process (din, en, iDelay, r, rst) is
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
         if (rst = RST_POLARITY_G and not SRL_EN_G) then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs        
         iDout <= r.shift(iDelay);

      end process comb;

      seq : process (clk) is
      begin
         if rising_edge(clk) then
            r <= rin after TPD_G;
         end if;
      end process seq;

      OUT_REG: if (REG_OUTPUT_G) generate
         REG: process (clk) is
         begin
            if (rising_edge(clk)) then
               if (rst = '1') then
                  dout <= INIT_C;
               else
                  dout <= iDout;                  
               end if;
            end if;
         end process REG;
      end generate OUT_REG;

      NO_OUT_REG: if (not REG_OUTPUT_G) generate
         dout <= iDout;
      end generate NO_OUT_REG;
      
   end generate YES_DELAY;
   
end rtl;
