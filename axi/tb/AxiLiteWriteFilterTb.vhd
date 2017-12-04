-------------------------------------------------------------------------------
-- File       : AxiLiteWriteFilterTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
-- Last update: 2017-11-13
-------------------------------------------------------------------------------
-- Description: Testbench for design "AxiLiteAsync"
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
use work.TextUtilPkg.all;
use work.AxiLitePkg.all;

entity AxiLiteWriteFilterTb is
end entity AxiLiteWriteFilterTb;
architecture tb of AxiLiteWriteFilterTb is

   constant CLK_PERIOD_C : time := 10 ns;
   constant TPD_G        : time := (CLK_PERIOD_C/4);

   signal axilReadMaster    : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave     : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster   : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave    : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal filterWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal filterWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

   signal axilClk  : sl := '0';
   signal axilRst  : sl := '1';
   signal enFilter : sl := '1';
   signal blockAll : sl := '1';

begin

   U_axilClk : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => axilClk,
         clkN => open,
         rst  => axilRst,
         rstL => open);

   test : process is
      variable addr : slv(31 downto 0) := (others => '0');
      variable data : slv(31 downto 0) := (others => '0');
   begin
      enFilter <= '1';
      blockAll <= '1';
      wait until axilRst = '1';
      wait until axilRst = '0';

      wait for 1 us;
      wait until axilClk = '1';
      report "Should be two DECODE_ERROR";
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000FF0", x"11111111", true);      
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"000001A0", x"11111111", true);      
      report "###################################################################################";
      report "###################################################################################";
      report "###################################################################################";

      wait for 1 us;
      blockAll <= '0';
      wait for 1 us;
      wait until axilClk = '1';
      report "Should be one DECODE_ERROR";
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000FF0", x"FFFFFFFF", true);      
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"000001A0", x"11111111", true);   
      report "###################################################################################";
      report "###################################################################################";
      report "###################################################################################";     

      wait for 1 us;
      wait until axilClk = '1';
      report "Read back the data";
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, x"00000FF0", data, true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, x"000001A0", data, true);
      report "###################################################################################";
      report "###################################################################################";
      report "###################################################################################";      

      wait for 1 us;
      enFilter <= '0';
      wait for 1 us;
      wait until axilClk = '1';
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000FF0", x"FFFFFFFF", true);
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"000001A0", x"22222222", true);
      report "###################################################################################";
      report "###################################################################################";
      report "###################################################################################";
      
      wait for 1 us;
      wait until axilClk = '1';
      report "Read back the data";
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, x"00000FF0", data, true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, x"000001A0", data, true);
      report "###################################################################################";
      report "###################################################################################";
      report "###################################################################################";      

   end process test;

   U_Filter : entity work.AxiLiteWriteFilter
      generic map (
         TPD_G            => TPD_G,
         FILTER_SIZE_G    => 1,
         FILTER_ADDR_G    => (0 => x"000001A0"),
         AXI_ERROR_RESP_G => AXI_RESP_DECERR_C)
      port map (
         -- Clock and reset
         axilClk          => axilClk,
         axilRst          => axilRst,
         enFilter         => enFilter,
         blockAll         => blockAll,
         -- AXI-Lite Slave Interface
         sAxilWriteMaster => axilWriteMaster,
         sAxilWriteSlave  => axilWriteSlave,
         -- AXI-Lite Master Interface
         mAxilWriteMaster => filterWriteMaster,
         mAxilWriteSlave  => filterWriteSlave);

   U_Mem : entity work.AxiDualPortRam
      generic map (
         TPD_G            => TPD_G,
         BRAM_EN_G        => true,
         REG_EN_G         => true,
         AXI_WR_EN_G      => true,
         SYS_WR_EN_G      => false,
         COMMON_CLK_G     => false,
         ADDR_WIDTH_G     => 9,
         DATA_WIDTH_G     => 32,
         AXI_ERROR_RESP_G => AXI_RESP_DECERR_C)
      port map (
         -- AXI-Lite Interface
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => axilReadMaster,
         axiReadSlave   => axilReadSlave,
         axiWriteMaster => filterWriteMaster,
         axiWriteSlave  => filterWriteSlave);

end architecture tb;
