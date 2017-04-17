-------------------------------------------------------------------------------
-- File       : EthMacRxFilter.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-21
-- Last update: 2016-09-14
-------------------------------------------------------------------------------
-- Description: Ethernet MAC's RX frame filter
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

entity EthMacRxFilter is
   generic (
      TPD_G     : time    := 1 ns;
      FILT_EN_G : boolean := false);
   port (
      -- Clock and Reset
      ethClk      : in  sl;
      ethRst      : in  sl;
      -- Incoming data from MAC
      sAxisMaster : in  AxiStreamMasterType;
      -- Outgoing data 
      mAxisMaster : out AxiStreamMasterType;
      mAxisCtrl   : in  AxiStreamCtrlType;
      -- Configuration
      dropOnPause : in  sl;
      macAddress  : in  slv(47 downto 0);
      filtEnable  : in  sl);
end EthMacRxFilter;

architecture rtl of EthMacRxFilter is

   type StateType is (
      IDLE_S,
      DROP_S,
      PASS_S);

   type RegType is record
      state       : StateType;
      mAxisMaster : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state       => IDLE_S,
      mAxisMaster => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";   

begin

   U_FiltEnGen : if (FILT_EN_G = true) generate

      comb : process (dropOnPause, ethRst, filtEnable, mAxisCtrl, macAddress, r, sAxisMaster) is
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Move the data
         v.mAxisMaster := sAxisMaster;

         -- State Machine
         case r.state is
            ----------------------------------------------------------------------
            when IDLE_S =>
               -- Check for data
               if (sAxisMaster.tValid = '1') then
                  -- Drop frames when pause is asserted to avoid downstream errors
                  if (mAxisCtrl.pause = '1') and (dropOnPause = '1') then
                     -- Drop the packet
                     v.mAxisMaster.tValid := '0';
                     -- Check for no EOF
                     if (sAxisMaster.tLast = '0') then
                        -- Next State
                        v.state := DROP_S;
                     end if;
                  -- Local match, broadcast or multicast
                  elsif (filtEnable = '0') or
                     (sAxisMaster.tData(47 downto 0) = macAddress) or         -- Local
                     (sAxisMaster.tData(0) = '1') or                          -- Multicast
                     (sAxisMaster.tData(47 downto 0) = x"FFFFFFFFFFFF") then  -- Broadcast
                     -- Check for no EOF
                     if (sAxisMaster.tLast = '0') then
                        -- Next State
                        v.state := PASS_S;
                     end if;
                  -- Drop frame
                  else
                     -- Drop the packet
                     v.mAxisMaster.tValid := '0';
                     -- Check for no EOF
                     if (sAxisMaster.tLast = '0') then
                        -- Next State
                        v.state := DROP_S;
                     end if;
                  end if;
               end if;
            ----------------------------------------------------------------------
            when DROP_S =>
               -- Drop the packet
               v.mAxisMaster.tValid := '0';
               -- Check for a valid EOF
               if (sAxisMaster.tValid = '1') and (sAxisMaster.tLast = '1') then
                  -- Next State
                  v.state := IDLE_S;
               end if;
            ----------------------------------------------------------------------
            when PASS_S =>
               -- Check for a valid EOF
               if (sAxisMaster.tValid = '1') and (sAxisMaster.tLast = '1') then
                  -- Next State
                  v.state := IDLE_S;
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
         mAxisMaster <= r.mAxisMaster;

      end process;

      seq : process (ethClk) is
      begin
         if rising_edge(ethClk) then
            r <= rin after TPD_G;
         end if;
      end process seq;
      
   end generate;

   U_FiltDisGen : if (FILT_EN_G = false) generate
      mAxisMaster <= sAxisMaster;
   end generate;

end rtl;
