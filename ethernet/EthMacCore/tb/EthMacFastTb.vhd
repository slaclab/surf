-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the EthMac module fast RX input
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------
-- Usage:
--    Run for 10us, check rxMaster - all 3 packets have passed through
-- Purpose:
--    This TB checks the what happens when a packet arrives immediately
--    after the previous one. It generates 3 packets directly to the
--    RX XGMII interface. Delay between packets 1 and 2 is 3 clock cycles,
--    and 0 between packets 2 and 3. Simulation is successful if all 3 packets
--    are passed onto rxMaster stream.
--
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.EthMacPkg.all;

entity EthMacFastTb is
end EthMacFastTb;

architecture testbed of EthMacFastTb is

   constant CLK_PERIOD_C : time := 10 ns;
   constant TPD_G        : time := (CLK_PERIOD_C/4);

   signal clk      : sl := '0';
   signal rst      : sl := '1';
   signal phyReady : sl := '0';

   signal txMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal rxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal ethStatus : EthMacStatusType := ETH_MAC_STATUS_INIT_C;
   signal ethConfig : EthMacConfigType := ETH_MAC_CONFIG_INIT_C;

   signal phyRxD : slv(63 downto 0) := (others => '0');
   signal phyRxC : slv(7 downto 0)  := (others => '0');
   signal phyTxD : slv(63 downto 0) := (others => '0');
   signal phyTxC : slv(7 downto 0)  := (others => '0');

begin

   ClkRst_Inst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1000 ns)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => phyReady);

   --------------------
   -- Ethernet MAC core
   --------------------
   U_MAC : entity surf.EthMacTop
      generic map (
         TPD_G         => TPD_G,
         PAUSE_EN_G    => false,
         JUMBO_G       => true,
         PHY_TYPE_G    => "XGMII",
         PRIM_CONFIG_G => EMAC_AXIS_CONFIG_C)
      port map (
         -- DMA Interface
         primClk         => clk,
         primRst         => rst,
         ibMacPrimMaster => txMaster,
         ibMacPrimSlave  => txSlave,
         obMacPrimMaster => rxMaster,
         obMacPrimSlave  => rxSlave,
         -- Ethernet Interface
         ethClk    => clk,
         ethRst    => rst,
         ethConfig => ethConfig,
         phyReady  => phyReady,
         -- XGMII PHY Interface
         xgmiiRxd => phyRxD,
         xgmiiRxc => phyRxC,
         xgmiiTxd => phyTxD,
         xgmiiTxc => phyTxC);

   ethConfig.macAddress  <= x"010300564400";

   -- Only doing RAW Ethernet communication
   ethConfig.ipCsumEn  <= '1';
   ethConfig.tcpCsumEn <= '1';
   ethConfig.udpCsumEn <= '1';

   p_DataGen : process
   begin
      wait for CLK_PERIOD_C;
      wait until rst = '0';
      phyRxC <= x"ff";
      phyRxD <= x"0707_0707_0707_0707";
      wait for 289*CLK_PERIOD_C + TPD_G;

      -------------------------------------------------------------------------
      -- Packet #1
      -------------------------------------------------------------------------
      --phyRxC <= x"01";
      --phyRxD <= x"d555_5555_5555_55fb";
      --wait for CLK_PERIOD_C;
      --phyRxC <= x"00";
      --phyRxD <= x"aa55_aa55_aa55_aa55";
      --wait for 255*CLK_PERIOD_C;
      --phyRxC <= x"00";
      --phyRxD <= x"e747_aa55_aa55_aa55";
      --wait for CLK_PERIOD_C;
      --phyRxC <= x"fc";
      --phyRxD <= x"0707_0707_07fd_bfe5";
      --wait for CLK_PERIOD_C;

      phyRxC <= x"01";
      phyRxD <= x"d5555555555555fb";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"1de4010300564400";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"0045000801616d2d";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"1140004076241c04";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"a8c00102a8c0ff8c";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"08040020839b0a02";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"004b00000053f81a";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"aa55aa55aa550400";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"aa55_aa55_aa55_aa55";
      wait for 126*CLK_PERIOD_C;
      phyRxC <= x"c0";
      phyRxD <= x"07fd90a35716aa55";
      wait for CLK_PERIOD_C;

      -- Insert 3 idle cycles
      phyRxC <= x"ff";
      phyRxD <= x"0707_0707_0707_0707";
      wait for 20*CLK_PERIOD_C;

      -------------------------------------------------------------------------
      -- Packet #2
      -------------------------------------------------------------------------
      phyRxC <= x"1f";
      phyRxD <= x"555555fb07070707";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"00564400d5555555";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"01616d2d1de40103";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"77241c0400450008";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"a8c0fe8c11400040";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"839b0a02a8c00102";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"0053f81908040020";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"aa550400004c0000";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"aa55_aa55_aa55_aa55";
      wait for 126*CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"0623aa55aa55aa55";
      wait for CLK_PERIOD_C;
      phyRxC <= x"fc";
      phyRxD <= x"0707070707fd91da";
      wait for CLK_PERIOD_C;

      -------------------------------------------------------------------------
      -- Packet #3 - Immediately after previous
      -------------------------------------------------------------------------
      phyRxC <= x"01";
      phyRxD <= x"d5555555555555fb";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"1de4010300564400";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"0045000801616d2d";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"1140004078241c04";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"a8c00102a8c0fd8c";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"08040020839b0a02";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"004d00000053f818";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"aa55aa55aa550400";
      wait for CLK_PERIOD_C;
      phyRxC <= x"00";
      phyRxD <= x"aa55_aa55_aa55_aa55";
      wait for 126*CLK_PERIOD_C;
      phyRxC <= x"c0";
      phyRxD <= x"07fd5e081389aa55";
      wait for CLK_PERIOD_C;

      phyRxC <= x"ff";
      phyRxD <= x"0707_0707_0707_0707";

   end process;

end testbed;
