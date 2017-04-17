-------------------------------------------------------------------------------
-- File       : SspEncoder8b10b.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-07-14
-- Last update: 2016-10-24
-------------------------------------------------------------------------------
-- Description: SimpleStreamingProtocol - A simple protocol layer for inserting
-- idle and framing control characters into a raw data stream. This module
-- ties the framing core to an RTL 8b10b encoder.
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
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.STD_LOGIC_ARITH.all;

use work.StdRtlPkg.all;
use work.Code8b10bPkg.all;

entity SspEncoder8b10b is

   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '0';
      RST_ASYNC_G    : boolean := true;
      AUTO_FRAME_G   : boolean := true);
   port (
      clk     : in  sl;
      rst     : in  sl := RST_POLARITY_G;
      valid   : in  sl;
      sof     : in  sl := '0';
      eof     : in  sl := '0';
      dataIn  : in  slv(15 downto 0);
      dataOut : out slv(19 downto 0));

end entity SspEncoder8b10b;

architecture rtl of SspEncoder8b10b is

   signal framedData  : slv(15 downto 0);
   signal framedDataK : slv(1 downto 0);

begin

   SspFramer_1 : entity work.SspFramer
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         AUTO_FRAME_G    => AUTO_FRAME_G,
         WORD_SIZE_G     => 16,
         K_SIZE_G        => 2,
         SSP_IDLE_CODE_G => D_10_2_C & K_28_5_C,
         SSP_IDLE_K_G    => "01",
         SSP_SOF_CODE_G  => D_10_2_C & K_23_7_C,
         SSP_SOF_K_G     => "01",
         SSP_EOF_CODE_G  => D_10_2_C & K_29_7_C,
         SSP_EOF_K_G     => "01")
      port map (
         clk      => clk,
         rst      => rst,
         valid    => valid,
         sof      => sof,
         eof      => eof,
         dataIn   => dataIn,
         dataOut  => framedData,
         dataKOut => framedDataK);

   Encoder8b10b_1 : entity work.Encoder8b10b
      generic map (
         TPD_G          => TPD_G,
         NUM_BYTES_G    => 2,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk     => clk,
         clkEn   => '1',
         rst     => rst,
         dataIn  => framedData,
         dataKIn => framedDataK(0),
         dataOut => dataOut);

end architecture rtl;
