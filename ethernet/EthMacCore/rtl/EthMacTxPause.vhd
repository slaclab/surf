-------------------------------------------------------------------------------
-- File       : EthMacTxPause.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-22
-- Last update: 2016-10-20
-------------------------------------------------------------------------------
-- Description:
-- Generic pause frame generator for Ethernet MACs.  This module as acts as
-- a gate keeper when the peer has requested a pause period.
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.AxiStreamPkg.all;
use work.StdRtlPkg.all;
use work.EthMacPkg.all;

entity EthMacTxPause is
   generic (
      TPD_G           : time                    := 1 ns;
      PAUSE_EN_G      : boolean                 := true;
      PAUSE_512BITS_G : natural range 1 to 1024 := 8;
      VLAN_EN_G       : boolean                 := false;
      VLAN_SIZE_G     : positive range 1 to 8   := 1);      
   port (
      -- Clock and Reset
      ethClk       : in  sl;
      ethRst       : in  sl;
      -- Incoming data from client
      sAxisMaster  : in  AxiStreamMasterType;
      sAxisSlave   : out AxiStreamSlaveType;
      sAxisMasters : in  AxiStreamMasterArray(VLAN_SIZE_G-1 downto 0);
      sAxisSlaves  : out AxiStreamSlaveArray(VLAN_SIZE_G-1 downto 0);
      -- Outgoing data to MAC
      mAxisMaster  : out AxiStreamMasterType;
      mAxisSlave   : in  AxiStreamSlaveType;
      -- Flow control input
      clientPause  : in  sl;
      -- Inputs from pause frame RX
      rxPauseReq   : in  sl;
      rxPauseValue : in  slv(15 downto 0);
      -- Configuration and status
      phyReady     : in  sl;
      pauseEnable  : in  sl;
      pauseTime    : in  slv(15 downto 0);
      macAddress   : in  slv(47 downto 0);
      pauseTx      : out sl);
end EthMacTxPause;

architecture rtl of EthMacTxPause is

   constant CNT_BITS_C : integer := bitSize(PAUSE_512BITS_G);
   constant SIZE_C     : natural := ite(VLAN_EN_G, (VLAN_SIZE_G+1), 1);

   type StateType is (
      IDLE_S,
      PAUSE_S,
      PASS_S);

   type RegType is record
      locPauseCnt : slv(15 downto 0);
      remPauseCnt : slv(15 downto 0);
      txCount     : slv(1 downto 0);
      locPreCnt   : slv(CNT_BITS_C-1 downto 0);
      remPreCnt   : slv(CNT_BITS_C-1 downto 0);
      pauseTx     : sl;
      mAxisMaster : AxiStreamMasterType;
      rxSlave     : AxiStreamSlaveType;
      state       : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      locPauseCnt => (others => '0'),
      remPauseCnt => (others => '0'),
      txCount     => (others => '0'),
      locPreCnt   => (others => '0'),
      remPreCnt   => (others => '0'),
      pauseTx     => '0',
      mAxisMaster => AXI_STREAM_MASTER_INIT_C,
      rxSlave     => AXI_STREAM_SLAVE_INIT_C,
      state       => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxMasters : AxiStreamMasterArray(SIZE_C-1 downto 0);
   signal rxSlaves  : AxiStreamSlaveArray(SIZE_C-1 downto 0);

   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";

