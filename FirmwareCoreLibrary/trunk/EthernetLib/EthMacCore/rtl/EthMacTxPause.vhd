-------------------------------------------------------------------------------
-- Title      : 1GbE/10GbE Ethernet MAC
-------------------------------------------------------------------------------
-- File       : EthMacTxPause.vhd
-- Author     : Ryan Herbst <rherbst@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-22
-- Last update: 2016-09-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Generic pause frame generator for Ethernet MACs.  This module as acts as
-- a gate keeper when the peer has requested a pause period.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Ethernet Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Ethernet Library', including this file, 
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
      VLAN_CNT_G      : positive range 1 to 8   := 1);      
   port (
      -- Clock and Reset
      ethClk       : in  sl;
      ethRst       : in  sl;
      -- Incoming data from client
      sAxisMaster  : in  AxiStreamMasterType;
      sAxisSlave   : out AxiStreamSlaveType;
      sAxisMasters : in  AxiStreamMasterArray(VLAN_CNT_G-1 downto 0);
      sAxisSlaves  : out AxiStreamSlaveArray(VLAN_CNT_G-1 downto 0);
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
      pauseTx      : out sl;
      pauseVlanTx  : out slv(7 downto 0));
end EthMacTxPause;

architecture rtl of EthMacTxPause is

   constant CNT_BITS_C : integer := bitSize(PAUSE_512BITS_G);

   type StateType is (
      IDLE_S,
      PASS_S,
      TX_S);

   type RegType is record
      state       : StateType;
      locPauseCnt : slv(15 downto 0);
      remPauseCnt : slv(15 downto 0);
      txCount     : slv(1 downto 0);
      locPreCnt   : slv(CNT_BITS_C-1 downto 0);
      remPreCnt   : slv(CNT_BITS_C-1 downto 0);
      pauseTx     : sl;
      pauseVlanTx : slv(7 downto 0);
      outMaster   : AxiStreamMasterType;
      outSlave    : AxiStreamSlaveType;
      vlanSlaves  : AxiStreamSlaveArray(VLAN_CNT_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      state       => IDLE_S,
      locPauseCnt => (others => '0'),
      remPauseCnt => (others => '0'),
      txCount     => (others => '0'),
      locPreCnt   => (others => '0'),
      remPreCnt   => (others => '0'),
      pauseTx     => '0',
      pauseVlanTx => (others => '0'),
      outMaster   => AXI_STREAM_MASTER_INIT_C,
      outSlave    => AXI_STREAM_SLAVE_INIT_C,
      vlanSlaves  => (others => AXI_STREAM_SLAVE_INIT_C));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";

begin

   U_TxPauseGen : if (PAUSE_EN_G = true) generate

      comb : process (clientPause, ethRst, mAxisSlave, macAddress, pauseEnable, pauseTime, phyReady,
                      r, rxPauseReq, rxPauseValue, sAxisMaster) is
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Pre-counter, 8 clocks ~= 512 bit times of 10G
         v.remPreCnt := r.remPreCnt - 1;
         v.locPreCnt := r.locPreCnt - 1;
         v.pauseTx   := '0';

         -- Local pause count tracking
         if pauseEnable = '0' then
            v.locPauseCnt := (others => '0');
         elsif rxPauseReq = '1' then
            v.locPauseCnt := rxPauseValue;
            v.locPreCnt   := (others => '1');
         elsif r.locPauseCnt /= 0 and r.locPreCnt = 0 then
            v.locPauseCnt := r.locPauseCnt - 1;
         end if;

         -- Remote pause count tracking
         if r.remPauseCnt /= 0 and r.remPreCnt = 0 then
            v.remPauseCnt := r.remPauseCnt - 1;
         end if;

         -- Clear tValid on ready assertion
         if mAxisSlave.tReady = '1' then
            v.outMaster.tValid := '0';
         end if;

         -- Clear ready
         v.outSlave   := AXI_STREAM_SLAVE_INIT_C;
         v.vlanSlaves := (others => AXI_STREAM_SLAVE_INIT_C);

         -- State Machine
         case r.state is

            -- IDLE, wait for frame
            when IDLE_S =>
               v.txCount := (others => '0');

               -- Pause transmit needed
               if clientPause = '1' and r.remPauseCnt = 0 and pauseEnable = '1' and phyReady = '1' then
                  v.state := TX_S;

               -- Transmit required and not paused by received pause count
               elsif sAxisMaster.tValid = '1' and r.locPauseCnt = 0 then
                  v.state := PASS_S;
               end if;

            -- Pause transmit
            when TX_S =>

               if v.outMaster.tValid = '0' then
                  v.outMaster        := AXI_STREAM_MASTER_INIT_C;
                  v.outMaster.tValid := '1';
                  v.txCount          := r.txCount + 1;

                  -- Select output data
                  case r.txCount is

                     -- Src Id, Upper 2 Bytes + Dest Id, All 6 bytes
                     when "00" =>
                        v.outMaster.tData(63 downto 48) := macAddress(15 downto 0);
                        v.outMaster.tData(47 downto 0)  := x"010000C28001";

                     -- Pause Op-code + Length/Type Field + Src Id, Lower 4 bytes
                     when "01" =>
                        v.outMaster.tData(63 downto 48) := x"0100";
                        v.outMaster.tData(47 downto 32) := x"0888";
                        v.outMaster.tData(31 downto 0)  := macAddress(47 downto 16);

                     -- Pause length and padding
                     when "10" =>
                        v.outMaster.tData(63 downto 16) := (others => '0');
                        v.outMaster.tData(15 downto 8)  := pauseTime(7 downto 0);
                        v.outMaster.tData(7 downto 0)   := pauseTime(15 downto 8);

                     -- padding
                     when others =>
                        v.outMaster.tLast := '1';
                        v.remPauseCnt     := pauseTime;
                        v.remPreCnt       := (others => '1');
                        v.pauseTx         := '1';
                        v.state           := IDLE_S;

                  end case;
               end if;

            -- Passing data
            when PASS_S =>

               -- Fill chain
               if v.outMaster.tValid = '0' then
                  v.outSlave.tReady := '1';
                  v.outMaster       := sAxisMaster;

                  if sAxisMaster.tValid = '1' and sAxisMaster.tLast = '1' then
                     v.state := IDLE_S;
                  end if;
               end if;

         end case;

         -- Reset
         if ethRst = '1' then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs 
         mAxisMaster <= r.outMaster;
         sAxisSlave  <= v.outSlave;
         sAxisSlaves <= v.vlanSlaves;
         pauseTx     <= r.pauseTx;
         pauseVlanTx <= r.pauseVlanTx;

      end process;

      seq : process (ethClk) is
      begin
         if rising_edge(ethClk) then
            r <= rin after TPD_G;
         end if;
      end process seq;
      
   end generate;

   U_BypTxPause : if (PAUSE_EN_G = false) generate
      mAxisMaster <= sAxisMaster;
      sAxisSlave  <= mAxisSlave;
      pauseTx     <= '0';
      pauseVlanTx <= (others => '0');
   end generate;
   
end rtl;
