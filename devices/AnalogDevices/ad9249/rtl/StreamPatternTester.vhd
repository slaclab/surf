-------------------------------------------------------------------------------
-- File       : StreamPatternTester.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 05/27/2016
-- Last update: 05/27/2016
-------------------------------------------------------------------------------
-- Description:   Test which compares the data stream to selected pattern
--                Designed for the automated delay alignment of the fast LVDS lines  
--                of ADCs with single or multiple serial data lanes
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

entity StreamPatternTester is 
   generic (
      TPD_G             : time := 1 ns;
      NUM_CHANNELS_G    : integer range 1 to 31 := 8
   );
   port ( 
      -- Master system clock
      clk               : in  std_logic;
      rst               : in  std_logic;
      
      -- ADC data stream inputs
      adcStreams        : in  AxiStreamMasterArray(NUM_CHANNELS_G-1 downto 0);
      
      -- Axi Interface
      axilWriteMaster   : in  AxiLiteWriteMasterType;
      axilWriteSlave    : out AxiLiteWriteSlaveType;
      axilReadMaster    : in  AxiLiteReadMasterType;
      axilReadSlave     : out AxiLiteReadSlaveType
   );
end StreamPatternTester;


-- Define architecture
architecture RTL of StreamPatternTester is

   -------------------------------------------------------------------------------------------------
   -- AXIL Registers
   -------------------------------------------------------------------------------------------------
   type AxilRegType is record
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
      testChannel    : slv(31 downto 0);
      testPattern    : slv(31 downto 0);
      testDataMask   : slv(31 downto 0);
      testSamples    : slv(31 downto 0);
      testTimeout    : slv(31 downto 0);
      testRequest    : sl;
   end record;

   constant AXIL_REG_INIT_C : AxilRegType := (
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      testChannel    => (others=>'0'),
      testPattern    => (others=>'0'),
      testDataMask   => (others=>'0'),
      testSamples    => (others=>'0'),
      testTimeout    => (others=>'0'),
      testRequest    => '0'
   );

   signal axilR   : AxilRegType := AXIL_REG_INIT_C;
   signal axilRin : AxilRegType;
   
   signal dataMux       : std_logic_vector(31 downto 0);
   signal dataValidMux  : std_logic;
   signal testCnt       : unsigned(31 downto 0);
   signal testDone      : std_logic;
   signal testPassed    : std_logic;
   signal testFailed    : std_logic;
   signal passCnt       : unsigned(31 downto 0);
   signal timeoutCnt    : unsigned(31 downto 0);
   
begin

   -------------------------------------------------------------------------------------------------
   -- AXIL Interface
   -------------------------------------------------------------------------------------------------
   axilComb : process (axilR, axilReadMaster, rst, axilWriteMaster, testPassed, testFailed) is
      variable v      : AxilRegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      v := axilR;

      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      axiSlaveRegister (axilEp, X"00" & "00", 0, v.testChannel);
      axiSlaveRegister (axilEp, X"01" & "00", 0, v.testDataMask);
      axiSlaveRegister (axilEp, X"02" & "00", 0, v.testPattern);
      axiSlaveRegister (axilEp, X"03" & "00", 0, v.testSamples);
      axiSlaveRegister (axilEp, X"04" & "00", 0, v.testTimeout);
      axiSlaveRegister (axilEp, X"05" & "00", 0, v.testRequest);
      axiSlaveRegisterR(axilEp, X"06" & "00", 0, testPassed);
      axiSlaveRegisterR(axilEp, X"07" & "00", 0, testFailed);

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      if (rst = '1') then
         v := AXIL_REG_INIT_C;
      end if;

      axilRin        <= v;
      axilWriteSlave <= axilR.axilWriteSlave;
      axilReadSlave  <= axilR.axilReadSlave;

   end process;

   axilSeq : process (clk) is
   begin
      if (rising_edge(clk)) then
         axilR <= axilRin after TPD_G;
      end if;
   end process axilSeq;
   
   -------------------------------------------------------------------------------------------------
   -- Tester logic
   -------------------------------------------------------------------------------------------------
   
   dataValidMux <= adcStreams(to_integer(unsigned(axilR.testChannel))).tValid;
   
   maskGen: for i in 0 to 31 generate
      dataMux(i) <= adcStreams(to_integer(unsigned(axilR.testChannel))).tData(i) and axilR.testDataMask(i);
   end generate maskGen;
   
   
   
   testProc: process ( clk ) 
   begin
      
      -- test samples counter
      if rising_edge(clk) then
         if rst = '1' or axilR.testRequest = '1' then
            testCnt <= (others=>'0')      after TPD_G;
         elsif dataValidMux = '1' and testDone = '0' then
            testCnt <= testCnt + 1        after TPD_G;
         end if;
      end if;
      
      -- comparison passed counter
      if rising_edge(clk) then
         if rst = '1' or axilR.testRequest = '1' then
            passCnt <= (others=>'0')      after TPD_G;
         elsif dataMux = axilR.testPattern and dataValidMux = '1' and testDone = '0' then
            passCnt <= passCnt + 1        after TPD_G;
         end if;
      end if;
      
      -- timeout counter
      if rising_edge(clk) then
         if rst = '1' or axilR.testRequest = '1' or dataValidMux = '1' then
            timeoutCnt <= unsigned(axilR.testTimeout) after TPD_G;
         elsif timeoutCnt > 0 then
            timeoutCnt <= timeoutCnt - 1        after TPD_G;
         end if;
      end if;
      
   end process;
   
   testDone <= '1' when (testCnt >= unsigned(axilR.testSamples) or timeoutCnt = 0) and axilR.testRequest = '0' else '0';
   testPassed <= '1' when testDone = '1' and passCnt = unsigned(axilR.testSamples) else '0';
   testFailed <= '1' when testDone = '1' and passCnt < unsigned(axilR.testSamples) else '0';

end RTL;

