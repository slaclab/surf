-------------------------------------------------------------------------------
-- File       : Ssp10b12bTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-10-26
-- Last update: 2016-10-26
-------------------------------------------------------------------------------
-- Description: Simulation testbed for Ssp10b12b
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.TextUtilPkg.all;
----------------------------------------------------------------------------------------------------

entity Ssp10b12bTb is

end entity Ssp10b12bTb;

----------------------------------------------------------------------------------------------------

architecture tb of Ssp10b12bTb is

   -- component generics
   constant TPD_G          : time    := 1 ns;
   constant RST_POLARITY_G : sl      := '0';
   constant RST_ASYNC_G    : boolean := true;
   constant AUTO_FRAME_G   : boolean := true;

   -- component ports
   signal clk     : sl;                    -- [in]
   signal rst     : sl := RST_POLARITY_G;  -- [in]

   signal encValid   : sl;                    -- [in]
   signal encSof     : sl := '0';             -- [in]
   signal encEof     : sl := '0';             -- [in]
   signal encDataIn  : slv(9 downto 0);       -- [in]
   signal encDataOut : slv(11 downto 0);      -- [out]

   signal decDataIn    : slv(11 downto 0);      -- [in]
   signal decDataOut   : slv(9 downto 0);       -- [out]
   signal decValid     : sl;                    -- [out]
   signal decSof       : sl;                    -- [out]
   signal decEof       : sl;                    -- [out]
   signal decEofe      : sl;                    -- [out]
   signal decCodeError : sl;                    -- [out]
   signal decDispError : sl;                    -- [out]

begin

   -- component instantiation
   U_SspEncoder10b12b: entity work.SspEncoder10b12b
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         AUTO_FRAME_G   => AUTO_FRAME_G)
      port map (
         clk     => clk,                -- [in]
         rst     => rst,                -- [in]
         valid   => encValid,              -- [in]
         sof     => encSof,                -- [in]
         eof     => encEof,                -- [in]
         dataIn  => encDataIn,             -- [in]
         dataOut => encDataOut);           -- [out]

   decDataIn <= encDataOut;
   U_SspDecoder10b12b_1: entity work.SspDecoder10b12b
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G)
      port map (
         clk       => clk,              -- [in]
         rst       => rst,              -- [in]
         dataIn    => decDataIn,           -- [in]
         dataOut   => decDataOut,          -- [out]
         valid     => decValid,            -- [out]
         sof       => decSof,              -- [out]
         eof       => decEof,              -- [out]
         eofe      => decEofe,             -- [out]
         codeError => decCodeError,        -- [out]
         dispError => decDispError);       -- [out]

   
   U_ClkRst_1 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 4 ns,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => false)
      port map (
         clkP => clk,
         rstL  => rst);

   gen: process is
   begin
      wait until clk = '1';
      wait until rst = '1';
      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';
      wait until clk = '1';

      for i in 0 to 2**10-1 loop
         wait until clk = '1';
         encValid <= '1' after TPD_G;
         encDataIn <= conv_std_logic_vector(i, 10) after TPD_G;
         wait until clk = '1';         
      end loop;

      wait until clk = '1';
      encValid <= '0' after TPD_G;
   end process gen;

   check: process is
   begin

      wait until decValid = '1';

      for i in 0 to 2**10-1 loop
         wait until clk = '1';         
         assert (decSof = '1' or i /= 0) report "No SOF" severity failure;
         assert (decDataOut = conv_std_logic_vector(i, 10)) report "Bad decode" severity failure;
         print("Expected " & str(conv_std_logic_vector(i, 10)) & " got " & str(decDataOut));
         wait until clk = '1';         
         assert (decDataOut = conv_std_logic_vector(i, 10)) report "Bad decode" severity failure;
         assert (decEof = '1' or i /= (2**10-1)) report "No EOF" severity failure;
         print("Expected " & str(conv_std_logic_vector(i, 10)) & " got " & str(decDataOut));         
      end loop;      
   end process check;
   

end architecture tb;

----------------------------------------------------------------------------------------------------
