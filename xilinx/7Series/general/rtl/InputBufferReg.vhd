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
      DDR_CLK_EDGE_G : string  := "OPPOSITE_EDGE";
      INIT_Q1_G      : bit     := '0';
      INIT_Q2_G      : bit     := '0';
      SRTYPE_G       : string  := "SYNC");
   port (
      I  : in  sl;
      IB : in  sl := '1';
      C  : in  sl;
      CE : in  sl := '1';
      R  : in  sl := '0';
      S  : in  sl := '0';
      Q1 : out sl;
      Q2 : out sl);
end InputBufferReg;

architecture rtl of InputBufferReg is

   signal inputSig : sl;

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

   U_IDDR : IDDR
      generic map (
         DDR_CLK_EDGE => DDR_CLK_EDGE_G,  -- "OPPOSITE_EDGE", "SAME_EDGE", or "SAME_EDGE_PIPELINED"
         INIT_Q1      => INIT_Q1_G,     -- Initial value of Q1: '0' or '1'
         INIT_Q2      => INIT_Q2_G,     -- Initial value of Q2: '0' or '1'
         SRTYPE       => SRTYPE_G)      -- Set/Reset type: "SYNC" or "ASYNC"
      port map (
         Q1 => Q1,  -- 1-bit output for positive edge of clock
         Q2 => Q2,  -- 1-bit output for negative edge of clock
         C  => C,                       -- 1-bit clock input
         CE => CE,                      -- 1-bit clock enable input
         D  => inputSig,                -- 1-bit DDR data input
         R  => R,                       -- 1-bit reset
         S  => S);                      -- 1-bit set

end rtl;
