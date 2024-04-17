-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the EthMac module
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
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

entity EthMacTb is
end EthMacTb;

architecture testbed of EthMacTb is

   constant CLK_PERIOD_C : time := 10 ns;
   constant TPD_G        : time := (CLK_PERIOD_C/4);

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(1);  -- 1 byte wide AXI stream interface

   constant PRESET_SIZE_G : slv(7 downto 0) := toSlv(11, 8);  -- Present up to the SRC MAC + DST MAC

   type RegType is record
      txMaster    : AxiStreamMasterType;
      txSize      : slv(7 downto 0);
      txCnt       : slv(7 downto 0);
      rxSlave     : AxiStreamSlaveType;
      rxSize      : slv(7 downto 0);
      rxCnt       : slv(7 downto 0);
      errorDet    : slv(7 downto 0);
      errorDetDly : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      txMaster    => AXI_STREAM_MASTER_INIT_C,
      txSize      => PRESET_SIZE_G,
      txCnt       => (others => '0'),
      rxSlave     => AXI_STREAM_SLAVE_INIT_C,
      rxSize      => PRESET_SIZE_G,
      rxCnt       => (others => '0'),
      errorDet    => (others => '0'),
      errorDetDly => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clk      : sl := '0';
   signal rst      : sl := '0';
   signal phyReady : sl := '0';

   signal txMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal rxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal ethStatus : EthMacStatusType := ETH_MAC_STATUS_INIT_C;
   signal ethConfig : EthMacConfigType := ETH_MAC_CONFIG_INIT_C;
   signal phyD      : slv(63 downto 0) := (others => '0');
   signal phyC      : slv(7 downto 0)  := (others => '0');

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
         JUMBO_G       => false,
         PHY_TYPE_G    => "XGMII",
         PRIM_CONFIG_G => AXIS_CONFIG_C)
      port map (
         -- DMA Interface
         primClk         => clk,
         primRst         => rst,
         ibMacPrimMaster => txMaster,
         ibMacPrimSlave  => txSlave,
         obMacPrimMaster => rxMaster,
         obMacPrimSlave  => rxSlave,
         -- Ethernet Interface
         ethClk          => clk,
         ethRst          => rst,
         ethConfig       => ethConfig,
         phyReady        => phyReady,
         -- XGMII PHY Interface
         xgmiiRxd        => phyD,       -- Loopback
         xgmiiRxc        => phyC,       -- Loopback
         xgmiiTxd        => phyD,       -- Loopback
         xgmiiTxc        => phyC);      -- Loopback

   -- For simplicity in error checking, local MAC is a counter sequence
   ethConfig.macAddress <= x"0B_0A_09_08_07_06";

   -- Only doing RAW Ethernet communication
   ethConfig.ipCsumEn  <= '0';
   ethConfig.tcpCsumEn <= '0';
   ethConfig.udpCsumEn <= '0';

   comb : process (r, rst, rxMaster, txSlave) is
      variable v        : RegType;
      variable rxEofIdx : slv(7 downto 0);
   begin
      -- Latch the current value
      v := r;

      ------------------
      -- TX Stream Logic
      ------------------
      v.txMaster.tKeep := toSlv(1, AXI_STREAM_MAX_TKEEP_WIDTH_C);
      if (txSlave.tReady = '1') then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
      end if;

      -- Check if ready to move data
      if (v.txMaster.tValid = '0') then

         -- Move data
         v.txMaster.tValid            := '1';
         v.txMaster.tData(7 downto 0) := r.txCnt;

         -- Check if SOF event
         if (r.txCnt = 0) then
            -- Set SOF flag
            ssiSetUserSof(AXIS_CONFIG_C, v.txMaster, '1');
         end if;

         -- Check if EOF event
         if (r.txCnt = r.txSize) then

            -- Reset the counter
            v.txCnt := (others => '0');

            -- Check for roll over
            if (r.txSize = x"FF")then
               v.txSize := PRESET_SIZE_G;
            else
               -- Increment the counter
               v.txSize := r.txSize + 1;
            end if;

            -- Set EOF flag
            v.txMaster.tLast := '1';

         else
            -- Increment the counter
            v.txCnt := r.txCnt + 1;
         end if;

      end if;

      ------------------
      -- RX Stream Logic
      ------------------
      v.rxSlave := AXI_STREAM_SLAVE_INIT_C;

      -- EthMacTxExportXgmii.vhd enforces a min. payload of 64 bytes
      if (r.rxSize > 64) then
         rxEofIdx := r.rxSize;
      else
         rxEofIdx := toSlv(64, 8);
      end if;

      -- Check if ready to move data
      if (rxMaster.tValid = '1') then

         -- Accept the data
         v.rxSlave.tReady := '1';

         -- Check for data error
         if (r.rxCnt > r.rxSize) then
            -- Zero padding
            if (rxMaster.tData(7 downto 0) /= 0) then
               -- Set the error flag
               v.errorDet(0) := '1';
            end if;
         else
            if (rxMaster.tData(7 downto 0) /= r.rxCnt) then
               -- Set the error flag
               v.errorDet(1) := '1';
            end if;
         end if;

         -- Check if SOF error
         if (r.rxCnt = 0) and (ssiGetUserSof(AXIS_CONFIG_C, rxMaster) /= '1') then
            -- Set the error flag
            v.errorDet(2) := '1';
         end if;

         -- Check if EOF error
         if ((r.rxCnt = rxEofIdx) and (rxMaster.tLast /= '1')) then
            -- Set the error flag
            v.errorDet(3) := '1';
         end if;

         -- Check if EOF error
         if ((r.rxCnt /= rxEofIdx) and (rxMaster.tLast = '1')) then
            -- Set the error flag
            v.errorDet(3) := '1';
         end if;

         -- Check if EOF event
         if (rxMaster.tLast = '1') then

            -- Reset the counter
            v.rxCnt := (others => '0');

            -- Check for roll over
            if (r.rxSize = x"FF")then
               v.rxSize := PRESET_SIZE_G;
            else
               -- Increment the counter
               v.rxSize := r.rxSize + 1;
            end if;

         else
            -- Increment the counter
            v.rxCnt := r.rxCnt + 1;
         end if;

      end if;

      -- Set the error flags
      v.errorDet(4) := ethStatus.rxFifoDropCnt;
      v.errorDet(5) := ethStatus.rxOverFlow;
      v.errorDet(6) := ethStatus.rxCrcErrorCnt;
      v.errorDet(7) := ethStatus.txUnderRunCnt;

      -- Outputs
      rxSlave  <= v.rxSlave;
      txMaster <= r.txMaster;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      ---------------------------------
      -- Simulation Error Self-checking
      ---------------------------------
      v.errorDetDly := uOr(r.errorDet);
      if r.errorDetDly = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end testbed;
