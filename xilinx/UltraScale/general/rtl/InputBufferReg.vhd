-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Output Registers
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


library surf;
use surf.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity InputBufferReg is
   generic (
      TPD_G          : time    := 1 ns;
      DIFF_PAIR_G    : boolean := false;
      DDR_CLK_EDGE_G : string  := "OPPOSITE_EDGE");
   port (
      I  : in  sl;
      IB : in  sl := '1';
      C  : in  sl;
      CE : in  sl := '1';
      R  : in  sl := '0';
      Q1 : out sl;
      Q2 : out sl);
end InputBufferReg;

architecture rtl of InputBufferReg is

   signal inputSig : sl;
   signal CB       : sl;

begin

   GEN_IBUF : if (DIFF_PAIR_G = false) generate
      U_IBUFDS : IBUF
         port map (
            I => I,
            O => inputSig);
   end generate;

   GEN_IBUFDS : if (DIFF_PAIR_G = true) generate
      U_IBUFDS : IBUFDS
         port map (
            I  => I,
            IB => IB,
            O  => inputSig);
   end generate;

   U_IDDR : IDDRE1
      generic map (
         DDR_CLK_EDGE => DDR_CLK_EDGE_G)  -- "OPPOSITE_EDGE", "SAME_EDGE", or "SAME_EDGE_PIPELINED"
      port map (
         Q1 => Q1,  -- 1-bit output: Registered parallel output 1
         Q2 => Q2,  -- 1-bit output: Registered parallel output 2
         C  => C,                       -- 1-bit input: High-speed clock
         CB => CB,  -- 1-bit input: Inversion of High-speed clock C
         D  => inputSig, -- 1-bit input: Serial Data Input
         R  => R);  -- 1-bit input: Active High Async Reset

   CB <= not(C);

end rtl;
