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

entity OutputBufferReg is
   generic (
      TPD_G          : time    := 1 ns;
      DIFF_PAIR_G    : boolean := false;
      DDR_CLK_EDGE_G : string  := "SAME_EDGE";
      INIT_G         : bit     := '0';
      SRTYPE_G       : string  := "SYNC");
   port (
      I   : in  sl;
      C   : in  sl;
      CE  : in  sl := '1';
      R   : in  sl := '0';
      S   : in  sl := '0';
      T   : in  sl := '0';  -- optional tristate (0 = enabled, 1 = high z output)
      inv : in  sl := '0';
      dly : in  sl := '0';
      O   : out sl;
      OB  : out sl := '1');
end OutputBufferReg;

architecture rtl of OutputBufferReg is

   signal mask      : sl := '0';
   signal maskDly   : sl := '0';
   signal D1        : sl := '0';
   signal D2        : sl := '0';
   signal outputSig : sl := '0';

begin

   ----------------------------------
   -- Set the command polarity output
   ----------------------------------
   mask <= I xor inv;

   --------------------------
   -- Generate a delayed copy
   --------------------------
   process(C)
   begin
      if rising_edge(C) then
         maskDly <= mask after TPD_G;
      end if;
   end process;

   --------------------------------------------------
   -- Add the ability to deskew I by half clock cycle
   --------------------------------------------------
   D1 <= mask when (dly = '0') else maskDly;
   D2 <= mask;

   U_ODDR : ODDR
      generic map(
         DDR_CLK_EDGE => DDR_CLK_EDGE_G,  -- "OPPOSITE_EDGE" or "SAME_EDGE"
         INIT         => INIT_G,  -- Initial value for Q port ('1' or '0')
         SRTYPE       => SRTYPE_G)      -- Reset Type ("ASYNC" or "SYNC")
      port map (
         Q  => outputSig,               -- 1-bit DDR output
         C  => C,                       -- 1-bit clock input
         CE => CE,                      -- 1-bit clock enable input
         D1 => D1,                      -- 1-bit input: Parallel data input 1
         D2 => D2,                      -- 1-bit input: Parallel data input 2
         R  => R);                      -- 1-bit reset input

   GEN_OBUF : if (DIFF_PAIR_G = false) generate
      U_OBUFDS : OBUFT
         port map (
            I => outputSig,
            T => T,
            O => O);
   end generate;

   GEN_OBUFDS : if (DIFF_PAIR_G = true) generate
      U_OBUFDS : OBUFTDS
         port map (
            I  => outputSig,
            T  => T,
            O  => O,
            OB => OB);
   end generate;

end rtl;
