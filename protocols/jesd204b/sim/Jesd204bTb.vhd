-------------------------------------------------------------------------------
-- File       : Jesd204bTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-02-03
-- Last update: 2018-05-11
-------------------------------------------------------------------------------
-- Description: Simulation testbed for Jesd204b
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
use work.AxiLitePkg.all;
use work.Jesd204bPkg.all;

entity Jesd204bTb is
end Jesd204bTb;

architecture tb of Jesd204bTb is

   constant CLK_PERIOD_C : time := 10 ns;
   constant TPD_C        : time := CLK_PERIOD_C/4;

   constant EN_SCRAMBLER_C : boolean := false;

   signal clk        : sl := '0';
   signal rst        : sl := '0';
   signal rstL       : sl := '1';
   signal configDone : sl := '0';
   signal sysRef     : sl := '0';

   signal jesdGtTxArr : jesdGtTxLaneType := JESD_GT_TX_LANE_INIT_C;
   signal jesdGtRxArr : jesdGtRxLaneType := JESD_GT_RX_LANE_INIT_C;

   signal txReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal txReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal txWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal txWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

   signal rxReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal rxReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal rxWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal rxWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

   signal txData  : slv(31 downto 0) := (others => '0');
   signal rxValid : sl               := '0';
   signal rxData  : slv(31 downto 0) := (others => '0');

begin

   ---------------------------
   -- Generate clock and reset
   ---------------------------
   U_ClkRst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => rstL);

   ---------------------
   -- Generate a counter
   ---------------------
   process(clk)
   begin
      if rising_edge(clk) then
         if (configDone = '0') then
            txData <= (others => '0') after TPD_C;
         else
            txData <= txData + 1 after TPD_C;
         end if;
      end if;
   end process;

   ---------------------------------------
   -- SYSREF period will be 128 clk cycles
   ---------------------------------------
   U_sysRef : entity work.JesdLmfcGen
      generic map (
         TPD_G => TPD_G,
         K_G   => 256,
         F_G   => 2)
      port map (
         clk      => clk,
         rst      => rst,
         nSync_i  => '0',
         sysref_i => '0',
         lmfc_o   => s_sysRef);

   -----------------
   -- JESD TX Module
   -----------------
   U_Jesd204bTx : entity work.Jesd204bTx
      generic map (
         TPD_G => TPD_C,
         K_G   => 32,
         F_G   => 2,
         L_G   => 1)
      port map (
         axiClk           => clk,
         axiRst           => rst,
         axilReadMaster   => txReadMaster,
         axilReadSlave    => txReadSlave,
         axilWriteMaster  => txWriteMaster,
         axilWriteSlave   => txWriteSlave,
         extSampleDataArray_i(0) txData,
         devClk_i         => clk,
         devRst_i         => rst,
         sysRef_i         => sysRef,
         nSync_i          => nSync,
         gtTxReady_i      => (others = configDone),
         r_jesdGtTxArr(0) => jesdGtTxArr);

   -------------------------
   -- Map the GT TX to GT RX
   -------------------------
   jesdGtRxArr.data      <= jesdGtTxArr.data;
   jesdGtRxArr.dataK     <= jesdGtTxArr.dataK;
   jesdGtRxArr.rstDone   <= configDone;
   jesdGtRxArr.cdrStable <= configDone;

   -----------------
   -- JESD RX Module
   -----------------            
   U_Jesd204bRx : entity work.Jesd204bRx
      generic map (
         TPD_G => TPD_C,
         K_G   => 32,
         F_G   => 2,
         L_G   => 1)
      port map (
         axiClk             => clk,
         axiRst             => rst,
         axilReadMaster     => rxReadMaster,
         axilReadSlave      => rxReadSlave,
         axilWriteMaster    => rxWriteMaster,
         axilWriteSlave     => rxWriteSlave,
         devClk_i           => clk,
         devRst_i           => rst,
         sysRef_i           => sysRef,
         dataValidVec_o(0)  => rxValid,
         sampleDataArr_o(0) => rxData,
         r_jesdGtRxArr(0)   => jesdGtRxArr,
         nSync_o            => nSync);

   ---------------------------
   -- Configure the JESD RX/TX
   ---------------------------
   config : process is
      variable addr : slv(31 downto 0) := (others => '0');
      variable data : slv(31 downto 0) := (others => '0');
   begin
      configDone <= '0';
      wait until rst = '1';
      wait until rst = '0';

      -- Configure the JESD TX
      axiLiteBusSimWrite(clk, txWriteMaster, txWriteSlave, x"00000000", x"00000001");  -- Enable=0x1 
      if(EN_SCRAMBLER_C) then
         axiLiteBusSimWrite(clk, txWriteMaster, txWriteSlave, x"00000010", x"00000043");  -- scrEnable=0x1,SubClass=x01,ReplaceEnable=0x1 
      else
         axiLiteBusSimWrite(clk, txWriteMaster, txWriteSlave, x"00000010", x"00000003");  -- SubClass=x01,ReplaceEnable=0x1 
      end if;

      -- Configure the JESD RX
      axiLiteBusSimWrite(clk, rxWriteMaster, rxWriteSlave, x"00000000", x"00000001");  -- Enable=0x1 
      axiLiteBusSimWrite(clk, rxWriteMaster, rxWriteSlave, x"00000004", x"0000000B");  -- SysrefDelay=0x8
      if(EN_SCRAMBLER_C) then
         axiLiteBusSimWrite(clk, rxWriteMaster, rxWriteSlave, x"00000010", x"00000023");  -- scrEnable=0x1,SubClass=x01,ReplaceEnable=0x1 
      else
         axiLiteBusSimWrite(clk, rxWriteMaster, rxWriteSlave, x"00000010", x"00000003");  -- SubClass=x01,ReplaceEnable=0x1 
      end if;

      configDone <= '1';

   end process config;

end tb;
