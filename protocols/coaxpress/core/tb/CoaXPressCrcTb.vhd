-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation CoaXPressCrc Testbed
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
use surf.AxiStreamPkg.all;
use surf.CrcPkg.all;
use surf.SsiPkg.all;

entity CoaXPressCrcTb is
end entity CoaXPressCrcTb;

architecture tb of CoaXPressCrcTb is

   signal cfgIbMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal cfgTxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal cfgTxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal clk : sl := '0';
   signal rst : sl := '0';

begin

   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 10 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1000 ns)
      port map (
         clkP => clk,
         rst  => rst);

   -- Generate SRPv3 read message
   cfgIbMaster.tValid                <= '1';
   cfgIbMaster.tLast                 <= '1';
   cfgIbMaster.tUser(1)              <= '1';
   cfgIbMaster.tData(31 downto 0)    <= x"0000_0003";  -- Word[0] = HEADER
   cfgIbMaster.tData(63 downto 32)   <= x"0000_0000";  -- Word[1] = TID[31:0]
   cfgIbMaster.tData(95 downto 64)   <= x"0000_0000";  -- Word[2] = Addr[31:0]
   cfgIbMaster.tData(127 downto 96)  <= x"0000_0000";  -- Word[3] = Addr[63:32]
   cfgIbMaster.tData(159 downto 128) <= x"0000_0003";  -- Word[4] = ReqSize[31:0]

   U_DUT : entity surf.CoaXPressConfig
      generic map (
         AXIS_CONFIG_G => ssiAxiStreamConfig(dataBytes => 160/8))
      port map (
         -- Clock and Reset
         cfgClk          => clk,
         cfgRst          => rst,
         -- Config Interface (cfgClk domain)
         configTimerSize => x"000_FFF",
         configErrResp   => '1',
         configPktTag    => '0',
         cfgIbMaster     => cfgIbMaster,
         cfgIbSlave      => open,
         cfgObMaster     => open,
         cfgObSlave      => AXI_STREAM_SLAVE_FORCE_C,
         -- TX Interface
         cfgTxMaster     => cfgTxMaster,
         cfgTxSlave      => cfgTxSlave,
         -- RX Interface
         cfgRxMaster     => AXI_STREAM_MASTER_INIT_C);

   U_Tx : entity surf.CoaXPressTx
      port map (
         -- Config Interface (cfgClk domain)
         cfgClk      => clk,
         cfgRst      => rst,
         cfgTxMaster => cfgTxMaster,
         cfgTxSlave  => cfgTxSlave,
         -- TX Interface (txClk domain)
         txClk       => clk,
         txRst       => rst,
         txLsRate    => '0',
         txLsValid   => open,
         txLsData    => open,
         txLsDataK   => open,
         txHsData    => open,
         txHsDataK   => open,
         swTrig      => (others => '0'),
         txTrig      => (others => '0'),
         txTrigDrop  => open);

   -- To aid understanding, a complete control command packet without tag (a read of address 0) is shown
   -- here, with the resulting CRC shown in red: K27.7 K27.7 K27.7 K27.7 0x02 0x02 0x02 0x02 0x00 0x00
   -- 0x00 0x04 0x00 0x00 0x00 0x00 0x56 0x86 0x5D 0x6F K29.7 K29.7 K29.7 K29.7.

end architecture tb;
