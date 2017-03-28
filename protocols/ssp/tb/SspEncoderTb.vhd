-------------------------------------------------------------------------------
-- File       : SspEncoderTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-08-27
-- Last update: 2016-09-06
-------------------------------------------------------------------------------
-- Description: Testbench for design "SspEncoder"
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

use work.StdRtlPkg.all;

----------------------------------------------------------------------------------------------------

entity SspEncoderTb is

end entity SspEncoderTb;

----------------------------------------------------------------------------------------------------

architecture sim of SspEncoderTb is

   -- component generics
   constant TPD_G          : time    := 1 ns;
   constant RST_POLARITY_G : sl      := '0';
   constant RST_ASYNC_G    : boolean := true;

   -- component ports
   signal clk      : sl               := '0';
   signal rst      : sl               := RST_POLARITY_G;
   signal validIn  : sl               := '0';
   signal dataIn   : slv(15 downto 0) := (others => '0');
   signal encData  : slv(19 downto 0);
   signal dataOut  : slv(15 downto 0);
   signal validOut : sl;
   signal sof      : sl;
   signal eof      : sl;
   signal eofe     : sl;


begin

   -- component instantiation
   Encoder : entity work.SspEncoder
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk     => clk,
         rst     => rst,
         valid   => validIn,
         dataIn  => dataIn,
         dataOut => encData);

   Decoder : entity work.SspDecoder
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk     => clk,
         rst     => rst,
         dataIn  => encData,
         dataOut => dataOut,
         valid   => validOut,
         sof     => sof,
         eof     => eof,
         eofe    => eofe);

   -- clock generation
   clk <= not clk after 10 ns;

   -- waveform generation
   WaveGen_Proc : process
   begin
      -- insert signal assignments here
      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';

      rst <= '1';
      
      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';

      wait for TPD_G;
      validIn <= '1';
      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';
      wait for TPD_G;
      validIn <= '0';

      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';
   end process WaveGen_Proc;

   

end architecture sim;

