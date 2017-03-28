-------------------------------------------------------------------------------
-- File       : EthMacTxBypass.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2016-09-14
-------------------------------------------------------------------------------
-- Description:
-- Mux stage to allow high priority bypass traffic to override primary path
-- traffic.
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

entity EthMacTxBypass is
   generic (
      TPD_G    : time    := 1 ns;
      BYP_EN_G : boolean := false);
   port (
      -- Clock and Reset
      ethClk      : in  sl;
      ethRst      : in  sl;
      -- Incoming primary traffic
      sPrimMaster : in  AxiStreamMasterType;
      sPrimSlave  : out AxiStreamSlaveType;
      -- Incoming bypass traffic
      sBypMaster  : in  AxiStreamMasterType;
      sBypSlave   : out AxiStreamSlaveType;
      -- Outgoing data to MAC
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end EthMacTxBypass;

architecture rtl of EthMacTxBypass is

   type StateType is (
      IDLE_S,
      PRIM_S,
      BYP_S);

   type RegType is record
      mAxisMaster : AxiStreamMasterType;
      sPrimSlave  : AxiStreamSlaveType;
      sBypSlave   : AxiStreamSlaveType;
      state       : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      mAxisMaster => AXI_STREAM_MASTER_INIT_C,
      sPrimSlave  => AXI_STREAM_SLAVE_INIT_C,
      sBypSlave   => AXI_STREAM_SLAVE_INIT_C,
      state       => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";

begin
   
   U_BypTxEnGen : if (BYP_EN_G = true) generate
      
      comb : process (ethRst, mAxisSlave, r, sBypMaster, sPrimMaster) is
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Clear tValid on ready assertion
         if mAxisSlave.tReady = '1' then
            v.mAxisMaster.tValid := '0';
         end if;

         -- Clear ready
         v.sPrimSlave.tReady := '0';
         v.sBypSlave.tReady  := '0';

         -- State Machine
         case r.state is
            ----------------------------------------------------------------------   
            when IDLE_S =>
               -- Check if ready to move data
               if v.mAxisMaster.tValid = '0' then
                  -- Check for Bypass frame request
                  if (sBypMaster.tValid = '1') then
                     -- Accept the data
                     v.sBypSlave.tReady := '1';
                     -- Move data
                     v.mAxisMaster      := sBypMaster;
                     -- Check for no EOF
                     if sBypMaster.tLast = '0' then
                        -- Next state
                        v.state := BYP_S;
                     end if;
                  -- Check for Primary frame request
                  elsif (sPrimMaster.tValid = '1') then
                     -- Accept the data
                     v.sPrimSlave.tReady := '1';
                     -- Move data
                     v.mAxisMaster       := sPrimMaster;
                     -- Check for no EOF
                     if sPrimMaster.tLast = '0' then
                        -- Next state
                        v.state := PRIM_S;
                     end if;
                  end if;
               end if;
            ----------------------------------------------------------------------   
            when PRIM_S =>
               -- Check if ready to move data
               if (v.mAxisMaster.tValid = '0') and (sPrimMaster.tValid = '1') then
                  -- Accept the data
                  v.sPrimSlave.tReady := '1';
                  -- Move the data
                  v.mAxisMaster       := sPrimMaster;
                  -- Check for EOF
                  if (sPrimMaster.tLast = '1') then
                     -- Next state
                     v.state := IDLE_S;
                  end if;
               end if;
            ----------------------------------------------------------------------   
            when BYP_S =>
               -- Check if ready to move data
               if (v.mAxisMaster.tValid = '0') and (sBypMaster.tValid = '1') then
                  -- Accept the data
                  v.sBypSlave.tReady := '1';
                  -- Move the data
                  v.mAxisMaster      := sBypMaster;
                  -- Check for EOF
                  if (sBypMaster.tLast = '1') then
                     -- Next state
                     v.state := IDLE_S;
                  end if;
               end if;
         ----------------------------------------------------------------------   
         end case;

         -- Reset
         if ethRst = '1' then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs 
         sPrimSlave  <= v.sPrimSlave;
         sBypSlave   <= v.sBypSlave;
         mAxisMaster <= r.mAxisMaster;

      end process;

      seq : process (ethClk) is
      begin
         if rising_edge(ethClk) then
            r <= rin after TPD_G;
         end if;
      end process seq;
      
   end generate;

   U_BypTxDisGen : if (BYP_EN_G = false) generate
      mAxisMaster <= sPrimMaster;
      sPrimSlave  <= mAxisSlave;
      sBypSlave   <= AXI_STREAM_SLAVE_FORCE_C;
   end generate;
   
end rtl;
