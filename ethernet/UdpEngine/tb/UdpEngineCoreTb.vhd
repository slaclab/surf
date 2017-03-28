-------------------------------------------------------------------------------
-- File       : UdpEngineCoreTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-17
-- Last update: 2015-08-25
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the UdpEngineCore module
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.EthMacPkg.all;

entity UdpEngineCoreTb is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Interface to UDP Engine
      obClientMaster : in  AxiStreamMasterType;
      obClientSlave  : out AxiStreamSlaveType;
      ibClientMaster : out AxiStreamMasterType;
      ibClientSlave  : in  AxiStreamSlaveType;
      -- Simulation Result
      passed         : out sl;
      failed         : out sl;
      -- Clock and Reset
      clk            : in  sl;
      rst            : in  sl);
end UdpEngineCoreTb;

architecture rtl of UdpEngineCoreTb is

   type StateType is (
      PROCESSING_S,
      DONE_S); 

   type RegType is record
      passed         : sl;
      failed         : slv(4 downto 0);
      passedDly      : sl;
      failedDly      : sl;
      txDone         : sl;
      tKeep          : slv(15 downto 0);
      timer          : slv(15 downto 0);
      txWordCnt      : natural range 0 to 64;
      txWordSize     : natural range 0 to 64;
      txByteCnt      : natural range 0 to 16;
      rxWordCnt      : natural range 0 to 64;
      rxWordSize     : natural range 0 to 64;
      rxByteCnt      : natural range 0 to 16;
      ibClientMaster : AxiStreamMasterType;
      obClientSlave  : AxiStreamSlaveType;
      state          : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      passed         => '0',
      failed         => (others => '0'),
      passedDly      => '0',
      failedDly      => '0',
      txDone         => '0',
      tKeep          => (others => '1'),
      timer          => (others => '0'),
      txWordCnt      => 0,
      txWordSize     => 0,
      txByteCnt      => 0,
      rxWordCnt      => 0,
      rxWordSize     => 0,
      rxByteCnt      => 0,
      ibClientMaster => AXI_STREAM_MASTER_INIT_C,
      obClientSlave  => AXI_STREAM_SLAVE_INIT_C,
      state          => PROCESSING_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (ibClientSlave, obClientMaster, r, rst) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.obClientSlave := AXI_STREAM_SLAVE_INIT_C;
      if ibClientSlave.tReady = '1' then
         v.ibClientMaster.tValid := '0';
         v.ibClientMaster.tLast  := '0';
         v.ibClientMaster.tUser  := (others => '0');
         v.ibClientMaster.tKeep  := (others => '1');
      end if;
      v.tKeep := (others => '1');

      -- Increment the timer
      if r.timer /= x"FFFF" then
         v.timer := r.timer + 1;
      else
         -- Timed out
         v.failed(0) := '1';
      end if;

      -- Create a delayed copy for easier viewing in simulation GUI
      v.passedDly := r.passed;
      v.failedDly := uOr(r.failed);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when PROCESSING_S =>
            ----------------------------------------------------------------------
            ----------------------------------------------------------------------
            ----------------------------------------------------------------------
            -- TX generate
            if (v.ibClientMaster.tValid = '0') and (r.txDone = '0') then
               -- Move data
               v.ibClientMaster.tValid := '1';
               -- Check for SOF
               if r.txWordCnt = 0 then
                  ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.ibClientMaster, '1');
               end if;
               -- Send data
               v.ibClientMaster.tdata := toSlv((r.txWordCnt*16)+r.txByteCnt+1, 128);
               -- Increment the counter
               v.txWordCnt            := r.txWordCnt + 1;
               -- Check for tLast
               if r.txWordCnt = r.txWordSize then
                  -- Reset the counters
                  v.txWordCnt            := 0;
                  -- Set EOF
                  v.ibClientMaster.tLast := '1';
                  -- Increment the counter
                  v.txByteCnt            := r.txByteCnt + 1;
                  -- Loop through the tKeep byte field
                  for i in 15 downto 0 loop
                     if (i > r.txByteCnt) then
                        v.ibClientMaster.tKeep(i) := '0';
                     end if;
                  end loop;
                  -- Check the counter
                  if r.txByteCnt = 15 then
                     -- Reset the counter
                     v.txByteCnt  := 0;
                     -- Increment the counter
                     v.txWordSize := r.txWordSize + 1;
                     -- Check if we are done
                     if r.txWordSize = 63 then
                        v.txDone := '1';
                     end if;
                  end if;
               end if;
            end if;
            ----------------------------------------------------------------------
            ----------------------------------------------------------------------
            ----------------------------------------------------------------------
            -- RX Comparator
            if obClientMaster.tValid = '1' then
               -- Accept the data
               v.obClientSlave.tReady := '1';
               -- Check for SOF
               if (r.rxWordCnt = 0) and (ssiGetUserSof(EMAC_AXIS_CONFIG_C, obClientMaster) = '0') then
                  v.failed(1) := '1';
               end if;
               -- Increment the counter
               v.rxWordCnt := r.rxWordCnt + 1;
               -- Check for errors
               if (obClientMaster.tdata /= toSlv((r.rxWordCnt*16)+r.rxByteCnt+1, 128)) then
                  v.failed(2) := '1';
               end if;
               -- Check if done with simulation test
               if (uOr(v.failed) = '0') and obClientMaster.tLast = '1' then
                  -- Reset the transaction timer
                  v.timer     := x"0000";
                  -- Reset the counter
                  v.rxWordCnt := 0;
                  -- Increment the counter
                  v.rxByteCnt := r.rxByteCnt + 1;
                  -- Loop through the tKeep byte field
                  for i in 15 downto 0 loop
                     if (i > r.rxByteCnt) then
                        v.tKeep(i) := '0';
                     end if;
                  end loop;
                  -- Check for errors
                  if (v.tKeep /= obClientMaster.tKeep) then
                     v.failed(3) := '1';
                  end if;
                  -- Check the counter
                  if r.rxByteCnt = 15 then
                     -- Reset the counter
                     v.rxByteCnt  := 0;
                     -- Increment the counter
                     v.rxWordSize := r.rxWordSize + 1;
                  end if;
                  -- Check for errors
                  if (r.rxWordSize /= r.rxWordCnt) then
                     v.failed(4) := '1';
                  end if;
                  -- Check for full word transfer and full size
                  if (obClientMaster.tKeep = x"FFFF") and (r.rxWordCnt = 63) then
                     -- Next state
                     v.state := DONE_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DONE_S =>
            v.passed := '1';
            v.timer  := x"0000";
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      obClientSlave  <= v.obClientSlave;
      ibClientMaster <= r.ibClientMaster;
      passed         <= r.passedDly;
      failed         <= r.failedDly;
      
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
