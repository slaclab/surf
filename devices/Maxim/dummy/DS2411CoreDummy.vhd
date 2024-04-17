-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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

library surf;
use surf.StdRtlPkg.all;

entity DS2411Core is
   generic (
      TPD_G        : time             := 1 ns;
      SIMULATION_G : boolean          := false;
      SIM_OUTPUT_G : slv(63 downto 0) := x"0123456789ABCDEF";
      CLK_PERIOD_G : real             := 6.4E-9;    --units of seconds
      SMPL_TIME_G  : real             := 13.1E-6);  --move sample time
   port (
      -- Clock & Reset Signals
      clk       : in    sl               := '0';
      rst       : in    sl               := '0';
      -- ID Prom Signals
      fdSerSdio : inout sl;
      -- output hookup of the fdSerSdio (optional)
      fdSerDin  : out   sl               := '0';
      -- Serial Number
      fdValue   : out   slv(63 downto 0) := (others => '0');
      fdValid   : out   sl               := '0');
end DS2411Core;

architecture mapping of DS2411Core is

begin

   assert (false)
      report "surf.device: DS2411Core not supported" severity failure;

end mapping;
