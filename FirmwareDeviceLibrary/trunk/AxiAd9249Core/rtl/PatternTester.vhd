-------------------------------------------------------------------------------
-- Title         : PatternTester
-- Project       : IPM Detector
-------------------------------------------------------------------------------
-- File       : PatternTester.vhd
-- Author     : Maciej Kwiatkowski, mkwiatko@slac.stanford.edu
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 05/27/2016
-- Last update: 05/27/2016
-- Platform   : Vivado 2015.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   Test which compares the data stream to selected pattern
--                Designed for the AD9653 or similar ADC with multiple serial data lanes
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Modification history:
-- 05/27/2016: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;

entity PatternTester is 
   generic (
      TPD_G       : time := 1 ns;
      CH_NUM_G    : integer range 1 to 31 := 8;
      CH_BITS_G   : integer range 1 to 31 := 8
   );
   port ( 
      -- Master system clock
      clk         : in  std_logic;
      rst         : in  std_logic;
      
      -- data input
      data        : in Slv8Array(CH_NUM_G-1 downto 0);
      dataValid   : in std_logic_vector(CH_NUM_G-1 downto 0);
      
      -- Test control and status
      testChannel : in  std_logic_vector(31 downto 0);            -- select lane to test
      testPattern : in  std_logic_vector(CH_BITS_G-1 downto 0);   -- select pattern to compare to
      testSamples : in  std_logic_vector(31 downto 0);            -- set number of samples to test
      testTimeout : in  std_logic_vector(31 downto 0);            -- set timeout if for any reason samples are not coming
      testRequest : in  std_logic;                                -- start test on falling edge
      testPassed  : out std_logic;                                -- set to '1' when test is finished and it passed
      testFailed  : out std_logic                                 -- set to '1' when test is finished and it failed
   );
end PatternTester;


-- Define architecture
architecture RTL of PatternTester is
   
   signal testCnt       : unsigned(31 downto 0);
   signal testDone      : std_logic;
   signal passCnt       : unsigned(31 downto 0);
   signal timeoutCnt    : unsigned(31 downto 0);
   
begin
   
   patTest_p: process ( clk ) 
   begin
      
      -- test samples counter
      if rising_edge(clk) then
         if rst = '1' or testRequest = '1' then
            testCnt <= (others=>'0')      after TPD_G;
         elsif dataValid(to_integer(unsigned(testChannel))) = '1' and testDone = '0' then
            testCnt <= testCnt + 1        after TPD_G;
         end if;
      end if;
      
      -- comparison passed counter
      if rising_edge(clk) then
         if rst = '1' or testRequest = '1' then
            passCnt <= (others=>'0')      after TPD_G;
         elsif data(to_integer(unsigned(testChannel)))(CH_BITS_G-1 downto 0) = testPattern and dataValid(to_integer(unsigned(testChannel))) = '1' and testDone = '0' then
            passCnt <= passCnt + 1        after TPD_G;
         end if;
      end if;
      
      -- timeout counter
      if rising_edge(clk) then
         if rst = '1' or testRequest = '1' or dataValid(to_integer(unsigned(testChannel))) = '1' then
            timeoutCnt <= unsigned(testTimeout) after TPD_G;
         elsif timeoutCnt > 0 then
            timeoutCnt <= timeoutCnt - 1        after TPD_G;
         end if;
      end if;
      
   end process;
   
   testDone <= '1' when (testCnt >= unsigned(testSamples) or timeoutCnt = 0) and testRequest = '0' else '0';
   testPassed <= '1' when testDone = '1' and passCnt = unsigned(testSamples) else '0';
   testFailed <= '1' when testDone = '1' and passCnt < unsigned(testSamples) else '0';

end RTL;

