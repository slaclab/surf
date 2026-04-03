-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for a 31-tap single-channel FIR timing
--              characterization with an exact delayed-negate center tap.
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
use surf.AxiLitePkg.all;

entity FirFilterSingleChannelTiming31TapWrapper is
   port (
      clk     : in  sl;
      rst     : in  sl;
      ibValid : in  sl;
      ibReady : out sl;
      din     : in  slv(7 downto 0);
      sbIn    : in  slv(5 downto 0);
      obValid : out sl;
      obReady : in  sl;
      dout    : out slv(7 downto 0);
      sbOut   : out slv(5 downto 0));
end entity FirFilterSingleChannelTiming31TapWrapper;

architecture rtl of FirFilterSingleChannelTiming31TapWrapper is

   constant COEFFICIENTS_C : IntegerArray(0 to 30) := (
      0  => 0,
      1  => 0,
      2  => 0,
      3  => 0,
      4  => 0,
      5  => 0,
      6  => 0,
      7  => 0,
      8  => 0,
      9  => 0,
      10 => 0,
      11 => 0,
      12 => 0,
      13 => 0,
      14 => 0,
      15 => 8,
      16 => 0,
      17 => 0,
      18 => 0,
      19 => 0,
      20 => 0,
      21 => 0,
      22 => 0,
      23 => 0,
      24 => 0,
      25 => 0,
      26 => 0,
      27 => 0,
      28 => 0,
      29 => 0,
      30 => 0);

begin

   U_DUT : entity surf.FirFilterSingleChannel
      generic map (
         COMMON_CLK_G      => true,
         NUM_TAPS_G        => 31,
         SIDEBAND_WIDTH_G  => 6,
         IBREADY_DEFAULT_G => '1',
         DATA_WIDTH_G      => 8,
         COEFF_WIDTH_G     => 5,
         COEFFICIENTS_G    => COEFFICIENTS_C)
      port map (
         clk             => clk,
         rst             => rst,
         ibValid         => ibValid,
         ibReady         => ibReady,
         din             => din,
         sbIn            => sbIn,
         obValid         => obValid,
         obReady         => obReady,
         dout            => dout,
         sbOut           => sbOut,
         axilClk         => clk,
         axilRst         => rst,
         axilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
         axilReadSlave   => open,
         axilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
         axilWriteSlave  => open);

end architecture rtl;
