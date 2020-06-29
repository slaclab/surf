-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the AxiLiteIpBusBridgeTb module
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

library ruckus;
use ruckus.BuildInfoPkg.all;

entity AxiLiteIpBusBridgeTb is end AxiLiteIpBusBridgeTb;

architecture testbed of AxiLiteIpBusBridgeTb is

   constant GET_BUILD_INFO_C : BuildInfoRetType := toBuildInfo(BUILD_INFO_C);
   constant MOD_BUILD_INFO_C : BuildInfoRetType := (
      buildString => GET_BUILD_INFO_C.buildString,
      fwVersion   => GET_BUILD_INFO_C.fwVersion,
      gitHash     => x"1111_2222_3333_4444_5555_6666_7777_8888_9999_AAAA");  -- create a fake githash
   constant SIM_BUILD_INFO_C : slv(2239 downto 0) := toSlv(MOD_BUILD_INFO_C);

   constant CLK_PERIOD_G : time := 10 ns;
   constant TPD_G        : time := CLK_PERIOD_G/4;

   signal axilClk : sl := '0';
   signal axilRst : sl := '0';

   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;

   signal ipbRdata  : slv(31 downto 0) := (others => '0');
   signal ipbAck    : sl               := '0';
   signal ipbErr    : sl               := '0';
   signal ipbAddr   : slv(31 downto 0) := (others => '0');
   signal ipbWdata  : slv(31 downto 0) := (others => '0');
   signal ipbStrobe : sl               := '0';
   signal ipbWrite  : sl               := '0';

   signal regWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal regWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal regReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal regReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;

begin

   --------------------
   -- Clocks and Resets
   --------------------
   U_axilClk : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_G,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1000 ns)
      port map (
         clkP => axilClk,
         rst  => axilRst);

   --------------------------------------------
   -- Simulation AXI-Lite Register Transactions
   --------------------------------------------
   test : process is
      variable debugData : slv(31 downto 0) := (others => '0');
   begin
      debugData := x"1111_1111";
      ------------------------------------------
      -- Wait for the AXI-Lite reset to complete
      ------------------------------------------
      wait until axilRst = '1';
      wait until axilRst = '0';

      -- Read the GIT hash
      axiLiteBusSimRead (axilClk, axilReadMaster, axilReadSlave, x"0000_0600", debugData, true);
      axiLiteBusSimRead (axilClk, axilReadMaster, axilReadSlave, x"0000_0604", debugData, true);
      axiLiteBusSimRead (axilClk, axilReadMaster, axilReadSlave, x"0000_0608", debugData, true);
      axiLiteBusSimRead (axilClk, axilReadMaster, axilReadSlave, x"0000_060C", debugData, true);
      axiLiteBusSimRead (axilClk, axilReadMaster, axilReadSlave, x"0000_0610", debugData, true);

      -- Write to the scratch pad
      axiLiteBusSimWrite (axilClk, axilWriteMaster, axilWriteSlave, x"0000_0004", x"1234_5678", true);

      -- Write to a read-only register to test error bus response path
      axiLiteBusSimWrite (axilClk, axilWriteMaster, axilWriteSlave, x"0000_0000", x"1234_5678", true);

      ---------------------------------------------------------------------------------
      -- Here's the expected output:
      ---------------------------------------------------------------------------------
      -- AxiLitePkg::axiLiteBusSimRead( addr:00000600, data: 9999AAAA)
      -- AxiLitePkg::axiLiteBusSimRead( addr:00000604, data: 77778888)
      -- AxiLitePkg::axiLiteBusSimRead( addr:00000608, data: 55556666)
      -- AxiLitePkg::axiLiteBusSimRead( addr:0000060C, data: 33334444)
      -- AxiLitePkg::axiLiteBusSimRead( addr:00000610, data: 11112222)
      -- AxiLitePkg::axiLiteBusSimWrite(addr:00000004, data: 12345678)
      -- AxiLitePkg::axiLiteBusSimWrite(addr:00000000, data: 12345678)
      -- Warning: AxiLitePkg::axiLiteBusSimWrite( addr:00000000): - BRESP = SLAVE_ERROR
      ---------------------------------------------------------------------------------

   end process test;

   ----------------------------
   -- Axi-Lite to IP bus Bridge
   ----------------------------
   U_AxiLiteToIpBus : entity surf.AxiLiteToIpBus
      generic map (
         TPD_G        => TPD_G)
      port map (
         -- Clock and Reset
         clk             => axilClk,
         rst             => axilRst,
         -- AXI-Lite Slave Interface
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         -- IP Bus Master Interface
         ipbRdata        => ipbRdata,
         ipbAck          => ipbAck,
         ipbErr          => ipbErr,
         ipbAddr         => ipbAddr,
         ipbWdata        => ipbWdata,
         ipbStrobe       => ipbStrobe,
         ipbWrite        => ipbWrite);

   ----------------------------
   -- IP Bus to Axi-Lite Bridge
   ----------------------------
   U_IpBusToAxiLite : entity surf.IpBusToAxiLite
      generic map (
         TPD_G        => TPD_G)
      port map (
         -- Clock and Reset
         clk             => axilClk,
         rst             => axilRst,
         -- IP Bus Slave Interface
         ipbAddr         => ipbAddr,
         ipbWdata        => ipbWdata,
         ipbStrobe       => ipbStrobe,
         ipbWrite        => ipbWrite,
         ipbRdata        => ipbRdata,
         ipbAck          => ipbAck,
         ipbErr          => ipbErr,
         -- AXI-Lite Master Interface
         axilReadMaster  => regReadMaster,
         axilReadSlave   => regReadSlave,
         axilWriteMaster => regWriteMaster,
         axilWriteSlave  => regWriteSlave);

   --------------------------
   -- Example Register Module
   --------------------------
   U_Version : entity surf.AxiVersion
      generic map (
         TPD_G        => TPD_G,
         BUILD_INFO_G => SIM_BUILD_INFO_C)
      port map (
         -- AXI-Lite Interface
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => regReadMaster,
         axiReadSlave   => regReadSlave,
         axiWriteMaster => regWriteMaster,
         axiWriteSlave  => regWriteSlave);

end testbed;
