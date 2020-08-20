-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.Jesd204bPkg.all;

entity Jesd204bTb is
end Jesd204bTb;

architecture tb of Jesd204bTb is

   constant CLK_PERIOD_C : time := 1 us;  -- 1 us makes it easy to count clock cycles in sim GUI
   constant TPD_G        : time := CLK_PERIOD_C/4;

   constant EN_SCRAMBLER_C : boolean := true;

   --------------------------------------------------------
   -- BYTE_SHIFT_C=0: JesdRx.JesdAlignChGen.position="0001"
   -- BYTE_SHIFT_C=1: JesdRx.JesdAlignChGen.position="1000"
   -- BYTE_SHIFT_C=2: JesdRx.JesdAlignChGen.position="0100"
   -- BYTE_SHIFT_C=3: JesdRx.JesdAlignChGen.position="0010"
   --------------------------------------------------------
   constant BYTE_SHIFT_C : natural range 0 to 3 := 3;

   signal clk        : sl := '0';
   signal rst        : sl := '0';
   signal rstL       : sl := '1';
   signal configDone : sl := '0';
   signal sysRef     : sl := '0';
   signal nSync      : sl := '0';

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

   signal txData         : slv(31 downto 0) := (others => '0');
   signal rxValid        : sl               := '0';
   signal rxData         : slv(31 downto 0) := (others => '0');
   signal nextRxData     : slv(31 downto 0) := (others => '0');
   signal cnt            : slv(6 downto 0)  := (others => '0');
   signal rxDataErrorDet : sl               := '0';
   signal data           : slv(63 downto 0) := (others => '0');
   signal dataK          : slv(7 downto 0)  := (others => '0');
   signal kCharDet       : slv(3 downto 0)  := (others => '0');
   signal rCharDet       : slv(3 downto 0)  := (others => '0');
   signal aCharDet       : slv(3 downto 0)  := (others => '0');
   signal fCharDet       : slv(3 downto 0)  := (others => '0');

begin

   ---------------------------
   -- Generate clock and reset
   ---------------------------
   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 10 us)    -- Hold reset for this long)
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
         -- Reset strobes
         rxDataErrorDet <= '0' after TPD_G;
         -- Wait for config to finish before sending data
         if (configDone = '0') then
            txData(7 downto 0)   <= x"00" after TPD_G;
            txData(15 downto 8)  <= x"01" after TPD_G;
            txData(23 downto 16) <= x"02" after TPD_G;
            txData(31 downto 24) <= x"03" after TPD_G;
         else
            txData(7 downto 0)   <= txData(7 downto 0) + 4   after TPD_G;
            txData(15 downto 8)  <= txData(15 downto 8) + 4  after TPD_G;
            txData(23 downto 16) <= txData(23 downto 16) + 4 after TPD_G;
            txData(31 downto 24) <= txData(31 downto 24) + 4 after TPD_G;
         end if;
         -- Wait for rxValid
         if (rxValid = '1') then
            -- Check for diff
            if (rxData /= nextRxData) then
               rxDataErrorDet <= '1' after TPD_G;
            end if;
         end if;
         -- Create a free running counter
         cnt                      <= cnt + 1                  after TPD_G;
         -- Calculate next RX data
         nextRxData(7 downto 0)   <= rxData(7 downto 0) + 4   after TPD_G;
         nextRxData(15 downto 8)  <= rxData(15 downto 8) + 4  after TPD_G;
         nextRxData(23 downto 16) <= rxData(23 downto 16) + 4 after TPD_G;
         nextRxData(31 downto 24) <= rxData(31 downto 24) + 4 after TPD_G;
      end if;
   end process;

   ---------------------------------------
   -- SYSREF period will be 128 clk cycles
   ---------------------------------------
   sysRef <= cnt(6);

   -----------------
   -- JESD TX Module
   -----------------
   U_Jesd204bTx : entity surf.Jesd204bTx
      generic map (
         TPD_G => TPD_G,
         K_G   => 32,
         F_G   => 2,
         L_G   => 1)
      port map (
         axiClk                  => clk,
         axiRst                  => rst,
         axilReadMaster          => txReadMaster,
         axilReadSlave           => txReadSlave,
         axilWriteMaster         => txWriteMaster,
         axilWriteSlave          => txWriteSlave,
         extSampleDataArray_i(0) => txData,
         devClk_i                => clk,
         devRst_i                => rst,
         sysRef_i                => sysRef,
         nSync_i(0)              => nSync,
         gtTxReady_i             => (others => configDone),
         r_jesdGtTxArr(0)        => jesdGtTxArr);

   ------------------------------------
   -- Generate SLV to test unaligned
   -- byte compensations in the JESD RX
   ------------------------------------
   process(clk)
   begin
      if rising_edge(clk) then
         data(31 downto 0)  <= data(63 downto 32) after TPD_G;
         dataK(3 downto 0)  <= dataK(7 downto 4)  after TPD_G;
         data(63 downto 32) <= jesdGtTxArr.data   after TPD_G;
         dataK(7 downto 4)  <= jesdGtTxArr.dataK  after TPD_G;
      end if;
   end process;

   -------------------------
   -- Map the GT TX to GT RX
   -------------------------
   jesdGtRxArr.data      <= data(31+(8*BYTE_SHIFT_C) downto (8*BYTE_SHIFT_C));  --- BYTE_SHIFT_C  applied the byte misalignment
   jesdGtRxArr.dataK     <= dataK(3+BYTE_SHIFT_C downto BYTE_SHIFT_C);
   jesdGtRxArr.rstDone   <= configDone;
   jesdGtRxArr.cdrStable <= configDone;

   -----------------------------------
   -- Adding char detect for debugging
   -----------------------------------
   process(jesdGtRxArr)
      variable i    : natural;
      variable kDet : slv(3 downto 0);
      variable rDet : slv(3 downto 0);
      variable aDet : slv(3 downto 0);
      variable fDet : slv(3 downto 0);
   begin
      -- Reset
      kDet := x"0";
      rDet := x"0";
      aDet := x"0";
      fDet := x"0";
      -- Loop through the 8B10B bytes
      for i in 3 downto 0 loop
         if (jesdGtRxArr.dataK(i) = '1') then
            if (jesdGtRxArr.data(7+(8*i) downto (8*i)) = K_CHAR_C) then
               kDet(i) := '1';
            end if;
            if (jesdGtRxArr.data(7+(8*i) downto (8*i)) = R_CHAR_C) then
               rDet(i) := '1';
            end if;
            if (jesdGtRxArr.data(7+(8*i) downto (8*i)) = A_CHAR_C) then
               aDet(i) := '1';
            end if;
            if (jesdGtRxArr.data(7+(8*i) downto (8*i)) = F_CHAR_C) then
               fDet(i) := '1';
            end if;
         end if;
      end loop;
      -- Return the results
      kCharDet <= kDet;
      rCharDet <= rDet;
      aCharDet <= aDet;
      fCharDet <= fDet;
   end process;

   -----------------
   -- JESD RX Module
   -----------------
   U_Jesd204bRx : entity surf.Jesd204bRx
      generic map (
         TPD_G => TPD_G,
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
   begin
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
