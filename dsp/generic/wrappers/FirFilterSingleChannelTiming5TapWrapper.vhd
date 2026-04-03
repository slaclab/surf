-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for a 5-tap single-channel FIR timing
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

entity FirFilterSingleChannelTiming5TapWrapper is
   port (
      clk     : in  sl;
      rst     : in  sl;
      ibValid : in  sl;
      ibReady : out sl;
      din     : in  slv(7 downto 0);
      sbIn    : in  slv(3 downto 0);
      obValid : out sl;
      obReady : in  sl;
      dout    : out slv(7 downto 0);
      sbOut   : out slv(3 downto 0));
end entity FirFilterSingleChannelTiming5TapWrapper;

architecture rtl of FirFilterSingleChannelTiming5TapWrapper is

   constant COEFFICIENTS_C : IntegerArray(0 to 4) := (
      0 => 0,
      1 => 0,
      2 => 8,
      3 => 0,
      4 => 0);

begin

   U_DUT : entity surf.FirFilterSingleChannel
      generic map (
         COMMON_CLK_G      => true,
         NUM_TAPS_G        => 5,
         SIDEBAND_WIDTH_G  => 4,
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
