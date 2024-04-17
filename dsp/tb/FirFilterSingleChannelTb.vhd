-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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
use ieee.numeric_std.all;
use ieee.math_real.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity FirFilterSingleChannelTb is end FirFilterSingleChannelTb;

architecture testbed of FirFilterSingleChannelTb is

   constant TPD_G : time := 1 ns;

   constant WIDTH_C    : positive := 12;
   constant TAP_SIZE_C : positive := 101;

   ---------------------------------------------------------------
   -- Python Code to generate FIR taps for 1 MHz low pass filter
   ---------------------------------------------------------------
   --    taps = scipy.signal.firwin(101, cutoff = 1.0e6/nyquist_freq, window = "hanning")
   --    for i in range(len(taps)):
   --       taps[i] = floor(taps[i]*4096);
   --       print( f'{i} => {int(taps[i])},' )
   ---------------------------------------------------------------
   constant COEFFICIENTS_C : IntegerArray(TAP_SIZE_C-1 downto 0) := (
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

   type RegType is record
      t   : real;
      din : slv(WIDTH_C-1 downto 0);
   end record RegType;
   constant REG_INIT_C : RegType := (
      t   => 0.0,
      din => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clk : sl := '0';
   signal rst : sl := '1';

   signal dout : slv(WIDTH_C-1 downto 0) := (others => '0');

begin

   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 10 ns,    -- 100 MHz
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1000 ns)
      port map (
         clkP => clk,
         rst  => rst);

   U_Fir : entity surf.FirFilterSingleChannel
      generic map (
         TPD_G          => TPD_G,
         TAP_SIZE_G     => TAP_SIZE_C,      -- Number of programmable taps
         WIDTH_G        => WIDTH_C,         -- Number of bits per data word
         COEFFICIENTS_G => COEFFICIENTS_C)  -- Tap Coefficients Init Constants
      port map (
         -- Clock and Reset
         clk             => clk,
         rst             => rst,
         -- Inbound Interface
         din             => r.din,
         -- Outbound Interface
         dout            => dout,
         -- AXI-Lite Interface (axilClk domain)
         axilClk         => clk,
         axilRst         => rst,
         axilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
         axilReadSlave   => open,
         axilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
         axilWriteSlave  => open);

   comb : process (r, rst) is
      variable v        : RegType;
      variable retValue : real;
   begin
      -- Latch the current value
      v := r;

      -- Init
      retValue := 0.0;

      -- 100 kHz Sine-wave (will NOT get filtered out)
      retValue := retValue + 1000.0*sin(2.0*MATH_PI*0.1E+6*r.t);

      -- 10 MHz Sine-wave (will get filtered out)
      retValue := retValue + 1000.0*sin(2.0*MATH_PI*10.0E+6*r.t);

      -- Assign to output
      v.din := std_logic_vector(to_signed(integer(retValue), WIDTH_C));

      -- Calculate next time sample
      v.t := r.t + 10.0E-9;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end testbed;
