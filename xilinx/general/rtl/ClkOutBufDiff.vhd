-------------------------------------------------------------------------------
-- File       : ClkOutBuf.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-12-07
-- Last update: 2015-04-28
-------------------------------------------------------------------------------
-- Description: Special buffer for outputting a clock on Xilinx FPGA pins.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use work.StdRtlPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity ClkOutBufDiff is
   generic (
      TPD_G          : time    := 1 ns;
      XIL_DEVICE_G   : string  := "7SERIES";
      RST_POLARITY_G : sl      := '1';
      INVERT_G       : boolean := false);
   port (
      rstIn   : in  sl := not RST_POLARITY_G;  -- Optional reset
      outEnL  : in  sl := '0';                 -- optional tristate (0 = enabled, 1 = high z output)
      clkIn   : in  sl;                        -- Input clock
      clkOutP : out sl;                        -- differential output buffer
      clkOutN : out sl);                       -- differential output buffer
end ClkOutBufDiff;

architecture rtl of ClkOutBufDiff is

   signal clkDdr : sl;
   signal rst    : sl;

begin

   rst <= rstIn when(RST_POLARITY_G = '1') else not(rstIn);

   GEN_7SERIES : if (XIL_DEVICE_G = "7SERIES") generate
      ODDR_I : ODDR
         port map (
            C  => clkIn,
            Q  => clkDdr,
            CE => '1',
            D1 => toSl(not INVERT_G),
            D2 => toSl(INVERT_G),
            R  => rst,
            S  => '0');
   end generate;

   GEN_ULTRA_SCALE : if (XIL_DEVICE_G = "ULTRASCALE") generate
      ODDR_I : ODDRE1
         port map (
            C  => clkIn,
            Q  => clkDdr,
            D1 => toSl(not INVERT_G),
            D2 => toSl(INVERT_G),
            SR => rst);
   end generate;

   -- Differential output buffer
   OBUFDS_I : OBUFTDS
      port map (
         I  => clkDdr,
         T  => outEnL,
         O  => clkOutP,
         OB => clkOutN);

end rtl;
