-------------------------------------------------------------------------------
-- Title         : Generic Ethernet Pause Frame Generation
-- Project       : Ethernet MAC
-------------------------------------------------------------------------------
-- File          : EthPauseTx.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 09/22/2015
-------------------------------------------------------------------------------
-- Description:
-- Generic pause frame generator for Ethernet MACs.  This module as acts as
-- a gate keeper when the peer has requested a pause period.
-------------------------------------------------------------------------------
-- Copyright (c) 2008 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 09/22/2015: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.AxiStreamPkg.all;
use work.StdRtlPkg.all;
use work.EthPkg.all;

entity EthPauseTx is 
   generic (
      TPD_G           : time := 1 ns
      PAUSE_512BITS_G : integer range 1 to (2**32) := 8
   );
   port ( 

      -- Clocks
      ethClk       : in  sl;
      ethClkRst    : in  sl;

      -- Incoming data from client
      sAxisMaster  : in  AxiStreamMasterType;
      sAxisSlave   : out AxiStreamSlaveType;

      -- Outgoing data to MAC
      mAxisMaster  : out AxiStreamMasterType;
      mAxisSlave   : in  AxiStreamSlaveType;

      -- Flow control input
      clientPause  : in  sl;

      -- Inputs from pause frame RX
      rxPauseReq   : in  sl;
      rxPauseValue : in  slv(15 downto 0);
     
      -- Configuration and status
      pauseEnable  : in  sl;
      pauseTime    : in  slv(15 downto 0);
      macAddress   : in  slv(47 downto 0);
      pauseTx      : out sl
   );
end EthPauseTx;


-- Define architecture
architecture EthPauseTx of EthPauseTx is

   constant CNT_BITS_C : integer := bitSize(PAUSE_512BITS_C);

   type StateType is ( IDLE_S, PASS_S, TX_S, LAST_S);

   type RegType is record
      state       : StateType;
      locPauseCnt : slv(15 downto 0);
      remPauseCnt : slv(15 downto 0);
      txCount     : slv(1  downto 0);
      pausePreCnt : slv(PAUSE_512BITS_C-1 downto 0);
      pauseTx     : sl;
      outMaster   : AxiStreamMasterType;
      outSlave    : AxiStreamSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state       => IDLE_S,
      locPauseCnt => (others=>'0'),
      remPauseCnt => (others=>'0'),
      txCount     => (others=>'0'),
      pausePreCnt => (others=>'0'),
      pauseTx     => '0',
      outMaster   => AXI_STREAM_MASTER_INIT_C,
      outSlave    => AXI_STREAM_SLAVE_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (ethClkRst, sAxisMaster, mAxisSlave, r, macAddress, pauseTime, 
                   rxPauseReq, rxPauseValue, clientPause, pauseEnable ) is
      variable v : RegType;
   begin

      v := r;

      -- Pre-counter, 8 clocks ~= 512 bit times of 10G
      v.pausePreCnt := r.pausePreCnt + 1;
      v.pauseTx := '0';

      -- Local pause count tracking
      if rxPauseReq = '1' and pauseEnable = '1' then
         v.locPauseCnt := rxPauseValue;
      elsif r.txPerCount /= 0 and r.pausePreCnt = 0 then
         v.txPerCount := r.txPerCount - 1;
      end if;

      -- Remote pause count tracking
      if r.remPauseCount /= 0 and r.pausePreCnt = 0 then
         v.remPauseCount := r.remPauseCount - 1;
      end if;

      -- State
      case r.state is

         -- IDLE, wait for frame
         when WAIT_S =>
            v.outSlave.tReady  := '0';
            v.outMaster.tValid := '0';
            v.txCount          := (others=>'0');

            -- Pause transmit needed
            if clientPause = '1' and r.remPauseCount = 0 and pauseEnable = '1' then
               v.state := TX_S;

            -- Transmit required and not paused by received pause count
            elsif sAxisMaster.tValid = '1' and r.locPauseCount = 0 then
               v.state := PASS_S;
            end if;


         -- Pause transmit
         when TX_S =>
            v.txReq := '0';

            if r.outMaster.tValid = '0' or sAxisSlave.tReady = '1' then
               v.outMaster        := AXI_STREAM_MASTER_INIT_C;
               v.outMaster.tValid := '1';
               v.txCount          := r.txCount + 1;

               -- Select output data
               case r.txCount is

                  -- Src Id, Upper 2 Bytes + Dest Id, All 6 bytes
                  when "00" => 
                     v.outMaster.tData(63 downto 56) := macAddress(39 downto 32);
                     v.outMaster.tData(55 downto 48) := macAddress(47 downto 40);
                     v.outMaster.tData(47 downto  0) := x"010000C28001";

                  -- Pause Opcode + Length/Type Field + Src Id, Lower 4 bytes
                  when "01" => 
                     v.outMaster.tData(63 downto 48) := x"0100";
                     v.outMaster.tData(47 downto 32) := x"0888";
                     v.outMaster.tData(31 downto 24) := macAddress(7  downto  0);
                     v.outMaster.tData(23 downto 16) := macAddress(15 downto  8);
                     v.outMaster.tData(15 downto  8) := macAddress(23 downto 16);
                     v.outMaster.tData(7  downto  0) := macAddress(31 downto 24);

                  -- Pause length and padding
                  when "10" => 
                     v.outMaster.tData(63 downto 16) := (others=>'0');
                     v.outMaster.tData(15 downto  8) := pauseTime(7  downto 0);
                     v.outMaster.tData(7  downto  0) := pauseTime(15 downto 8);

                  -- padding
                  when "11" =>
                     v.outMaster.tLast := '1';
                     v.remPauseCount   := pauseTime;
                     v.pauseTx         := '1';
                     v.state           := LAST_S;
               end case;
            end if;


         -- Passing data
         wait PASS_S =>

            -- Fill chain
            if r.outMaster.tValid = '0' then
               v.outSlave.tReady := '1';
               v.outMaster       := sAxisMaster;
            else
               v.outSlave.tReady := mAxisSlave.tReady;
               v.outMaster       := sAxisMaster;
            end if;

            if sAxisMaster.tValid = '1' and sAxisMaster.tLast = '1' and v.outSlave.tReady = '1' then
               v.state := LAST_S;
            end if;


         -- Last Data wait for ready
         wait LAST_S =>
            if mAxisSlave.tReady = '1' then
               v.outMaster.tValid := '0';
               v.state            := WAIT_S;
            end if;

      end case;

      if ethClkRst = '1' then
         v := REG_INIT_C;
      end if;

      rin <= v;

      mAxisMaster <= r.outMaster;
      sAxisSlave  <= v.outSlave;

   end process;

   seq : process (ethClk) is
   begin
      if rising_edge(ethClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end EthPauseTx;

