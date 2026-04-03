-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for a 101-tap single-channel FIR using
--              the legacy 1 MHz low-pass coefficient set at 100 MHz sample
--              rate.
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

entity FirFilterSingleChannelLowPass101TapWrapper is
   port (
      clk     : in  sl;
      rst     : in  sl;
      ibValid : in  sl;
      ibReady : out sl;
      din     : in  slv(11 downto 0);
      obValid : out sl;
      obReady : in  sl;
      dout    : out slv(11 downto 0));
end entity FirFilterSingleChannelLowPass101TapWrapper;

architecture rtl of FirFilterSingleChannelLowPass101TapWrapper is

   constant COEFFICIENTS_C : IntegerArray(0 to 100) := (
      0   => 0,
      1   => 0,
      2   => 0,
      3   => 0,
      4   => 0,
      5   => 0,
      6   => 0,
      7   => 0,
      8   => 1,
      9   => 1,
      10  => 2,
      11  => 2,
      12  => 3,
      13  => 4,
      14  => 6,
      15  => 7,
      16  => 9,
      17  => 11,
      18  => 12,
      19  => 15,
      20  => 17,
      21  => 20,
      22  => 22,
      23  => 25,
      24  => 28,
      25  => 31,
      26  => 35,
      27  => 38,
      28  => 42,
      29  => 46,
      30  => 49,
      31  => 53,
      32  => 57,
      33  => 61,
      34  => 64,
      35  => 68,
      36  => 72,
      37  => 75,
      38  => 78,
      39  => 82,
      40  => 85,
      41  => 87,
      42  => 90,
      43  => 92,
      44  => 94,
      45  => 96,
      46  => 97,
      47  => 99,
      48  => 99,
      49  => 100,
      50  => 100,
      51  => 100,
      52  => 99,
      53  => 99,
      54  => 97,
      55  => 96,
      56  => 94,
      57  => 92,
      58  => 90,
      59  => 87,
      60  => 85,
      61  => 82,
      62  => 78,
      63  => 75,
      64  => 72,
      65  => 68,
      66  => 64,
      67  => 61,
      68  => 57,
      69  => 53,
      70  => 49,
      71  => 46,
      72  => 42,
      73  => 38,
      74  => 35,
      75  => 31,
      76  => 28,
      77  => 25,
      78  => 22,
      79  => 20,
      80  => 17,
      81  => 15,
      82  => 12,
      83  => 11,
      84  => 9,
      85  => 7,
      86  => 6,
      87  => 4,
      88  => 3,
      89  => 2,
      90  => 2,
      91  => 1,
      92  => 1,
      93  => 0,
      94  => 0,
      95  => 0,
      96  => 0,
      97  => 0,
      98  => 0,
      99  => 0,
      100 => 0);

begin

   U_DUT : entity surf.FirFilterSingleChannel
      generic map (
         COMMON_CLK_G      => true,
         NUM_TAPS_G        => 101,
         SIDEBAND_WIDTH_G  => 1,
         IBREADY_DEFAULT_G => '1',
         DATA_WIDTH_G      => 12,
         COEFF_WIDTH_G     => 12,
         COEFFICIENTS_G    => COEFFICIENTS_C)
      port map (
         clk             => clk,
         rst             => rst,
         ibValid         => ibValid,
         ibReady         => ibReady,
         din             => din,
         sbIn            => "0",
         obValid         => obValid,
         obReady         => obReady,
         dout            => dout,
         sbOut           => open,
         axilClk         => clk,
         axilRst         => rst,
         axilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
         axilReadSlave   => open,
         axilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
         axilWriteSlave  => open);

end architecture rtl;
