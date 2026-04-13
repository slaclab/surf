-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Generic cocotb-facing wrapper for single-channel FIR
--              configurations that do not need external AXI-Lite access.
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

entity FirFilterSingleChannelWrapper is
   generic (
      NUM_TAPS_G        : positive               := 3;
      SIDEBAND_WIDTH_G  : positive               := 1;
      DATA_WIDTH_G      : positive               := 8;
      COEFF_WIDTH_G     : positive range 1 to 32 := 4;
      COEFFICIENTS_G    : IntegerArray           := (0 => 0));
   port (
      clk     : in  sl;
      rst     : in  sl;
      ibValid : in  sl;
      ibReady : out sl;
      din     : in  slv(DATA_WIDTH_G-1 downto 0);
      sbIn    : in  slv(SIDEBAND_WIDTH_G-1 downto 0);
      obValid : out sl;
      obReady : in  sl;
      dout    : out slv(DATA_WIDTH_G-1 downto 0);
      sbOut   : out slv(SIDEBAND_WIDTH_G-1 downto 0));
end entity FirFilterSingleChannelWrapper;

architecture rtl of FirFilterSingleChannelWrapper is

begin

   U_DUT : entity surf.FirFilterSingleChannel
      generic map (
         COMMON_CLK_G      => true,
         NUM_TAPS_G        => NUM_TAPS_G,
         SIDEBAND_WIDTH_G  => SIDEBAND_WIDTH_G,
         IBREADY_DEFAULT_G => '1',
         DATA_WIDTH_G      => DATA_WIDTH_G,
         COEFF_WIDTH_G     => COEFF_WIDTH_G,
         COEFFICIENTS_G    => COEFFICIENTS_G)
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