begin

   rxMasters(0) <= sAxisMaster;
   sAxisSlave   <= rxSlaves(0);

   U_NoVlanGen : if (VLAN_EN_G = false) generate
      
      rxMaster    <= rxMasters(0);
      rxSlaves(0) <= rxSlave;
      sAxisSlaves <= (others => AXI_STREAM_SLAVE_FORCE_C);
      
   end generate;

   U_VlanGen : if (VLAN_EN_G = true) generate
      
      GEN_VEC :
      for i in (VLAN_SIZE_G-1) downto 0 generate
         rxMasters(i+1) <= sAxisMasters(i);
         sAxisSlaves(i) <= rxSlaves(i+1);
      end generate GEN_VEC;

      U_AxiStreamMux : entity work.AxiStreamMux
         generic map (
            TPD_G        => TPD_G,
            NUM_SLAVES_G => SIZE_C)
         port map (
            -- Clock and reset
            axisClk      => ethClk,
            axisRst      => ethRst,
            -- Slaves
            sAxisMasters => rxMasters,
            sAxisSlaves  => rxSlaves,
            -- Master
            mAxisMaster  => rxMaster,
            mAxisSlave   => rxSlave);    

   end generate;

   U_TxPauseGen : if (PAUSE_EN_G = true) generate

      comb : process (clientPause, ethRst, mAxisSlave, macAddress, pauseEnable, pauseTime, phyReady,
                      r, rxMaster, rxPauseReq, rxPauseValue) is
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Reset the flags
         v.pauseTx := '0';
         v.rxSlave := AXI_STREAM_SLAVE_INIT_C;
         if (mAxisSlave.tReady = '1') then
            v.mAxisMaster.tValid := '0';
         end if;

         -- Pre-counter, 8 clocks ~= 512 bit times of 10G
         v.remPreCnt := r.remPreCnt - 1;
         v.locPreCnt := r.locPreCnt - 1;

         -- Local pause count tracking
         if (pauseEnable = '0') then
            v.locPauseCnt := (others => '0');
         elsif (rxPauseReq = '1') then
            v.locPauseCnt := rxPauseValue;
            v.locPreCnt   := (others => '1');
         elsif (r.locPauseCnt /= 0) and (r.locPreCnt = 0) then
            v.locPauseCnt := r.locPauseCnt - 1;
         end if;

         -- Remote pause count tracking
         if (r.remPauseCnt /= 0) and (r.remPreCnt = 0) then
            v.remPauseCnt := r.remPauseCnt - 1;
         end if;

         -- State Machine
         case r.state is
            ----------------------------------------------------------------------
            when IDLE_S =>
               -- Check if we need to transmit pause
               if (clientPause = '1') and (r.remPauseCnt = 0) and (pauseEnable = '1') and (phyReady = '1') then
                  -- Next state
                  v.state := PAUSE_S;
               -- Transmit required and not paused by received pause count
               elsif (rxMaster.tValid = '1') and (r.locPauseCnt = 0) then
                  -- Next state
                  v.state := PASS_S;
               end if;
            ----------------------------------------------------------------------
            when PAUSE_S =>
               ----------------------------------------------------------------------------------------------------------
               -- Refer to https://www.safaribooksonline.com/library/view/ethernet-the-definitive/1565926609/ch04s02.html
               ----------------------------------------------------------------------------------------------------------
               -- Check if ready to move data
               if (v.mAxisMaster.tValid = '0') then
                  -- Reset the bus to defaults
                  v.mAxisMaster        := AXI_STREAM_MASTER_INIT_C;
                  -- Performing a write operation
                  v.mAxisMaster.tValid := '1';
                  -- Increment the counter
                  v.txCount            := r.txCount + 1;
                  -- Check the flag
                  if (r.txCount = 0) then
                     -- DST MAC (Pause MAC Address)
                     v.mAxisMaster.tData(47 downto 0)    := x"010000C28001";
                     -- SRC MAC (local MAC address)
                     v.mAxisMaster.tData(95 downto 48)   := macAddress;
                     -- MAC Control Type
                     v.mAxisMaster.tData(111 downto 96)  := x"0888";
                     -- Pause Op-code
                     v.mAxisMaster.tData(127 downto 112) := x"0100";                -- 2 bytes
                  elsif (r.txCount = 1) then
                     -- Pause length
                     v.mAxisMaster.tData(7 downto 0)    := pauseTime(15 downto 8);  -- 1 bytes
                     v.mAxisMaster.tData(15 downto 8)   := pauseTime(7 downto 0);   -- 1 bytes
                     -- Zero Padding
                     v.mAxisMaster.tData(127 downto 16) := (others => '0');         -- 14 bytes
                  elsif (r.txCount = 2) then
                     -- Zero Padding
                     v.mAxisMaster.tData := (others => '0');
                     v.mAxisMaster.tKeep := x"FFFF";  -- 16 bytes    
                  else
                     -- Zero Padding
                     v.mAxisMaster.tData := (others => '0');
                     v.mAxisMaster.tKeep := x"0FFF";  -- 12 bytes (Fixed frame size = 46 bytes)
                     -- Set EOF
                     v.mAxisMaster.tLast := '1';
                     -- Latch the Pause time   
                     v.remPauseCnt       := pauseTime;
                     v.remPreCnt         := (others => '1');
                     v.pauseTx           := '1';
                     -- Reset the counter
                     v.txCount           := (others => '0');
                     -- Next state
                     v.state             := IDLE_S;
                  end if;
               end if;
            ----------------------------------------------------------------------
            when PASS_S =>
               -- Check if ready to move data
               if (v.mAxisMaster.tValid = '0') and (rxMaster.tValid = '1') then
                  -- Accept the data
                  v.rxSlave.tReady := '1';
                  -- Move the data
                  v.mAxisMaster    := rxMaster;
                  -- Check for EOF
                  if (rxMaster.tLast = '1') then
                     -- Next state
                     v.state := IDLE_S;
                  end if;
               end if;
         ----------------------------------------------------------------------
         end case;

         -- Reset
         if (ethRst = '1') then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs 
         rxSlave     <= v.rxSlave;
         mAxisMaster <= r.mAxisMaster;
         pauseTx     <= r.pauseTx;

      end process;

      seq : process (ethClk) is
      begin
         if rising_edge(ethClk) then
            r <= rin after TPD_G;
         end if;
      end process seq;
      
   end generate;

   U_BypTxPause : if (PAUSE_EN_G = false) generate
      mAxisMaster <= rxMaster;
      rxSlave     <= mAxisSlave;
      pauseTx     <= '0';
   end generate;
   
end rtl;
