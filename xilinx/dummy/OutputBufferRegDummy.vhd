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

entity OutputBufferReg is
   generic (
      TPD_G          : time    := 1 ns;
      DIFF_PAIR_G    : boolean := false;
      DDR_CLK_EDGE_G : string  := "SAME_EDGE";
      INIT_G         : bit     := '0';
      SRTYPE_G       : string  := "SYNC");
   port (
      I   : in  sl := '0';
      C   : in  sl := '0';
      CE  : in  sl := '1';
      R   : in  sl := '0';
      SR  : in  sl := '0';
      S   : in  sl := '0';
      T   : in  sl := '0';  -- optional tristate (0 = enabled, 1 = high z output)
      inv : in  sl := '0';
      dly : in  sl := '0';
      O   : out sl := '0';
      OB  : out sl := '1');
end OutputBufferReg;

architecture mapping of OutputBufferReg is

begin

   assert (false)
      report "surf.xilinx: OutputBufferReg not supported" severity failure;

end mapping;
