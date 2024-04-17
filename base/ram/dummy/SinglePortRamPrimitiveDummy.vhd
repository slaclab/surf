-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Manual instantiation of RAM32X1S, RAM64X1S, RAM128X1S,
--                 RAM256X1S, or RAM512X1S.
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

entity SinglePortRamPrimitive is
   generic (
      TPD_G        : time                   := 1 ns;
      XIL_DEVICE_G : string                 := "ULTRASCALE_PLUS";
      DEPTH_G      : integer range 1 to 512 := 64;
      WIDTH_G      : positive               := 16);
   port (
      clk  : in  sl                              := '0';
      we   : in  sl                              := '1';
      addr : in  slv(log2(DEPTH_G) - 1 downto 0) := (others => '0');
      din  : in  slv(WIDTH_G - 1 downto 0)       := (others => '0');
      dout : out slv(WIDTH_G - 1 downto 0)       := (others => '0'));
end entity SinglePortRamPrimitive;

architecture mapping of SinglePortRamPrimitive is

begin

   assert (false)
      report "surf.base.ram: SinglePortRamPrimitive not supported" severity failure;

end mapping;
