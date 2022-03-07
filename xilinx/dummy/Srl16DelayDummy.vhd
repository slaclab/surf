-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: SRL16 delay module - pack 2 SRL16 per slice
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

entity Srl16Delay is
   generic (
      TPD_G        : time                  := 1 ns;
      XIL_DEVICE_G : string                := "ULTRASCALE_PLUS";  -- "7SERIES" or "ULTRASCALE" or "ULTRASCALE_PLUS"
      DELAY_G      : natural range 3 to 17 := 3;  -- default number of clock cycle delays
      WIDTH_G      : positive              := 16);
   port (
      clk   : in  sl                      := '0';
      din   : in  slv(WIDTH_G-1 downto 0) := (others => '0');
      dout  : out slv(WIDTH_G-1 downto 0) := (others => '0');
      dly_2 : in  slv(3 downto 0)         := toSlv(DELAY_G-2, 4));  -- slv for DELAY-2, runtime optional
end entity Srl16Delay;

architecture mapping of Srl16Delay is

begin

   assert (false)
      report "surf.xilinx: Srl16Delay not supported" severity failure;

end mapping;
