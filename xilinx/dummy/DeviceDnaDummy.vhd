-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for the DNA_PORT
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
use surf.TextUtilPkg.all;

entity DeviceDna is
   generic (
      TPD_G           : time     := 1 ns;
      XIL_DEVICE_G    : string   := "7SERIES";  -- Either "7SERIES" or "ULTRASCALE" or "ULTRASCALE_PLUS"
      USE_SLOWCLK_G   : boolean  := false;
      BUFR_CLK_DIV_G  : positive := 8;
      RST_POLARITY_G  : sl       := '1';
      SIM_DNA_VALUE_G : slv      := X"000000000000000000000000");
   port (
      clk      : in  sl;
      rst      : in  sl;
      slowClk  : in  sl                := '0';
      dnaValue : out slv(127 downto 0) := (others => '0');
      dnaValid : out sl                := '0');
end DeviceDna;

architecture mapping of DeviceDna is

begin

   assert (false)
      report "surf.xilinx: DeviceDna not supported" severity failure;

end mapping;
