-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Testbench for design "SspDecoder8b10b"
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

----------------------------------------------------------------------------------------------------

entity SspDecoder8b10bTb is

end entity SspDecoder8b10bTb;

----------------------------------------------------------------------------------------------------

architecture sim of SspDecoder8b10bTb is

   -- component generics
   constant TPD_G          : time    := 1 ns;
   constant RST_POLARITY_G : sl      := '1';
   constant RST_ASYNC_G    : boolean := true;

   -- component ports
   signal clkDiv2  : sl               := '0';
   signal clk      : sl               := '0';
   signal rst      : sl               := RST_POLARITY_G;
   signal dataIn   : slv(19 downto 0) := (others => '0');
   signal validIn  : sl;
   signal dataOut  : slv(15 downto 0);
   signal validOut : sl;
   signal sof      : sl;
   signal eof      : sl;
   signal eofe     : sl;

   signal dataInEnc    : slv(15 downto 0);
   signal dataValidEnc : sl;
   signal dataOutEnc   : slv(19 downto 0);

begin

   -- component instantiation

   -- encoded data gen
   Stimuli : entity surf.SspEncoder8b10b
      generic map (
         RST_POLARITY_G => '1'
         )
      port map (
         clk     => clkDiv2,
         rst     => rst,
         valid   => dataValidEnc,
         dataIn  => dataInEnc,
         dataOut => dataOutEnc
         );

   -- async fifo for validIn simulation
   Fifo : entity surf.FifoCascade
      generic map (
         GEN_SYNC_FIFO_G => false,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => 20
         )
      port map (
         -- Resets
         rst    => rst,
         wr_clk => clkDiv2,
         wr_en  => '1',
         din    => dataOutEnc,
         --Read Ports (rd_clk domain)
         rd_clk => clk,
         rd_en  => validIn,
         dout   => dataIn,
         valid  => validIn
         );

   -- unit under test
   UUT : entity surf.SspDecoder8b10b
      generic map (
         RST_POLARITY_G => '1'
         )
      port map (
         clk      => clk,
         rst      => rst,
         dataIn   => dataIn,
         validIn  => validIn,
         dataOut  => dataOut,
         validOut => validOut,
         sof      => sof,
         eof      => eof,
         eofe     => eofe
         );

   -- clock generation
   clk     <= not clk     after 10 ns;
   clkDiv2 <= not clkDiv2 after 20 ns;

   -- waveform generation
   WaveGen_Proc : process
   begin

      dataValidEnc <= '0';
      dataInEnc    <= x"0000";

      -- insert signal assignments here
      wait until clkDiv2 = '1';
      wait until clkDiv2 = '1';
      wait until clkDiv2 = '1';
      wait until clkDiv2 = '1';

      rst <= not RST_POLARITY_G;

      wait until clkDiv2 = '1';
      wait until clkDiv2 = '1';
      wait until clkDiv2 = '1';
      wait until clkDiv2 = '1';
      wait until clkDiv2 = '1';
      wait until clkDiv2 = '1';
      wait until clkDiv2 = '1';
      wait until clkDiv2 = '1';
      wait until clkDiv2 = '1';
      wait until clkDiv2 = '1';
      wait until clkDiv2 = '1';
      wait until clkDiv2 = '1';
      wait until clkDiv2 = '1';
      wait until clkDiv2 = '1';


      wait until clkDiv2 = '1';
      dataValidEnc <= '1';
      dataInEnc    <= x"0001";

      wait until clkDiv2 = '1';
      dataValidEnc <= '1';
      dataInEnc    <= x"0002";

      wait until clkDiv2 = '1';
      dataValidEnc <= '1';
      dataInEnc    <= x"0003";

      wait until clkDiv2 = '1';
      dataValidEnc <= '1';
      dataInEnc    <= x"0004";

      wait until clkDiv2 = '1';
      dataValidEnc <= '1';
      dataInEnc    <= x"0005";

      wait until clkDiv2 = '1';
      dataValidEnc <= '1';
      dataInEnc    <= x"0006";

      wait until clkDiv2 = '1';
      dataValidEnc <= '1';
      dataInEnc    <= x"0007";

      wait until clkDiv2 = '1';
      dataValidEnc <= '1';
      dataInEnc    <= x"0008";

      wait until clkDiv2 = '1';
      dataValidEnc <= '0';

      wait;
   end process WaveGen_Proc;



end architecture sim;

