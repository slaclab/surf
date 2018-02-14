-------------------------------------------------------------------------------
-- File       : DspFp32Max.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-09-18
-- Last update: 2018-02-14
-------------------------------------------------------------------------------
-- Description: 32-bit Floating Point DSP inferred maximum module  
-- Equation: p = max(a[i])
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

--------------------------------------
-- Comment out these for simulation --
--------------------------------------
use ieee.fixed_float_types.all;
use ieee.float_pkg.all;
--------------------------------------

-- synthesis translate_off
library ieee_proposed;
use ieee_proposed.fixed_float_types.all;
use ieee_proposed.float_pkg.all;
-- synthesis translate_on

use work.StdRtlPkg.all;
use work.DspPkg.all;

entity DspFp32Max is
   generic (
      TPD_G          : time                 := 1 ns;
      RST_POLARITY_G : sl                   := '1';  -- '1' for active high rst, '0' for active low
      USE_DSP_G      : string               := "yes";
      PIPE_STAGES_G  : natural range 0 to 1 := 0);
   port (
      clk     : in  sl;
      rst     : in  sl := not(RST_POLARITY_G);
      -- Inbound Interface
      ibValid : in  sl := '1';
      ibReady : out sl;
      ain     : in  slv(31 downto 0);
      load    : in  sl := '0';
      -- Outbound Interface
      obValid : out sl;
      obReady : in  sl := '1';
      pOut    : out slv(31 downto 0));
end DspFp32Max;

architecture rtl of DspFp32Max is

   type RegType is record
      ibReady : sl;
      tValid  : sl;
      p       : float32;
   end record RegType;
   constant REG_INIT_C : RegType := (
      ibReady => '0',
      tValid  => '0',
      p       => FP32_ZERO_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal tReady : sl;

   signal p : slv(31 downto 0);

   attribute use_dsp48      : string;
   attribute use_dsp48 of r : signal is USE_DSP_G;

begin

   comb : process (ain, ibValid, load, r, rst, tReady) is
      variable v : RegType;
      variable a : float32;
   begin
      -- Latch the current value
      v := r;

      -- typecast from slv to float32
      a := float32(ain);

      -- Reset the flags
      v.ibReady := '0';
      if tReady = '1' then
         v.tValid := '0';
      end if;

      -- Check if ready to process data
      if (v.tValid = '0') and (ibValid = '1') then
         -- Set the flow control flags
         v.ibReady := '1';
         v.tValid  := '1';
         -- Process the data
         if (load = '1') then
            v.p := a;
         elsif (a > r.p) then
            v.p := a;
         end if;
      end if;

      -- Combinatorial outputs before the reset
      ibReady <= v.ibReady;

      -- Reset
      if (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs              
      p <= std_logic_vector(r.p);

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_Pipe : entity work.FifoOutputPipeline
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         DATA_WIDTH_G   => 32,
         PIPE_STAGES_G  => PIPE_STAGES_G)
      port map (
         -- Slave Port         
         sData  => p,
         sValid => r.tValid,
         sRdEn  => tReady,
         -- Master Port
         mData  => pOut,
         mValid => obValid,
         mRdEn  => obReady,
         -- Clock and Reset
         clk    => clk,
         rst    => rst);

end rtl;
