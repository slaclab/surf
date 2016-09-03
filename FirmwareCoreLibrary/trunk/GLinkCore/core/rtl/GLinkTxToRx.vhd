-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : GLinkTxToRx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-20
-- Last update: 2014-05-20
-- Platform   : Vivado 2014.1
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'SLAC G-Link Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC G-Link Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.GlinkPkg.all;

entity GLinkTxToRx is
   generic (
      TPD_G          : time    := 1 ns;
      RST_ASYNC_G    : boolean := false;
      RST_POLARITY_G : sl      := '1';  -- '1' for active HIGH reset, '0' for active LOW reset      
      FLAGSEL_G      : boolean := false);
   port (
      -- TX Signals
      txReady       : in  sl;
      gLinkTx       : in  GLinkTxType;
      -- RX Signals 
      rxReady       : in  sl;
      gLinkRx       : out GLinkRxType;
      decoderError  : out sl;
      decoderErrorL : out sl;
      -- Global Signals
      en            : in  sl := '1';
      clk           : in  sl;
      rst           : in  sl);
end GLinkTxToRx;

architecture mapping of GLinkTxToRx is
   
   signal encodedData : slv(19 downto 0);
   
begin
   
   GLinkEncoder_Inst : entity work.GLinkEncoder
      generic map(
         TPD_G          => TPD_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         RST_POLARITY_G => RST_POLARITY_G,
         FLAGSEL_G      => FLAGSEL_G)   
      port map (
         en          => en,
         clk         => clk,
         rst         => rst,
         gLinkTx     => gLinkTx,
         encodedData => encodedData); 

   GLinkDecoder_Inst : entity work.GLinkDecoder
      generic map(
         TPD_G          => TPD_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         RST_POLARITY_G => RST_POLARITY_G,
         FLAGSEL_G      => FLAGSEL_G)   
      port map (
         en            => en,
         clk           => clk,
         rst           => rst,
         gtRxData      => encodedData,
         rxReady       => rxReady,
         txReady       => txReady,
         gLinkRx       => gLinkRx,
         decoderError  => decoderError,
         decoderErrorL => decoderErrorL);         

end mapping;
